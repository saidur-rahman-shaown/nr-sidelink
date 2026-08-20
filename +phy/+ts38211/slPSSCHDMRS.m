function r = slPSSCHDMRS(NID, l, nsf, NsymbSlot, len)
%slPSSCHDMRS PSSCH demodulation reference signal sequence, one OFDM symbol.
%Spec:   TS 38.211 V16.10.0, clause 8.4.1.1.1
%Inputs: NID        integer, 0..65535 -- N_ID = N_ID^X mod 2^16, where N_ID^X
%                   is the decimal value of the CRC on the PSCCH associated
%                   with this PSSCH (TS 38.212 clause 7.3.2 -- not built yet;
%                   caller supplies the already-computed value)
%        l          integer, >=0 -- OFDM symbol number within the slot
%        nsf        integer, >=0 -- slot number within a frame, n_{s,f}^mu
%        NsymbSlot  integer, >0 -- OFDM symbols per slot (14 or 12)
%        len        integer, >0 -- number of DM-RS RE pairs needed in this
%                   symbol (RE-mapping positions, clause 6.4.1.1.3, are not
%                   implemented yet -- see slPSSCHDMRSIndices' absence and
%                   +phy/+ts38211/CLAUDE.md; this function only generates the
%                   sequence values, the caller must place them)
%Outputs: r  len-by-1 complex column vector, r_l(0)..r_l(len-1), unit average
%            power (QPSK)
%
%Textually the same cinit formula as slPSCCHDMRS (clause 8.4.1.3.1) -- same
%arithmetic, different NID source, kept as separate functions since the
%source of NID must stay visible at the call site (existing interface rule).
cinit = mod(2^17 * (NsymbSlot*nsf + l + 1) * (2*NID + 1) + 2*NID, 2^31);
bits = phy.lib.goldSeq(cinit, 2*len);
r = phy.lib.modMap(bits, 'QPSK');
end
