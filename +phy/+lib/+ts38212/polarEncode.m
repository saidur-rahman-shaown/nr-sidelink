function out = polarEncode(in, E, nMax, iIL)
%polarEncode Polar encoding: frozen-bit determination, input interleaving
%and encoding. Toolbox body: nrPolarEncode.
%Spec:   TS 38.212 V16.15.0, clause 5.3.1
%Inputs: in    column vector of 0/1 (or logical/int8), length K -- the
%              CRC-attached message (a single code block; C>1 from clause
%              5.2.1 polar segmentation is not handled by this wrapper)
%        E     nonnegative integer -- rate-matched output length this
%              encoding is sized for (N, the polar mother-code length, is
%              derived internally from K and E)
%        nMax  integer, 9 or 10 -- {9,true} is the downlink {nMax,iIL}
%              pairing, {10,false} the uplink pairing per clause 5.3.1;
%              caller supplies both, no default is assumed here since
%              clause 8's sidelink SCI framing (not yet extracted locally)
%              is what actually decides which pairing applies
%        iIL   logical scalar -- input interleaver enable, paired with nMax
%              as above
%Outputs: out  N-by-1 column vector, logical -- the polar-encoded codeword
if ~(isscalar(nMax) && (nMax == 9 || nMax == 10))
    error('lib:ts38212:polarEncode:badNMax', 'polarEncode: nMax must be 9 or 10, got %s', num2str(nMax));
end
out = logical(nrPolarEncode(double(in(:)), E, nMax, iIL));
end
