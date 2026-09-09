function h = harqInit(nProcesses, isPeriodicMode2)
%harqInit Create a Sidelink HARQ entity with its parallel Sidelink processes.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.3.1: "The MAC entity includes at most one Sidelink
%        HARQ entity for transmission on SL-SCH, which maintains a number of parallel Sidelink
%        processes. The maximum number of transmitting Sidelink processes associated with the
%        Sidelink HARQ Entity is 16. A sidelink process may be configured for transmissions of
%        multiple MAC PDUs. For transmissions of multiple MAC PDUs with Sidelink resource
%        allocation mode 2, the maximum number of transmitting Sidelink processes associated
%        with the Sidelink HARQ Entity is 4." Also clause 5.22.1.3.1a ("Each Sidelink process
%        supports one TB", the HARQ buffer) and clause 5.22.1.3.3 (numConsecutiveDTX).
%Inputs: nProcesses       integer, >=1 -- the number of parallel Sidelink processes. Bounded by
%                         16, or by 4 when isPeriodicMode2 -- see the two limits below.
%        isPeriodicMode2  logical scalar -- whether these processes are for transmissions of
%                         MULTIPLE MAC PDUs with Sidelink resource allocation mode 2, which is
%                         the configuration the clause caps at 4 rather than 16.
%Outputs: h  scalar struct, struct-of-parallel-arrays over the processes (no cell arrays, no
%            hidden state -- the whole entity serialises and diffs):
%              .nProcesses        integer -- how many processes exist
%              .isPeriodicMode2   logical -- which of the two limits applies
%              .bufferOccupied    1 x nProcesses logical -- whether the process's HARQ buffer
%                                 holds a MAC PDU. "Flush the HARQ buffer" clears this, and an
%                                 empty buffer is what makes clause 5.22.1.3.1 ignore a
%                                 retransmission grant.
%              .ndi               1 x nProcesses logical -- the New Data Indicator most recently
%                                 sent for this process. Clause 5.22.1.3.1 toggles it per initial
%                                 transmission; NOTE 2 leaves the very first value to UE
%                                 implementation, so it starts false here by choice, not by rule.
%              .txCount           1 x nProcesses integer -- transmissions made of the current TB,
%                                 initial included. Compared against sl-MaxTransNum.
%              .rvIndex           1 x nProcesses integer -- index into the caller's RV sequence
%                                 for the next transmission, 0-based
%              .harqProcessId     1 x nProcesses integer -- the HARQ Process ID associated with
%                                 the process, or -1 when none is associated. Clause 5.22.1.3.1
%                                 NOTE 1a: "There is one-to-one mapping between a HARQ Process ID
%                                 and a Sidelink process in the MAC entity configured with
%                                 Sidelink resource allocation mode 1."
%              .feedbackEnabled   1 x nProcesses logical -- the HARQ feedback enabled/disabled
%                                 indicator carried in the SCI for the stored TB
%              .numConsecutiveDTX integer scalar -- clause 5.22.1.3.3's counter. Held once per
%                                 entity here rather than per process because the clause
%                                 maintains it "for each PC5-RRC connection"; a caller modelling
%                                 several peers keeps one entity per connection.
%
%The two process limits are not interchangeable and the smaller one is easy to miss: a mode-2 UE
%doing periodic (multiple-MAC-PDU) transmissions gets FOUR processes, not sixteen. Over-allocating
%lets a simulation run more concurrent TBs than any conformant UE could, which inflates
%throughput without ever failing a test.
maxProcessesGeneral = 16;   % clause 5.22.1.3.1
maxProcessesPeriodicMode2 = 4;   % clause 5.22.1.3.1, the multiple-MAC-PDU mode-2 case

if ~isscalar(isPeriodicMode2) || ~(islogical(isPeriodicMode2) || isnumeric(isPeriodicMode2))
    error('mac:harqInit:badMode', 'harqInit: isPeriodicMode2 must be a logical scalar');
end
isPeriodicMode2 = logical(isPeriodicMode2);
if isPeriodicMode2
    limit = maxProcessesPeriodicMode2;
else
    limit = maxProcessesGeneral;
end
if ~isscalar(nProcesses) || mod(nProcesses, 1) ~= 0 || nProcesses < 1 || nProcesses > limit
    error('mac:harqInit:badCount', 'harqInit: nProcesses must be an integer in 1..%d for this configuration (clause 5.22.1.3.1 allows %d transmitting Sidelink processes%s), got %s', limit, limit, ternaryLabel(isPeriodicMode2), num2str(nProcesses));
end

h.nProcesses = nProcesses;
h.isPeriodicMode2 = isPeriodicMode2;
h.bufferOccupied = false(1, nProcesses);
h.ndi = false(1, nProcesses);
h.txCount = zeros(1, nProcesses);
h.rvIndex = zeros(1, nProcesses);
h.harqProcessId = -ones(1, nProcesses);
h.feedbackEnabled = false(1, nProcesses);
h.numConsecutiveDTX = 0;
end

function s = ternaryLabel(isPeriodicMode2)
if isPeriodicMode2
    s = ' for transmissions of multiple MAC PDUs with resource allocation mode 2';
else
    s = '';
end
end
