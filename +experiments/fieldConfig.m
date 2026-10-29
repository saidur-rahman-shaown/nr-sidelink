function f = fieldConfig()
%fieldConfig THE ONE STRUCT TO EDIT for the multi-UE field experiments (field, eventStrategy,
%cbrCapacity). Every field is a fieldScenario override; see +experiments/private/fieldScenario.m.
%
%   f = experiments.fieldConfig(); f.densityPerKm2 = 400; r = experiments.field([], f);
%
%UEs are a Poisson point process: N ~ Poisson(densityPerKm2 x area), positions uniform. Set
%densityPerKm2 = [] and nUe = N to fix the count instead.
f.sizeM          = [500 500];   % field, metres (configurable)
f.densityPerKm2  = 160;         % PPP intensity: 160 /km^2 -> mean 40 UEs in 500 m x 500 m
f.nUe            = 40;          % used only when densityPerKm2 is []
f.dropSeed       = 7;           % placement
f.seed           = 11;          % traffic and channel draws
f.durationS      = 10;          % simulated air time, seconds (t in the request)
f.rangeM         = 300;         % intended-receiver range for per-link PRR / latency
f.mcs            = 7;           % must be a row of harness.phyabs.blerTable: 4 7 11 16 20
f.prsvpTxMs      = 100;         % P_rsvp_TX
f.numRetx        = 1;           % blind retransmissions
f.castType       = 'broadcast';
f.policy         = struct('t2MaxMs', Inf);
% Periodic awareness (CAM, ETSI EN 302 637-2) and event-driven warnings (DENM-like, Poisson).
f.flows = struct('pqi', {58, 56}, 'periodMs', {100, 500}, 'sizeBytes', {300, 250}, ...
    'lcid', {4, 5}, 'nPackets', {inf, inf}, 'pdbMsOverride', {[], []}, ...
    'arrival', {'periodic', 'poisson'});
end
