function st = txHardwareInit(hw, fs, fcHz, seed)
%txHardwareInit One UE's transmitter hardware: Communications Toolbox behavioural models, with
%the PA drive calibrated so the antenna-port power is hw.tx.pOutDbm AFTER compression.
%Spec:   none -- implementation (+rf/ is outside every 3GPP SAP).
%Inputs: hw    rf.hwDefaults()
%        fs    real, Hz -- sample rate of phy.lib.ofdmMod
%        fcHz  real, Hz -- carrier, for the ppm frequency error
%        seed  integer -- this UE's own stream, so a run does not depend on worker partitioning
%Outputs: st  scalar struct of handle objects and constants, consumed by rf.txHardware:
%   .pn      comm.PhaseNoise          the oscillator's phase noise
%   .pfo     comm.PhaseFrequencyOffset  the carrier-frequency error, applied with continuous phase
%   .pa      comm.MemorylessNonlinearity (Rapp)  the power amplifier, in sqrt(W) units
%   .foHz    this UE's frequency error, Hz
%   .drive   amplitude applied to a UNIT-power waveform at the PA input
%   .pOutW   the calibrated average output power, W
%   .dacFs   DAC full scale relative to the unit-power input (12 dB above its RMS)
%
%WHY THE DRIVE IS CALIBRATED THROUGH THE PA, NOT BEFORE IT
%---------------------------------------------------------
%A compressing PA delivers less average power than its small-signal gain predicts, and how much
%less depends on the waveform's peaks. Setting the input for 23 dBm and letting the PA eat the
%peaks would leave the antenna port below 23 dBm and every link budget slightly short. So the
%drive is found by bisection on a representative full-band OFDM slot: the output, compression
%included, averages exactly pOutDbm over the transmitted samples.
rs = RandStream('mt19937ar', 'Seed', seed);
st.foHz = (2 * rand(rs) - 1) * hw.lo.ppm * 1e-6 * fcHz;
st.pn = comm.PhaseNoise('Level', hw.pn.levelDbcHz, 'FrequencyOffset', hw.pn.offsetHz, ...
    'SampleRate', fs, 'RandomStream', 'mt19937ar with seed', 'Seed', mod(seed, 2^32 - 1) + 1);
st.pfo = comm.PhaseFrequencyOffset('FrequencyOffset', st.foHz, 'SampleRate', fs);
W_PER_MW = 1e-3;
st.pOutW = 10^(hw.tx.pOutDbm / 10) * W_PER_MW;
satW = 10^(hw.tx.paSatDbm / 10) * W_PER_MW;
st.pa = comm.MemorylessNonlinearity('Method', 'Rapp model', 'Smoothness', hw.tx.paSmoothness, ...
    'OutputSaturationLevel', sqrt(satW), 'LinearGain', 0);
DAC_HEADROOM_DB = 12;                         % full scale 12 dB above the RMS: OFDM PAPR ~10 dB
st.dacFs = 10^(DAC_HEADROOM_DB / 20);
st.hw = hw;

% ---- calibrate the drive on a representative slot -----------------------------------
cal = RandStream('mt19937ar', 'Seed', 1);     % the SAME probe for every UE: identical PAs
nSc = 50 * 12;
grid = (sign(randn(cal, nSc, 13)) + 1j * sign(randn(cal, nSc, 13))) / sqrt(2);
grid(:, 14) = 0;                              % guard symbol
x = phy.lib.ofdmMod(grid, 1, 0);
on = x ~= 0;
x = x / sqrt(mean(abs(x(on)).^2));
lo = sqrt(st.pOutW) * 0.1; hi = sqrt(satW) * 10;
for it = 1:60
    mid = sqrt(lo * hi);
    reset(st.pa);
    y = st.pa(mid * x);
    if mean(abs(y(on)).^2) < st.pOutW, lo = mid; else, hi = mid; end
end
st.drive = sqrt(lo * hi);
reset(st.pa);
end
