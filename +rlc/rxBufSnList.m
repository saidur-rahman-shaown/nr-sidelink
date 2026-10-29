function sns = rxBufSnList(b)
%rxBufSnList The distinct SNs for which any bytes are held.
%Spec:   TS 38.322 V16.3.0, clauses 5.2.2.2.3 / 5.2.2.2.4 -- the window-driven discards act on
%        "any UMD PDUs with SN that falls outside of the reassembly window" and "all segments
%        with SN < updated RX_Next_Reassembly", i.e. on every held SN at once.
%Inputs: b  reception buffer
%Outputs: sns  1 x S integer row vector, in first-arrival order

sns = zeros(1, 0);
for k = 1:numel(b.sn)
    if ~any(sns == b.sn(k))
        sns(end + 1) = b.sn(k);   %#ok<AGROW>
    end
end
end
