function test_LinkAdaptation()
%test_LinkAdaptation Range-based broadcast MCS selection (dummy model).

cfg = defaultPreconfig();
L = 2;                                      % 2 sub-channels -> 7.2 MHz

%% farther target range must never get a higher MCS
ranges = [50 100 200 400 800 1500];
idx = zeros(size(ranges));
for k = 1:numel(ranges)
    idx(k) = rangeBasedMCS(ranges(k), L, cfg);
end
assert(all(diff(idx) <= 0), 'MCS must be non-increasing with range: %s', mat2str(idx));

%% short range -> aggressive MCS, long range -> robust / range-limited
[iShort, infoS] = rangeBasedMCS(50, L, cfg);
assert(iShort >= 15, '50 m should support a high MCS, got %d', iShort);
[iFar, infoF] = rangeBasedMCS(1500, L, cfg);
assert(iFar == 0 || infoF.RangeLimited || infoF.Efficiency < 1, ...
    '1.5 km RMa must force the robust end (got MCS %d)', iFar);

%% 200 m (CAM awareness range): sane middle ground, budget arithmetic holds
[i200, info] = rangeBasedMCS(200, L, cfg);
assert(i200 > iFar && i200 <= iShort, 'ordering');
assert(abs(info.NoiseFloor_dBm - (-174 + 10*log10(7.2e6) + 9)) < 1e-9);
assert(abs(info.SNRatRange_dB - (23 - info.PL_dB - info.NoiseFloor_dBm - 4)) < 1e-9);
assert(info.RequiredSNR_dB <= info.SNRatRange_dB, 'chosen MCS must close the budget');
assert(~info.RangeLimited);

%% achievable range of the chosen MCS covers the target
assert(info.AchievableRange_m >= 200 * 0.98, ...
    'achievable range %.0f m must cover the 200 m target', info.AchievableRange_m);

%% outputs are directly consumable by the PHY
assert(any(strcmp(info.Modulation, {'QPSK', '16QAM', '64QAM'})));
assert(info.TargetCodeRate > 0 && info.TargetCodeRate < 1);

%% pool clamp (sl-MinMaxMCS-List stand-in)
iClamped = rangeBasedMCS(50, L, cfg, struct('MaxMCS', 11));
assert(iClamped <= 11, 'MaxMCS clamp violated');
iFloor = rangeBasedMCS(5000, L, cfg, struct('MinMCS', 3));
assert(iFloor == 3, 'range-limited case must fall back to MinMCS');

%% NLOS costs range at equal MCS
[~, infoN] = rangeBasedMCS(200, L, cfg, struct('Model', 'RMa-NLOS'));
assert(infoN.SNRatRange_dB < info.SNRatRange_dB, 'NLOS must reduce the budget');

fprintf('test_LinkAdaptation: PASS (200 m -> MCS %d, %s R=%.2f, reaches %.0f m)\n', ...
    i200, info.Modulation, info.TargetCodeRate, info.AchievableRange_m);
end
