function rx = amRxPollRecheck(rx)
%amRxPollRecheck Release delayed poll triggers whose condition now holds.
%Spec:   TS 38.322 V16.3.0, clause 5.3.4: "else: delay triggering the STATUS report until x <
%        RX_Highest_Status or x >= RX_Next + AM_Window_Size." NOTE 1: "This ensures that the RLC
%        Status report is transmitted after HARQ reordering." Modulus base RX_Next (clause 7.1).
%Inputs: rx  AM receive entity
%Outputs: rx  with statusTriggered set, and the released SNs removed from pollDelayedSn
%
%Called after every change to RX_Next or RX_Highest_Status. A delayed poll that is never
%re-checked is a poll that is never answered: the transmitter's t-PollRetransmit then expires,
%it retransmits the highest SN for no reason, and the RETX_COUNT that climbs is the one that
%declares radio link failure.

snLen = rx.cfg.snFieldLength;
W = rx.cfg.AM_Window_Size;
dRhs = rlc.snDiff(rx.RX_Highest_Status, rx.RX_Next, snLen);
keep = true(1, numel(rx.pollDelayedSn));
for k = 1:numel(rx.pollDelayedSn)
    d = rlc.snDiff(rx.pollDelayedSn(k), rx.RX_Next, snLen);
    if d < dRhs || d >= W
        rx.statusTriggered = true;
        keep(k) = false;
    end
end
rx.pollDelayedSn = rx.pollDelayedSn(keep);
end
