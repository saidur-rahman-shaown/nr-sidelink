function [rbStart, nRb] = bwpLocation(locationAndBandwidth)
%bwpLocation Decode a BWP's locationAndBandwidth into its first PRB and PRB count.
%Spec:   TS 38.331 V16.22.0, BWP field description locationAndBandwidth: "Frequency domain
%        location and bandwidth of this bandwidth part. The value of the field shall be
%        interpreted as resource indicator value (RIV) as defined TS 38.214 with assumptions as
%        described in TS 38.213, clause 12, i.e. setting N_BWP^size = 275." The RIV itself is
%        TS 38.214 V16.17.0, clause 5.1.2.2.2: RIV = N(L-1) + RB_start if (L-1) <= floor(N/2),
%        else RIV = N(N-L+1) + (N-1-RB_start), with 1 <= L <= N - RB_start.
%Inputs: locationAndBandwidth  integer, 0..37949 -- the raw field (INTEGER (0..37949))
%Outputs: rbStart  integer, 0..274 -- RB_start, the first PRB of the BWP relative to the
%                  carrier's offsetToCarrier, in this BWP's subcarrier spacing
%         nRb      integer, 1..275 -- L_RBs, the BWP's PRB count
%
%Both branches are tried and the one whose own condition holds is the answer. Decoding with the
%first branch's arithmetic alone mis-reads every wide BWP: 1099, which this repository's example
%config once carried, reads naively as 4 PRBs starting at PRB 274, but it is the second branch's
%encoding of a 273-PRB BWP starting at PRB 0 -- which is what was really wrong with it, since the
%carrier it sat on has 51 PRBs. cfgValidate now checks that containment.

N = 275;                            % N_BWP^size per the field description
RIV_MAX = 37949;                    % INTEGER (0..37949)
if ~(locationAndBandwidth >= 0 && locationAndBandwidth <= RIV_MAX && mod(locationAndBandwidth, 1) == 0)
    error('cfg:bwpLocation:badRiv', 'bwpLocation: locationAndBandwidth must be an integer in 0..%d, got %s', RIV_MAX, num2str(locationAndBandwidth));
end
q = floor(locationAndBandwidth / N);
r = mod(locationAndBandwidth, N);

% Branch 1: (L-1) <= floor(N/2), RIV = N(L-1) + RB_start.
L1 = q + 1;
s1 = r;
if (L1 - 1) <= floor(N / 2) && L1 >= 1 && L1 <= N - s1
    rbStart = s1;
    nRb = L1;
    return;
end
% Branch 2: RIV = N(N-L+1) + (N-1-RB_start).
L2 = N - q + 1;
s2 = N - 1 - r;
if (L2 - 1) > floor(N / 2) && L2 >= 1 && L2 <= N - s2
    rbStart = s2;
    nRb = L2;
    return;
end
error('cfg:bwpLocation:invalid', 'bwpLocation: %d is not a valid RIV for N = %d (no branch yields 1 <= L <= N - RB_start)', locationAndBandwidth, N);
end
