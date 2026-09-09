function Cresel = cresel(slResourceReselectionCounter, isPeriodic)
%cresel C_resel from SL_RESOURCE_RESELECTION_COUNTER.
%Spec:   TS 38.214 V16.17.0, clause 8.1.4 -- C_resel "= 10 * SL_RESOURCE_RESELECTION_COUNTER if
%        [the counter] is configured, else 1"; the counter itself is TS 38.321 V16.22.0 clause
%        5.22.1.3.1a, which is also what scopes when it exists: "If the Sidelink process is
%        configured to perform transmissions of multiple MAC PDUs with Sidelink resource
%        allocation mode 2, the process maintains a counter SL_RESOURCE_RESELECTION_COUNTER.
%        For other configurations of the Sidelink process, this counter is not available."
%Inputs: slResourceReselectionCounter  integer, >=0 -- the counter's current value, drawn from
%                                      creselCounterRange and decremented by grantOnTransmission.
%                                      Ignored when isPeriodic is false.
%        isPeriodic                    logical scalar -- whether this Sidelink process maintains
%                                      the counter at all, i.e. whether it is configured for
%                                      transmissions of MULTIPLE MAC PDUs in mode 2. False for a
%                                      single-MAC-PDU (aperiodic) grant, where clause 5.22.1.3.1a
%                                      says the counter "is not available" and TS 38.214's C_resel
%                                      falls back to 1. Carried as an explicit flag rather than
%                                      encoding absence as counter==0, per +cfg/CLAUDE.md's rule
%                                      that absence and zero are different things -- and here
%                                      they genuinely are: a periodic process whose counter has
%                                      reached 0 is at the reselection decision point, which is a
%                                      completely different state from an aperiodic process that
%                                      never had a counter.
%Outputs: Cresel  positive integer -- C_resel, the number of reserved periods. Feeds
%                 +phy/+ts38214/candidateSet as req.Cresel, where it bounds the j=0..C_resel-1
%                 projection of the UE's own future reservations (clause 8.1.5).
%
%KNOWN TRAP (+mac/CLAUDE.md names it first): C_resel is TEN TIMES the counter. The multiplier is
%written here explicitly rather than folded into creselCounterRange's draw bounds or into a
%constant, so that the counter and C_resel stay visibly different quantities. They are decremented
%and consumed by different things -- the COUNTER decrements once per MAC PDU (clause 5.22.1.3.1a:
%"if this transmission corresponds to the last transmission of the MAC PDU: decrement
%SL_RESOURCE_RESELECTION_COUNTER by 1"), while C_RESEL is a projection horizon handed to the
%physical layer and never decremented at all.
if ~isscalar(isPeriodic) || ~(islogical(isPeriodic) || isnumeric(isPeriodic))
    error('mac:cresel:badPeriodicFlag', 'cresel: isPeriodic must be a logical scalar');
end
if ~logical(isPeriodic)
    Cresel = 1;   % TS 38.214 clause 8.1.4: C_resel = 1 when the counter is not configured
    return;
end
if ~isscalar(slResourceReselectionCounter) || mod(slResourceReselectionCounter, 1) ~= 0 || slResourceReselectionCounter < 0
    error('mac:cresel:badCounter', 'cresel: slResourceReselectionCounter must be a nonnegative integer, got %s', num2str(slResourceReselectionCounter));
end
if slResourceReselectionCounter == 0
    error('mac:cresel:counterExpired', 'cresel: SL_RESOURCE_RESELECTION_COUNTER is 0, so this Sidelink process is at its reselection decision point and has no C_resel to report; resolve the keepDecision/reselectionTrigger branch first');
end

creselMultiplier = 10;   % TS 38.214 clause 8.1.4: C_resel = 10 * SL_RESOURCE_RESELECTION_COUNTER
Cresel = creselMultiplier * slResourceReselectionCounter;
end
