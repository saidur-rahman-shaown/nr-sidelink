function out = ldpcDeRateMatch(in, trblklen, R, rv, modulation, nlayers, numCB)
%ldpcDeRateMatch LDPC rate-matching recovery: inverse of code block
%concatenation, bit interleaving and bit selection.
%Toolbox body: nrRateRecoverLDPC.
%Spec:   TS 38.212 V16.15.0, clause 5.4.2 and clause 5.5 (inverse, combined
%        -- see ldpcRateMatch's header for why there is one function per
%        direction rather than a separate cbConcat/cbDeconcat pair)
%Inputs: in          column vector, length G -- soft or hard values
%                    recovered for a rate-matched, concatenated LDPC
%                    codeword
%        trblklen    nonnegative integer -- length of the original
%                    transport block (before CRC attachment; used to
%                    recover C, the LDPC-encoded code block lengths,
%                    filler positions and lifting size)
%        R           real scalar, 0..1 -- target code rate used at encode
%                    time
%        rv          integer, 0..3 -- redundancy version, must match the
%                    rv ldpcRateMatch used
%        modulation  char, one of 'pi/2-BPSK','BPSK','QPSK','16QAM',
%                    '64QAM','256QAM'
%        nlayers     integer, 1..4 -- number of transmission layers
%        numCB       nonnegative integer, or [] -- number of code blocks
%                    to recover; [] recovers the full number implied by
%                    trblklen and R
%Outputs: out  K-by-C matrix -- recovered LDPC-encoded code blocks, one
%              per column, filler positions marked Inf (per
%              nrRateRecoverLDPC's convention for soft-value filler)
legalMod = {'pi/2-BPSK', 'BPSK', 'QPSK', '16QAM', '64QAM', '256QAM'};
if ~ismember(modulation, legalMod)
    error('lib:ts38212:ldpcDeRateMatch:badModulation', 'ldpcDeRateMatch: "%s" is not a Rel-16 sidelink modulation scheme', modulation);
end
if ~(isscalar(rv) && any(rv == 0:3))
    error('lib:ts38212:ldpcDeRateMatch:badRv', 'ldpcDeRateMatch: rv must be 0..3, got %s', num2str(rv));
end
if isempty(numCB)
    out = nrRateRecoverLDPC(double(in(:)), trblklen, R, rv, modulation, nlayers);
else
    out = nrRateRecoverLDPC(double(in(:)), trblklen, R, rv, modulation, nlayers, numCB);
end
end
