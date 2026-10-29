function test_rlcAm()
%test_rlcAm AM data transfer: ARQ, polling, status reporting, window, discard, max-retx.
%SPEC: TS 38.322 V16.3.0 clauses 5.2.3, 5.3.2, 5.3.3, 5.3.4, 5.4, 5.5, 6.2.3.10, 7.1-7.4.
%
%Level 1 (+test/CLAUDE.md): two AM entities talking to each other prove self-consistency only.
%The receive-side STATUS construction and the transmit-side ARQ trace are checked against
%independent-verifier worked examples in test_rlcWorkedExamples.

base = struct('sl_SN_FieldLengthAM_r16', 'size12', 'sl_T_PollRetransmit_r16', 'ms45', ...
    'sl_PollPDU_r16', 'p4', 'sl_PollByte_r16', 'kB25', 'sl_MaxRetxThreshold_r16', 't4');
cfg12 = rlc.amConfig(base, 'ms20', 'ms10');
b18 = base; b18.sl_SN_FieldLengthAM_r16 = 'size18';
cfg18 = rlc.amConfig(b18, 'ms20', 'ms10');

%% ---- clean link, both SN lengths: everything delivered once, everything acked ----
for cfg = [cfg12 cfg18]
    r = amLink(cfg, 300, @(t, dir, k) false, 1);
    assert(r.allDelivered && r.allAcked && r.nDup == 0, 'clean link, %d-bit SN', cfg.snFieldLength);
end

%% ---- lossy link in BOTH directions: ARQ recovers everything, exactly once --------
for seed = 1:3
    rng(seed);
    r = amLink(cfg12, 200, @(t, dir, k) rand < 0.15, seed);
    assert(r.allDelivered && r.nDup == 0, 'seed %d: every SDU delivered exactly once despite 15%% loss', seed);
    assert(r.allAcked && isempty(r.maxRetx), 'seed %d: every SDU acknowledged, no max-retx', seed);
end

%% ---- SN wrap: more SDUs than the 12-bit SN space --------------------------------
r = amLink(cfg12, 5000, @(t, dir, k) mod(t * 7 + k, 97) == 0, 9, 40);
assert(r.allDelivered && r.allAcked && r.nDup == 0, '5000 SDUs through a 4096-SN space with periodic loss');

%% ---- polling, clause 5.3.3.2 ------------------------------------------------------
tx = rlc.amTxInit(cfg12);
for k = 1:6, tx = rlc.amTxEnqueue(tx, 1:10, k); end
[tx, pb, pl] = rlc.amTxBuild(tx, 12 * 6, 0);
p = pollBits(pb, pl, 12);
assert(isequal(p, [0 0 0 1 0 1]), 'pollPDU = 4 polls the 4th PDU; the last PDU polls because the buffer empties');
assert(tx.POLL_SN == 5 && tx.tPollRetransmitExpiry == 45, 'POLL_SN = highest submitted; t-PollRetransmit started');
tx = rlc.amTxOnStatus(tx, 6, [1 2 3], [-1 -1 -1], [-1 -1 -1], [0 0 0]);
assert(tx.tPollRetransmitExpiry < 0, 'a STATUS covering POLL_SN stops t-PollRetransmit');
% Retransmissions do not advance PDU_WITHOUT_POLL.
tx = rlc.amTxEnqueue(tx, 1:10, 7);
[tx, pb, pl] = rlc.amTxBuild(tx, 12 * 3, 1);     % three retransmissions; the new SDU does not fit
assert(isequal(pollBits(pb, pl, 12), [0 0 0]) && tx.PDU_WITHOUT_POLL == 0, ...
    'retransmissions are not counted toward pollPDU');
[tx, pb, pl] = rlc.amTxBuild(tx, 12, 2);
assert(isequal(pollBits(pb, pl, 12), 1) && tx.POLL_SN == 6, 'the PDU that empties both buffers carries a poll');
% pollByte.
bb = base; bb.sl_PollPDU_r16 = 'pInfinity';
tx = rlc.amTxInit(rlc.amConfig(bb, 'ms20', 'ms10'));
for k = 1:30, tx = rlc.amTxEnqueue(tx, zeros(1, 1000), k); end
[~, pb, pl] = rlc.amTxBuild(tx, 1002 * 30, 0);
assert(isequal(find(pollBits(pb, pl, 12)), [25 30]), ...
    'pollByte 25000 polls on the 25th 1000-byte PDU, then on the buffer-empty one');

%% ---- clause 5.3.2: RETX_COUNT once per SDU per STATUS PDU ------------------------
tx = rlc.amTxInit(cfg12);
tx = rlc.amTxEnqueue(tx, 1:100, 1);
tx = rlc.amTxEnqueue(tx, 1:100, 2);
tx = rlc.amTxBuild(tx, 1000, 0);
tx = rlc.amTxOnStatus(tx, 1, [0 0], [0 50], [9 59], [0 0]);
assert(tx.RETX_COUNT(1) == 0 && tx.RETX_COUNT(2) == -1, 'first consideration sets RETX_COUNT to 0; SN 1 untouched');
assert(isequal(tx.retxSo, [0 50]) && isequal(tx.retxEnd, [9 59]), 'two pending byte ranges');
tx = rlc.amTxBuild(tx, 1000, 1);
tx = rlc.amTxOnStatus(tx, 1, [0 0 0], [0 20 50], [9 29 59], [0 0 0]);
assert(tx.RETX_COUNT(1) == 1, 'three NACK sets for one SDU in one STATUS PDU increment ONCE, got %d', tx.RETX_COUNT(1));
tx = rlc.amTxOnStatus(tx, 1, 0, 0, 9, 0);
assert(tx.RETX_COUNT(1) == 1, 'a NACK for bytes already pending retransmission does not increment');
[tx, acked] = rlc.amTxOnStatus(tx, 2, [], [], [], []);
assert(isequal(acked, [1 2]) && tx.TX_Next_Ack == 2 && isempty(tx.retxSn), ...
    'ACK clears both SDUs and the pending ranges with them');

%% ---- invalid STATUS PDUs are discarded whole (clause 5.6.1) -----------------------
tx = rlc.amTxInit(cfg12);
for k = 1:3, tx = rlc.amTxEnqueue(tx, 1:10, k); end
tx = rlc.amTxBuild(tx, 24, 0);                       % SNs 0 and 1 submitted, SN 2 not
before = tx;
[tx, ~, ~, v] = rlc.amTxOnStatus(tx, 3, [], [], [], []);
assert(~v && isequal(tx, before), 'ACK_SN beyond highest submitted + 1 must not acknowledge SN 2');
[tx, ~, ~, v] = rlc.amTxOnStatus(tx, 1, 1, -1, -1, 0);
assert(~v && isequal(tx, before), 'a NACK at ACK_SN is invalid');
[~, acked, ~, v] = rlc.amTxOnStatus(tx, 2, 1, 5, 3, 0);
assert(~v && isempty(acked), 'SOend before SOstart is invalid');

%% ---- max retransmission on a dead link (clause 5.3.3.4 -> 5.3.2) ----------------
tx = rlc.amTxInit(cfg12);                            % maxRetxThreshold t4
tx = rlc.amTxEnqueue(tx, 1:50, 77);
tx = rlc.amTxBuild(tx, 100, 0);
reachedAt = -1; nIndications = 0;
for t = 1:1000
    [tx, ~, mr] = rlc.amTxTimer(tx, t);
    if ~isempty(mr)
        nIndications = nIndications + 1;
        if reachedAt < 0, reachedAt = t; assert(isequal(mr, 77), 'the tag of the failing SDU'); end
    end
    tx = rlc.amTxBuild(tx, 100, t);                  % the peer never answers
end
% Expiries at 45, 90, 135, 180, 225 take RETX_COUNT through 0,1,2,3,4.
assert(reachedAt == 225, 'max-retx must be indicated at the 5th t-PollRetransmit expiry (t=225), got %d', reachedAt);
assert(nIndications == 1, 'indicated once: later expiries push RETX_COUNT past the threshold, got %d', nIndications);

%% ---- transmitting window stall, clause 5.2.3.1.1 ---------------------------------
tx = rlc.amTxInit(cfg12);
W = cfg12.AM_Window_Size;
for k = 1:W + 10, tx = rlc.amTxEnqueue(tx, 1, k); end
[tx, pb, pl] = rlc.amTxBuild(tx, 4 * (W + 10), 0);
assert(numel(pl) == W, 'only AM_Window_Size SNs may be submitted before an acknowledgement, got %d', numel(pl));
p = pollBits(pb, pl, 12);
assert(p(end) == 1, 'the PDU after which the window stalls carries a poll');
dvol = rlc.amTxDataVolume(tx);
assert(dvol == 10, 'SDUs waiting outside the window still count as data volume');
tx = rlc.amTxOnStatus(tx, 100, [], [], [], []);
[~, ~, pl] = rlc.amTxBuild(tx, 1000, 1);
assert(numel(pl) == 10, 'the window opens once SNs are acknowledged');

%% ---- clause 5.4: discard closes the SN gap ----------------------------------------
tx = rlc.amTxInit(cfg12);
for k = 1:4, tx = rlc.amTxEnqueue(tx, 1:10, k); end
tx = rlc.amTxBuild(tx, 12, 0);                       % SN 0 submitted
[tx, d0] = rlc.amTxDiscard(tx, 1);
[tx, d2] = rlc.amTxDiscard(tx, 3);
assert(~d0 && d2, 'a submitted SDU cannot be discarded; an unsent one can');
assert(isequal(tx.sduSn, [0 1 2]) && isequal(tx.sduTag, [1 2 4]) && tx.TX_Next == 3, ...
    'the SDU after the discarded one takes its SN: no gap');

%% ---- receive side: duplicates and a poll on a duplicate ---------------------------
rx = rlc.amRxInit(cfg12);
pdu = rlc.amdPduPack(1, 0, 0, 0, 1:10, 12);
[rx, ~, l1] = rlc.amRxPdu(rx, pdu, 0);
rx = rlc.amRxStatusBuild(rx, 100, 0);                % answer the first poll
[rx, ~, l2] = rlc.amRxPdu(rx, pdu, 50);
assert(isequal(l1, 10) && isempty(l2) && rx.nPduDiscarded == 1, 'a duplicate is discarded, not re-delivered');
assert(rx.statusTriggered, 'a poll on a DISCARDED PDU still triggers a STATUS report (clause 5.3.4)');
% t-StatusProhibit: one report per prohibit period, however many triggers.
[rx, s1] = rlc.amRxStatusBuild(rx, 100, 50);
rx.statusTriggered = true;
[rx, s2] = rlc.amRxStatusBuild(rx, 100, 55);
rx = rlc.amRxTimer(rx, 60);
[~, s3] = rlc.amRxStatusBuild(rx, 100, 60);
assert(~isempty(s1) && isempty(s2) && ~isempty(s3), 't-StatusProhibit (10 ms) holds the second report until expiry');

%% ---- control PDUs are prioritised, and data volume includes the STATUS -----------
txA = rlc.amTxInit(cfg12); rxA = rlc.amRxInit(cfg12);
txA = rlc.amTxEnqueue(txA, 1:40, 1);
rxA = rlc.amRxPdu(rxA, rlc.amdPduPack(1, 0, 0, 0, 1:5, 12), 0);
[~, ~, sv] = rlc.amDataVolume(txA, rxA, 0);
assert(sv == 3, 'a triggered STATUS with nothing missing is 3 bytes of data volume');
[~, ~, pb, pl] = rlc.amTxOpportunity(txA, rxA, 20, 0);
assert(pl(1) == 3 && floor(pb(1) / 128) == 0 && sum(pl) <= 20, 'STATUS first, data after, within the grant');
end

% =====================================================================================
function r = amLink(cfg, nSdu, dropFn, seed, grantMax)
% Two AM entities, A sending nSdu SDUs to B; dropFn(t, dir, k) loses the k-th PDU of slot t
% in direction dir (1: A->B data, 2: B->A status).
if nargin < 5, grantMax = 300; end
rng(seed);
txA = rlc.amTxInit(cfg); rxA = rlc.amRxInit(cfg);
txB = rlc.amTxInit(cfg); rxB = rlc.amRxInit(cfg);
sent = cell(1, nSdu);
for k = 1:nSdu
    sent{k} = randi([0 255], 1, randi([1 200]));
end
MAX_QUEUED = 500;           % the upper layer offers SDUs gradually, as a real source would
nextSdu = 1;
got = cell(1, 0); acked = zeros(1, 0); maxRetx = zeros(1, 0);
for t = 1:40000
    while nextSdu <= nSdu && numel(txA.sduSn) < MAX_QUEUED
        txA = rlc.amTxEnqueue(txA, sent{nextSdu}, nextSdu);
        nextSdu = nextSdu + 1;
    end
    [txA, ~, m1] = rlc.amTxTimer(txA, t); rxA = rlc.amRxTimer(rxA, t);
    txB = rlc.amTxTimer(txB, t);          rxB = rlc.amRxTimer(rxB, t);
    maxRetx = [maxRetx m1]; %#ok<AGROW>
    [txA, rxA, pb, pl] = rlc.amTxOpportunity(txA, rxA, randi([8 grantMax]), t);
    off = 0;
    for k = 1:numel(pl)
        if ~dropFn(t, 1, k)
            [txB, rxB, sb] = rlc.amReceive(txB, rxB, pb(off + 1 : off + pl(k)), t);
            if ~isempty(sb), got{end + 1} = sb; end %#ok<AGROW>
        end
        off = off + pl(k);
    end
    [txB, rxB, pb, pl] = rlc.amTxOpportunity(txB, rxB, 50, t);
    off = 0;
    for k = 1:numel(pl)
        if ~dropFn(t, 2, k)
            [txA, rxA, ~, ~, a, m2] = rlc.amReceive(txA, rxA, pb(off + 1 : off + pl(k)), t);
            acked = [acked a]; maxRetx = [maxRetx m2]; %#ok<AGROW>
        end
        off = off + pl(k);
    end
    if numel(acked) == nSdu && nextSdu > nSdu && isempty(txA.sduSn), break; end
end
% AM delivers out of order (clause 4.2.1.3.3, "as soon as they are available"), so compare
% the delivered SDUs with the sent ones as multisets.
key = @(c) sort(cellfun(@(x) sprintf('%d,', x), c, 'UniformOutput', false));
r.allDelivered = isequal(key(got), key(sent));
r.nDup = numel(got) - numel(unique(key(got)));
r.allAcked = isequal(sort(acked), 1:nSdu);
r.maxRetx = maxRetx;
end

function p = pollBits(pb, pl, snLen)
p = zeros(1, numel(pl));
off = 0;
for k = 1:numel(pl)
    [v, pp] = rlc.amdPduParse(pb(off + 1 : off + pl(k)), snLen);
    assert(v, 'AMD PDU %d did not parse', k);
    p(k) = pp;
    off = off + pl(k);
end
end
