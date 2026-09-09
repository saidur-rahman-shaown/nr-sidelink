function [h, ndi, rv] = harqNewTransmission(h, procIdx, rvSequence, harqProcessId, feedbackEnabled)
%harqNewTransmission Associate a grant to a Sidelink process for an initial transmission.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.3.1 (the Sidelink HARQ Entity's initial-transmission
%        branch: "(re-)associate a Sidelink process to this grant", obtain the MAC PDU, set the
%        Sidelink transmission information, "deliver the MAC PDU, the sidelink grant and the
%        Sidelink transmission information of the TB to the associated Sidelink process; instruct
%        the associated Sidelink process to trigger a new transmission") and clause 5.22.1.3.1a
%        ("store the MAC PDU in the associated HARQ buffer; store the sidelink grant [...];
%        generate a transmission").
%Inputs: h                struct from harqInit or a prior HARQ call
%        procIdx          integer, 1..h.nProcesses -- which Sidelink process the MAC entity chose.
%                         Chosen by the caller, not here: clause 5.22.1.3.1 NOTE 1A says "The
%                         Sidelink HARQ Entity will associate the selected sidelink grant to the
%                         Sidelink process DETERMINED BY THE MAC ENTITY", and NOTE 1b likewise
%                         leaves the Sidelink process ID in the SCI to UE implementation.
%        rvSequence       1 x nRv integer row vector -- the redundancy version order this
%                         deployment uses, e.g. [0 2 3 1]. Taken as an input because clause
%                         5.22.1.3.1 only says "set the Redundancy version to the selected
%                         value"; the sequence itself is a TS 38.214 clause 8.1.3 / UE
%                         implementation matter, not something this clause fixes.
%        harqProcessId    integer, >=0, or -1 -- the HARQ Process ID to associate, where the
%                         grant carries one (mode 1, or a configured grant: clause 5.22.1.1
%                         derives it as floor(CURRENT_slot / PeriodicitySL) mod
%                         sl-NrOfHARQ-Processes + sl-HARQ-ProcID-offset). Pass -1 for a mode-2
%                         selected grant, which carries none.
%        feedbackEnabled  logical scalar -- the HARQ feedback enabled/disabled indicator for this
%                         MAC PDU, decided by clause 5.22.1.4.2 / the LCP multiplex (slLcp fixes
%                         it to the highest-priority selected channel's value)
%Outputs: h    updated entity: buffer occupied, txCount reset to 1, RV index advanced to the
%              second entry of the sequence, NDI toggled
%         ndi  logical -- the NDI to signal in the SCI for this transmission
%         rv   integer -- the redundancy version to signal, rvSequence(1)
%
%The NDI is TOGGLED, never set. Clause 5.22.1.3.1: "consider the NDI to have been toggled compared
%to the value of the previous transmission corresponding to the Sidelink identification
%information and the Sidelink process ID of the MAC PDU and set the NDI to the toggled value."
%Setting it to a fixed 1 for every initial transmission would make every new TB look like new
%data to a receiver that tracks toggles, which is right by accident on the first PDU and wrong on
%every one after a retransmission.
%
%A new transmission always overwrites: clause 5.22.1.3.1's initial-transmission branch
%"(re-)associates" the process and clause 5.22.1.3.1a stores the new MAC PDU in the buffer. So an
%occupied buffer is not an error here -- it is the normal case when a process is reused for the
%next TB. The buffer only has to be EMPTY-checked on the retransmission path, which is
%harqRetransmission's job.
if ~isscalar(procIdx) || mod(procIdx, 1) ~= 0 || procIdx < 1 || procIdx > h.nProcesses
    error('mac:harqNewTransmission:badProcess', 'harqNewTransmission: procIdx must be an integer in 1..%d, got %s', h.nProcesses, num2str(procIdx));
end
if isempty(rvSequence) || ~isrow(rvSequence) || any(mod(rvSequence, 1) ~= 0) || any(rvSequence < 0) || any(rvSequence > 3)
    error('mac:harqNewTransmission:badRvSequence', 'harqNewTransmission: rvSequence must be a non-empty row vector of redundancy versions in 0..3');
end
if ~isscalar(harqProcessId) || mod(harqProcessId, 1) ~= 0 || harqProcessId < -1
    error('mac:harqNewTransmission:badHarqId', 'harqNewTransmission: harqProcessId must be a nonnegative integer, or -1 for a mode-2 selected grant that carries none, got %s', num2str(harqProcessId));
end
if ~isscalar(feedbackEnabled) || ~(islogical(feedbackEnabled) || isnumeric(feedbackEnabled))
    error('mac:harqNewTransmission:badFeedbackFlag', 'harqNewTransmission: feedbackEnabled must be a logical scalar');
end

h.ndi(procIdx) = ~h.ndi(procIdx);   % clause 5.22.1.3.1: toggled relative to the previous TB
h.bufferOccupied(procIdx) = true;
h.txCount(procIdx) = 1;
h.rvIndex(procIdx) = 1;             % the next transmission takes rvSequence(2)
h.harqProcessId(procIdx) = harqProcessId;
h.feedbackEnabled(procIdx) = logical(feedbackEnabled);

ndi = h.ndi(procIdx);
rv = rvSequence(1);
end
