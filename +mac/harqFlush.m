function h = harqFlush(h, procIdx)
%harqFlush Flush a Sidelink process's HARQ buffer.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.3.1 -- the initial-transmission branch obtains a MAC
%        PDU from the Multiplexing and assembly entity and, "3> else: 4> flush the HARQ buffer of
%        the associated Sidelink process", i.e. when a grant is treated as an initial transmission
%        but NO MAC PDU could be obtained. Also the explicit flush in clause 5.22.1.1 for an
%        activated configured grant at the first PSSCH opportunity of an sl-PeriodCG.
%Inputs: h        struct from harqInit or a prior HARQ call
%        procIdx  integer, 1..h.nProcesses
%Outputs: h  updated entity with that process's buffer emptied and its transmission state reset
%
%This is the flush path that is NOT feedback-driven, which is why it is its own function rather
%than a branch of harqOnFeedback. Clause 5.22.1.3.1 reaches it when the multiplexing entity had
%nothing to send -- LCP selected no logical channel, or clause 5.22.1.4.1.3's "shall not generate
%a MAC PDU [...] zero MAC SDUs and no Sidelink CSI Reporting MAC CE" rule applied. The grant is
%consumed either way; what must not happen is the process keeping a stale TB that a later
%retransmission grant would then resurrect. harqOnFeedback covers the other three flush conditions
%(sl-MaxTransNum reached, positive acknowledgement, negative-only with no NACK), so between them
%the two functions implement all four the spec defines.
%
%Flushing an already-empty buffer is a no-op, not an error: the "no MAC PDU obtained" case fires
%naturally on a process that was never loaded.
if ~isscalar(procIdx) || mod(procIdx, 1) ~= 0 || procIdx < 1 || procIdx > h.nProcesses
    error('mac:harqFlush:badProcess', 'harqFlush: procIdx must be an integer in 1..%d, got %s', h.nProcesses, num2str(procIdx));
end
h.bufferOccupied(procIdx) = false;
h.txCount(procIdx) = 0;
h.rvIndex(procIdx) = 0;
h.harqProcessId(procIdx) = -1;
% The NDI is deliberately NOT reset. Clause 5.22.1.3.1 toggles it "compared to the value of the
% previous transmission corresponding to the Sidelink identification information and the Sidelink
% process ID" -- it is a running parity across TBs, not per-buffer state, so clearing it here
% would make the next initial transmission's toggle meaningless to a receiver tracking it.
end
