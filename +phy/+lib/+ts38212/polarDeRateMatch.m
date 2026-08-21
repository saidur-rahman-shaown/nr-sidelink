function out = polarDeRateMatch(in, K, N, iBIL)
%polarDeRateMatch Polar rate-matching recovery: the inverse bit selection,
%sub-block de-interleaving and coded-bit de-interleaving.
%Toolbox body: nrRateRecoverPolar.
%Spec:   TS 38.212 V16.15.0, clause 5.4.1 (inverse)
%Inputs: in    column vector, length E -- soft or hard values recovered for
%              a rate-matched polar codeword (output of polarRateMatch, or
%              its received/demodulated counterpart)
%        K     nonnegative integer -- information block length the
%              original encoding used
%        N     nonnegative integer -- polar mother-code length the
%              original encoding used
%        iBIL  logical scalar -- must match the iBIL polarRateMatch used
%Outputs: out  N-by-1 column vector -- de-rate-matched codeword, ready for
%              polar decoding (not performed here)
out = nrRateRecoverPolar(double(in(:)), K, N, iBIL);
end
