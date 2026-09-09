function ctx = ctxTransmitted(ctx, slot)
%ctxTransmitted Count one transmission of this packet, stamping the first.
%Spec:   none -- KPI instrumentation. The count it maintains is compared against
%        sl-MaxTransNum by TS 38.321 clause 5.22.1.3.1, but the comparison is +mac/'s.
%Inputs: ctx   scalar struct from +sap/ctxInit
%        slot  integer -- PHYSICAL slot of this transmission
%Outputs: ctx  with .nTx incremented, and .tTxSlot set if this is the first
%
%The one place nTx moves. Initial transmission, blind retransmission and HARQ retransmission
%all come through here and all count -- that is what makes nTx comparable with sl-MaxTransNum
%and what makes "transmissions per delivered packet" a meaningful efficiency figure. Only the
%first sets tTxSlot; see +sap/ctxStamp on why a retransmission must not move it.

if ctx.nTx == 0
    ctx = sap.ctxStamp(ctx, 'tx', slot);
end
ctx.nTx = ctx.nTx + 1;
end
