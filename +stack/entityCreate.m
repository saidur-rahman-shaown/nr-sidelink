function e = entityCreate(ue, rb, peerL2Id, groupL2Id, castLbl, lcid, isTx, isRx)
%entityCreate Establish the PDCP and RLC entities and the logical channel for one SLRB and peer.
%Spec:   TS 38.331 V16.22.0 clause 5.8.9.1a.2.2 (sidelink DRB addition: SDAP, PDCP, RLC, logical
%        channel, all "in accordance with" the SLRB's sl-SDAP-Config / sl-PDCP-Config /
%        sl-RLC-Config / sl-MAC-LogicalChannelConfig); TS 38.322 5.1.1 and TS 38.323 5.1.1
%        (establishment, including the groupcast/broadcast receiver "when receiving the first
%        UMD PDU / PDCP PDU" for a Source/Destination pair and LCID).
%Inputs: ue         struct from stack.ueInit
%        rb         integer -- index into ue.rbs, or 0 for a groupcast/broadcast RECEIVER, which
%                   cannot know the transmitter's SLRB: it uses the values TS 38.331 clause
%                   9.1.1.5 fixes for groupcast and broadcast (UM, 6-bit SN; PDCP 12-bit SN)
%        peerL2Id   integer -- destination (transmit) or source (receive) Layer-2 ID
%        groupL2Id  integer -- the gc/bc Destination Layer-2 ID on the receive side, else 0
%        castLbl    char -- 'broadcast', 'groupcast' or 'unicast'
%        lcid       integer, 4..19
%        isTx, isRx logical -- which sides to build. Unicast builds both: an AM entity is
%                   bidirectional (data one way, STATUS the other)
%Outputs: e  record from stack.entityNew, filled
%
%The receive-side t-Reassembly / t-StatusProhibit / t-Reordering are the RECEIVING UE's choices
%(TS 38.331 9.1.1.4/9.1.1.5, TS 38.323 7.3) and come from ue.k, never from the transmitter's SLRB.

LCID_MIN = 4; LCID_MAX = 19;                     % TS 38.321 Table 6.2.4-1
if ~(lcid >= LCID_MIN && lcid <= LCID_MAX)
    error('stack:entityCreate:badLcid', 'entityCreate: LCID %d is outside 4..19', lcid);
end
k = ue.k;
e = stack.entityNew();
e.peerL2Id = peerL2Id;
e.groupL2Id = groupL2Id;
e.cast = sdap.castCode(castLbl);
e.rb = rb;
e.lcid = lcid;
e.isTx = isTx;
e.isRx = isRx;
isGcBc = ~strcmp(castLbl, 'unicast');

if rb == 0
    % Groupcast/broadcast receiver: TS 38.331 9.1.1.5 STCH defaults.
    if ~isGcBc || isTx
        error('stack:entityCreate:noRb', 'entityCreate: only a gc/bc receiver may be built without an SLRB');
    end
    pdcpLeaf = struct('sl_DiscardTimer_r16_Present', false, 'sl_DiscardTimer_r16', '', ...
        'sl_PDCP_SN_Size_r16_Present', true, 'sl_PDCP_SN_Size_r16', 'len12bits', ...
        'sl_OutOfOrderDelivery', k.gcbcRxOutOfOrder);   % a receiving-UE choice, see stack.defaults
    e.mode = 'um';
    e.rlcRx = rlc.umRxInit(rlc.umConfig(struct('sl_SN_FieldLengthUM_r16', 'size6'), k.tReassemblyLbl), true);
    e.pdcpRx = pdcp.pdcpRxInit(pdcp.pdcpConfig(pdcpLeaf, castLbl, k.tReorderingMs, k.sduType));
    e.sdapHeader = false;                       % TS 37.324 6.2.1: never on gc/bc
    return;
end

slrb = ue.rbs(rb);
rlcCfg = ue.rbRlc(rb).sl_RLC_Config_r16;
lch = ue.rbLch(rb);
e.prio = lch.priority;
e.pbr = lch.pbrBytesPerSec;
e.bsd = lch.bsdSec;
e.harqFb = lch.harqFeedbackEnabled;
e.sdapHeader = ue.rules.headerPresent(rb);
tReord = k.tReorderingMs;
if strcmp(rlcCfg.case, 'sl-AM-RLC-r16')
    tReord = k.tReorderingAmMs;                 % must outlast ARQ recovery, see stack.defaults
end
pc = pdcp.pdcpConfig(slrb.sl_PDCP_Config_r16, castLbl, tReord, k.sduType);
switch rlcCfg.case
    case 'sl-UM-RLC-r16'
        e.mode = 'um';
        uc = rlc.umConfig(rlcCfg.sl_UM_RLC_r16, k.tReassemblyLbl);
        if isTx, e.rlcTx = rlc.umTxInit(uc); end
        if isRx, e.rlcRx = rlc.umRxInit(uc, isGcBc); end
    case 'sl-AM-RLC-r16'
        e.mode = 'am';
        ac = rlc.amConfig(rlcCfg.sl_AM_RLC_r16, k.tReassemblyLbl, k.tStatusProhibitLbl);
        e.rlcTx = rlc.amTxInit(ac);
        e.rlcRx = rlc.amRxInit(ac);
end
if isTx, e.pdcpTx = pdcp.pdcpTxInit(pc); end
if isRx, e.pdcpRx = pdcp.pdcpRxInit(pc); end
end
