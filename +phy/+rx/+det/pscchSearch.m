function [found, sci1aBits, startSubch, metric] = pscchSearch(grid, carrier, pscchCfgTemplate, numSubchannel, subchSizeRb, A, noiseVar, listSize)
%pscchSearch Blind PSCCH decode across every candidate sub-channel start.
%Spec:   none -- blind detection is not specified. TS 38.214 clause 8.1.2.2 places the PSCCH in
%        the LOWEST sub-channel of whatever allocation carries it, which is what makes the
%        candidate set the sub-channel starts and nothing finer.
%Inputs: grid               nSubcarriers-by-nSymbols complex -- the demodulated received slot
%        carrier            scalar struct, slCarrierConfig
%        pscchCfgTemplate   scalar struct from phy.ts38211.slPSCCHConfig -- its .startPRB is
%                           REPLACED per candidate; every other field is the pool's and fixed
%        numSubchannel      integer, >=1 -- sl-NumSubchannel, i.e. how many candidates exist
%        subchSizeRb        integer, >=1 -- sl-SubchannelSize
%        A                  integer -- SCI-1A payload length in bits
%        noiseVar           real -- post-equalisation noise variance for the LLR scaling, or
%                           **0 to use the per-candidate estimate** from the candidate's own
%                           DM-RS. Zero is the honest setting: a receiver blind-searching does
%                           not know the noise on a candidate it has not yet decoded
%        listSize           integer, one of {1,2,4,8}
%Outputs: found       1 x numSubchannel logical -- whether a PSCCH decoded at each candidate
%         sci1aBits   A-by-numSubchannel -- the payload recovered at each candidate; the
%                     columns where found is false are meaningless
%         startSubch  1 x numSubchannel integer -- 0..numSubchannel-1, for convenience
%         metric      1 x numSubchannel logical -- the CRC verdict, which IS the detection
%                     metric here: a polar CRC is the only honest present/absent test a
%                     receiver has for a control channel
%
%THE RECEIVER IS NOT HANDED THE TRANSMISSION LIST
%--------------------------------------------------
%This is the module form of what +harness/+sls/slotStep does inline: a loop over candidate
%POSITIONS, not over transmissions that exist. A receiver does not know the allocation until it
%has decoded the SCI that describes it, so it must try every sub-channel start. Iterating the
%transmissions instead is genie-aided and silently grants the receiver knowledge of exactly
%what was sent and where.
%
%THE CRC IS THE DETECTOR, AND IT HAS A FALSE-ALARM RATE
%--------------------------------------------------------
%There is no energy threshold here: a candidate is "found" exactly when its 24-bit CRC checks
%after polar decoding. That is the right test -- but it is not free of false alarms. With a
%24-bit CRC roughly one in 16.8 million decodes of pure noise passes, and a receiver sweeping
%numSubchannel candidates every slot takes that many draws surprisingly quickly in a long run.
%+phy/+rx/CLAUDE.md requires detection to report false alarm and missed detection AS A PAIR;
%this function supplies the raw verdicts and the measurement of that pair belongs to whoever
%sweeps it.

if ~(numSubchannel >= 1 && mod(numSubchannel, 1) == 0)
    error('rx:det:pscchSearch:badNumSubchannel', 'pscchSearch: numSubchannel must be a positive integer, got %s', num2str(numSubchannel));
end

% =========================================================================
function ref = localPscchDmrs(cfg)
%localPscchDmrs Regenerate the PSCCH DM-RS a transmitter at this candidate would have sent.
nPerSym = 3 * cfg.NRB;
ref = complex(zeros(nPerSym * numel(cfg.symbols), 1));
for s = 1:numel(cfg.symbols)
    ref((s - 1) * nPerSym + (1:nPerSym)) = phy.ts38211.slPSCCHDMRS( ...
        cfg.DMRS_NID, cfg.symbols(s), cfg.nsf, cfg.NsymbSlot, cfg.NRB);
end
end

found      = false(1, numSubchannel);
sci1aBits  = false(A, numSubchannel);
startSubch = 0:numSubchannel - 1;
metric     = false(1, numSubchannel);

for x = 0:numSubchannel - 1
    cfg = pscchCfgTemplate;
    cfg.startPRB = x * subchSizeRb;

    ind     = phy.ts38211.slPSCCHIndices(carrier, cfg);
    dmrsInd = phy.ts38211.slPSCCHDMRSIndices(cfg.startPRB, cfg.NRB, cfg.symbols);
    if max([ind(:, 1); dmrsInd(:, 1)]) + 1 > size(grid, 1)
        continue;                      % this candidate runs off the top of the grid
    end

    % Each candidate is estimated and equalised from ITS OWN DM-RS. A blind search cannot
    % borrow a channel estimate from elsewhere in the slot: the candidate may be empty, may
    % hold a different transmitter's PSCCH, and in general sees a different channel. Decoding
    % raw REs instead -- which the first version of this function did -- only works when the
    % channel is flat and the receiver is already scaled, i.e. exactly the conditions under
    % which blind search is easiest anyway.
    [sym, dmrsSym] = phy.rx.ce.gridExtract(grid, ind, dmrsInd);
    refDmrs = localPscchDmrs(cfg);
    [hEst, nvEst] = phy.rx.ce.dmrsEstimate(dmrsSym, refDmrs, dmrsInd, ind, size(grid, 1));
    [eqSym, eqNv] = phy.rx.eq.zfEqualise(sym, hEst, nvEst);
    if noiseVar > 0
        eqNv = eqNv * 0 + noiseVar;    % caller-supplied variance overrides the estimate
    end

    [bits, crcOk] = phy.chan.pscchRx(eqSym, carrier, cfg, A, eqNv, listSize);
    found(x + 1)  = crcOk;
    metric(x + 1) = crcOk;
    if crcOk
        sci1aBits(:, x + 1) = logical(bits(:));
    end
end
end

% =========================================================================
function ref = localPscchDmrs(cfg)
%localPscchDmrs Regenerate the PSCCH DM-RS a transmitter at this candidate would have sent.
%Its cinit walks with the symbol index, so one call per symbol -- never one long sequence
%sliced up, which would put symbol 2's reference on symbol 1's REs and leave the channel
%estimate correlated with noise rather than with the channel.
nPerSym = 3 * cfg.NRB;
ref = complex(zeros(nPerSym * numel(cfg.symbols), 1));
for s = 1:numel(cfg.symbols)
    ref((s - 1) * nPerSym + (1:nPerSym)) = phy.ts38211.slPSCCHDMRS( ...
        cfg.DMRS_NID, cfg.symbols(s), cfg.nsf, cfg.NsymbSlot, cfg.NRB);
end
end
