function tf = rxBufMissingBeforeLast(b, sn)
%rxBufMissingBeforeLast Whether SDU sn has a hole before the last byte received for it.
%Spec:   TS 38.322 V16.3.0, clauses 5.2.2.2.3, 5.2.2.2.4, 5.2.3.2.3, 5.2.3.2.4: "there is at
%        least one missing byte segment of the RLC SDU associated with SN = x before the last
%        byte of all received segments of this RLC SDU". Its negation is the "there is no
%        missing byte segment ... before the last byte" test used to stop t-Reassembly.
%Inputs: b   reception buffer
%        sn  integer
%Outputs: tf  logical -- false when nothing of sn is held: with no received segments there is
%             no "last byte of all received segments" to be missing anything before
%
%"Before the last byte RECEIVED", not before the SDU's end. A missing TAIL is not a hole in
%this sense: bytes 0..99 of a 300-byte SDU with 100..299 still in flight is the ordinary
%mid-segmentation state, and starting t-Reassembly on it would start the timer on every
%segmented SDU.

maxEnd = -1;
have = 0;
for k = 1:numel(b.sn)
    if b.sn(k) ~= sn
        continue;
    end
    have = have + b.len(k);
    maxEnd = max(maxEnd, b.so(k) + b.len(k) - 1);
end
tf = maxEnd >= 0 && have < maxEnd + 1;
end
