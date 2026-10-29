function [ue, out, dec] = rxSlot(ue, iq, n)
%rxSlot One slot of the receive side: IQ up to application packets.
%Spec:   none itself; each step is the owning package's:
%          stack.phySlotRx                 PHY: blind PSCCH, PSSCH, SCI-2, TB, PSSCH-RSRP
%          TS 38.214 8.1.4 step 2          sensing record (phy.ts38214.sensingDbRecord) with the
%                                          TRIV/FRIV-announced chained resources (TS 38.214 8.1.5)
%          TS 38.321 5.22.2.2.1/5.22.2.2.2 interest, receive HARQ, duplicate handling
%                                          (mac.sciInterest, harqRxAssign, harqRxProcess)
%          TS 38.321 5.22.2.2.2 / 6.1.6    PDU filter and disassembly (mac.pduFilter, demuxSlSch)
%          TS 38.322 5.1.1 / 38.323 5.1.1  gc/bc receiving entities created on the first PDU
%          TS 38.322 5.2.2.2 / 5.2.3.2     RLC (rlc.umRxPdu / rlc.amReceive)
%          TS 38.323 5.2.2 / 5.2.4         PDCP (pdcp.pdcpRxPdu / pdcpRxTimer)
%          TS 37.324 5.2.2 (NO LOCAL PDF)  SDAP header removal (sdap.sdapPduParse)
%Inputs: ue  struct from stack.ueInit
%        iq  nSamples x 1 complex -- what arrives at this UE in slot n (the channel's output), or
%            empty when nothing was transmitted
%        n   integer -- the slot
%Outputs: ue   updated
%         out  1 x d struct array, one per application packet delivered:
%              .srcL2Id .dstL2Id .cast (sdap.castCode) .lcid .qfi .payload .slot
%         dec  1 x m struct array, one per PSCCH this UE decoded in slot n, for a harness's
%              collision and capture statistics (it changes nothing in the UE):
%              .startSubch .LsubCH   where the SCI said the PSSCH is
%              .sourceID             SCI-2 Source ID (8 LSB of the L2 ID), -1 if SCI-2 failed
%              .tbOk                 this transmission's TB decoded ON ITS OWN (before any
%                                    HARQ combining), whether or not the UE is interested
%              .rsrpDbm              PSSCH-RSRP
%              Empty when the UE transmitted PSSCH in slot n (half duplex: nothing decoded).
%
%Retransmissions are soft-combined: mac.harqRxProcess returns the instruction to combine and
%stack.harqCombineDecode acts on it with the per-process soft buffer in ue.rxSoft. A copy of a TB
%already delivered is recognised and not delivered twice (but is still ACKed).

DUPLICATE_WINDOW_SLOTS = 32;        % one TB's chained copies span <= 31 slots (TRIV reach)
g = ue.g;
nowMs = n * g.slotMs;
out = repmat(struct('srcL2Id', 0, 'dstL2Id', 0, 'cast', 0, 'lcid', 0, 'qfi', 0, ...
    'payload', zeros(1, 0), 'slot', 0), 1, 0);

% ---- receive timers (UM t-Reassembly, PDCP t-Reordering; AM timers run in txSlot) ------
for i = 1:numel(ue.ent)
    e = ue.ent(i);
    if ~e.isRx, continue; end
    if strcmp(e.mode, 'um')
        e.rlcRx = rlc.umRxTimer(e.rlcRx, nowMs);
    end
    [e.pdcpRx, b, l] = pdcp.pdcpRxTimer(e.pdcpRx, nowMs);
    [out, ue.stats] = upToApp(out, ue.stats, e, b, l, n);
    ue.ent(i) = e;
end
ue.harqRx = mac.harqRxAge(ue.harqRx, n, DUPLICATE_WINDOW_SLOTS);

% Half duplex: a UE that transmitted PSCCH/PSSCH in slot n heard none of the others' PSSCH, and
% one that transmitted PSFCH did not hear the PSFCH symbols.
sentPssch = ue.lastTx.slot == n && ue.lastTx.pssch;
sentPsfch = ue.lastTx.slot == n && ue.lastTx.psfch;
nsf = mod(n, 10 * 2^g.mu);
det = repmat(struct(), 1, 0);
grid = []; powerCal = 0;
if ~isempty(iq)
    [det, grid, powerCal] = stack.phySlotRx(g, iq, nsf, ue.k.listSize, ue.k.maxIter, ~sentPssch);
end
ue = rssiRecord(ue, n, grid, powerCal, sentPssch);
dec = repmat(struct('startSubch', 0, 'LsubCH', 0, 'sourceID', -1, 'tbOk', false, 'rsrpDbm', 0), 1, 0);
for d = det
    sid = -1;
    if d.sci2Ok, sid = d.sci2.sourceID; end
    dec(end + 1) = struct('startSubch', d.startSubch, 'LsubCH', d.LsubCH, 'sourceID', sid, ...
        'tbOk', d.tbOk, 'rsrpDbm', d.rsrpDbm); %#ok<AGROW>
end
ue = psfchReceive(ue, n, nsf, grid, powerCal, sentPsfch);
if isempty(det)
    return;
end
ue.stats.pscchFound = ue.stats.pscchFound + numel(det);
ct = sap.castTypes();
peers = [ue.ent([ue.ent.cast] == sdap.castCode('unicast')).peerL2Id];
for d = det
    % Sensing: every decoded SCI-1A is recorded, interested or not (TS 38.214 8.1.4 step 2).
    [N, t1, t2] = phy.ts38212.trivDecode(d.sci1a.triv, g.maxNumPerReserve);
    [s1, s2] = phy.ts38212.frivDecode(d.sci1a.friv, d.LsubCH, g.numSubchannel, g.maxNumPerReserve);
    % The reservation period, when the pool carries the field (sl-MultiReserveResource): an SPS
    % transmitter announces P_rsvp_TX, and step 6 of 8.1.4 projects the reservation forward by it.
    % Recorded as absent before 2026-10-28 even when present, so no UE ever avoided another's
    % periodic reservation.
    rsvMs = 0;
    if g.multiReserve
        rsvMs = g.reservePeriodListMs(d.sci1a.reservationPeriodIndex + 1);
    end
    ue.db = phy.ts38214.sensingDbRecord(ue.db, n, d.startSubch, d.LsubCH, d.sci1a.priority, ...
        d.rsrpDbm, rsvMs > 0, rsvMs, N, t1, t2, s1, s2);      % 0 ms announces no periodic reservation
    if ~d.sci2Ok
        continue;
    end
    s = d.sci2;
    if ~mac.sciInterest(s.castType, s.destinationID, ue.srcL2Id, [ue.monitoredL2Ids peers])
        continue;
    end
    [ue.harqRx, proc, isNew, why] = mac.harqRxAssign(ue.harqRx, s.sourceID, s.destinationID, ...
        s.harqProcessNumber, s.ndi, n, DUPLICATE_WINDOW_SLOTS);
    if proc == 0
        % A repeat of a TB already delivered still gets its ACK (TS 38.321 5.22.2.2.2, "or if the
        % data for this TB was successfully decoded before") -- only delivery is once-only.
        if strcmp(why, 'duplicate')
            ue = owePsfch(ue, n, d, mac.harqRxDuplicateFeedback(s.castType, s.harqFeedbackEnabled == 1));
        end
        continue;
    end
    % Soft combining: the same condition mac.harqRxProcess uses to instruct it (5.22.2.2.2), so
    % the TB is decoded against everything heard for it, not this transmission alone.
    combine = ~isNew && ue.harqRx.softValid(proc) && ~ue.harqRx.decoded(proc);
    prevBuf = [];
    if combine, prevBuf = ue.rxSoft(proc).buf; end
    [tbBitsC, tbOkC, ue.rxSoft(proc).buf] = stack.harqCombineDecode(d.dataLlr, prevBuf, d.trblklen, ...
        d.R, s.rv, d.modScheme, ue.k.maxIter);
    if combine && tbOkC && ~d.tbOk
        ue.stats.combinedRescue = ue.stats.combinedRescue + 1;
    end
    d.tbOk = tbOkC;
    d.tbBits = tbBitsC;
    passes = false;
    if d.tbOk
        ue.stats.tbOk = ue.stats.tbOk + 1;
        [srcHigh16, dstHigh8, sduBytes, sduLen, sduLcid] = mac.demuxSlSch(d.tbBits);
        passes = mac.pduFilter(s.castType, dstHigh8, srcHigh16, s.destinationID, s.sourceID, ...
            ue.srcL2Id, [ue.monitoredL2Ids peers], sduLcid, false);
    else
        ue.stats.tbFailed = ue.stats.tbFailed + 1;
    end
    [ue.harqRx, deliver, fb, combineMac] = mac.harqRxProcess(ue.harqRx, proc, isNew, d.tbOk, passes, ...
        s.castType, s.harqFeedbackEnabled == 1, true, n);
    assert(combineMac == combine, 'stack:rxSlot:combine', 'soft-combining decision disagrees with mac.harqRxProcess');
    ue = owePsfch(ue, n, d, fb);
    if ~deliver
        continue;
    end
    src = srcHigh16 * 2^8 + s.sourceID;               % the two halves of each identity
    dst = dstHigh8 * 2^16 + s.destinationID;          % (TS 38.321 6.2.4 + 5.22.1.3.1)
    if s.castType == ct.unicast
        castLbl = 'unicast';
    elseif s.castType == ct.broadcast
        castLbl = 'broadcast';
    else
        castLbl = 'groupcast';
    end
    off = 0;
    for q = 1:numel(sduLen)
        rlcPdu = sduBytes(off + 1 : off + sduLen(q));
        off = off + sduLen(q);
        [ue, out] = toEntity(ue, out, castLbl, src, dst, sduLcid(q), rlcPdu, nowMs, n);
    end
end
end

% =========================================================================================
function ue = rssiRecord(ue, n, grid, powerCal, sentPssch)
% SL RSSI of every sub-channel of the pool in slot n (TS 38.215 5.1.25, phy.ts38215.slRssi) into
% the CBR ring (TS 38.215 5.1.27). The grid is put in sqrt(W) per RE first (powerCal, see
% stack.phySlotRx). A slot this UE transmitted PSSCH in was not measured (half duplex): NaN, which
% phy.ts38215.cbr leaves out of both numerator and denominator. Nothing arrived: no energy above
% the thermal floor, which no sl-ThreshS-RSSI-CBR (>= -112 dBm) can call busy: -Inf.
g = ue.g;
if ~g.cbrMeasured
    return;
end
row = nan(1, g.numSubchannel);
if ~sentPssch
    if isempty(grid)
        row(:) = -Inf;
    else
        gw = grid * sqrt(powerCal);
        sym = g.slStartSymbol + (0:g.ld - 1);         % PSCCH/PSSCH symbols; slRssi drops the first
        for s = 1:g.numSubchannel
            [~, row(s)] = phy.ts38215.slRssi(gw, g.subchStartRb(s), g.subchSizeRb, sym);
        end
    end
end
r = mod(n, numel(ue.rssiRingSlot)) + 1;
ue.rssiRing(r, :) = row;
ue.rssiRingSlot(r) = n;
end

function ue = owePsfch(ue, n, d, fb)
% Queue the HARQ-ACK this UE owes for PSSCH d: TS 38.213 16.3, "the UE transmits the PSFCH in a
% first slot that includes PSFCH resources and is at least ... sl-MinTimeGapPSFCH ... after a last
% slot of the PSSCH reception", on the resource derived from the PSSCH's sub-channel and P_ID.
if strcmp(fb, 'none') || ue.g.psfchPeriod == 0
    return;
end
[prb, m0] = stack.psfchResourceFor(ue.g, d.startSubch, d.sci2.sourceID);
ue.psfchOut(end + 1) = struct('slot', phy.ts38213.psfchTiming(n, ue.g.minTimeGapPsfch, ue.g.psfchPeriod), ...
    'prb', prb, 'm0', m0, 'ackBit', double(strcmp(fb, 'ack')));
end

% =========================================================================================
function ue = psfchReceive(ue, n, nsf, grid, powerCal, sentPsfch)
% Resolve every PSFCH this UE is waiting for in slot n: ACK, NACK or DTX (TS 38.321 5.22.1.3.2),
% then the HARQ entity's flush and DTX/RLF rules (mac.harqOnFeedback, 5.22.1.3.1a / 5.22.1.3.3).
if isempty(ue.psfchWait)
    return;
end
due = find([ue.psfchWait.slot] == n);
if isempty(due)
    return;
end
g = ue.g;
ackBit = -ones(1, numel(due));                       % DTX unless something is detected
if ~isempty(grid) && ~sentPsfch
    dps = repmat(struct('m0', 0, 'mcs', 0, 'lp', g.psfchSymbol, 'nsf', nsf, 'NsymbSlot', g.NsymbSlot, ...
        'startPRB', 0, 'symbol', g.psfchSymbol), 1, numel(due));
    for q = 1:numel(due)
        dps(q).m0 = ue.psfchWait(due(q)).m0;
        dps(q).startPRB = ue.psfchWait(due(q)).prb;
    end
    ackBit = phy.rx.det.psfchDetect(grid, struct(), g.psfchCfg, dps, false(1, numel(due)), ue.k.psfchThreshold);
    % Energy gate (non-normative): the correlator is scale-free, so require the PRB to stand clear
    % of the thermal noise before believing either hypothesis.
    SUBCARRIERS_PER_RB = 12; MW_PER_W = 1000; DB = 10; SCS_BASE_HZ = 15e3;
    noisePerReW = 10^(rf.noiseFloorDbm(SCS_BASE_HZ * 2^g.mu, ue.k.noiseFigureDb) / DB) / MW_PER_W;
    for q = 1:numel(due)
        k0 = dps(q).startPRB * SUBCARRIERS_PER_RB;
        re = grid(k0 + (1:SUBCARRIERS_PER_RB), g.psfchSymbol + 1);
        if powerCal * mean(abs(re).^2) < noisePerReW * 10^(ue.k.psfchGateDb / DB)
            ackBit(q) = -1;
        end
    end
end
for q = 1:numel(due)
    w = ue.psfchWait(due(q));
    ack = ackBit(q) == 1;
    received = ackBit(q) >= 0;
    if ack, ue.stats.ackRx = ue.stats.ackRx + 1;
    elseif received, ue.stats.nackRx = ue.stats.nackRx + 1;
    else, ue.stats.dtxRx = ue.stats.dtxRx + 1;
    end
    [ue.harq, flushed, rlf] = mac.harqOnFeedback(ue.harq, w.proc, ack, received, 0, ue.maxConsecutiveDtx);
    ue.rlf = ue.rlf || rlf;
    if flushed
        % ACK: the TB is done; the grant's remaining (retransmission) resources are released.
        if ~w.isLast
            ue.stats.harqFreedEarly = ue.stats.harqFreedEarly + 1;
        end
        if ~isempty(ue.grants)
            ue.grants([ue.grants.proc] == w.proc & [ue.grants.next] > 1) = [];
        end
    elseif w.isLast
        % NACK or DTX on the last reserved transmission: no resource left, the MAC gives up on the
        % TB (RLC AM, if any, recovers it).
        ue.harq = mac.harqFlush(ue.harq, w.proc);
        ue.stats.macTbFailed = ue.stats.macTbFailed + 1;
    end
end
ue.psfchWait(due) = [];
end

% =========================================================================================
function [ue, out] = toEntity(ue, out, castLbl, src, dst, lcid, rlcPdu, nowMs, n)
c = sdap.castCode(castLbl);
if strcmp(castLbl, 'unicast')
    i = find([ue.ent.isRx] & [ue.ent.cast] == c & [ue.ent.peerL2Id] == src & [ue.ent.lcid] == lcid, 1);
    if isempty(i), return; end                         % no PC5-RRC-agreed entity on this LCID
else
    i = find([ue.ent.isRx] & [ue.ent.cast] == c & [ue.ent.peerL2Id] == src & ...
        [ue.ent.groupL2Id] == dst & [ue.ent.lcid] == lcid, 1);
    if isempty(i)
        % TS 38.322 5.1.1 / TS 38.323 5.1.1: first PDU from a new (source, destination, LCID).
        ue.ent(end + 1) = stack.entityCreate(ue, 0, src, dst, castLbl, lcid, false, true);
        i = numel(ue.ent);
    end
end
e = ue.ent(i);
if strcmp(e.mode, 'am')
    [e.rlcTx, e.rlcRx, b, l, ~, mr] = rlc.amReceive(e.rlcTx, e.rlcRx, rlcPdu, nowMs);
    ue.stats.maxRetx = ue.stats.maxRetx + numel(mr);
else
    [e.rlcRx, b, l] = rlc.umRxPdu(e.rlcRx, rlcPdu, nowMs);
end
off = 0;
for q = 1:numel(l)
    [e.pdcpRx, pb, pl] = pdcp.pdcpRxPdu(e.pdcpRx, b(off + 1 : off + l(q)), nowMs);
    off = off + l(q);
    [out, ue.stats] = upToApp(out, ue.stats, e, pb, pl, n, src, dst);
end
ue.ent(i) = e;
end

function [out, stats] = upToApp(out, stats, e, b, l, n, src, dst)
% PDCP SDUs -> SDAP -> application packets.
if nargin < 7
    src = e.peerL2Id;
    dst = e.groupL2Id;
end
off = 0;
for q = 1:numel(l)
    [valid, qfi, payload] = sdap.sdapPduParse(b(off + 1 : off + l(q)), e.sdapHeader);
    off = off + l(q);
    if ~valid, continue; end
    out(end + 1) = struct('srcL2Id', src, 'dstL2Id', dst, 'cast', e.cast, 'lcid', e.lcid, ...
        'qfi', qfi, 'payload', payload, 'slot', n); %#ok<AGROW>
    stats.sduDelivered = stats.sduDelivered + 1;
end
end
