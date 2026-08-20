classdef MacEntity < handle
%MacEntity Rel-16 sidelink MAC: Mode 2 grant, SPS, re-evaluation, pre-emption.
%SPEC: TS 38.321 5.22.1.1 (grant), 5.22.1.2 (reselection check),
%      5.22.1.2a (re-evaluation / pre-emption)
%
%   Owns: the selected grant, SL_RESOURCE_RESELECTION_COUNTER, C_resel,
%   the keep-probability draw, the random pick from S_A, and all seven
%   reselection triggers. Never computes an RSRP or a threshold — the
%   8.1.4 procedure runs PHY-side (phy/sensing) per Plan.md §0.5.

    properties
        cfg
        slotMap
        db                  % SensingDatabase
        rs                  % RandStream (per-UE, seeded — Plan.md §8.4)
        % traffic / grant parameters
        prioTx     = 3      % L1 priority (1..8)
        Prsvp_ms   = 100    % own reservation period (0 = aperiodic)
        LsubCH     = 2
        pdb_ms     = 100    % remaining packet delay budget at trigger
        hasDataFcn          % @(n) logical — data availability hook
    end

    properties (SetAccess = private)
        grant = []          % struct, [] when no selected grant
        lastTxAbs = -inf
        unusedOpportunities = 0
        flagPoolReconfigured = false      % trigger 2 (harness-driven, §8.5)
        flagSduTooLarge      = false      % trigger 6
        flagPdbFail          = false      % trigger 7
        stats
    end

    methods
        function obj = MacEntity(cfg, slotMap, db, rs)
            obj.cfg = cfg;  obj.slotMap = slotMap;  obj.db = db;  obj.rs = rs;
            obj.hasDataFcn = @(n) true;   % full buffer by default
            obj.stats = struct('selections', 0, 'txCount', 0, ...
                'reEval', 0, 'preempt', 0, 'keepCount', 0, ...
                'triggerCounts', zeros(1, 7));
        end

        function txInfo = runSlot(obj, n)
            %runSlot One MAC slot: T3 checks, reselection check, transmit.
            obj.reEvalPreemptCheck(n);          % 5.22.1.2a
            obj.reselectionCheck(n);            % 5.22.1.2
            txInfo = obj.maybeTransmit(n);      % 5.22.1.1
        end

        % ---- trigger inputs (harness / upper-layer hooks) -------------
        function notifyPoolReconfigured(obj), obj.flagPoolReconfigured = true; end
        function reportSduTooLarge(obj),      obj.flagSduTooLarge = true;      end
        function reportPdbFail(obj),          obj.flagPdbFail = true;          end
    end

    methods (Static)
        function row = pickUniform(S_A, rs)
            %pickUniform Random selection from S_A with equal probability.
            %SPEC: TS 38.321 5.22.1.1
            row = S_A(randi(rs, size(S_A, 1)), :);
        end
    end

    methods (Access = private)

        function reselectionCheck(obj, n)
            %SPEC: TS 38.321 5.22.1.2 — the seven triggers.
            clearWhy = 0;

            % (2) pool (re)configured by RRC — scripted event in this UE
            if obj.flagPoolReconfigured
                clearWhy = 2;  obj.flagPoolReconfigured = false;
            end
            % (6) grant cannot fit the SDU (segmentation declined)
            if clearWhy == 0 && obj.flagSduTooLarge
                clearWhy = 6;  obj.flagSduTooLarge = false;
            end
            % (7) grant cannot meet remaining PDB
            if clearWhy == 0 && obj.flagPdbFail
                clearWhy = 7;  obj.flagPdbFail = false;
            end
            % (1) counter expired; keep-probability draw happens ONCE
            if clearWhy == 0 && ~isempty(obj.grant) && ...
                    obj.grant.PtxPrime > 0 && obj.grant.counter <= 0 && ...
                    ~obj.grant.expiryHandled
                obj.grant.expiryHandled = true;
                if rand(obj.rs) < obj.cfg.sl_ProbResourceKeep
                    % keep grant, redraw counter (5.22.1.2 cond 1 not met)
                    [obj.grant.counter, obj.grant.Cresel] = ...
                        creselDraw(obj.Prsvp_ms, obj.rs);
                    obj.grant.expiryHandled = false;
                    obj.stats.keepCount = obj.stats.keepCount + 1;
                else
                    clearWhy = 1;
                end
            end
            % (4) no (re)transmission on the grant during the last second
            % (measured against grant activity: creation or last TX)
            if clearWhy == 0 && ~isempty(obj.grant)
                lastActivity = max(obj.lastTxAbs, obj.grant.createdAt);
                if isfinite(lastActivity) && ...
                        (n - lastActivity) > 1000 * obj.cfg.slotsPerMs
                    clearWhy = 4;
                end
            end
            % (5) sl-ReselectAfter consecutive unused opportunities
            if clearWhy == 0 && ~isempty(obj.grant) && ...
                    ~isempty(obj.cfg.sl_ReselectAfter) && ...
                    obj.unusedOpportunities >= obj.cfg.sl_ReselectAfter
                clearWhy = 5;
            end

            if clearWhy > 0
                obj.grant = [];
                obj.unusedOpportunities = 0;
                obj.stats.triggerCounts(clearWhy) = ...
                    obj.stats.triggerCounts(clearWhy) + 1;
            end

            % (3) no selected sidelink grant on the pool (and data waiting)
            if isempty(obj.grant) && obj.hasDataFcn(n)
                if obj.canSelectAt(n)
                    obj.selectNewGrant(n);
                    if clearWhy == 0
                        obj.stats.triggerCounts(3) = obj.stats.triggerCounts(3) + 1;
                    end
                end
            end
        end

        function selectNewGrant(obj, n)
            %SPEC: TS 38.321 5.22.1.1 + TS 38.214 8.1.4 (via PHY report)
            [counter, Cresel] = creselDraw(obj.Prsvp_ms, obj.rs);
            req = obj.buildReq(n, Cresel);
            S_A = selectCandidateResources( ...
                req, obj.cfg, obj.slotMap, obj.db);

            % initial TX: uniform random from S_A
            init = MacEntity.pickUniform(S_A, obj.rs);

            % blind retransmissions: after the initial, within 31 physical
            % slots (TRIV bound), at most sl-MaxNumPerReserve-1 extra
            nRetx = min(obj.cfg.sl_MaxTxTransNumPSSCH - 1, ...
                        obj.cfg.sl_MaxNumPerReserve - 1);
            initAbs = obj.slotMap.logical2abs(init(1));
            gap = obj.slotMap.logical2abs(S_A(:, 1)) - initAbs;
            pool = S_A(gap >= 1 & gap <= 31, :);
            resList = init;
            usedSlots = init(1);
            for k = 1:nRetx
                avail = pool(~ismember(pool(:, 1), usedSlots), :);
                if isempty(avail), break; end
                pick = MacEntity.pickUniform(avail, obj.rs);
                resList(end+1, :) = pick;                   %#ok<AGROW>
                usedSlots(end+1) = pick(1);                 %#ok<AGROW>
            end
            [~, order] = sort(resList(:, 1));
            resList = resList(order, :);

            g.baseLog  = resList(:, 1);
            g.baseX    = resList(:, 2);
            g.LsubCH   = obj.LsubCH;
            g.PtxPrime = prsvpToLogical(obj.Prsvp_ms, obj.slotMap);
            g.counter  = counter;
            g.Cresel   = Cresel;
            g.expiryHandled = false;
            g.occurrence = 0;
            g.initialDone = false;
            g.createdAt = n;
            g.pending  = [g.baseLog, g.baseX, zeros(size(g.baseLog))]; % unsignalled
            obj.grant  = g;
            obj.stats.selections = obj.stats.selections + 1;
        end

        function txInfo = maybeTransmit(obj, n)
            txInfo = [];
            if isempty(obj.grant), return; end
            g = obj.grant;
            absPending = obj.slotMap.logical2abs(g.pending(:, 1));
            row = find(absPending == n, 1);
            if isempty(row), return; end

            isInitial = ~g.initialDone;
            if isInitial && ~obj.hasDataFcn(n)
                % opportunity unused: skip the whole occurrence (trigger 5 feed)
                obj.unusedOpportunities = obj.unusedOpportunities + 1;
                obj.advanceOccurrence();
                return;
            end

            % same-TB TRIV resources: [logSlot, startSub] per remaining
            % resource — SCI-1A's FRIV carries a PER-RESOURCE frequency
            % allocation, so the chained slots keep their own sub-channels
            remaining = g.pending(row+1:end, 1:2);
            txInfo = struct( ...
                'absSlot',   n, ...
                'logSlot',   g.pending(row, 1), ...
                'startSub',  g.pending(row, 2), ...
                'LsubCH',    g.LsubCH, ...
                'prio',      obj.prioTx, ...
                'Prsvp_ms',  obj.Prsvp_ms, ...              % SCI-1A period field
                'trivLog',   remaining, ...
                'isInitial', isInitial, ...
                'occurrence', g.occurrence);

            % the SCI just sent signals all remaining resources of this TB
            obj.grant.pending(row:end, 3) = 1;
            obj.grant.pending(row, :) = [];                 % consumed

            if isInitial
                obj.grant.counter = obj.grant.counter - 1;  % per occurrence
                obj.grant.initialDone = true;
                obj.unusedOpportunities = 0;
            end
            obj.lastTxAbs = n;
            obj.stats.txCount = obj.stats.txCount + 1;

            if isempty(obj.grant.pending)
                obj.advanceOccurrence();
            end
        end

        function advanceOccurrence(obj)
            %advanceOccurrence SPS: same resources shifted by P'_rsvp_TX.
            g = obj.grant;
            if g.PtxPrime <= 0
                obj.grant = [];                             % one-shot grant
                return;
            end
            newLog = g.baseLog + g.PtxPrime;
            if any(newLog > obj.slotMap.nLogical)
                obj.grant = [];                             % beyond horizon
                return;
            end
            obj.grant.baseLog = newLog;
            obj.grant.occurrence = g.occurrence + 1;
            obj.grant.initialDone = false;
            % announced by the period field of this occurrence's SCIs
            obj.grant.pending = [newLog, g.baseX, ones(size(newLog))];
        end

        function reEvalPreemptCheck(obj, n)
            %SPEC: TS 38.321 5.22.1.2a; TS 38.214 8.1.4 (T3 = T_proc,1)
            if isempty(obj.grant), return; end
            [~, Tproc1] = procTimeTable(obj.cfg.mu);
            T3 = Tproc1;

            absPending = obj.slotMap.logical2abs(obj.grant.pending(:, 1));
            dueRows = find(absPending == n + T3);
            if isempty(dueRows) || ~obj.canSelectAt(n), return; end

            req = obj.buildReq(n, obj.grant.Cresel);
            [S_A, ~, ThOffFinal] = selectCandidateResources( ...
                req, obj.cfg, obj.slotMap, obj.db);

            for row = dueRows(:)'
                r = obj.grant.pending(row, 1:2);
                inSA = any(S_A(:, 1) == r(1) & S_A(:, 2) == r(2));
                if inSA, continue; end

                if obj.grant.pending(row, 3) == 0
                    % --- re-evaluation: not yet signalled in any SCI ----
                    obj.replaceResource(row, S_A);
                    obj.stats.reEval = obj.stats.reEval + 1;
                else
                    % --- pre-emption: already signalled -----------------
                    [exc, prioRx] = isExcludedByStep6( ...
                        r, req, ThOffFinal, obj.cfg, obj.slotMap, obj.db);
                    if exc && obj.preemptionApplies(prioRx)
                        obj.replaceResource(row, S_A);
                        obj.stats.preempt = obj.stats.preempt + 1;
                    end
                end
            end
        end

        function tf = preemptionApplies(obj, prioRx)
            %SPEC: TS 38.214 8.1.4 — sl-PreemptionEnable-r16 condition.
            %   Lower prio value = higher priority; prioTx > prioRx means
            %   the other UE outranks us.
            pe = obj.cfg.sl_PreemptionEnable;
            if isempty(pe)
                tf = false;                    % absent: no pre-emption
            elseif strcmp(pe, 'enabled')
                tf = obj.prioTx > prioRx;
            else                               % 'pl1'..'pl8' -> prio_pre
                prioPre = sscanf(pe, 'pl%d');
                tf = (prioRx < prioPre) && (obj.prioTx > prioRx);
            end
        end

        function replaceResource(obj, row, S_A)
            %replaceResource Random replacement from S_A, avoiding own slots.
            otherSlots = obj.grant.pending(:, 1);
            otherSlots(row) = [];
            avail = S_A(~ismember(S_A(:, 1), otherSlots), :);
            if isempty(avail), avail = S_A; end
            pick = MacEntity.pickUniform(avail, obj.rs);
            wasSignalled = obj.grant.pending(row, 3);
            obj.grant.pending(row, :) = [pick, wasSignalled];
            [~, order] = sort(obj.slotMap.logical2abs(obj.grant.pending(:, 1)));
            obj.grant.pending = obj.grant.pending(order, :);
        end

        function req = buildReq(obj, n, Cresel)
            req = struct('n', n, 'LsubCH', obj.LsubCH, ...
                'prioTx', obj.prioTx, 'remainingPDB_ms', obj.pdb_ms, ...
                'PrsvpTx_ms', obj.Prsvp_ms, 'Cresel', Cresel);
        end

        function tf = canSelectAt(obj, n)
            %canSelectAt Selection window must fit inside the sim horizon.
            T2 = round(obj.pdb_ms * obj.cfg.slotsPerMs);
            tf = (n + T2) <= obj.slotMap.logical2abs(end);
        end
    end
end
