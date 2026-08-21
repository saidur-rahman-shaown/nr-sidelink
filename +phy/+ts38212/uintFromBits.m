function value = uintFromBits(bits)
%uintFromBits Unpack a fixed-width MSB-first bit column into a nonnegative integer.
%Not itself a spec clause -- inverse of bitsFromUint; see that file's header.
%Inputs: bits  width-by-1 logical (or 0/1) column, bits(1) is the MSB; width==0 is legal
%Outputs: value  nonnegative integer
if isempty(bits)
    value = 0;
    return;
end
value = bin2dec(char(double(bits(:))' + '0'));
end
