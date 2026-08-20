function d = slPSCCH(carrier, cfg, codedBits)
%slPSCCH PSCCH scrambling and modulation (an already-coded codeword in, QPSK
%symbols out -- mirrors nrPDSCH, which stops at the same point; 38.212 coding
%that produces codedBits is a separate, not-yet-built package).
%Spec:   TS 38.211 V16.10.0, clause 8.3.2.1 (scrambling), 8.3.2.2 (modulation)
%Inputs: carrier    scalar struct, slCarrierConfig -- unused here, accepted
%                   for the uniform (carrier, config, codedBits) call signature
%                   every channel function in +phy/+ts38211/CLAUDE.md commits to
%        cfg        scalar struct from slPSCCHConfig() -- also unused here
%                   (the fixed cinit below doesn't depend on any config field)
%        codedBits  column vector of 0/1 (or logical), length M_bit, even
%Outputs: d  (M_bit/2)-by-1 complex column vector, QPSK symbols, unit average power
%
%cinit = 1010 is fixed by the spec -- not a config field, not derived from
%anything. This is the one channel in clause 8 with no dynamic scrambling ID.
%#ok<*INUSD>
scrambled = phy.lib.scramble(codedBits, 1010);
d = phy.lib.modMap(scrambled, 'QPSK');
end
