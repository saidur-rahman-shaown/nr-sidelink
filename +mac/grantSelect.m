function g = grantSelect(g, txOppSlot, txOppStartSubch, lSubch, pRsvpTxMs, isPeriodic, counter)
%grantSelect Install a selected sidelink grant, TS 38.321 clause 5.22.1.1.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.1 -- the steps taken once "the TX resource
%        (re-)selection is triggered as the result of the TX resource (re-)selection check":
%        select P_rsvp_TX from sl-ResourceReservePeriodList, draw SL_RESOURCE_RESELECTION_COUNTER,
%        select the number of HARQ retransmissions and the amount of frequency resources, pick
%        the transmission opportunities, and "consider the sets of initial transmission
%        opportunities and retransmission opportunities as the selected sidelink grant".
%Inputs: g                 struct from grantInit or a prior lifecycle call. Any existing grant is
%                          REPLACED -- clause 5.22.1.2 clears the old grant before reselection is
%                          triggered, so arriving here with one still installed is the caller
%                          having skipped that step, and is rejected.
%        txOppSlot         1 x nOpp integer row vector, ascending, no repeats -- the logical pool
%                          slot of each transmission opportunity within ONE reservation period.
%                          Element 1 is the initial transmission opportunity and the rest are
%                          retransmission opportunities: clause 5.22.1.1 says to "consider a
%                          transmission opportunity which comes first in time as the initial
%                          transmission opportunity and other transmission opportunities as the
%                          retransmission opportunities", which is why ascending order is
%                          enforced rather than merely expected.
%        txOppStartSubch   1 x nOpp integer row vector, >=0 -- starting sub-channel of each
%                          opportunity, in the same order
%        lSubch            integer, >=1 -- L_subCH, the "amount of frequency resources" selected
%                          once for the whole grant
%        pRsvpTxMs         real, >=0 -- P_rsvp_TX in ms; must be 0 exactly when ~isPeriodic
%        isPeriodic        logical -- whether this grant covers transmissions of MULTIPLE MAC PDUs
%        counter           integer -- the SL_RESOURCE_RESELECTION_COUNTER value the caller drew
%                          from creselCounterRange's [lo,hi]. Validated against that range here,
%                          which is the only place the draw and its bounds meet. Must be 0 when
%                          ~isPeriodic (clause 5.22.1.3.1a: the counter "is not available").
%Outputs: g  updated state with the grant installed, all opportunities marked unused, and the
%            sl-ReselectAfter and keep-draw bookkeeping reset -- a freshly selected grant has no
%            unused-period history and no pending draw.
%
%What this function deliberately does NOT do: choose anything. P_rsvp_TX, the counter draw, the
%retransmission count, L_subCH and the actual resources all arrive as inputs. Clause 5.22.1.1
%routes the resource choice through "randomly select the time and frequency resources [...] from
%the resources indicated by the physical layer as specified in clause 8.1.4 of TS 38.214", i.e.
%from +phy/+ts38214/candidateSet's S_A -- and +mac/CLAUDE.md fixes the division: "MAC calls
%+phy/+ts38214/candidateSet and selects uniformly from what comes back. The selection algorithm
%is not here; the trigger and the grant lifecycle are."
%
%One grant is NOT one transmission (+mac/CLAUDE.md's fourth known trap). It covers the initial
%transmission and its retransmission opportunities within a period, and then repeats at
%P_rsvp_TX for as long as the counter lasts. nOpp here is the count within ONE period.
if g.hasGrant
    error('mac:grantSelect:grantStillInstalled', 'grantSelect: a selected sidelink grant is already installed; clause 5.22.1.2 requires it be cleared (grantClear) before reselection installs a new one');
end
if ~isrow(txOppSlot) || isempty(txOppSlot)
    error('mac:grantSelect:badOpportunities', 'grantSelect: txOppSlot must be a non-empty row vector; a grant with no transmission opportunity is not a grant');
end
if ~isequal(size(txOppSlot), size(txOppStartSubch))
    error('mac:grantSelect:badOpportunities', 'grantSelect: txOppSlot and txOppStartSubch must be the same size, got %d and %d', numel(txOppSlot), numel(txOppStartSubch));
end
if any(mod(txOppSlot, 1) ~= 0) || any(mod(txOppStartSubch, 1) ~= 0) || any(txOppStartSubch < 0)
    error('mac:grantSelect:badOpportunities', 'grantSelect: txOppSlot must be integers and txOppStartSubch nonnegative integers');
end
if numel(txOppSlot) > 1 && any(diff(txOppSlot) <= 0)
    error('mac:grantSelect:notAscending', 'grantSelect: txOppSlot must be strictly ascending -- clause 5.22.1.1 identifies the initial transmission opportunity as the one "which comes first in time", so the order carries meaning');
end
if lSubch < 1 || mod(lSubch, 1) ~= 0
    error('mac:grantSelect:badLsubch', 'grantSelect: lSubch must be a positive integer (L_subCH), got %s', num2str(lSubch));
end
if ~isscalar(isPeriodic) || ~(islogical(isPeriodic) || isnumeric(isPeriodic))
    error('mac:grantSelect:badPeriodicFlag', 'grantSelect: isPeriodic must be a logical scalar');
end
isPeriodic = logical(isPeriodic);

if isPeriodic
    if pRsvpTxMs <= 0
        error('mac:grantSelect:badPeriod', 'grantSelect: a periodic grant needs pRsvpTxMs > 0, got %s', num2str(pRsvpTxMs));
    end
    [lo, hi] = mac.creselCounterRange(pRsvpTxMs);
    if counter < lo || counter > hi || mod(counter, 1) ~= 0
        error('mac:grantSelect:counterOutOfRange', 'grantSelect: SL_RESOURCE_RESELECTION_COUNTER must be an integer drawn from [%d,%d] for P_rsvp_TX=%s ms (clause 5.22.1.1), got %s', lo, hi, num2str(pRsvpTxMs), num2str(counter));
    end
else
    if pRsvpTxMs ~= 0
        error('mac:grantSelect:badPeriod', 'grantSelect: an aperiodic (single-MAC-PDU) grant must have pRsvpTxMs = 0, got %s', num2str(pRsvpTxMs));
    end
    if counter ~= 0
        error('mac:grantSelect:badCounter', 'grantSelect: an aperiodic grant maintains no SL_RESOURCE_RESELECTION_COUNTER (clause 5.22.1.3.1a), so counter must be 0, got %s', num2str(counter));
    end
end

g.hasGrant = true;
g.isPeriodic = isPeriodic;
g.pRsvpTxMs = pRsvpTxMs;
g.counter = counter;
g.txOppSlot = txOppSlot;
g.txOppStartSubch = txOppStartSubch;
g.txOppUsed = false(1, numel(txOppSlot));
g.lSubch = lSubch;
g.consecutiveUnusedPeriods = 0;
g.keepDrawPending = false;
g.keepDraw = 0;
end
