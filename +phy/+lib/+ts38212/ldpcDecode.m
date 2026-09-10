function [bits, crcOk] = ldpcDecode(cbLlr, bgn, maxIter, trblklen, R, numCB)
%ldpcDecode LDPC decoding and code-block desegmentation. Toolbox body: nrLDPCDecode.
%Spec:   the inverse of TS 38.212 V16.15.0 clause 5.3.2 (LDPC coding) and clause 5.2.2 (code
%        block segmentation). Decoding is not normative; the code is.
%Inputs: cbLlr     N-by-C real matrix -- de-rate-matched LLRs, one column per code block, as
%                  phy.lib.ts38212.ldpcDeRateMatch returns them. **Negative for a probable 1**
%        bgn       integer, 1 or 2 -- base graph number, matching the encoder's
%        maxIter    positive integer -- decoder iteration cap. A tuning knob, not a spec
%                  quantity; the BLER curves state what they were measured at
%        trblklen  positive integer -- transport block length before CRC, to undo segmentation
%        R         real, 0<R<1 -- target code rate, needed to recover the segmentation
%        numCB     positive integer -- number of code blocks
%Outputs: bits   trblklen-by-1 int8 column -- the recovered transport block, CRCs removed
%         crcOk  logical -- whether the transport block CRC checked
%
%TWO CRC LAYERS, AND ONLY ONE OF THEM DECIDES THE BLOCK ERROR
%-------------------------------------------------------------
%Clause 5.2.2 attaches a CRC to every code block when there is more than one, and clause 6.2.1
%attaches one to the transport block. The per-code-block CRCs exist for early termination, not
%for the error decision: a transport block is in error if and only if the TRANSPORT-block CRC
%fails. Reporting a code-block CRC failure as a block error double-counts on segmented blocks
%and produces a BLER curve that is pessimistic by a factor that grows with block size --
%invisible unless it is compared against an unsegmented one.

if ~any(bgn == [1 2])
    error('lib:ts38212:ldpcDecode:badBgn', 'ldpcDecode: bgn must be 1 or 2, got %s', num2str(bgn));
end
if ~(maxIter >= 1 && mod(maxIter, 1) == 0)
    error('lib:ts38212:ldpcDecode:badIter', 'ldpcDecode: maxIter must be a positive integer, got %s', num2str(maxIter));
end

decoded = nrLDPCDecode(double(cbLlr), bgn, maxIter);
[bits, err] = nrCodeBlockDesegmentLDPC(decoded, bgn, trblklen + 24);
[bits, tbErr] = nrCRCDecode(bits, '24A');
crcOk = (tbErr == 0);
end
