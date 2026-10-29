function test_dmrsEstimate()
%test_dmrsEstimate phy.rx.ce.dmrsEstimate's noise estimate, scalar and per block.
%SPEC: none -- non-normative receiver. +phy/+rx/CLAUDE.md: no bit-exactness here; the test is the
%      estimate against the known truth of a synthetic grid.
%Three sub-channels of 10 PRB, comb DM-RS on two symbols, flat unit channel, noise variance
%sigma2 everywhere and an interferer of power 100*sigma2 on the middle sub-channel only -- the
%partial collision the per-block option exists for.

rs = RandStream('mt19937ar', 'Seed', 5);
SC_PER_SUBCH = 120;
nSc = 3 * SC_PER_SUBCH;
kP = (0:2:nSc - 1)';                                  % comb pilots
dmrsInd = [kP, 3 * ones(size(kP)); kP, 8 * ones(size(kP))];
kD = (0:nSc - 1)';
dataInd = [kD, 5 * ones(size(kD))];
ref = exp(1j * pi / 2 * floor(4 * rand(rs, size(dmrsInd, 1), 1)));
sigma2 = 0.01;
n = sqrt(sigma2 / 2) * (randn(rs, size(ref)) + 1j * randn(rs, size(ref)));
hit = dmrsInd(:, 1) >= SC_PER_SUBCH & dmrsInd(:, 1) < 2 * SC_PER_SUBCH;
n(hit) = n(hit) + sqrt(100 * sigma2 / 2) * (randn(rs, nnz(hit), 1) + 1j * randn(rs, nnz(hit), 1));
rx = ref + n;

% ---- default: one scalar, unchanged behaviour (the LLS and its BLER table depend on it) -----
[h, nv] = phy.rx.ce.dmrsEstimate(rx, ref, dmrsInd, dataInd, nSc);
assert(isscalar(nv) && numel(h) == nSc, 'without groupSc the variance is one scalar');
assert(nv > 10 * sigma2, 'the scalar is pulled up by the collided third: %.3g vs sigma2 %.3g', nv, sigma2);

% ---- per sub-channel: the collided block is flagged, the clean ones are not -----------------
[~, nvB] = phy.rx.ce.dmrsEstimate(rx, ref, dmrsInd, dataInd, nSc, SC_PER_SUBCH);
assert(isequal(size(nvB), [nSc 1]), 'per data RE');
blk = floor(kD / SC_PER_SUBCH);
clean = nvB(blk ~= 1); dirty = nvB(blk == 1);
assert(all(abs(clean / sigma2 - 1) < 0.35), 'clean blocks estimate sigma2 to within 35%%');
assert(all(abs(dirty / (101 * sigma2) - 1) < 0.35), 'the collided block estimates noise + interference');
assert(min(dirty) > 30 * max(clean), 'so its LLRs are scaled down by more than an order of magnitude');

% ---- argument check -------------------------------------------------------------------------
try
    phy.rx.ce.dmrsEstimate(rx, ref, dmrsInd, dataInd, nSc, 1);
    error('test:noRaise', 'groupSc = 1 must be rejected');
catch e
    assert(strcmp(e.identifier, 'rx:ce:dmrsEstimate:badGroup'), 'wrong error %s', e.identifier);
end
fprintf('test_dmrsEstimate: all assertions passed.\n');
end
