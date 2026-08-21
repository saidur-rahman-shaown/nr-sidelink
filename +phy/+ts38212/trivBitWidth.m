function bits = trivBitWidth(maxReserve)
%trivBitWidth Bit width of the SCI format 1-A "Time resource assignment" (TRIV) field.
%Spec:   TS 38.212 V16.15.0, clause 8.3.1.1
%Inputs: maxReserve  integer, 2 or 3 -- higher-layer parameter sl-MaxNumPerReserve
%Outputs: bits  5 if maxReserve==2, 9 if maxReserve==3
if maxReserve == 2
    bits = 5;
elseif maxReserve == 3
    bits = 9;
else
    error('ts38212:trivBitWidth:badMaxReserve', 'trivBitWidth: maxReserve must be 2 or 3, got %s', num2str(maxReserve));
end
end
