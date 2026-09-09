function g = grantOnTransmission(g, oppIndex)
%grantOnTransmission Mark one transmission opportunity of the current period as used.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.3.1a (the Sidelink process generating a transmission)
%        and clause 5.22.1.2 (the sl-ReselectAfter unused-opportunity count). This function does
%        the bookkeeping WITHIN a reservation period; grantOnPeriodEnd does the per-period
%        transitions (counter decrement, unused-period count, keep draw).
%Inputs: g          struct with a grant installed
%        oppIndex   integer, 1..nOpp -- which transmission opportunity of the current reservation
%                   period was actually transmitted on. Index 1 is the initial transmission
%                   opportunity, higher indices are retransmission opportunities (grantSelect
%                   fixes that ordering).
%Outputs: g  updated state with txOppUsed(oppIndex) set
%
%Marking the same opportunity twice is rejected rather than ignored: within one reservation
%period each opportunity is one PSSCH duration, so a repeat means the caller has lost track of
%which period it is in -- which is exactly the bug that makes the counter decrement at the wrong
%rate.
if ~g.hasGrant
    error('mac:grantOnTransmission:noGrant', 'grantOnTransmission: no selected sidelink grant is installed');
end
if ~isscalar(oppIndex) || mod(oppIndex, 1) ~= 0 || oppIndex < 1 || oppIndex > numel(g.txOppSlot)
    error('mac:grantOnTransmission:badIndex', 'grantOnTransmission: oppIndex must be an integer in 1..%d, got %s', numel(g.txOppSlot), num2str(oppIndex));
end
if g.txOppUsed(oppIndex)
    error('mac:grantOnTransmission:alreadyUsed', 'grantOnTransmission: opportunity %d is already marked used in the current reservation period; call grantOnPeriodEnd at the period boundary', oppIndex);
end
g.txOppUsed(oppIndex) = true;
end
