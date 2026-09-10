function [waveform, sampleRate] = ofdmMod(grid, mu, nSlot)
%ofdmMod OFDM modulation: resource grid to time-domain samples. Toolbox body: nrOFDMModulate.
%Spec:   TS 38.211 V16.10.0, clause 5.3.1 (OFDM baseband signal generation) and clause 5.3.2
%        (cyclic prefix lengths per numerology). Normal CP only -- extended CP is legal at
%        mu=2 and is not exercised anywhere in this tree.
%Inputs: grid   nSubcarriers-by-nSymbols complex matrix -- the resource grid, subcarrier k on
%               rows (ascending, common-resource-block-0-relative, matching the [k l] index
%               convention every +phy/+ts38211/ index function returns) and OFDM symbol l on
%               columns
%        mu     integer, 0..3 -- mu_SL, the SCS configuration. SCS = 15*2^mu kHz
%        nSlot  integer, >=0 -- slot number within the frame; sets the CP pattern, since the
%               first symbol of every half-subframe carries a longer CP than the rest
%Outputs: waveform    nSamples-by-1 complex column vector
%         sampleRate  real, Hz -- the sample rate the FFT size implies. Returned rather than
%                     left for the caller to recompute: the caller needs it to add noise at a
%                     stated SNR, and deriving it independently is how a 10*log10(Nfft/nUsed)
%                     factor goes missing
%
%The grid's subcarrier count fixes the number of resource blocks, and therefore the FFT size:
%nSubcarriers must be a multiple of 12.

if ~(mu >= 0 && mu <= 3 && mod(mu, 1) == 0)
    error('lib:ofdmMod:badMu', 'ofdmMod: mu must be an integer in 0..3, got %s', num2str(mu));
end
if mod(size(grid, 1), 12) ~= 0
    error('lib:ofdmMod:badGrid', 'ofdmMod: the grid must hold a whole number of resource blocks (12 subcarriers each), got %d rows', size(grid, 1));
end
if ~(nSlot >= 0 && mod(nSlot, 1) == 0)
    error('lib:ofdmMod:badSlot', 'ofdmMod: nSlot must be a nonnegative integer, got %s', num2str(nSlot));
end

scsKHz = 15 * 2^mu;
nrb    = size(grid, 1) / 12;

waveform   = nrOFDMModulate(grid, scsKHz, nSlot);
info       = nrOFDMInfo(nrb, scsKHz);
sampleRate = info.SampleRate;
end
