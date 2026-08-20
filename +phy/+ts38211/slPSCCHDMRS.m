function r = slPSCCHDMRS(NID, l, nsf, NsymbSlot, NRB)
%slPSCCHDMRS PSCCH demodulation reference signal sequence, one OFDM symbol.
%Spec:   TS 38.211 V16.10.0, clause 8.4.1.3.1
%Inputs: NID        integer, 0..65535 -- higher-layer parameter sl-DMRS-ScrambleID in SL-PSCCH-Config-r16
%        l          integer, >=0 -- OFDM symbol number within the slot
%        nsf        integer, >=0 -- slot number within a frame, n_{s,f}^mu
%        NsymbSlot  integer, >0 -- OFDM symbols per slot (14 normal CP, 12 extended)
%        NRB        integer, >0 -- number of PRBs assigned to PSCCH
%Outputs: r  (3*NRB)-by-1 complex column vector, r_l(0)..r_l(3*NRB-1), unit
%            average power (QPSK)
%
%r_l(m) = (1-2c(2m))/sqrt(2) + j(1-2c(2m+1))/sqrt(2) is exactly QPSK Gray
%mapping applied to consecutive pairs of Gold-sequence bits -- reuses
%lib.goldSeq + lib.modMap rather than a new primitive.
cinit = mod(2^17 * (NsymbSlot*nsf + l + 1) * (2*NID + 1) + 2*NID, 2^31);
len = 3 * NRB;
bits = phy.lib.goldSeq(cinit, 2*len);
r = phy.lib.modMap(bits, 'QPSK');
end
