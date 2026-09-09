function g = grantInit()
%grantInit Create an empty selected-sidelink-grant lifecycle state.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.1 (selected sidelink grant) and clause 5.22.1.3.1a
%        (the Sidelink process and its SL_RESOURCE_RESELECTION_COUNTER). Structure only; the
%        transitions are in grantSelect / grantOnTransmission / grantClear.
%Outputs: g  scalar struct, the whole lifecycle state, explicit and serialisable (the
%            normative-packages rule bans persistent/global, so every bit of a UE's grant state
%            lives here and can be diffed or replayed):
%              .hasGrant            logical -- whether a selected sidelink grant exists at all.
%                                   False here is exactly clause 5.22.1.2's "there is no selected
%                                   sidelink grant" reselection condition.
%              .isPeriodic          logical -- whether this grant is for transmissions of MULTIPLE
%                                   MAC PDUs (clause 5.22.1.3.1a: only then does the counter
%                                   exist). False for a single-MAC-PDU grant.
%              .pRsvpTxMs           real, >=0 -- P_rsvp_TX, the resource reservation interval in
%                                   ms; 0 when aperiodic
%              .counter             integer, >=0 -- SL_RESOURCE_RESELECTION_COUNTER. Meaningful
%                                   only where isPeriodic; 0 otherwise.
%              .txOppSlot           1 x nOpp integer row vector -- logical pool slot of each
%                                   transmission opportunity in ONE reservation period, ascending
%              .txOppStartSubch     1 x nOpp integer row vector -- starting sub-channel of each,
%                                   same order
%              .txOppUsed           1 x nOpp logical row vector -- whether each opportunity has
%                                   been used in the CURRENT reservation period; reset at each
%                                   period boundary by grantOnTransmission
%              .lSubch              integer, >=1 -- L_subCH, sub-channels per opportunity (one
%                                   value for the whole grant: clause 5.22.1.1 selects "an amount
%                                   of frequency resources" once per (re)selection)
%              .consecutiveUnusedPeriods  integer, >=0 -- the sl-ReselectAfter counter, which
%                                   clause 5.22.1.2 increments "by 1 when NONE of the resources
%                                   of the selected sidelink grant within a resource reservation
%                                   interval is used" -- per PERIOD, never per slot
%              .keepDrawPending     logical -- whether a sl-ProbResourceKeep draw has been
%                                   captured for this grant. Clause 5.22.1.1/5.22.1.2 take the
%                                   draw "when SL_RESOURCE_RESELECTION_COUNTER WAS EQUAL TO 1"
%                                   and act on it at 0, so it must be stored across one MAC PDU
%                                   rather than taken fresh at expiry -- see keepDecision.m.
%              .keepDraw            real in [0,1] -- the captured draw; meaningful only where
%                                   keepDrawPending
%
%Fixed-width parallel arrays rather than a cell array or a nested struct array, per the
%normative-packages rule -- same shape as +phy/+ts38214/'s sensing database.
g.hasGrant = false;
g.isPeriodic = false;
g.pRsvpTxMs = 0;
g.counter = 0;
g.txOppSlot = zeros(1, 0);
g.txOppStartSubch = zeros(1, 0);
g.txOppUsed = false(1, 0);
g.lSubch = 0;
g.consecutiveUnusedPeriods = 0;
g.keepDrawPending = false;
g.keepDraw = 0;
end
