function test_rlcUm()
%test_rlcUm UM data transfer: segmentation, reassembly, t-Reassembly, window, discard.
%SPEC: TS 38.322 V16.3.0 clauses 4.2.1.2, 5.2.2.1.1, 5.2.2.2.1-5.2.2.2.4, 5.4, 5.5, 7.1, 7.2.
%
%Level 1 (+test/CLAUDE.md): transmitter-into-receiver round trips prove self-consistency, never
%correctness -- a transmitter and receiver that misread the same clause the same way pass them.
%The state-variable trace of the UM receiver is checked against an independent-verifier worked
%example separately, in test_rlcWorkedExamples.

cfg6 = rlc.umConfig(struct('sl_SN_FieldLengthUM_r16', 'size6'), 'ms10');
cfg12 = rlc.umConfig(struct('sl_SN_FieldLengthUM_r16', 'size12'), 'ms10');

%% ---- segmentation over every grant boundary --------------------------------
% For each SDU size and every grant up to one past "fits whole", the PDUs must: never exceed
% the grant, be one complete PDU exactly when L + 1 <= grant, otherwise a first segment of
% (grant - hdrFirst) then SO-bearing segments of (grant - hdrSo), and reassemble exactly.
for cfg = [cfg6 cfg12]
    snLen = cfg.snFieldLength;
    hF = rlc.umdHeaderBytes(1, snLen);
    hS = rlc.umdHeaderBytes(2, snLen);
    for L = [1 2 3 7 40 300]
        sdu = mod(L * 31 + (1:L), 256);
        for g = 1:L + 2
            tx = rlc.umTxInit(cfg);
            rx = rlc.umRxInit(cfg, false);
            tx = rlc.umTxEnqueue(tx, sdu, 1);
            got = zeros(1, 0);
            nPdu = 0;
            for opp = 1:L + 5
                [tx, pb, pl] = rlc.umTxBuild(tx, g);
                assert(sum(pl) <= g, 'PDUs exceed the grant (L=%d g=%d)', L, g);
                [rx, got, nPdu] = feed(rx, pb, pl, got, nPdu, 0);
                if isempty(pl), break; end
            end
            if g >= L + 1
                assert(nPdu == 1 && isequal(got, sdu) && tx.TX_Next == 0, ...
                    'L=%d g=%d: a fitting SDU goes whole, and consumes no SN', L, g);
            elseif g < hF + 1
                assert(nPdu == 0 && isempty(tx.sduOffset) == false && tx.sduOffset(1) == 0, ...
                    'L=%d g=%d: no room for header + 1 byte must emit nothing, not an empty segment', L, g);
            elseif g < hS + 1
                % Room for a first segment but never for an SO-bearing one: exactly one PDU,
                % then the entity waits for a bigger grant rather than corrupting anything.
                assert(nPdu == 1 && isempty(got) && tx.sduOffset(1) == g - hF, 'L=%d g=%d: first segment only', L, g);
                [tx, pb, pl] = rlc.umTxBuild(tx, L + hS);
                [~, got] = feed(rx, pb, pl, got, 0, 0);
                assert(isequal(got, sdu), 'L=%d g=%d: completes on a larger grant', L, g);
            else
                expected = 1 + ceil((L - (g - hF)) / (g - hS));
                assert(nPdu == expected && isequal(got, sdu) && tx.TX_Next == 1, ...
                    'L=%d g=%d: %d segments expected, got %d', L, g, expected, nPdu);
            end
        end
    end
end

% Exactly two segments, and many, with the header fields checked.
tx = rlc.umTxInit(cfg6);
tx = rlc.umTxEnqueue(tx, 1:20, 7);
[tx, pb, pl, pt] = rlc.umTxBuild(tx, 11);       % first: 1-byte header + 10
[~, si1, sn1, so1, d1] = rlc.umdPduParse(pb, 6);
assert(pl == 11 && si1 == 1 && sn1 == 0 && so1 == 0 && isequal(d1, 1:10) && pt == 7, 'first of two');
[tx, pb] = rlc.umTxBuild(tx, 100);
[~, si2, sn2, so2, d2] = rlc.umdPduParse(pb, 6);
assert(si2 == 2 && sn2 == 0 && so2 == 10 && isequal(d2, 11:20) && tx.TX_Next == 1, 'last of two: same SN, SO 10');
tx = rlc.umTxEnqueue(tx, 1:100, 8);
[tx, ~, pl] = rlc.umTxBuild(tx, 13);            % first 12 bytes
sis = zeros(1, 0);
while ~isempty(tx.sduLen)
    [tx, pb, pl] = rlc.umTxBuild(tx, 13);
    [~, si] = rlc.umdPduParse(pb, 6);
    sis(end + 1) = si; %#ok<AGROW>
end
assert(all(sis(1:end - 1) == 3) && sis(end) == 2 && tx.TX_Next == 2, 'middles are SI 11, the last SI 10');

%% ---- SN is consumed only by segmented SDUs (clause 6.2.3.3) ---------------
tx = rlc.umTxInit(cfg6);
for k = 1:5, tx = rlc.umTxEnqueue(tx, 1:10, k); end
[tx, ~, pl] = rlc.umTxBuild(tx, 1000);
assert(numel(pl) == 5 && tx.TX_Next == 0, 'five whole SDUs consume no SN');

%% ---- long loss-free stream across many SN wraps ---------------------------
for cfg = [cfg6 cfg12]
    rng(1);
    tx = rlc.umTxInit(cfg);
    rx = rlc.umRxInit(cfg, true);
    nSdu = 400;
    sent = cell(1, nSdu);
    for k = 1:nSdu
        sent{k} = randi([0 255], 1, randi([1 120]));
        tx = rlc.umTxEnqueue(tx, sent{k}, k);
    end
    got = zeros(1, 0); gotLen = zeros(1, 0);
    t = 0;
    while ~isempty(tx.sduLen)
        t = t + 1;
        [tx, pb, pl] = rlc.umTxBuild(tx, randi([4 90]));
        [rx, gb, gl] = feedAll(rx, pb, pl, t);
        got = [got gb]; gotLen = [gotLen gl]; %#ok<AGROW>
    end
    assert(numel(gotLen) == nSdu && isequal(got, [sent{:}]), ...
        'every SDU delivered byte-exact across %d-bit SN wraps', cfg.snFieldLength);
    assert(rx.nPduDiscarded == 0 && rx.nSnAbandoned == 0 && rx.tReassemblyExpiry < 0, 'nothing lost on a clean link');
end

%% ---- a lost segment: t-Reassembly discards the partial, and UM does not stall ----
tx = rlc.umTxInit(cfg6);
rx = rlc.umRxInit(cfg6, true);
for k = 1:300, tx = rlc.umTxEnqueue(tx, mod(k + (1:30), 256), k); end
nDelivered = 0; t = 0; dropped = false; firstDelivAfterLoss = -1;
while ~isempty(tx.sduLen)
    t = t + 1;
    [rx] = rlc.umRxTimer(rx, t);
    [tx, pb, pl] = rlc.umTxBuild(tx, 13);        % 30-byte SDUs -> 3 segments each
    if ~dropped && t == 50
        dropped = true;                          % lose one middle/last segment
        continue;
    end
    [rx, ~, gl] = feedAll(rx, pb, pl, t);
    nDelivered = nDelivered + numel(gl);
    if dropped && firstDelivAfterLoss < 0 && ~isempty(gl), firstDelivAfterLoss = t; end
end
for t2 = t + 1:t + 20, rx = rlc.umRxTimer(rx, t2); end
assert(nDelivered == 299, 'exactly the one SDU with the lost segment is missing, got %d', nDelivered);
assert(rx.nSnAbandoned == 1, 't-Reassembly must abandon exactly the one partial SDU');
assert(firstDelivAfterLoss > 0 && firstDelivAfterLoss < 60, 'later SDUs are delivered as soon as complete (out of order)');
assert(rx.tReassemblyExpiry < 0 && isempty(rx.buf.sn), 'nothing left held once the stream ends');

%% ---- groupcast/broadcast: initialise from the first SN (clause 7.1) -------
tx = rlc.umTxInit(cfg6);
for k = 1:40                                     % the stream is already at SN 40 when rx joins
    tx = rlc.umTxEnqueue(tx, 1:20, k);
    [tx] = rlc.umTxBuild(tx, 11); [tx] = rlc.umTxBuild(tx, 100);
end
assert(tx.TX_Next == 40, 'setup');
joinGc = rlc.umRxInit(cfg6, true);
joinZero = rlc.umRxInit(cfg6, false);
nGc = 0; nZero = 0;
for k = 1:10
    tx = rlc.umTxEnqueue(tx, 1:20, 100 + k);
    [tx, p1] = rlc.umTxBuild(tx, 11);
    [tx, p2] = rlc.umTxBuild(tx, 100);
    [joinGc, ~, a] = rlc.umRxPdu(joinGc, p1, k); [joinGc, ~, b2] = rlc.umRxPdu(joinGc, p2, k);
    [joinZero, ~, c] = rlc.umRxPdu(joinZero, p1, k); [joinZero, ~, d] = rlc.umRxPdu(joinZero, p2, k);
    nGc = nGc + numel(a) + numel(b2); nZero = nZero + numel(c) + numel(d);
end
assert(nGc == 10, 'a groupcast receiver joining mid-stream delivers from its first PDU, got %d', nGc);
assert(nZero == 0, ['the same stream into a receiver initialised at 0 is discarded -- SN 40..49 sit in ' ...
    '[RX_Next_Highest - 32, RX_Next_Reassembly) -- which is why clause 7.1 has the sidelink rule']);

%% ---- window jump: an SN far ahead drags the window and abandons stale partials ----
rx = rlc.umRxInit(cfg6, false);
rx = rlc.umRxPdu(rx, rlc.umdPduPack(1, 0, 0, 1:5, 6), 0);        % SN 0 first segment
% With RX_Next_Highest = 1 the window is [33, 1): an SN in [33, 64) is BEHIND
% RX_Next_Reassembly and is discarded, not a jump forward. SN 40 must be dropped...
rx = rlc.umRxPdu(rx, rlc.umdPduPack(1, 40, 0, 1:5, 6), 1);
assert(rx.nPduDiscarded == 1 && rx.RX_Next_Highest == 1, 'SN 40 lies in [RX_Next_Highest - 32, RX_Next_Reassembly)');
% ...while SN 32, the furthest forward SN, moves the window to [1, 33).
rx = rlc.umRxPdu(rx, rlc.umdPduPack(1, 32, 0, 1:5, 6), 2);
assert(rx.RX_Next_Highest == 33 && rx.nSnAbandoned == 1 && ~any(rx.buf.sn == 0), 'SN 0 fell outside the window');
assert(rx.RX_Next_Reassembly == 1, 'RX_Next_Reassembly moved to the new lower edge, got %d', rx.RX_Next_Reassembly);

%% ---- clause 5.4 discard, and clause 5.5 data volume ------------------------
tx = rlc.umTxInit(cfg6);
tx = rlc.umTxEnqueue(tx, 1:50, 1);
tx = rlc.umTxEnqueue(tx, 1:30, 2);
[dv, hv] = rlc.umTxDataVolume(tx);
assert(dv == 80 && hv == 2, 'volume 80 data bytes, two 1-byte complete headers');
tx = rlc.umTxBuild(tx, 21);                      % 20 bytes of SDU 1 go
[tx, ok1] = rlc.umTxDiscard(tx, 1);
[tx, ok2] = rlc.umTxDiscard(tx, 2);
assert(~ok1 && ok2 && isequal(tx.sduTag, 1), 'a part-sent SDU is not discarded; an unsent one is');
[dv, hv] = rlc.umTxDataVolume(tx);
assert(dv == 30 && hv == 3, 'remaining 30 bytes need an SO-bearing (3-byte) header');
end

function [rx, got, nPdu] = feed(rx, pb, pl, got, nPdu, t)
off = 0;
for k = 1:numel(pl)
    [rx, sb] = rlc.umRxPdu(rx, pb(off + 1 : off + pl(k)), t);
    got = [got sb]; %#ok<AGROW>
    off = off + pl(k);
    nPdu = nPdu + 1;
end
end

function [rx, gb, gl] = feedAll(rx, pb, pl, t)
gb = zeros(1, 0); gl = zeros(1, 0);
off = 0;
for k = 1:numel(pl)
    [rx, sb, sl] = rlc.umRxPdu(rx, pb(off + 1 : off + pl(k)), t);
    gb = [gb sb]; gl = [gl sl]; %#ok<AGROW>
    off = off + pl(k);
end
end
