function [sci1aBits, crcOk] = pscchRx(eqSymbols, carrier, cfg, A, noiseVar, listSize)
%pscchRx PSCCH receive chain: equalised symbols to SCI-1A bits. Normative inverses only.
%Spec:   the inverse of TS 38.211 clause 8.3.2 (descramble, demap) and TS 38.212 clause
%        8.3.2-8.3.4 (de-rate-match, polar decode, CRC), via sci1aChainDecode.
%Inputs: eqSymbols  nDataRE-by-1 complex column -- the PSCCH data REs, **already channel-
%                   estimated and equalised**. Extraction from the grid, channel estimation and
%                   equalisation are NOT normative and live in +phy/+rx/; +phy/+chan/CLAUDE.md
%                   draws that line and this signature is where it lands
%        carrier    scalar struct, slCarrierConfig
%        cfg        scalar struct from phy.ts38211.slPSCCHConfig
%        A          positive integer -- SCI-1A payload length in bits
%        noiseVar   real, >0 -- post-equalisation noise variance, for the LLR scaling
%        listSize   integer, one of {1,2,4,8} -- SCL list size
%Outputs: sci1aBits  A-by-1 logical column -- ready for phy.ts38212.sci1aUnpack
%         crcOk      logical -- the PSCCH block-error indication
%
%DESCRAMBLING ON SOFT VALUES IS A SIGN FLIP, NOT AN XOR
%-------------------------------------------------------
%The transmitter XORs the coded bits with a Gold sequence; the receiver has LLRs, not bits, so
%the inverse is to negate the LLR wherever the sequence bit is 1. Hard-slicing first in order
%to XOR would throw away exactly the soft information the polar list decoder exists to use, and
%costs several dB at the waterfall -- while still working perfectly at high SNR, which is what
%makes it easy to ship.
%
%cinit = 1010 is fixed by clause 8.3.2 for PSCCH -- not derived from any identity, unlike every
%other channel in clause 8. Kept at this call site rather than inside a helper, per
%+phy/+chan/CLAUDE.md's rule that the per-channel derivation stays visible where it is used.

llr = phy.lib.demodLLR(eqSymbols(:), 'QPSK', noiseVar);

pscchScramblingCinit = 1010;                    % clause 8.3.2, fixed
c   = phy.lib.goldSeq(pscchScramblingCinit, numel(llr));
llr = llr .* (1 - 2 * double(c));

[sci1aBits, crcOk] = phy.ts38212.sci1aChainDecode(llr, A, listSize);
end
