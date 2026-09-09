function test_macSidelink()
%test_macSidelink Unit tests for +mac/, the TS 38.321 sidelink MAC procedures.
%SPEC: TS 38.321 V16.22.0 (creselCounterRange/grantSelect: clause 5.22.1.1; reselectionTrigger:
%      5.22.1.2; reevaluation/preemption: 5.22.1.2a; harq*: 5.22.1.3.1/.1a/.3.3; slLcp*:
%      5.22.1.4.1; muxSlSch: 6.1.6 + 6.2.4 + 6.1.3.35) and TS 38.214 V16.17.0 clause 8.1.4
%      (cresel's x10 multiplier, preemption's priority/RSRP condition).
%
%Hand-computed expected values throughout. Per +test/CLAUDE.md level 2 an independent-verifier
%pass (spec-only, blind to this code) is required before these are trusted -- see +mac/CLAUDE.md.
tol = 1e-12;

%% creselCounterRange -- clause 5.22.1.1
[lo, hi] = mac.creselCounterRange(100);
assert(lo == 5 && hi == 15, 'creselCounterRange: P_rsvp_TX = 100 ms is the ">= 100ms" branch, expected [5,15], got [%d,%d]', lo, hi);
[lo, hi] = mac.creselCounterRange(200);
assert(lo == 5 && hi == 15, 'creselCounterRange: P_rsvp_TX = 200 ms must also give [5,15]');
% Below 100 ms both endpoints scale by ceil(100/max(20,P)).
[lo, hi] = mac.creselCounterRange(50);
assert(lo == 10 && hi == 30, 'creselCounterRange: P=50 -> scale ceil(100/50)=2, expected [10,30], got [%d,%d]', lo, hi);
[lo, hi] = mac.creselCounterRange(20);
assert(lo == 25 && hi == 75, 'creselCounterRange: P=20 -> scale ceil(100/20)=5, expected [25,75], got [%d,%d]', lo, hi);
% The max(20, .) floor: P=10 must give the SAME answer as P=20. Without the floor it would be
% ceil(100/10)=10 -> [50,150], double. This is the case that catches a dropped max().
[lo10, hi10] = mac.creselCounterRange(10);
assert(lo10 == 25 && hi10 == 75, 'creselCounterRange: the max(20,P) floor must make P=10 give [25,75], got [%d,%d] -- [50,150] means the floor was dropped', lo10, hi10);
[lo1, hi1] = mac.creselCounterRange(1);
assert(lo1 == 25 && hi1 == 75, 'creselCounterRange: every P below 20 ms clamps to the same [25,75]');
% Both endpoints scale by the SAME factor: the ratio hi/lo is invariant at 3.
assert(abs(hi10 / lo10 - 3) < tol, 'creselCounterRange: the multiplier must scale both endpoints, keeping hi/lo = 15/5 = 3');
try
    mac.creselCounterRange(0);
    error('test_macSidelink:shouldHaveErrored', 'creselCounterRange should reject a non-positive period');
catch e
    assert(strcmp(e.identifier, 'mac:creselCounterRange:badPeriod'), 'creselCounterRange: wrong error for P=0');
end

%% cresel -- TS 38.214 clause 8.1.4, C_resel = 10 x counter
assert(mac.cresel(5, true) == 50, 'cresel: C_resel must be TEN times the counter');
assert(mac.cresel(1, true) == 10, 'cresel: counter 1 -> C_resel 10');
assert(mac.cresel(7, false) == 1, 'cresel: an aperiodic process has no counter, so C_resel = 1 regardless of the counter argument');
try
    mac.cresel(0, true);
    error('test_macSidelink:shouldHaveErrored', 'cresel should refuse a periodic process whose counter has expired');
catch e
    assert(strcmp(e.identifier, 'mac:cresel:counterExpired'), 'cresel: wrong error for an expired counter');
end

%% keepDecision -- clauses 5.22.1.1 / 5.22.1.2
% The two clauses partition the outcome with "less than or equal to" (keep) and "above"
% (reselect), so the exact boundary belongs to KEEP.
assert(mac.keepDecision(0.4, 0.4), 'keepDecision: draw exactly equal to sl-ProbResourceKeep must KEEP (clause 5.22.1.1 is "less than or equal to")');
assert(~mac.keepDecision(0.41, 0.4), 'keepDecision: a draw above sl-ProbResourceKeep must reselect');
assert(mac.keepDecision(0.5, 0.8), 'keepDecision: 0.5 <= 0.8 must keep');
assert(~mac.keepDecision(0.5, 0.2), 'keepDecision: 0.5 > 0.2 must reselect');
assert(mac.keepDecision(0, 0), 'keepDecision: sl-ProbResourceKeep=0 with a draw of exactly 0 still satisfies "<="');
assert(~mac.keepDecision(0.0001, 0), 'keepDecision: sl-ProbResourceKeep=0 means effectively never keep');
try
    mac.keepDecision(0.5, 0.5);
    error('test_macSidelink:shouldHaveErrored', 'keepDecision should reject a probability outside the sl-ProbResourceKeep enum');
catch e
    assert(strcmp(e.identifier, 'mac:keepDecision:badProb'), 'keepDecision: wrong error for an unconfigurable probability');
end

%% reselectionTrigger -- clause 5.22.1.2, all seven conditions
none = struct('counterExpiredNotKept', false, 'poolReconfigured', false, 'noSelectedGrant', false, ...
              'noTxLastSecond', false, 'reselectAfterReached', false, 'cannotAccommodateSdu', false, ...
              'pdbNotMet', false);
[trig, cond] = mac.reselectionTrigger(none);
assert(~trig && ~any(cond), 'reselectionTrigger: no condition set must not trigger');
% Each condition alone must fire, and must be reported in its own slot: a truth table, not a
% sample. This is what makes `conditions` worth returning.
names = fieldnames(none);
for i = 1:numel(names)
    c = none;
    c.(names{i}) = true;
    [trig, cond] = mac.reselectionTrigger(c);
    assert(trig, 'reselectionTrigger: condition %s alone must trigger reselection', names{i});
    assert(cond(i) && nnz(cond) == 1, 'reselectionTrigger: condition %s must be reported in slot %d alone, got [%s]', names{i}, i, num2str(cond));
end
% Two at once: both reported, still one trigger.
c = none; c.noSelectedGrant = true; c.pdbNotMet = true;
[trig, cond] = mac.reselectionTrigger(c);
assert(trig && nnz(cond) == 2, 'reselectionTrigger: simultaneous conditions must all be reported (no short-circuit)');
% A missing condition must be an error, never a silent false.
c = rmfield(none, 'poolReconfigured');
try
    mac.reselectionTrigger(c);
    error('test_macSidelink:shouldHaveErrored', 'reselectionTrigger should reject a missing condition rather than defaulting it to false');
catch e
    assert(strcmp(e.identifier, 'mac:reselectionTrigger:missingCondition'), 'reselectionTrigger: wrong error for a missing condition');
end

%% grant lifecycle -- a full hand-traced SPS lifecycle (the +mac/CLAUDE.md gate)
g = mac.grantInit();
assert(~g.hasGrant, 'grantInit: a fresh state holds no grant');
% P_rsvp_TX = 100 ms -> counter drawn from [5,15]; take 7. Three opportunities per period:
% one initial transmission plus two retransmissions.
g = mac.grantSelect(g, [10 12 14], [0 0 0], 2, 100, true, 7);
assert(g.hasGrant && g.counter == 7 && g.isPeriodic, 'grantSelect: grant not installed as expected');
assert(mac.cresel(g.counter, g.isPeriodic) == 70, 'grantSelect/cresel: counter 7 must give C_resel 70 for candidateSet');
% Transmit on all three opportunities, then close the period. The counter must fall by ONE,
% not by three -- clause 5.22.1.3.1a decrements per MAC PDU, not per transmission.
for k = 1:3
    g = mac.grantOnTransmission(g, k);
end
[g, hitZero] = mac.grantOnPeriodEnd(g, 0.9);
assert(g.counter == 6, 'grantOnPeriodEnd: three transmissions in one reservation period must cost ONE count, got counter %d (4 means it decremented per transmission)', g.counter);
assert(~hitZero, 'grantOnPeriodEnd: counter 6 has not hit zero');
assert(g.consecutiveUnusedPeriods == 0, 'grantOnPeriodEnd: a period with any use must reset the sl-ReselectAfter streak');
assert(~any(g.txOppUsed), 'grantOnPeriodEnd: the new period must start with every opportunity unused');
% Run down to the 1 -> 0 transition. The keep draw must be captured on THAT period, not before.
for p = 1:5
    g = mac.grantOnTransmission(g, 1);
    assert(~g.keepDrawPending, 'grantOnPeriodEnd: the keep draw must not be captured while the counter is above 1 (period %d, counter %d)', p, g.counter);
    [g, hitZero] = mac.grantOnPeriodEnd(g, 0.3);
    assert(~hitZero || g.counter == 0, 'grantOnPeriodEnd: counterHitZero must only be true at zero');
end
assert(g.counter == 1, 'grant lifecycle: expected counter 1 after 6 periods from 7, got %d', g.counter);
g = mac.grantOnTransmission(g, 1);
[g, hitZero] = mac.grantOnPeriodEnd(g, 0.25);
assert(g.counter == 0 && hitZero, 'grant lifecycle: the seventh period must take the counter to 0 and report it');
assert(g.keepDrawPending && abs(g.keepDraw - 0.25) < tol, 'grantOnPeriodEnd: the sl-ProbResourceKeep draw must be captured on the 1->0 transition, holding 0.25');
% sl-ProbResourceKeep = 0.4 with the captured draw 0.25 -> keep; 0.2 -> reselect.
assert(mac.keepDecision(g.keepDraw, 0.4), 'grant lifecycle: draw 0.25 <= 0.4 must keep the grant');
assert(~mac.keepDecision(g.keepDraw, 0.2), 'grant lifecycle: draw 0.25 > 0.2 must trigger reselection');
% The reselect branch feeds reselectionTrigger's first condition.
c = none; c.counterExpiredNotKept = ~mac.keepDecision(g.keepDraw, 0.2);
assert(mac.reselectionTrigger(c), 'grant lifecycle: a counter at 0 whose draw said "reselect" must trigger the check');
% ...but a counter at 0 whose draw said "keep" must NOT, which is what makes sl-ProbResourceKeep
% mean anything at all.
c2 = none; c2.counterExpiredNotKept = ~mac.keepDecision(g.keepDraw, 0.4);
assert(~mac.reselectionTrigger(c2), 'grant lifecycle: counter==0 alone is NOT a trigger when the keep draw succeeded');

% sl-ReselectAfter counts unused PERIODS, and any single use resets the streak.
g2 = mac.grantSelect(mac.grantInit(), [10 12], [0 0], 1, 100, true, 5);
[g2, ~] = mac.grantOnPeriodEnd(g2, 0.5);
[g2, ~] = mac.grantOnPeriodEnd(g2, 0.5);
assert(g2.consecutiveUnusedPeriods == 2, 'grantOnPeriodEnd: two wholly unused periods must give a streak of 2, got %d', g2.consecutiveUnusedPeriods);
g2 = mac.grantOnTransmission(g2, 2);   % one use, on a retransmission opportunity
[g2, ~] = mac.grantOnPeriodEnd(g2, 0.5);
assert(g2.consecutiveUnusedPeriods == 0, 'grantOnPeriodEnd: using ANY one opportunity in a period must reset the streak (clause 5.22.1.2 increments only when NONE is used)');

% A counter drawn outside creselCounterRange's interval must be refused.
try
    mac.grantSelect(mac.grantInit(), [10 12], [0 0], 1, 100, true, 20);
    error('test_macSidelink:shouldHaveErrored', 'grantSelect should reject a counter outside the clause-5.22.1.1 draw range');
catch e
    assert(strcmp(e.identifier, 'mac:grantSelect:counterOutOfRange'), 'grantSelect: wrong error for an out-of-range counter');
end
% An aperiodic grant has no counter at all.
gA = mac.grantSelect(mac.grantInit(), 30, 1, 1, 0, false, 0);
assert(mac.cresel(gA.counter, gA.isPeriodic) == 1, 'grantSelect: an aperiodic grant must yield C_resel = 1');
[gA, hitZeroA] = mac.grantOnPeriodEnd(gA, 0.5);
assert(gA.counter == 0 && ~hitZeroA, 'grantOnPeriodEnd: an aperiodic grant maintains no counter, so nothing decrements and nothing "hits zero"');
% Clearing is total.
gC = mac.grantClear(g2);
assert(~gC.hasGrant && gC.counter == 0 && gC.consecutiveUnusedPeriods == 0, 'grantClear: clearing must drop the resources, the counter and the sl-ReselectAfter streak together');

%% slLcpBucket -- clause 5.22.1.4.1.1
Sbj = mac.slLcpBucket([0 0], [100 100], [0.5 0.1], 0.2);
assert(abs(Sbj(1) - 20) < tol, 'slLcpBucket: 100 bytes/s over 0.2 s is 20 bytes, under the 50-byte bucket');
assert(abs(Sbj(2) - 10) < tol, 'slLcpBucket: the same increment capped at the 100*0.1 = 10-byte bucket, got %g', Sbj(2));
% The cap is what makes a long idle stretch not hand over the whole grant.
SbjLong = mac.slLcpBucket(0, 100, 0.5, 1000);
assert(abs(SbjLong - 50) < tol, 'slLcpBucket: a long idle period must still cap at sPBR*sBSD = 50, got %g', SbjLong);
% A negative bucket (left by the second allocation pass) refills normally.
SbjNeg = mac.slLcpBucket(-30, 100, 0.5, 0.2);
assert(abs(SbjNeg - (-10)) < tol, 'slLcpBucket: -30 + 20 = -10; a negative bucket is legal and refills');
% Inf sPBR must not produce NaN via Inf*0.
SbjInf = mac.slLcpBucket(0, Inf, 0.5, 0);
assert(isinf(SbjInf) && ~isnan(SbjInf), 'slLcpBucket: an infinite sPBR with zero elapsed time must give Inf, not NaN');

%% slLcp -- clauses 5.22.1.4.1.2 / 5.22.1.4.1.3
% Three channels, all eligible, same HARQ-feedback setting, 400-byte grant:
%   A prio 1, SBj  100, data 500
%   B prio 2, SBj   50, data 500
%   C prio 3, SBj  -20, data 500
% Selection filters to SBj > 0 (A and B qualify, so the filter applies and C is dropped).
% Pass 1 serves A up to its 100 and B up to its 50 -> 150 spent, 250 left, and SBj is decremented
% by THAT only. Pass 2 then serves in strict priority order regardless of SBj: A takes the
% remaining 250. So A=350, B=50, C=0, and SBj ends [0 0 -20].
[alloc, SbjOut, selected] = mac.slLcp([100 50 -20], [1 2 3], [500 500 500], [true true true], [true true true], 400);
% All three are SELECTED. Clause 5.22.1.4.1.2's "SBj > 0" condition is in the DESTINATION-
% selection bullet list, not the logical-channel one, so C survives selection despite SBj < 0 --
% it simply wins nothing in pass 1. Dropping it here starves it permanently and under-fills large
% grants; the 2000-byte case below is what makes that visible.
assert(isequal(selected, logical([1 1 1])), 'slLcp: clause 5.22.1.4.1.2 has no SBj condition in its logical-channel-selection list, so an SBj<0 channel of the selected Destination is still selected, got [%s]', num2str(selected));
assert(abs(alloc(1) - 350) < tol && abs(alloc(2) - 50) < tol && alloc(3) == 0, 'slLcp: expected allocation [350 50 0], got [%s]', num2str(alloc));
assert(sum(alloc) == 400, 'slLcp: the whole grant must be used when data is available, got %g', sum(alloc));
assert(abs(SbjOut(1)) < tol && abs(SbjOut(2)) < tol && abs(SbjOut(3) - (-20)) < tol, 'slLcp: SBj must be decremented by the FIRST pass only -- expected [0 0 -20], got [%s]. A(350) would mean pass 2 was charged to the bucket too', num2str(SbjOut));

% Grant far larger than the sPBR round: pass 2 must reach EVERY selected channel, including the
% negative-bucket one. This is the case that discriminates a correct selection from one that
% filtered on SBj -- the filtered version would allocate only 1000 of the 2000 bytes and give C
% nothing at all.
[allocBig, SbjBig, selBig] = mac.slLcp([100 50 -20], [1 2 3], [500 500 500], [true true true], [true true true], 2000);
assert(all(selBig), 'slLcp: a large grant must still select all three channels');
assert(isequal(allocBig, [500 500 500]), 'slLcp: with 2000 bytes every channel''s 500 bytes of data must be served, got [%s] -- [500 500 0] means the SBj<0 channel was wrongly filtered out at selection', num2str(allocBig));
assert(abs(SbjBig(1)) < tol && abs(SbjBig(2)) < tol && abs(SbjBig(3) - (-20)) < tol, 'slLcp: even serving 500 bytes to A, only its 100-byte pass-1 share is charged, so SBj must end [0 0 -20], got [%s]', num2str(SbjBig));

% Pass 1 truncated by the grant: B is grant-limited to 20 of its 50-byte entitlement, so its
% bucket must be charged 20, not 50, and must retain 30.
[allocT, SbjT, ~] = mac.slLcp([100 50 -20], [1 2 3], [500 500 500], [true true true], [true true true], 120);
assert(isequal(allocT, [100 20 0]), 'slLcp: a 120-byte grant gives A its 100 and B the remaining 20, got [%s]', num2str(allocT));
assert(abs(SbjT(2) - 30) < tol, 'slLcp: B was served only 20 bytes, so its bucket must retain 50-20 = 30, got %g', SbjT(2));
% sl-Priority is inverted: 1 is the HIGHEST. If the order were read as descending numeric, C
% would be served first. Give only C a positive bucket and check A still wins pass 2.
[allocP, ~, ~] = mac.slLcp([10 10 10], [1 2 3], [1000 1000 1000], [true true true], [true true true], 100);
assert(allocP(1) > allocP(3), 'slLcp: sl-Priority 1 is the HIGHEST priority, so channel A must be served before C');
assert(abs(allocP(1) - 80) < tol, 'slLcp: pass 1 gives 10/10/10, then pass 2 gives A the remaining 70, expected A=80, got %g', allocP(1));
% Every bucket negative: pass 1 allocates nothing, but pass 2 serves "regardless of the value of
% SBj", so the UE still transmits. A UE that could not transmit here would be permanently stuck,
% since SBj is only replenished by sPBR x T and nothing would ever spend it.
[allocE, SbjE, selE] = mac.slLcp([-5 -5], [1 2], [100 100], [true true], [true true], 60);
assert(all(selE), 'slLcp: an all-negative-bucket UE must still select its channels');
assert(isequal(allocE, [60 0]), 'slLcp: pass 2 serves in strict priority order, so the highest-priority channel takes the whole 60-byte grant, got [%s]', num2str(allocE));
assert(isequal(SbjE, [-5 -5]), 'slLcp: pass 2 allocations are never charged to the buckets, so SBj must be unchanged at [-5 -5], got [%s]', num2str(SbjE));
% HARQ-feedback exclusivity: the highest-priority channel decides, the mismatched one is dropped.
[allocH, ~, selH] = mac.slLcp([100 100], [1 2], [500 500], [true false], [true true], 300);
assert(isequal(selH, logical([1 0])), 'slLcp: a logical channel whose sl-HARQ-FeedbackEnabled differs from the highest-priority selected channel cannot be multiplexed into the same MAC PDU');
assert(allocH(2) == 0 && abs(allocH(1) - 300) < tol, 'slLcp: the dropped channel gets nothing and the whole grant goes to the compatible one');
% ...and the winner is decided by PRIORITY, not by position: same test with the disabled channel
% at the higher priority flips which survives.
[~, ~, selH2] = mac.slLcp([100 100], [2 1], [500 500], [true false], [true true], 300);
assert(isequal(selH2, logical([0 1])), 'slLcp: the HARQ-feedback value is taken from the highest-priority channel, not the first one');

%% muxSlSch -- clauses 6.1.6, 6.2.4, 6.1.3.35
% SRC carries the 16 MSB of a 24-bit Source L2 ID, DST the 8 MSB of the Destination L2 ID.
srcId = hex2dec('ABCDEF'); dstId = hex2dec('123456');
[pduBits, nPad, nSdu] = mac.muxSlSch(srcId, dstId, [1 2 3], 3, 4, true, 1, 5, 16);
assert(numel(pduBits) == 16 * 8, 'muxSlSch: the PDU must be padded to exactly pduSizeBytes, expected 128 bits, got %d', numel(pduBits));
octets = bitsToOctets(pduBits);
assert(octets(1) == 0, 'muxSlSch: octet 1 is V(4)|R R R R, and clause 6.2.4 sets V to 0 in this version');
assert(octets(2) == hex2dec('AB') && octets(3) == hex2dec('CD'), 'muxSlSch: SRC must be the 16 MOST significant bits of the Source L2 ID (0xABCD from 0xABCDEF), got 0x%02X%02X', octets(2), octets(3));
assert(octets(4) == hex2dec('12'), 'muxSlSch: DST must be the 8 MOST significant bits of the Destination L2 ID (0x12 from 0x123456), got 0x%02X', octets(4));
assert(octets(5) == 4, 'muxSlSch: the SDU subheader is R(1)|F(1)|LCID(6); a 3-byte SDU on LCID 4 gives F=0 and octet 0x04, got 0x%02X', octets(5));
assert(octets(6) == 3, 'muxSlSch: an F=0 subheader carries an 8-bit L field, expected 3');
assert(isequal(octets(7:9), [1 2 3]), 'muxSlSch: the SDU payload must follow its subheader');
assert(octets(10) == 62, 'muxSlSch: the Sidelink CSI Reporting MAC CE takes the fixed-size R(2)|LCID(6) subheader with LCID 62, got 0x%02X', octets(10));
assert(octets(11) == 168, 'muxSlSch: the CSI MAC CE octet is RI(1)|CQI(4)|R(3); RI=1, CQI=5 gives 128+40 = 168, got %d', octets(11));
assert(octets(12) == 63, 'muxSlSch: the padding subheader is R(2)|LCID(6) with LCID 63, got 0x%02X', octets(12));
assert(nPad == 4 && all(octets(13:16) == 0), 'muxSlSch: expected 4 padding octets after the padding subheader, got %d', nPad);
assert(nSdu == 1, 'muxSlSch: one SDU was supplied');
% An exact fit needs no padding subPDU at all ("the size of padding can be zero").
[bitsExact, nPadExact] = mac.muxSlSch(srcId, dstId, [1 2 3], 3, 4, true, 1, 5, 11);
assert(numel(bitsExact) == 11 * 8 && nPadExact == 0, 'muxSlSch: content filling the TB exactly must emit no padding subheader');
% One spare octet is consumed entirely by the padding subheader, leaving zero padding bytes.
[~, nPadOne] = mac.muxSlSch(srcId, dstId, [1 2 3], 3, 4, true, 1, 5, 12);
assert(nPadOne == 0, 'muxSlSch: a single spare octet becomes the padding subheader itself, with zero padding bytes');
% F is fixed by the SDU size, not free: 256 bytes crosses to a 16-bit L field.
big = ones(1, 256);
[bitsBig, ~] = mac.muxSlSch(srcId, dstId, big, 256, 4, false, 0, 0, 300);
octBig = bitsToOctets(bitsBig);
assert(bitand(octBig(5), 64) == 64, 'muxSlSch: a 256-byte SDU must set F=1 (clause 6.2.4: F=0 only below 256 bytes)');
assert(octBig(6) == 1 && octBig(7) == 0, 'muxSlSch: an F=1 subheader carries a 16-bit L field, 256 = 0x0100');
% Two SDUs keep LCP order, and the CE follows all of them.
[bits2, ~] = mac.muxSlSch(srcId, dstId, [9 9 8 8 8], [2 3], [4 5], true, 0, 3, 20);
oct2 = bitsToOctets(bits2);
assert(oct2(5) == 4 && oct2(6) == 2 && isequal(oct2(7:8), [9 9]), 'muxSlSch: the first SDU subPDU must come first');
assert(oct2(9) == 5 && oct2(10) == 3 && isequal(oct2(11:13), [8 8 8]), 'muxSlSch: the second SDU subPDU must follow the first');
assert(oct2(14) == 62, 'muxSlSch: clause 6.1.6 places the MAC CE after ALL MAC SDU subPDUs');
% Clause 5.22.1.4.1.3 forbids a PDU with no SDUs and no CSI CE.
try
    mac.muxSlSch(srcId, dstId, zeros(1, 0), zeros(1, 0), zeros(1, 0), false, 0, 0, 16);
    error('test_macSidelink:shouldHaveErrored', 'muxSlSch should refuse a PDU with zero SDUs and no CSI MAC CE');
catch e
    assert(strcmp(e.identifier, 'mac:muxSlSch:emptyPdu'), 'muxSlSch: wrong error for an empty PDU');
end
try
    mac.muxSlSch(srcId, dstId, [1 2 3], 3, 63, false, 0, 0, 16);
    error('test_macSidelink:shouldHaveErrored', 'muxSlSch should reject the padding LCID as an SDU LCID');
catch e
    assert(strcmp(e.identifier, 'mac:muxSlSch:badLcid'), 'muxSlSch: wrong error for a reserved LCID');
end
try
    mac.muxSlSch(srcId, dstId, [1 2 3], 3, 4, false, 0, 0, 5);
    error('test_macSidelink:shouldHaveErrored', 'muxSlSch should reject content larger than the transport block');
catch e
    assert(strcmp(e.identifier, 'mac:muxSlSch:overflow'), 'muxSlSch: wrong error for overflow');
end

%% HARQ entity -- clauses 5.22.1.3.1, 5.22.1.3.1a, 5.22.1.3.3
% Two process limits, and the mode-2 periodic one is the smaller.
h = mac.harqInit(16, false);
assert(h.nProcesses == 16, 'harqInit: 16 processes are allowed in the general case');
h4 = mac.harqInit(4, true);
assert(h4.nProcesses == 4, 'harqInit: 4 processes for multiple-MAC-PDU mode 2');
try
    mac.harqInit(5, true);
    error('test_macSidelink:shouldHaveErrored', 'harqInit should cap multiple-MAC-PDU mode 2 at 4 processes');
catch e
    assert(strcmp(e.identifier, 'mac:harqInit:badCount'), 'harqInit: wrong error for exceeding the mode-2 periodic limit');
end
try
    mac.harqInit(17, false);
    error('test_macSidelink:shouldHaveErrored', 'harqInit should cap the general case at 16 processes');
catch e
    assert(strcmp(e.identifier, 'mac:harqInit:badCount'), 'harqInit: wrong error for exceeding 16');
end

rvSeq = [0 2 3 1];
h = mac.harqInit(4, true);
% The NDI TOGGLES per initial transmission; it is not set to a constant. Note what is NOT
% asserted: the absolute value of the FIRST NDI. Clause 5.22.1.3.1 NOTE 2 leaves "the initial
% value of the NDI set to the very first transmission for the associated Sidelink process" to UE
% implementation, so pinning it would over-constrain the spec. Only the toggle relation between
% consecutive initial transmissions is normative, and that is what the ndi1 != ndi2 check below
% asserts.
[h, ndi1, rv1] = mac.harqNewTransmission(h, 1, rvSeq, -1, true);
assert(islogical(ndi1) && rv1 == 0, 'harqNewTransmission: the first initial transmission takes rvSequence(1) and reports a logical NDI');
assert(h.bufferOccupied(1) && h.txCount(1) == 1, 'harqNewTransmission: the HARQ buffer must hold the TB after an initial transmission');
% Retransmissions walk the RV sequence and wrap rather than running off the end.
[h, rvA, ignA] = mac.harqRetransmission(h, 1, rvSeq);
[h, rvB, ~] = mac.harqRetransmission(h, 1, rvSeq);
[h, rvC, ~] = mac.harqRetransmission(h, 1, rvSeq);
[h, rvD, ~] = mac.harqRetransmission(h, 1, rvSeq);
assert(~ignA && isequal([rvA rvB rvC rvD], [2 3 1 0]), 'harqRetransmission: the RV sequence must be walked in order and wrap, expected [2 3 1 0], got [%s]', num2str([rvA rvB rvC rvD]));
assert(h.txCount(1) == 5, 'harqRetransmission: each retransmission counts toward sl-MaxTransNum, expected 5 transmissions, got %d', h.txCount(1));
% A positive acknowledgement flushes the buffer.
[h, flushed, rlf] = mac.harqOnFeedback(h, 1, true, true, 0, 0);
assert(flushed && ~h.bufferOccupied(1) && ~rlf, 'harqOnFeedback: a positive acknowledgement must flush the HARQ buffer');
% A retransmission grant for a flushed process is IGNORED, not an error -- it happens routinely
% when the grant was selected before the ACK arrived.
[h, rvIgn, ignored] = mac.harqRetransmission(h, 1, rvSeq);
assert(ignored && rvIgn == -1, 'harqRetransmission: a grant for a process with an empty HARQ buffer must be ignored (clause 5.22.1.3.1), not raised');
% The next initial transmission toggles the NDI back.
[h, ndi2, ~] = mac.harqNewTransmission(h, 1, rvSeq, -1, true);
assert(ndi2 ~= ndi1, 'harqNewTransmission: the NDI must TOGGLE between consecutive initial transmissions on a process, not be set to a constant (clause 5.22.1.3.1). Its absolute first value is UE implementation per NOTE 2 and is deliberately not asserted');

% harqFlush -- clause 5.22.1.3.1's fourth flush condition: an initial-transmission grant for
% which the multiplexing entity produced no MAC PDU. Not feedback-driven, so it is its own path.
hF = mac.harqInit(2, false);
[hF, ~, ~] = mac.harqNewTransmission(hF, 2, rvSeq, -1, true);
assert(hF.bufferOccupied(2), 'harqFlush setup: the buffer should be occupied before the flush');
hF = mac.harqFlush(hF, 2);
assert(~hF.bufferOccupied(2) && hF.txCount(2) == 0 && hF.harqProcessId(2) == -1, 'harqFlush: the buffer, transmission count and HARQ Process ID association must all be cleared');
ndiBefore = hF.ndi(2);
hF = mac.harqFlush(hF, 2);
assert(hF.ndi(2) == ndiBefore, 'harqFlush: flushing must NOT reset the NDI -- it is a running parity across TBs, not per-buffer state');
[~, rvAfterFlush, ignAfterFlush] = mac.harqRetransmission(hF, 2, rvSeq);
assert(ignAfterFlush && rvAfterFlush == -1, 'harqFlush: a retransmission grant after a flush must be ignored, so a stale TB cannot be resurrected');
% sl-MaxTransNum flushes even without an ACK; 0 means not configured.
h2 = mac.harqInit(2, false);
[h2, ~, ~] = mac.harqNewTransmission(h2, 1, rvSeq, -1, false);
[h2, ~, ~] = mac.harqRetransmission(h2, 1, rvSeq);
[h2, flushedNo, ~] = mac.harqOnFeedback(h2, 1, false, true, 0, 0);
assert(~flushedNo, 'harqOnFeedback: with sl-MaxTransNum unconfigured (0) a NACK must not flush');
[h2, flushedMax, ~] = mac.harqOnFeedback(h2, 1, false, true, 2, 0);
assert(flushedMax, 'harqOnFeedback: reaching sl-MaxTransNum must flush the buffer even without an acknowledgement');

% RLF detection counts DTX -- absence of PSFCH -- and resets on ANY reception, NACK included.
h3 = mac.harqInit(1, false);
[h3, ~, ~] = mac.harqNewTransmission(h3, 1, rvSeq, -1, true);
[h3, ~, rlf1] = mac.harqOnFeedback(h3, 1, false, false, 0, 3);
[h3, ~, rlf2] = mac.harqOnFeedback(h3, 1, false, false, 0, 3);
assert(~rlf1 && ~rlf2 && h3.numConsecutiveDTX == 2, 'harqOnFeedback: two DTX occasions must give numConsecutiveDTX 2 without declaring RLF');
% A received NACK is not a DTX: the peer is demonstrably alive, so the streak resets.
[h3, ~, ~] = mac.harqOnFeedback(h3, 1, false, true, 0, 3);
assert(h3.numConsecutiveDTX == 0, 'harqOnFeedback: numConsecutiveDTX must reset on ANY PSFCH reception, including a NACK -- resetting only on ACK turns a lossy link into a false RLF');
[h3, ~, ~] = mac.harqOnFeedback(h3, 1, false, false, 0, 3);
[h3, ~, ~] = mac.harqOnFeedback(h3, 1, false, false, 0, 3);
[h3, ~, rlfHit] = mac.harqOnFeedback(h3, 1, false, false, 0, 3);
assert(rlfHit && h3.numConsecutiveDTX == 3, 'harqOnFeedback: RLF must be indicated on the occasion the counter REACHES sl-maxNumConsecutiveDTX');
[h3, ~, rlfAgain] = mac.harqOnFeedback(h3, 1, false, false, 0, 3);
assert(~rlfAgain, 'harqOnFeedback: RLF must be indicated once, on the crossing, not on every subsequent DTX');

%% reevaluation -- clause 5.22.1.2a
% Grant of two resources; neither yet signalled. Slot 20 is still in S_A, slot 30 has dropped out.
candY = [20 25 30];
candX = [0 0 0];
survivor = logical([1 1 0]);
T3 = phy.ts38214.procTimeSelection(0);
[needs, checked] = mac.reevaluation([20 30], [0 0], [false false], 40, T3, candY, candX, survivor);
assert(all(checked), 'reevaluation: both resources are past their m - T3 point at slot 40');
assert(isequal(needs, logical([0 1])), 'reevaluation: only the resource that has dropped out of S_A must be flagged, got [%s]', num2str(needs));
% A resource already announced by a prior SCI is pre-emption's business, never re-evaluation's.
[needsSig, checkedSig] = mac.reevaluation([30], [0], [true], 40, T3, candY, candX, survivor);
assert(~needsSig && ~checkedSig, 'reevaluation: an already-signalled resource must not be checked here (clause 5.22.1.2a scopes re-evaluation to resources NOT identified by a prior SCI)');
% Before m - T3 the check has not come due.
[~, checkedEarly] = mac.reevaluation([30], [0], [false], 30 - T3 - 1, T3, candY, candX, survivor);
assert(~checkedEarly, 'reevaluation: a resource must not be checked before its m - T3 point');
[~, checkedDue] = mac.reevaluation([30], [0], [false], 30 - T3, T3, candY, candX, survivor);
assert(checkedDue, 'reevaluation: the check becomes due exactly at m - T3');

%% preemption -- clause 5.22.1.2a + TS 38.214 clause 8.1.4
thr = -110 * ones(1, 64);
db = phy.ts38214.sensingDbInit();
% A higher-priority (numerically smaller) reservation overlapping our slot 30, well above Th.
db = phy.ts38214.sensingDbRecord(db, 30, 0, 2, 2, -80, false, 0, 1, 0, 0, 0, 0);
[pre, checkedP] = mac.preemption(30, 0, 2, true, 4, 40, T3, db, thr, 0, 'enabled');
assert(checkedP && pre, 'preemption: a higher-priority overlapping reservation above the RSRP threshold must pre-empt');
% Not yet signalled -> re-evaluation's set, not this one.
[preUnsig, checkedUnsig] = mac.preemption(30, 0, 2, false, 4, 40, T3, db, thr, 0, 'enabled');
assert(~preUnsig && ~checkedUnsig, 'preemption: a resource not yet indicated by a prior SCI is out of scope here');
% EQUAL priority must NOT pre-empt. If it did, two same-priority UEs would pre-empt each other
% forever and neither would transmit -- the livelock this strict comparison exists to prevent.
dbEq = phy.ts38214.sensingDbInit();
dbEq = phy.ts38214.sensingDbRecord(dbEq, 30, 0, 2, 4, -80, false, 0, 1, 0, 0, 0, 0);
assert(~mac.preemption(30, 0, 2, true, 4, 40, T3, dbEq, thr, 0, 'enabled'), 'preemption: an EQUAL-priority reservation must not pre-empt (the comparison is strict)');
% Lower priority (numerically larger) must not pre-empt either.
dbLo = phy.ts38214.sensingDbInit();
dbLo = phy.ts38214.sensingDbRecord(dbLo, 30, 0, 2, 6, -80, false, 0, 1, 0, 0, 0, 0);
assert(~mac.preemption(30, 0, 2, true, 4, 40, T3, dbLo, thr, 0, 'enabled'), 'preemption: a lower-priority reservation must not pre-empt');
% Higher priority but below the threshold must not pre-empt.
dbWeak = phy.ts38214.sensingDbInit();
dbWeak = phy.ts38214.sensingDbRecord(dbWeak, 30, 0, 2, 2, -120, false, 0, 1, 0, 0, 0, 0);
assert(~mac.preemption(30, 0, 2, true, 4, 40, T3, dbWeak, thr, 0, 'enabled'), 'preemption: a reservation whose SL-RSRP is below Th must not pre-empt');
% The escalated offset candidateSet converged on must be honoured: +50 dB lifts Th above the
% -80 dBm reservation and the pre-emption disappears.
assert(~mac.preemption(30, 0, 2, true, 4, 40, T3, db, thr, 50, 'enabled'), 'preemption: candidateSet''s final threshold offset must be applied -- a +50 dB offset lifts Th above -80 dBm');
% No frequency overlap -> no pre-emption, even at higher priority and above Th.
assert(~mac.preemption(30, 5, 2, true, 4, 40, T3, db, thr, 0, 'enabled'), 'preemption: a reservation that does not overlap in sub-channel must not pre-empt');
% A clause-8.1.5 chained resource pre-empts just as the anchor does.
dbChain = phy.ts38214.sensingDbInit();
dbChain = phy.ts38214.sensingDbRecord(dbChain, 20, 0, 2, 2, -80, false, 0, 2, 10, 0, 0, 0);
assert(mac.preemption(30, 0, 2, true, 4, 40, T3, dbChain, thr, 0, 'enabled'), 'preemption: a TRIV/FRIV-chained resource (slot 20 + t1 10 = 30) must pre-empt like an anchor');

% sl-PreemptionEnable is a THREE-way gate, not a boolean. Both of TS 38.214 clause 8.1.4's
% pre-emption bullets begin "sl-PreemptionEnable is provided", so with the field ABSENT nothing is
% ever pre-empted -- even the case that pre-empts under 'enabled'.
[preOff, checkedOff] = mac.preemption(30, 0, 2, true, 4, 40, T3, db, thr, 0, '');
assert(~preOff && ~checkedOff, 'preemption: with sl-PreemptionEnable not provided, no resource may be reported for pre-emption');
% ...while re-evaluation carries no such gate and is unaffected.
[~, checkedReev] = mac.reevaluation(30, 0, false, 40, T3, candY, candX, survivor);
assert(checkedReev, 'reevaluation: sl-PreemptionEnable does not gate re-evaluation');
% The 'plN' branch adds a SECOND strict test, prio_RX < prio_pre. Our sensed reservation is
% priority 2 against own priority 4: it pre-empts under 'pl3' (2 < 3) but not under 'pl2'
% (2 < 2 is false), even though it is higher priority than us in both cases.
assert(mac.preemption(30, 0, 2, true, 4, 40, T3, db, thr, 0, 'pl3'), 'preemption: prio_RX=2 < prio_pre=3 and prio_TX=4 > prio_RX=2, so ''pl3'' must pre-empt');
assert(~mac.preemption(30, 0, 2, true, 4, 40, T3, db, thr, 0, 'pl2'), 'preemption: prio_RX < prio_pre is STRICT, so prio_RX=2 against ''pl2'' must NOT pre-empt despite being higher priority than us');
try
    mac.preemption(30, 0, 2, true, 4, 40, T3, db, thr, 0, 'yes');
    error('test_macSidelink:shouldHaveErrored', 'preemption should reject an sl-PreemptionEnable label outside the enum');
catch e
    assert(strcmp(e.identifier, 'mac:preemption:badPreemptionEnable'), 'preemption: wrong error for a bad sl-PreemptionEnable label');
end

fprintf('test_macSidelink: PASS\n');
end

function octets = bitsToOctets(bits)
%bitsToOctets Inverse of muxSlSch's MSB-first octet expansion, for readable assertions.
n = numel(bits) / 8;
octets = zeros(1, n);
for i = 1:n
    v = 0;
    for b = 1:8
        v = v * 2 + bits((i - 1) * 8 + b);
    end
    octets(i) = v;
end
end
