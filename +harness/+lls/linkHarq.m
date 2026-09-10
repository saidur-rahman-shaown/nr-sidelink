function okByAttempt = linkHarq(lc, snrDb, nAttempts, stream)
%linkHarq One transport block over up to nAttempts transmissions, with soft combining.
%Spec:   none. The redundancy version sequence is TS 38.321 clause 5.22.1.3.1's; the SOFT
%        BUFFER is a receiver structure the spec does not describe.
%Inputs: lc         from harness.lls.linkConfig
%        snrDb      real, dB -- Es/N0 per RE, the same on every attempt
%        nAttempts  integer, >=1 -- transmissions to run
%        stream     RandStream
%Outputs: okByAttempt  1 x nAttempts logical -- whether the block had decoded by attempt n.
%                      Cumulative: once true it stays true, because a receiver that has already
%                      decoded does not un-decode
%
%WHY THE COMBINING LIVES HERE AND NOT IN slSchDecode
%-----------------------------------------------------
%phy.ts38212.slSchDecode decodes one redundancy version in isolation, because a normative
%package may not hold hidden state (.claude/rules/normative-packages.md) and a soft buffer is
%exactly that. nrULSCHDecoder keeps one internally, so the object is held here, in
%non-normative harness code, for the life of one transport block.
%
%This is worth several dB by the second attempt and is the reason the BLER table has a
%retransmission dimension at all. A table measured without combining describes a receiver that
%throws away everything it heard the first time, and using it would make blind retransmission
%look far weaker than it is.

decoder = nrULSCHDecoder;
decoder.TargetCodeRate        = lc.R;
decoder.TransportBlockLength  = lc.trblklen;
decoder.LDPCDecodingAlgorithm = 'Normalized min-sum';
decoder.MaximumLDPCIterationCount = 12;

rvSequence = [0 2 3 1];                       % clause 5.22.1.3.1's order
okByAttempt = false(1, nAttempts);
tbBits = [];
decoded = false;

for a = 1:nAttempts
    rv = rvSequence(mod(a - 1, numel(rvSequence)) + 1);
    r  = harness.lls.linkSlot(lc, snrDb, stream, rv, tbBits);
    tbBits = r.tbBits;
    if ~decoded
        % The decoder accumulates into its own soft buffer across calls, so each attempt is
        % decoded against everything heard so far rather than on its own.
        [tbRx, err] = decoder(double(r.dataLlr), lc.modScheme, 1, rv);
        decoded = ~err && isequal(logical(tbRx(:)), logical(tbBits(:)));
    end
    okByAttempt(a) = decoded;
end
end
