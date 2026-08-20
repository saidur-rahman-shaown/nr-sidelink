function [S_A, M_total, ThOffsetFinal, S_total] = selectCandidateResources(req, cfg, slotMap, db)
%selectCandidateResources TS 38.214 8.1.4 steps 1-7. Reports S_A to MAC.
%SPEC: TS 38.214 8.1.4
%
%   PHY-side procedure (Plan.md §0.5): determines the candidate set and
%   reports it; the MAC does the random pick (38.321 5.22.1.1).
%
%   req: .n               trigger slot (absolute, 0-based)
%        .LsubCH          sub-channels per candidate
%        .prioTx          own L1 priority (1..8)
%        .remainingPDB_ms remaining packet delay budget
%        .PrsvpTx_ms      own reservation period (0 = aperiodic)
%        .Cresel          10*counter (periodic) or 1 — owned by MAC
%
%   Returns S_A, M_total, the final 3 dB offset (needed by pre-emption,
%   §8.6), and S_total for diagnostics. Candidates are [yLogical, xStart].

n = req.n;
[Tproc0, Tproc1] = procTimeTable(cfg.mu);

% ---- step 1: selection window [n+T1, n+T2] ---------------------------
T1 = Tproc1;                                   % policy §0.4: T1 = T_proc,1
pdbSlots = round(req.remainingPDB_ms * cfg.slotsPerMs);
T2min = cfg.sl_SelectionWindowList_slots(req.prioTx);
if T2min < pdbSlots
    T2 = pdbSlots;                             % policy §0.4: use full PDB
else
    T2 = pdbSlots;                             % T2min >= PDB -> T2 = PDB
end
assert(T2 >= T1 + 1, 'sensing:windowEmpty', ...
    'Selection window empty: T1=%d, T2=%d (PDB too small).', T1, T2);

loA = n + T1;  hiA = n + T2;
inWin = slotMap.logical2abs >= loA & slotMap.logical2abs <= hiA;
ys = find(inWin);                              % logical pool slots in window
xs = 0:(cfg.sl_NumSubchannel_r16 - req.LsubCH);
assert(~isempty(ys) && ~isempty(xs), 'sensing:noCandidates', ...
    'No candidate resources in [n+%d, n+%d].', T1, T2);

S_total = [repelem(ys(:), numel(xs)), repmat(xs(:), numel(ys), 1)];
M_total = size(S_total, 1);
X = cfg.sl_TxPercentageList(req.prioTx);       % sl-TxPercentageList-r16

% ---- step 2: sensing window [n-T0, n-Tproc0), right end EXCLUSIVE ----
T0slots = cfg.sl_SensingWindow_ms * cfg.slotsPerMs;
recs  = db.recordsInAbsWindow(n - T0slots, n - Tproc0);
unmon = db.unmonitoredPoolLogicals(n - T0slots, n - Tproc0);

rsvpList = cfg.sl_ResourceReservePeriodList_ms;
rsvpList = rsvpList(rsvpList > 0);

ThOffset = 0;                                  % step-7 escalation, dB
for iter = 0:cfg.maxThresholdEscalations
    % ---- step 4: initialise S_A to all candidates --------------------
    alive = true(M_total, 1);

    % ---- step 5: unmonitored slots, hypothetical SCI -----------------
    % For each slot the UE could not hear, assume an SCI-1A with each
    % allowed periodicity reserving ALL sub-channels, and apply cond (c).
    for m = unmon
        for P = rsvpList
            hyp = struct('log', m, 'startSub', 0, ...
                         'L', cfg.sl_NumSubchannel_r16, ...
                         'Prsvp', P, 'trivLog', []);
            alive = alive & ~condCMask( ...
                S_total, hyp, req, cfg, slotMap, n, T2);
        end
    end

    % ---- step 5a: re-initialise if step 5 over-excluded --------------
    if nnz(alive) < X * M_total
        alive = true(M_total, 1);
    end

    % ---- step 6: sensed reservations, conditions (a)+(b)+(c) ---------
    for r = recs
        % (b) 64-entry threshold lookup, i = pRx + (pTx-1)*8, + escalation
        Th = cfg.sl_Thres_RSRP_List_dBm(r.prio + (req.prioTx - 1) * 8) + ThOffset;
        if r.rsrp > Th
            alive = alive & ~condCMask( ...
                S_total, r, req, cfg, slotMap, n, T2);
        end
    end

    % ---- step 7: report or escalate and restart from step 4 ----------
    if nnz(alive) >= X * M_total
        S_A = S_total(alive, :);
        ThOffsetFinal = ThOffset;
        return;
    end
    ThOffset = ThOffset + 3;                   % every priority pair, +3 dB
end

error('sensing:noConvergence', ...
    'Threshold escalation did not converge after %d iterations.', ...
    cfg.maxThresholdEscalations);
end
