function dynamicParams = sci2bUnpack(bits)
%sci2bUnpack Unpack SCI format 2-B information bits a0..a(A-1) into named fields.
%Spec:   TS 38.212 V16.15.0, clause 8.4.1.2 (inverse of sci2bPack)
%Inputs: bits  48-by-1 column vector (logical or 0/1), a0 first
%Outputs: dynamicParams  scalar struct with the same fields sci2bPack takes -- see that
%              file's header for each field's type/range
bits = logical(bits(:));
if numel(bits) ~= 48
    error('ts38212:sci2bUnpack:badLength', 'sci2bUnpack: expected 48 bits, got %d', numel(bits));
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
[f, idx] = phy.ts38212.takeField(bits, idx, 12);
dynamicParams.zoneID = phy.ts38212.uintFromBits(f);
[f, idx] = phy.ts38212.takeField(bits, idx, 4);
dynamicParams.commRangeRequirement = phy.ts38212.uintFromBits(f);
if idx - 1 ~= numel(bits)
    error('ts38212:sci2bUnpack:badLength', 'sci2bUnpack: consumed %d bits but input has %d', idx - 1, numel(bits));
end
end
