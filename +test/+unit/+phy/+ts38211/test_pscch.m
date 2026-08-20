function test_pscch()
%test_pscch Unit tests for the PSCCH channel: slPSCCHDMRS(Indices),
%slPSCCHConfig, slPSCCH, slPSCCHIndices.
%SPEC: TS 38.211 V16.10.0 clause 8.3.2 (channel), clause 8.4.1.3 (DM-RS)

%% slPSCCHDMRS
r = phy.ts38211.slPSCCHDMRS(12345, 1, 3, 14, 5);
assert(numel(r) == 15 && iscolumn(r), 'slPSCCHDMRS: wrong shape');
assert(abs(mean(abs(r).^2) - 1) < 1e-9, 'slPSCCHDMRS: not unit power (QPSK)');

%% slPSCCHDMRSIndices
ind = phy.ts38211.slPSCCHDMRSIndices(10, 5, [1 2]);
assert(isequal(size(ind), [30 2]), 'slPSCCHDMRSIndices: wrong size');
k1 = ind(ind(:,2) == 1, 1);
expectedK = sort(reshape(repmat((0:4)'*12, 1, 3) + [1 5 9], [], 1)) + 10*12;
assert(isequal(sort(k1), expectedK), 'slPSCCHDMRSIndices: k pattern does not match offsets {1,5,9} mod 12');

%% slPSCCHConfig
pool = struct('sl_DMRS_ScrambleID_r16_Present', true, 'sl_DMRS_ScrambleID_r16', 999);
dyn = struct('startPRB', 10, 'NRB', 5, 'symbols', [1 2], 'nsf', 3, 'NsymbSlot', 14);
cfg = phy.ts38211.slPSCCHConfig(pool, dyn);
assert(cfg.DMRS_NID == 999 && cfg.startPRB == 10 && cfg.NRB == 5, 'slPSCCHConfig: field mismatch');

%% slPSCCH
carrier = struct();
bits = randi([0 1], 60, 1);
d = phy.ts38211.slPSCCH(carrier, cfg, bits);
assert(numel(d) == 30 && iscolumn(d), 'slPSCCH: wrong output length');
assert(abs(mean(abs(d).^2) - 1) < 1e-9, 'slPSCCH: not unit power (QPSK)');

%% slPSCCHIndices
indData = phy.ts38211.slPSCCHIndices(carrier, cfg);
expectedRows = 5*12*2 - 30;   % NRB*12*nSym - DM-RS REs
assert(size(indData, 1) == expectedRows, 'slPSCCHIndices: wrong RE count');
overlap = intersect(indData(:,1) + 1i*indData(:,2), ind(:,1) + 1i*ind(:,2));
assert(isempty(overlap), 'slPSCCHIndices: overlaps with DM-RS');

fprintf('test_pscch: PASS\n');
end
