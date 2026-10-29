function [rx, sduBytes, sduLen] = umRxPdu(rx, pdu, nowMs)
%umRxPdu Receive one UMD PDU from lower layer: deliver, discard, or buffer and reassemble.
%Spec:   TS 38.322 V16.3.0, clause 5.2.2.2.1 (the reassembly window: "a SN falls within the
%        reassembly window if (RX_Next_Highest - UM_Window_Size) <= SN < RX_Next_Highest"),
%        clause 5.2.2.2.2 (actions on receipt), clause 5.2.2.2.3 (actions when placed in the
%        reception buffer, including starting and stopping t-Reassembly), clause 7.1 (modulus
%        base RX_Next_Highest - UM_Window_Size, and the sidelink groupcast/broadcast initial
%        values), clause 5.6.1 (invalid PDUs are discarded).
%Inputs: rx     entity from umRxInit
%        pdu    1 x n row vector of octets -- one UMD PDU as MAC demultiplexed it
%        nowMs  real, ms -- current time; used only to set t-Reassembly's deadline
%Outputs: rx        updated entity
%         sduBytes  1 x sum(sduLen) octets -- RLC SDUs delivered to upper layer by this PDU,
%                   concatenated. Usually zero or one SDU
%         sduLen    1 x nSdu integer
%
%Call rlc.umRxTimer for the same instant as well: this function starts and stops
%t-Reassembly but never expires it, because expiry is a time event, not a reception event.
%
%DELIVERY IS OUT OF ORDER, AND THAT IS THE SPEC
%-----------------------------------------------
%Clause 4.2.1.2.3: "reassemble RLC SDUs ... and deliver the RLC SDUs to upper layer as soon as
%they are available". NR RLC does no reordering in either mode -- that moved to PDCP. A
%complete SDU with SN 7 is delivered while SN 6 is still missing; RX_Next_Reassembly simply
%stays at 6. Holding 7 back would add a t-Reassembly of latency to every SDU behind a loss.
%
%Complete-SDU PDUs (SI = 00) bypass the window entirely -- they have no SN -- so at 6-bit SN
%a UM entity whose SDUs always fit a grant never touches any of the state below.

SI_COMPLETE = rlc.siValue(true, true);
SI_LAST = rlc.siValue(false, true);
snLen = rx.cfg.snFieldLength;
W = rx.cfg.UM_Window_Size;
M = 2^snLen;

sduBytes = zeros(1, 0);
sduLen = zeros(1, 0);

[valid, si, sn, so, data] = rlc.umdPduParse(pdu, snLen);
if ~valid
    rx.nPduDiscarded = rx.nPduDiscarded + 1;
    return;
end

% ---- clause 5.2.2.2.2 --------------------------------------------------------
if si == SI_COMPLETE
    % "if the UMD PDU header does not contain an SN: remove the RLC header and deliver the RLC
    % SDU to upper layer."
    sduBytes = data;
    sduLen = numel(data);
    return;
end
if ~rx.snInitialised
    % Clause 7.1, sidelink groupcast/broadcast: both initialised to the first SN seen.
    rx.RX_Next_Reassembly = sn;
    rx.RX_Next_Highest = sn;
    rx.snInitialised = true;
end
if rlc.snDiff(sn, rx.RX_Next_Highest - W, snLen) < rlc.snDiff(rx.RX_Next_Reassembly, rx.RX_Next_Highest - W, snLen)
    % "else if (RX_Next_Highest - UM_Window_Size) <= SN < RX_Next_Reassembly: discard"
    rx.nPduDiscarded = rx.nPduDiscarded + 1;
    return;
end
rx.buf = rlc.rxBufInsert(rx.buf, sn, so, data, si == SI_LAST);

% ---- clause 5.2.2.2.3, "When an UMD PDU with SN = x is placed in the reception buffer" ----
x = sn;
if rlc.rxBufComplete(rx.buf, x)
    sdu = rlc.rxBufAssemble(rx.buf, x);
    sduBytes = sdu;
    sduLen = numel(sdu);
    rx.buf = rlc.rxBufDrop(rx.buf, x);
    rx.doneSn(end + 1) = x;
    if x == rx.RX_Next_Reassembly
        % "update RX_Next_Reassembly to the SN of the first SN > current RX_Next_Reassembly
        % that has not been reassembled and delivered to upper layer."
        rx.RX_Next_Reassembly = firstNotDone(rx.doneSn, mod(rx.RX_Next_Reassembly + 1, M), M);
    end
elseif rlc.snDiff(x, rx.RX_Next_Highest - W, snLen) >= W
    % "else if x falls outside of the reassembly window: update RX_Next_Highest to x + 1"
    rx.RX_Next_Highest = mod(x + 1, M);
    % "discard any UMD PDUs with SN that falls outside of the reassembly window"
    held = rlc.rxBufSnList(rx.buf);
    for k = 1:numel(held)
        if rlc.snDiff(held(k), rx.RX_Next_Highest - W, snLen) >= W
            rx.buf = rlc.rxBufDrop(rx.buf, held(k));
            rx.nSnAbandoned = rx.nSnAbandoned + 1;
        end
    end
    rx.doneSn = rx.doneSn(rlc.snDiff(rx.doneSn, rx.RX_Next_Highest - W, snLen) < W);
    % "if RX_Next_Reassembly falls outside of the reassembly window: set RX_Next_Reassembly to
    % the SN of the first SN >= (RX_Next_Highest - UM_Window_Size) that has not been
    % reassembled and delivered to upper layer."
    if rlc.snDiff(rx.RX_Next_Reassembly, rx.RX_Next_Highest - W, snLen) >= W
        rx.RX_Next_Reassembly = firstNotDone(rx.doneSn, mod(rx.RX_Next_Highest - W, M), M);
    end
end

% ---- t-Reassembly, the second half of clause 5.2.2.2.3 ----------------------
base = rx.RX_Next_Highest - W;
dRnr = rlc.snDiff(rx.RX_Next_Reassembly, base, snLen);
if rx.tReassemblyExpiry >= 0
    dTrig = rlc.snDiff(rx.RX_Timer_Trigger, base, snLen);
    stopNow = dTrig <= dRnr ...
        || (dTrig >= W && rx.RX_Timer_Trigger ~= rx.RX_Next_Highest) ...
        || (rx.RX_Next_Highest == mod(rx.RX_Next_Reassembly + 1, M) ...
            && ~rlc.rxBufMissingBeforeLast(rx.buf, rx.RX_Next_Reassembly));
    if stopNow
        rx.tReassemblyExpiry = -1;      % "stop and reset t-Reassembly"
    end
end
if rx.tReassemblyExpiry < 0
    dRnrPlus1 = rlc.snDiff(rx.RX_Next_Reassembly + 1, base, snLen);
    if rlc.snDiff(rx.RX_Next_Highest, base, snLen) > dRnrPlus1 ...
            || (rx.RX_Next_Highest == mod(rx.RX_Next_Reassembly + 1, M) ...
                && rlc.rxBufMissingBeforeLast(rx.buf, rx.RX_Next_Reassembly))
        rx.tReassemblyExpiry = nowMs + rx.cfg.t_Reassembly;     % "start t-Reassembly"
        rx.RX_Timer_Trigger = rx.RX_Next_Highest;
    end
end

rx.doneSn = pruneDone(rx);
end

function s = firstNotDone(doneSn, start, M)
% The first SN >= start that is not in doneSn. Bounded: each step passes a distinct done SN.
s = start;
while any(doneSn == s)
    s = mod(s + 1, M);
end
end

function d = pruneDone(rx)
% Keep only delivered SNs in [RX_Next_Reassembly, RX_Next_Highest). An SN below the lower edge
% is already accounted for by RX_Next_Reassembly; an SN left in the set after the window has
% moved on would alias the SAME number one wrap later and make a new SDU look delivered.
snLen = rx.cfg.snFieldLength;
base = rx.RX_Next_Highest - rx.cfg.UM_Window_Size;
dSn = rlc.snDiff(rx.doneSn, base, snLen);
d = rx.doneSn(dSn >= rlc.snDiff(rx.RX_Next_Reassembly, base, snLen) & dSn < rx.cfg.UM_Window_Size);
end
