function pDetect = psfchDetect(sinrDb)
%psfchDetect Probability of correctly detecting one PSFCH cyclic shift. A PLACEHOLDER.
%Spec:   none -- PHY abstraction. The thing being abstracted is TS 38.211 clause 8.3.3's
%        PSFCH format 0: a single-PRB, one-symbol sequence carrying its HARQ-ACK bit in a
%        cyclic shift, detected by correlation rather than decoded as a coded block.
%Inputs: sinrDb  real array, dB -- SINR at the PSFCH's single PRB. NaN where unheard
%Outputs: pDetect  real array in [0,1] -- probability the correct cyclic shift is detected
%
%WHY THIS IS NOT blerLookup
%---------------------------
%PSFCH carries one bit in a sequence, not a transport block through a decoder. Its detection
%curve is a correlation threshold, steeper and shifted well below any MCS's waterfall -- a
%sequence detector works at SINRs where no coded block would. Reusing the transport-block
%curve here would make feedback fail at roughly the same range as data, which is exactly
%backwards: the whole point of a one-bit sequence is that it survives further out.
%
%A logistic with a low midpoint and a steep slope. Right shape, invented numbers, same status
%as +harness/+phyabs/blerLookup and to be replaced by the same Phase 3 measurement.
%
%WHAT IS NOT MODELLED, AND WHY IT MATTERS
%-----------------------------------------
%A missed detection here becomes a DTX at the transmitter, and TS 38.321 clause 5.22.1.3.3
%counts consecutive DTX toward radio link failure. So this curve sets the RLF rate directly.
%Not modelled: false alarm (detecting a shift nobody sent) and the ACK/NACK confusion that
%comes from detecting the WRONG shift of the right sequence. Both are real and both are
%asymmetric in consequence -- a false ACK loses a packet silently, a false NACK only wastes a
%retransmission -- so a real curve must report them as a pair, the way +phy/+rx/CLAUDE.md
%already requires of detection generally.

midpointDb = -8;      % a sequence detector works well below any coded block's waterfall
slopePerDb = 1.2;

pDetect = 1 ./ (1 + exp(-slopePerDb * (sinrDb - midpointDb)));
pDetect(isnan(sinrDb)) = 0;
end
