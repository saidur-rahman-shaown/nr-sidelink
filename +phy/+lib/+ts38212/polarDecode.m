function bits = polarDecode(llrN, K, N, listSize, nMax, iIL, crcLen)
%polarDecode Polar successive-cancellation-list decoding. Toolbox body: nrPolarDecode.
%Spec:   the inverse of TS 38.212 V16.15.0 clause 5.3.1 (polar encoding), with the CRC of
%        clause 5.1 / 7.3.2 used as the list-selection criterion. Decoding is NOT normative --
%        the spec fixes the code, not how it is decoded -- so this is verified by recovering
%        what phy.lib.ts38212.polarEncode produced, over the parameter range, rather than
%        against anyone else's decoder.
%Inputs: llrN      N-by-1 real column vector -- channel LLRs already put back on the mother
%                  code by phy.lib.ts38212.polarDeRateMatch, **negative for a probable 1**
%                  (phy.lib.demodLLR's convention). De-rate-matching is a SEPARATE call because
%                  its iBIL flag differs per channel -- SCI-1A uses false (clause 7.3.4) and
%                  SCI-2 uses true (clause 5.4.1 with IBIL=1) -- and folding it in here would
%                  hide a per-channel parameter inside a generic decoder
%        K         positive integer -- information block length INCLUDING its CRC bits
%        N         positive integer -- mother-code length, from
%                  phy.lib.ts38212.polarMotherLength(K, E, nMax)
%        listSize  integer, one of {1,2,4,8} -- SCL list size. A decoder tuning knob, not a
%                  spec quantity: 8 is the conventional operating point
%        nMax      integer, 9 or 10 -- n_max, clause 5.3.1's mother-code cap. 9 for uplink and
%                  sidelink control, 10 for downlink
%        iIL       logical -- input interleaving, matching what the encoder used
%        crcLen    integer, 6, 11 or 24 -- the CRC length embedded in K, the list-selection
%                  criterion
%Outputs: bits  K-by-1 int8 column -- the recovered bits **with their CRC still attached**
%
%THE CRC IS LEFT ON, DELIBERATELY
%---------------------------------
%This function does not check or strip the CRC, because it cannot know which convention
%attached it. Clause 7.3.2's DCI/SCI payloads get a 24-ones prepend before CRC24C
%(phy.lib.ts38212.dciCrcEncode) while clause 5.1's plain payloads do not
%(phy.lib.ts38212.crcEncode) -- and stripping with the wrong one produces bits that are right
%and a CRC verdict that is always false, which reads as a receiver that never decodes anything.
%The caller applies the check function that matches the encode function it used, keeping the
%pair symmetric. A failed check is the normal outcome at low SNR, not an exception, so those
%functions report it as a value too.
%
%The list size is the one number here that is ours to choose rather than the spec's. Raising it
%buys fractions of a dB at linear cost; the BLER curves this tree produces state the list size
%they were measured at, because a curve measured at L=8 does not describe a receiver running
%L=1 and the difference is large enough to matter at the waterfall.

if ~any(listSize == [1 2 4 8])
    error('lib:ts38212:polarDecode:badList', 'polarDecode: listSize must be 1, 2, 4 or 8, got %s', num2str(listSize));
end
if ~any(nMax == [9 10])
    error('lib:ts38212:polarDecode:badNMax', 'polarDecode: nMax must be 9 or 10, got %s', num2str(nMax));
end
if ~any(crcLen == [6 11 24])
    error('lib:ts38212:polarDecode:badCrcLen', 'polarDecode: crcLen must be 6, 11 or 24, got %s', num2str(crcLen));
end
if numel(llrN) ~= N
    error('lib:ts38212:polarDecode:badLlrLength', 'polarDecode: llrN must be N=%d long (run polarDeRateMatch first), got %d', N, numel(llrN));
end

% E = N here: the sequence is already back on the mother code, so no further rate
% recovery is wanted from the list decoder.
bits = int8(nrPolarDecode(double(llrN(:)), K, N, listSize, nMax, iIL, crcLen));
end
