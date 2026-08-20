function test_psschMapping()
%test_psschMapping Unit tests for PSSCH layer mapping and resource mapping:
%slLayerMap, slPSSCHDMRSIndices, slPSSCHIndices.
%SPEC: TS 38.211 V16.10.0 clause 7.3.1.3 (layer mapping, via 8.3.1.3),
%      clause 6.4.1.1.3 (DM-RS RE-mapping template, via 8.4.1.1.2),
%      clause 8.3.1.5 (VRB mapping, two-step)

%% slLayerMap
d = (1:10)' + 1i*(11:20)';
x1 = phy.ts38211.slLayerMap(d, 1);
assert(isequal(x1, d), 'slLayerMap: nu=1 must be pass-through');

x2 = phy.ts38211.slLayerMap(d, 2);
assert(isequal(size(x2), [5 2]), 'slLayerMap: nu=2 wrong shape');
assert(isequal(x2(:,1), d(1:2:end)) && isequal(x2(:,2), d(2:2:end)), 'slLayerMap: nu=2 not even/odd demux');

try
    phy.ts38211.slLayerMap((1:9)', 2);
    error('test_psschMapping:shouldHaveErrored', 'slLayerMap should reject odd length for nu=2');
catch e
    assert(strcmp(e.identifier, 'ts38211:slLayerMap:oddLength'), 'slLayerMap: wrong error for odd length');
end
try
    phy.ts38211.slLayerMap(d, 3);
    error('test_psschMapping:shouldHaveErrored', 'slLayerMap should reject nu=3 (sidelink PSSCH is single-codeword, nu in {1,2} only)');
catch e
    assert(strcmp(e.identifier, 'ts38211:slLayerMap:badNu'), 'slLayerMap: wrong error for nu=3');
end

%% slPSSCHDMRSIndices
indDmrs = phy.ts38211.slPSSCHDMRSIndices(10, 5, [1 5]);
assert(isequal(size(indDmrs), [60 2]), 'slPSSCHDMRSIndices: wrong size');   % 6*NRB=30 per symbol * 2 symbols
k1 = sort(indDmrs(indDmrs(:,2) == 1, 1));
expectedK = sort(reshape(4*(0:14)' + [0 2], [], 1)) + 10*12;
assert(isequal(k1, expectedK), 'slPSSCHDMRSIndices: k pattern does not match k=4n+2k'' template');

%% slPSSCHIndices -- full two-step VRB mapping
startPRB = 10; NRB = 5; ld = 6; dmrsSymbols = [1 5]; Msymb1 = 4;
dmrsRE = phy.ts38211.slPSSCHDMRSIndices(startPRB, NRB, dmrsSymbols);
cfg = struct('startPRB', startPRB, 'NRB', NRB, 'ld', ld, 'dmrsSymbols', dmrsSymbols, ...
    'Msymb1', Msymb1, 'pscchRE', [], 'ptrsRE', [], 'csirsRE', []);
carrier = struct();
ind = phy.ts38211.slPSSCHIndices(carrier, cfg);

totalGrid = 5*NRB*12;   % symbols 1..5, NRB*12 subcarriers each
expectedTotal = totalGrid - size(dmrsRE, 1);
assert(size(ind, 1) == expectedTotal, 'slPSSCHIndices: wrong total RE count');
assert(~any(ismember(ind, dmrsRE, 'rows')), 'slPSSCHIndices: overlaps with DM-RS');

sci2 = ind(1:Msymb1, :);
assert(all(sci2(:,2) == 1), 'slPSSCHIndices: SCI-2 portion should start at the first DM-RS symbol');

[~, ia] = unique(ind, 'rows', 'stable');
assert(numel(ia) == size(ind, 1), 'slPSSCHIndices: duplicate REs in output');

allK = (startPRB*12 : startPRB*12+NRB*12-1)';
fullGrid = [repmat(allK, 5, 1), repelem((1:5)', NRB*12)];
combined = [ind; dmrsRE];
assert(size(combined, 1) == size(fullGrid, 1), 'slPSSCHIndices+DMRS: wrong total tile count');
assert(isempty(setxor(combined(:,1) + 1i*combined(:,2), fullGrid(:,1) + 1i*fullGrid(:,2))), ...
    'slPSSCHIndices+DMRS: does not exactly tile the allocation');

% PSCCH exclusion (k relative-offset 1,3 are odd, never DM-RS positions, so genuinely new exclusions)
pscchRE = [startPRB*12+1, 1; startPRB*12+3, 1];
cfg2 = cfg; cfg2.pscchRE = pscchRE;
ind2 = phy.ts38211.slPSSCHIndices(carrier, cfg2);
assert(~any(ismember(ind2, pscchRE, 'rows')), 'slPSSCHIndices: PSCCH exclusion not respected');
assert(size(ind2, 1) == expectedTotal - 2, 'slPSSCHIndices: wrong count after PSCCH exclusion');

% dataStartIdx
cfg3 = cfg; cfg3.dataStartIdx = 3;
ind3 = phy.ts38211.slPSSCHIndices(carrier, cfg3);
assert(size(ind3, 1) == expectedTotal - 3, 'slPSSCHIndices: dataStartIdx did not skip REs as expected');

% insufficient REs for the requested SCI-2 symbol count
cfgBad = cfg; cfgBad.Msymb1 = 10000;
try
    phy.ts38211.slPSSCHIndices(carrier, cfgBad);
    error('test_psschMapping:shouldHaveErrored', 'slPSSCHIndices should reject an impossible Msymb1');
catch e
    assert(strcmp(e.identifier, 'ts38211:slPSSCHIndices:notEnoughSCI2REs'), 'slPSSCHIndices: wrong error for impossible Msymb1');
end

fprintf('test_psschMapping: PASS\n');
end
