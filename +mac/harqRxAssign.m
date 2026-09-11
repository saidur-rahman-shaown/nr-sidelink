function [h, procIdx, isNewTx] = harqRxAssign(h, srcId, dstId, harqId, ndi)
%harqRxAssign Map a received SCI to a Sidelink process. TS 38.321 clause 5.22.2.2.1.
%Spec:   TS 38.321 V16.22.0, clause 5.22.2.2.1, the "For each PSSCH duration, the Sidelink HARQ
%        Entity shall" block.
%Inputs: h       struct from harqRxInit or a prior call
%        srcId   integer, 0..255 -- SCI Source ID, the 8 LSB of the Source Layer-2 ID
%        dstId   integer, 0..65535 -- SCI Destination ID, the 16 LSB of the Destination Layer-2 ID
%        harqId  integer, 0..15 -- the Sidelink process ID carried in SCI-2
%        ndi     integer, 0 or 1 -- New data indicator from SCI-2
%Outputs: h        updated entity
%         procIdx  integer, 1..nProcesses, or 0 -- the process this reception belongs to. **0
%                  means no process was available and the TB is dropped**; see below
%         isNewTx  logical -- true for a new transmission, false for a retransmission.
%                  Meaningless when procIdx is 0
%
%THE TOGGLE TEST IS AGAINST THE TRIPLE, NOT AGAINST A GLOBAL LAST-NDI
%----------------------------------------------------------------------
%Clause 5.22.2.2.1 compares the NDI "to the value of the previous received transmission
%corresponding to the Sidelink identification information and the Sidelink process ID of the
%SCI". So the comparison is per (srcId, dstId, harqId) triple. A receiver that keeps one NDI
%per process index instead sees a toggle every time two peers interleave on the same process
%number, flushes a perfectly good soft buffer, and loses the combining gain -- silently, since
%the TB still decodes eventually on a strong link.
%
%A FIRST RECEPTION COUNTS AS A TOGGLE
%-------------------------------------
%"...or this is the very first received transmission for the pair" -- so an unknown triple is a
%new transmission whatever its NDI value. Without that clause a receiver that joins mid-stream
%waits for the next toggle before decoding anything, which looks like a slow-to-acquire link.
%
%NO FREE PROCESS IS A DROP, AND THE CLAUSE SAYS SO
%---------------------------------------------------
%NOTE 1: "If there is no unoccupied Sidelink process in the Sidelink HARQ entity, how to manage
%receiving Sidelink processes is up to UE implementation." This returns procIdx = 0 and drops
%the TB rather than evicting a process mid-reassembly: evicting would discard a soft buffer
%that a retransmission was about to complete, trading a certain loss for a probable one. It is
%a choice, not a rule, and it is reported as a value so a caller can count it.

if ~(ndi == 0 || ndi == 1)
    error('mac:harqRxAssign:badNdi', 'harqRxAssign: ndi must be 0 or 1, got %s', num2str(ndi));
end
if ~(harqId >= 0 && harqId <= 15 && mod(harqId, 1) == 0)
    error('mac:harqRxAssign:badHarqId', 'harqRxAssign: harqId must be an integer in 0..15 (SCI-2 field width), got %s', num2str(harqId));
end

% The process already associated with this exact triple, if any.
match = find(h.occupied & h.srcId == srcId & h.dstId == dstId & h.harqId == harqId, 1);

if ~isempty(match) && h.lastNdi(match) == ndi
    % NDI unchanged for a known triple: a retransmission of what that process already holds.
    procIdx = match;
    isNewTx = false;
    return;
end

% Either the NDI toggled, or this triple has never been seen: a new transmission.
if ~isempty(match)
    % "consider the Sidelink process as unoccupied" / "flush the soft buffer"
    h = releaseProcess(h, match);
end

free = find(~h.occupied, 1);
if isempty(free)
    procIdx = 0;                  % NOTE 1's implementation choice; see the header
    isNewTx = true;
    return;
end

h.occupied(free)  = true;
h.srcId(free)     = srcId;
h.dstId(free)     = dstId;
h.harqId(free)    = harqId;
h.lastNdi(free)   = ndi;
h.decoded(free)   = false;
h.softValid(free) = false;

procIdx = free;
isNewTx = true;
end

% =========================================================================
function h = releaseProcess(h, idx)
%releaseProcess Mark a process unoccupied and flush its soft buffer.
h.occupied(idx)  = false;
h.srcId(idx)     = 0;
h.dstId(idx)     = 0;
h.harqId(idx)    = -1;
h.lastNdi(idx)   = -1;
h.decoded(idx)   = false;
h.softValid(idx) = false;
end
