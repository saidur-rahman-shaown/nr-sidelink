function [tx, pduBytes, pduLen] = amTxBuild(tx, grantBytes, nowMs)
%amTxBuild Fill a transmission opportunity with AMD PDUs: retransmissions first, then new data.
%Spec:   TS 38.322 V16.3.0,
%        clause 5.2.3.1.1: "shall prioritize transmission of AMD PDUs containing previously
%          transmitted RLC SDUs or RLC SDU segments over transmission of AMD PDUs containing not
%          previously transmitted ..."; "shall not submit to lower layer any AMD PDU whose SN
%          falls outside of the transmitting window"; "When submitting an AMD PDU that contains a
%          segment of an RLC SDU ... set the SN of the AMD PDU to the SN of the corresponding
%          RLC SDU."
%        clause 4.2.1.3.2 / 5.3.2: segment or re-segment so the PDU fits; "the number of
%          re-segmentation is not limited"; "only map the original RLC SDU or RLC SDU segment to
%          the Data field of the new AMD PDU".
%        clause 5.3.3.2: PDU_WITHOUT_POLL / BYTE_WITHOUT_POLL counting and the four poll
%          conditions; "To include a poll ... set the P field ... to 1; set PDU_WITHOUT_POLL to
%          0; set BYTE_WITHOUT_POLL to 0"; "Upon submission of an AMD PDU including a poll ...
%          set POLL_SN to the highest SN of the AMD PDU among the AMD PDUs submitted to lower
%          layer; if t-PollRetransmit is not running: start t-PollRetransmit. else: restart".
%        clause 5.3.3.4: after t-PollRetransmit expiry, "include a poll in an AMD PDU".
%Inputs: tx          entity from amTxInit
%        grantBytes  integer, >=0 -- bytes of RLC PDU(s) this opportunity can carry for the
%                    DATA PDUs (amTxOpportunity has already taken any STATUS PDU out of it)
%        nowMs       real, ms -- used to start/restart t-PollRetransmit
%Outputs: tx        updated entity
%         pduBytes  1 x sum(pduLen) octets -- AMD PDUs in submission order, concatenated
%         pduLen    1 x nPdu integer
%
%POLL COUNTERS COUNT NEW DATA ONLY
%---------------------------------
%Clause 5.3.3.2's first block runs "for each AMD PDU ... such that the AMD PDU contains either a
%not previously transmitted RLC SDU or an RLC SDU segment containing not previously transmitted
%byte segment". A retransmission advances neither counter. Counting retransmissions makes a
%lossy link poll MORE often the more it loses, and every extra poll is another STATUS PDU on the
%reverse link competing with that peer's own data.
%
%The second block (buffers empty, window stalled) applies to EVERY AMD PDU, retransmissions
%included -- the last PDU of a burst of retransmissions must carry a poll, or nothing ever asks
%the receiver whether they arrived.

snLen = tx.cfg.snFieldLength;
W = tx.cfg.AM_Window_Size;
if ~(grantBytes >= 0 && mod(grantBytes, 1) == 0)
    error('rlc:amTxBuild:badGrant', 'amTxBuild: grantBytes must be a non-negative integer');
end

pduBytes = zeros(1, 0);
pduLen = zeros(1, 0);
remaining = grantBytes;

while true
    if ~isempty(tx.retxSn)
        % ---- retransmission: lowest SN (from TX_Next_Ack), then lowest offset ----------
        r = 1;
        for q = 2:numel(tx.retxSn)
            dq = rlc.snDiff(tx.retxSn(q), tx.TX_Next_Ack, snLen);
            dr = rlc.snDiff(tx.retxSn(r), tx.TX_Next_Ack, snLen);
            if dq < dr || (dq == dr && tx.retxSo(q) < tx.retxSo(r))
                r = q;
            end
        end
        sn = tx.retxSn(r);
        k = find(tx.sduSn == sn, 1);
        so = tx.retxSo(r);
        hdr = rlc.amdHeaderBytes(so > 0, snLen);
        if remaining < hdr + 1
            break;      % strict priority: new data never overtakes a pending retransmission
        end
        n = min(tx.retxEnd(r) - so + 1, remaining - hdr);
        tx.retxSo(r) = so + n;
        if tx.retxSo(r) > tx.retxEnd(r)
            tx.retxSn(r) = []; tx.retxSo(r) = []; tx.retxEnd(r) = [];
        end
        isNew = false;
    else
        % ---- new data -------------------------------------------------------------------
        [~, stalled, k] = txBufferState(tx);
        if k == 0 || stalled
            break;
        end
        sn = tx.sduSn(k);
        so = tx.sduSent(k);
        hdr = rlc.amdHeaderBytes(so > 0, snLen);
        if remaining < hdr + 1
            break;
        end
        n = min(tx.sduLen(k) - so, remaining - hdr);
        tx.sduSent(k) = so + n;
        isNew = true;
    end

    L = tx.sduLen(k);
    start = 1 + sum(tx.sduLen(1:k - 1));
    data = tx.buf(start + so : start + so + n - 1);
    si = rlc.siValue(so == 0, so + n == L);

    % ---- clause 5.3.3.2 ---------------------------------------------------------------
    poll = false;
    if isNew
        tx.PDU_WITHOUT_POLL = tx.PDU_WITHOUT_POLL + 1;
        tx.BYTE_WITHOUT_POLL = tx.BYTE_WITHOUT_POLL + n;
        if tx.PDU_WITHOUT_POLL >= tx.cfg.pollPDU || tx.BYTE_WITHOUT_POLL >= tx.cfg.pollByte
            poll = true;
        end
        [anySub, highest] = txSubmitted(tx);
        if ~anySub || rlc.snDiff(sn, tx.TX_Next_Ack, snLen) > rlc.snDiff(highest, tx.TX_Next_Ack, snLen)
            tx.highestSubmittedSn = sn;
        end
    end
    [bothEmpty, stalled] = txBufferState(tx);
    if bothEmpty || stalled
        poll = true;
    end
    if tx.pollPending
        poll = true;                    % clause 5.3.3.4, owed since t-PollRetransmit expired
        tx.pollPending = false;
    end
    if poll
        tx.PDU_WITHOUT_POLL = 0;
        tx.BYTE_WITHOUT_POLL = 0;
        tx.POLL_SN = tx.highestSubmittedSn;
        tx.tPollRetransmitExpiry = nowMs + tx.cfg.t_PollRetransmit;   % start, or restart
    end

    assert(rlc.snDiff(sn, tx.TX_Next_Ack, snLen) < W, 'rlc:amTxBuild:outsideWindow', ...
        'amTxBuild: SN %d is outside the transmitting window', sn);
    pdu = rlc.amdPduPack(poll, si, sn, so, data, snLen);
    pduBytes = [pduBytes, pdu];         %#ok<AGROW>
    pduLen(end + 1) = numel(pdu);       %#ok<AGROW>
    remaining = remaining - numel(pdu);
end
end
