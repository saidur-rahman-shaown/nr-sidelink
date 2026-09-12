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
%   .lastSlot    1 x nProcesses integer -- the slot this process last received anything in,
%                for the staleness release below. -1 when unoccupied
%   .doneSrc .doneDst .doneHarq .doneNdi  1 x nProcesses integer -- a ring of the most recently
%                COMPLETED receptions, so a repeat of a TB already delivered is discarded
%                instead of being delivered twice. See below
%   .doneSlot    1 x nProcesses integer -- when each was completed. **The ring entries EXPIRE**,
%                and that is not optional: the key (srcId, dstId, harqId, ndi) has only
%                nProcesses x 2 distinct values per peer, so it repeats legitimately every few
%                TBs. Without a time window the ring eventually holds every combination and
%                rejects genuinely new transport blocks forever
%   .doneCursor  integer -- write position in that ring
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
%
%TWO THINGS THE CLAUSE LEAVES TO IMPLEMENTATION, AND BOTH BITE
%---------------------------------------------------------------
%Clause 5.22.2.2.2 releases a process on the first SUCCESSFUL decode and says nothing about a
%reception that never succeeds; NOTE 1 says only that "how to manage receiving Sidelink
%processes is up to UE implementation" when none are free. Taken literally, both gaps are real
%failures:
%
%  * **A TB that never decodes holds its process forever.** Measured before the fix: at 20 UEs
%    the worst UE held 4 of 16 processes, at 50 UEs it held 16 of 16, and pool-wide 91% were
%    occupied at 80 UEs. Once full, harqRxAssign drops TBs that WOULD have decoded -- a
%    silent reception failure that grows with density, i.e. exactly where it is least visible
%    and most costly. `lastSlot` plus mac.harqRxAge is the release policy.
%  * **A repeat of a TB already delivered is delivered again.** After a successful decode the
%    process is released, so the second copy of a blind retransmission finds no association,
%    is treated as a new transmission, and is handed up a second time. NOTE 1a covers exactly
%    this case ("if there is no Sidelink process associated ... it is up to UE implementation
%    to handle the corresponding TB"), and delivering a duplicate is the wrong answer. The
%    `done*` ring remembers RECENTLY completed receptions so the repeat is discarded.
%
%    "Recently" is load-bearing. The ring's key is (srcId, dstId, harqId, ndi), and a
%    transmitter cycles a handful of HARQ processes with a toggling NDI -- so with four
%    transmitting processes the key repeats every EIGHT transport blocks. A ring without a time
%    window fills with every combination and then rejects genuinely new TBs as duplicates,
%    permanently. Measured when the window was missing: unicast delivery stopped dead at 8
%    packets per UE and every packet after that expired -- 160 delivered and 220 expired over a
%    4000-slot run that should have delivered nearly all 400.

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
    'softValid',  false(1, nProcesses), ...
    'lastSlot',   -ones(1, nProcesses), ...
    'doneSrc',    -ones(1, nProcesses), ...
    'doneDst',    -ones(1, nProcesses), ...
    'doneHarq',   -ones(1, nProcesses), ...
    'doneNdi',    -ones(1, nProcesses), ...
    'doneSlot',   -ones(1, nProcesses), ...
    'doneCursor', 0);
end
