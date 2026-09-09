function ctx = ctxInit(pktId, srcL2Id, dstL2Id, pqi, prio, pdbMs, sizeBytes, lcid, tGenSlot)
%ctxInit Create the per-packet context that travels the whole stack.
%Spec:   none -- this struct is our own, but its contents are not: pqi/prio/pdbMs come from
%        TS 23.287 clause 5.4.4 Table 5.4.4-1 via +cfg/pqiTable, the Layer-2 IDs are the
%        24-bit identifiers TS 38.321 clause 6.2.4 splits between the MAC subheader and the
%        SCI, and lcid is that clause's logical channel ID.
%Inputs: pktId      integer, >=1 -- unique and monotonic per UE
%        srcL2Id    integer, 0..2^24-1 -- Source Layer-2 ID
%        dstL2Id    integer, 0..2^24-1 -- Destination Layer-2 ID
%        pqi        integer, >=1 -- PC5 5QI, a PQI column of +cfg/pqiTable
%        prio       integer, 1..8 -- sl-Priority. 1 is the HIGHEST (see +mac/CLAUDE.md)
%        pdbMs      real, >0 -- packet delay budget in ms, pqiTable's PDB_ms
%        sizeBytes  integer, >=1 -- SDU payload size
%        lcid       integer, 0..63 -- logical channel ID
%        tGenSlot   integer, >=0 -- generation slot, PHYSICAL slot index
%Outputs: ctx  scalar struct, the fields above plus the timestamp trail, all initialised to 0:
%   .tMacSlot .tGrantSlot .tTxSlot .tRxSlot  integer -- 0 means "not yet"
%   .nTx      integer -- transmissions spent, including blind retransmissions
%   .outcome  integer -- +sap/outcomeCodes, starts at .inFlight
%
%tGenSlot IS THE ONE REFERENCE POINT
%-----------------------------------
%+app/CLAUDE.md fixes it: "D_app in the delay budget is measured from here and nowhere else".
%Every latency figure the simulator reports is a difference against this field, so it is set
%once, at creation, and no later stage may overwrite it. The other four timestamps are filled
%in as the packet crosses each SAP, by +sap/ctxStamp, which refuses to overwrite a stamp that
%is already set -- a packet cannot cross the same boundary twice.
%
%PHYSICAL slot indices throughout. The logical pool numbering that +phy/+ts38214/ uses is a
%pool-relative re-indexing that skips slots; a duration measured in it is not a duration in
%time. Latency is wall-clock, so it is measured in physical slots and converted once, at
%report time, by 2^mu.

if ~(pktId >= 1 && mod(pktId, 1) == 0)
    error('sap:ctxInit:badPktId', 'ctxInit: pktId must be a positive integer, got %s', num2str(pktId));
end
l2IdMax = 2^24 - 1;   % TS 23.287: Layer-2 IDs are 24 bits (see +mac/CLAUDE.md's pending-human note)
if ~(srcL2Id >= 0 && srcL2Id <= l2IdMax && mod(srcL2Id, 1) == 0)
    error('sap:ctxInit:badSrcId', 'ctxInit: srcL2Id must be an integer in 0..%d, got %s', l2IdMax, num2str(srcL2Id));
end
if ~(dstL2Id >= 0 && dstL2Id <= l2IdMax && mod(dstL2Id, 1) == 0)
    error('sap:ctxInit:badDstId', 'ctxInit: dstL2Id must be an integer in 0..%d, got %s', l2IdMax, num2str(dstL2Id));
end
if ~(prio >= 1 && prio <= 8 && mod(prio, 1) == 0)
    error('sap:ctxInit:badPrio', 'ctxInit: prio must be an integer in 1..8 (1 is highest), got %s', num2str(prio));
end
if ~(pdbMs > 0)
    error('sap:ctxInit:badPdb', 'ctxInit: pdbMs must be > 0, got %s', num2str(pdbMs));
end
if ~(sizeBytes >= 1 && mod(sizeBytes, 1) == 0)
    error('sap:ctxInit:badSize', 'ctxInit: sizeBytes must be a positive integer, got %s', num2str(sizeBytes));
end
% TS 38.321 clause 6.2.4: the SL-SCH subheader's LCID field is 6 bits.
if ~(lcid >= 0 && lcid <= 63 && mod(lcid, 1) == 0)
    error('sap:ctxInit:badLcid', 'ctxInit: lcid must be an integer in 0..63, got %s', num2str(lcid));
end
if ~(tGenSlot >= 0 && mod(tGenSlot, 1) == 0)
    error('sap:ctxInit:badGenSlot', 'ctxInit: tGenSlot must be a nonnegative integer, got %s', num2str(tGenSlot));
end

ctx = struct( ...
    'pktId',      pktId, ...
    'srcL2Id',    srcL2Id, ...
    'dstL2Id',    dstL2Id, ...
    'pqi',        pqi, ...
    'prio',       prio, ...
    'pdbMs',      pdbMs, ...
    'sizeBytes',  sizeBytes, ...
    'lcid',       lcid, ...
    'tGenSlot',   tGenSlot, ...
    'tMacSlot',   0, ...
    'tGrantSlot', 0, ...
    'tTxSlot',    0, ...
    'tRxSlot',    0, ...
    'nTx',        0, ...
    'outcome',    0);
end
