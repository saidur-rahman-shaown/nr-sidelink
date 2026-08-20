function scrambledBits = scramble(bits, cinit)
%scramble Generic scrambling: XOR a bit sequence with a Gold sequence.
%Spec:   TS 38.211 V16.10.0, clause 5.2.1 (the generic scrambling operation only
%        -- the per-channel cinit formula is NOT here; it stays visible at the
%        call site in +phy/+ts38211/ or +phy/+chan/, per +phy/+ts38211/CLAUDE.md's
%        interface rule, so a change to one channel's cinit derivation can never
%        silently affect another's)
%Inputs: bits   column vector of 0/1 (or logical), the codeword to scramble
%        cinit  integer, 0 to 2^31-1 -- caller-derived per channel
%Outputs: scrambledBits  column vector, same length as bits, logical
n = numel(bits);
seq = phy.lib.goldSeq(cinit, n);
scrambledBits = xor(logical(bits(:)), seq);
end
