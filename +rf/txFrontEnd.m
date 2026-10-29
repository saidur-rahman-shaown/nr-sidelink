function [iq, pTxW] = txFrontEnd(waveform, pTxDbm)
%txFrontEnd Scale a baseband slot waveform to the transmit power -- the IQ handed to the channel.
%Spec:   none. TS 38.213 clause 16.2 sets the power (phy.ts38213.slPowerControl, max-power by
%        explicit decision); how a baseband waveform becomes radiated power is implementation,
%        which is why this is in +rf/ and not +phy/.
%Inputs: waveform  nSamples x 1 complex -- phy.lib.ofdmMod output, REs at unit average power
%        pTxDbm    real, dBm -- the PSSCH/PSCCH transmit power
%Outputs: iq    nSamples x 1 complex, in sqrt(watts): mean |iq|^2 over the slot's TRANSMITTED
%               samples equals pTxW
%         pTxW  real, W
%
%"Transmitted samples" excludes the guard symbol, which is all zeros (TS 38.211 8.2.1). Averaging
%over the whole slot instead would understate the power by the guard's share and put every link
%budget about 0.3 dB low. PA compression, EVM and spectral emission are not modelled.

MW_PER_W = 1000;
DB = 10;
pTxW = 10^(pTxDbm / DB) / MW_PER_W;
on = waveform ~= 0;
if ~any(on)
    iq = waveform;
    return;
end
iq = waveform * sqrt(pTxW / mean(abs(waveform(on)).^2));
end
