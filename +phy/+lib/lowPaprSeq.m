function seq = lowPaprSeq(u, v, alpha, m)
%lowPaprSeq Low-PAPR (type 1) sequence generator. Toolbox body: nrLowPAPRS.
%Spec:   TS 38.211 V16.10.0, clause 5.2.2
%Inputs: u      sequence group number, integer 0..29
%        v      base sequence number, 0 or 1 (must be 0 when m < 72)
%        alpha  cyclic shift, radians
%        m      sequence length, nonnegative integer -- covers the whole clause
%               internally (phase-table construction for m < 30, cyclic-extended
%               Zadoff-Chu for m >= 30); there is no separate short/long form to
%               choose between at this call site
%Outputs: seq  m-by-1 complex column vector, constant modulus (|seq(k)| == 1)
%
%Verified: constant modulus at m=12 and m=36; a cyclic shift changes phase only,
%magnitude unchanged. See +phy/+lib/ch5-toolbox-survey.md.
%
%nrLowPAPRS also accepts a (u,cinit,m) "type 2" syntax -- that is TS 38.211
%clause 5.2.3, a different sequence family for Rel-16 DM-RS transform
%precoding on PUSCH/PUCCH, not the clause 5.2.2 sequence this wrapper covers.
%Confirmed empirically: the type-2 form is NOT constant modulus (it is a
%pi/2-BPSK-modulated, FFT-derived construction) -- do not call it expecting a
%low-PAPR result. If sidelink ever needs it, it is a separate wrapper.
if any(u < 0) || any(u > 29) || any(mod(u, 1) ~= 0)
    error('lib:lowPaprSeq:badU', 'lowPaprSeq: u must be an integer in 0..29, got [%s]', num2str(u));
end
if m < 72 && any(v ~= 0)
    error('lib:lowPaprSeq:badV', 'lowPaprSeq: v must be 0 when m < 72 (got m=%d, v=[%s])', m, num2str(v));
end
seq = nrLowPAPRS(u, v, alpha, m);
end
