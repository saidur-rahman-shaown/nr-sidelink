function h = harqRxInit(nProcesses)
%harqRxInit Create the RECEIVE-side Sidelink HARQ entity, TS 38.321 clause 5.22.2.2.1.
%Spec:   TS 38.321 V16.22.0, clause 5.22.2.2.1: "There is at most one Sidelink HARQ Entity at
%        the MAC entity for reception of the SL-SCH, which maintains a number of parallel
%        Sidelink processes."
%Inputs: nProcesses  integer, >=1 -- "The number of Receiving Sidelink processes associated
%                    with the Sidelink HARQ Entity is defined in TS 38.306" -- a UE capability,
%                    not a fixed constant, and TS 38.306 has no local PDF. Taken as an input
%                    rather than defaulted, the same way harqInit takes its transmit-side count
%Outputs: h  scalar struct, all state explicit and serialisable (the normative-packages rule
%            bans persistent/global):
%   .nProcesses  integer
%   .occupied    1 x nProcesses logical -- whether the process is associated with a peer
%   .srcId       1 x nProcesses integer -- SCI Source ID (8 LSB) it is associated with
%   .dstId       1 x nProcesses integer -- SCI Destination ID (16 LSB)
%   .harqId      1 x nProcesses integer -- the Sidelink process ID from the SCI
%   .lastNdi     1 x nProcesses integer -- NDI of the previous reception, for the toggle test
%   .decoded     1 x nProcesses logical -- whether this TB has already been decoded
%   .softValid   1 x nProcesses logical -- whether the soft buffer holds anything to combine
%
%THE RECEIVE ENTITY IS KEYED ON A TRIPLE, NOT ON A PROCESS NUMBER
%------------------------------------------------------------------
%A transmit-side process is just an index. A receive-side process is associated with
%(Source ID, Destination ID, Sidelink process ID) -- clause 5.22.2.2.1's "Sidelink
%identification information and the Sidelink process ID of the SCI". Two different peers using
%the same HARQ process number are two different processes here, and NOTE 2 makes it explicit
%that the association is one-to-one in both directions. Keying on the process number alone
%makes two peers share a soft buffer, so one peer's retransmission is combined into another's
%TB and the result decodes to noise -- at a rate that rises with the number of peers, which
%reads as congestion.

if ~(isscalar(nProcesses) && nProcesses >= 1 && mod(nProcesses, 1) == 0)
    error('mac:harqRxInit:badCount', 'harqRxInit: nProcesses must be a positive integer, got %s', num2str(nProcesses));
end

h = struct( ...
    'nProcesses', nProcesses, ...
    'occupied',   false(1, nProcesses), ...
    'srcId',      zeros(1, nProcesses), ...
    'dstId',      zeros(1, nProcesses), ...
    'harqId',     -ones(1, nProcesses), ...
    'lastNdi',    -ones(1, nProcesses), ...
    'decoded',    false(1, nProcesses), ...
    'softValid',  false(1, nProcesses));
end
