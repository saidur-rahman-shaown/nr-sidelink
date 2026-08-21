function dynamicParams = mibSlUnpack(bits)
%mibSlUnpack Unpack the MasterInformationBlockSidelink bit sequence into named fields.
%Spec:   TS 38.331 V16.22.0, IE MasterInformationBlockSidelink (inverse of mibSlPack; see
%        that file's header for the field-order caveat)
%Inputs: bits  32-by-1 column vector (logical or 0/1), a0 first
%Outputs: dynamicParams  scalar struct with the same fields mibSlPack takes -- see that
%              file's header for each field's type/range
bits = logical(bits(:));
if numel(bits) ~= 32
    error('ts38212:mibSlUnpack:badLength', 'mibSlUnpack: expected 32 bits, got %d', numel(bits));
end
idx = 1;
[f, idx] = phy.ts38212.takeField(bits, idx, 12);
dynamicParams.tddConfig = f;
[f, idx] = phy.ts38212.takeField(bits, idx, 1);
dynamicParams.inCoverage = phy.ts38212.uintFromBits(f);
[f, idx] = phy.ts38212.takeField(bits, idx, 10);
dynamicParams.directFrameNumber = phy.ts38212.uintFromBits(f);
[f, idx] = phy.ts38212.takeField(bits, idx, 7);
dynamicParams.slotIndex = phy.ts38212.uintFromBits(f);
[f, idx] = phy.ts38212.takeField(bits, idx, 2);
dynamicParams.reservedBits = f;
if idx - 1 ~= numel(bits)
    error('ts38212:mibSlUnpack:badLength', 'mibSlUnpack: consumed %d bits but input has %d', idx - 1, numel(bits));
end
end
