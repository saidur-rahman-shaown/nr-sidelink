function [mibBits, crcOk] = slBchDecode(llr, listSize)
%slBchDecode SL-BCH transport channel processing, inverse: de-rate-match, polar decode, CRC.
%Spec:   the inverse of TS 38.212 V16.15.0 clause 8.1 (SL-BCH follows BCH per clause 7.1, with
%        payload generation and scrambling omitted), i.e. of slBchEncode. The CODE is
%        normative; the DECODER is not, so the list size is ours and this is verified by
%        recovering what slBchEncode produced.
%Inputs: llr       E-by-1 real column vector -- channel LLRs for the PSBCH codeword,
%                  **negative for a probable 1**. E is taken from numel(llr): it is fixed by
%                  the S-SSB's own structure, which a receiver knows before it decodes anything
%        listSize  integer, one of {1,2,4,8} -- SCL list size
%Outputs: mibBits  32-by-1 logical -- the MIB-SL payload, ready for phy.ts38212.mibSlUnpack
%         crcOk    logical -- the PSBCH block-error indication
%
%CRC24C WITHOUT THE 24-ONES PREPEND
%-----------------------------------
%slBchEncode attaches the CRC with phy.lib.ts38212.crcEncode (plain clause 5.1), not with
%dciCrcEncode (clause 7.3.2's 24-ones prepend). SL-BCH is a broadcast transport channel, not a
%control payload, so the DCI convention does not apply -- and the matching check here is
%crcCheck, not dciCrcCheck. Getting the pair wrong yields bits that are right and a CRC verdict
%that is always false, i.e. a receiver that appears never to acquire.

if ~any(listSize == [1 2 4 8])
    error('ts38212:slBchDecode:badList', 'slBchDecode: listSize must be 1, 2, 4 or 8, got %s', num2str(listSize));
end

MIB_SL_BITS = 32;                 % clause 8.1 via TS 38.331 MasterInformationBlockSidelink
E = numel(llr);
K = MIB_SL_BITS + 24;             % CRC24C
N = phy.lib.ts38212.polarMotherLength(K, E, 9);

recovered = phy.lib.ts38212.polarDeRateMatch(llr(:), K, N, false);
withCrc   = phy.lib.ts38212.polarDecode(recovered, K, N, listSize, 9, true, 24);
[mibBits, err] = phy.lib.ts38212.crcCheck(withCrc, '24C');
crcOk = (err == 0);
end
