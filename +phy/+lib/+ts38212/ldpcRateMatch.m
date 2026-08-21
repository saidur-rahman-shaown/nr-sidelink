function out = ldpcRateMatch(in, outlen, rv, modulation, nlayers, Nref)
%ldpcRateMatch LDPC rate matching (bit selection, bit interleaving) and
%code block concatenation in one call. Toolbox body: nrRateMatchLDPC.
%Spec:   TS 38.212 V16.15.0, clause 5.4.2 (rate matching) and clause 5.5
%        (code block concatenation) -- nrRateMatchLDPC's own documentation
%        states it performs both together when given the full
%        per-transport-block matrix, so there is no separate cbConcat
%        wrapper. See ch5-toolbox-survey.md in this folder.
%Inputs: in          N-by-C matrix -- LDPC-encoded code blocks (output of
%                    ldpcEncode), one column per code block, filler
%                    positions marked -1
%        outlen      nonnegative integer -- G, the total rate-matched and
%                    concatenated output length
%        rv          integer, 0..3 -- redundancy version
%        modulation  char, one of 'pi/2-BPSK','BPSK','QPSK','16QAM',
%                    '64QAM','256QAM' -- the six Rel-16 sidelink modulation
%                    orders (the toolbox's '1024QAM' is out of this
%                    project's scope, same restriction as
%                    phy.lib.modMap)
%        nlayers     integer, 1..4 -- number of transmission layers
%        Nref        nonnegative integer, or [] -- limited-buffer
%                    soft-buffer size per clause 5.4.2.1; [] means no
%                    limit
%Outputs: out  outlen-by-1 column vector, logical -- the rate-matched,
%              concatenated codeword g(0)..g(outlen-1)
legalMod = {'pi/2-BPSK', 'BPSK', 'QPSK', '16QAM', '64QAM', '256QAM'};
if ~ismember(modulation, legalMod)
    error('lib:ts38212:ldpcRateMatch:badModulation', 'ldpcRateMatch: "%s" is not a Rel-16 sidelink modulation scheme', modulation);
end
if ~(isscalar(rv) && any(rv == 0:3))
    error('lib:ts38212:ldpcRateMatch:badRv', 'ldpcRateMatch: rv must be 0..3, got %s', num2str(rv));
end
if ~(isscalar(nlayers) && nlayers >= 1 && nlayers <= 4 && mod(nlayers, 1) == 0)
    error('lib:ts38212:ldpcRateMatch:badNlayers', 'ldpcRateMatch: nlayers must be an integer in 1..4, got %s', num2str(nlayers));
end
if isempty(Nref)
    out = logical(nrRateMatchLDPC(double(in), outlen, rv, modulation, nlayers));
else
    out = logical(nrRateMatchLDPC(double(in), outlen, rv, modulation, nlayers, Nref));
end
end
