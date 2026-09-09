function [h, flushed, rlfDetected] = harqOnFeedback(h, procIdx, ack, psfchReceived, slMaxTransNum, slMaxNumConsecutiveDTX)
%harqOnFeedback Apply PSFCH feedback: flush the buffer if done, and age the RLF DTX counter.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.3.1a (the flush conditions), clause 5.22.1.3.2 (PSFCH
%        reception: "if an acknowledgement corresponding to the PSSCH transmission [...] is
%        obtained from the physical layer: deliver the acknowledgement [...] else: deliver a
%        NEGATIVE acknowledgement"), and clause 5.22.1.3.3 (HARQ-based Sidelink RLF detection).
%        Clause 5.22.1.3.1a's flush conditions, verbatim:
%          "if sl-MaxTransNum [...] has been configured [...] and the number of transmissions of
%           the MAC PDU has been reached to sl-MaxTransNum; or if a POSITIVE acknowledgement to
%           this transmission of the MAC PDU was received [...]; or if NEGATIVE-ONLY
%           acknowledgement was enabled in the SCI and NO negative acknowledgement was received
%           for this transmission [...]: flush the HARQ buffer of the associated Sidelink process."
%Inputs: h                       struct from harqInit or a prior HARQ call
%        procIdx                 integer, 1..h.nProcesses
%        ack                     logical scalar -- true for a positive acknowledgement. Under
%                                negative-only acknowledgement the physical layer signals only
%                                NACK, so "no NACK received" IS the success case and the caller
%                                passes ack = true for it -- which is why this argument is a
%                                decoded verdict rather than a raw PSFCH energy.
%        psfchReceived           logical scalar -- whether ANY PSFCH was received on the occasion.
%                                Distinct from ack: clause 5.22.1.3.3 counts DTX ("if PSFCH
%                                reception is ABSENT on the PSFCH reception occasion"), which is
%                                not the same as a received NACK. Conflating them makes a UE that
%                                is being actively NACKed declare radio link failure, and a UE
%                                hearing nothing at all never declare it -- both backwards.
%        slMaxTransNum           positive integer, or 0 when not configured -- sl-MaxTransNum for
%                                the highest priority of the logical channels in the MAC PDU,
%                                from sl-CG-MaxTransNumList. Clause 5.22.1.3.1a guards this
%                                condition with "if [it] has been configured", so 0 disables it.
%        slMaxNumConsecutiveDTX  positive integer, or 0 when not configured --
%                                sl-maxNumConsecutiveDTX (clause 5.22.1.3.3). 0 disables RLF
%                                detection.
%Outputs: h            updated entity
%         flushed      logical -- whether the HARQ buffer was flushed, i.e. this TB is finished
%                      and the process is free for a new transmission
%         rlfDetected  logical -- true on exactly the occasion where numConsecutiveDTX reaches
%                      sl-maxNumConsecutiveDTX, which clause 5.22.1.3.3 says to "indicate [...]
%                      to RRC"
%
%DTX counting resets on ANY PSFCH reception, not on a positive one. Clause 5.22.1.3.3's else
%branch is "re-initialize numConsecutiveDTX to zero", and its if branch is keyed purely on
%absence. A received NACK therefore clears the DTX streak: the peer is demonstrably still there,
%which is precisely what this counter is measuring. Resetting only on ACK would turn a lossy but
%live link into a false RLF.
%
%The counter is checked with "reaches", so it fires once, on the occasion it hits the threshold,
%rather than on every occasion beyond it. It keeps counting afterwards (nothing in the clause
%resets it on detection) but rlfDetected is only true on the crossing, so a caller cannot
%accidentally re-indicate RLF to RRC on every subsequent DTX.
if ~isscalar(procIdx) || mod(procIdx, 1) ~= 0 || procIdx < 1 || procIdx > h.nProcesses
    error('mac:harqOnFeedback:badProcess', 'harqOnFeedback: procIdx must be an integer in 1..%d, got %s', h.nProcesses, num2str(procIdx));
end
if slMaxTransNum < 0 || mod(slMaxTransNum, 1) ~= 0
    error('mac:harqOnFeedback:badMaxTransNum', 'harqOnFeedback: slMaxTransNum must be a nonnegative integer (0 = not configured), got %s', num2str(slMaxTransNum));
end
if slMaxNumConsecutiveDTX < 0 || mod(slMaxNumConsecutiveDTX, 1) ~= 0
    error('mac:harqOnFeedback:badMaxDTX', 'harqOnFeedback: slMaxNumConsecutiveDTX must be a nonnegative integer (0 = not configured), got %s', num2str(slMaxNumConsecutiveDTX));
end
ack = logical(ack);
psfchReceived = logical(psfchReceived);

% ---- clause 5.22.1.3.3: HARQ-based Sidelink RLF detection ----------------
rlfDetected = false;
if psfchReceived
    h.numConsecutiveDTX = 0;
else
    h.numConsecutiveDTX = h.numConsecutiveDTX + 1;
    if slMaxNumConsecutiveDTX > 0 && h.numConsecutiveDTX == slMaxNumConsecutiveDTX
        rlfDetected = true;
    end
end

% ---- clause 5.22.1.3.1a: flush conditions --------------------------------
flushed = false;
if ~h.bufferOccupied(procIdx)
    return;   % nothing to flush; a repeat feedback for a finished TB is not an error
end
maxReached = slMaxTransNum > 0 && h.txCount(procIdx) >= slMaxTransNum;
if ack || maxReached
    h.bufferOccupied(procIdx) = false;
    h.txCount(procIdx) = 0;
    h.rvIndex(procIdx) = 0;
    h.harqProcessId(procIdx) = -1;
    flushed = true;
end
end
