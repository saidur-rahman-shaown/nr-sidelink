function [h, deliver, feedback, combine] = harqRxProcess(h, procIdx, isNewTx, decodedOk, passesFilter, castType, feedbackEnabled, inCommRange)
%harqRxProcess Act on one received TB: deliver, buffer, and decide feedback. Clause 5.22.2.2.2.
%Spec:   TS 38.321 V16.22.0, clause 5.22.2.2.2 (Sidelink process), including its HARQ feedback
%        generation rules. The delivery IDENTITY test is mac.pduFilter's; its verdict arrives
%        here as passesFilter, because clause 5.22.2.2.2 interleaves the two and separating
%        them keeps each testable.
%Inputs: h                struct from harqRxInit
%        procIdx          integer, 1..nProcesses -- from mac.harqRxAssign
%        isNewTx          logical -- from mac.harqRxAssign
%        decodedOk        logical -- whether the physical layer decoded THIS attempt
%        passesFilter     logical -- mac.pduFilter's verdict. Only consulted on the first
%                         successful decode
%        castType         integer, 0..3 -- SCI-2A Cast type indicator, Table 8.4.1.1-1
%        feedbackEnabled  logical -- the SCI's HARQ feedback enabled/disabled indicator
%        inCommRange      logical -- for NACK-only groupcast: whether this UE is within the
%                         communication range requirement, or has no location information, or
%                         the SCI indicated no zone. Clause 5.22.2.2.2 treats all three the
%                         same way, so they are collapsed into one flag by the caller
%Outputs: h         updated entity
%         deliver   logical -- hand the PDU to disassembly and demultiplexing
%         feedback  char -- 'none', 'ack' or 'nack', what to tell the physical layer to send
%         combine   logical -- whether this attempt should have been combined with the soft
%                   buffer. Returned for the caller that actually holds the LLRs, since the
%                   clause instructs the PHYSICAL layer to combine and a MAC module holds no
%                   soft buffer of its own
%
%"SUCCESSFULLY DECODED BEFORE" IS A SEPARATE CASE FROM "DECODED NOW"
%---------------------------------------------------------------------
%The clause's condition is "if the data which the MAC entity attempted to decode was
%successfully decoded for this TB; OR if the data for this TB was successfully decoded before".
%The second arm matters: a retransmission of a TB already delivered must still produce an ACK,
%or the transmitter keeps retransmitting something the receiver already has. Only the FIRST
%success delivers, though -- guarded by h.decoded -- so a duplicate is acknowledged without
%being handed up twice.
%
%NACK-ONLY GROUPCAST SENDS NOTHING ON SUCCESS
%----------------------------------------------
%For cast type 3 the clause generates a negative acknowledgement only, and only on failure.
%Silence is the positive acknowledgement. A receiver that ACKs here would transmit on a PSFCH
%resource the scheme does not allocate for it, colliding with the NACKs of other group members
%-- who share that resource precisely because only failures speak.

CAST_GROUPCAST_NACK_ONLY = 3;    % Table 8.4.1.1-1, "Groupcast when HARQ-ACK information includes only NACK"
CAST_BROADCAST = 0;

if ~(procIdx >= 1 && procIdx <= h.nProcesses && mod(procIdx, 1) == 0)
    error('mac:harqRxProcess:badProcIdx', 'harqRxProcess: procIdx must be an integer in 1..%d, got %s', h.nProcesses, num2str(procIdx));
end
if ~h.occupied(procIdx)
    error('mac:harqRxProcess:unoccupied', 'harqRxProcess: process %d is not associated with any peer; call harqRxAssign first', procIdx);
end

alreadyDecoded = h.decoded(procIdx);

% "if this is a new transmission: attempt to decode" / "else if a retransmission: if the data
% for this TB has not yet been successfully decoded, combine with the soft buffer".
combine = ~isNewTx && ~alreadyDecoded && h.softValid(procIdx);

deliver = false;
if decodedOk || alreadyDecoded
    if ~alreadyDecoded
        % First successful decoding: this is the only point at which the PDU goes up.
        deliver = passesFilter;
        h.decoded(procIdx) = true;
    end
    % "consider the Sidelink process as unoccupied" -- the TB is complete either way, whether
    % or not the identity check let it through. A PDU that failed the filter was still received
    % correctly; holding the process open for it would leak processes to every neighbour whose
    % traffic this UE can hear but is not addressed by.
    h.softValid(procIdx) = false;
    h.occupied(procIdx)  = false;
else
    % "instruct the physical layer to replace the data in the soft buffer with the data which
    % the MAC entity attempted to decode".
    h.softValid(procIdx) = true;
end

% ---- feedback, clause 5.22.2.2.2's closing block -------------------------
feedback = 'none';
if ~feedbackEnabled || castType == CAST_BROADCAST
    return;
end

succeeded = decodedOk || alreadyDecoded;
if castType == CAST_GROUPCAST_NACK_ONLY
    if ~succeeded && inCommRange
        feedback = 'nack';
    end
else
    % ACK/NACK groupcast, or unicast.
    if succeeded
        feedback = 'ack';
    else
        feedback = 'nack';
    end
end
end
