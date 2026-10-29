function [iq, fs] = slotModulate(g, grid, nsf, pTxDbm)
%slotModulate A finished slot grid to transmit IQ: OFDM, then the RF power scaling.
%Spec:   TS 38.211 V16.10.0 clause 5.3.1 (OFDM baseband, via phy.lib.ofdmMod); power from
%        TS 38.213 16.2 (phy.ts38213.slPowerControl, max-power policy) applied by rf.txFrontEnd.
%Inputs: g       struct from stack.poolGeometry
%        grid    nSubcarriers x 14 complex -- PSCCH/PSSCH and/or PSFCH already mapped
%        nsf     integer -- slot number in the frame (CP pattern)
%        pTxDbm  real, dBm
%Outputs: iq  nSamples x 1 complex, sqrt(W)
%         fs  real, Hz
%
%A slot carrying both this UE's PSSCH and its PSFCH is scaled as one waveform to pTxDbm. TS 38.213
%16.2 gives PSSCH and PSFCH separate power rules and 16.2.4 prioritises between them; with the
%max-power policy both are P_CMAX and the split is not modelled.
[wave, fs] = phy.lib.ofdmMod(grid, g.mu, nsf);
iq = rf.txFrontEnd(wave, pTxDbm);
end
