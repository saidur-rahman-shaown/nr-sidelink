function [triggered, conditions] = reselectionTrigger(c)
%reselectionTrigger TX resource (re-)selection check, TS 38.321 clause 5.22.1.2.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.2 "TX resource (re-)selection check". The clause is a
%        flat OR of seven conditions; if any holds, the MAC entity shall "clear the selected
%        sidelink grant associated to the Sidelink process, if available" and "trigger the TX
%        resource (re-)selection".
%Inputs: c  scalar struct, one logical field per clause-5.22.1.2 condition, in clause order.
%           Every field is REQUIRED -- there is no default, because a missing condition silently
%           reading as false is exactly how a trigger goes unnoticed:
%             .counterExpiredNotKept   SL_RESOURCE_RESELECTION_COUNTER = 0 AND the [0,1] draw
%                                      taken when it was equal to 1 was ABOVE sl-ProbResourceKeep.
%                                      This is the complement of keepDecision -- pass
%                                      ~keepDecision(draw, prob), never a fresh draw. Note the
%                                      clause makes counter==0 necessary but NOT sufficient: a
%                                      counter at 0 whose draw said "keep" does not trigger here,
%                                      it takes clause 5.22.1.1's reuse branch instead.
%             .poolReconfigured        "the pool of resources is configured or reconfigured by RRC"
%             .noSelectedGrant         "there is no selected sidelink grant on the selected pool
%                                      of resources" -- the boot case, and why a UE with nothing
%                                      selected always reselects rather than stalling.
%             .noTxLastSecond          "neither transmission nor retransmission has been performed
%                                      by the MAC entity on any resource indicated in the selected
%                                      sidelink grant during the last second". One SECOND of wall
%                                      clock, not a slot count and not a reservation period --
%                                      the caller converts.
%             .reselectAfterReached    "sl-ReselectAfter is configured and the number of
%                                      consecutive unused transmission opportunities on resources
%                                      indicated in the selected sidelink grant [...] is equal to
%                                      sl-ReselectAfter". EQUAL TO, not >= : see the trap below.
%             .cannotAccommodateSdu    "the selected sidelink grant cannot accommodate a RLC SDU
%                                      by using the maximum allowed MCS configured by RRC in
%                                      sl-MaxMCS-PSSCH [...] and the UE selects not to segment the
%                                      RLC SDU". Both halves: NOTE 1 makes segment-vs-reselect a
%                                      UE implementation choice, so the caller must have already
%                                      decided not to segment before setting this true.
%             .pdbNotMet               "transmission(s) with the selected sidelink grant cannot
%                                      fulfil the remaining PDB of the data in a logical channel,
%                                      and the MAC entity selects not to perform transmission(s)
%                                      corresponding to a single MAC PDU". Again both halves --
%                                      NOTE 2 makes the fallback a UE implementation choice.
%Outputs: triggered   logical scalar -- true if ANY condition holds, i.e. clear the grant and
%                     trigger reselection
%         conditions  1 x 7 logical row vector -- each condition's own value, in the clause order
%                     listed above. Returned so a caller (and the truth-table test) can assert
%                     WHICH condition fired rather than only that something did; a lifecycle log
%                     that records only `triggered` cannot be debugged.
%
%Every condition is evaluated; there is no short-circuit. The clause is an OR, so short-circuiting
%would be functionally equivalent, but it would make `conditions` a lie -- and two conditions
%firing at once is diagnostically different from one.
%
%KNOWN TRAPS:
%  - sl-ReselectAfter is "EQUAL TO", not ">=". The counter of consecutive unused opportunities is
%    incremented "by 1 when NONE of the resources of the selected sidelink grant within a resource
%    reservation interval is used" -- i.e. once per reservation period, not once per unused slot
%    or once per unused resource. Counting per slot inflates it and fires reselection early.
%    Resolving that count is the caller's job (grantOnTransmission tracks it); this function only
%    consumes the resulting predicate.
%  - counter==0 alone is NOT a trigger. The keep branch of clause 5.22.1.1 and the reselect branch
%    of clause 5.22.1.2 partition the counter==0 case by the sl-ProbResourceKeep draw, and getting
%    this wrong makes sl-ProbResourceKeep a no-op that nothing else would reveal.
required = {'counterExpiredNotKept', 'poolReconfigured', 'noSelectedGrant', 'noTxLastSecond', ...
            'reselectAfterReached', 'cannotAccommodateSdu', 'pdbNotMet'};
if ~isstruct(c) || ~isscalar(c)
    error('mac:reselectionTrigger:badInput', 'reselectionTrigger: c must be a scalar struct with one logical field per clause-5.22.1.2 condition');
end
missing = required(~isfield(c, required));
if ~isempty(missing)
    error('mac:reselectionTrigger:missingCondition', 'reselectionTrigger: missing condition field(s): %s. Every clause-5.22.1.2 condition must be stated explicitly; an absent one must not default to false', strjoin(missing, ', '));
end
extra = setdiff(fieldnames(c)', required);
if ~isempty(extra)
    error('mac:reselectionTrigger:unknownCondition', 'reselectionTrigger: unknown field(s): %s. Clause 5.22.1.2 has exactly %d conditions', strjoin(extra, ', '), numel(required));
end

conditions = false(1, numel(required));
for i = 1:numel(required)
    v = c.(required{i});
    if ~isscalar(v) || ~(islogical(v) || isnumeric(v))
        error('mac:reselectionTrigger:badCondition', 'reselectionTrigger: condition %s must be a logical scalar', required{i});
    end
    conditions(i) = logical(v);
end
triggered = any(conditions);   % clause 5.22.1.2 is a flat OR over its seven "1>" conditions
end
