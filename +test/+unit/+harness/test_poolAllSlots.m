function test_poolAllSlots()
%test_poolAllSlots Unit tests for harness.poolAllSlots, the baseline all-sidelink pool.
%SPEC: harness.poolAllSlots is a scenario choice, not a procedure. What is asserted is that it
%      really does mean "every slot", at every numerology -- and, in the last block, that the
%      identity it produces is a property of THIS configuration and not of the mapping.

%% ---- every slot, at every numerology ------------------------------------
for mu = 0:3
    nDfnSlots = 10240 * 2^mu;
    [po, lo, Tp] = harness.poolAllSlots(mu);
    assert(Tp == nDfnSlots, 'poolAllSlots: mu=%d must give all %d slots, got %d', mu, nDfnSlots, Tp);
    assert(isequal(po, 0:nDfnSlots - 1), 'poolAllSlots: mu=%d must be the identity map', mu);
    assert(isequal(lo, 0:nDfnSlots - 1), 'poolAllSlots: mu=%d inverse must be the identity too', mu);
    assert(~any(lo < 0), 'poolAllSlots: no slot may be outside the pool in the baseline');
end

%% ---- the bitmap length is load-bearing ----------------------------------
% The point of pinning L_bitmap = 10: an all-ones bitmap is NOT sufficient on its own. Clause
% 8's reserved rule removes (L mod L_bitmap) slots before the bitmap is applied, so a length
% that does not divide 10240*2^mu silently loses slots from a fully-sidelink period.
mu   = 1;
N    = 10240 * 2^mu;
none = false(1, N);
for Lbitmap = [10 16 20 40 160]
    [~, ~, Tp] = phy.ts38214.poolSlotMap(mu, none, none, true(1, Lbitmap));
    assert(mod(N, Lbitmap) == 0, 'test setup: %d must divide %d', Lbitmap, N);
    assert(Tp == N, 'a dividing L_bitmap=%d must keep all %d slots, got %d', Lbitmap, N, Tp);
end
for Lbitmap = [11 12 30 50 60 100]
    [~, ~, Tp] = phy.ts38214.poolSlotMap(mu, none, none, true(1, Lbitmap));
    assert(mod(N, Lbitmap) ~= 0, 'test setup: %d must NOT divide %d', Lbitmap, N);
    assert(Tp == N - mod(N, Lbitmap), 'a non-dividing L_bitmap=%d must lose exactly %d slots, got T''max %d', Lbitmap, mod(N, Lbitmap), Tp);
    assert(Tp < N, 'a non-dividing L_bitmap=%d must lose slots even with an all-ones bitmap', Lbitmap);
end
% The worst of the likely lengths, named: 100 at mu=1 loses 80 slots from a fully-sidelink DFN
% period, with nothing reporting it. This is the case poolAllSlots exists to prevent.
[~, ~, Tp100] = phy.ts38214.poolSlotMap(mu, none, none, true(1, 100));
assert(Tp100 == 20400, 'L_bitmap=100 at mu=1 must lose 80 slots, giving 20400, got %d', Tp100);

%% ---- excluding ONE slot removes TEN ------------------------------------
% The baseline is balanced on a knife edge, and this is the sharpest way to show it. Exclude a
% single S-SSB slot and L becomes 20479, so N_reserved goes from 0 to 20479 mod 10 = 9, and the
% reserved rule removes nine MORE slots spread across the period. One exclusion, ten fewer pool
% slots -- and because r starts at m=0, physical slot 0 is one of the casualties, so the map
% stops being the identity from its very first entry rather than from slot 160.
ssb1 = false(1, N); ssb1(160 + 1) = true;
[po1, lo1, Tp1] = phy.ts38214.poolSlotMap(mu, ssb1, false(1, N), true(1, 10));
assert(Tp1 == N - 10, 'excluding one slot must cost ten: 1 excluded + 9 newly reserved, expected %d, got %d', N - 10, Tp1);
assert(mod(N - 1, 10) == 9, 'test setup: L = %d must leave N_reserved = 9', N - 1);
assert(lo1(0 + 1) == -1, 'with N_reserved > 0, l_0 (physical slot 0) is reserved and leaves the pool');
assert(po1(1) ~= 0, 'the map must NOT be the identity once any slot is excluded');

%% ---- the identity is a property of the CONFIG, not of the mapping -------
% If a caller drops the logical-to-physical conversion, the baseline still looks right, and
% breaks the moment a real S-SSB or TDD pattern arrives. Excluding ten slots keeps L divisible
% by 10, so N_reserved stays 0 and the ONLY change is the ten exclusions -- which isolates the
% shift and shows exactly what a dropped conversion would get wrong.
ssb = false(1, N);
excluded = 160 * (1:10);                       % ten slots, 160 apart
ssb(excluded + 1) = true;
[poS, loS, TpS] = phy.ts38214.poolSlotMap(mu, ssb, false(1, N), true(1, 10));
assert(mod(N - 10, 10) == 0, 'test setup: L must stay divisible by L_bitmap so N_reserved is 0');
assert(TpS == N - 10, 'ten excluded slots must remove exactly ten, got T''max %d', TpS);
assert(isequal(poS(1:160), 0:159), 'the map must stay the identity BEFORE the first excluded slot');
assert(loS(160 + 1) == -1, 'the excluded slot itself must have no logical index');
assert(poS(160 + 1) == 161, 'immediately after the excluded slot the map must shift by one, got %d', poS(160 + 1));
assert(loS(161 + 1) == 160, 'physical slot 161 must be logical slot 160 once slot 160 is excluded');
% By the end of the run of exclusions the shift has accumulated to ten -- the size of the error
% a caller makes by treating a logical index as a physical one.
assert(loS(1601 + 1) == 1591, 'after all ten exclusions the shift must be ten: physical 1601 is logical 1591, got %d', loS(1601 + 1));
assert(~isequal(poS, 0:TpS - 1), 'this configuration must NOT be the identity -- otherwise the test proves nothing');

fprintf('test_poolAllSlots: all assertions passed.\n');
end
