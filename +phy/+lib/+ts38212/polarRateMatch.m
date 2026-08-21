function out = polarRateMatch(in, K, E, iBIL)
%polarRateMatch Polar rate matching: sub-block interleaving, bit selection
%and coded-bit interleaving. Toolbox body: nrRateMatchPolar.
%Spec:   TS 38.212 V16.15.0, clause 5.4.1
%Inputs: in    column vector of 0/1 (or logical/int8), length N -- a
%              polar-encoded codeword (output of polarEncode)
%        K     nonnegative integer -- the information block length the
%              encoding started from (needed to place the rate-matched
%              output correctly; not itself rate-matched)
%        E     nonnegative integer -- rate-matched output length
%        iBIL  logical scalar -- coded-bit interleaving enable; false for
%              downlink configurations, true for uplink, per clause
%              5.4.1.3
%Outputs: out  E-by-1 column vector, logical -- the rate-matched codeword
out = logical(nrRateMatchPolar(double(in(:)), K, E, iBIL));
end
