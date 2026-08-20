function [tf, prioRxBest] = isExcludedByStep6(res, req, ThOffset, cfg, slotMap, db)
%isExcludedByStep6 Step-6 exclusion test for ONE resource at a given offset.
%SPEC: TS 38.214 8.1.4 (pre-emption condition 2, clause 5.22.1.2a)
%
%   Used by the pre-emption check: the resource must meet the step-6
%   conditions at the FINAL threshold (initial + every 3 dB escalation).
%
%   res = [yLogical, xStart];  prioRxBest = lowest (i.e. highest-priority)
%   prio value among the SCIs that exclude res, NaN if none.

n = req.n;
[Tproc0, ~] = procTimeTable(cfg.mu);
T0slots = cfg.sl_SensingWindow_ms * cfg.slotsPerMs;
recs = db.recordsInAbsWindow(n - T0slots, n - Tproc0);

pdbSlots = round(req.remainingPDB_ms * cfg.slotsPerMs);
T2 = pdbSlots;

Sres = res(:)';                    % 1 x 2, same layout as S_total rows
tf = false;
prioRxBest = NaN;

for r = recs
    Th = cfg.sl_Thres_RSRP_List_dBm(r.prio + (req.prioTx - 1) * 8) + ThOffset;
    if r.rsrp > Th
        hit = condCMask(Sres, r, req, cfg, slotMap, n, T2);
        if hit
            tf = true;
            prioRxBest = min(prioRxBest, r.prio);
            if isnan(prioRxBest), prioRxBest = r.prio; end
        end
    end
end
end
