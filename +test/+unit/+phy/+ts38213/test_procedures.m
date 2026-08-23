function test_procedures()
%test_procedures Unit tests for +phy/+ts38213/'s clause 16.1/16.3/16.4 procedures (clause 16.2
%is a deliberate simplification -- max-power-always, not the real open-loop formula).
%SPEC: TS 38.213 V16.17.0 clause 16.1 (sSsbSlotIndex, slTddConfigEncode/Decode), clause 16.2
%      (slPowerControl, simplified), clause 16.3/16.3.1 (psfchOccasionCheck, psfchTiming,
%      psfchPrbRange, psfchResource, psfchCyclicShiftM0/Mcs, harqAckCombine), clause 16.4
%      (reservationPeriodIndex, mode2ResourceSelect)
%
%Structural/shape assertions and round trips only at this stage -- per +test/CLAUDE.md level 2,
%an independent-verifier pass on the genuinely new hand-derived procedures (the clause 16.1
%TDD-config derivation, clause 16.3's PSFCH PRB-range/resource-index formulas and the m0/mcs
%table lookups, clause 16.4's Mode-2 resource-selection-to-TRIV/FRIV procedure) is still
%required before this is considered done -- see +phy/+ts38213/CLAUDE.md.

%% sSsbSlotIndex
assert(phy.ts38213.sSsbSlotIndex(2, 3, 0, 4) == 2, 'sSsbSlotIndex: iSSSB=0 case failed');
assert(phy.ts38213.sSsbSlotIndex(2, 3, 1, 4) == 6, 'sSsbSlotIndex: iSSSB=1 case failed');
try
    phy.ts38213.sSsbSlotIndex(0, 0, 4, 4);
    error('test_procedures:shouldHaveErrored', 'sSsbSlotIndex should reject iSSSB=Nperiod (out of range)');
catch e
    assert(strcmp(e.identifier, 'ts38213:sSsbSlotIndex:badISSSB'), 'sSsbSlotIndex: wrong error for out-of-range iSSSB');
end

%% slTddConfigEncode / slTddConfigDecode -- all-ones case
tddAllOnes = phy.ts38213.slTddConfigEncode(true, [], [], 0, 0, 'normal', 0);
assert(isequal(double(tddAllOnes), ones(12, 1)), 'slTddConfigEncode: allOnesCase should produce all ones');
infoAllOnes = phy.ts38213.slTddConfigDecode(tddAllOnes, 0);
assert(infoAllOnes.allOnesCase, 'slTddConfigDecode: should detect allOnesCase');

%% slTddConfigEncode / slTddConfigDecode -- pattern1 only
p1.P = 2; p1.uSlots = 3; p1.uSym = 5;
tdd1 = phy.ts38213.slTddConfigEncode(false, p1, [], 1, 0, 'normal', 10);
assert(numel(tdd1) == 12, 'slTddConfigEncode: expected 12 bits');
info1 = phy.ts38213.slTddConfigDecode(tdd1, 1);
assert(~info1.allOnesCase && ~info1.a0, 'slTddConfigDecode: pattern1-only should have a0=false');
assert(info1.P == 2, 'slTddConfigDecode: pattern1-only P mismatch, got %g', info1.P);
% Hand check: L=14 (normal CP); I1 = mod(5*2^1,14)>=14-10 -> mod(10,14)=10>=4 -> I1=1;
% uSlotsSL = 3*2^1 + floor(5*2^1/14) + 1 = 6+0+1 = 7.
assert(info1.uSlotsSL == 7, 'slTddConfigDecode: pattern1-only uSlotsSL expected 7, got %d', info1.uSlotsSL);

%% slTddConfigEncode / slTddConfigDecode -- pattern1+pattern2, exercises Table 16.1-2 row 1110
% (P=5,P2=5) whose granularity was verified by rendering the PDF page directly (pdftotext
% merges this table's cells in a way that is easy to misread -- see Known traps).
p1b.P = 5; p1b.uSlots = 2; p1b.uSym = 3;
p2b.P = 5; p2b.uSlots = 1; p2b.uSym = 4;
tdd2 = phy.ts38213.slTddConfigEncode(false, p1b, p2b, 2, 0, 'normal', 5);
info2 = phy.ts38213.slTddConfigDecode(tdd2, 2);
assert(info2.a0, 'slTddConfigDecode: pattern1+pattern2 should have a0=true');
assert(info2.P == 5 && info2.P2 == 5, 'slTddConfigDecode: P/P2 mismatch for row 1110');
assert(info2.w == 2, 'slTddConfigDecode: row 1110 at mu=2 (60kHz) expected w=2, got %d', info2.w);
% independent-verifier worked example: full uSlotsSL value, not just the table-lookup fields.
assert(info2.uSlotsSL == 26, 'slTddConfigDecode: row 1110 uSlotsSL expected 26, got %d', info2.uSlotsSL);
assert(isequal(sprintf('%d', double(tdd2)), '111100011010'), 'slTddConfigEncode: full 12-bit worked example mismatch for row 1110');

% independent-verifier: the two-pattern formula's ceiling term uses P*2^mu, NOT P*2^(mu-muRef)
% -- every other exponent in both formulas IS 2^(mu-muRef), so this is a genuine asymmetry, not
% a typo, and it is invisible whenever muRef=0 (as in every other case in this file, since then
% the two exponents coincide). This case uses muRef=1 specifically to discriminate them.
p1d.P = 10; p1d.uSlots = 15; p1d.uSym = 6;
p2d.P = 10; p2d.uSlots = 10; p2d.uSym = 10;
tddD = phy.ts38213.slTddConfigEncode(false, p1d, p2d, 3, 1, 'normal', 7);
infoD = phy.ts38213.slTddConfigDecode(tddD, 3);
assert(infoD.uSlotsSL == 62, 'slTddConfigDecode: mu-vs-(mu-muRef) discriminating case expected uSlotsSL=62, got %d (would be 37 with the wrong exponent)', infoD.uSlotsSL);

% independent-verifier: I1/I2 use ">=", not ">", at the L-Y boundary -- this case sits exactly
% at that boundary (uSym*2^(mu-muRef) mod L == L-Y).
p1e.P = 2; p1e.uSlots = 0; p1e.uSym = 7;
tddE = phy.ts38213.slTddConfigEncode(false, p1e, [], 0, 0, 'normal', 7);
infoE = phy.ts38213.slTddConfigDecode(tddE, 0);
assert(infoE.uSlotsSL == 1, 'slTddConfigDecode: I1 boundary case (">=" vs ">") expected uSlotsSL=1, got %d', infoE.uSlotsSL);

try
    badP1.P = 0.9; badP1.uSlots = 0; badP1.uSym = 0;
    phy.ts38213.slTddConfigEncode(false, badP1, [], 0, 0, 'normal', 0);
    error('test_procedures:shouldHaveErrored', 'slTddConfigEncode should reject an illegal P not in Table 16.1-1');
catch e
    assert(strcmp(e.identifier, 'ts38213:slTddConfigEncode:badP'), 'slTddConfigEncode: wrong error for illegal P');
end

%% slPowerControl -- simplified max-power-always policy, not clause 16.2's real formula
assert(phy.ts38213.slPowerControl('PSSCH', 23, -106, 0.8, 90, 1, 20) == 23, 'slPowerControl: should always return pCmax');
assert(phy.ts38213.slPowerControl('S-SSB', 10, 0, 0, 0, 0, 1) == 10, 'slPowerControl: should always return pCmax');
try
    phy.ts38213.slPowerControl('PDSCH', 23, -106, 0.8, 90, 1, 20);
    error('test_procedures:shouldHaveErrored', 'slPowerControl should reject an illegal channel name');
catch e
    assert(strcmp(e.identifier, 'ts38213:slPowerControl:badChannel'), 'slPowerControl: wrong error for illegal channel');
end

%% psfchOccasionCheck / psfchTiming
assert(phy.ts38213.psfchOccasionCheck(0, 4) == true, 'psfchOccasionCheck: k=0 should be an occasion');
assert(phy.ts38213.psfchOccasionCheck(4, 4) == true, 'psfchOccasionCheck: k=4 should be an occasion (period 4)');
assert(phy.ts38213.psfchOccasionCheck(2, 4) == false, 'psfchOccasionCheck: k=2 should not be an occasion (period 4)');
assert(phy.ts38213.psfchTiming(5, 2, 4) == 8, 'psfchTiming: expected first occasion at slot 8 (5+2=7, next multiple of 4 is 8), got %d', phy.ts38213.psfchTiming(5, 2, 4));

%% psfchPrbRange / psfchResource
[prbStart, prbEnd, MsubchSlot] = phy.ts38213.psfchPrbRange(1, 2, 60, 5, 4);
% MPrbSet=60, Nsubch=5, NPsschPsfch=4 -> MsubchSlot = 60/(5*4) = 3.
% i=1, j=2 -> prbStart = (1 + 2*4)*3 = 27; prbEnd = (1+1+2*4)*3-1 = 30*... let's just assert
% against the formula directly rather than a second hand-typed number.
assert(MsubchSlot == 3, 'psfchPrbRange: MsubchSlot expected 3, got %d', MsubchSlot);
assert(prbStart == (1 + 2 * 4) * 3, 'psfchPrbRange: prbStart mismatch');
assert(prbEnd == (1 + 1 + 2 * 4) * 3 - 1, 'psfchPrbRange: prbEnd mismatch');

% independent-verifier: PRB is the fastest-varying (inner) dimension, cyclic-shift-pair the
% slowest -- prbOffset = resourceIndex mod N_PRB, csPairIndex = floor(resourceIndex / N_PRB).
% This NCS==N_PRB==3 case cannot by itself distinguish that from the transposed reading
% (dividing by NCS instead of N_PRB) -- both give the same answer here by coincidence, which
% is exactly how the original (buggy) implementation passed this exact case undetected.
[prb, csPairIndex] = phy.ts38213.psfchResource(prbStart, MsubchSlot, 1, 3, 200, 0);
% RPrbCs = 1*3*3 = 9; resourceIndex = mod(200+0,9) = 2; NPRB=3; prbOffset=mod(2,3)=2;
% csPairIndex=floor(2/3)=0; prb = prbStart+2.
assert(csPairIndex == 0, 'psfchResource: csPairIndex expected 0, got %d', csPairIndex);
assert(prb == prbStart + 2, 'psfchResource: prb expected %d, got %d', prbStart + 2, prb);

% independent-verifier's discriminating case: NCS(=2) != N_PRB(=3) breaks the coincidental tie
% above and is the only case that actually proves the divisor is N_PRB, not NCS.
[prbTie, csTie] = phy.ts38213.psfchResource(27, 3, 1, 2, 202, 0);
% RPrbCs = 1*3*2 = 6; resourceIndex = mod(202,6) = 4; NPRB=3; prbOffset=mod(4,3)=1;
% csPairIndex=floor(4/3)=1; prb = 27+1 = 28.
% (transposed/buggy reading would give prb=29, csPairIndex=0 instead)
assert(prbTie == 28 && csTie == 1, 'psfchResource: NCS!=N_PRB discriminating case failed, got prb=%d cs=%d', prbTie, csTie);

try
    phy.ts38213.psfchResource(0, 3, 2, 3, 0, 0);
    error('test_procedures:shouldHaveErrored', 'psfchResource should reject Ntype~=1 (allocSubCH not yet supported)');
catch e
    assert(strcmp(e.identifier, 'ts38213:psfchResource:allocSubCHNotSupported'), 'psfchResource: wrong error for Ntype~=1');
end

%% psfchCyclicShiftM0 / psfchCyclicShiftMcs
assert(phy.ts38213.psfchCyclicShiftM0(0, 6) == 0, 'psfchCyclicShiftM0: NCS=6 index0 expected m0=0');
assert(phy.ts38213.psfchCyclicShiftM0(5, 6) == 5, 'psfchCyclicShiftM0: NCS=6 index5 expected m0=5');
assert(phy.ts38213.psfchCyclicShiftM0(1, 3) == 2, 'psfchCyclicShiftM0: NCS=3 index1 expected m0=2 (Table 16.3-1)');
assert(phy.ts38213.psfchCyclicShiftM0(0, 1) == 0, 'psfchCyclicShiftM0: NCS=1 expected m0=0');

assert(phy.ts38213.psfchCyclicShiftMcs(0, false) == 0, 'psfchCyclicShiftMcs: NACK, ack-or-nack table expected mcs=0');
assert(phy.ts38213.psfchCyclicShiftMcs(1, false) == 6, 'psfchCyclicShiftMcs: ACK, ack-or-nack table expected mcs=6');
assert(phy.ts38213.psfchCyclicShiftMcs(0, true) == 0, 'psfchCyclicShiftMcs: NACK, nack-only table expected mcs=0');
try
    phy.ts38213.psfchCyclicShiftMcs(1, true);
    error('test_procedures:shouldHaveErrored', 'psfchCyclicShiftMcs should reject ACK in the NACK-only table');
catch e
    assert(strcmp(e.identifier, 'ts38213:psfchCyclicShiftMcs:ackNotApplicable'), 'psfchCyclicShiftMcs: wrong error for ACK in NACK-only mode');
end

%% harqAckCombine
assert(phy.ts38213.harqAckCombine('unicast', 1) == 1, 'harqAckCombine: unicast passthrough failed');
assert(phy.ts38213.harqAckCombine('unicast', 0) == 0, 'harqAckCombine: unicast passthrough failed');
assert(phy.ts38213.harqAckCombine('groupcastAckNack', [true true true]) == 1, 'harqAckCombine: all-ACK should report ACK');
assert(phy.ts38213.harqAckCombine('groupcastAckNack', [true false true]) == 0, 'harqAckCombine: one NACK should report NACK overall');
assert(phy.ts38213.harqAckCombine('groupcastNackOnly', false) == 1, 'harqAckCombine: absence of reception should report ACK');
assert(phy.ts38213.harqAckCombine('groupcastNackOnly', true) == 0, 'harqAckCombine: detected reception should report NACK');

%% reservationPeriodIndex
periodList = [0, 10, 20, 50, 100];
assert(phy.ts38213.reservationPeriodIndex(20, periodList) == 2, 'reservationPeriodIndex: expected index 2');
try
    phy.ts38213.reservationPeriodIndex(15, periodList);
    error('test_procedures:shouldHaveErrored', 'reservationPeriodIndex should reject a period not in the list');
catch e
    assert(strcmp(e.identifier, 'ts38213:reservationPeriodIndex:notFound'), 'reservationPeriodIndex: wrong error for not-found period');
end

%% mode2ResourceSelect -- feeds directly into trivEncode/frivEncode, round-tripped
candidates = struct('slotIdx', {10, 15, 25, 50}, 'startSubch', {0, 2, 4, 1});
[N, t1, t2, nStart1, nStart2] = phy.ts38213.mode2ResourceSelect(candidates, 10, 3);
% slots >= 10 and <= 41: {10,15,25} (50 excluded, out of window) -> Nselected=3, N=min(3,3)=3.
assert(N == 3, 'mode2ResourceSelect: expected N=3, got %d', N);
assert(t1 == 5 && t2 == 15, 'mode2ResourceSelect: t1/t2 mismatch, got t1=%d t2=%d', t1, t2);
assert(nStart1 == 2 && nStart2 == 4, 'mode2ResourceSelect: nStart1/nStart2 mismatch');

% Round trip through trivEncode/trivDecode and frivEncode/frivDecode with maxReserve=3.
[trivVal, ~] = phy.ts38212.trivEncode(N, t1, t2, 3);
[NBack, t1Back, t2Back] = phy.ts38212.trivDecode(trivVal, 3);
assert(NBack == N && t1Back == t1 && t2Back == t2, 'mode2ResourceSelect: TRIV round trip failed');

Nsub = 10; LsubCH = 1;
[frivVal, ~] = phy.ts38212.frivEncode(nStart1, nStart2, LsubCH, Nsub, 3);
[nStart1Back, nStart2Back] = phy.ts38212.frivDecode(frivVal, LsubCH, Nsub, 3);
assert(nStart1Back == nStart1 && nStart2Back == nStart2, 'mode2ResourceSelect: FRIV round trip failed');

% NmaxReserve caps N even when more candidates fit in the window.
candidatesMany = struct('slotIdx', {10, 11, 12, 13}, 'startSubch', {0, 1, 2, 3});
[Ncapped, ~, ~, ~, ~] = phy.ts38213.mode2ResourceSelect(candidatesMany, 10, 2);
assert(Ncapped == 2, 'mode2ResourceSelect: NmaxReserve=2 should cap N at 2 even with 4 in-window candidates, got %d', Ncapped);

fprintf('test_procedures: PASS\n');
end
