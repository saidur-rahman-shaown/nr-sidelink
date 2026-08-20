function test_SlotMap()
%test_SlotMap Logical pool slot map, T'_max, P'_rsvp conversion.
%SPEC: TS 38.214 8.1.7; checklist item 5 (logical pool slots)

% ---- all-slots pool (default) ----------------------------------------
cfg = defaultPreconfig();
sm  = deriveLogicalSlots(cfg, 1000);
assert(sm.nLogical == 1000, 'all-true pool must include every slot');
assert(sm.TmaxPrime == 20480, 'T''_max over 10240 ms @30 kHz all-pool');
% P'_rsvp = ceil((20480/10240)*100) = 200
assert(prsvpToLogical(100, sm) == 200);
assert(prsvpToLogical(1, sm)   == 2);

% ---- bitmap + TDD holes, hand-computed --------------------------------
cfg2 = cfg;
cfg2.tdd_ULSlotMask      = [true true true false true];   % abs mod 5 == 3 out
cfg2.sl_TimeResource_r16 = [true true false true];        % 3rd candidate out
nSim = 100;
sm2 = deriveLogicalSlots(cfg2, nSim);

% brute-force reference
isPoolRef = false(1, nSim);
bm = 0;
for n = 0:nSim-1
    if mod(n, 5) == 3, continue; end
    bm = bm + 1;
    if cfg2.sl_TimeResource_r16(mod(bm-1, 4) + 1)
        isPoolRef(n+1) = true;
    end
end
assert(isequal(sm2.isPool, isPoolRef), 'bitmap/TDD mask mismatch vs brute force');

% inverse maps
for lg = 1:sm2.nLogical
    a = sm2.logical2abs(lg);
    assert(sm2.abs2logical(a + 1) == lg, 'abs<->logical maps must be inverse');
end

% T'_max: 20480 slots -> 4096 TDD periods * 4 candidates = 16384 candidates;
% bitmap 3-of-4 -> 12288 pool slots
assert(sm2.TmaxPrime == 12288, 'T''_max=%d, expected 12288', sm2.TmaxPrime);

% P'_rsvp with the sparse pool: ceil((12288/10240)*100) = ceil(120) = 120
assert(prsvpToLogical(100, sm2) == 120);
% ceil, not round: P = 3 ms -> ceil(1.2*3) = ceil(3.6) = 4 (round gives 4 too;
% use P = 7 -> 12288/10240*7 = 8.4 -> ceil 9, round 8)
assert(prsvpToLogical(7, sm2) == 9, 'must be ceil, not round');

% ---- S-SSB exclusion --------------------------------------------------
cfg3 = cfg;
cfg3.sssb_SlotsInPeriod = [0 1];
cfg3.sssb_Period_slots  = 320;
sm3 = deriveLogicalSlots(cfg3, 700);
assert(~sm3.isPool(1) && ~sm3.isPool(2), 'S-SSB slots excluded');
assert(~sm3.isPool(321) && ~sm3.isPool(322), 'S-SSB exclusion repeats');
assert(sm3.isPool(3), 'non-S-SSB slot kept');

% ---- nextPoolLogical --------------------------------------------------
assert(nextPoolLogical(sm2, sm2.logical2abs(10)) == 10);
gapAbs = find(~sm2.isPool, 1) - 1;                 % an excluded abs slot
nxt = nextPoolLogical(sm2, gapAbs);
assert(sm2.logical2abs(nxt) > gapAbs, 'must return first pool slot AFTER n');

fprintf('test_SlotMap: PASS\n');
end
