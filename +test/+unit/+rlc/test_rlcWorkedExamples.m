function test_rlcWorkedExamples()
%test_rlcWorkedExamples Level-2 worked examples for the UM and AM state machines.
%SPEC: TS 38.322 V16.3.0 clauses 5.2.2.2 (UM receive), 5.2.3.2 + 5.3.4 (AM receive and STATUS
%      construction), 5.2.3.1.1 + 5.3.2 + 5.3.3 (AM transmit, ARQ, polling).
%
%Every expected value here was computed by the independent-verifier subagent from the spec text
%alone, never having seen +rlc/ (+test/CLAUDE.md level 2). All three traces matched the
%implementation on the first run, with one exception that is a UE choice rather than a
%disagreement -- the t=66 case below, marked pending-human.
%
%The (PDU formats) level-2 vectors live in test_rlcFormats.

hex = @(s) hex2dec(strsplit(s, ' '))';

%% ==== 1. AM receive: STATUS PDU for a stated loss pattern (12-bit SN) ==========
% t-Reassembly 20 ms, t-StatusProhibit 0. SDU 1 = 30 bytes with 10..19 lost; SDU 2 lost; SDU 4
% tail lost (length unknown); SDUs 5, 6 lost; SDU 7 bytes 5..9 only; SDU 8 complete with P = 1.
cfg = rlc.amConfig(struct('sl_SN_FieldLengthAM_r16', 'size12', 'sl_T_PollRetransmit_r16', 'ms45', ...
    'sl_PollPDU_r16', 'p4', 'sl_PollByte_r16', 'kB25', 'sl_MaxRetxThreshold_r16', 't2'), 'ms20', 'ms0');
rx = rlc.amRxInit(cfg);
pdus = {rlc.amdPduPack(0, 0, 0, 0, 1:10, 12), rlc.amdPduPack(0, 1, 1, 0, 1:10, 12), ...
        rlc.amdPduPack(0, 2, 1, 20, 21:30, 12), rlc.amdPduPack(0, 0, 3, 0, 1:5, 12), ...
        rlc.amdPduPack(0, 1, 4, 0, 1:8, 12), rlc.amdPduPack(0, 3, 7, 5, 1:5, 12), ...
        rlc.amdPduPack(1, 0, 8, 0, 1:6, 12)};
%            RX_Next RX_Next_Highest RX_Highest_Status RX_Next_Status_Trigger deadline delivered
expect = [   1 1 1 0 -1 10;
             1 2 1 0 -1  0;
             1 2 1 2 22  0;
             1 4 1 2 22  5;
             1 5 1 2 22  0;
             1 8 1 2 22  0;
             1 9 1 2 22  6];
reports = zeros(1, 0);
for t = 0:60
    rx = rlc.amRxTimer(rx, t);
    if t <= 6
        [rx, ~, sl] = rlc.amRxPdu(rx, pdus{t + 1}, t);
        got = [rx.RX_Next rx.RX_Next_Highest rx.RX_Highest_Status rx.RX_Next_Status_Trigger ...
               rx.tReassemblyExpiry sum(sl)];
        assert(isequal(got, expect(t + 1, :)), 'AM rx state after the PDU at t=%d: got %s', t, mat2str(got));
    end
    if t == 6
        assert(isequal(rx.pollDelayedSn, 8) && ~rx.statusTriggered, ...
            'the poll on SN 8 is DELAYED: 8 < RX_Highest_Status (1) fails and 8 < RX_Next + 2048');
    end
    rxBefore = rx;
    [rx, pdu] = rlc.amRxStatusBuild(rx, Inf, t);
    if ~isempty(pdu)
        reports(end + 1) = t; %#ok<AGROW>
        if t == 22
            assert(isequal(pdu, hex('00 02 80 00 14 00 0A 00 13')), 'first STATUS: ACK_SN 2, NACK SN 1 SO 10..19');
            assert(rx.RX_Highest_Status == 2 && rx.tReassemblyExpiry == 42 && rx.RX_Next_Status_Trigger == 9, ...
                't-Reassembly restarts at the expiry instant + 20 with RX_Next_Status_Trigger = 9');
        elseif t == 42
            assert(isequal(pdu, hex(['00 09 80 00 1C 00 0A 00 13 00 28 00 4C 00 08 FF FF 00 5A 02 ' ...
                '00 7C 00 00 00 04 00 74 00 0A FF FF'])), 'second STATUS: the full 32-byte loss map');
            assert(rx.tReassemblyExpiry < 0 && isempty(rx.pollDelayedSn), ...
                'no restart at t=42, and the delayed poll is released (8 < RX_Highest_Status = 9)');
            [~, p10] = rlc.amRxStatusBuild(rxBefore, 10, t);
            assert(isequal(p10, hex('00 02 80 00 14 00 0A 00 13')), ...
                'a 10-byte grant stops before SN 2 and sets ACK_SN = 2');
        end
    end
end
assert(isequal(reports, [22 42]), 'exactly two STATUS PDUs, at t=22 and t=42; got %s', mat2str(reports));

%% ==== 2. UM receive, sidelink groupcast (6-bit SN, t-Reassembly 10 ms) =========
cu = rlc.umConfig(struct('sl_SN_FieldLengthUM_r16', 'size6'), 'ms10');
rx = rlc.umRxInit(cu, true);
ev = {0,  rlc.umdPduPack(1, 40, 0, 1:10, 6),  [40 41  0 -1 0]; ...
      1,  rlc.umdPduPack(2, 40, 10, 1:5, 6),  [41 41  0 -1 15]; ...
      2,  rlc.umdPduPack(1, 41, 0, 1:10, 6),  [41 42  0 -1 0]; ...
      3,  rlc.umdPduPack(1, 42, 0, 1:10, 6),  [41 43 43 13 0]; ...
      4,  rlc.umdPduPack(2, 42, 10, 1:3, 6),  [41 43 43 13 13]; ...
      5,  rlc.umdPduPack(0, 0, 0, 1:4, 6),    [41 43 43 13 4]; ...
      30, rlc.umdPduPack(1, 20, 0, 1:7, 6),   [43 43 43 -1 0]; ...
      31, rlc.umdPduPack(2, 43, 10, 1:2, 6),  [43 44 44 41 0]; ...
      32, rlc.umdPduPack(1, 21, 0, 1:5, 6),   [43 44 44 41 0]; ...
      33, rlc.umdPduPack(2, 20, 7, 1:3, 6),   [43 44 44 41 0]};
%   RX_Next_Reassembly RX_Next_Highest RX_Timer_Trigger deadline delivered-bytes
e = 1;
for t = 0:60
    [rx, expired] = rlc.umRxTimer(rx, t);
    if t == 13
        assert(expired && rx.RX_Next_Reassembly == 43 && rx.nSnAbandoned == 1 && rx.tReassemblyExpiry < 0, ...
            't=13 expiry: RX_Next_Reassembly -> 43, the SN 41 first segment discarded, no restart');
    elseif t == 41
        assert(expired && rx.RX_Next_Reassembly == 44 && rx.nSnAbandoned == 2 && rx.tReassemblyExpiry < 0, ...
            't=41 expiry: the SN 43 last segment discarded');
    else
        assert(~expired, 'no t-Reassembly expiry at t=%d', t);
    end
    while e <= size(ev, 1) && ev{e, 1} == t
        [rx, ~, sl] = rlc.umRxPdu(rx, ev{e, 2}, t);
        got = [rx.RX_Next_Reassembly rx.RX_Next_Highest rx.RX_Timer_Trigger rx.tReassemblyExpiry sum(sl)];
        want = ev{e, 3};
        if want(4) < 0, got(3) = want(3); end          % RX_Timer_Trigger is stale/unused while stopped
        assert(isequal(got, want), 'UM rx at t=%d: got %s, want %s', t, mat2str(got), mat2str(want));
        e = e + 1;
    end
end
assert(rx.nPduDiscarded == 3, ['SN 20 (twice) and SN 21 lie in [RX_Next_Highest - 32, ' ...
    'RX_Next_Reassembly) and are discarded -- surprising, and derived by both']);

%% ==== 3. AM transmit: ARQ, polling and RETX_COUNT (12-bit, pollPDU 4, maxRetx 2) ====
tx = rlc.amTxInit(cfg);
for k = 11:15, tx = rlc.amTxEnqueue(tx, mod(1:100, 256), k); end
%            SN SI SO len P
[tx, h] = build(tx, 250, 0);
assert(isequal(h, [0 0 0 100 0; 1 0 0 100 0; 2 1 0 44 0]), 't=0 build');
assert(tx.PDU_WITHOUT_POLL == 3 && tx.BYTE_WITHOUT_POLL == 244 && tx.tPollRetransmitExpiry < 0, 't=0 counters');
[tx, h] = build(tx, 250, 1);
assert(isequal(h, [2 2 44 56 1; 3 0 0 100 0; 4 1 0 86 0]), 't=1 build: pollPDU fires on the 4th new PDU');
assert(tx.POLL_SN == 2 && tx.PDU_WITHOUT_POLL == 2 && tx.BYTE_WITHOUT_POLL == 186 && tx.tPollRetransmitExpiry == 46, 't=1 state');
[tx, h] = build(tx, 250, 2);
assert(isequal(h, [4 2 86 14 1]) && tx.POLL_SN == 4 && tx.tPollRetransmitExpiry == 47, 't=2: buffer-empty poll, timer restarted');

[tx, acked] = rlc.amTxOnStatus(tx, 5, [1 3], [-1 50], [-1 65535], [0 0]);
assert(isequal(acked, [11 13 15]) && tx.TX_Next_Ack == 1 && tx.tPollRetransmitExpiry < 0, 't=10 STATUS: ACKs, POLL_SN covered');
assert(isequal(tx.RETX_COUNT, [0 0]) && isequal(tx.retxSo, [0 50]) && isequal(tx.retxEnd, [99 99]), 't=10 retransmission buffer');
[tx, h] = build(tx, 60, 11);
assert(isequal(h, [1 1 0 58 0]), 't=11: re-segmented retransmission, not counted toward polling');
[tx, h] = build(tx, 200, 12);
assert(isequal(h, [1 2 58 42 0; 3 2 50 50 1]) && tx.tPollRetransmitExpiry == 57, 't=12');

[tx, acked] = rlc.amTxOnStatus(tx, 5, [1 1], [0 40], [29 65535], [0 0]);
assert(isequal(acked, 14) && tx.RETX_COUNT == 1 && tx.tPollRetransmitExpiry < 0, ...
    't=20: two NACK sets of SN 1 in one STATUS PDU increment RETX_COUNT once');
[tx, h] = build(tx, 500, 21);
assert(isequal(h, [1 1 0 30 0; 1 2 40 60 1]) && tx.tPollRetransmitExpiry == 66, 't=21');

% t=66: pending-human. Clause 5.3.3.4 offers "the RLC SDU with the highest SN among the RLC SDUs
% submitted" OR "any RLC SDU which has not been positively acknowledged". The highest submitted,
% SN 4, was acknowledged at t=10; the verifier's literal reading re-sends it and later declares
% max-retx against an SDU the peer HAS. This implementation takes the second option (the
% verifier's "Alternative A") once the highest has been acknowledged: SN 1, tag 12.
ind = zeros(0, 2);
for t = 22:200
    [tx, ex, m] = rlc.amTxTimer(tx, t);
    if ~isempty(m), ind(end + 1, :) = [t m]; end %#ok<AGROW>
    if ex
        [tx, h] = build(tx, 500, t);
        assert(isequal(h, [1 0 0 100 1]), 'expiry at t=%d re-sends SN 1 whole, with a poll', t);
    end
end
assert(isequal(ind, [66 12]), 'max retransmission for tag 12 at t=66, once; got %s', mat2str(ind));
assert(tx.RETX_COUNT == 4 && tx.tPollRetransmitExpiry == 201, 'expiries at 66, 111, 156');
end

function [tx, h] = build(tx, g, t)
[tx, pb, pl] = rlc.amTxBuild(tx, g, t);
h = zeros(numel(pl), 5);
off = 0;
for k = 1:numel(pl)
    [~, p, si, sn, so, d] = rlc.amdPduParse(pb(off + 1 : off + pl(k)), tx.cfg.snFieldLength);
    h(k, :) = [sn si so numel(d) p];
    off = off + pl(k);
end
end
