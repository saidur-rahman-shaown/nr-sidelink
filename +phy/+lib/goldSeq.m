function seq = goldSeq(cinit, len)
%goldSeq Gold/PRBS sequence generator. Toolbox body: nrPRBS.
%Spec:   TS 38.211 V16.10.0, clause 5.2.1
%Inputs: cinit  integer, 0 to 2^31-1 -- x2 LFSR initialisation
%        len    nonnegative integer -- number of output bits, c(0)..c(len-1)
%Outputs: seq  len-by-1 logical column vector, c(n) for n = 0..len-1
%
%Nc = 1600 offset verified against a hand-rolled LFSR (x1 fixed-init, x2 seeded
%from cinit's 31-bit expansion) for cinit in {0, 1, 12345, 2^31-1} -- bit-for-bit
%match in all four cases. See +phy/+lib/ch5-toolbox-survey.md.
seq = logical(nrPRBS(cinit, len));
end
