function [mibBits, crcOk] = psbchRx(eqSymbols, carrier, cfg, noiseVar, listSize)
%psbchRx PSBCH receive chain: equalised symbols to MIB-SL bits. Normative inverses only.
%Spec:   the inverse of TS 38.211 clause 8.4.1 (descramble, demap) and TS 38.212 clause 8.1
%        (de-rate-match, polar decode, CRC), via slBchDecode.
%Inputs: eqSymbols  nDataRE-by-1 complex column -- the PSBCH data REs, already equalised.
%                   Channel estimation and equalisation live in +phy/+rx/
%        carrier    scalar struct, slCarrierConfig
%        cfg        scalar struct from phy.ts38211.slPSBCHConfig
%        noiseVar   real >0, or nDataRE-by-1 -- post-equalisation noise variance
%        listSize   integer, one of {1,2,4,8}
%Outputs: mibBits  32-by-1 logical -- ready for phy.ts38212.mibSlUnpack
%         crcOk    logical -- the PSBCH block-error indication, and hence the acquisition test
%
%cinit = N_ID^SL for PSBCH (clause 8.4.1), re-initialised at the start of each S-SS/PSBCH block
%-- kept visible at this call site per +phy/+chan/CLAUDE.md rather than hidden in a helper.
%Descrambling on soft values is a sign flip, not an XOR: hard-slicing first to XOR would throw
%away the soft information the polar list decoder exists to use.

llr = phy.lib.demodLLR(eqSymbols(:), 'QPSK', noiseVar);

c   = phy.lib.goldSeq(cfg.NIDSL, numel(llr));
llr = llr .* (1 - 2 * double(c));

[mibBits, crcOk] = phy.ts38212.slBchDecode(llr, listSize);
end
