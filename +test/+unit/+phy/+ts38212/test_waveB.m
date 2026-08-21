function test_waveB()
%test_waveB Unit tests for +phy/+ts38212/ Wave B: trivEncode/trivDecode, frivEncode/frivDecode,
%sci1aPack/sci1aUnpack, sci2aPack/sci2aUnpack, sci2bPack/sci2bUnpack, mibSlPack/mibSlUnpack.
%SPEC: TS 38.212 V16.15.0 clause 8.3.1.1 (SCI-1A), clause 8.4.1.1 (SCI-2A), clause 8.4.1.2
%      (SCI-2B); TS 38.214 V16.17.0 clause 8.1.5 (TRIV/FRIV); TS 38.331 V16.22.0
%      MasterInformationBlockSidelink (MIB-SL)
%
%TRIV/FRIV are checked by exhaustive round trip over their entire legal space (both are small
%enumerable spaces -- computed and printed below). SCI-1A/2A/2B/MIB-SL are checked by
%pack/unpack round trip across a representative sweep of pool configs, plus illegal-input
%rejection and total-length structural assertions. This is hand-written normative code with no
%toolbox to cross-check against -- see +phy/+ts38212/CLAUDE.md's Tests section: an
%independent-verifier pass on SCI-1A's field table and the TRIV/FRIV formulas is still required
%before this is considered vector-freeze-ready, this file alone does not close that out.

%% TRIV exhaustive round trip
n2 = 0;
for t1 = 1:31
    [triv, w] = phy.ts38212.trivEncode(2, t1, 0, 2);
    assert(w == 5, 'trivEncode: wrong width for maxReserve=2');
    [N, dt1, dt2] = phy.ts38212.trivDecode(triv, 2);
    assert(N == 2 && dt1 == t1 && dt2 == 0, 'TRIV round trip failed at maxReserve=2, t1=%d', t1);
    n2 = n2 + 1;
end
[triv1, ~] = phy.ts38212.trivEncode(1, 0, 0, 2);
[N1, ~, ~] = phy.ts38212.trivDecode(triv1, 2);
assert(triv1 == 0 && N1 == 1, 'TRIV N=1 case failed');

n3 = 0;
seenTriv = false(1, 512);
for t1 = 1:30
    for t2 = (t1 + 1):31
        [triv, w] = phy.ts38212.trivEncode(3, t1, t2, 3);
        assert(w == 9, 'trivEncode: wrong width for maxReserve=3');
        assert(~seenTriv(triv + 1), 'TRIV collision at t1=%d t2=%d triv=%d', t1, t2, triv);
        seenTriv(triv + 1) = true;
        [N, dt1, dt2] = phy.ts38212.trivDecode(triv, 3);
        assert(N == 3 && dt1 == t1 && dt2 == t2, 'TRIV round trip failed at maxReserve=3, t1=%d t2=%d', t1, t2);
        n3 = n3 + 1;
    end
end
fprintf('TRIV: maxReserve=2 space size = %d, maxReserve=3 space size = %d, all round-trip and unique\n', n2 + 1, n3 + 1);

try
    phy.ts38212.trivEncode(2, 32, 0, 2);
    error('test_waveB:shouldHaveErrored', 'trivEncode should reject t1=32 at maxReserve=2');
catch e
    assert(strcmp(e.identifier, 'ts38212:trivEncode:badT1'), 'trivEncode: wrong error for illegal t1');
end

%% FRIV worked examples (independent-verifier, spec-derived, never saw this code)
[friv1, w1] = phy.ts38212.frivEncode(3, 0, 1, 10, 2);
assert(friv1 == 3 && w1 == 6, 'FRIV worked example (maxReserve=2) failed: got friv=%d bits=%d', friv1, w1);
[friv2, w2] = phy.ts38212.frivEncode(3, 6, 2, 10, 3);
assert(friv2 == 157 && w2 == 9, 'FRIV worked example (maxReserve=3, squared summand) failed: got friv=%d bits=%d, expected 157/9 -- this is the exact case that catches a dropped exponent in the maxReserve=3 formula', friv2, w2);
[friv3, w3] = phy.ts38212.frivEncode(0, 0, 1, 1, 2);
assert(friv3 == 0 && w3 == 0, 'FRIV worked example (Nsub=1 degenerate) failed: got friv=%d bits=%d', friv3, w3);

%% FRIV exhaustive round trip (representative Nsub/maxReserve/L sweep)
frivSpace = 0;
for Nsub = [1, 3, 10, 27]
    for maxReserve = [2, 3]
        for L = 1:min(3, Nsub)
            w = phy.ts38212.frivBitWidth(Nsub, maxReserve);
            for nStart1 = 0:(Nsub - L)
                if maxReserve == 2
                    [friv, fw] = phy.ts38212.frivEncode(nStart1, 0, L, Nsub, maxReserve);
                    assert(fw == w, 'frivEncode: width mismatch');
                    [dn1, ~] = phy.ts38212.frivDecode(friv, L, Nsub, maxReserve);
                    assert(dn1 == nStart1, 'FRIV round trip failed (maxReserve=2) Nsub=%d L=%d nStart1=%d', Nsub, L, nStart1);
                    frivSpace = frivSpace + 1;
                else
                    for nStart2 = 0:(Nsub - L)
                        [friv, ~] = phy.ts38212.frivEncode(nStart1, nStart2, L, Nsub, maxReserve);
                        [dn1, dn2] = phy.ts38212.frivDecode(friv, L, Nsub, maxReserve);
                        assert(dn1 == nStart1 && dn2 == nStart2, 'FRIV round trip failed (maxReserve=3) Nsub=%d L=%d n1=%d n2=%d', Nsub, L, nStart1, nStart2);
                        frivSpace = frivSpace + 1;
                    end
                end
            end
        end
    end
end
fprintf('FRIV: swept %d (Nsub,maxReserve,L,nStart) combinations, all round-trip\n', frivSpace);

try
    phy.ts38212.frivEncode(100, 0, 1, 10, 2);
    error('test_waveB:shouldHaveErrored', 'frivEncode should reject nStart1 beyond Nsub-L');
catch e
    assert(strcmp(e.identifier, 'ts38212:frivEncode:badNStart1'), 'frivEncode: wrong error for illegal nStart1');
end

%% SCI-1A round trip across a pool-config sweep
sci1aSpace = 0;
for Nsub = [3, 10]
    for maxReserve = [2, 3]
        for multiReserve = [false, true]
            for nDmrsPatterns = [1, 3]
                for addMcsLabel = {'', 'qam256', 'qam256-qam64LowSE'}
                    for psfchPeriod = [0, 2]
                        pool = testPool(Nsub, maxReserve, multiReserve, nDmrsPatterns, addMcsLabel{1}, psfchPeriod);
                        dp = testSci1aParams(pool);
                        bits = phy.ts38212.sci1aPack(pool, dp);
                        expectedLen = 3 + phy.ts38212.frivBitWidth(Nsub, maxReserve) + phy.ts38212.trivBitWidth(maxReserve) + ...
                            (multiReserve) * ceil(log2(2)) + ceil(log2(nDmrsPatterns)) + 2 + 2 + 1 + 5 + ...
                            phy.ts38212.additionalMcsTableWidth(addMcsLabel{1}) + (psfchPeriod == 2 || psfchPeriod == 4) + pool.sl_PSCCH_Config_r16.sl_NumReservedBits_r16;
                        assert(numel(bits) == expectedLen, 'sci1aPack: length mismatch, got %d expected %d', numel(bits), expectedLen);
                        back = phy.ts38212.sci1aUnpack(bits, pool);
                        assert(isequal(back.priority, dp.priority), 'sci1a round trip: priority');
                        assert(isequal(back.friv, dp.friv), 'sci1a round trip: friv');
                        assert(isequal(back.triv, dp.triv), 'sci1a round trip: triv');
                        assert(isequal(back.dmrsPatternIndex, dp.dmrsPatternIndex), 'sci1a round trip: dmrsPatternIndex');
                        assert(isequal(back.sci2Format, dp.sci2Format), 'sci1a round trip: sci2Format');
                        assert(isequal(back.betaOffsetIndex, dp.betaOffsetIndex), 'sci1a round trip: betaOffsetIndex');
                        assert(isequal(back.numDmrsPort, dp.numDmrsPort), 'sci1a round trip: numDmrsPort');
                        assert(isequal(back.mcs, dp.mcs), 'sci1a round trip: mcs');
                        if multiReserve
                            assert(isequal(back.reservationPeriodIndex, dp.reservationPeriodIndex), 'sci1a round trip: reservationPeriodIndex');
                        end
                        if phy.ts38212.additionalMcsTableWidth(addMcsLabel{1}) > 0
                            assert(isequal(back.additionalMcsTableIndex, dp.additionalMcsTableIndex), 'sci1a round trip: additionalMcsTableIndex');
                        end
                        if psfchPeriod == 2 || psfchPeriod == 4
                            assert(isequal(back.psfchOverhead, dp.psfchOverhead), 'sci1a round trip: psfchOverhead');
                        end
                        sci1aSpace = sci1aSpace + 1;
                    end
                end
            end
        end
    end
end
fprintf('SCI-1A: round-tripped %d pool-config combinations\n', sci1aSpace);

try
    poolBad = testPool(10, 2, false, 1, '', 0);
    dpBad = testSci1aParams(poolBad);
    dpBad.priority = 9;
    phy.ts38212.sci1aPack(poolBad, dpBad);
    error('test_waveB:shouldHaveErrored', 'sci1aPack should reject priority=9');
catch e
    assert(strcmp(e.identifier, 'ts38212:sci1aPack:badPriority'), 'sci1aPack: wrong error for illegal priority');
end

%% SCI-2A round trip
dp2a.harqProcessNumber = 5; dp2a.ndi = 1; dp2a.rv = 2; dp2a.sourceID = 200; dp2a.destinationID = 5000;
dp2a.harqFeedbackEnabled = 1; dp2a.castType = 2; dp2a.csiRequest = 0;
bits2a = phy.ts38212.sci2aPack(dp2a);
assert(numel(bits2a) == 35, 'sci2aPack: expected 35 bits, got %d', numel(bits2a));
back2a = phy.ts38212.sci2aUnpack(bits2a);
assert(isequal(back2a, dp2a), 'sci2a round trip failed');

try
    dpBad2a = dp2a; dpBad2a.destinationID = 70000;
    phy.ts38212.sci2aPack(dpBad2a);
    error('test_waveB:shouldHaveErrored', 'sci2aPack should reject destinationID=70000');
catch e
    assert(strcmp(e.identifier, 'ts38212:sci2aPack:badDestinationID'), 'sci2aPack: wrong error for illegal destinationID');
end

%% SCI-2B round trip
dp2b.harqProcessNumber = 3; dp2b.ndi = 0; dp2b.rv = 1; dp2b.sourceID = 10; dp2b.destinationID = 60000;
dp2b.harqFeedbackEnabled = 0; dp2b.zoneID = 4000; dp2b.commRangeRequirement = 9;
bits2b = phy.ts38212.sci2bPack(dp2b);
assert(numel(bits2b) == 48, 'sci2bPack: expected 48 bits, got %d', numel(bits2b));
back2b = phy.ts38212.sci2bUnpack(bits2b);
assert(isequal(back2b, dp2b), 'sci2b round trip failed');

%% MIB-SL round trip
dpMib.tddConfig = logical(randi([0 1], 12, 1));
dpMib.inCoverage = 1;
dpMib.directFrameNumber = 777;
dpMib.slotIndex = 42;
dpMib.reservedBits = false(2, 1);
bitsMib = phy.ts38212.mibSlPack(dpMib);
assert(numel(bitsMib) == 32, 'mibSlPack: expected 32 bits, got %d', numel(bitsMib));
backMib = phy.ts38212.mibSlUnpack(bitsMib);
assert(isequal(backMib.tddConfig, dpMib.tddConfig), 'mibSl round trip: tddConfig');
assert(isequal(backMib.inCoverage, dpMib.inCoverage), 'mibSl round trip: inCoverage');
assert(isequal(backMib.directFrameNumber, dpMib.directFrameNumber), 'mibSl round trip: directFrameNumber');
assert(isequal(backMib.slotIndex, dpMib.slotIndex), 'mibSl round trip: slotIndex');
assert(isequal(backMib.reservedBits, dpMib.reservedBits), 'mibSl round trip: reservedBits');

try
    phy.ts38212.mibSlPack(struct('tddConfig', false(12,1), 'inCoverage', 0, ...
        'directFrameNumber', 1024, 'slotIndex', 0, 'reservedBits', false(2,1)));
    error('test_waveB:shouldHaveErrored', 'mibSlPack should reject directFrameNumber=1024');
catch e
    assert(strcmp(e.identifier, 'ts38212:mibSlPack:badDfn'), 'mibSlPack: wrong error for illegal directFrameNumber');
end

fprintf('test_waveB: PASS\n');
end

function pool = testPool(Nsub, maxReserve, multiReserve, nDmrsPatterns, addMcsLabel, psfchPeriod)
%testPool Hand-built resourcePool.m-shaped struct exercising only the fields Wave B reads.
%Field names/shape match +cfg/resourcePool.m's documented output exactly (read in full while
%designing this test) -- built directly rather than via cfg.resourcePool(raw) so this test
%exercises the +phy/+ts38212/ contract in isolation from +cfg/'s own JSON-decoding, which has
%its own test coverage per +cfg/CLAUDE.md's Gate.
pool.sl_NumSubchannel_r16 = Nsub;
pool.sl_NumSubchannel_r16_Present = true;

pool.sl_UE_SelectedConfigRP_r16_Present = true;
pool.sl_UE_SelectedConfigRP_r16.sl_MaxNumPerReserve_r16 = maxReserve;
pool.sl_UE_SelectedConfigRP_r16.sl_MultiReserveResource_r16 = multiReserve;
if multiReserve
    pool.sl_UE_SelectedConfigRP_r16.sl_ResourceReservePeriodList_r16 = repmat(struct('case', 'sl-ResourceReservePeriod2-r16', 'sl_ResourceReservePeriod_ms', 20), 1, 2);
else
    pool.sl_UE_SelectedConfigRP_r16.sl_ResourceReservePeriodList_r16 = repmat(struct('case', 'sl-ResourceReservePeriod2-r16', 'sl_ResourceReservePeriod_ms', 20), 1, 0);
end

pool.sl_PSCCH_Config_r16_Present = true;
pool.sl_PSCCH_Config_r16.sl_NumReservedBits_r16 = 2;

pool.sl_PSSCH_Config_r16_Present = true;
pool.sl_PSSCH_Config_r16.sl_PSSCH_DMRS_TimePatternList_r16 = 2 * ones(1, nDmrsPatterns);
pool.sl_PSSCH_Config_r16.sl_BetaOffsets2ndSCI_r16 = [1 2 3 4];

pool.sl_PSFCH_Config_r16_Present = true;
pool.sl_PSFCH_Config_r16.sl_PSFCH_Period_r16 = psfchPeriod;

pool.sl_Additional_MCS_Table_r16 = addMcsLabel;
end

function dp = testSci1aParams(pool)
%testSci1aParams A representative, self-consistent set of SCI-1A dynamicParams for testPool.
Nsub = pool.sl_NumSubchannel_r16;
maxReserve = pool.sl_UE_SelectedConfigRP_r16.sl_MaxNumPerReserve_r16;
dp.priority = 3;
[dp.friv, ~] = phy.ts38212.frivEncode(min(1, Nsub - 1), 0, 1, Nsub, maxReserve);
[dp.triv, ~] = phy.ts38212.trivEncode(1, 0, 0, maxReserve);
dp.reservationPeriodIndex = 0;
dp.dmrsPatternIndex = 0;
dp.sci2Format = 'A';
dp.betaOffsetIndex = 2;
dp.numDmrsPort = 1;
dp.mcs = 9;
dp.additionalMcsTableIndex = 0;
dp.psfchOverhead = 1;
end
