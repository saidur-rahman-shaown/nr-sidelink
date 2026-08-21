function cbs = cbSegment(blk, bgn)
%cbSegment LDPC code block segmentation and per-block CRC attachment.
%Toolbox body: nrCodeBlockSegmentLDPC.
%Spec:   TS 38.212 V16.15.0, clause 5.2.2 -- LDPC direction only. The polar
%        code block segmentation of clause 5.2.1 is not wrapped here: every
%        sidelink control channel this project builds stays at a single code
%        block (C=1), so the polar branch of clause 5.2.1 is never exercised.
%        See ch5-toolbox-survey.md in this folder.
%Inputs: blk  column vector of 0/1 (or logical/int8), length B -- the
%             CRC-attached transport block (output of crcEncode with
%             CRC24A)
%        bgn  integer, 1 or 2 -- LDPC base graph number. Base graph
%             *selection* is not this function's job -- it is a K/R
%             threshold rule that belongs at the +phy/+chan/ SL-SCH call
%             site.
%Outputs: cbs  K-by-C matrix -- one code block segment per column, filler
%              bits (where present) represented as -1; each column has a
%              type-24B CRC attached when C>1
if ~(isscalar(bgn) && (bgn == 1 || bgn == 2))
    error('lib:ts38212:cbSegment:badBgn', 'cbSegment: bgn must be 1 or 2, got %s', num2str(bgn));
end
cbs = nrCodeBlockSegmentLDPC(blk(:), bgn);
end
