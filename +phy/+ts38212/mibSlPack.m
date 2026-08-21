function bits = mibSlPack(dynamicParams)
%mibSlPack Pack the MasterInformationBlockSidelink IE into its transmitted bit sequence.
%Spec:   TS 38.331 V16.22.0, IE MasterInformationBlockSidelink (ASN.1 SEQUENCE)
%
%Field order and the MSB-first-within-field convention follow this project's declaration-order
%packing rule for sidelink control information (TS 38.212 clause 8.3.1 / clause 8.4.1 state
%this explicitly for SCI formats). No equivalent explicit statement was found for MIB-SL's
%ASN.1 SEQUENCE -- this is an inference from the only precedent available in this project, not
%a confirmed citation; flagged for independent-verifier rather than assumed silently.
%
%Inputs: dynamicParams  scalar struct:
%          .tddConfig          12-by-1 logical (or 0/1) column -- sl-TDD-Config-r16, an opaque
%                              BIT STRING (not an integer); caller supplies the bits directly
%          .inCoverage         integer, 0 or 1
%          .directFrameNumber  integer, 0..1023
%          .slotIndex          integer, 0..127
%          .reservedBits       2-by-1 logical (or 0/1) column -- no "set to zero" instruction
%                              was found for this field (unlike SCI-1A's reserved field);
%                              caller supplies it
%Outputs: bits  32-by-1 logical column, a0 first
if numel(dynamicParams.tddConfig) ~= 12
    error('ts38212:mibSlPack:badTddConfig', 'mibSlPack: tddConfig must have 12 elements, got %d', numel(dynamicParams.tddConfig));
end
if ~(dynamicParams.inCoverage == 0 || dynamicParams.inCoverage == 1)
    error('ts38212:mibSlPack:badInCoverage', 'mibSlPack: inCoverage must be 0 or 1, got %s', num2str(dynamicParams.inCoverage));
end
if dynamicParams.directFrameNumber < 0 || dynamicParams.directFrameNumber > 1023 || mod(dynamicParams.directFrameNumber, 1) ~= 0
    error('ts38212:mibSlPack:badDfn', 'mibSlPack: directFrameNumber must be an integer in 0..1023, got %s', num2str(dynamicParams.directFrameNumber));
end
if dynamicParams.slotIndex < 0 || dynamicParams.slotIndex > 127 || mod(dynamicParams.slotIndex, 1) ~= 0
    error('ts38212:mibSlPack:badSlotIndex', 'mibSlPack: slotIndex must be an integer in 0..127, got %s', num2str(dynamicParams.slotIndex));
end
if numel(dynamicParams.reservedBits) ~= 2
    error('ts38212:mibSlPack:badReservedBits', 'mibSlPack: reservedBits must have 2 elements, got %d', numel(dynamicParams.reservedBits));
end
bits = [logical(dynamicParams.tddConfig(:)); ...
        phy.ts38212.bitsFromUint(dynamicParams.inCoverage, 1); ...
        phy.ts38212.bitsFromUint(dynamicParams.directFrameNumber, 10); ...
        phy.ts38212.bitsFromUint(dynamicParams.slotIndex, 7); ...
        logical(dynamicParams.reservedBits(:))];
end
