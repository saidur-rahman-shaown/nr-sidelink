function si = siValue(containsFirstByte, containsLastByte)
%siValue The 2-bit Segmentation Info field for a Data field element.
%Spec:   TS 38.322 V16.3.0, clause 6.2.3.4, Table 6.2.3.4-1:
%          00  Data field contains all bytes of an RLC SDU
%          01  Data field contains the first segment of an RLC SDU
%          10  Data field contains the last segment of an RLC SDU
%          11  Data field contains neither the first nor last segment of an RLC SDU
%Inputs: containsFirstByte  logical -- the Data field starts at byte 0 of the SDU (SO = 0)
%        containsLastByte   logical -- the Data field ends at the SDU's last byte
%Outputs: si  integer, 0..3
%
%Note the code points are NOT a first/last bit pair: "last" is 10 and "first" is 01, so the
%value is not first + 2*last. A retransmitted AMD PDU that happens to span the whole SDU is
%SI = 00 again, whatever its original segmentation was -- SI describes this Data field, not
%history.

SI_COMPLETE = 0;   % 00
SI_FIRST    = 1;   % 01
SI_LAST     = 2;   % 10
SI_MIDDLE   = 3;   % 11

if containsFirstByte && containsLastByte
    si = SI_COMPLETE;
elseif containsFirstByte
    si = SI_FIRST;
elseif containsLastByte
    si = SI_LAST;
else
    si = SI_MIDDLE;
end
end
