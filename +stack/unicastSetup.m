function [ueA, ueB] = unicastSetup(ueA, ueB)
%unicastSetup Establish the unicast sidelink DRBs between two UEs, both directions.
%Spec:   TS 38.331 V16.22.0 clause 5.8.9.1a.2.2 (for unicast the DRB is established "after
%        receiving the RRCReconfigurationCompleteSidelink message", with the logical channel from
%        sl-MAC-LogicalChannelConfigPC5 carrying the LCID the peer was told) and clause 9.1.1.4
%        (the AM parameters split between transmitting and receiving UE).
%Inputs: ueA, ueB  structs from stack.ueInit
%Outputs: ueA, ueB  with one bidirectional entity per unicast SLRB towards each other
%
%NOT MODELLED, AND REPLACED BY THIS FUNCTION: the PC5-S Direct Link Establishment (TS 24.587)
%that creates the link and its Layer-2 IDs, and the PC5-RRC RRCReconfigurationSidelink exchange
%that carries sl-RLC-ConfigPC5 / sl-LogicalChannelIdentity to the peer. Their OUTCOME is what
%matters to the user plane -- both UEs hold matching entities on matching LCIDs -- and that is
%what is set up here, from each UE's own copy of the stored configuration. Neither is an access
%stratum data-transmission layer (PC5-S is NAS-level signalling), and TS 24.587 has no local PDF.

ucode = sdap.castCode('unicast');
for rb = find(ueA.rules.rbCast == ucode | ueA.rules.rbCast == 0)
    if ~any(ueA.rules.rb == rb) && ueA.rules.defaultRb(ucode) ~= rb
        continue;                               % an SLRB no unicast flow can map to
    end
    lcid = nextLcid(ueA, ueB);
    ueA.ent(end + 1) = stack.entityCreate(ueA, rb, ueB.srcL2Id, 0, 'unicast', lcid, true, true);
    ueB.ent(end + 1) = stack.entityCreate(ueB, rb, ueA.srcL2Id, 0, 'unicast', lcid, true, true);
end
end

function lcid = nextLcid(ueA, ueB)
% The lowest LCID free on BOTH sides for this peer pair: the transmitter picks it and the receiver
% must be able to accept it, which is what the PC5-RRC exchange negotiates.
usedA = [ueA.ent([ueA.ent.peerL2Id] == ueB.srcL2Id).lcid];
usedB = [ueB.ent([ueB.ent.peerL2Id] == ueA.srcL2Id).lcid];
lcid = ueA.k.lcidFirst;
while any(usedA == lcid) || any(usedB == lcid)
    lcid = lcid + 1;
end
end
