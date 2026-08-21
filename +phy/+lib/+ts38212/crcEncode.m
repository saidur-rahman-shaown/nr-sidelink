function blkcrc = crcEncode(blk, poly)
%crcEncode CRC calculation and appending. Toolbox body: nrCRCEncode.
%Spec:   TS 38.212 V16.15.0, clause 5.1
%Inputs: blk   column vector of 0/1 (or logical/int8), length A -- the block
%              to protect
%        poly  char, one of '6','11','16','24A','24B','24C' -- selects the
%              generator polynomial and CRC length L (6, 11, 16, 24, 24, 24
%              bits respectively)
%Outputs: blkcrc  column vector, length A+L, logical -- blk with the CRC
%                 parity bits p(0)..p(L-1) appended per clause 5.1's b(k)
%                 relation
legalPoly = {'6', '11', '16', '24A', '24B', '24C'};
if ~ismember(poly, legalPoly)
    error('lib:ts38212:crcEncode:badPoly', 'crcEncode: "%s" is not a clause 5.1 CRC polynomial', poly);
end
blkcrc = logical(nrCRCEncode(blk(:), poly));
end
