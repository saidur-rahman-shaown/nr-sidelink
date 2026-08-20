function test_psbch()
%test_psbch Unit tests for the PSBCH channel: slPSBCHDMRS(Indices),
%slPSBCHIndices, slPSBCHConfig, slPSBCH.
%SPEC: TS 38.211 V16.10.0 clause 8.3.3 (channel), clause 8.4.1.4 (DM-RS),
%      clause 8.4.3.1 Table 8.4.3.1-1 (S-SS/PSBCH block RE mapping)

Nsymb = 13;    % normal CP
NIDSL = 555;

%% slPSBCHDMRS
r = phy.ts38211.slPSBCHDMRS(NIDSL, Nsymb);
assert(numel(r) == 33*9 && iscolumn(r), 'slPSBCHDMRS: wrong shape');
assert(abs(mean(abs(r).^2) - 1) < 1e-9, 'slPSBCHDMRS: not unit power (QPSK)');

%% slPSBCHDMRSIndices / slPSBCHIndices -- structural tiling check
indD = phy.ts38211.slPSBCHDMRSIndices(Nsymb);
assert(isequal(size(indD), [297 2]), 'slPSBCHDMRSIndices: wrong size');
assert(isequal(unique(indD(:,2))', [0 5 6 7 8 9 10 11 12]), 'slPSBCHDMRSIndices: wrong symbol set');
assert(isequal(unique(indD(:,1))', 0:4:128), 'slPSBCHDMRSIndices: wrong subcarrier set');

indB = phy.ts38211.slPSBCHIndices(Nsymb);
assert(isequal(size(indB), [891 2]), 'slPSBCHIndices: wrong size');
overlap = intersect(indD(:,1) + 1i*indD(:,2), indB(:,1) + 1i*indB(:,2));
assert(isempty(overlap), 'slPSBCHIndices: overlaps with DM-RS');
allCombined = union(indD(:,1) + 1i*indD(:,2), indB(:,1) + 1i*indB(:,2));
assert(numel(allCombined) == 132*9, 'slPSBCHIndices+DMRS: does not exactly tile the S-SS/PSBCH block');

%% slPSBCHConfig
cfg = phy.ts38211.slPSBCHConfig(NIDSL, Nsymb);
assert(cfg.NIDSL == NIDSL && cfg.Nsymb == Nsymb, 'slPSBCHConfig: field mismatch');
try
    phy.ts38211.slPSBCHConfig(700, Nsymb);
    error('test_psbch:shouldHaveErrored', 'slPSBCHConfig should reject NIDSL=700');
catch e
    assert(strcmp(e.identifier, 'ts38211:slPSBCHConfig:badNIDSL'), 'slPSBCHConfig: wrong error for illegal NIDSL');
end

%% slPSBCH
carrier = struct();
bits = randi([0 1], 100, 1);
d = phy.ts38211.slPSBCH(carrier, cfg, bits);
assert(numel(d) == 50, 'slPSBCH: wrong output length');
assert(abs(mean(abs(d).^2) - 1) < 1e-9, 'slPSBCH: not unit power (QPSK)');

fprintf('test_psbch: PASS\n');
end
