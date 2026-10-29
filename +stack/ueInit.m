function ue = ueInit(o, srcL2Id, monitoredL2Ids, k, seed)
%ueInit One UE's sidelink access stratum, configured entirely from the stored configuration.
%Spec:   none itself -- this is the composition. What it assembles, and from where:
%          SDAP rules          TS 38.331 sl-RadioBearerPreConfigList-r16 -> sdap.sdapRules
%          PDCP / RLC / LCH    per SLRB, established lazily per destination (TS 38.331
%                              5.8.9.1a.2.2: "establish a PDCP entity ... establish a RLC entity
%                              ... configure the MAC entity with a logical channel ... and assign
%                              a new LCID to this logical channel")
%          MAC                 HARQ entity (mac.harqInit), sensing DB (phy.ts38214.sensingDbInit),
%                              receive HARQ entity (mac.harqRxInit)
%          PHY geometry        stack.poolGeometry
%Inputs: o               struct from cfg.loadConfig -- THE ONLY SOURCE of configuration
%        srcL2Id         integer, 0..2^24-1 -- this UE's Source Layer-2 ID (TS 23.287 assigns it)
%        monitoredL2Ids  1 x m integer -- Destination Layer-2 IDs this UE receives on: the
%                        broadcast/groupcast addresses it is interested in (TS 38.321 5.22.2.2.1's
%                        "Sidelink identification information" the MAC is interested in)
%        k               struct from stack.defaults -- the UE-implementation choices
%        seed            integer -- the UE's random stream (resource draws), so a run replays
%Outputs: ue  scalar struct -- see the field comments below
%
%A UE HAS NO ENTITIES UNTIL TRAFFIC ASKS FOR ONE
%-----------------------------------------------
%An SLRB's PDCP/RLC/logical channel exist per DESTINATION, not per configured bearer: the same
%SLRB 1 to two broadcast addresses is two RLC entities with two LCIDs. So entities are created by
%stack.appSend (transmit side, groupcast/broadcast), by stack.rxSlot on the first PDU from a new
%(source, destination, LCID) (receive side, TS 38.322 5.1.1 / TS 38.323 5.1.1), and by
%stack.unicastSetup for unicast, which stands in for the PC5-RRC exchange that is not modelled.

ue.cfg = o;
ue.k = k;
ue.srcL2Id = srcL2Id;
ue.monitoredL2Ids = monitoredL2Ids;
ue.g = stack.poolGeometry(o, k.mcs);
ue.rng = RandStream('mt19937ar', 'Seed', seed);

pre = o.preconfig;
if ~pre.sl_RadioBearerPreConfigList_r16_Present || ~pre.sl_RLC_BearerPreConfigList_r16_Present
    error('stack:ueInit:noBearers', 'ueInit: the stored config has no sidelink radio bearer / RLC bearer lists');
end
ue.rbs = pre.sl_RadioBearerPreConfigList_r16;
ue.rules = sdap.sdapRules(ue.rbs);
rlcs = pre.sl_RLC_BearerPreConfigList_r16;
nRb = numel(ue.rbs);
ue.rbRlc = repmat(rlcs(1), 1, nRb);              % the RLC bearer serving each SLRB
ue.rbLch = repmat(mac.slLchConfig(rlcs(1).sl_MAC_LogicalChannelConfig_r16), 1, nRb);
for i = 1:nRb
    j = find([rlcs.sl_ServedRadioBearer_r16] == ue.rbs(i).slrb_Uu_ConfigIndex_r16, 1);
    ue.rbRlc(i) = rlcs(j);
    ue.rbLch(i) = mac.slLchConfig(rlcs(j).sl_MAC_LogicalChannelConfig_r16);
    % TS 37.324 6.2.1: "For groupcast and broadcast of NR sidelink communication, only SDAP data
    % PDU without SDAP header is supported." (cfgValidate check 16c rejects it in the config too.)
    if ue.rules.rbCast(i) ~= sdap.castCode('unicast') && ue.rules.headerPresent(i)
        error('stack:ueInit:gcBcHeader', 'ueInit: SLRB %d is groupcast/broadcast and may not carry an SDAP header (TS 37.324 6.2.1)', ue.rbs(i).slrb_Uu_ConfigIndex_r16);
    end
end

ue.ent = repmat(stack.entityNew(), 1, 0);          % PDCP/RLC/logical-channel entities
ue.harq = mac.harqInit(k.nHarqProcesses, false);
ue.harqRx = mac.harqRxInit(k.nHarqProcesses);
ue.rxSoft = repmat(struct('buf', []), 1, k.nHarqProcesses);   % one soft buffer per receive process
ue.db = phy.ts38214.sensingDbInit();
ue.grants = repmat(stack.grantNone(), 1, 0);    % one selected grant per Destination at most
% HARQ feedback (TS 38.213 16.3 / TS 38.321 5.22.1.3.2): PSFCH this UE expects (as transmitter)
% and PSFCH it owes (as receiver), each as a slot plus the 16.3-derived PRB and m0.
ue.psfchWait = repmat(struct('slot', 0, 'proc', 0, 'prb', 0, 'm0', 0, 'isLast', false), 1, 0);
ue.psfchOut = repmat(struct('slot', 0, 'prb', 0, 'm0', 0, 'ackBit', 0), 1, 0);
ue.lastTx = struct('slot', -1, 'pssch', false, 'psfch', false);      % half duplex
ue.maxConsecutiveDtx = 0;                       % sl-MaxNumConsecutiveDTX, 0 = RLF detection off
if pre.sl_MaxNumConsecutiveDTX_r16_Present
    ue.maxConsecutiveDtx = pre.sl_MaxNumConsecutiveDTX_r16;
end
ue.rlf = false;
% Congestion control (TS 38.214 8.1.6): SL RSSI per (slot, sub-channel) over the CBR window, kept
% as a ring of a + N + 1 slots so the window [n-N-a, n-N-1] is always held; and this UE's own
% transmissions [slot, L_subCH, priority] over the CR window, for SL CR per priority.
ue.congN = phy.ts38214.procTimeCongestion(ue.g.mu, k.congestionCapability);
ue.rssiRing = nan(ue.g.cbrWindowSlots + ue.congN + 1, ue.g.numSubchannel);
ue.rssiRingSlot = -ones(ue.g.cbrWindowSlots + ue.congN + 1, 1);
ue.txHist = zeros(0, 3);
ue.cbrLast = NaN;
ue.nextProc = 1;
ue.stats = struct('sduOffered', 0, 'noBearer', 0, 'lostToDiscard', 0, 'pdcpTimerExpired', 0, ...
    'macPdus', 0, 'transmissions', 0, 'selections', 0, 'infeasible', 0, 'pscchFound', 0, ...
    'tbOk', 0, 'tbFailed', 0, 'sduDelivered', 0, 'maxRetx', 0, ...
    'psfchSent', 0, 'ackRx', 0, 'nackRx', 0, 'dtxRx', 0, 'harqFreedEarly', 0, 'macTbFailed', 0, 'combinedRescue', 0, 'pdbReselect', 0, ...
    'spsPeriods', 0, 'spsUnusedPeriods', 0, 'spsKept', 0, 'spsReleased', 0, 'spsTooSmall', 0, 'missedResources', 0, ...
    'ccDropped', 0, 'reevalFlagged', 0, 'preemptFlagged', 0, 'replaced', 0, 'replaceFailed', 0);
end
