function out = dciCrcEncode(blk, rnti)
%dciCrcEncode CRC attachment for DCI-style payloads (also used by SCI, minus masking).
%Spec:   TS 38.212 V16.15.0, clause 7.3.2
%Inputs: blk   column vector of 0/1 (or logical/int8), length A -- the payload
%        rnti  integer, 0..65535, or [] -- RNTI used to XOR-mask the low 16 bits of the 24-bit
%              CRC (clause 7.3.2's masking convention: the top 8 bits of the CRC are left
%              unmasked). [] skips masking entirely -- the case every sidelink caller in this
%              project uses, since clause 8.3.2/8.4.2 say "except that scrambling [this
%              masking] is not performed."
%Outputs: out  column vector, length A+24, logical -- [payload; 24 new parity bits]. The 24
%              ones prepended for the CRC calculation are NOT part of the output -- clause
%              7.3.2: a'_i=1 for i=0..23, a'_i=a_{i-24} for i=24..A+23; the parity bits are
%              computed over a', then b_k=a_k for k=0..A-1, b_k=p_{k-A} for k=A..A+23. The
%              prepended ones influence the parity only, then are discarded.
blk = logical(blk(:));
padded = [true(24, 1); blk];
if isempty(rnti)
    withCrc = phy.lib.ts38212.crcEncode(padded, '24C');
else
    withCrc = logical(nrCRCEncode(double(padded), '24C', rnti));
end
parity = withCrc(end - 23:end);
out = [blk; parity];
end
