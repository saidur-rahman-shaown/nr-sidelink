function slotMap = deriveLogicalSlots(cfg, nSlotsSim)
%deriveLogicalSlots Physical<->logical pool slot map, plus T'_max.
%SPEC: TS 38.214 8.1.7; TS 38.331 (sl-TimeResource-r16 bitmap semantics)
%
%   A slot belongs to the pool iff (Plan.md §4.2):
%     1. not an S-SSB slot,
%     2. usable per the TDD UL mask,
%     3. its position in the sl-TimeResource bitmap is 1, where the bitmap
%        advances only over slots that pass filters 1-2 and repeats.
%
%   Returns:
%     .isPool       1 x nSlotsSim logical (index = absSlot+1, absSlot 0-based)
%     .abs2logical  1 x nSlotsSim, 1-based logical index or NaN
%     .logical2abs  1 x nLogical, 0-based absolute slot numbers
%     .nLogical     count of pool slots in the simulation horizon
%     .TmaxPrime    pool slots within 10240 ms (computed over 10240 ms
%                   regardless of nSlotsSim)  -- feeds P'_rsvp (8.1.7)

isPool = poolMask(cfg, nSlotsSim);

slotMap.isPool      = isPool;
slotMap.logical2abs = find(isPool) - 1;              % 0-based abs slots
slotMap.nLogical    = numel(slotMap.logical2abs);
slotMap.abs2logical = nan(1, nSlotsSim);
slotMap.abs2logical(isPool) = 1:slotMap.nLogical;    % 1-based logical idx

% T'_max over exactly 10240 ms, independent of simulation length
n10240 = 10240 * cfg.slotsPerMs;
slotMap.TmaxPrime = nnz(poolMask(cfg, n10240));

assert(slotMap.nLogical > 0, 'deriveLogicalSlots:emptyPool', ...
    'Pool configuration yields no sidelink slots.');
end

function isPool = poolMask(cfg, nSlots)
bitmap = logical(cfg.sl_TimeResource_r16(:)');
tdd    = logical(cfg.tdd_ULSlotMask(:)');
Lb = numel(bitmap);
Lt = numel(tdd);

isPool = false(1, nSlots);
bmIdx  = 0;                                  % bitmap cursor over candidates
for n = 0:nSlots-1
    if ~isempty(cfg.sssb_SlotsInPeriod) && ...
            any(mod(n, cfg.sssb_Period_slots) == cfg.sssb_SlotsInPeriod)
        continue;                            % S-SSB slot: not a pool candidate
    end
    if ~tdd(mod(n, Lt) + 1)
        continue;                            % not a sidelink-capable slot
    end
    bmIdx = bmIdx + 1;                       % bitmap advances over candidates
    if bitmap(mod(bmIdx - 1, Lb) + 1)
        isPool(n + 1) = true;
    end
end
end
