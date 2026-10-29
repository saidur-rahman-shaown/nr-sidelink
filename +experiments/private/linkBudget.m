function snrDb = linkBudget(dM, nRb, s, losMode)
%linkBudget Mean per-RE SNR at distance dM for an nRb-wide PSSCH at P_CMAX.
%Spec:   none -- the same budget harness.field.run reports (linkSnrDb): transmit power spread
%        evenly over the allocation's subcarriers, TR 38.901 RMa path loss through
%        harness.chanmodel.pathloss, thermal noise kTB*NF per 30 kHz RE (rf.noiseFloorDbm).
%        Fading is NOT in this number; it is in the measured BLER curve the SNR is read against.
%Inputs: dM       vector, metres
%        nRb      PRBs the transmission occupies -- a wider allocation spreads the same power
%                 thinner, so its per-RE SNR is lower at every distance
%        s        experiments.settings()
%        losMode  optional, default s.radio.losMode
if nargin < 4, losMode = s.radio.losMode; end
r = s.radio;
pl = harness.chanmodel.pathlossModel('rma', struct('fcHz', r.fcHz, 'losMode', losMode, ...
    'hTxM', r.hAntM, 'hRxM', r.hAntM));
SCS_HZ = 30e3;
SC_PER_RB = 12;
noiseReDbm = rf.noiseFloorDbm(SCS_HZ, r.noiseFigureDb);
snrDb = zeros(size(dM));
for k = 1:numel(dM)
    snrDb(k) = r.pCmaxDbm - 10 * log10(SC_PER_RB * nRb) - harness.chanmodel.pathloss(pl, dM(k)) - noiseReDbm;
end
end
