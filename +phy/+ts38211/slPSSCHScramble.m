function scrambled = slPSSCHScramble(bits, placeholderMask, NID, MbitSCI2)
%slPSSCHScramble PSSCH scrambling, including SCI-2 placeholder-bit handling.
%Spec:   TS 38.211 V16.10.0, clause 8.3.1.1
%Inputs: bits             column vector of 0/1 (or logical), length M_bit --
%                         value at placeholderMask positions is ignored
%        placeholderMask  column vector of logical, length M_bit, true where
%                         bit i is an SCI placeholder ('x' in the spec
%                         pseudocode) rather than a real coded bit. WHICH
%                         positions are placeholders is TS 38.212 information
%                         (not built yet) -- caller supplies this mask.
%        NID              integer, 0..65535 -- N_ID = N_ID^X mod 2^16, the
%                         decimal value of the CRC on the associated PSCCH
%                         (TS 38.212 clause 8.3.2 -- caller-computed)
%        MbitSCI2         integer, 0..numel(bits) -- M_bit,SCI2, the boundary
%                         separating the 2nd-stage-SCI portion (indices
%                         0..MbitSCI2-1) from the data portion
%Outputs: scrambled  column vector of logical, length M_bit
%
%Faithful transcription of the clause's pseudocode, not a simplification: a
%placeholder position copies b~(i-2) and does NOT consume a scrambling-
%sequence value; a real bit at index i consumes c(i - M~_i,j), where
%M~_i,j = j (placeholders seen so far) in the SCI-2 portion, and the FIXED
%value M_bit,SCI2 in the data portion regardless of further placeholders --
%these two regions do not share one running "skip count", which is easy to
%get wrong by over-simplifying into a single counter.
Mbit = numel(bits);
if numel(placeholderMask) ~= Mbit
    error('ts38211:slPSSCHScramble:badMask', 'slPSSCHScramble: placeholderMask must match bits in length');
end
if MbitSCI2 < 0 || MbitSCI2 > Mbit
    error('ts38211:slPSSCHScramble:badBoundary', 'slPSSCHScramble: MbitSCI2 must be in 0..numel(bits)');
end

cinit = 2^15 * NID + 1010;   % clause 8.3.1.1 states no mod here (unlike the DM-RS cinit
                              % formulas); harmless either way since NID <= 65535 keeps
                              % this under 2^31, but kept literal rather than adding one
c = phy.lib.goldSeq(cinit, Mbit);   % safe upper bound: max(i - M~_i,j) < Mbit always

bits = logical(bits(:));
placeholderMask = logical(placeholderMask(:));
scrambled = false(Mbit, 1);
j = 0;
for i = 0:(Mbit-1)
    if i < MbitSCI2
        Mij = j;
    else
        Mij = MbitSCI2;
    end
    if placeholderMask(i+1)
        if i < 2
            error('ts38211:slPSSCHScramble:badPlaceholder', ...
                'slPSSCHScramble: placeholder bit at i=%d has no b~(i-2) to copy from', i);
        end
        scrambled(i+1) = scrambled(i-1);
        j = j + 1;
    else
        scrambled(i+1) = xor(bits(i+1), c(i - Mij + 1));
    end
end
end
