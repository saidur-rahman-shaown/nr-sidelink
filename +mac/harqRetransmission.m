function [h, rv, ignored] = harqRetransmission(h, procIdx, rvSequence)
%harqRetransmission Trigger a retransmission on a Sidelink process.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.3.1, the "else (i.e. retransmission)" branch:
%          "if the HARQ Process ID corresponding to the sidelink grant [...] is associated to a
%           Sidelink process of which HARQ BUFFER IS EMPTY; or if the HARQ Process ID
%           corresponding to the sidelink grant received on PDCCH is not associated to any
%           Sidelink process:  ignore the sidelink grant.
%           else: identify the Sidelink process associated with this grant [...] deliver the
%           sidelink grant of the MAC PDU to the associated Sidelink process; instruct the
%           associated Sidelink process to trigger a retransmission."
%        Also clause 5.22.1.3.1a: a retransmission stores the new grant but does NOT touch the
%        HARQ buffer -- only "store the sidelink grant received from the Sidelink HARQ Entity;
%        generate a transmission".
%Inputs: h           struct from harqInit or a prior HARQ call
%        procIdx     integer, 1..h.nProcesses -- the process associated with this grant
%        rvSequence  1 x nRv integer row vector -- the redundancy version order, same sequence
%                    passed to harqNewTransmission for this TB
%Outputs: h        updated entity
%         rv       integer -- the redundancy version to signal, or -1 when the grant was ignored
%         ignored  logical -- true if the grant was IGNORED per the clause's empty-buffer rule
%
%Ignoring is a normative outcome, not an error, which is why it is a return value rather than a
%thrown exception. A retransmission grant arriving for a process whose buffer was flushed -- by a
%positive acknowledgement, or by hitting sl-MaxTransNum -- is exactly the case clause 5.22.1.3.1
%says to ignore, and it happens routinely: the grant was selected before the ACK came back. A
%caller that treats it as a failure will report phantom errors on every successful early ACK.
%
%The RV sequence WRAPS. Clause 5.22.1.3.1a places no bound on retransmissions of its own -- the
%bound is sl-MaxTransNum, checked by harqOnFeedback -- so the index cycles modulo the sequence
%length rather than running off the end. A UE configured for more transmissions than the sequence
%has entries reuses the sequence from the start, which is the standard behaviour and is why the
%index, not the RV value, is what the entity stores.
if ~isscalar(procIdx) || mod(procIdx, 1) ~= 0 || procIdx < 1 || procIdx > h.nProcesses
    error('mac:harqRetransmission:badProcess', 'harqRetransmission: procIdx must be an integer in 1..%d, got %s', h.nProcesses, num2str(procIdx));
end
if isempty(rvSequence) || ~isrow(rvSequence) || any(mod(rvSequence, 1) ~= 0) || any(rvSequence < 0) || any(rvSequence > 3)
    error('mac:harqRetransmission:badRvSequence', 'harqRetransmission: rvSequence must be a non-empty row vector of redundancy versions in 0..3');
end

if ~h.bufferOccupied(procIdx)
    % clause 5.22.1.3.1: an empty HARQ buffer means "ignore the sidelink grant"
    ignored = true;
    rv = -1;
    return;
end

ignored = false;
rv = rvSequence(mod(h.rvIndex(procIdx), numel(rvSequence)) + 1);
h.rvIndex(procIdx) = h.rvIndex(procIdx) + 1;
h.txCount(procIdx) = h.txCount(procIdx) + 1;
end
