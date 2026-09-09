function c = castTypes()
%castTypes SCI format 2-A 'Cast type indicator' values.
%Spec:   TS 38.212 V16.15.0, clause 8.4.1.1, Table 8.4.1.1-1, read from
%        Documentations/38212-gf0.pdf.
%Inputs: none
%Outputs: c  scalar struct of the four 2-bit code points:
%   .broadcast          0  (00)
%   .groupcastAckNack   1  (01) -- groupcast, HARQ-ACK includes ACK or NACK  ("option 2")
%   .unicast            2  (10)
%   .groupcastNackOnly  3  (11) -- groupcast, HARQ-ACK includes only NACK    ("option 1")
%
%THE ORDER IS NOT THE INTUITIVE ONE
%----------------------------------
%It is not broadcast/groupcast/unicast = 0/1/2. **Unicast is 2**, and groupcast occupies BOTH 1
%and 3, split by which HARQ-ACK feedback it uses. Writing the obvious enumeration puts unicast
%traffic on a groupcast code point and vice versa -- and since both are legal values that decode
%without error, the only symptom is peers responding with the wrong feedback scheme.
%
%The two groupcast values are a feedback mode, not two kinds of group. NACK-only (3) is the
%distance-based scheme that pairs with SCI format 2-B's zone and communication-range fields; a
%groupcast using it and one using ACK/NACK (1) differ in what the receivers transmit on PSFCH,
%not in who they are.

c = struct('broadcast', 0, 'groupcastAckNack', 1, 'unicast', 2, 'groupcastNackOnly', 3);
end
