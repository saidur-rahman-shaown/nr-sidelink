function x = slMSeq(taps, initState, len)
%slMSeq Generic binary maximal-length sequence (LFSR) generator.
%Spec:   TS 38.211 V16.10.0 -- the shared recurrence shape used by clause
%        8.4.2.2.1 (S-PSS) and clause 8.4.2.3.1 (S-SSS): x(i+N) = XOR of x at
%        stated tap offsets from i, for a degree-N register. No single clause
%        names this as a standalone primitive; it is generalised here because
%        both callers need the identical construction with different taps and
%        initial states, and duplicating the recurrence twice inline would be
%        exactly the kind of parallel copy portability.md's interface rule
%        warns against.
%Inputs: taps       row vector of feedback tap offsets, 0-based, each strictly
%                   less than N = numel(initState) (e.g. [4 0] for x(i+7) =
%                   x(i+4) xor x(i), i.e. degree N=7)
%        initState  1-by-N vector, the register's initial state written in the
%                   spec's own order [x(N-1) x(N-2) ... x(1) x(0)] -- copy it
%                   verbatim from the spec text, do not pre-reverse it
%        len        nonnegative integer, number of output values to generate
%Outputs: x  1-by-len logical row vector, x(0)..x(len-1)
N = numel(initState);
if any(taps < 0) || any(taps >= N)
    error('ts38211:slMSeq:badTaps', 'slMSeq: every tap must be in 0..%d, got [%s]', N-1, num2str(taps));
end
if ~isscalar(len) || len < 0 || mod(len, 1) ~= 0
    error('ts38211:slMSeq:badLen', 'slMSeq: len must be a nonnegative integer, got %s', mat2str(len));
end
bufLen = max(len, N);
xbuf = false(1, bufLen);
xbuf(1:N) = logical(initState(end:-1:1));   % xbuf(k+1) == x(k); initState is x(N-1)..x(0)
for i = 0:(len - N - 1)
    xbuf(i+N+1) = mod(sum(double(xbuf(i+taps+1))), 2);
end
x = xbuf(1:len);
end
