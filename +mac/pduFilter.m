function deliver = pduFilter(castType, dstHigh8, srcHigh16, sciDstId16, sciSrcId8, ownSrcL2Id, ownDstL2Id, sduLcid, isFirstTb)
%pduFilter Decide whether a decoded MAC PDU is for this UE. Clause 5.22.2.2.2's identity check.
%Spec:   TS 38.321 V16.22.0, clause 5.22.2.2.2, the two delivery conditions under "if this is
%        the first successful decoding of the data for this TB". This is the "PDU filtering
%        (RX only)" box of Figure 4.2.2-3.
%Inputs: castType    integer, 0..3 -- SCI-2A Cast type indicator, TS 38.212 Table 8.4.1.1-1.
%                    2 is unicast; 0, 1 and 3 are broadcast and the two groupcast flavours
%        dstHigh8    integer, 0..255 -- DST field of the decoded subheader, from mac.demuxSlSch
%        srcHigh16   integer, 0..65535 -- SRC field of the decoded subheader
%        sciDstId16  integer, 0..65535 -- Destination ID carried in the SCI (the 16 LSB)
%        sciSrcId8   integer, 0..255 -- Source ID carried in the SCI (the 8 LSB)
%        ownSrcL2Id  1 x n integer -- this UE's own Source Layer-2 ID(s), full 24 bits
%        ownDstL2Id  1 x m integer -- the Destination Layer-2 ID(s) this UE is interested in,
%                    full 24 bits. For unicast these are its peers' identities; for groupcast
%                    and broadcast they are the group and broadcast addresses it monitors
%        sduLcid     1 x k integer -- LCIDs present in the PDU, from mac.demuxSlSch
%        isFirstTb   logical -- whether this is the first TB for the Source/Destination
%                    Layer-2 ID pair. The clause's own NOTE says that determination is made
%                    "based on the Source Layer-2 ID and Destination Layer-2 ID pair", which is
%                    state the caller holds, not this function
%Outputs: deliver  logical -- whether to hand the PDU to disassembly and demultiplexing
%
%THE WHOLE POINT IS THAT NEITHER LAYER ALONE ADDRESSES A PEER
%--------------------------------------------------------------
%The MAC subheader carries the 16 MSB of the source and the 8 MSB of the destination; the SCI
%carries the 8 LSB of the source and the 16 LSB of the destination. So the test is not "does
%this ID match" but "is there an ID I hold whose LOW half matches the SCI and whose HIGH half
%matches the subheader" -- a join across two layers, per identity. Checking either half alone
%accepts traffic for a UE whose other half differs, which is a collision every 256 or 65536
%identities rather than never.
%
%AND THE TWO DIRECTIONS ARE CROSSED
%-----------------------------------
%For unicast the clause checks the subheader's DST against **this UE's own SOURCE** Layer-2 IDs,
%and the subheader's SRC against **the Destination** Layer-2 IDs it holds. That inversion is
%correct and is the easiest thing here to get backwards: the sender's destination is the
%receiver's own source identity, and the sender's source is one of the destinations the
%receiver keeps for its peers. Matching DST against own destinations would make a UE accept
%only traffic it sent itself.
%
%Broadcast and groupcast are not crossed -- there the subheader's DST is matched against the
%Destination Layer-2 IDs the UE monitors, because a group address is not anyone's source.

CAST_UNICAST = 2;                     % TS 38.212 Table 8.4.1.1-1
LCID_SCCH_LOW = 0;                    % Table 6.2.4-1: LCIDs 0 and 1 are SCCH flavours
LCID_SCCH_HIGH = 1;

if ~any(castType == [0 1 2 3])
    error('mac:pduFilter:badCastType', 'pduFilter: castType must be 0..3 (Table 8.4.1.1-1), got %s', num2str(castType));
end

if castType == CAST_UNICAST
    % "the DST field [...] is equal to the 8 MSB of any of the Source Layer-2 ID(s) of the UE
    %  for which the 16 LSB are equal to the Destination ID in the corresponding SCI"
    dstOk = any(bitshift(ownSrcL2Id, -16) == dstHigh8 & bitand(ownSrcL2Id, 65535) == sciDstId16);
    if ~dstOk
        deliver = false;
        return;
    end
    % "if the SRC field [...] is equal to the 16 MSB of any of the Destination Layer-2 ID(s) of
    %  the UE for which the 8 LSB are equal to the Source ID in the corresponding SCI; or"
    srcOk = any(bitshift(ownDstL2Id, -8) == srcHigh16 & bitand(ownDstL2Id, 255) == sciSrcId8);
    % "if this TB is corresponding to the logical channel with LCID equal to 0 or 1 and
    %  determined to be the first TB"
    % The second branch is what lets a unicast link be ESTABLISHED: before the peer's identity
    % is known there is no Destination Layer-2 ID to match SRC against, so the signalling
    % channel is admitted on the strength of the destination check alone. Dropping this branch
    % makes a link that can never start, and it fails silently -- every later TB would match.
    sigOk = isFirstTb && any(sduLcid == LCID_SCCH_LOW | sduLcid == LCID_SCCH_HIGH);
    deliver = srcOk || sigOk;
else
    % "if this TB is associated to groupcast or broadcast and the DST field [...] is equal to
    %  the 8 MSB of any of the Destination Layer-2 ID(s) of the UE for which the 16 LSB are
    %  equal to the Destination ID in the corresponding SCI"
    deliver = any(bitshift(ownDstL2Id, -16) == dstHigh8 & bitand(ownDstL2Id, 65535) == sciDstId16);
end
end
