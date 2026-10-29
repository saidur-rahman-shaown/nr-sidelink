function [y, info] = rxHardware(st, x, t0, agcSamples)
%rxHardware One slot window through the receiver hardware: thermal noise, LO (frequency error,
%phase noise), IQ imbalance, AGC, ADC. Output back in absolute sqrt(W).
%Spec:   none -- implementation. Order is the physical chain: antenna -> LNA noise -> mixer
%        (LO error, phase noise, IQ imbalance) -> AGC -> ADC -> digital rescale.
%Inputs: st          from rf.rxHardwareInit
%        x           nSamples x 1 complex, sqrt(W) -- the sum of every arriving signal, or [] for
%                    silence (thermal noise is still received)
%        t0          real, s -- absolute time of the first sample (continuous LO phase)
%        agcSamples  integer -- samples the AGC measures over: the AGC symbol at the start of
%                    the window, which is what TS 38.211 8.2.1's duplicated first symbol is for
%Outputs: y     nSamples x 1 complex, sqrt(W) -- what the baseband receiver sees, rescaled by the
%               known digital gain so absolute-power quantities (RSRP, the PSFCH energy gate)
%               keep their meaning
%         info  struct: .agcGainDb (applied before the ADC), .clipFrac (share of samples that
%               hit full scale), .inDbm (mean input power, dBm)
%WHAT THE AGC + ADC MODEL CAPTURES
%The gain is set once per slot from the AGC symbol and held. A strong nearby transmitter sets it;
%a weak far one in the same slot then sits closer to the quantisation floor (fewer effective
%bits), and a signal stronger in later symbols than in the AGC symbol clips. Both are real
%sidelink failure modes that an ideal floating-point receiver cannot show.
n = numel(x);
if isempty(x), x = complex(zeros(n, 1)); end
hw = st.hw;
x = x + sqrt(st.noiseW / 2) * (randn(st.rng, n, 1) + 1j * randn(st.rng, n, 1));
release(st.pfo);
st.pfo.PhaseOffset = mod(-360 * st.foHz * t0, 360);
x = st.pfo(x);
x = st.pn(x);
x = iqimbal(x, hw.rx.iqAmpDb, hw.rx.iqPhaseDeg);
agcSamples = min(agcSamples, n);
rmsAgc = sqrt(mean(abs(x(1:agcSamples)).^2));
target = st.adcFs * 10^(-hw.rx.agcBackoffDb / 20);
g = target / max(rmsAgc, eps);
v = g * x;
L = 2^(hw.rx.adcBits - 1);
qr = @(u) max(-L, min(L - 1, floor(u / st.adcFs * L))) + 0.5;
clipped = abs(real(v)) >= st.adcFs | abs(imag(v)) >= st.adcFs;
q = (qr(real(v)) + 1j * qr(imag(v))) * st.adcFs / L;
y = q / g;
info = struct('agcGainDb', 20 * log10(g), 'clipFrac', mean(clipped), ...
    'inDbm', 10 * log10(mean(abs(x).^2)) + 30);
end
