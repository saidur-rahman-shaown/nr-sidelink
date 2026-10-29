function [rx, expired] = umRxTimer(rx, nowMs)
%umRxTimer Run the receiving UM entity's t-Reassembly expiry, if it is due.
%Spec:   TS 38.322 V16.3.0, clause 5.2.2.2.4: "When t-Reassembly expires, the receiving UM RLC
%        entity shall: update RX_Next_Reassembly to the SN of the first SN >= RX_Timer_Trigger
%        that has not been reassembled; discard all segments with SN < updated
%        RX_Next_Reassembly; if RX_Next_Highest > RX_Next_Reassembly + 1; or if RX_Next_Highest
%        = RX_Next_Reassembly + 1 and there is at least one missing byte segment of the RLC SDU
%        associated with SN = RX_Next_Reassembly before the last byte of all received segments
%        of this RLC SDU: start t-Reassembly; set RX_Timer_Trigger to RX_Next_Highest."
%        Comparisons use the modulus base RX_Next_Highest - UM_Window_Size (clause 7.1).
%Inputs: rx     entity from umRxInit
%        nowMs  real, ms -- current time
%Outputs: rx       updated entity
%         expired  logical -- whether t-Reassembly expired in this call
%
%A restart is timed from the EXPIRY instant, not from nowMs: a caller stepping in coarse ticks
%would otherwise stretch every restarted timer by up to one tick. For the same reason the
%function loops, so a tick long enough to span an expiry and its restart handles both.
%
%This is what keeps UM from stalling. A lost segment leaves a partial SDU that can never
%complete; without expiry RX_Next_Reassembly never passes it, and once RX_Next_Highest has
%moved half the SN space ahead, every new SN lands in [RX_Next_Highest - UM_Window_Size,
%RX_Next_Reassembly), is discarded, and the entity is dead. The expiry abandons the partial
%SDU and moves the lower edge on.

snLen = rx.cfg.snFieldLength;
W = rx.cfg.UM_Window_Size;
M = 2^snLen;
expired = false;

while rx.tReassemblyExpiry >= 0 && nowMs >= rx.tReassemblyExpiry
    expired = true;
    tExpiry = rx.tReassemblyExpiry;
    rx.tReassemblyExpiry = -1;
    base = rx.RX_Next_Highest - W;

    % "the first SN >= RX_Timer_Trigger that has not been reassembled"
    s = rx.RX_Timer_Trigger;
    while any(rx.doneSn == s)
        s = mod(s + 1, M);
    end
    rx.RX_Next_Reassembly = s;

    % "discard all segments with SN < updated RX_Next_Reassembly"
    dRnr = rlc.snDiff(rx.RX_Next_Reassembly, base, snLen);
    held = rlc.rxBufSnList(rx.buf);
    for k = 1:numel(held)
        if rlc.snDiff(held(k), base, snLen) < dRnr
            rx.buf = rlc.rxBufDrop(rx.buf, held(k));
            rx.nSnAbandoned = rx.nSnAbandoned + 1;
        end
    end

    dRnrPlus1 = rlc.snDiff(rx.RX_Next_Reassembly + 1, base, snLen);
    if rlc.snDiff(rx.RX_Next_Highest, base, snLen) > dRnrPlus1 ...
            || (rx.RX_Next_Highest == mod(rx.RX_Next_Reassembly + 1, M) ...
                && rlc.rxBufMissingBeforeLast(rx.buf, rx.RX_Next_Reassembly))
        rx.tReassemblyExpiry = tExpiry + rx.cfg.t_Reassembly;
        rx.RX_Timer_Trigger = rx.RX_Next_Highest;
    end

    dSn = rlc.snDiff(rx.doneSn, base, snLen);
    rx.doneSn = rx.doneSn(dSn >= dRnr & dSn < W);
end
end
