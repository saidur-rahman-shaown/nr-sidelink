function test_lch()
%test_lch Unit tests for the MAC SAP -- logical channels into MAC.
%SPEC: the SAP is TS 38.321 Figure 4.2.2-3's upper boundary (SBCCH/SCCH/STCH); the per-channel
%      parameters are clause 5.22.1.4.1.1's. The queue is ours. What is asserted is that the
%      vectors handed to +mac/slLcp are in the exact shape it documents, that PDB expiry
%      removes packets as LOSSES, and that no context is created or lost by a queue operation.

codes = sap.outcomeCodes();

%% ---- construction --------------------------------------------------------
% Two Destinations: channels 1-2 share one, channel 3 has its own. Priorities deliberately not
% in channel order, since 1 is the HIGHEST and the ordering is what slLcp inverts.
lch = sap.lchInit([4 5 6], [3 1 5], [200 200 300], [1e5 2e5 5e4], [0.1 0.1 0.1], logical([1 1 0]));
assert(lch.nLch == 3 && isequal(lch.Sbj, [0 0 0]), 'lchInit: buckets must start at zero');
assert(isempty(lch.q) && isempty(lch.qLch), 'lchInit: the queue must start empty');
assert(isequal(sap.lchDataAvailable(lch), [0 0 0]), 'lchDataAvailable: an empty set must report zero on every channel');
mustError(@() sap.lchInit([4 4], [1 1], [1 1], [1 1], [1 1], logical([1 1])), 'sap:lchInit:duplicateLcid', 'duplicate LCIDs');
mustError(@() sap.lchInit([4 5], [1 1 1], [1 1], [1 1], [1 1], logical([1 1])), 'sap:lchInit:sizeMismatch', 'mismatched parameter lengths');
mustError(@() sap.lchInit(4, 0, 1, 1, 1, true), 'sap:lchInit:badPrio', 'priority 0');
mustError(@() sap.lchInit(64, 1, 1, 1, 1, true), 'sap:lchInit:badLcid', 'an LCID above the 6-bit field');

%% ---- enqueue: the entry point --------------------------------------------
% PQI 55, 100 ms PDB, on lcid 4 (destination 200).
c1 = sap.ctxInit(1, 100, 200, 55, 3, 100, 300, 4, 10);
lch = sap.lchEnqueue(lch, c1, 12);
assert(lch.q(1).tMacSlot == 12, 'lchEnqueue: arrival must be stamped at the MAC SAP, got %d', lch.q(1).tMacSlot);
assert(lch.q(1).tGenSlot == 10, 'lchEnqueue: generation time must be untouched');
assert(lch.qLch(1) == 1, 'lchEnqueue: lcid 4 is channel 1');
assert(isequal(sap.lchDataAvailable(lch), [300 0 0]), 'lchDataAvailable: 300 bytes on channel 1');
% Routing is by lcid, and the destination must agree -- a context on the wrong Destination is a
% caller bug, not something to silently re-home.
mustError(@() sap.lchEnqueue(lch, sap.ctxInit(2, 100, 200, 55, 3, 100, 300, 9, 10), 12), 'sap:lchEnqueue:noSuchLcid', 'an unknown LCID');
mustError(@() sap.lchEnqueue(lch, sap.ctxInit(2, 100, 999, 55, 3, 100, 300, 4, 10), 12), 'sap:lchEnqueue:dstMismatch', 'a destination that disagrees with the channel');

% Fill all three channels and check the vector is exactly slLcp's shape.
lch = sap.lchEnqueue(lch, sap.ctxInit(2, 100, 200, 55, 3, 100, 200, 4, 10), 12);
lch = sap.lchEnqueue(lch, sap.ctxInit(3, 100, 200, 55, 1, 100, 500, 5, 11), 13);
lch = sap.lchEnqueue(lch, sap.ctxInit(4, 100, 300, 55, 5, 100, 150, 6, 11), 13);
avail = sap.lchDataAvailable(lch);
assert(isequal(avail, [500 500 150]), 'lchDataAvailable: expected [500 500 150], got %s', mat2str(avail));
assert(isrow(avail) && numel(avail) == lch.nLch, 'lchDataAvailable: must be the 1-by-nLch row vector slLcp documents');

%% ---- it composes with +mac/slLcp -----------------------------------------
% The point of this SAP: its outputs are slLcp's inputs, with no adaptation in between.
eligible = lch.dstL2Id == 200;                        % serve Destination 200 this grant
[alloc, ~, selected] = mac.slLcp(lch.Sbj, lch.prio, avail, lch.harqFeedbackEnabled, eligible, 400);
assert(numel(alloc) == lch.nLch, 'slLcp must accept the SAP''s vectors unchanged');
assert(~selected(3), 'the channel on the other Destination must not be selected');
assert(sum(alloc) <= 400, 'slLcp must not over-allocate the grant');
% Channel 2 has priority 1, the highest, so it is served first and takes the whole 400.
assert(alloc(2) == 400, 'the highest-priority channel must be served first, got %s', mat2str(alloc));

%% ---- dequeue: whole SDUs, oldest first -----------------------------------
% Channel 1 holds 300 then 200 bytes. An allocation of 300 takes only the first.
[lchD, served] = sap.lchDequeue(lch, [300 0 0]);
assert(numel(served) == 1 && served.pktId == 1, 'lchDequeue: a 300-byte allocation must take exactly the 300-byte head SDU');
assert(isequal(sap.lchDataAvailable(lchD), [200 500 150]), 'lchDequeue: the rest must stay queued');
% 250 bytes cannot fit the 300-byte head, but CAN fit the 200-byte SDU behind it. Documented
% departure from strict head-of-line blocking; assert it deliberately so a change is visible.
[~, served2] = sap.lchDequeue(lch, [250 0 0]);
assert(numel(served2) == 1 && served2.pktId == 2, 'lchDequeue: a smaller later SDU must be taken when the head does not fit');
% Nothing is created or lost: served + remaining == what went in.
[lchD3, served3] = sap.lchDequeue(lch, [500 500 150]);
assert(numel(served3) + numel(lchD3.q) == numel(lch.q), 'lchDequeue: contexts must be conserved');
assert(isempty(lchD3.q), 'lchDequeue: an allocation covering everything must empty the queue');
mustError(@() sap.lchDequeue(lch, [1 1]), 'sap:lchDequeue:sizeMismatch', 'an allocation vector of the wrong length');
mustError(@() sap.lchDequeue(lch, [-1 0 0]), 'sap:lchDequeue:negativeAlloc', 'a negative allocation');

%% ---- expiry: a dead packet is a LOSS, and leaves the queue ---------------
% mu=1, so the 100 ms PDB is 200 physical slots. Packet 1 was generated at slot 10.
mu = 1;
[lchE, expired] = sap.lchExpire(lch, 100, mu);
assert(isempty(expired) && numel(lchE.q) == 4, 'lchExpire: nothing may expire before its budget runs out');
% At slot 210 the packets generated at slot 10 are exactly spent; those from slot 11 are not.
[lchE, expired] = sap.lchExpire(lch, 210, mu);
assert(numel(expired) == 2, 'lchExpire: the two slot-10 packets must expire at slot 210, got %d', numel(expired));
assert(all([expired.outcome] == codes.pdbExpired), 'lchExpire: an expired packet must be resolved as a LOSS, not left in flight');
assert(all([expired.tRxSlot] == 0), 'lchExpire: an expired packet was never received');
assert(numel(lchE.q) == 2 && isequal(sap.lchDataAvailable(lchE), [0 500 150]), 'lchExpire: expired packets must leave the queue');
% One slot earlier they are still alive -- the boundary is the budget's own, not one slot late.
[~, notYet] = sap.lchExpire(lch, 209, mu);
assert(isempty(notYet), 'lchExpire: the boundary must be the budget''s own slot, not one earlier');
% and the discard point agrees with the selection-window feasibility point, by construction.
[~, dead] = phy.rx.policy.remainingPdbSlots(100, 10, 210, mu);
assert(dead, 'the policy and the queue must agree on when a budget is spent');
% Conservation again: expired + remaining == what went in.
assert(numel(expired) + numel(lchE.q) == numel(lch.q), 'lchExpire: contexts must be conserved');

fprintf('test_lch: all assertions passed.\n');
end

function mustError(fh, expectedId, what)
try
    fh();
catch e
    assert(strcmp(e.identifier, expectedId), 'expected %s for %s, got %s', expectedId, what, e.identifier);
    return;
end
error('test_lch:noError', 'expected an error for %s, none raised', what);
end
