function [sinrDb, rxPowerDbm, canHear, sinrPscchDb] = slotSinr(air, posXY, radio, numSubchannel, pscchPrb, subchSizeRb)
%slotSinr Per-link SINR for every transmission in one slot, at every UE.
%Spec:   none -- this is the channel SAP, our own boundary. It is called ONCE per slot for the
%        whole scenario rather than once per link, because interference is a property of the
%        slot: computing it per link invites counting a transmission as its own interferer or
%        missing one that started after the victim was evaluated.
%Inputs: air            1 x nTx struct array -- this slot's on-air transmissions, from
%                       +rf/toAir. Fields used: .ueId .posXY .txPowerDbm .startSubch .LsubCH
%        posXY          nUe x 2 real, metres -- every UE's position this slot
%        radio          scalar struct: .fcHz .bwHz .noiseFigureDb .plExponent .plRefDistM
%        numSubchannel  integer, >=1 -- sl-NumSubchannel
%        pscchPrb       integer, >=1 -- sl-FreqResourcePSCCH, PRBs the PSCCH occupies inside
%                       the LOWEST sub-channel of the PSSCH allocation
%        subchSizeRb    integer, >=1 -- sl-SubchannelSize, PRBs per sub-channel
%Outputs: sinrDb      nTx x nUe real, dB -- SINR of transmission i as seen by UE j.
%                     NaN where UE j cannot hear transmission i at all (see canHear)
%         rxPowerDbm  nTx x nUe real, dBm -- received power before interference
%         canHear     nTx x nUe logical -- false where j is i's own transmitter, or where j
%                     transmitted anything this slot
%         sinrPscchDb nTx x nUe real, dB -- SINR of transmission i's PSCCH, over the PSCCH's
%                     own narrow band rather than the whole PSSCH allocation. See below
%
%HALF-DUPLEX IS FIRST CLASS, NOT AN IMPAIRMENT ADDED LATER
%---------------------------------------------------------
%A UE that transmits in a slot receives nothing in it. That is the single largest source of
%packet loss in dense sidelink, it is why +phy/+ts38214/sensingDbMarkUnmonitored exists, and
%modelling it as an afterthought understates loss in exactly the regime the KPI is about. Every
%UE appearing anywhere in `air` is deaf for the whole slot.
%
%INTERFERENCE IS SCALED BY FREQUENCY OVERLAP
%-------------------------------------------
%Two transmissions in the same slot interfere only where their sub-channel ranges overlap, and
%an interferer covering half the victim's bandwidth contributes half its power. Full power
%regardless of overlap over-states interference in a lightly-loaded pool; ignoring partial
%overlap under-states it in a heavily-loaded one. Both matter here, so the fraction is carried.
%
%WHY PSCCH GETS ITS OWN SINR, AND WHY IT IS *NOT* A BANDWIDTH ADVANTAGE
%-----------------------------------------------------------------------
%PSCCH occupies sl-FreqResourcePSCCH PRBs inside the lowest sub-channel of the allocation. It
%is tempting to conclude that the narrower band gives it a noise advantage of
%10*log10(L_subCH*subchSizeRb/pscchPrb). **It does not.** For a fixed total transmit power the
%spectral density is constant, so signal and noise shrink together with the band and the SNR is
%exactly the same -- this function computed a 4.8 dB advantage on paper and measured 0.0 dB,
%which is the correct answer. Control reaches further than data because of its far lower
%effective CODE RATE (a few tens of bits spread over the PSCCH's REs, against PSSCH at the
%signalled MCS), and that belongs in the BLER model, not here. +harness/+sls/ decodes SCI at a
%deliberately low effective MCS for exactly this reason.
%
%What DOES differ, and why this output is not redundant, is the INTERFERENCE. An interferer
%overlapping only part of the PSSCH allocation still covers all of the PSCCH's sub-channel, or
%none of it. So the two SINRs diverge whenever interference is partial-band -- which is the
%normal case in a pool where allocations differ in width and position.
%
%The path loss model is a documented PLACEHOLDER -- see +harness/+chanmodel/pathlossDb. No
%fading, no shadowing, no antenna pattern: a deterministic distance-based link. Absolute
%PRR-versus-distance results are meaningless until it is replaced; comparisons between policies
%on the same channel are not.

nTx = numel(air);
nUe = size(posXY, 1);
sinrDb      = nan(nTx, nUe);
rxPowerDbm  = nan(nTx, nUe);
sinrPscchDb = nan(nTx, nUe);
canHear     = false(nTx, nUe);
if nTx == 0
    return;
end
if pscchPrb > subchSizeRb
    error('chanmodel:slotSinr:pscchTooWide', 'slotSinr: sl-FreqResourcePSCCH (%d PRB) cannot exceed sl-SubchannelSize (%d PRB)', pscchPrb, subchSizeRb);
end

% ---- who is deaf this slot -------------------------------------------------
isTransmitting = false(1, nUe);
for i = 1:nTx
    isTransmitting(air(i).ueId) = true;
end

% ---- received power of every transmission at every UE ----------------------
for i = 1:nTx
    d  = sqrt(sum((posXY - air(i).posXY).^2, 2))';       % 1 x nUe
    pl = harness.chanmodel.pathlossDb(d, radio.fcHz, radio.plExponent, radio.plRefDistM);
    rxPowerDbm(i, :) = air(i).txPowerDbm - pl;
end
rxPowerMw = 10.^(rxPowerDbm / 10);

% ---- interference and noise, per victim ------------------------------------
for i = 1:nTx
    loI  = air(i).startSubch;
    hiI  = loI + air(i).LsubCH - 1;
    bwI  = radio.bwHz * air(i).LsubCH / numSubchannel;
    nMw  = 10.^(rf.noiseFloorDbm(bwI, radio.noiseFigureDb) / 10);

    interfMw = zeros(1, nUe);
    for k = 1:nTx
        if k == i
            continue;
        end
        loK = air(k).startSubch;
        hiK = loK + air(k).LsubCH - 1;
        nOverlap = max(0, min(hiI, hiK) - max(loI, loK) + 1);
        if nOverlap == 0
            continue;
        end
        interfMw = interfMw + rxPowerMw(k, :) * (nOverlap / air(i).LsubCH);
    end

    sinrDb(i, :) = 10 * log10(rxPowerMw(i, :) ./ (nMw + interfMw));

    % ---- the same again over the PSCCH's band, in the LOWEST sub-channel ----
    % The PSCCH sits in sub-channel loI, so this transmission puts pscchPrb/(LsubCH*subchSize)
    % of its power there, and an interferer covering that sub-channel puts
    % pscchPrb/(LsubCH_k*subchSize) of its own.
    % Noise and signal are both taken over the PSCCH's own band. They scale together, so this
    % is not an SNR advantage -- it is what makes the INTERFERENCE term band-correct.
    bwPscch  = radio.bwHz * pscchPrb / (numSubchannel * subchSizeRb);
    nPscchMw = 10.^(rf.noiseFloorDbm(bwPscch, radio.noiseFigureDb) / 10);
    sigPscchMw = rxPowerMw(i, :) * (pscchPrb / (air(i).LsubCH * subchSizeRb));
    intPscchMw = zeros(1, nUe);
    for k = 1:nTx
        if k == i
            continue;
        end
        loK = air(k).startSubch;
        hiK = loK + air(k).LsubCH - 1;
        if loI < loK || loI > hiK
            continue;                 % this interferer has no energy in the PSCCH's sub-channel
        end
        intPscchMw = intPscchMw + rxPowerMw(k, :) * (pscchPrb / (air(k).LsubCH * subchSizeRb));
    end
    sinrPscchDb(i, :) = 10 * log10(sigPscchMw ./ (nPscchMw + intPscchMw));

    hear = ~isTransmitting;                 % half-duplex: a transmitting UE hears nothing
    hear(air(i).ueId) = false;              % and nobody decodes their own transmission
    canHear(i, :)     = hear;
end

sinrDb(~canHear)      = NaN;
rxPowerDbm(~canHear)  = NaN;
sinrPscchDb(~canHear) = NaN;
end
