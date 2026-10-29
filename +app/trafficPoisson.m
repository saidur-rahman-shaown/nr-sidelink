function due = trafficPoisson(u, meanPeriodSlots)
%trafficPoisson Whether an event-driven (Poisson) message is generated in this slot.
%Spec:   none. ETSI EN 302 637-3 DENMs and event-triggered CPM/sensor messages arrive when the
%        triggering event happens, not on a timer; the standard evaluation abstraction for such
%        traffic is a Poisson arrival process, which is what this models.
%Inputs: u                real in [0,1) -- ONE uniform draw for this slot and this generator,
%                         supplied by the caller from the scenario's single RNG stream. Taken as
%                         an input, not drawn here, so the function stays stateless and a run is
%                         reproducible from its seed alone (+app/CLAUDE.md)
%        meanPeriodSlots  real, >=1 -- mean inter-arrival time in PHYSICAL slots, 1/lambda
%Outputs: due  logical
%
%A Poisson process of rate lambda per slot puts at least one arrival in a slot with probability
%1 - exp(-lambda). One packet per due slot is generated, so for lambda << 1 (every realistic event
%rate: a 100 ms mean is lambda = 0.005 at 30 kHz) the slotted process is Poisson to within
%lambda^2/2 of the arrivals, and the inter-arrival times are geometric -- the discrete exponential.
%
%Unlike the periodic generator there is no phase to stagger: independent draws per UE already
%desynchronise the population, which is the property trafficPeriodic's offsets exist to provide.

if ~(meanPeriodSlots >= 1)
    error('app:trafficPoisson:badPeriod', 'trafficPoisson: meanPeriodSlots must be >= 1, got %s', num2str(meanPeriodSlots));
end
if ~(u >= 0 && u < 1)
    error('app:trafficPoisson:badDraw', 'trafficPoisson: u must be a uniform draw in [0,1), got %s', num2str(u));
end
due = u < 1 - exp(-1 / meanPeriodSlots);
end
