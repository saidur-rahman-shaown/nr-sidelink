function [rx, reassemblyExpired] = amRxTimer(rx, nowMs)
%amRxTimer Run the receiving side's t-Reassembly and t-StatusProhibit expiries, if due.
%Spec:   TS 38.322 V16.3.0, clause 5.2.3.2.4: "When t-Reassembly expires, the receiving side of
%        an AM RLC entity shall: update RX_Highest_Status to the SN of the first RLC SDU with SN
%        >= RX_Next_Status_Trigger for which not all bytes have been received; if
%        RX_Next_Highest > RX_Highest_Status + 1: or if RX_Next_Highest = RX_Highest_Status + 1
%        and there is at least one missing byte segment of the SDU associated with SN =
%        RX_Highest_Status before the last byte of all received segments of this SDU: start
%        t-Reassembly; set RX_Next_Status_Trigger to RX_Next_Highest."
%        Clause 5.3.4: "The receiving side of an AM RLC entity shall trigger a STATUS report
%        when t-Reassembly expires." NOTE 2: "the STATUS report shall be triggered after
%        RX_Highest_Status is updated." Clause 7.3 for t-StatusProhibit.
%Inputs: rx     entity from amRxInit
%        nowMs  real, ms
%Outputs: rx                 updated entity
%         reassemblyExpired  logical
%
%t-Reassembly in AM discards NOTHING, unlike UM's (clause 5.2.2.2.4). It only moves
%RX_Highest_Status -- the upper edge of what the next STATUS PDU may NACK -- and triggers that
%report. Copying UM's "discard all segments with SN < ..." into AM throws away the partial SDUs
%that the NACK is about to ask to have completed.
%
%A restart is timed from the expiry instant (see rlc.umRxTimer).

snLen = rx.cfg.snFieldLength;
M = 2^snLen;
reassemblyExpired = false;

while rx.tReassemblyExpiry >= 0 && nowMs >= rx.tReassemblyExpiry
    reassemblyExpired = true;
    tExpiry = rx.tReassemblyExpiry;
    rx.tReassemblyExpiry = -1;

    s = rx.RX_Next_Status_Trigger;
    while any(rx.doneSn == s)
        s = mod(s + 1, M);
    end
    rx.RX_Highest_Status = s;

    dRnh = rlc.snDiff(rx.RX_Next_Highest, rx.RX_Next, snLen);
    dRhs1 = rlc.snDiff(rx.RX_Highest_Status + 1, rx.RX_Next, snLen);
    if dRnh > dRhs1 || (dRnh == dRhs1 && rlc.rxBufMissingBeforeLast(rx.buf, rx.RX_Highest_Status))
        rx.tReassemblyExpiry = tExpiry + rx.cfg.t_Reassembly;
        rx.RX_Next_Status_Trigger = rx.RX_Next_Highest;
    end

    rx.statusTriggered = true;          % after the RX_Highest_Status update (NOTE 2)
    rx = amRxPollRecheck(rx);
end

if rx.tStatusProhibitExpiry >= 0 && nowMs >= rx.tStatusProhibitExpiry
    rx.tStatusProhibitExpiry = -1;
end
end
