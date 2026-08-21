function bits = sci2bPack(dynamicParams)
%sci2bPack Pack SCI format 2-B fields into the information bit sequence a0..a(A-1).
%Spec:   TS 38.212 V16.15.0, clause 8.4.1.2
%Inputs: dynamicParams  scalar struct, per-transmission:
%          .harqProcessNumber    integer, 0..15
%          .ndi                  integer, 0 or 1 -- new data indicator
%          .rv                   integer, 0..3 -- redundancy version, plain binary per
%                                Table 7.3.1.1.1-2
%          .sourceID             integer, 0..255
%          .destinationID        integer, 0..65535
%          .harqFeedbackEnabled  integer, 0 or 1
%          .zoneID               integer, 0..4095 -- TS 38.331 clause 5.8.11
%          .commRangeRequirement integer, 0..15 -- higher-layer parameter
%                                sl-ZoneConfigMCR-Index
%Outputs: bits  48-by-1 logical column, a0 first
if dynamicParams.harqProcessNumber < 0 || dynamicParams.harqProcessNumber > 15 || mod(dynamicParams.harqProcessNumber, 1) ~= 0
    error('ts38212:sci2bPack:badHarq', 'sci2bPack: harqProcessNumber must be an integer in 0..15, got %s', num2str(dynamicParams.harqProcessNumber));
end
if ~(dynamicParams.ndi == 0 || dynamicParams.ndi == 1)
    error('ts38212:sci2bPack:badNdi', 'sci2bPack: ndi must be 0 or 1, got %s', num2str(dynamicParams.ndi));
end
if dynamicParams.rv < 0 || dynamicParams.rv > 3 || mod(dynamicParams.rv, 1) ~= 0
    error('ts38212:sci2bPack:badRv', 'sci2bPack: rv must be an integer in 0..3, got %s', num2str(dynamicParams.rv));
end
if dynamicParams.sourceID < 0 || dynamicParams.sourceID > 255 || mod(dynamicParams.sourceID, 1) ~= 0
    error('ts38212:sci2bPack:badSourceID', 'sci2bPack: sourceID must be an integer in 0..255, got %s', num2str(dynamicParams.sourceID));
end
if dynamicParams.destinationID < 0 || dynamicParams.destinationID > 65535 || mod(dynamicParams.destinationID, 1) ~= 0
    error('ts38212:sci2bPack:badDestinationID', 'sci2bPack: destinationID must be an integer in 0..65535, got %s', num2str(dynamicParams.destinationID));
end
if ~(dynamicParams.harqFeedbackEnabled == 0 || dynamicParams.harqFeedbackEnabled == 1)
    error('ts38212:sci2bPack:badHarqFeedback', 'sci2bPack: harqFeedbackEnabled must be 0 or 1, got %s', num2str(dynamicParams.harqFeedbackEnabled));
end
if dynamicParams.zoneID < 0 || dynamicParams.zoneID > 4095 || mod(dynamicParams.zoneID, 1) ~= 0
    error('ts38212:sci2bPack:badZoneID', 'sci2bPack: zoneID must be an integer in 0..4095, got %s', num2str(dynamicParams.zoneID));
end
if dynamicParams.commRangeRequirement < 0 || dynamicParams.commRangeRequirement > 15 || mod(dynamicParams.commRangeRequirement, 1) ~= 0
    error('ts38212:sci2bPack:badCommRange', 'sci2bPack: commRangeRequirement must be an integer in 0..15, got %s', num2str(dynamicParams.commRangeRequirement));
end
bits = [phy.ts38212.bitsFromUint(dynamicParams.harqProcessNumber, 4); ...
        phy.ts38212.bitsFromUint(dynamicParams.ndi, 1); ...
        phy.ts38212.bitsFromUint(dynamicParams.rv, 2); ...
        phy.ts38212.bitsFromUint(dynamicParams.sourceID, 8); ...
        phy.ts38212.bitsFromUint(dynamicParams.destinationID, 16); ...
        phy.ts38212.bitsFromUint(dynamicParams.harqFeedbackEnabled, 1); ...
        phy.ts38212.bitsFromUint(dynamicParams.zoneID, 12); ...
        phy.ts38212.bitsFromUint(dynamicParams.commRangeRequirement, 4)];
end
