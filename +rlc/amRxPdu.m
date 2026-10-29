function [rx, sduBytes, sduLen] = amRxPdu(rx, pdu, nowMs)
%amRxPdu Receive one AMD PDU from lower layer on the receiving side of an AM entity.
%Spec:   TS 38.322 V16.3.0,
%        clause 5.2.3.2.1: the receiving window, "RX_Next <= SN < RX_Next + AM_Window_Size".
%        clause 5.2.3.2.2: "if x falls outside of the receiving window; or if byte segment
%          numbers y to z of the RLC SDU with SN = x have been received before: discard the
%          received AMD PDU. else: place the received AMD PDU in the reception buffer; if some
%          byte segments ... have been received before: discard the duplicate byte segments."
%        clause 5.2.3.2.3: RX_Next_Highest / RX_Highest_Status / RX_Next updates, delivery, and
%          the t-Reassembly stop and start conditions.
%        clause 5.3.4: the poll-triggered STATUS report, including its delay rule.
%        clause 7.1: modulus base RX_Next. clause 5.6.1: invalid PDUs are discarded.
%Inputs: rx     entity from amRxInit
%        pdu    1 x n octets -- one AMD PDU (D/C = 1). A control PDU belongs to the
%               transmitting side; rlc.amReceive routes by D/C
%        nowMs  real, ms -- to set t-Reassembly's deadline
%Outputs: rx        updated entity
%         sduBytes  1 x sum(sduLen) octets -- SDUs delivered, concatenated (zero or one)
%         sduLen    1 x nSdu integer
%
%Call rlc.amRxTimer at the same instant too; this function never expires a timer.
%
%A POLL ON A DISCARDED PDU STILL TRIGGERS A REPORT
%-------------------------------------------------
%"if the AMD PDU is to be discarded as specified in clause 5.2.3.2.2 ...: trigger a STATUS
%report." The typical discarded-with-poll PDU is a retransmission of something the receiver
%already has -- sent because the transmitter never saw the STATUS acknowledging it. Ignoring
%the poll because the data was a duplicate leaves the transmitter still not knowing, so it
%retransmits again, forever, while RETX_COUNT climbs toward a false radio link failure.

snLen = rx.cfg.snFieldLength;
W = rx.cfg.AM_Window_Size;
M = 2^snLen;
SI_COMPLETE = rlc.siValue(true, true);
SI_LAST = rlc.siValue(false, true);

sduBytes = zeros(1, 0);
sduLen = zeros(1, 0);

[valid, p, si, x, so, data] = rlc.amdPduParse(pdu, snLen);
if ~valid
    rx.nPduDiscarded = rx.nPduDiscarded + 1;
    return;
end
y = so;
z = so + numel(data) - 1;

% ---- clause 5.2.3.2.2 --------------------------------------------------------
discard = rlc.snDiff(x, rx.RX_Next, snLen) >= W ...
    || any(rx.doneSn == x) ...
    || rlc.rxBufCovered(rx.buf, x, y, z);
if discard
    rx.nPduDiscarded = rx.nPduDiscarded + 1;
    if p
        rx.statusTriggered = true;
    end
    return;
end
rx.buf = rlc.rxBufInsert(rx.buf, x, so, data, si == SI_COMPLETE || si == SI_LAST);

% ---- clause 5.2.3.2.3 --------------------------------------------------------
if rlc.snDiff(x, rx.RX_Next, snLen) >= rlc.snDiff(rx.RX_Next_Highest, rx.RX_Next, snLen)
    rx.RX_Next_Highest = mod(x + 1, M);           % "if x >= RX_Next_Highest"
end
if rlc.rxBufComplete(rx.buf, x)
    sdu = rlc.rxBufAssemble(rx.buf, x);
    sduBytes = sdu;
    sduLen = numel(sdu);
    rx.buf = rlc.rxBufDrop(rx.buf, x);
    rx.doneSn(end + 1) = x;
    if x == rx.RX_Highest_Status
        % "update RX_Highest_Status to the SN of the first RLC SDU with SN > current
        % RX_Highest_Status for which not all bytes have been received."
        rx.RX_Highest_Status = firstIncomplete(rx.doneSn, mod(rx.RX_Highest_Status + 1, M), M);
    end
    if x == rx.RX_Next
        rx.RX_Next = firstIncomplete(rx.doneSn, mod(rx.RX_Next + 1, M), M);
    end
end

dNext1 = rlc.snDiff(rx.RX_Next + 1, rx.RX_Next, snLen);     % = 1, written as the clause writes it
if rx.tReassemblyExpiry >= 0
    trig = rx.RX_Next_Status_Trigger;
    stopNow = trig == rx.RX_Next ...
        || (trig == mod(rx.RX_Next + 1, M) && ~rlc.rxBufMissingBeforeLast(rx.buf, rx.RX_Next)) ...
        || (rlc.snDiff(trig, rx.RX_Next, snLen) >= W && trig ~= mod(rx.RX_Next + W, M));
    if stopNow
        rx.tReassemblyExpiry = -1;
    end
end
if rx.tReassemblyExpiry < 0
    dRnh = rlc.snDiff(rx.RX_Next_Highest, rx.RX_Next, snLen);
    if dRnh > dNext1 || (dRnh == dNext1 && rlc.rxBufMissingBeforeLast(rx.buf, rx.RX_Next))
        rx.tReassemblyExpiry = nowMs + rx.cfg.t_Reassembly;
        rx.RX_Next_Status_Trigger = rx.RX_Next_Highest;
    end
end

% ---- clause 5.3.4, poll ------------------------------------------------------
if p
    rx.pollDelayedSn(end + 1) = x;      % released at once below if its condition holds
end
rx = amRxPollRecheck(rx);

% Keep doneSn to [RX_Next, RX_Next_Highest): below RX_Next it is implied, and a stale entry
% would alias the same SN one wrap later.
dDone = rlc.snDiff(rx.doneSn, rx.RX_Next, snLen);
rx.doneSn = rx.doneSn(dDone < rlc.snDiff(rx.RX_Next_Highest, rx.RX_Next, snLen));
end

function s = firstIncomplete(doneSn, start, M)
s = start;
while any(doneSn == s)
    s = mod(s + 1, M);
end
end
