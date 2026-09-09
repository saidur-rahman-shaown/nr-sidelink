function lchSet = lchEnqueue(lchSet, ctx, nowPhys)
%lchEnqueue Deliver one SDU across the MAC SAP, onto its logical channel.
%Spec:   TS 38.321 Figure 4.2.2-3's upper boundary. This is the entry point of the whole
%        transmit path: data arrives here on a logical channel and leaves the MAC as SL-SCH.
%Inputs: lchSet   from +sap/lchInit
%        ctx      scalar struct from +sap/ctxInit -- its .lcid selects the channel
%        nowPhys  integer -- PHYSICAL slot of arrival; stamped as the context's 'mac' crossing
%Outputs: lchSet  with the context appended to the queue
%
%The 'mac' stamp happens here and only here, which is what makes queueing delay measurable:
%tTxSlot - tMacSlot is time spent inside the MAC, and tMacSlot - tGenSlot is time spent above
%it. A caller that stamps separately can get them out of order; this cannot.

idx = find(lchSet.lcid == ctx.lcid, 1);
if isempty(idx)
    error('sap:lchEnqueue:noSuchLcid', 'lchEnqueue: no logical channel with lcid %s in this set (have %s)', num2str(ctx.lcid), mat2str(lchSet.lcid));
end
if ctx.dstL2Id ~= lchSet.dstL2Id(idx)
    error('sap:lchEnqueue:dstMismatch', 'lchEnqueue: context destination %s does not match logical channel %s''s destination %s', num2str(ctx.dstL2Id), num2str(ctx.lcid), num2str(lchSet.dstL2Id(idx)));
end

ctx = sap.ctxStamp(ctx, 'mac', nowPhys);

lchSet.q(end + 1)    = ctx;
lchSet.qLch(end + 1) = idx;
end
