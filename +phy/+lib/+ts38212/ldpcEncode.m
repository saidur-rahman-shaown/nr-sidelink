function out = ldpcEncode(in, bgn)
%ldpcEncode LDPC encoding. Toolbox body: nrLDPCEncode.
%Spec:   TS 38.212 V16.15.0, clause 5.3.2
%Inputs: in   K-by-C matrix of 0/1 (or logical/int8/double), filler bits
%             (if any) represented as -1 -- one code block segment per
%             column, the output of cbSegment
%        bgn  integer, 1 or 2 -- LDPC base graph number; must match the bgn
%             cbSegment used to produce in (base graph *selection* is not
%             this function's job -- see cbSegment's header)
%Outputs: out  N-by-C matrix -- LDPC-encoded codeword per column, filler
%              positions still marked -1
if ~(isscalar(bgn) && (bgn == 1 || bgn == 2))
    error('lib:ts38212:ldpcEncode:badBgn', 'ldpcEncode: bgn must be 1 or 2, got %s', num2str(bgn));
end
out = nrLDPCEncode(double(in), bgn);
end
