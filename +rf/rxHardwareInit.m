function st = rxHardwareInit(hw, fs, fcHz, seed)
%rxHardwareInit One UE's receiver hardware state (Communications Toolbox behavioural models).
%Spec:   none -- implementation.
%Inputs: hw    rf.hwDefaults()
%        fs    real, Hz -- sample rate
%        fcHz  real, Hz -- carrier
%        seed  integer -- this UE's own stream
%Outputs: st  scalar struct consumed by rf.rxHardware:
%   .foHz      this UE's LO frequency error, Hz. A real UE has ONE oscillator, so the deployment
%              engine overwrites this (and .pfo's offset) with its transmitter's value
%   .pn        comm.PhaseNoise -- the receive LO's phase noise
%   .pfo       comm.PhaseFrequencyOffset -- removes the LO's own offset (sign: -foHz)
%   .noiseW    thermal noise power per sample, W: k T0 F fs
%   .rng       RandStream for the noise
%   .adcFs     ADC full-scale amplitude per rail after the AGC (1.0: the AGC normalises to it)
rs = RandStream('mt19937ar', 'Seed', seed);
st.foHz = (2 * rand(rs) - 1) * hw.lo.ppm * 1e-6 * fcHz;
st.pn = comm.PhaseNoise('Level', hw.pn.levelDbcHz, 'FrequencyOffset', hw.pn.offsetHz, ...
    'SampleRate', fs, 'RandomStream', 'mt19937ar with seed', 'Seed', mod(seed + 7, 2^32 - 1) + 1);
st.pfo = comm.PhaseFrequencyOffset('FrequencyOffset', -st.foHz, 'SampleRate', fs);
W_PER_MW = 1e-3;
st.noiseW = 10^(rf.noiseFloorDbm(fs, hw.rx.noiseFigureDb) / 10) * W_PER_MW;
st.rng = RandStream('mt19937ar', 'Seed', seed + 1);
st.adcFs = 1;
st.hw = hw;
end
