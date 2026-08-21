function bits = sci2aPack(dynamicParams)
%sci2aPack Pack SCI format 2-A fields into the information bit sequence a0..a(A-1).
%Spec:   TS 38.212 V16.15.0, clause 8.4.1.1
%Inputs: dynamicParams  scalar struct, per-transmission:
%          .harqProcessNumber    integer, 0..15
%          .ndi                  integer, 0 or 1 -- new data indicator
%          .rv                   integer, 0..3 -- redundancy version, plain binary per
%                                Table 7.3.1.1.1-2 (confirmed not remapped/Gray-coded)
%          .sourceID             integer, 0..255
%          .destinationID        integer, 0..65535
%          .harqFeedbackEnabled  integer, 0 or 1
%          .castType             integer, 0..3 -- Table 8.4.1.1-1
%          .csiRequest           integer, 0 or 1
%Outputs: bits  35-by-1 logical column, a0 first
if dynamicParams.harqProcessNumber < 0 || dynamicParams.harqProcessNumber > 15 || mod(dynamicParams.harqProcessNumber, 1) ~= 0
    error('ts38212:sci2aPack:badHarq', 'sci2aPack: harqProcessNumber must be an integer in 0..15, got %s', num2str(dynamicParams.harqProcessNumber));
end
if ~(dynamicParams.ndi == 0 || dynamicParams.ndi == 1)
    error('ts38212:sci2aPack:badNdi', 'sci2aPack: ndi must be 0 or 1, got %s', num2str(dynamicParams.ndi));
end
if dynamicParams.rv < 0 || dynamicParams.rv > 3 || mod(dynamicParams.rv, 1) ~= 0
    error('ts38212:sci2aPack:badRv', 'sci2aPack: rv must be an integer in 0..3, got %s', num2str(dynamicParams.rv));
end
if dynamicParams.sourceID < 0 || dynamicParams.sourceID > 255 || mod(dynamicParams.sourceID, 1) ~= 0
    error('ts38212:sci2aPack:badSourceID', 'sci2aPack: sourceID must be an integer in 0..255, got %s', num2str(dynamicParams.sourceID));
end
if dynamicParams.destinationID < 0 || dynamicParams.destinationID > 65535 || mod(dynamicParams.destinationID, 1) ~= 0
    error('ts38212:sci2aPack:badDestinationID', 'sci2aPack: destinationID must be an integer in 0..65535, got %s', num2str(dynamicParams.destinationID));
end
if ~(dynamicParams.harqFeedbackEnabled == 0 || dynamicParams.harqFeedbackEnabled == 1)
    error('ts38212:sci2aPack:badHarqFeedback', 'sci2aPack: harqFeedbackEnabled must be 0 or 1, got %s', num2str(dynamicParams.harqFeedbackEnabled));
end
if dynamicParams.castType < 0 || dynamicParams.castType > 3 || mod(dynamicParams.castType, 1) ~= 0
    error('ts38212:sci2aPack:badCastType', 'sci2aPack: castType must be an integer in 0..3, got %s', num2str(dynamicParams.castType));
end
if ~(dynamicParams.csiRequest == 0 || dynamicParams.csiRequest == 1)
    error('ts38212:sci2aPack:badCsiRequest', 'sci2aPack: csiRequest must be 0 or 1, got %s', num2str(dynamicParams.csiRequest));
end
bits = [phy.ts38212.bitsFromUint(dynamicParams.harqProcessNumber, 4); ...
        phy.ts38212.bitsFromUint(dynamicParams.ndi, 1); ...
        phy.ts38212.bitsFromUint(dynamicParams.rv, 2); ...
        phy.ts38212.bitsFromUint(dynamicParams.sourceID, 8); ...
        phy.ts38212.bitsFromUint(dynamicParams.destinationID, 16); ...
        phy.ts38212.bitsFromUint(dynamicParams.harqFeedbackEnabled, 1); ...
        phy.ts38212.bitsFromUint(dynamicParams.castType, 2); ...
        phy.ts38212.bitsFromUint(dynamicParams.csiRequest, 1)];
end
