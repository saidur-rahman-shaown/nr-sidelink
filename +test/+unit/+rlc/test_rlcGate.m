function test_rlcGate()
%test_rlcGate The B9 RLC gate: AM recovers a lost segment while UM runs uninterrupted.
%SPEC: TS 38.322 V16.3.0 clauses 4.2.1 (entities per logical channel), 5.1.1 (a receiving UM
%      entity per Source/Destination Layer-2 ID pair and LCID), 5.2.2, 5.2.3, 5.3.
%
%+rlc/CLAUDE.md's gate: "AM recovers a lost segment via retransmission while a UM flow runs
%uninterrupted on the same UE." One UE runs a broadcast UM entity and a unicast AM entity on
%two logical channels, splitting each opportunity between them; one AM segment is lost.
%Level 1 only: both ends are this package.
%
%Not integrated with +mac/: the grant split below stands in for slLcp, deliberately.

cu = rlc.umConfig(struct('sl_SN_FieldLengthUM_r16', 'size6'), 'ms20');
ca = rlc.amConfig(struct('sl_SN_FieldLengthAM_r16', 'size12', 'sl_T_PollRetransmit_r16', 'ms45', ...
    'sl_PollPDU_r16', 'p4', 'sl_PollByte_r16', 'kB25', 'sl_MaxRetxThreshold_r16', 't4'), 'ms10', 'ms0');

% UE A: UM TX (broadcast STCH) + AM entity (unicast STCH). Peers: B receives the broadcast, C is
% the unicast peer.
umTx = rlc.umTxInit(cu);
amTxA = rlc.amTxInit(ca); amRxA = rlc.amRxInit(ca);
umRxB = rlc.umRxInit(cu, true);
amTxC = rlc.amTxInit(ca); amRxC = rlc.amRxInit(ca);

nUm = 100; nAm = 60;
umDeliverT = zeros(1, 0); amGot = zeros(1, 0); amAcked = zeros(1, 0);
lostSn = -1; lostAt = -1; recoveredAt = -1;
for t = 1:400
    if t <= nUm, umTx = rlc.umTxEnqueue(umTx, mod(t + (1:60), 256), t); end
    if t <= nAm, amTxA = rlc.amTxEnqueue(amTxA, mod(t * 3 + (1:90), 256), t); end

    [amTxA] = rlc.amTxTimer(amTxA, t); amRxA = rlc.amRxTimer(amRxA, t);
    amTxC = rlc.amTxTimer(amTxC, t);   amRxC = rlc.amRxTimer(amRxC, t);
    umRxB = rlc.umRxTimer(umRxB, t);

    % A's opportunity: 40 bytes to each channel -> both SDU streams need segmentation.
    [umTx, pb, pl] = rlc.umTxBuild(umTx, 40);
    off = 0;
    for k = 1:numel(pl)
        [umRxB, ~, sl] = rlc.umRxPdu(umRxB, pb(off + 1 : off + pl(k)), t);
        umDeliverT = [umDeliverT, t * ones(1, numel(sl))]; %#ok<AGROW>
        off = off + pl(k);
    end
    [amTxA, amRxA, pb, pl] = rlc.amTxOpportunity(amTxA, amRxA, 40, t);
    off = 0;
    for k = 1:numel(pl)
        pdu = pb(off + 1 : off + pl(k));
        off = off + pl(k);
        [v, ~, si, sn] = rlc.amdPduParse(pdu, 12);
        if lostSn < 0 && v && sn == 10 && si == rlc.siValue(false, false)
            lostSn = sn; lostAt = t;               % lose the middle segment of SN 10, once
            continue;
        end
        [amTxC, amRxC, sb] = rlc.amReceive(amTxC, amRxC, pdu, t);
        if ~isempty(sb)
            amGot(end + 1) = sb(1); %#ok<AGROW>
            if lostSn >= 0 && recoveredAt < 0 && sb(1) == mod(11 * 3 + 1, 256), recoveredAt = t; end
        end
    end
    % C's opportunity: its STATUS PDUs back to A.
    [amTxC, amRxC, pb, pl] = rlc.amTxOpportunity(amTxC, amRxC, 40, t);
    off = 0;
    for k = 1:numel(pl)
        [amTxA, amRxA, ~, ~, a] = rlc.amReceive(amTxA, amRxA, pb(off + 1 : off + pl(k)), t);
        amAcked = [amAcked a]; %#ok<AGROW>
        off = off + pl(k);
    end
end

assert(lostSn == 10, 'the loss was injected');
assert(isequal(sort(amAcked), 1:nAm) && numel(amGot) == nAm, 'AM delivered and acknowledged every SDU');
assert(recoveredAt > lostAt, 'SN 10 (tag 11) delivered only after the retransmission');
assert(numel(umDeliverT) == nUm && umRxB.nSnAbandoned == 0 && umRxB.nPduDiscarded == 0, ...
    'the UM flow delivered every SDU, none abandoned');
gaps = diff(umDeliverT);
assert(all(gaps <= 2), 'the UM flow never paused while AM was recovering (max gap %d slots)', max(gaps));

%% ---- trap: receiving entities are keyed per (Source, Destination, LCID) ------------
% Two broadcasters on the same LCID both start at SN 0. One receiving entity per source is
% clause 5.1.1; a single shared entity mixes their SN spaces and splices their SDUs.
txP = rlc.umTxInit(cu); txQ = rlc.umTxInit(cu);
rxP = rlc.umRxInit(cu, true); rxQ = rlc.umRxInit(cu, true); rxShared = rlc.umRxInit(cu, true);
txP = rlc.umTxEnqueue(txP, 1:20, 1);  txQ = rlc.umTxEnqueue(txQ, 101:120, 1);
[txP, p1] = rlc.umTxBuild(txP, 11);   [txQ, q1] = rlc.umTxBuild(txQ, 11);
[~, p2] = rlc.umTxBuild(txP, 100);    [~, q2] = rlc.umTxBuild(txQ, 100);
[rxP] = rlc.umRxPdu(rxP, p1, 0);      [rxQ] = rlc.umRxPdu(rxQ, q1, 0);
[~, sP] = rlc.umRxPdu(rxP, p2, 1);    [~, sQ] = rlc.umRxPdu(rxQ, q2, 1);
assert(isequal(sP, 1:20) && isequal(sQ, 101:120), 'per-source entities reassemble each SDU correctly');
rxShared = rlc.umRxPdu(rxShared, p1, 0);
[rxShared, s1] = rlc.umRxPdu(rxShared, q2, 1);   % Q's last segment lands on P's SN 0
assert(isequal(s1, [1:10 111:120]), 'a shared entity splices two peers'' SDUs -- the trap, demonstrated');
end
