function [counter, Cresel] = creselDraw(Prsvp_ms, rs)
%creselDraw Draw SL_RESOURCE_RESELECTION_COUNTER and derive C_resel.
%SPEC: TS 38.321 5.22.1.1 (counter ranges); TS 38.214 8.1.5 (C_resel)
%
%   P_rsvp_TX >= 100 ms :  counter ~ U[5, 15]
%   P_rsvp_TX <  100 ms :  counter ~ U[5k, 15k], k = ceil(100/max(20, P))
%   C_resel = 10 * counter (periodic), else 1.
%
%   rs — RandStream (reproducibility, Plan.md §8.4).

if Prsvp_ms <= 0
    counter = 0;                 % aperiodic: no SPS counter
    Cresel  = 1;                 % 8.1.5: C_resel = 1 when not configured
    return;
end

if Prsvp_ms >= 100
    lo = 5;  hi = 15;
else
    k  = ceil(100 / max(20, Prsvp_ms));
    lo = 5 * k;  hi = 15 * k;
end

counter = randi(rs, [lo, hi]);
Cresel  = 10 * counter;
end
