function r = slPSBCHDMRS(NIDSL, Nsymb)
%slPSBCHDMRS PSBCH demodulation reference signal sequence for one S-SS/PSBCH block.
%Spec:   TS 38.211 V16.10.0, clause 8.4.1.4.1
%Inputs: NIDSL  integer, 0..671 -- N_ID^SL, the combined sidelink sync identity
%               (compose it at the caller from NID1/NID2, per the existing
%               interface rule -- not recomposed here)
%        Nsymb  integer, 13 (normal CP) or 11 (extended CP) -- N_symb^S-SSB
%Outputs: r  (33*(Nsymb-4))-by-1 complex column vector, unit average power (QPSK)
%
%ONE cinit for the whole block occasion (not re-initialised per symbol, unlike
%PSCCH/PSSCH DM-RS) -- a single continuous sequence spans every DM-RS symbol
%in the block, consumed in mapping order by slPSBCHDMRSIndices.
cinit = NIDSL;
len = 33 * (Nsymb - 4);
bits = phy.lib.goldSeq(cinit, 2*len);
r = phy.lib.modMap(bits, 'QPSK');
end
