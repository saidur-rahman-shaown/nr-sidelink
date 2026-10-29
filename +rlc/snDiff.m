function d = snDiff(sn, base, snFieldLength)
%snDiff Offset of an SN from a modulus base: (sn - base) modulo 2^[sn-FieldLength].
%Spec:   TS 38.322 V16.3.0, clause 7.1: "When performing arithmetic comparisons of state
%        variables or SN values, a modulus base shall be used ... This modulus base is
%        subtracted from all the values involved, and then an absolute comparison is performed
%        (e.g. RX_Next <= SN < RX_Next + AM_Window_Size is evaluated as [RX_Next - RX_Next]
%        modulo 2^[sn-FieldLength] <= [SN - RX_Next] modulo 2^[sn-FieldLength] < [RX_Next +
%        AM_Window_Size - RX_Next] modulo 2^[sn-FieldLength])".
%Inputs: sn             integer or integer row vector -- any integers; the result is reduced,
%                       so a caller may pass e.g. RX_Next_Highest - UM_Window_Size unreduced
%        base           integer -- the modulus base. Clause 7.1 names it per side:
%                       TX_Next_Ack (AM transmit), RX_Next (AM receive),
%                       RX_Next_Highest - UM_Window_Size (UM receive)
%        snFieldLength  integer, one of 6, 12, 18
%Outputs: d  integer (same shape as sn), 0..2^snFieldLength - 1
%
%Every "<", "<=", ">" in clauses 5.2 and 5.3 compares snDiff values against the SAME base.
%Comparing raw SNs is correct until the first wrap and wrong forever after -- at 6 bits that is
%the 64th segmented SDU, which is inside most test runs only if the test is written to reach it.

assert(any(snFieldLength == [6 12 18]), 'rlc:snDiff:badLength', ...
    'snDiff: sn-FieldLength must be 6, 12 or 18, got %s', num2str(snFieldLength));
d = mod(sn - base, 2^snFieldLength);
end
