function d = slPSBCH(carrier, cfg, codedBits)
%slPSBCH PSBCH scrambling and modulation (an already-coded MIB-SL payload in,
%QPSK symbols out -- mirrors nrPBCH; 38.212 coding that produces codedBits is
%a separate, not-yet-built package).
%Spec:   TS 38.211 V16.10.0, clause 8.3.3.1 (scrambling), 8.3.3.2 (modulation)
%Inputs: carrier    scalar struct, slCarrierConfig -- unused here, accepted
%                   for the uniform (carrier, config, codedBits) call signature
%        cfg        scalar struct from slPSBCHConfig()
%        codedBits  column vector of 0/1 (or logical), length M_bit, even
%Outputs: d  (M_bit/2)-by-1 complex column vector, QPSK symbols, unit average power
%
%cinit = N_ID^SL, re-initialised at the start of each S-SS/PSBCH block -- the
%same value slPSBCHDMRS() uses, by design (both are one cinit per occasion).
%#ok<*INUSD>
scrambled = phy.lib.scramble(codedBits, cfg.NIDSL);
d = phy.lib.modMap(scrambled, 'QPSK');
end
