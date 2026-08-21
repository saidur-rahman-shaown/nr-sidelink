function dynamicParams = sci2aUnpack(bits)
%sci2aUnpack Unpack SCI format 2-A information bits a0..a(A-1) into named fields.
%Spec:   TS 38.212 V16.15.0, clause 8.4.1.1 (inverse of sci2aPack)
%Inputs: bits  35-by-1 column vector (logical or 0/1), a0 first
%Outputs: dynamicParams  scalar struct with the same fields sci2aPack takes -- see that
%              file's header for each field's type/range
bits = logical(bits(:));
if numel(bits) ~= 35
    error('ts38212:sci2aUnpack:badLength', 'sci2aUnpack: expected 35 bits, got %d', numel(bits));
end
idx = 1;
[f, idx] = phy.ts38212.takeField(bits, idx, 4);
dynamicParams.harqProcessNumber = phy.ts38212.uintFromBits(f);
[f, idx] = phy.ts38212.takeField(bits, idx, 1);
dynamicParams.ndi = phy.ts38212.uintFromBits(f);
[f, idx] = phy.ts38212.takeField(bits, idx, 2);
dynamicParams.rv = phy.ts38212.uintFromBits(f);
[f, idx] = phy.ts38212.takeField(bits, idx, 8);
dynamicParams.sourceID = phy.ts38212.uintFromBits(f);
[f, idx] = phy.ts38212.takeField(bits, idx, 16);
dynamicParams.destinationID = phy.ts38212.uintFromBits(f);
[f, idx] = phy.ts38212.takeField(bits, idx, 1);
dynamicParams.harqFeedbackEnabled = phy.ts38212.uintFromBits(f);
[f, idx] = phy.ts38212.takeField(bits, idx, 2);
dynamicParams.castType = phy.ts38212.uintFromBits(f);
[f, idx] = phy.ts38212.takeField(bits, idx, 1);
dynamicParams.csiRequest = phy.ts38212.uintFromBits(f);
if idx - 1 ~= numel(bits)
    error('ts38212:sci2aUnpack:badLength', 'sci2aUnpack: consumed %d bits but input has %d', idx - 1, numel(bits));
end
end
