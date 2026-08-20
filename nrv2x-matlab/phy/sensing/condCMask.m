function mask = condCMask(S_total, rec, req, cfg, slotMap, n, T2)
%condCMask Step-6 condition (c): two-sided periodic overlap test.
%SPEC: TS 38.214 8.1.4 step 6c, 8.1.5 (resources set by an SCI), 8.1.7
%
%   Returns logical Mx1: true where candidate S_total(i,:) = [yLog, x]
%   is excluded by the (real or hypothetical) SCI record `rec`.
%
%   Sensed side : the SCI's own resources — its slot PLUS the same-TB
%                 TRIV-chained resources, EACH WITH ITS OWN start
%                 sub-channel (SCI-1A's FRIV is per-resource) — recurring
%                 q = 1..Q iff the reservation period is present.
%   Own side    : OUR candidate repeats j = 0..C_resel-1 at P'_rsvp_TX.
%
%   rec fields: log, startSub, L, Prsvp (ms),
%               trivLog = K x 2 [logSlot, startSub] chained resources.
%   req fields: LsubCH, PrsvpTx_ms, Cresel.

M = size(S_total, 1);
mask = false(M, 1);

% --- per-resource occupied entries: [logSlot, freqLo, freqHi] ----------
ent = [rec.log, rec.startSub, rec.startSub + rec.L - 1];
if ~isempty(rec.trivLog)
    ent = [ent; rec.trivLog(:, 1), rec.trivLog(:, 2), ...
                rec.trivLog(:, 2) + rec.L - 1];
end

% --- sensed-side recurrence count Q ------------------------------------
Q = 1;
Pp_rx = 0;
if rec.Prsvp > 0
    Pp_rx    = prsvpToLogical(rec.Prsvp, slotMap);
    Tscal_ms = T2 / cfg.slotsPerMs;          % T2 converted to msec
    nPrime   = nextPoolLogical(slotMap, n);
    % Q formula incl. the n'-m <= P'_rsvp_RX guard.
    % NOTE (unit quirk): note 06 writes Q = ceil(T_scal / P'_rsvp_RX) with
    % T_scal in ms and P' in logical slots. Implemented here as ms/ms
    % (Q = ceil(T_scal / P_rsvp_RX)) which is dimensionally consistent;
    % %TODO verify against 38214-gh0.pdf p.161 before M4 sign-off.
    if rec.Prsvp < Tscal_ms && (nPrime - rec.log) <= Pp_rx
        Q = ceil(Tscal_ms / rec.Prsvp);
    end
end

% --- own-side repetition -----------------------------------------------
if req.PrsvpTx_ms > 0
    Pp_tx = prsvpToLogical(req.PrsvpTx_ms, slotMap);
    jMax  = req.Cresel - 1;
else
    Pp_tx = 0;
    jMax  = 0;                               % C_resel = 1 when aperiodic
end

candLo = S_total(:, 2);
candHi = S_total(:, 2) + req.LsubCH - 1;

for e = 1:size(ent, 1)
    freqHit = candLo <= ent(e, 3) & candHi >= ent(e, 2);
    if ~any(freqHit)
        continue;
    end
    occSlots = ent(e, 1);                    % q = 0: the resource itself
    if rec.Prsvp > 0
        occSlots = [occSlots, ent(e, 1) + (1:Q) * Pp_rx]; %#ok<AGROW>
    end
    % candidate y is excluded if y + j*P'_tx lands on an occupied slot
    for s = occSlots
        for j = 0:jMax
            yNeeded = s - j * Pp_tx;
            if yNeeded < 1, break; end       % j grows -> yNeeded shrinks
            mask = mask | (S_total(:, 1) == yNeeded & freqHit);
            if Pp_tx == 0, break; end
        end
    end
end
end
