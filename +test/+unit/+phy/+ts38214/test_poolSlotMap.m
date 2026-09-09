function test_poolSlotMap()
%test_poolSlotMap Unit tests for phy.ts38214.poolSlotMap.
%SPEC: TS 38.214 V16.17.0, clause 8 preamble -- the set of slots that may belong to a sidelink
%      resource pool, the four exclusions (S-SSB, non-sidelink, reserved, bitmap), and the
%      re-indexing to t'^SL_i.
%
%Level 1 (structural and round-trip) and level 2 (worked example) per +test/CLAUDE.md. The
%worked-example block's values were computed by the independent-verifier subagent from the PDF
%alone, blind to poolSlotMap.m -- see +phy/+ts38214/CLAUDE.md.

%% ---- worked example: mu=0, S-SSB every 160 slots, non-SL at n mod 10 == 5 ----
% Chosen so the two exclusion sets are disjoint (n = 0 mod 160 implies n = 0 mod 10, never 5)
% and so N_reserved is comfortably non-zero.
mu    = 0;
Tmax  = 10240 * 2^mu;
n     = 0:Tmax - 1;
ssb   = mod(n, 160) == 0;               % N_S-SSB = 64
nonsl = mod(n, 10)  == 5;               % N_nonSL = 1024
bm    = [true(1, 10) false(1, 10)];     % L_bitmap = 20, first half selected

assert(nnz(ssb) == 64, 'test setup: expected 64 S-SSB slots, got %d', nnz(ssb));
assert(nnz(nonsl) == 1024, 'test setup: expected 1024 non-SL slots, got %d', nnz(nonsl));

[po, lo, Tp] = phy.ts38214.poolSlotMap(mu, ssb, nonsl, bm);

% L = 10240 - 64 - 1024 = 9152; N_reserved = 9152 mod 20 = 12; 9152 - 12 = 9140 = 20*457;
% the bitmap selects half of each 20-slot tile, so T'max = 9140/2 = 4570.
assert(Tp == 4570, 'poolSlotMap: T''max must be 4570 for this configuration, got %d', Tp);
% l_0 is slot 1 (slot 0 is an S-SSB slot); the reserved rule removes r=0, i.e. l_0 itself, so
% the pool starts at slot 2. Slot 5 is non-SL, so the run continues 2,3,4 then jumps to 6,7.
assert(isequal(po(1:5), [2 3 4 6 7]), 'poolSlotMap: first five pool slots must be [2 3 4 6 7], got %s', mat2str(po(1:5)));
assert(lo(0 + 1)   == -1,  'poolSlotMap: slot 0 is an S-SSB slot and must not be in the pool');
assert(lo(1 + 1)   == -1,  'poolSlotMap: slot 1 is l_0, removed as reserved slot r=0');
assert(lo(5 + 1)   == -1,  'poolSlotMap: slot 5 is a non-sidelink slot');
assert(lo(10 + 1)  ==  7,  'poolSlotMap: slot 10 must be logical slot 7, got %d', lo(10 + 1));
assert(lo(160 + 1) == -1,  'poolSlotMap: slot 160 is an S-SSB slot');
assert(lo(762 + 1) == 340, 'poolSlotMap: slot 762 must be logical slot 340, got %d', lo(762 + 1));

% The twelve reserved slots, named explicitly. r = floor(m*9152/12) for m = 0..11 gives
% r in {0, 762, 1525, 2288, 3050, 3813, 4576, 5338, 6101, 6864, 7626, 8389}, and those index
% into (l_0, l_1, ...) -- not into physical slots -- landing on the physical slots below.
% Each survives the S-SSB and non-SL exclusions, so if any of them shows a logical index the
% reserved-slot rule was skipped or mis-indexed. This is the assertion that fails if
% m*L/N_reserved is ever read as a product rather than a quotient.
reservedPhys = [1 853 1707 2561 3413 4267 5121 5973 6827 7681 8533 9387];
assert(~any(ssb(reservedPhys + 1) | nonsl(reservedPhys + 1)), 'test setup: the reserved slots must survive exclusions 1 and 2, or the test proves nothing');
assert(all(lo(reservedPhys + 1) == -1), 'poolSlotMap: every reserved slot must be excluded; %s are not', mat2str(reservedPhys(lo(reservedPhys + 1) ~= -1)));

%% ---- the N_reserved == 0 branch, with the same bitmap -------------------
% 10240 - 0 - 0 = 10240 = 20*512, so N_reserved = 0 and step 2's m-range is empty. The
% discriminating detail: l_0 (physical slot 0) is reserved whenever N_reserved > 0, because
% m starts at 0 -- so here, and only here, slot 0 IS in the pool.
none0 = false(1, Tmax);
[poZ0, loZ0, TpZ0] = phy.ts38214.poolSlotMap(mu, none0, none0, bm);
assert(TpZ0 == 5120, 'poolSlotMap: with nothing excluded the half bitmap must select 5120 slots, got %d', TpZ0);
assert(isequal(poZ0(1:5), [0 1 2 3 4]), 'poolSlotMap: with N_reserved = 0, slot 0 must be logical slot 0, got %s', mat2str(poZ0(1:5)));
assert(loZ0(0 + 1) == 0, 'poolSlotMap: N_reserved = 0 is the one case where physical slot 0 is in the pool');
assert(loZ0(10 + 1) == -1, 'poolSlotMap: bit 10 of the bitmap is 0, so the 11th survivor is not in the pool');

%% ---- the two maps are exact inverses -----------------------------------
% The property the "applied exactly once" rule rests on: a round trip through both directions
% must be the identity, in both directions, everywhere.
assert(numel(po) == Tp && numel(lo) == Tmax, 'poolSlotMap: output sizes must be T''max and Tmax');
assert(isequal(lo(po + 1), 0:Tp - 1), 'poolSlotMap: logicalOfPhys(physOfLogical(i)) must be i for every logical slot');
inPool = find(lo >= 0) - 1;
assert(isequal(inPool, po), 'poolSlotMap: the slots with a logical index must be exactly the pool slots, in the same order');
assert(all(diff(po) > 0), 'poolSlotMap: pool slots must be strictly increasing (the clause re-indexes in increasing slot order)');
assert(all(po >= 0 & po < Tmax), 'poolSlotMap: every pool slot must lie in 0..Tmax-1');
% No excluded slot may carry a logical index.
assert(all(lo(ssb) == -1), 'poolSlotMap: no S-SSB slot may be in the pool');
assert(all(lo(nonsl) == -1), 'poolSlotMap: no non-sidelink slot may be in the pool');

%% ---- the reserved slots make the survivors tile the bitmap exactly -----
% This is the whole purpose of exclusion 3, and the property that catches an off-by-one in it:
% (L - N_reserved) must be an exact multiple of L_bitmap, at every bitmap length, so the
% bitmap phase never slips at a DFN wrap.
for Lbitmap = [10 11 12 16 20 30 40 50 60 100 160]
    b = false(1, Lbitmap); b(1) = true;              % one slot per tile
    [poK, ~, TpK] = phy.ts38214.poolSlotMap(mu, ssb, nonsl, b);
    L = Tmax - nnz(ssb) - nnz(nonsl);
    survivors = L - mod(L, Lbitmap);
    assert(mod(survivors, Lbitmap) == 0, 'test setup: survivor count must tile');
    assert(TpK == survivors / Lbitmap, 'poolSlotMap: a one-bit bitmap of length %d must select %d slots, got %d', Lbitmap, survivors / Lbitmap, TpK);
    % Selecting bit 0 of every tile means the pool slots are exactly every Lbitmap-th survivor.
    assert(all(diff(poK) > 0), 'poolSlotMap: pool slots must stay increasing at L_bitmap=%d', Lbitmap);
end
% An all-ones bitmap selects every survivor, which pins the survivor count itself.
allOnes = true(1, 20);
[~, ~, TpAll] = phy.ts38214.poolSlotMap(mu, ssb, nonsl, allOnes);
assert(TpAll == 9140, 'poolSlotMap: an all-ones bitmap must select all 9140 survivors, got %d', TpAll);
% and the sum over a partitioned bitmap must equal it -- the bitmap cannot create or lose slots.
firstHalf  = [true(1, 10) false(1, 10)];
secondHalf = [false(1, 10) true(1, 10)];
[~, ~, TpA] = phy.ts38214.poolSlotMap(mu, ssb, nonsl, firstHalf);
[~, ~, TpB] = phy.ts38214.poolSlotMap(mu, ssb, nonsl, secondHalf);
assert(TpA + TpB == TpAll, 'poolSlotMap: complementary bitmaps must partition the survivors exactly, got %d + %d vs %d', TpA, TpB, TpAll);

%% ---- N_reserved == 0 is the no-reserved-slots case, not a divide by zero ----
% L must be an exact multiple of L_bitmap for this branch. 10240 - 0 - 0 = 10240 = 20*512.
noneExcluded = false(1, Tmax);
[poZ, ~, TpZ] = phy.ts38214.poolSlotMap(mu, noneExcluded, noneExcluded, allOnes);
assert(TpZ == Tmax, 'poolSlotMap: with nothing excluded and an all-ones bitmap the pool is every slot, got %d', TpZ);
assert(isequal(poZ, 0:Tmax - 1), 'poolSlotMap: that pool must be the identity mapping');

%% ---- numerology scaling ------------------------------------------------
% Tmax = 10240*2^mu, so the mask length and the pool both double per mu step.
prev = 0;
for m = 0:3
    Tm  = 10240 * 2^m;
    none = false(1, Tm);
    [~, loM, TpM] = phy.ts38214.poolSlotMap(m, none, none, true(1, 10));
    assert(numel(loM) == Tm, 'poolSlotMap: logicalOfPhys must be Tmax long at mu=%d', m);
    assert(TpM == Tm, 'poolSlotMap: an unrestricted pool at mu=%d must hold all %d slots, got %d', m, Tm, TpM);
    if m > 0
        assert(TpM == 2 * prev, 'poolSlotMap: T''max must double from mu=%d to mu=%d', m - 1, m);
    end
    prev = TpM;
end

%% ---- validation --------------------------------------------------------
mustError(@() phy.ts38214.poolSlotMap(4, ssb, nonsl, bm), 'ts38214:poolSlotMap:badMu', 'mu out of 0..3');
mustError(@() phy.ts38214.poolSlotMap(mu, ssb(1:100), nonsl, bm), 'ts38214:poolSlotMap:badSsbMask', 'a mask of the wrong length');
% A mask sized for the wrong numerology is the realistic version of that mistake.
mustError(@() phy.ts38214.poolSlotMap(1, ssb, false(1, 20480), bm), 'ts38214:poolSlotMap:badSsbMask', 'a mu=0 mask passed at mu=1');
mustError(@() phy.ts38214.poolSlotMap(mu, double(ssb), nonsl, bm), 'ts38214:poolSlotMap:badSsbMask', 'a numeric mask');
mustError(@() phy.ts38214.poolSlotMap(mu, ssb, nonsl, true(1, 9)), 'ts38214:poolSlotMap:badBitmapLength', 'a bitmap shorter than SIZE(10..160)');
mustError(@() phy.ts38214.poolSlotMap(mu, ssb, nonsl, true(1, 161)), 'ts38214:poolSlotMap:badBitmapLength', 'a bitmap longer than SIZE(10..160)');
mustError(@() phy.ts38214.poolSlotMap(mu, ssb, nonsl, false(1, 20)), 'ts38214:poolSlotMap:emptyBitmap', 'an all-zero bitmap');
% Overlapping exclusion sets: the clause's count (Tmax - N_S-SSB - N_nonSL) presumes disjoint.
overlap = false(1, Tmax); overlap(1) = true;      % slot 0, which ssb also marks
mustError(@() phy.ts38214.poolSlotMap(mu, ssb, overlap, bm), 'ts38214:poolSlotMap:maskOverlap', 'overlapping S-SSB and non-SL masks');
% Everything excluded: no slot can belong to any pool.
mustError(@() phy.ts38214.poolSlotMap(mu, true(1, Tmax), false(1, Tmax), bm), 'ts38214:poolSlotMap:noSlotsLeft', 'every slot excluded');

fprintf('test_poolSlotMap: all assertions passed.\n');
end

function mustError(fh, expectedId, what)
%mustError Assert fh() raises, with the expected identifier.
try
    fh();
catch e
    assert(strcmp(e.identifier, expectedId), 'expected %s for %s, got %s', expectedId, what, e.identifier);
    return;
end
error('test_poolSlotMap:noError', 'expected an error for %s, none raised', what);
end
