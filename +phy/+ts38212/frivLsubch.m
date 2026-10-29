function LsubCH = frivLsubch(friv, Nsub, maxReserve)
%frivLsubch Recover L_subCH, the allocation width, from an FRIV value.
%Spec:   TS 38.214 V16.17.0, clause 8.1.5: FRIV = n_start,1 + sum_{i=1}^{L-1}(N+1-i) for
%        sl-MaxNumPerReserve 2, and n_start,1 + n_start,2*(N+1-L) + sum_{i=1}^{L-1}(N+1-i)^2 for
%        3 (N = sl-NumSubchannel, L = L_subCH). The inverse of phy.ts38212.frivEncode's L term.
%Inputs: friv        nonnegative integer -- the decoded SCI-1A 'Frequency resource assignment'
%        Nsub        integer, 1..27 -- sl-NumSubchannel
%        maxReserve  integer, 2 or 3 -- sl-MaxNumPerReserve
%Outputs: LsubCH  integer, 1..Nsub
%
%WHY L IS RECOVERABLE AT ALL
%---------------------------
%For a given L the n_start terms span exactly (N+1-L)^(maxReserve-1) values, and the summation is
%precisely the total span of every narrower L. So the FRIV values of different widths occupy
%disjoint, contiguous bands and L is the band FRIV falls in. A receiver needs this: the PSCCH
%sits in the lowest sub-channel of the allocation (TS 38.214 clause 8.1.2.2) and says nothing
%else about its width, so without FRIV the PSSCH's PRB count is unknown.
%
%frivDecode takes L as an INPUT and recovers only the starts; this is the step before it.

MAX_RESERVE_SET = [2 3];      % sl-MaxNumPerReserve-r16 ENUMERATED {n2, n3}
NSUB_MAX = 27;                % sl-NumSubchannel-r16 INTEGER (1..27)
if ~any(maxReserve == MAX_RESERVE_SET)
    error('ts38212:frivLsubch:badMaxReserve', 'frivLsubch: maxReserve must be 2 or 3, got %s', num2str(maxReserve));
end
if ~(Nsub >= 1 && Nsub <= NSUB_MAX && mod(Nsub, 1) == 0)
    error('ts38212:frivLsubch:badNsub', 'frivLsubch: Nsub must be an integer in 1..27, got %s', num2str(Nsub));
end
if ~(friv >= 0 && mod(friv, 1) == 0)
    error('ts38212:frivLsubch:badFriv', 'frivLsubch: FRIV must be a nonnegative integer, got %s', num2str(friv));
end
p = maxReserve - 1;                     % the exponent of each band's span
base = 0;
for L = 1:Nsub
    span = (Nsub + 1 - L)^p;
    if friv < base + span
        LsubCH = L;
        return;
    end
    base = base + span;
end
error('ts38212:frivLsubch:outOfRange', 'frivLsubch: FRIV %d exceeds every L_subCH band for Nsub=%d', friv, Nsub);
end
