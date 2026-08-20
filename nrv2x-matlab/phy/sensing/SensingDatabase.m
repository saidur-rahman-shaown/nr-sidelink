classdef SensingDatabase < handle
%SensingDatabase Decoded SCI-1A records + monitored(t') vector.
%SPEC: TS 38.214 8.1.4 step 2 (window, half-duplex); Plan.md §8.1
%
%   One record per successfully decoded SCI-1A. Slots default to
%   UNMONITORED until markMonitored is called — this matches boot (§5 B4):
%   a UE that has not listened to a slot may not treat it as sensed.
%
%   NOTE scale: plain arrays, pruned on query. Swap for a circular buffer
%   at the 100-UE milestone (Plan.md §15), interface unchanged.

    properties (SetAccess = private)
        cfg
        slotMap
        % record columns (parallel arrays)
        recAbs   = zeros(0,1)   % absolute rx slot (0-based)
        recLog   = zeros(0,1)   % logical rx slot (1-based)
        recStart = zeros(0,1)   % start sub-channel (0-based)
        recL     = zeros(0,1)   % LsubCH of the sensed allocation
        recPrio  = zeros(0,1)   % SCI-1A priority field (1..8)
        recPrsvp = zeros(0,1)   % resource reservation period, ms (0 = absent)
        recRSRP  = zeros(0,1)   % SL RSRP, dBm (abstract; per sl-RS-ForSensing)
        recTriv  = {}           % extra same-TB reserved slots (logical idx)
        recSrcL2 = zeros(0,1)   % source L2 ID from SCI-2 (0 = not decoded)
        monitored               % 1 x nLogical logical
    end

    methods
        function obj = SensingDatabase(cfg, slotMap)
            obj.cfg = cfg;
            obj.slotMap = slotMap;
            obj.monitored = false(1, slotMap.nLogical);
        end

        function addRecord(obj, absSlot, startSub, LsubCH, prio, Prsvp_ms, rsrp_dBm, trivLog, srcL2)
            %addRecord Store one decoded SCI-1A. Non-pool slots are ignored.
            %   trivLog (optional): K x 2 [logSlot, startSub] — the same-TB
            %   resources chained by the SCI's TRIV/FRIV. Each chained
            %   resource carries its OWN start sub-channel (the FRIV is
            %   per-resource); LsubCH is common to the TB.
            %   srcL2 (optional): source L2 ID when the SCI-2 was decoded;
            %   sensing itself never uses it (8.1.4 is destination-blind),
            %   it exists for diagnostics/visualisation of reservations.
            if nargin < 8 || isempty(trivLog), trivLog = zeros(0, 2); end
            if nargin < 9, srcL2 = 0; end
            assert(size(trivLog, 2) == 2, 'SensingDatabase:trivShape', ...
                'trivLog must be K x 2 [logSlot, startSub]');
            lg = obj.logOf(absSlot);
            if isnan(lg), return; end
            obj.recAbs(end+1,1)   = absSlot;
            obj.recLog(end+1,1)   = lg;
            obj.recStart(end+1,1) = startSub;
            obj.recL(end+1,1)     = LsubCH;
            obj.recPrio(end+1,1)  = prio;
            obj.recPrsvp(end+1,1) = Prsvp_ms;
            obj.recRSRP(end+1,1)  = rsrp_dBm;
            obj.recTriv{end+1,1}  = trivLog;
            obj.recSrcL2(end+1,1) = srcL2;
        end

        function markMonitored(obj, absSlot)
            lg = obj.logOf(absSlot);
            if ~isnan(lg), obj.monitored(lg) = true; end
        end

        function markUnmonitored(obj, absSlot)
            %markUnmonitored Half-duplex: own-TX slot cannot be sensed.
            lg = obj.logOf(absSlot);
            if ~isnan(lg), obj.monitored(lg) = false; end
        end

        function recs = recordsInAbsWindow(obj, loAbs, hiAbs)
            %recordsInAbsWindow Records with absSlot in [loAbs, hiAbs).
            %   The EXCLUSIVE right end is the caller's n - T_proc,0 bound.
            sel = obj.recAbs >= loAbs & obj.recAbs < hiAbs;
            idx = find(sel);
            recs = struct('log', {}, 'startSub', {}, 'L', {}, ...
                          'prio', {}, 'Prsvp', {}, 'rsrp', {}, ...
                          'trivLog', {}, 'srcL2', {}, 'abs', {});
            for k = 1:numel(idx)
                i = idx(k);
                recs(k).log      = obj.recLog(i);
                recs(k).startSub = obj.recStart(i);
                recs(k).L        = obj.recL(i);
                recs(k).prio     = obj.recPrio(i);
                recs(k).Prsvp    = obj.recPrsvp(i);
                recs(k).rsrp     = obj.recRSRP(i);
                recs(k).trivLog  = obj.recTriv{i};
                recs(k).srcL2    = obj.recSrcL2(i);
                recs(k).abs      = obj.recAbs(i);
            end
        end

        function logs = unmonitoredPoolLogicals(obj, loAbs, hiAbs)
            %unmonitoredPoolLogicals Pool slots in [loAbs, hiAbs) not monitored.
            absAll = obj.slotMap.logical2abs;
            sel = absAll >= loAbs & absAll < hiAbs;
            logs = find(sel);
            logs = logs(~obj.monitored(logs));
        end
    end

    methods (Access = private)
        function lg = logOf(obj, absSlot)
            if absSlot < 0 || absSlot + 1 > numel(obj.slotMap.abs2logical)
                lg = NaN;
            else
                lg = obj.slotMap.abs2logical(absSlot + 1);
            end
        end
    end
end
