function [tbBits, crcOk] = slSchDecode(llr, trblklen, R, rv, modulation, nlayers, maxIter)
%slSchDecode SL-SCH transport channel processing, inverse: de-rate-match, LDPC decode, CRC check.
%Spec:   the inverse of TS 38.212 V16.15.0 clause 8.2.1 via clauses 6.2.1-6.2.6, i.e. of
%        slSchEncode. Toolbox body: nrULSCHDecoder, the counterpart of the nrULSCH object
%        slSchEncode uses -- the same pairing argument +phy/+ts38212/CLAUDE.md makes for the
%        encoder applies to the decoder.
%Inputs: llr         G-by-1 real column vector -- channel LLRs for the SL-SCH portion,
%                    **negative for a probable 1**
%        trblklen    positive integer -- transport block size in bits, from
%                    phy.ts38214.tbsDetermine. The receiver knows it from the MCS and
%                    allocation signalled in the SCI it has already decoded
%        R           real, 0<R<1 -- target code rate from the MCS
%        rv          integer, 0..3 -- redundancy version, from SCI-2
%        modulation  char -- 'QPSK','16QAM','64QAM','256QAM'
%        nlayers     integer, 1 or 2
%        maxIter     positive integer -- LDPC decoder iteration cap. A tuning knob, not a spec
%                    quantity; any BLER curve must state what it was measured at
%Outputs: tbBits  trblklen-by-1 logical column -- the recovered transport block
%         crcOk   logical -- whether the TRANSPORT-block CRC verified
%
%SOFT COMBINING IS NOT DONE HERE
%--------------------------------
%This decodes one redundancy version in isolation. A real HARQ receiver accumulates LLRs across
%retransmissions in a soft buffer and decodes the sum, which is worth several dB by the second
%attempt. nrULSCHDecoder can do that -- it keeps per-process soft buffers -- but only if the
%caller holds one decoder object per HARQ process across slots, and this tree's normative
%packages may not hold hidden state (.claude/rules/normative-packages.md). So combining belongs
%to whoever owns the HARQ buffers, and +harness/+lls/ models it by accumulating LLRs itself.
%A curve measured here without combining understates a retransmitting link.
%
%The TRANSPORT-block CRC decides the block error, not the per-code-block CRCs: those exist for
%early termination. Counting a code-block failure as a block error double-counts on segmented
%transport blocks, by a factor that grows with block size.

legal = {'QPSK', '16QAM', '64QAM', '256QAM'};
if ~ismember(modulation, legal)
    error('ts38212:slSchDecode:badModulation', 'slSchDecode: "%s" is not in Table 8.3.1.2-1', modulation);
end
if ~(rv >= 0 && rv <= 3 && mod(rv, 1) == 0)
    error('ts38212:slSchDecode:badRv', 'slSchDecode: rv must be an integer in 0..3, got %s', num2str(rv));
end
if ~(maxIter >= 1 && mod(maxIter, 1) == 0)
    error('ts38212:slSchDecode:badIter', 'slSchDecode: maxIter must be a positive integer, got %s', num2str(maxIter));
end

decoder = nrULSCHDecoder;
decoder.TargetCodeRate       = R;
decoder.TransportBlockLength = trblklen;
decoder.LDPCDecodingAlgorithm = 'Normalized min-sum';
decoder.MaximumLDPCIterationCount = maxIter;

[tb, err] = decoder(double(llr(:)), modulation, nlayers, rv);
tbBits = logical(tb);
crcOk  = ~err;
end
