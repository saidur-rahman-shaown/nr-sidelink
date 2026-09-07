function test_procedures()
%test_procedures Unit tests for +phy/+ts38214/'s clause 8 data-plane procedures.
%SPEC: TS 38.214 V16.17.0 clause 8 (subchannelMap: preamble to 8.1; mcsTableSelect: 8.1.3.1;
%      tbsDetermine: 8.1.3.2 + 5.1.3.2 steps 2-4; procTimeSensing/procTimeSelection: Table
%      8.1.4-1/-2; reservationPeriodToSlots: 8.1.7; sensingDb*: 8.1.4 step 2; candidateSet:
%      8.1.4 steps 1-7; procTimeCongestion/cbrRangeIndex/congestionControlCheck: 8.1.6 and
%      Tables 8.1.6-1/-2)
%
%Structural/shape assertions, hand-traced sensing-history scenarios, and a direct cross-check
%of tbsDetermine's quantisation path against a live nrTBS call. Per +test/CLAUDE.md level 2, an
%independent-verifier pass (spec-only, blind to this code) is still required for candidateSet
%and for tbsDetermine's clause-8.1.3.2-specific N_RE formula before this package is considered
%done -- see +phy/+ts38214/CLAUDE.md.

%% subchannelMap
[prbStart, unused] = phy.ts38214.subchannelMap(0, 10, 5, 50);
assert(isequal(prbStart, [0 10 20 30 40]), 'subchannelMap: prbStart mismatch');
assert(unused == 0, 'subchannelMap: unusedPrbCount expected 0, got %d', unused);
[~, unused2] = phy.ts38214.subchannelMap(0, 10, 5, 55);
assert(unused2 == 5, 'subchannelMap: unusedPrbCount expected 5, got %d', unused2);
[prbStart3, ~] = phy.ts38214.subchannelMap(2, 10, 3, 32);
assert(isequal(prbStart3, [2 12 22]), 'subchannelMap: nSubchRBStart offset mismatch');
try
    phy.ts38214.subchannelMap(0, 10, 6, 50);
    error('test_procedures:shouldHaveErrored', 'subchannelMap should reject geometry exceeding NPRB');
catch e
    assert(strcmp(e.identifier, 'ts38214:subchannelMap:badGeometry'), 'subchannelMap: wrong error for bad geometry');
end

%% mcsTableSelect
[mod0, Qm0, R0] = phy.ts38214.mcsTableSelect(0, '', 0);
t = nrPDSCHMCSTables;
row0 = t.QAM64Table.MCSIndex == 0;
assert(strcmp(mod0, t.QAM64Table.Modulation{row0}) && Qm0 == t.QAM64Table.Qm(row0) && R0 == t.QAM64Table.TargetCodeRate(row0), 'mcsTableSelect: IMcs=0, no additional table, mismatch vs Table 5.1.3.1-1');

[modA, QmA, RA] = phy.ts38214.mcsTableSelect(20, 'table2', 1);
row20 = t.QAM256Table.MCSIndex == 20;
assert(strcmp(modA, t.QAM256Table.Modulation{row20}) && QmA == t.QAM256Table.Qm(row20) && RA == t.QAM256Table.TargetCodeRate(row20), 'mcsTableSelect: table2 indicator=1 should route to Table 5.1.3.1-2');

[modB, QmB, RB] = phy.ts38214.mcsTableSelect(21, 'table3', 1);
rowB = t.QAM64LowSETable.MCSIndex == 21;
assert(strcmp(modB, t.QAM64LowSETable.Modulation{rowB}) && QmB == t.QAM64LowSETable.Qm(rowB) && RB == t.QAM64LowSETable.TargetCodeRate(rowB), 'mcsTableSelect: table3 indicator=1 should route to Table 5.1.3.1-3');

[modC, ~, ~] = phy.ts38214.mcsTableSelect(5, 'table2table3', 2);
rowC = t.QAM64LowSETable.MCSIndex == 5;
assert(strcmp(modC, t.QAM64LowSETable.Modulation{rowC}), 'mcsTableSelect: table2table3 indicator=2 (''10'') should route to the 2nd table (table3)');

try
    phy.ts38214.mcsTableSelect(29, '', 0);
    error('test_procedures:shouldHaveErrored', 'mcsTableSelect should reject a reserved IMcs');
catch e
    assert(strcmp(e.identifier, 'ts38214:mcsTableSelect:reservedMcs'), 'mcsTableSelect: wrong error for reserved IMcs');
end
try
    phy.ts38214.mcsTableSelect(0, 'table2table3', 3);
    error('test_procedures:shouldHaveErrored', 'mcsTableSelect should reject the reserved 2-bit indicator value 3');
catch e
    assert(strcmp(e.identifier, 'ts38214:mcsTableSelect:reservedIndicator'), 'mcsTableSelect: wrong error for reserved indicator');
end
try
    phy.ts38214.mcsTableSelect(0, '', 1);
    error('test_procedures:shouldHaveErrored', 'mcsTableSelect should reject a nonzero indicator when the field does not exist');
catch e
    assert(strcmp(e.identifier, 'ts38214:mcsTableSelect:badIndicator'), 'mcsTableSelect: wrong error for spurious indicator');
end

%% tbsDetermine -- cross-check against a live nrTBS call (nReSci1=nReSci2=0)
modulation = '16QAM'; Qm = 4; R = 0.4785; nLayers = 1; nPRB = 10; slLengthSymbols = 14;
dmrsPattern = [3];
[tbsMine, NRE] = phy.ts38214.tbsDetermine(Qm, R, nLayers, nPRB, slLengthSymbols, 0, false, 0, dmrsPattern, 0, 0);
NREPerPRBForNrTBS = 12 * ((slLengthSymbols - 2) - 0) - 18;   % clause 8.1.3.2: N_symb^sh=sl-LengthSymbols-2; Table 8.1.3.2-1: pattern {3} -> 18
tbsRef = nrTBS(modulation, nLayers, nPRB, NREPerPRBForNrTBS, R, 0);
assert(tbsMine == tbsRef, 'tbsDetermine: mismatch vs nrTBS cross-check, got %d expected %d', tbsMine, tbsRef);
assert(NRE == min(156, NREPerPRBForNrTBS) * nPRB, 'tbsDetermine: NRE mismatch in the no-SCI-overhead case');

% PSFCH overhead indicated (period 2 or 4) shortens the symbol count used, so NRE should shrink
[~, NREPsfch] = phy.ts38214.tbsDetermine(Qm, R, nLayers, nPRB, slLengthSymbols, 2, true, 0, dmrsPattern, 0, 0);
assert(NREPsfch == NRE - 3 * 12 * nPRB, 'tbsDetermine: PSFCH overhead subtraction mismatch');

% sidelink-specific N_RE^SCI,1/SCI,2 subtraction (needs independent-verifier before "done")
[~, NRESci] = phy.ts38214.tbsDetermine(Qm, R, nLayers, nPRB, slLengthSymbols, 0, false, 0, dmrsPattern, 20, 10);
assert(NRESci == NRE - 30, 'tbsDetermine: N_RE^SCI,1/SCI,2 subtraction mismatch');

%% tbsDetermine -- independent-verifier worked example (clause 8.1.3.2's own N_RE formula)
% Case A (nominal): sl-LengthSymbols=14, sl-PSFCH-Period=2, overhead-indicated=true,
% sl-X-Overhead=6, DMRS list={2,3}, nPRB=10, N_RE^SCI,1=24, N_RE^SCI,2=12.
% Confirmed: N_symb^PSFCH=3, N_RE^DMRS=15, N_RE'=87, N_RE=834.
[~, NRE_A] = phy.ts38214.tbsDetermine(4, 0.5, 1, 10, 14, 2, true, 6, [2 3], 24, 12);
assert(NRE_A == 834, 'tbsDetermine independent-verifier Case A: expected N_RE=834, got %d', NRE_A);

% Case D: same slot, overhead-indicated=false -> N_symb^PSFCH=0 instead of 3, N_RE'=123, N_RE=1194
[~, NRE_D] = phy.ts38214.tbsDetermine(4, 0.5, 1, 10, 14, 2, false, 6, [2 3], 24, 12);
assert(NRE_D == 1194, 'tbsDetermine independent-verifier Case D: expected N_RE=1194, got %d', NRE_D);

% Case E: sl-PSFCH-Period=1 -> N_symb^PSFCH=3 UNCONDITIONALLY, the overhead-indication bit must
% be ignored (a plain "if bit then 3 else 0" would wrongly give 0 for the false case)
[~, NRE_E_true]  = phy.ts38214.tbsDetermine(4, 0.5, 1, 10, 14, 1, true,  6, [2 3], 24, 12);
[~, NRE_E_false] = phy.ts38214.tbsDetermine(4, 0.5, 1, 10, 14, 1, false, 6, [2 3], 24, 12);
assert(NRE_E_true == 834 && NRE_E_false == 834, 'tbsDetermine independent-verifier Case E: sl-PSFCH-Period=1 must ignore the overhead-indication bit, got %d / %d', NRE_E_true, NRE_E_false);

% Case F: sl-PSFCH-Period=0 -> N_symb^PSFCH=0 unconditionally, bit ignored the other way
[~, NRE_F] = phy.ts38214.tbsDetermine(4, 0.5, 1, 10, 14, 0, true, 6, [2 3], 24, 12);
assert(NRE_F == 1194, 'tbsDetermine independent-verifier Case F: expected N_RE=1194, got %d', NRE_F);

% dmrsTimePattern takes the CONFIGURED LIST, not the SCI-selected pattern: a pool configuring
% BOTH {2} and {3} as options uses Table 8.1.3.2-1's {2,3} row (15) regardless of which single
% pattern the SCI happens to select for a given transmission -- the row is the mean of its
% singleton members, not either singleton alone. This is the exact case the
% independent-verifier's read of clause 8.1.3.2 turned up: an earlier version of this header
% documented the input as "the SCI-selected pattern", which would have wrongly used 12 or 18.
[~, NRE_listcheck] = phy.ts38214.tbsDetermine(4, 0.5, 1, 10, 14, 0, false, 0, [2 3], 0, 0);
assert(NRE_listcheck == (12 * (14 - 2) - 15) * 10, 'tbsDetermine: dmrsTimePattern must use the configured list''s Table 8.1.3.2-1 row (15 for {2,3}), not either singleton value (12 or 18)');

try
    phy.ts38214.tbsDetermine(Qm, R, 3, nPRB, slLengthSymbols, 0, false, 0, dmrsPattern, 0, 0);
    error('test_procedures:shouldHaveErrored', 'tbsDetermine should reject nLayers not in {1,2}');
catch e
    assert(strcmp(e.identifier, 'ts38214:tbsDetermine:badNLayers'), 'tbsDetermine: wrong error for bad nLayers');
end
try
    phy.ts38214.tbsDetermine(Qm, R, nLayers, nPRB, slLengthSymbols, 0, false, 0, [5], 0, 0);
    error('test_procedures:shouldHaveErrored', 'tbsDetermine should reject an unlisted DMRS pattern');
catch e
    assert(strcmp(e.identifier, 'ts38214:tbsDetermine:badDmrsPattern'), 'tbsDetermine: wrong error for bad DMRS pattern');
end

%% procTimeSensing / procTimeSelection -- Table 8.1.4-1 / Table 8.1.4-2
assert(isequal(arrayfun(@phy.ts38214.procTimeSensing, 0:3), [1 1 2 4]), 'procTimeSensing: Table 8.1.4-1 mismatch');
assert(isequal(arrayfun(@phy.ts38214.procTimeSelection, 0:3), [3 5 9 17]), 'procTimeSelection: Table 8.1.4-2 mismatch');

%% reservationPeriodToSlots
assert(phy.ts38214.reservationPeriodToSlots(100, 10240) == 100, 'reservationPeriodToSlots: 1:1 case failed');
assert(phy.ts38214.reservationPeriodToSlots(100, 5120) == 50, 'reservationPeriodToSlots: half-density case failed');
try
    phy.ts38214.reservationPeriodToSlots(0, 10240);
    error('test_procedures:shouldHaveErrored', 'reservationPeriodToSlots should reject a non-positive period');
catch e
    assert(strcmp(e.identifier, 'ts38214:reservationPeriodToSlots:badPeriod'), 'reservationPeriodToSlots: wrong error for non-positive period');
end

%% sensingDb -- init / record (with TRIV/FRIV chaining) / markUnmonitored
db = phy.ts38214.sensingDbInit();
assert(isempty(db.slot) && isempty(db.unmonitoredSlot), 'sensingDbInit: expected empty database');

db = phy.ts38214.sensingDbRecord(db, 40, 2, 1, 4, -70, true, 100, 3, 5, 15, 0, 2);
assert(db.slot(1) == 40 && db.startSubch(1) == 2 && db.chainedCount(1) == 2, 'sensingDbRecord: N=3 chaining metadata mismatch');
assert(db.chainedSlot1(1) == 45 && db.chainedStart1(1) == 0, 'sensingDbRecord: chained resource 1 (t1/nStart1) mismatch');
assert(db.chainedSlot2(1) == 55 && db.chainedStart2(1) == 2, 'sensingDbRecord: chained resource 2 (t2/nStart2) mismatch');

db = phy.ts38214.sensingDbRecord(db, 41, 0, 1, 2, -80, false, 0, 1, 0, 0, 0, 0);
assert(db.chainedCount(2) == 0 && db.chainedSlot1(2) == 0, 'sensingDbRecord: N=1 should record no chained resources');

db = phy.ts38214.sensingDbMarkUnmonitored(db, 43);
assert(isequal(db.unmonitoredSlot, 43), 'sensingDbMarkUnmonitored: mismatch');

%% candidateSet -- Test A0: step 6 sensed-reservation exclusion, no escalation needed
req = struct('n', 50, 'T1', 3, 'T2', 5, 'remainingPdbSlots', 10, 'LsubCH', 1, 'prioTx', 5, 'prsvpTxMs', 0, 'Cresel', 1);
mu = 0;
db = phy.ts38214.sensingDbInit();
db = phy.ts38214.sensingDbRecord(db, 43, 1, 1, 3, 25, true, 12, 1, 0, 0, 0, 0);   % anchor only, N=1
thresholdListDbm = zeros(64, 1);
thresholdListDbm(3 + (5 - 1) * 8) = 20;   % Th(prio_RX=3, prio_TX=5) = 20 dBm
[candY, candX, survivor0, Mtotal, nEscA0] = phy.ts38214.candidateSet( ...
    req, 3, 100, mu, db, thresholdListDbm, 0.8, [12], 5, 10240, 20);
assert(Mtotal == 9, 'candidateSet TestA0: expected Mtotal=9 (window [n+T1,n+T2]=[53,55], 3 slots x 3 sub-channels), got %d', Mtotal);
hitIdx = candY == 55 & candX == 1;
assert(nnz(hitIdx) == 1 && ~survivor0(hitIdx), 'candidateSet TestA0: candidate (y=55,x=1) should be excluded by the sensed reservation''s q=1 recurrence at slot 43+12=55');
assert(nnz(survivor0) == Mtotal - 1, 'candidateSet TestA0: expected exactly one exclusion, got %d survivors of %d', nnz(survivor0), Mtotal);
assert(nEscA0 == 0, 'candidateSet TestA0: 8/9 already meets X=0.8, no escalation should be needed, got %d', nEscA0);

%% candidateSet -- Test A1: the same exclusion, but a tighter X forces 3 dB escalation until
%  the sensed RSRP (25 dBm) no longer exceeds the escalated threshold and the resource clears
[~, ~, survivorA1, ~, nEscA1, thOffA1] = phy.ts38214.candidateSet( ...
    req, 3, 100, mu, db, thresholdListDbm, 0.99, [12], 5, 10240, 20);
assert(all(survivorA1), 'candidateSet TestA1: once Th escalates past rsrp=25 dBm the exclusion should clear and every candidate should survive');
assert(nEscA1 == 2, 'candidateSet TestA1: expected 2 escalation rounds (Th must reach 26 dBm=20+2*3 to clear rsrp=25 dBm), got %d', nEscA1);
assert(thOffA1 == 6, 'candidateSet TestA1: expected final threshold offset 6 dB, got %d', thOffA1);

%% candidateSet -- Test B: step 5 (hypothetical SCI) + step 5a re-initialisation
dbB = phy.ts38214.sensingDbInit();
dbB = phy.ts38214.sensingDbMarkUnmonitored(dbB, 43);
[candYB, ~, survivorB, MtotalB, nEscB] = phy.ts38214.candidateSet( ...
    req, 3, 100, mu, dbB, thresholdListDbm, 0.9, [12], 5, 10240, 20);
assert(MtotalB == 9, 'candidateSet TestB: expected Mtotal=9, got %d', MtotalB);
assert(all(survivorB), 'candidateSet TestB: step 5a should have re-included every candidate excluded by the hypothetical-SCI test (step 5 alone would exclude all of slot y=55)');
assert(nEscB == 0, 'candidateSet TestB: no escalation should be needed once step 5a restores the full set, got %d', nEscB);
assert(any(candYB == 55), 'candidateSet TestB: sanity check that slot 55 is actually in the window');

%% candidateSet -- Test C: boot with an empty sensing database
dbC = phy.ts38214.sensingDbInit();
[~, ~, survivorC, MtotalC, nEscC] = phy.ts38214.candidateSet( ...
    req, 3, 100, mu, dbC, thresholdListDbm, 0.9, [12], 5, 10240, 20);
assert(all(survivorC) && MtotalC == 9 && nEscC == 0, 'candidateSet TestC: an empty sensing database should report every candidate, unfiltered');

%% candidateSet -- Test D: step 6c's Q formula must divide two MS quantities, not mix ms/slots.
% Independent-verifier flag: at mu=0 with TmaxPrime=10240, P_rsvp (ms) and P'_rsvp (slots) are
% numerically identical, so Tests A0/A1/B/C above cannot tell "Q=ceil(T_scal/P_rsvp_RX)" (correct)
% apart from a dimensionally-wrong "Q=ceil(T_scal/P'_rsvp_RX)". This case uses mu=1 with
% TmaxPrime=20480 so P_rsvp_RX(6 ms) and P'_rsvp_RX(12 slots) differ, and picks T_scal=17.5 ms
% so the two formulas give different Q (ceil(17.5/6)=3 vs ceil(17.5/12)=2) and therefore a
% different excluded-candidate count (3 vs 2).
reqD = struct('n', 50, 'T1', 5, 'T2', 35, 'remainingPdbSlots', 35, 'LsubCH', 1, 'prioTx', 5, 'prsvpTxMs', 0, 'Cresel', 1);
dbD = phy.ts38214.sensingDbInit();
dbD = phy.ts38214.sensingDbRecord(dbD, 45, 0, 1, 3, 30, true, 6, 1, 0, 0, 0, 0);   % P_rsvp_RX=6ms
[candYD, ~, survivorD, MtotalD] = phy.ts38214.candidateSet( ...
    reqD, 1, 100, 1, dbD, thresholdListDbm, 0.9, [6], 5, 20480, 20);
assert(MtotalD == 31, 'candidateSet TestD: expected Mtotal=31 (window [55,85], 1 sub-channel), got %d', MtotalD);
excludedD = candYD(~survivorD);
assert(isequal(sort(excludedD), [57 69 81]), 'candidateSet TestD: expected exclusions at slots 45+q*12 for q=1,2,3 (Q=ceil(17.5/6)=3), i.e. {57,69,81}, got [%s] -- a Q=ceil(T_scal/P''_rsvp_RX) unit mix-up would give only {57,69}', num2str(sort(excludedD)));

%% candidateSet -- bounds validation
badReq = req; badReq.T1 = 999;
try
    phy.ts38214.candidateSet(badReq, 3, 100, mu, dbC, thresholdListDbm, 0.9, [12], 5, 10240, 20);
    error('test_procedures:shouldHaveErrored', 'candidateSet should reject T1 above T_proc,1');
catch e
    assert(strcmp(e.identifier, 'ts38214:candidateSet:badT1'), 'candidateSet: wrong error for out-of-range T1');
end

%% procTimeCongestion -- clause 8.1.6, Tables 8.1.6-1/-2
% mu=0 is deliberately not the only case checked: the two capability tables agree at mu=0
% (N=2 both) and diverge for every mu>=1, so a mu=0-only test is blind to a table mix-up.
% Both FULL vectors are asserted rather than sampled, because of a structural overlap the
% independent-verifier flagged: for mu>=1 Table 8.1.6-2 is exactly 2x Table 8.1.6-1, AND
% Table 8.1.6-2 at mu equals Table 8.1.6-1 at mu+1 -- so an off-by-one row index in one table
% masquerades as the other table. Only pinning both endpoints ((mu=0,cap=2)=2 and
% (mu=3,cap=1)=8) alongside the interior rows separates a row-offset bug from a table-selection
% bug.
assert(isequal(arrayfun(@(m) phy.ts38214.procTimeCongestion(m, 1), 0:3), [2 2 4 8]), 'procTimeCongestion: capability 1 must match Table 8.1.6-1 = [2 2 4 8]');
assert(isequal(arrayfun(@(m) phy.ts38214.procTimeCongestion(m, 2), 0:3), [2 4 8 16]), 'procTimeCongestion: capability 2 must match Table 8.1.6-2 = [2 4 8 16]');
assert(phy.ts38214.procTimeCongestion(1, 1) ~= phy.ts38214.procTimeCongestion(1, 2), 'procTimeCongestion: mu=1 must discriminate the two capability tables (2 vs 4)');
try
    phy.ts38214.procTimeCongestion(1, 3);
    error('test_procedures:shouldHaveErrored', 'procTimeCongestion should reject a capability other than 1 or 2');
catch e
    assert(strcmp(e.identifier, 'ts38214:procTimeCongestion:badCapability'), 'procTimeCongestion: wrong error for bad capability');
end
try
    phy.ts38214.procTimeCongestion(4, 1);
    error('test_procedures:shouldHaveErrored', 'procTimeCongestion should reject mu outside 0..3');
catch e
    assert(strcmp(e.identifier, 'ts38214:procTimeCongestion:badMu'), 'procTimeCongestion: wrong error for bad mu');
end

%% cbrRangeIndex -- clause 8.1.6 + TS 38.331 sl-CBR-RangeConfigList semantics
% Entries are the INCLUSIVE upper bound of each level, ascending, first level's lower bound 0.
bounds = [0.2 0.5 0.8 1.0];
assert(phy.ts38214.cbrRangeIndex(0, bounds) == 1, 'cbrRangeIndex: cbr=0 must land in level 1 (first range''s lower bound is 0, inclusive)');
assert(phy.ts38214.cbrRangeIndex(0.2, bounds) == 1, 'cbrRangeIndex: cbr exactly at a range''s upper bound must stay in THAT level (bounds are inclusive), expected 1');
assert(phy.ts38214.cbrRangeIndex(0.20001, bounds) == 2, 'cbrRangeIndex: cbr just above level 1''s upper bound must move to level 2');
assert(phy.ts38214.cbrRangeIndex(0.35, bounds) == 2, 'cbrRangeIndex: cbr=0.35 must land in level 2');
assert(phy.ts38214.cbrRangeIndex(0.5, bounds) == 2, 'cbrRangeIndex: cbr=0.5 (level 2''s upper bound) must stay in level 2');
assert(phy.ts38214.cbrRangeIndex(0.65, bounds) == 3, 'cbrRangeIndex: cbr=0.65 must land in level 3');
assert(phy.ts38214.cbrRangeIndex(0.8, bounds) == 3, 'cbrRangeIndex: cbr=0.8 (level 3''s upper bound) must stay in level 3');
assert(phy.ts38214.cbrRangeIndex(0.95, bounds) == 4, 'cbrRangeIndex: cbr=0.95 must land in level 4');
assert(phy.ts38214.cbrRangeIndex(1.0, bounds) == 4, 'cbrRangeIndex: cbr=1.0 must land in the top level');
assert(phy.ts38214.cbrRangeIndex(0.4, 1.0) == 1, 'cbrRangeIndex: a single-level list (SIZE(1..maxCBR-Level)) must always report level 1');
try
    phy.ts38214.cbrRangeIndex(0.9, [0.2 0.5 0.8]);
    error('test_procedures:shouldHaveErrored', 'cbrRangeIndex should reject a CBR above every configured range rather than clamping');
catch e
    assert(strcmp(e.identifier, 'ts38214:cbrRangeIndex:noRange'), 'cbrRangeIndex: wrong error for a CBR outside every configured range');
end
try
    phy.ts38214.cbrRangeIndex(0.4, [0.5 0.2 0.8]);
    error('test_procedures:shouldHaveErrored', 'cbrRangeIndex should reject a non-ascending range list');
catch e
    assert(strcmp(e.identifier, 'ts38214:cbrRangeIndex:notAscending'), 'cbrRangeIndex: wrong error for a non-ascending range list');
end

%% congestionControlCheck -- clause 8.1.6, sum_{i>=k} CR(i) <= CR_limit(k)
% The summation runs DOWNWARD in priority: priority 1 is the highest, so CR_limit(1) constrains
% the total occupancy of ALL eight priorities, and CR_limit(8) constrains only priority 8's own.
% This CR vector is deliberately front-loaded (0.30 at priority 1) so the correct reverse
% accumulation and a wrong forward one produce visibly different vectors -- a forward cumsum
% would give crCumulative(1)=0.30 and crCumulative(8)=0.42, exactly the reverse of the truth.
crTol = 1e-12;
crVec = [0.30 0.05 0.02 0.01 0.01 0.01 0.01 0.01];
crLim = [0.50 0.10 0.10 0.10 0.10 0.10 0.10 0.10];
allPresent = true(1, 8);
[okA, cumA, violA] = phy.ts38214.congestionControlCheck(crVec, crLim, allPresent);
expCumA = [0.42 0.12 0.07 0.05 0.04 0.03 0.02 0.01];
assert(all(abs(cumA - expCumA) < crTol), 'congestionControlCheck: crCumulative mismatch, expected [%s], got [%s] -- a forward (i<=k) accumulation would give [%s]', num2str(expCumA), num2str(cumA), num2str(cumsum(crVec)));
assert(abs(cumA(1) - sum(crVec)) < crTol, 'congestionControlCheck: crCumulative(1) must be the sum over ALL priorities (k=1 is the highest priority, sum_{i>=1})');
assert(abs(cumA(8) - crVec(8)) < crTol, 'congestionControlCheck: crCumulative(8) must be priority 8''s own CR alone');
assert(all(diff(cumA) <= 0), 'congestionControlCheck: crCumulative must be non-increasing in k by construction');
assert(isequal(violA, logical([0 1 0 0 0 0 0 0])), 'congestionControlCheck: only k=2 should violate (0.12 > 0.10), got [%s]', num2str(violA));
assert(~okA, 'congestionControlCheck: withinLimit must be false when any configured limit is exceeded');

% Presence flags: an absent sl-CR-Limit imposes no limit at that k (TS 38.331 OPTIONAL, and
% clause 8.1.6 applies only "if a UE is configured with higher layer parameter sl-CR-Limit").
[okB, cumB, violB] = phy.ts38214.congestionControlCheck(crVec, crLim, logical([1 0 0 0 0 0 0 0]));
assert(all(abs(cumB - expCumA) < crTol), 'congestionControlCheck: presence flags must not change crCumulative');
assert(~any(violB) && okB, 'congestionControlCheck: with only k=1 configured (0.42 <= 0.50), nothing should violate');

% Independent-verifier case 3c: CR(2) lowered so crCumulative(2) lands EXACTLY on its limit.
% Two things at once -- it pins the non-strict "<=" (equality must pass), and unlike case A it
% discriminates the summation direction on withinLimit alone: a forward (i<=k) accumulation
% gives crCumulative(2)=0.33 > 0.10 and would report false here. The verifier checked the FP
% behaviour explicitly: right-to-left accumulation gives exactly 0.1 at k=2 while a left-to-right
% sum(cr(2:8)) gives 0.09999999999999999, and both still satisfy "<=", so the verdict is robust
% either way -- but crCumulative itself is asserted with a tolerance, never exact equality.
crVecC = [0.30 0.03 0.02 0.01 0.01 0.01 0.01 0.01];
[okE, cumE, violE] = phy.ts38214.congestionControlCheck(crVecC, crLim, allPresent);
expCumE = [0.40 0.10 0.07 0.05 0.04 0.03 0.02 0.01];
assert(all(abs(cumE - expCumE) < crTol), 'congestionControlCheck (verifier case 3c): crCumulative mismatch, expected [%s], got [%s]', num2str(expCumE), num2str(cumE));
assert(~any(violE) && okE, 'congestionControlCheck (verifier case 3c): crCumulative(2) exactly equal to CR_limit(2) must PASS; a forward (i<=k) accumulation would report a violation here');

% Boundary: the clause is "<=", so hitting the limit exactly is compliant. Values chosen to be
% exact in binary floating point (0.25/0.5) so this tests the comparison operator, not FP noise.
[okC, cumC, violC] = phy.ts38214.congestionControlCheck([0.25 0.25 0 0 0 0 0 0], [0.5 0.25 1 1 1 1 1 1], true(1, 8));
assert(cumC(1) == 0.5 && cumC(2) == 0.25, 'congestionControlCheck: exact-boundary case should give crCumulative(1)=0.5, crCumulative(2)=0.25');
assert(~any(violC) && okC, 'congestionControlCheck: sum exactly equal to the limit must PASS (clause 8.1.6 is "<=", not "<")');

okD = phy.ts38214.congestionControlCheck(zeros(1, 8), zeros(1, 8), true(1, 8));
assert(okD, 'congestionControlCheck: an idle UE (all CR zero) must pass even a zero limit');

try
    phy.ts38214.congestionControlCheck([0.1 0.1], crLim, allPresent);
    error('test_procedures:shouldHaveErrored', 'congestionControlCheck should reject a CR vector that is not 8 entries');
catch e
    assert(strcmp(e.identifier, 'ts38214:congestionControlCheck:badCr'), 'congestionControlCheck: wrong error for a wrong-length CR vector');
end
try
    phy.ts38214.congestionControlCheck([1.5 zeros(1, 7)], crLim, allPresent);
    error('test_procedures:shouldHaveErrored', 'congestionControlCheck should reject a CR outside [0,1]');
catch e
    assert(strcmp(e.identifier, 'ts38214:congestionControlCheck:badCr'), 'congestionControlCheck: wrong error for an out-of-range CR');
end

fprintf('test_procedures: PASS\n');
end
