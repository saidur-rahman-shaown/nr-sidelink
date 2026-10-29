function [ue, ok, rb] = appSend(ue, pqi, pfi, dstL2Id, castType, payload, nowMs)
%appSend Hand one application packet to the access stratum: SDAP -> PDCP -> RLC queue.
%Spec:   the transmit half of the user plane above MAC:
%          TS 37.324 5.2.1 (NO LOCAL PDF): map the QoS flow to an SLRB -- sdap.sdapTxMap -- and
%            build the SDAP Data PDU -- sdap.sdapPduPack
%          TS 38.323 5.2.1/5.2.3: COUNT, discardTimer, header -- pdcp.pdcpTxSdu
%          TS 38.322 5.2.2.1/5.2.3.1.1: into the RLC transmission buffer -- rlc.umTxEnqueue /
%            rlc.amTxEnqueue, tagged with the PDCP COUNT so a PDCP discard can be indicated
%        The QoS ENTERS here: the PQI picks the SLRB, the SLRB's logical channel carries
%        sl-Priority, and that priority is what LCP orders by and what SCI-1A signals.
%Inputs: ue        struct from stack.ueInit
%        pqi       integer -- the packet's PC5 5QI (TS 23.287), set by the V2X application
%        pfi       integer, 0..63 -- the PC5 QoS flow identifier, carried in the SDAP header
%        dstL2Id   integer, 0..2^24-1 -- Destination Layer-2 ID
%        castType  char -- 'broadcast', 'groupcast' or 'unicast'
%        payload   1 x n octets -- the V2X message
%        nowMs     real, ms -- starts the PDCP discardTimer
%Outputs: ue  updated
%         ok  logical -- false when no SLRB maps the flow (counted in ue.stats.noBearer); the
%             packet is not sent on an invented bearer
%         rb  integer -- the SLRB index used (0 when not ok)

ue.stats.sduOffered = ue.stats.sduOffered + 1;
rb = sdap.sdapTxMap(ue.rules, pqi, castType);
ok = rb > 0;
if ~ok
    ue.stats.noBearer = ue.stats.noBearer + 1;
    return;
end
c = sdap.castCode(castType);
i = find([ue.ent.isTx] & [ue.ent.peerL2Id] == dstL2Id & [ue.ent.cast] == c & [ue.ent.rb] == rb, 1);
if isempty(i)
    if strcmp(castType, 'unicast')
        error('stack:appSend:noLink', 'appSend: no unicast link to %d; call stack.unicastSetup first (PC5-S/PC5-RRC are not modelled)', dstL2Id);
    end
    % TS 38.331 5.8.9.1a.2.2: "assign a new LCID to this logical channel" -- new per destination.
    used = [ue.ent([ue.ent.isTx] & [ue.ent.peerL2Id] == dstL2Id).lcid];
    lcid = ue.k.lcidFirst;
    while any(used == lcid), lcid = lcid + 1; end
    ue.ent(end + 1) = stack.entityCreate(ue, rb, dstL2Id, 0, castType, lcid, true, false);
    i = numel(ue.ent);
end
e = ue.ent(i);
sdapPdu = sdap.sdapPduPack(e.sdapHeader, pfi, payload);
[e.pdcpTx, pdcpPdu, count] = pdcp.pdcpTxSdu(e.pdcpTx, sdapPdu, count0(e), nowMs);
if strcmp(e.mode, 'am')
    e.rlcTx = rlc.amTxEnqueue(e.rlcTx, pdcpPdu, count);
else
    e.rlcTx = rlc.umTxEnqueue(e.rlcTx, pdcpPdu, count);
end
ue.ent(i) = e;
end

function c = count0(e)
% The tag PDCP records against the discardTimer is the COUNT itself, so the discard it reports
% can be handed straight to RLC, which was given the same COUNT as its SDU tag.
c = e.pdcpTx.TX_NEXT;
end
