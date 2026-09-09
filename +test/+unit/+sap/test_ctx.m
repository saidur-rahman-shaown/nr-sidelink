function test_ctx()
%test_ctx Unit tests for +sap/, the packet context that carries the latency measurement.
%SPEC: none -- +sap/ is our own instrumentation, not a protocol layer. What is asserted here is
%      that the measurement cannot be corrupted by ordinary misuse: no boundary stamped twice,
%      no packet resolved twice, no packet left unresolved, and tGenSlot immutable.

codes = sap.outcomeCodes();

%% ---- a clean end-to-end life --------------------------------------------
c = sap.ctxInit(1, 100, 200, 55, 6, 100, 300, 4, 1000);
assert(c.tGenSlot == 1000 && c.outcome == codes.inFlight && c.nTx == 0, 'ctxInit: a fresh context must start in flight with no transmissions');
assert(all([c.tMacSlot c.tGrantSlot c.tTxSlot c.tRxSlot] == 0), 'ctxInit: every downstream timestamp must start at 0 (= not yet)');
c = sap.ctxStamp(c, 'mac',   1002);
c = sap.ctxStamp(c, 'grant', 1007);
c = sap.ctxTransmitted(c, 1030);
c = sap.ctxTransmitted(c, 1034);      % a blind retransmission
c = sap.ctxFinish(c, codes.delivered, 1034);
assert(c.tTxSlot == 1030, 'ctxTransmitted: a retransmission must NOT move tTxSlot off the first transmission, got %d', c.tTxSlot);
assert(c.nTx == 2, 'ctxTransmitted: both transmissions must be counted, got %d', c.nTx);
assert(c.tRxSlot == 1034 && c.outcome == codes.delivered, 'ctxFinish: delivery must stamp rx and set the outcome');
% The three KPIs this struct exists to produce, all differences against tGenSlot.
assert(c.tRxSlot - c.tGenSlot == 34, 'latency must be 34 slots');
assert(c.tTxSlot - c.tMacSlot == 28, 'access delay must be 28 slots');
assert(c.tGenSlot == 1000, 'tGenSlot must never move -- it is the one reference point');

%% ---- each boundary is crossed exactly once -------------------------------
% The failure this prevents: a restamped tx turns access delay into "delay of the last
% attempt", so every retransmitting UE looks slower than it is and nothing contradicts it.
c2 = sap.ctxInit(2, 1, 2, 55, 6, 100, 300, 4, 0);
c2 = sap.ctxStamp(c2, 'mac', 5);
mustError(@() sap.ctxStamp(c2, 'mac', 9), 'sap:ctxStamp:alreadyStamped', 'a second mac stamp');
c2 = sap.ctxTransmitted(c2, 20);
mustError(@() sap.ctxStamp(c2, 'tx', 40), 'sap:ctxStamp:alreadyStamped', 'a second tx stamp');
mustError(@() sap.ctxStamp(c2, 'bogus', 9), 'sap:ctxStamp:badEvent', 'an unknown event name');
mustError(@() sap.ctxStamp(c2, 'grant', -1), 'sap:ctxStamp:badSlot', 'a negative slot');

%% ---- causality ----------------------------------------------------------
c3 = sap.ctxInit(3, 1, 2, 55, 6, 100, 300, 4, 500);
mustError(@() sap.ctxStamp(c3, 'mac', 499), 'sap:ctxStamp:beforeGen', 'a stamp before generation');
c3 = sap.ctxStamp(c3, 'mac', 500);      % the same slot is legal: generated and enqueued at once
assert(c3.tMacSlot == 500, 'ctxStamp: stamping in the generation slot itself must be allowed');

%% ---- every packet resolves exactly once ---------------------------------
c4 = sap.ctxInit(4, 1, 2, 55, 6, 100, 300, 4, 0);
c4 = sap.ctxFinish(c4, codes.pdbExpired, 200);
assert(c4.outcome == codes.pdbExpired, 'ctxFinish: the expired outcome must stick');
assert(c4.tRxSlot == 0, 'ctxFinish: a PDB-expired packet was never received, so tRxSlot must stay 0');
mustError(@() sap.ctxFinish(c4, codes.delivered, 300), 'sap:ctxFinish:alreadyResolved', 'resolving twice');
mustError(@() sap.ctxFinish(sap.ctxInit(5, 1, 2, 55, 6, 100, 300, 4, 0), codes.inFlight, 10), 'sap:ctxFinish:notTerminal', 'inFlight as a terminal outcome');
mustError(@() sap.ctxFinish(sap.ctxInit(6, 1, 2, 55, 6, 100, 300, 4, 0), 99, 10), 'sap:ctxFinish:badOutcome', 'an outcome outside the code set');
% All four terminal codes are reachable and distinct.
term = [codes.delivered codes.pdbExpired codes.maxTx codes.dropped];
assert(numel(unique(term)) == 4 && ~any(term == codes.inFlight), 'outcomeCodes: the four terminal codes must be distinct and none may equal inFlight');
for k = 1:4
    ck = sap.ctxFinish(sap.ctxInit(10 + k, 1, 2, 55, 6, 100, 300, 4, 0), term(k), 50);
    assert(ck.outcome == term(k), 'ctxFinish: outcome %d must be settable', term(k));
end

%% ---- ctxInit validation --------------------------------------------------
mustError(@() sap.ctxInit(0, 1, 2, 55, 6, 100, 300, 4, 0), 'sap:ctxInit:badPktId', 'pktId 0');
mustError(@() sap.ctxInit(1, 2^24, 2, 55, 6, 100, 300, 4, 0), 'sap:ctxInit:badSrcId', 'a Layer-2 ID above 24 bits');
mustError(@() sap.ctxInit(1, 1, 2^24, 55, 6, 100, 300, 4, 0), 'sap:ctxInit:badDstId', 'a destination ID above 24 bits');
mustError(@() sap.ctxInit(1, 1, 2, 55, 0, 100, 300, 4, 0), 'sap:ctxInit:badPrio', 'priority 0 (1 is the highest)');
mustError(@() sap.ctxInit(1, 1, 2, 55, 9, 100, 300, 4, 0), 'sap:ctxInit:badPrio', 'priority 9');
mustError(@() sap.ctxInit(1, 1, 2, 55, 6, 0, 300, 4, 0), 'sap:ctxInit:badPdb', 'a zero PDB');
mustError(@() sap.ctxInit(1, 1, 2, 55, 6, 100, 0, 4, 0), 'sap:ctxInit:badSize', 'a zero-byte SDU');
mustError(@() sap.ctxInit(1, 1, 2, 55, 6, 100, 300, 64, 0), 'sap:ctxInit:badLcid', 'an LCID above the 6-bit field');
% The 24-bit boundary itself is legal.
cMax = sap.ctxInit(1, 2^24 - 1, 2^24 - 1, 55, 6, 100, 300, 63, 0);
assert(cMax.srcL2Id == 2^24 - 1 && cMax.lcid == 63, 'ctxInit: the top of each field range must be accepted');

%% ---- the PDB the context carries agrees with the policy's view -----------
% Both read pqiTable's PDB_ms, so a context and phy.rx.policy must never disagree about how
% much budget a packet has. mu=1: 100 ms is 200 slots.
t = cfg.pqiTable();
row = t([t.PQI] == 55);
cp  = sap.ctxInit(20, 1, 2, row.PQI, row.priority, row.PDB_ms, 300, 4, 0);
[remaining, expired] = phy.rx.policy.remainingPdbSlots(cp.pdbMs, cp.tGenSlot, 0, 1);
assert(remaining == 200 && ~expired, 'the context PDB and the policy must agree: expected 200 slots, got %d', remaining);
[~, ~, feasible] = phy.rx.policy.selectionWindow(1, remaining);
assert(feasible, 'a fresh PQI 55 packet must have a feasible selection window');

fprintf('test_ctx: all assertions passed.\n');
end

function mustError(fh, expectedId, what)
try
    fh();
catch e
    assert(strcmp(e.identifier, expectedId), 'expected %s for %s, got %s', expectedId, what, e.identifier);
    return;
end
error('test_ctx:noError', 'expected an error for %s, none raised', what);
end
