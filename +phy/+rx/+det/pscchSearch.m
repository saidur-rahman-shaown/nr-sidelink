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
%        noiseVar           real, >0 -- for the LLR scaling
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

found      = false(1, numSubchannel);
sci1aBits  = false(A, numSubchannel);
startSubch = 0:numSubchannel - 1;
metric     = false(1, numSubchannel);

for x = 0:numSubchannel - 1
    cfg = pscchCfgTemplate;
    cfg.startPRB = x * subchSizeRb;

    ind = phy.ts38211.slPSCCHIndices(carrier, cfg);
    if max(ind(:, 1)) + 1 > size(grid, 1)
        continue;                      % this candidate runs off the top of the grid
    end
    sym = grid(sub2ind(size(grid), ind(:, 1) + 1, ind(:, 2) + 1));

    [bits, crcOk] = phy.chan.pscchRx(sym, carrier, cfg, A, noiseVar, listSize);
    found(x + 1)  = crcOk;
    metric(x + 1) = crcOk;
    if crcOk
        sci1aBits(:, x + 1) = logical(bits(:));
    end
end
end
