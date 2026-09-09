function ctx = ctxFinish(ctx, outcome, slot)
%ctxFinish Resolve a packet, recording how it ended.
%Spec:   none -- KPI bookkeeping.
%Inputs: ctx      scalar struct from +sap/ctxInit
%        outcome  integer -- a field of +sap/outcomeCodes, other than .inFlight
%        slot     integer, >= ctx.tGenSlot -- PHYSICAL slot at which it resolved. For
%                 .delivered this is the decode slot and is also stamped as 'rx'.
%Outputs: ctx  with .outcome set, and .tRxSlot set on delivery
%
%Every packet must end here exactly once, whatever the ending. A packet left .inFlight at the
%end of a run is neither a success nor a loss and quietly leaves the denominator, which is the
%arithmetic that makes a reliability figure look better than the run was. The harness asserts
%no context is still .inFlight when it stops.
%
%.pdbExpired IS A LOSS. It is a separate code from .delivered only so the run can report WHY it
%failed; every reliability figure counts it on the failure side. See
%+phy/+rx/+policy/CLAUDE.md -- a late packet scored as a slow success inflates throughput and
%truncates the latency tail at once, in the same direction, with nothing to contradict it.

codes = sap.outcomeCodes();
if ctx.outcome ~= codes.inFlight
    error('sap:ctxFinish:alreadyResolved', 'ctxFinish: packet %s already resolved with outcome %s', num2str(ctx.pktId), num2str(ctx.outcome));
end
if outcome == codes.inFlight
    error('sap:ctxFinish:notTerminal', 'ctxFinish: inFlight is not a terminal outcome');
end
if ~any(outcome == [codes.delivered codes.pdbExpired codes.maxTx codes.dropped])
    error('sap:ctxFinish:badOutcome', 'ctxFinish: outcome %s is not one of +sap/outcomeCodes', num2str(outcome));
end

if outcome == codes.delivered
    ctx = sap.ctxStamp(ctx, 'rx', slot);
end
ctx.outcome = outcome;
end
