function [blk, err] = crcCheck(blkcrc, poly)
%crcCheck CRC verification and removal. Toolbox body: nrCRCDecode.
%Spec:   TS 38.212 V16.15.0, clause 5.1 (inverse)
%Inputs: blkcrc  column vector of 0/1 (or logical/int8), length A+L -- a
%                block with its clause-5.1 CRC parity bits attached
%        poly    char, one of '6','11','16','24A','24B','24C' -- must match
%                the polynomial crcEncode used to attach the CRC being
%                checked
%Outputs: blk  column vector, length A, logical -- blkcrc with the CRC
%              removed
%         err  uint32 scalar -- 0 if the recomputed CRC matches the attached
%              CRC, nonzero (the XOR difference) otherwise
legalPoly = {'6', '11', '16', '24A', '24B', '24C'};
if ~ismember(poly, legalPoly)
    error('lib:ts38212:crcCheck:badPoly', 'crcCheck: "%s" is not a clause 5.1 CRC polynomial', poly);
end
[blkOut, err] = nrCRCDecode(blkcrc(:), poly);
blk = logical(blkOut);
end
