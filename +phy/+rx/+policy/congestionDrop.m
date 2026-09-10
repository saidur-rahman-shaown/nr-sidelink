function drop = congestionDrop(withinLimit)
%congestionDrop What to do when the CR limit would be exceeded.
%Spec:   TS 38.214 V16.17.0, clause 8.1.6's closing sentence: "It is up to UE implementation how
%        to meet the above limits, including dropping the transmissions in slot n." So the
%        LIMIT is normative and the RESPONSE is not, which is exactly the split
%        +phy/+ts38214/congestionControlCheck documents -- it reports, it does not drop.
%Inputs: withinLimit  logical -- congestionControlCheck's verdict
%Outputs: drop  logical -- true to skip this slot's transmission
%
%THIS CUT: DROP THE TRANSMISSION.
%--------------------------------
%The bluntest of the responses the clause permits, and the only one available without machinery
%that does not exist yet. The alternatives it hints at are all adaptations rather than refusals:
%lower the MCS, take fewer sub-channels, drop the retransmission but keep the initial
%transmission, or reselect to a longer reservation period. Each needs a feedback path from the
%congestion measurement back into the selection policy, and each spends less of the channel
%without losing the packet outright.
%
%What dropping costs, so it is not mistaken for a result: the packet is lost, and it is lost
%*because the UE chose not to send it*. That shows up as reliability loss, not as congestion,
%and the two are indistinguishable in a PRR figure alone -- which is why +harness/kpiReport
%counts congestion drops separately rather than folding them into the loss count.

drop = ~withinLimit;
end
