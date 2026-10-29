function y = txHardware(st, iq, t0)
%txHardware One slot through the transmitter hardware: DAC, IQ imbalance, phase noise, carrier
%frequency error, power amplifier. Output in sqrt(W) at the antenna port.
%Spec:   none -- implementation. The order is the physical chain: digital samples -> DAC ->
%        IQ modulator (imbalance) -> LO (phase noise, frequency error) -> PA.
%Inputs: st  from rf.txHardwareInit (handle objects: state advances)
%        iq  nSamples x 1 complex -- the slot as phy.lib.ofdmMod / stack.slotModulate produced it;
%            only its SHAPE matters, it is renormalised to unit power here
%        t0  real, s -- absolute time of the slot's first sample, so the frequency error keeps a
%            continuous phase across the UE's (non-contiguous) transmissions
%Outputs: y  nSamples x 1 complex, sqrt(W): mean |y|^2 over transmitted samples = st.pOutW (to
%            within how far this slot's peaks differ from the calibration probe's)
%The guard symbol stays exactly zero: every block maps 0 to 0.
on = iq ~= 0;
if ~any(on)
    y = iq;
    return;
end
x = iq / sqrt(mean(abs(iq(on)).^2));
hw = st.hw;
if isfinite(hw.tx.dacBits)
    x = quantise(x, st.dacFs, hw.tx.dacBits);
end
x = iqimbal(x, hw.tx.iqAmpDb, hw.tx.iqPhaseDeg);
x = st.pn(x);
% Continuous carrier phase: the offset at t0, then the object's own phase accumulator from 0.
release(st.pfo);
st.pfo.PhaseOffset = mod(360 * st.foHz * t0, 360);
x = st.pfo(x);
y = st.pa(st.drive * x);
y(~on) = 0;
end

function q = quantise(x, fs, bits)
%quantise Uniform mid-rise quantiser on I and Q separately, clipping at +/- full scale.
L = 2^(bits - 1);
qr = @(v) max(-L, min(L - 1, floor(v / fs * L))) + 0.5;
q = (qr(real(x)) + 1j * qr(imag(x))) * fs / L;
end
