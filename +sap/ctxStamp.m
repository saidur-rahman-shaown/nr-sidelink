function ctx = ctxStamp(ctx, event, slot)
%ctxStamp Record the slot at which a packet crossed one SAP boundary.
%Spec:   none -- KPI instrumentation.
%Inputs: ctx    scalar struct from +sap/ctxInit
%        event  char, one of:
%                 'mac'    arrival at the MAC SAP (from the logical channel)
%                 'grant'  a sidelink grant covering this packet was selected
%                 'tx'     first transmission on the air
%                 'rx'     successful decode at an intended receiver
%        slot   integer, >= ctx.tGenSlot -- PHYSICAL slot index
%Outputs: ctx  the input with one timestamp field filled in
%
%A switch, not a dynamic field name, because the normative-packages rule bans those on an
%interface and because a typo in an event name must be an error rather than a new field that
%silently absorbs every subsequent stamp.
%
%EACH BOUNDARY IS CROSSED ONCE
%-----------------------------
%Re-stamping is an error, not an update. 'tx' means the FIRST transmission: a blind
%retransmission or a HARQ retransmission increments nTx (via +sap/ctxTransmitted) and must not
%move tTxSlot, or the access-delay statistic silently becomes "delay of the last attempt" and
%every retransmitting UE looks slower than it is. Likewise 'rx' is the first successful decode;
%a second receiver decoding the same broadcast does not restamp.

if ~(slot >= 0 && mod(slot, 1) == 0)
    error('sap:ctxStamp:badSlot', 'ctxStamp: slot must be a nonnegative integer, got %s', num2str(slot));
end
if slot < ctx.tGenSlot
    error('sap:ctxStamp:beforeGen', 'ctxStamp: slot %s precedes tGenSlot %s; a packet cannot cross a boundary before it exists', num2str(slot), num2str(ctx.tGenSlot));
end

switch event
    case 'mac'
        assertUnset(ctx.tMacSlot, 'mac', ctx.pktId);
        ctx.tMacSlot = slot;
    case 'grant'
        % Deliberately NOT once-only in spirit -- but it is here, because a packet that outlives
        % its first grant (reselection, pre-emption) is re-granted, and the first grant is what
        % the queueing-delay statistic wants. A caller that needs the later one reads the log.
        assertUnset(ctx.tGrantSlot, 'grant', ctx.pktId);
        ctx.tGrantSlot = slot;
    case 'tx'
        assertUnset(ctx.tTxSlot, 'tx', ctx.pktId);
        ctx.tTxSlot = slot;
    case 'rx'
        assertUnset(ctx.tRxSlot, 'rx', ctx.pktId);
        ctx.tRxSlot = slot;
    otherwise
        error('sap:ctxStamp:badEvent', 'ctxStamp: event must be one of mac|grant|tx|rx, got ''%s''', event);
end
end

function assertUnset(value, name, pktId)
if value ~= 0
    error('sap:ctxStamp:alreadyStamped', 'ctxStamp: packet %s already has a ''%s'' stamp at slot %s; each SAP boundary is crossed once', num2str(pktId), name, num2str(value));
end
end
