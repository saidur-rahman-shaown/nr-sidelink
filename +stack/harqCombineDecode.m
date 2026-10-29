function [tbBits, ok, buf] = harqCombineDecode(llr, buf, trblklen, R, rv, modScheme, maxIter)
%harqCombineDecode Decode an SL-SCH transmission combined with the HARQ soft buffer.
%Spec:   the soft-buffer half of TS 38.321 V16.22.0 clause 5.22.2.2.2 ("if this is a
%        retransmission: if the data for this TB has not yet been successfully decoded: instruct the
%        physical layer to combine the received data with the data currently in the soft buffer
%        for this TB and attempt to decode the combined data"), done the way the inverse of TS
%        38.212 5.4.2 allows: each redundancy version is rate-recovered into the circular-buffer
%        positions it was taken from (phy.lib.ts38212.ldpcDeRateMatch), and the buffers are SUMMED
%        before LDPC decoding. Non-normative: receivers are not specified.
%Inputs: llr        G x 1 real -- the SL-SCH data LLRs of this transmission (negative = probable 1)
%        buf        K x C real, or [] -- the process's soft buffer from earlier transmissions of
%                   this TB; [] for a new transmission
%        trblklen   integer -- TBS in bits, from the SCI-1A MCS and allocation
%        R          real -- target code rate
%        rv         integer, 0..3 -- this transmission's redundancy version (SCI-2)
%        modScheme  char
%        maxIter    integer -- LDPC iterations
%Outputs: tbBits  trblklen x 1 logical
%         ok      logical -- transport block CRC
%         buf     K x C real -- the updated soft buffer, to keep if ok is false
%
%THE BUFFER IS RETURNED, NOT HELD. The decoder object +harness/+lls/linkHarq uses keeps its soft
%buffer inside itself, which is hidden state; here the buffer is a value the caller stores per
%receive HARQ process (stack.rxSlot), so a UE's whole receive state still serialises.
%
%Why it matters: incremental redundancy only works WITH combining. RV 2 is mostly parity, so a
%receiver that lost RV 0 and decodes RV 2 alone usually fails -- the first feedback run here
%NACKed exactly that case, the transmitter ran out of resources, and RLC AM had to recover a
%packet that HARQ should have.

FILLER = Inf;                                 % nrRateRecoverLDPC marks filler bits as Inf
cb = phy.lib.ts38212.ldpcDeRateMatch(double(llr(:)), trblklen, R, rv, modScheme, 1, []);
if isempty(buf) || ~isequal(size(buf), size(cb))
    buf = cb;
else
    filler = isinf(cb);
    buf(~filler) = buf(~filler) + cb(~filler);
    buf(filler) = FILLER;
end
info = nrDLSCHInfo(trblklen, R);              % the base graph and CRC TS 38.212 6.2.1/6.2.2 select
dec = nrLDPCDecode(buf, info.BGN, maxIter, 'Algorithm', 'Normalized min-sum');
blk = nrCodeBlockDesegmentLDPC(dec, info.BGN, trblklen + info.L);
[tb, crcErr] = nrCRCDecode(blk, info.CRC);
tbBits = logical(tb);
ok = crcErr == 0;
end
