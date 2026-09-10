function grid = ofdmDemod(waveform, nSubcarriers, mu, nSlot)
%ofdmDemod OFDM demodulation: time-domain samples to resource grid. Toolbox body: nrOFDMDemodulate.
%Spec:   the inverse of TS 38.211 V16.10.0 clause 5.3.1. Demodulation is NOT normative -- the
%        spec defines what a transmitter emits, not how a receiver recovers it -- which is why
%        this lives in +phy/+lib/ and is verified by round-tripping phy.lib.ofdmMod rather than
%        against a worked example.
%Inputs: waveform      nSamples-by-1 complex column vector
%        nSubcarriers  integer, a multiple of 12 -- the grid width to recover. The receiver
%                      must be told this: it is a property of the pool's bandwidth, not
%                      something recoverable from the samples
%        mu            integer, 0..3 -- mu_SL
%        nSlot         integer, >=0 -- slot number within the frame, for the CP pattern
%Outputs: grid  nSubcarriers-by-nSymbols complex matrix
%
%Assumes the waveform is already time-aligned and carrier-frequency corrected. Acquiring that
%alignment is +phy/+rx/+sync/'s job, not this wrapper's: a demodulator that silently searched
%for its own timing would hide every synchronisation failure inside a channel-estimation error.

if mod(nSubcarriers, 12) ~= 0
    error('lib:ofdmDemod:badWidth', 'ofdmDemod: nSubcarriers must be a multiple of 12, got %d', nSubcarriers);
end
if ~(mu >= 0 && mu <= 3 && mod(mu, 1) == 0)
    error('lib:ofdmDemod:badMu', 'ofdmDemod: mu must be an integer in 0..3, got %s', num2str(mu));
end

grid = nrOFDMDemodulate(waveform(:), nSubcarriers / 12, 15 * 2^mu, nSlot);
end
