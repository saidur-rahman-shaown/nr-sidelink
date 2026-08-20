function test_psschModulation()
%test_psschModulation Unit tests for PSSCH scrambling and modulation:
%slPSSCHDMRS, slPSSCHScramble (incl. SCI-2 placeholder-bit handling),
%slPSSCHConfig, slPSSCH.
%SPEC: TS 38.211 V16.10.0 clause 8.3.1.1 (scrambling), 8.3.1.2 (modulation),
%      8.4.1.1.1 (DM-RS sequence)

%% slPSSCHDMRS
r = phy.ts38211.slPSSCHDMRS(2468, 3, 5, 14, 12);
assert(numel(r) == 12, 'slPSSCHDMRS: wrong length');
assert(abs(mean(abs(r).^2) - 1) < 1e-9, 'slPSSCHDMRS: not unit power (QPSK)');

%% slPSSCHScramble -- no placeholders, matches a direct manual replica
Mbit = 40; MbitSCI2 = 16; NID = 3333;
bits = randi([0 1], Mbit, 1);
mask = false(Mbit, 1);
scr = phy.ts38211.slPSSCHScramble(bits, mask, NID, MbitSCI2);
cinit = 2^15*NID + 1010;
c = phy.lib.goldSeq(cinit, Mbit);
expected = false(Mbit, 1);
for i = 0:Mbit-1
    if i < MbitSCI2, cidx = i; else, cidx = i - MbitSCI2; end
    expected(i+1) = xor(logical(bits(i+1)), c(cidx+1));
end
assert(isequal(scr, expected), 'slPSSCHScramble: no-placeholder case does not match manual computation');

%% slPSSCHScramble -- with placeholders, verifies the copy-from-i-2 mechanic
mask2 = false(Mbit, 1);
mask2([5 6]) = true;   % placeholders at 0-based i=4,5, inside the SCI-2 region
scr2 = phy.ts38211.slPSSCHScramble(bits, mask2, NID, MbitSCI2);
j = 0; expected2 = false(Mbit, 1);
for i = 0:Mbit-1
    if i < MbitSCI2, Mij = j; else, Mij = MbitSCI2; end
    if mask2(i+1)
        expected2(i+1) = expected2(i-1);
        j = j + 1;
    else
        expected2(i+1) = xor(logical(bits(i+1)), c(i - Mij + 1));
    end
end
assert(isequal(scr2, expected2), 'slPSSCHScramble: placeholder case does not match manual computation');
assert(scr2(5) == scr2(3), 'slPSSCHScramble: i=4 should copy b~(2)');
assert(scr2(6) == scr2(4), 'slPSSCHScramble: i=5 should copy b~(3)');

try
    badMask = false(Mbit, 1); badMask(1) = true;
    phy.ts38211.slPSSCHScramble(bits, badMask, NID, MbitSCI2);
    error('test_psschModulation:shouldHaveErrored', 'slPSSCHScramble should reject a placeholder at i<2');
catch e
    assert(strcmp(e.identifier, 'ts38211:slPSSCHScramble:badPlaceholder'), 'slPSSCHScramble: wrong error for early placeholder');
end

%% slPSSCHConfig / slPSSCH end to end
pool = struct();
dyn = struct('NID', NID, 'MbitSCI2', MbitSCI2, 'modScheme', '16QAM', 'nsf', 5, 'NsymbSlot', 14);
cfg = phy.ts38211.slPSSCHConfig(pool, dyn);
carrier = struct();
d = phy.ts38211.slPSSCH(carrier, cfg, bits, mask);
expectedLen = MbitSCI2/2 + (Mbit - MbitSCI2)/4;   % 16QAM Qm=4
assert(numel(d) == expectedLen, 'slPSSCH: wrong output length');
assert(abs(mean(abs(d(1:MbitSCI2/2)).^2) - 1) < 1e-9, 'slPSSCH: SCI-2 (QPSK) portion not unit power');

try
    phy.ts38211.slPSSCHConfig(pool, struct('NID', 1, 'MbitSCI2', 1, 'modScheme', '1024QAM', 'nsf', 0, 'NsymbSlot', 14));
    error('test_psschModulation:shouldHaveErrored', 'slPSSCHConfig should reject 1024QAM (not in Table 8.3.1.2-1)');
catch e
    assert(strcmp(e.identifier, 'ts38211:slPSSCHConfig:badScheme'), 'slPSSCHConfig: wrong error for illegal scheme');
end

fprintf('test_psschModulation: PASS\n');
end
