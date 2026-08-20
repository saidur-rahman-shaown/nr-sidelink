function d = slPSSCH(carrier, cfg, codedBits, placeholderMask)
%slPSSCH PSSCH scrambling and modulation (an already-coded codeword in,
%modulation symbols out -- mirrors nrPDSCH, which stops at the same point;
%38.212 coding that produces codedBits/placeholderMask is a separate,
%not-yet-built package). Layer mapping, precoding, and resource mapping
%(clauses 8.3.1.3, 8.3.1.4, 8.3.1.5) are NOT implemented here -- see
%+phy/+ts38211/CLAUDE.md, they depend on clauses 7.3.1.3 and 6.3.1.5 of the
%same spec document, not extracted locally yet.
%Spec:   TS 38.211 V16.10.0, clause 8.3.1.1 (scrambling), 8.3.1.2 (modulation)
%Inputs: carrier          scalar struct, slCarrierConfig -- unused here,
%                         accepted for call-signature uniformity
%        cfg              scalar struct from slPSSCHConfig()
%        codedBits        column vector of 0/1 (or logical), length M_bit
%        placeholderMask  column vector of logical, length M_bit -- see
%                         slPSSCHScramble()
%Outputs: d  M_symb-by-1 complex column vector: the QPSK-modulated SCI-2
%            portion (M_bit,SCI2/2 symbols) followed by the cfg.modScheme-
%            modulated data portion, concatenated -- d^(q) in the spec,
%            M_symb = M_bit,SCI2/2 + (M_bit - M_bit,SCI2)/Q_m
%#ok<*INUSD>
scrambled = phy.ts38211.slPSSCHScramble(codedBits, placeholderMask, cfg.NID, cfg.MbitSCI2);
dSCI2 = phy.lib.modMap(scrambled(1:cfg.MbitSCI2), 'QPSK');
dData = phy.lib.modMap(scrambled(cfg.MbitSCI2+1:end), cfg.modScheme);
d = [dSCI2; dData];
end
