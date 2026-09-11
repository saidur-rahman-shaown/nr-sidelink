function [ackBit, detected, metric] = psfchRx(eqSymbols, carrier, pool, dp, ackNackOnly, threshold)
%psfchRx PSFCH format 0 detection: correlate against both candidate cyclic shifts.
%Spec:   the inverse of TS 38.211 clause 8.3.4, with the two candidate shifts given by TS 38.213
%        Table 16.3-2 (ACK-or-NACK) or Table 16.3-3 (NACK-only), via
%        phy.ts38213.psfchCyclicShiftMcs. Detection is NOT normative -- the spec fixes what is
%        transmitted, not how it is found -- so this lives behind the same line +phy/+chan/
%        draws for every other channel, and the threshold is ours to choose.
%Inputs: eqSymbols    12-by-1 complex -- the PSFCH content symbol's REs, already equalised
%        carrier      scalar struct, slCarrierConfig
%        pool         scalar struct -- the sl_PSFCH_Config_r16 fields phy.ts38211.slPSFCHConfig
%                     takes, carrying sl-PSFCH-HopID
%        dp           scalar struct -- the same dynamicParams the transmitter used (.m0, .lp,
%                     .nsf, .NsymbSlot, .startPRB, .symbol). Its .mcs is IGNORED and replaced
%                     per hypothesis: mcs is precisely the field that encodes the ACK/NACK bit,
%                     so a receiver that trusted the transmitter's value would be reading the
%                     answer rather than detecting it
%        ackNackOnly  logical -- true for NACK-only reporting (SCI 2-B, or 2-A cast type 11),
%                     where Table 16.3-3 defines NO shift for ACK
%        threshold    real, >0 -- correlation magnitude, relative to the sequence length, below
%                     which nothing is declared detected
%Outputs: ackBit    integer, 0 (NACK) or 1 (ACK), or -1 when nothing was detected
%         detected  logical -- whether the correlation cleared the threshold
%         metric    1 x 2 real -- normalised correlation against [NACK, ACK] hypotheses. Both
%                   returned so a caller can see the margin, not just the winner
%
%DETECTION IS A CORRELATION, AND THE TWO HYPOTHESES ARE NOT SYMMETRIC
%----------------------------------------------------------------------
%In ACK-or-NACK mode both shifts are legal and the larger correlation wins, subject to the
%threshold. In NACK-only mode Table 16.3-3 gives ACK the literal entry "N/A" -- there is no ACK
%shift at all, so the ONLY question is whether a NACK is present. +phy/+ts38213/
%psfchCyclicShiftMcs rejects harqAckBit = 1 in that mode for exactly this reason, and this
%function mirrors it: silence means success there, and testing an ACK hypothesis would let
%noise on an unused shift be read as a positive acknowledgement.
%
%AN UNDETECTED PSFCH IS A DTX, NOT A NACK, AND THEY DIFFER IN CONSEQUENCE
%-------------------------------------------------------------------------
%ackBit = -1 with detected = false is the DTX case, and TS 38.321 clause 5.22.1.3.3 counts
%consecutive DTX toward radio link failure while a NACK merely triggers a retransmission.
%Collapsing the two -- returning NACK when nothing was heard -- makes a UE that has walked out
%of range look like a lossy-but-alive link and it never declares RLF.

if numel(eqSymbols) ~= 12
    error('chan:psfchRx:badLength', 'psfchRx: PSFCH format 0 occupies one PRB, 12 subcarriers; got %d', numel(eqSymbols));
end
if ~(threshold > 0)
    error('chan:psfchRx:badThreshold', 'psfchRx: threshold must be > 0');
end

NACK_BIT = 0;
ACK_BIT  = 1;

rx = eqSymbols(:);
rx = rx / max(norm(rx), eps);        % normalise so the threshold is scale-free

metric = zeros(1, 2);
metric(1) = hypothesisCorr(rx, carrier, pool, dp, NACK_BIT, ackNackOnly);
if ackNackOnly
    % Table 16.3-3 defines no ACK shift; testing one would read noise as a positive ack.
    metric(2) = 0;
else
    metric(2) = hypothesisCorr(rx, carrier, pool, dp, ACK_BIT, ackNackOnly);
end

[best, which] = max(metric);
if best < threshold
    ackBit   = -1;
    detected = false;
else
    ackBit   = which - 1;            % index 1 -> NACK (0), index 2 -> ACK (1)
    detected = true;
end
end

% =========================================================================
function c = hypothesisCorr(rx, carrier, pool, dp, harqAckBit, ackNackOnly)
%hypothesisCorr Normalised correlation of the received PRB against one candidate shift.
%The config is rebuilt per hypothesis rather than patched, because slPSFCHConfig derives alpha
%from m0 and mcs together -- overwriting alpha on a copy would leave u and v resolved from the
%wrong inputs if that derivation ever widens.
dp.mcs = phy.ts38213.psfchCyclicShiftMcs(harqAckBit, ackNackOnly);
h   = phy.ts38211.slPSFCHConfig(pool, dp);
ref = phy.ts38211.slPSFCH(carrier, h);
ref = ref(:) / max(norm(ref), eps);
c   = abs(ref' * rx);
end
