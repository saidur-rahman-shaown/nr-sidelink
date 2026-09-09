function due = trafficPeriodic(nowPhys, periodSlots, offsetSlots)
%trafficPeriodic Whether a periodic CAM-like message is generated in this slot.
%Spec:   ETSI EN 302 637-2 describes CAM generation as event- and dynamics-driven with a
%        100 ms to 1 s period. This models the FIXED-period case only, which is the standard
%        3GPP V2X evaluation assumption and the one the KPI curves are read against.
%Inputs: nowPhys      integer, >=0 -- current PHYSICAL slot
%        periodSlots  integer, >=1 -- generation period in physical slots
%        offsetSlots  integer, 0..periodSlots-1 -- per-UE phase. NOT zero for every UE: giving
%                     every UE the same offset synchronises the whole scenario's traffic and
%                     manufactures a collision pattern that has nothing to do with the resource
%                     selection being measured
%Outputs: due  logical
%
%Deterministic and stateless -- no RNG, no counter. A run is reproducible from its parameters
%alone, which +app/CLAUDE.md requires ("A KPI run that cannot be reproduced exactly is not a
%result") and which a stateful generator makes harder to guarantee.
%
%Aperiodic and variable-size generation are not built. They change the resource-selection
%problem qualitatively -- an aperiodic UE cannot use a periodic reservation at all -- so they
%are a separate model rather than a parameter of this one.

if ~(periodSlots >= 1 && mod(periodSlots, 1) == 0)
    error('app:trafficPeriodic:badPeriod', 'trafficPeriodic: periodSlots must be a positive integer, got %s', num2str(periodSlots));
end
if ~(offsetSlots >= 0 && offsetSlots < periodSlots && mod(offsetSlots, 1) == 0)
    error('app:trafficPeriodic:badOffset', 'trafficPeriodic: offsetSlots must be an integer in 0..%d, got %s', periodSlots - 1, num2str(offsetSlots));
end

due = mod(nowPhys - offsetSlots, periodSlots) == 0 && nowPhys >= offsetSlots;
end
