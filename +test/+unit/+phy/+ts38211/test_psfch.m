function test_psfch()
%test_psfch Unit tests for the PSFCH channel: slPSFCHConfig, slPSFCHAlpha,
%slPSFCH, slPSFCHIndices.
%SPEC: TS 38.211 V16.10.0 clause 8.3.4.2 (channel), clause 6.3.2.2.2 (alpha,
%      applied via 8.3.4.2.1)

pool = struct('sl_PSFCH_HopID_r16_Present', true, 'sl_PSFCH_HopID_r16', 47);
dyn = struct('m0', 3, 'mcs', 6, 'lp', 8, 'nsf', 5, 'NsymbSlot', 14, 'startPRB', 20, 'symbol', 8);

%% slPSFCHConfig -- alpha is computed, not caller-supplied
cfg = phy.ts38211.slPSFCHConfig(pool, dyn);
assert(cfg.nID == 47 && cfg.u == mod(47, 30) && cfg.v == 0, 'slPSFCHConfig: u/v derivation wrong');
assert(cfg.alpha >= 0 && cfg.alpha < 2*pi, 'slPSFCHConfig: alpha out of range');

pool2 = struct('sl_PSFCH_HopID_r16_Present', false);
cfg2 = phy.ts38211.slPSFCHConfig(pool2, dyn);
assert(cfg2.nID == 0 && cfg2.u == 0, 'slPSFCHConfig: wrong defaults when hop ID unconfigured');

%% slPSFCHAlpha -- deterministic and in range over the legal m0/mcs values
for m0 = 0:5
    for mcs = [0 6]
        a = phy.ts38211.slPSFCHAlpha(m0, mcs, 47, 8, 5, 14);
        assert(a >= 0 && a < 2*pi, 'slPSFCHAlpha: out of range at m0=%d mcs=%d', m0, mcs);
        a2 = phy.ts38211.slPSFCHAlpha(m0, mcs, 47, 8, 5, 14);
        assert(a == a2, 'slPSFCHAlpha: not deterministic');
    end
end

%% slPSFCH
carrier = struct();
x = phy.ts38211.slPSFCH(carrier, cfg);
assert(numel(x) == 12 && iscolumn(x), 'slPSFCH: wrong length');
assert(max(abs(abs(x) - 1)) < 1e-10, 'slPSFCH: not constant modulus');

%% slPSFCHIndices
ind = phy.ts38211.slPSFCHIndices(carrier, cfg);
assert(isequal(size(ind), [12 2]), 'slPSFCHIndices: wrong size');
assert(isequal(ind(:,1), (20*12:20*12+11)'), 'slPSFCHIndices: wrong k range');
assert(all(ind(:,2) == 8), 'slPSFCHIndices: wrong symbol');

fprintf('test_psfch: PASS\n');
end
