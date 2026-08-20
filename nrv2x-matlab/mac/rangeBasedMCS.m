function [I_MCS, info] = rangeBasedMCS(targetRange_m, LsubCH, cfg, opts)
%rangeBasedMCS Dummy open-loop link adaptation for BROADCAST sidelink.
%
%   Broadcast has no HARQ feedback and no CQI — there is nobody to close a
%   loop with. The standard engineering answer (and this function) is
%   RANGE-BASED provisioning: the application states how far the message
%   must reach (e.g. CAM awareness distance), and the MCS is chosen so the
%   link budget at that distance still supports the modulation/code rate:
%
%     1. link budget:  SNR(d) = P_tx − PL_RMa(d) − N_thermal − fade margin
%     2. per-MCS requirement (DUMMY model): Shannon threshold + a fixed
%        implementation gap,  SNR_req = 10log10(2^eff − 1) + gap,
%        eff = Qm·R from the TS 38.214 Table 5.1.3.1-1 entries
%        (SidelinkMCS 'table1')
%     3. pick the HIGHEST I_MCS whose SNR_req <= SNR(targetRange)
%
%   Related spec hook: Rel-16 has a *minimum communication range* concept
%   (sl-ZoneConfigMCR, TS 38.331) but only for groupcast option 1
%   NACK-distance feedback — for plain broadcast, range-based MCS is a
%   declared policy, not a spec procedure. Replace step 2 with calibrated
%   SINR->BLER link curves (Plan.md §11) to graduate from "dummy".
%
%   [I_MCS, INFO] = rangeBasedMCS(RANGE_M, LSUBCH, CFG, OPTS)
%     OPTS fields (all optional):
%       .Model        'RMa-LOS' (default) | 'RMa-NLOS' | 'FSPL'
%       .TxPower_dBm  23      .NoiseFigure_dB 9
%       .FadeMargin_dB 4      (≈ one sigma_SF of RMa LOS)
%       .ImplGap_dB    5      (Shannon -> practical decoder)
%       .MinMCS 0  .MaxMCS 27 (pool clamp, sl-MinMaxMCS-List stand-in)
%
%   INFO: SNR at range, noise floor, per-MCS table (eff, required SNR),
%   chosen Qm/R/modulation/TargetCodeRate (feed these to
%   SidelinkPHYEntity.configureFromParams), achievableRange_m of the
%   chosen MCS, and rangeLimited flag when even I_MCS = MinMCS fails.

if nargin < 4, opts = struct(); end
model  = getOpt(opts, 'Model', 'RMa-LOS');
Ptx    = getOpt(opts, 'TxPower_dBm', 23);
NF     = getOpt(opts, 'NoiseFigure_dB', 9);
fade   = getOpt(opts, 'FadeMargin_dB', 4);
gap    = getOpt(opts, 'ImplGap_dB', 5);
mcsLo  = getOpt(opts, 'MinMCS', 0);
mcsHi  = getOpt(opts, 'MaxMCS', 27);

% ---- 1. link budget at the target range ------------------------------
B_Hz = LsubCH * cfg.sl_SubchannelSize_r16 * 12 * cfg.scs_kHz * 1e3;
N_dBm = -174 + 10*log10(B_Hz) + NF;
PL = sidelinkPathLoss(targetRange_m, 5.9e9, model);
snrAvail_dB = Ptx - PL - N_dBm - fade;

% ---- 2. per-MCS requirement (dummy: Shannon + gap) -------------------
nMCS = mcsHi - mcsLo + 1;
tblEff = zeros(nMCS, 1);  tblReq = zeros(nMCS, 1);
tblQm  = zeros(nMCS, 1);  tblR   = zeros(nMCS, 1);
for k = 1:nMCS
    [Qm, R] = SidelinkMCS.lookupMCS(mcsLo + k - 1, 'table1');
    tblQm(k) = Qm;  tblR(k) = R;
    tblEff(k) = Qm * R;                              % bits/s/Hz
    tblReq(k) = 10*log10(2^tblEff(k) - 1) + gap;     % required SNR, dB
end

% ---- 3. highest MCS that closes the budget ---------------------------
ok = find(tblReq <= snrAvail_dB, 1, 'last');
rangeLimited = isempty(ok);
if rangeLimited
    ok = 1;                                          % most robust MCS
end
I_MCS = mcsLo + ok - 1;

% achievable range of the chosen MCS (invert the monotonic PL by bisection)
maxPL = Ptx - N_dBm - fade - tblReq(ok);
lo = 10; hi = 10e3;
if sidelinkPathLoss(hi, 5.9e9, model) < maxPL
    dMax = hi;
else
    for it = 1:50
        mid = (lo + hi) / 2;
        if sidelinkPathLoss(mid, 5.9e9, model) <= maxPL, lo = mid; else, hi = mid; end
    end
    dMax = lo;
end

info = struct( ...
    'SNRatRange_dB',    snrAvail_dB, ...
    'PL_dB',            PL, ...
    'NoiseFloor_dBm',   N_dBm, ...
    'Bandwidth_Hz',     B_Hz, ...
    'Qm',               tblQm(ok), ...
    'TargetCodeRate',   tblR(ok), ...
    'Modulation',       SidelinkMCS.modulationFromOrder(tblQm(ok)), ...
    'Efficiency',       tblEff(ok), ...
    'RequiredSNR_dB',   tblReq(ok), ...
    'AchievableRange_m', dMax, ...
    'RangeLimited',     rangeLimited, ...
    'MCSIndices',       (mcsLo:mcsHi)', ...
    'PerMCS_Eff',       tblEff, ...
    'PerMCS_ReqSNR_dB', tblReq);
end

function v = getOpt(s, name, default)
if isfield(s, name) && ~isempty(s.(name)), v = s.(name); else, v = default; end
end
