function b = rxBufDrop(b, sn)
%rxBufDrop Remove every held byte run of SDU sn.
%Spec:   TS 38.322 V16.3.0, clause 5.2.2.2.3 ("discard any UMD PDUs with SN that falls outside
%        of the reassembly window"), clause 5.2.2.2.4 ("discard all segments with SN < updated
%        RX_Next_Reassembly"), and after reassembly-and-delivery in both modes.
%Inputs: b   reception buffer
%        sn  integer
%Outputs: b  buffer without sn

keep = true(1, numel(b.sn));
dataKeep = true(1, numel(b.data));
start = 1;
for k = 1:numel(b.sn)
    if b.sn(k) == sn
        keep(k) = false;
        dataKeep(start : start + b.len(k) - 1) = false;
    end
    start = start + b.len(k);
end
b.sn = b.sn(keep);
b.so = b.so(keep);
b.len = b.len(keep);
b.last = b.last(keep);
b.data = b.data(dataKeep);
end
