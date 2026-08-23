function [blk, err] = dciCrcCheck(in, rnti)
%dciCrcCheck CRC verification for DCI-style payloads (also used by SCI). Inverse of dciCrcEncode.
%Spec:   TS 38.212 V16.15.0, clause 7.3.2 (inverse)
%Inputs: in    column vector of 0/1 (or logical/int8), length A+24 -- [payload; 24 parity bits],
%              the output of dciCrcEncode
%        rnti  integer, 0..65535, or [] -- must match the rnti dciCrcEncode used
%Outputs: blk  column vector, length A, logical -- the recovered payload
%         err  uint32 scalar -- 0 if the CRC verifies, nonzero otherwise
in = logical(in(:));
A = numel(in) - 24;
blk = in(1:A);
padded = [true(24, 1); blk];
reEncoded = [padded; in(A + 1:end)];
if isempty(rnti)
    [~, err] = phy.lib.ts38212.crcCheck(reEncoded, '24C');
else
    [~, err] = nrCRCDecode(double(reEncoded), '24C', rnti);
end
end
