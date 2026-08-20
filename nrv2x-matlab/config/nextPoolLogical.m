function nPrime = nextPoolLogical(slotMap, nAbs)
%nextPoolLogical Logical index t'_n' of slot n.
%SPEC: TS 38.214 8.1.4 step 6c —
%   t'_n' = n if slot n belongs to the pool, else the first pool slot after n.

nAbs = max(0, nAbs);
if nAbs + 1 <= numel(slotMap.abs2logical) && ~isnan(slotMap.abs2logical(nAbs + 1))
    nPrime = slotMap.abs2logical(nAbs + 1);
    return;
end
idx = find(slotMap.logical2abs > nAbs, 1, 'first');
assert(~isempty(idx), 'nextPoolLogical:beyondHorizon', ...
    'No pool slot at or after abs slot %d within the simulation horizon.', nAbs);
nPrime = idx;
end
