function test_rlcRxBuf()
%test_rlcRxBuf The shared reception buffer's byte-segment predicates.
%SPEC: TS 38.322 V16.3.0 clauses 5.2.2.2.3, 5.2.3.2.2, 5.2.3.2.3, 5.3.4 -- "all byte segments
%      received", "byte segment numbers y to z ... received before", "discard the duplicate
%      byte segments", "at least one missing byte segment ... before the last byte of all
%      received segments", and the missing runs a STATUS PDU reports.
%Level 1: hand-computed expectations on small cases; no independent verification.

b = rlc.rxBufInit();
assert(~rlc.rxBufComplete(b, 5) && ~rlc.rxBufMissingBeforeLast(b, 5), 'empty buffer');
[g0, g1] = rlc.rxBufGaps(b, 5);
assert(isequal(g0, 0) && isequal(g1, -1), 'nothing held is one open gap from byte 0');

% SDU 5 is 30 bytes: receive 0..9 then 20..29 (last).
[b, n] = rlc.rxBufInsert(b, 5, 0, 1:10, false);
assert(n == 10 && ~rlc.rxBufMissingBeforeLast(b, 5), ...
    'a missing TAIL is not a hole "before the last byte of all received segments"');
[g0, g1] = rlc.rxBufGaps(b, 5);
assert(isequal(g0, 10) && isequal(g1, -1), 'tail missing, SDU length unknown -> SOend 0xFFFF run');
[b, n] = rlc.rxBufInsert(b, 5, 20, 21:30, true);
assert(n == 10 && rlc.rxBufMissingBeforeLast(b, 5) && ~rlc.rxBufComplete(b, 5), 'bytes 10..19 are a hole');
[g0, g1] = rlc.rxBufGaps(b, 5);
assert(isequal(g0, 10) && isequal(g1, 19), 'one closed gap once the last byte is known');
assert(rlc.rxBufCovered(b, 5, 0, 9) && rlc.rxBufCovered(b, 5, 22, 25) && ~rlc.rxBufCovered(b, 5, 5, 12), ...
    'rxBufCovered is true only when EVERY byte is held');

% A retransmission covering 5..24 straddles both held runs: only 10..19 is new.
[b, n] = rlc.rxBufInsert(b, 5, 5, 6:25, false);
assert(n == 10, 'only the missing bytes are stored, got %d', n);
assert(rlc.rxBufComplete(b, 5), 'SDU 5 is complete');
assert(isequal(rlc.rxBufAssemble(b, 5), 1:30), 'reassembled by SO, not by arrival order');

% Out-of-order arrival: last segment first, and the length is only known from it.
[b, ~] = rlc.rxBufInsert(b, 9, 4, [50 51], true);
assert(~rlc.rxBufComplete(b, 9) && rlc.rxBufMissingBeforeLast(b, 9), 'SDU 9 missing 0..3');
[b, ~] = rlc.rxBufInsert(b, 9, 0, [46 47 48 49], false);
assert(rlc.rxBufComplete(b, 9) && isequal(rlc.rxBufAssemble(b, 9), 46:51), 'SDU 9 assembled');
% Contiguous-from-zero is NOT complete without a last-byte marker.
[b, ~] = rlc.rxBufInsert(b, 11, 0, 1:40, false);
assert(~rlc.rxBufComplete(b, 11), 'no Data field has claimed the last byte, so the length is unknown');

% A whole duplicate adds nothing, and a duplicate carrying the last-byte marker moves it on.
[b, n] = rlc.rxBufInsert(b, 11, 30, 31:40, false);
assert(n == 0, 'a pure duplicate adds 0 bytes');
[b, n] = rlc.rxBufInsert(b, 11, 30, 31:40, true);
assert(n == 0 && rlc.rxBufComplete(b, 11), 'the last-byte marker must survive a fully-duplicate Data field');

assert(isequal(sort(rlc.rxBufSnList(b)), [5 9 11]), 'rxBufSnList');
b = rlc.rxBufDrop(b, 9);
assert(isequal(sort(rlc.rxBufSnList(b)), [5 11]) && isequal(rlc.rxBufAssemble(b, 5), 1:30) && ...
    isequal(rlc.rxBufAssemble(b, 11), 1:40), 'dropping one SN leaves the others byte-exact');

% Several holes, reported in byte order.
b = rlc.rxBufInit();
b = rlc.rxBufInsert(b, 0, 3, 1:2, false);      % 3..4
b = rlc.rxBufInsert(b, 0, 10, 1:5, false);     % 10..14
b = rlc.rxBufInsert(b, 0, 7, 1, false);        % 7
[g0, g1] = rlc.rxBufGaps(b, 0);
assert(isequal(g0, [0 5 8 15]) && isequal(g1, [2 6 9 -1]), 'gaps in byte order, open at the unknown end');
end
