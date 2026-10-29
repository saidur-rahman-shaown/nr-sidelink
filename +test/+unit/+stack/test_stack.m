function test_stack()
%test_stack The access stratum end to end: application packet -> SDAP -> PDCP -> RLC -> MAC -> PHY
%-> IQ -> PHY -> MAC -> RLC -> PDCP -> SDAP -> application, configured from the stored JSON.
%SPEC: composition test; each layer's clauses are tested in its own package. What this proves
%      is that the layers agree with each other on real bytes and a real waveform, and that the
%      configuration actually reaches every layer.
%Level 1: both ends are this tree. The "channel" here is a sum of IQ plus a small AWGN floor --
%      the channel model is +harness/'s concern, not the access stratum's.

o = cfg.loadConfig('+cfg/configs/preconfig_example.json', [58 56 23]);
k = stack.defaults();
BC = hex2dec('FFFFFF');
pq = cfg.pqiTable();
srcA = hex2dec('0A0B0C'); srcB = hex2dec('112233');

%% ---- configuration reaches every layer --------------------------------------
A = stack.ueInit(o, srcA, BC, k, 1);
g = A.g;
assert(g.nRbBwp == 50 && g.mu == 1 && g.ld == 10 && isequal(g.dmrsSymbols, [3 8]) && g.psfchSymbol == 12, ...
    ['geometry from the stored config: 50-PRB BWP, 30 kHz; PSFCH every slot, so l_d = 14 - guard - 2 PSFCH ' ...
     '- the gap before them = 10, DM-RS at 3 and 8 (Table 8.4.1.1.2-1), PSFCH content on symbol 12']);
assert(isequal(g.subchStartRb, [0 10 20 30 40]) && g.pscchPrb == 10 && g.pscchSymbols == 2, 'pool geometry');
assert(g.beta == 1.125, 'beta from sl-BetaOffsets2ndSCI index 0 -> Table 9.3-2 entry 0');
assert(all(g.thresListDbm == -90), 'sl-Thres-RSRP value 20 = -128 + 19*2 = -90 dBm (TS 38.331)');

%% ---- QoS: PQI -> SLRB -> logical channel priority -> SCI-1A, for every mapped PQI -------
% The cross-package check +sdap/CLAUDE.md asks for: the priority a receiver decodes from SCI-1A
% equals the PQI table's priority level, for every PQI the stored config maps.
B = stack.ueInit(o, srcB, BC, k, 2);
[A, B] = stack.unicastSetup(A, B);
cases = {58, 'broadcast'; 56, 'broadcast'; 23, 'unicast'};
for c = 1:size(cases, 1)
    pqi = cases{c, 1}; cast = cases{c, 2};
    a = stack.ueInit(o, srcA, BC, k, 10 + c);
    b = stack.ueInit(o, srcB, BC, k, 20 + c);
    [a, b] = stack.unicastSetup(a, b);
    dst = BC; if strcmp(cast, 'unicast'), dst = srcB; end
    [a, ok, rb] = stack.appSend(a, pqi, c, dst, cast, mod(1:40, 256), 0);
    row = cfg.pqiLookup(pq, pqi);
    assert(ok && a.rbLch(rb).priority == row.priority, 'PQI %d: SLRB %d logical channel priority %d, PQI table %d', ...
        pqi, rb, a.rbLch(rb).priority, row.priority);
    [a, b, log] = runLink([a b], 0:230, @(n, from, to) false);   % covers a 100 ms PDB window
    sci = [log.prio];
    assert(~isempty(sci) && all(sci == row.priority), 'PQI %d: SCI-1A priority %s, expected %d', pqi, mat2str(sci), row.priority);
    dd = log(1).delivered;
    assert(numel(dd) == 1 && isequal(dd(1).payload, mod(1:40, 256)), 'PQI %d: delivered byte-exact', pqi);
    if strcmp(cast, 'unicast')
        assert(dd(1).qfi == c, 'unicast carries the PQFI in the SDAP header (37.324 6.2.2.4)');
    else
        assert(dd(1).qfi == -1, 'broadcast carries NO SDAP header (37.324 6.2.1)');
    end
end

%% ---- broadcast: two flows, two SLRBs, segmentation, one IQ ----------------------
A = stack.ueInit(o, srcA, BC, k, 1);
B = stack.ueInit(o, srcB, BC, k, 2);
rng(7);
p1 = randi([0 255], 1, 200); p2 = randi([0 255], 1, 700);
A = stack.appSend(A, 58, 1, BC, 'broadcast', p1, 0);
A = stack.appSend(A, 56, 2, BC, 'broadcast', p2, 0);
assert(isequal([A.ent.lcid], [4 5]) && isequal([A.ent.prio], [4 6]), 'a new LCID per SLRB towards the destination');
[A, ~, iq, tx] = firstTx(A, 0:60);
assert(numel(iq) == 15360, 'one slot at 30 kHz: 15360 samples at 30.72 MHz');
on = iq ~= 0;
assert(abs(10 * log10(mean(abs(iq(on)).^2)) + 30 - 23) < 0.01, 'IQ scaled to 23 dBm over the transmitted samples');
% The guard and AGC statements are about the resource grid (the time-domain tail of the guard
% symbol carries the modulator's symbol-edge windowing, so it is checked on the grid).
s1 = struct('priority', 3, 'friv', 0, 'triv', 0, 'reservationPeriodIndex', 0, 'dmrsPatternIndex', 0, ...
    'sci2Format', 'A', 'betaOffsetIndex', 0, 'numDmrsPort', 0, 'mcs', 7, 'additionalMcsTableIndex', 0, 'psfchOverhead', 0);
s2 = struct('harqProcessNumber', 0, 'ndi', 0, 'rv', 0, 'sourceID', 1, 'destinationID', 2, ...
    'harqFeedbackEnabled', 0, 'castType', 0, 'csiRequest', 0);
[~, grid] = stack.phySlotTx(g, 2, 1, 0, s1, s2, false(8 * g.tbsBytesByLsubCH(1), 1), 0, NaN);
sc = 20 * 12 + (0:119);
assert(nnz(grid(:, 14)) == 0 && nnz(grid(:, 11)) == 0, 'the guard symbol and the pre-PSFCH gap are empty');
assert(nnz(grid(:, 12)) == 0 && nnz(grid(:, 13)) == 0, 'a PSSCH-only slot leaves the PSFCH symbols empty');
assert(isequal(grid(sc + 1, 1), grid(sc + 1, 2)) && nnz(grid(:, 1)) == 120, ...
    'the AGC symbol duplicates symbol 1 on exactly the allocation (TS 38.211 8.3.1.5 / 8.3.2.3)');
% 900 bytes do not fit the largest TB (560 bytes once PSFCH takes three symbols), so LCP serves
% the priority-4 channel (LCID 4, PQI 58) first; SCI-1A carries that priority.
assert(tx.lcids(1) == 4 && tx.prio == 4, 'LCP serves the higher-priority channel first; SCI priority 4');
A = stack.ueInit(o, srcA, BC, k, 1);
A = stack.appSend(A, 58, 1, BC, 'broadcast', p1, 0);
A = stack.appSend(A, 56, 2, BC, 'broadcast', p2, 0);
[~, ~, log] = runLink([A B], 0:230, @(n, from, to) false);
d = log(1).delivered;
assert(numel(d) == 2, 'both packets delivered, got %d', numel(d));
assert(isequal(d([d.lcid] == 4).payload, p1) && isequal(d([d.lcid] == 5).payload, p2), 'byte-exact through every layer, one LCID per SLRB');
assert(all([d.srcL2Id] == srcA) && all([d.dstL2Id] == BC), 'both halves of each Layer-2 ID rejoin (MAC subheader + SCI)');

%% ---- the B9 gate: unicast AM recovers a loss while broadcast UM runs ----------------
A = stack.ueInit(o, srcA, BC, k, 3);
B = stack.ueInit(o, srcB, BC, k, 4);
[A, B] = stack.unicastSetup(A, B);
uniPay = cell(1, 4); bcPay = cell(1, 4);
for q = 1:4
    uniPay{q} = mod(q * 11 + (1:150), 256);
    bcPay{q} = mod(q * 7 + (1:120), 256);
end
nUniNew = 0;
    function drop = lose(n, from, to, tx) %#ok<INUSL>
        % Lose every copy of A's FIRST unicast MAC PDU -- the initial transmission and its blind
        % retransmission, whenever selection put them. Broadcast is untouched, so the UM flow
        % must arrive intact while RLC AM repairs the unicast loss.
        drop = false;
        if from ~= 1 || isempty(tx) || tx.cast ~= sdap.castCode('unicast'), return; end   % a PSFCH-only slot has no PSSCH record
        if ~tx.isRetx, nUniNew = nUniNew + 1; end
        drop = nUniNew == 1;
    end
nextQ = 1;
ues = [A B];
logAll = repmat(struct('delivered', [], 'prio', []), 1, 2);
for n = 0:1200
    if mod(n, 50) == 0 && nextQ <= 4
        ues(1) = stack.appSend(ues(1), 23, 9, srcB, 'unicast', uniPay{nextQ}, n * g.slotMs);
        ues(1) = stack.appSend(ues(1), 58, 1, BC, 'broadcast', bcPay{nextQ}, n * g.slotMs);
        nextQ = nextQ + 1;
    end
    [ues, step] = oneSlot(ues, n, @lose);
    for u = 1:2, logAll(u).delivered = [logAll(u).delivered step(u).delivered]; end
end
dB = logAll(2).delivered;
uni = dB([dB.cast] == sdap.castCode('unicast'));
bc = dB([dB.cast] == sdap.castCode('broadcast'));
assert(numel(uni) == 4 && isequal(sort(cellfun(@(x) x(1), {uni.payload})), sort(cellfun(@(x) x(1), uniPay))), ...
    'every unicast packet delivered, including the one whose transport blocks were lost (RLC AM ARQ)');
assert(numel(bc) == 4 && isequal(sort(cellfun(@(x) x(1), {bc.payload})), sort(cellfun(@(x) x(1), bcPay))), ...
    'the broadcast UM flow ran uninterrupted alongside: all 4 delivered, got %d', numel(bc));
assert(ues(1).stats.lostToDiscard == 0 && ues(1).stats.maxRetx == 0, 'nothing discarded, no max-retx');
assert(nUniNew >= 2, 'the lost unicast MAC PDU was followed by more unicast transmissions');
assert(ues(1).stats.dtxRx >= 1, 'the lost MAC PDU drew no PSFCH: a DTX at A');
assert(ues(2).stats.psfchSent >= 3 && ues(1).stats.ackRx >= 3, 'B acknowledged the unicast TBs it decoded');
assert(ues(2).stats.transmissions > 0, 'B transmitted STATUS PDUs back on the AM logical channel');

%% ---- HARQ feedback, unicast only --------------------------------------------------
% (a) Clean link: every unicast TB is ACKed after its FIRST transmission, so the reserved
%     retransmission resource is released, not used. (b) Broadcast never asks for feedback.
A = stack.ueInit(o, srcA, BC, k, 6);
B = stack.ueInit(o, srcB, BC, k, 7);
[A, B] = stack.unicastSetup(A, B);
A = stack.appSend(A, 23, 9, srcB, 'unicast', 1:100, 0);
A = stack.appSend(A, 58, 1, BC, 'broadcast', 1:100, 0);
[A, B] = runLink([A B], 0:450, @(n, f, t) false);
assert(A.stats.ackRx >= 1 && A.stats.nackRx == 0 && A.stats.dtxRx == 0, 'clean unicast: ACK, no NACK, no DTX');
assert(A.stats.harqFreedEarly >= 1, 'the ACK released the reserved retransmission resource (TS 38.321 5.22.1.3.1a)');
assert(B.stats.psfchSent == A.stats.ackRx, 'every PSFCH B sent is one A detected');
assert(A.stats.psfchSent == B.stats.ackRx, 'and B''s STATUS PDUs to A (feedback-enabled too) were ACKed by A');
assert(B.stats.psfchSent + A.stats.psfchSent == A.stats.ackRx + B.stats.ackRx, 'no PSFCH for broadcast');

% (c) Lose only the FIRST transmission (RV 0) of the first unicast TB. B never heard RV 0, so the
%     RV 2 retransmission is its FIRST reception of the TB: nothing to combine with, and RV 2 alone
%     (mostly parity, code rate ~0.73 here) does not decode. So: DTX at A (nothing heard), then a
%     NACK (SCI decoded, TB not), no resource left -> the MAC gives up, and RLC AM recovers it with
%     a fresh RV 0. This is how incremental redundancy behaves when the first copy is lost.
A = stack.ueInit(o, srcA, BC, k, 8);
B = stack.ueInit(o, srcB, BC, k, 9);
[A, B] = stack.unicastSetup(A, B);
A = stack.appSend(A, 23, 9, srcB, 'unicast', 1:100, 0);
nUni = 0;
    function drop = loseFirstTx(n, from, to, tx) %#ok<INUSL>
        drop = false;
        if from == 1 && ~isempty(tx) && tx.cast == sdap.castCode('unicast')
            nUni = nUni + 1;
            drop = nUni == 1;
        end
    end
ues = [A B]; got = [];
for n = 0:450
    [ues, step] = oneSlot(ues, n, @loseFirstTx);
    got = [got step(2).delivered]; %#ok<AGROW>
end
A = ues(1);
assert(numel(got) == 1 && isequal(got(1).payload, 1:100), 'delivered once');
assert(A.stats.dtxRx == 1 && A.stats.nackRx == 1 && A.stats.macTbFailed == 1 && A.stats.ackRx == 1, ...
    'DTX, then NACK on RV 2 alone, MAC gives up, RLC retransmits and is ACKed; got DTX %d NACK %d fail %d ACK %d', ...
    A.stats.dtxRx, A.stats.nackRx, A.stats.macTbFailed, A.stats.ackRx);

% (d) Soft combining: both transmissions arrive weak (-3 dB over the band, about +4 dB per RE on
%     the 10-PRB allocation). RV 0 alone fails -> NACK; the RV 2 retransmission is combined with
%     RV 0 in the receive process's soft buffer and decodes -> ACK. HARQ, not RLC, recovers it.
A = stack.ueInit(o, srcA, BC, k, 8);
B = stack.ueInit(o, srcB, BC, k, 9);
[A, B] = stack.unicastSetup(A, B);
A = stack.appSend(A, 23, 9, srcB, 'unicast', 1:100, 0);
ues = [A B]; got = []; rsW = RandStream('mt19937ar', 'Seed', 97);
for n = 0:450
    [ues, step] = oneSlot(ues, n, @(n, f, t, x) false, false, ...
        @(n, f, t, x) weakUnicast(f, x), rsW);
    got = [got step(2).delivered]; %#ok<AGROW>
end
A = ues(1); B = ues(2);
assert(numel(got) == 1 && isequal(got(1).payload, 1:100), 'delivered once');
assert(A.stats.nackRx == 1 && A.stats.ackRx >= 1 && B.stats.combinedRescue == 1 && A.stats.macTbFailed == 0, ...
    'NACK on RV 0, then the combined RV 0 + RV 2 decodes; got NACK %d ACK %d rescue %d fail %d', ...
    A.stats.nackRx, A.stats.ackRx, B.stats.combinedRescue, A.stats.macTbFailed);

%% ---- PDB discard is counted, not sent late ----------------------------------------
A = stack.ueInit(o, srcA, BC, k, 5);
A = stack.appSend(A, 56, 2, BC, 'broadcast', 1:50, 0);        % 20 ms PDB / ms20 discard timer
[A, iq] = stack.txSlot(A, 41);                                 % first look after 20.5 ms
assert(isempty(iq) && A.stats.lostToDiscard == 1 && A.stats.pdcpTimerExpired == 1, ...
    'an unsent SDU whose discardTimer expired is discarded AND counted');

%% ---- no bearer, no invention --------------------------------------------------------
[A, ok] = stack.appSend(A, 58, 1, hex2dec('ABCDEF'), 'groupcast', 1:10, 0);
assert(~ok && A.stats.noBearer == 1, 'no groupcast SLRB and no groupcast default: the packet is refused and counted');

%% ---- sensing-based SPS (prsvpTxMs = 100): one grant reused period after period -------
% A periodic PQI 56 flow every 100 ms. With SPS the MAC selects once and reuses the resources
% (TS 38.321 5.22.1.1); every SCI-1A announces the 100 ms period, and the receiver records it as
% a periodic reservation in its sensing database (TS 38.214 8.1.4 step 2). P_rsvp = 0 for
% comparison selects once per packet.
kS = k; kS.prsvpTxMs = 100;
nPkt = 6; per = 200;                                    % 100 ms at mu = 1
for mode = [100 0]
    kS.prsvpTxMs = mode;
    A = stack.ueInit(o, srcA, BC, kS, 31); B = stack.ueInit(o, srcB, BC, kS, 32);
    got = 0;
    for n = 0:nPkt * per + 60
        if mod(n, per) == 10 && n < nPkt * per
            A = stack.appSend(A, 56, 2, BC, 'broadcast', mod(1:300, 256), n * A.g.slotMs);
        end
        [A, iqA, txA] = stack.txSlot(A, n);
        [B, ~] = stack.txSlot(B, n);
        if ~isempty(iqA)
            [B, dd] = stack.rxSlot(B, iqA, n);
            got = got + numel(dd);
        end
    end
    if mode > 0
        assert(A.stats.selections <= 2, 'SPS: 6 periodic packets must ride one grant (two at most), got %d selections', A.stats.selections);
        assert(A.stats.spsPeriods >= nPkt - 1, 'SPS: the grant must close a period per packet, got %d', A.stats.spsPeriods);
        assert(any(B.db.reservationPeriodPresent & B.db.reservationPeriodMs == 100), 'SPS: the receiver must record the announced 100 ms reservation');
    else
        assert(A.stats.selections == nPkt, 'dynamic: one selection per packet, got %d', A.stats.selections);
    end
    assert(got == nPkt, 'P_rsvp %d: all %d packets delivered, got %d', mode, nPkt, got);
    assert(A.stats.transmissions == 2 * nPkt, 'P_rsvp %d: initial + blind retransmission for every packet, got %d', mode, A.stats.transmissions);
end

%% ---- congestion control (TS 38.214 8.1.6): a busy channel caps the UE's own CR -------------
% The stored config maps every priority to CBR ranges [0.2 0.4 0.6 0.8 1.0] with sl-CR-Limit
% 1.0/0.6/0.3/0.12/0.05. A receiver drowned in wideband energy measures every sub-channel above
% sl-ThreshS-RSSI-CBR, so CBR = 1 (top range, CR limit 0.05 over 1000 ms = 500 sub-channel-slots);
% a quiet one measures CBR = 0 (limit 1.0). The same 1000-byte flow every 10 ms is throttled in the
% first case and not in the second.
kC = k; kC.prsvpTxMs = 0;
rsJ = RandStream('mt19937ar', 'Seed', 7);
for jam = [true false]
    A = stack.ueInit(o, srcA, BC, kC, 41);
    for n = 0:1200
        if mod(n, 20) == 0
            A = stack.appSend(A, 56, 2, BC, 'broadcast', mod(1:1000, 256), n * A.g.slotMs);
        end
        [A, ~] = stack.txSlot(A, n);
        y = [];
        if jam, y = 1e-3 * (randn(rsJ, 15360, 1) + 1j * randn(rsJ, 15360, 1)) / sqrt(2); end   % -30 dBm wideband
        A = stack.rxSlot(A, y, n);
    end
    usedSubchSlots = sum(A.txHist(A.txHist(:, 1) > 1200 - A.g.crWindowSlots, 2));
    fprintf('congestion control, jammed %d: CBR %.2f, transmissions %d, dropped %d, own sub-channel-slots %d\n', ...
        jam, A.cbrLast, A.stats.transmissions, A.stats.ccDropped, usedSubchSlots);
    if jam
        assert(A.cbrLast == 1, 'jammed: every measured sub-channel busy, CBR 1, got %g', A.cbrLast);
        assert(A.stats.ccDropped > 0, 'jammed: the CR limit 0.05 must drop transmissions');
        assert(usedSubchSlots <= 0.05 * A.g.numSubchannel * A.g.crWindowSlots, ...
            'jammed: own usage over the CR window stays within sl-CR-Limit 0.05, got %d', usedSubchSlots);
    else
        assert(A.cbrLast == 0 && A.stats.ccDropped == 0, 'quiet: CBR 0 and nothing dropped, got CBR %g, %d dropped', A.cbrLast, A.stats.ccDropped);
    end
end

%% ---- re-evaluation and pre-emption (TS 38.321 5.22.1.2a) at m - T3 ------------------------
% A reservation sensed AFTER selection that lands on a reserved resource: before the resource is
% announced, re-evaluation drops it from S_A (any priority above the RSRP threshold); once it is
% announced (SPS, second period), only a HIGHER-priority reservation pre-empts it
% (sl-PreemptionEnable 'enabled'). Either way the resource alone is replaced; the grant survives.
for mode = [0 100]
    kR = k; kR.prsvpTxMs = mode;
    A = stack.ueInit(o, srcA, BC, kR, 51);
    T3 = phy.ts38214.procTimeSelection(A.g.mu);
    A = stack.appSend(A, 56, 2, BC, 'broadcast', mod(1:300, 256), 0);
    hit = false;
    for n = 0:500
        if n > 0 && ((mode > 0 && mod(n, 200) == 0) || (mode == 0 && ~hit && mod(n, 40) == 0))
            A = stack.appSend(A, 56, 2, BC, 'broadcast', mod(1:300, 256), n * A.g.slotMs);
        end
        gr = A.grants;
        % inject once: dynamic -- before the first transmission; SPS -- in the second period
        if ~hit && ~isempty(gr) && (mode == 0 || gr(1).periodIdx >= 1) && gr(1).next == 1 && ...
                gr(1).slots(1) - n > T3 + 1 && gr(1).slots(1) - n <= 31
            target = gr(1).slots(1); tsub = gr(1).subch(1);
            % a neighbour's SCI decoded in slot n-1 whose second resource is our target
            A.db = phy.ts38214.sensingDbRecord(A.db, n - 1, mod(tsub + 2, A.g.numSubchannel), gr(1).L, 1, -50, ...
                false, 0, 2, target - (n - 1), 0, tsub, 0);
            hit = true;
            selBefore = A.stats.selections;
        end
        [A, ~] = stack.txSlot(A, n);
        if hit && n >= target, break; end
    end
    assert(hit, 'P_rsvp %d: no grant to disturb', mode);
    fprintf('re-evaluation, P_rsvp %d: re-evaluated %d, pre-empted %d, replaced %d, failed %d\n', mode, ...
        A.stats.reevalFlagged, A.stats.preemptFlagged, A.stats.replaced, A.stats.replaceFailed);
    if mode == 0
        assert(A.stats.reevalFlagged >= 1 && A.stats.preemptFlagged == 0, 'dynamic, not yet announced: re-evaluation, not pre-emption');
    else
        assert(A.stats.preemptFlagged >= 1, 'SPS second period, announced: pre-emption by the priority-1 reservation');
    end
    assert(A.stats.replaced >= 1 && A.stats.replaceFailed == 0, 'the flagged resource is replaced, the grant kept');
    assert(A.stats.selections == selBefore, 'no reselection: one resource swapped, not the grant cleared');
end
end

% =========================================================================================
function [ue, n, iq, tx] = firstTx(ue, slots)
for n = slots
    [ue, iq, tx] = stack.txSlot(ue, n);
    if ~isempty(iq), return; end
end
error('test:noTx', 'no transmission in the window');
end

function [a, b, log] = runLink(ues, slots, dropFn)
log = repmat(struct('delivered', [], 'prio', []), 1, 2);
for n = slots
    [ues, step] = oneSlot(ues, n, @(n, f, t, x) dropFn(n, f, t), true);
    log(1).delivered = [log(1).delivered step(2).delivered];   % log(1) = what B received
    log(1).prio = [log(1).prio step(2).prio];                   % SCI priorities B decoded
end
a = ues(1); b = ues(2);
log(2) = log(1);
end

function snr = weakUnicast(from, tx)
% -3 dB on A's unicast PSSCH, the default clean floor on everything else.
snr = Inf;
if from == 1 && ~isempty(tx) && tx.cast == sdap.castCode('unicast')
    snr = -3;
end
end

function [ues, step] = oneSlot(ues, n, dropFn, wantPrio, snrFn, rs)
% Every UE transmits (or not), then every UE receives the sum of the OTHERS' IQ through a small
% AWGN floor -- a shared medium where transmissions in one slot superpose. Half duplex is the
% stack's business (stack.rxSlot): a UE that sent PSSCH still hears PSFCH in the slot's last symbols.
nU = numel(ues);
iqs = cell(1, nU);
txs = cell(1, nU);
step = repmat(struct('delivered', [], 'prio', []), 1, nU);
for u = 1:nU
    [ues(u), iqs{u}, txs{u}] = stack.txSlot(ues(u), n);
end
for u = 1:nU
    rxIq = [];
    for v = 1:nU
        if v == u || isempty(iqs{v}) || dropFn(n, v, u, txs{v}), continue; end
        x = iqs{v};
        if nargin >= 5 && ~isempty(snrFn)
            snr = snrFn(n, v, u, txs{v});
            if isfinite(snr)
                p = mean(abs(x(x ~= 0)).^2);
                x = x + sqrt(p * 10^(-snr / 10)) * (randn(rs, size(x)) + 1j * randn(rs, size(x))) / sqrt(2);
            end
        end
        if isempty(rxIq), rxIq = x; else, rxIq = rxIq + x; end
    end
    if nargin < 4, wantPrio = false; end
    if ~isempty(rxIq)
        rxIq = rxIq + 1e-3 * sqrt(mean(abs(rxIq).^2)) * (randn(size(rxIq)) + 1j * randn(size(rxIq))) / sqrt(2);
        if wantPrio && isempty(iqs{u})
            det = stack.phySlotRx(ues(u).g, rxIq, mod(n, 10 * 2^ues(u).g.mu), 8, 12);
            step(u).prio = arrayfun(@(d) d.sci1a.priority, det);
        end
    end
    [ues(u), step(u).delivered] = stack.rxSlot(ues(u), rxIq, n);
end
end
