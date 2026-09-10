function s = noiseScale(nSubcarriers, mu, nSlot)
%noiseScale Time-domain noise amplitude that yields unit noise variance per resource element.
%Spec:   none -- a calibration, not a procedure.
%Inputs: nSubcarriers  integer, a multiple of 12 -- grid height
%        mu            integer, 0..3
%        nSlot         integer, >=0
%Outputs: s  real, >0 -- multiply unit-variance complex Gaussian time samples by this to get
%            exactly unit noise variance per RE after phy.lib.ofdmDemod
%
%MEASURED, NOT DERIVED
%---------------------
%The relationship between time-domain noise power and per-RE noise power after OFDM
%demodulation depends on the FFT size, the occupied-to-total subcarrier ratio and whatever
%normalisation the demodulator applies. Writing that factor as a formula means encoding an
%assumption about the demodulator's internal scaling, and a wrong assumption shifts every BLER
%curve horizontally by a constant -- the single most damaging error possible in a table that
%exists to be read as "BLER at SNR x", because the curves keep their correct shape and nothing
%looks wrong.
%
%So it is measured: push pure noise through the actual demodulator and read the variance back.
%Deterministic seed, so a run is reproducible and the calibration is identical every time.

nSym  = 14;
stream = RandStream('mt19937ar', 'Seed', 20260910);
probeGrid = complex(zeros(nSubcarriers, nSym));
[probeWave, ~] = phy.lib.ofdmMod(probeGrid, mu, nSlot);
n = (randn(stream, numel(probeWave), 1) + 1j * randn(stream, numel(probeWave), 1)) / sqrt(2);
demod = phy.lib.ofdmDemod(n, nSubcarriers, mu, nSlot);
measured = var(demod(:));
s = 1 / sqrt(measured);
end
