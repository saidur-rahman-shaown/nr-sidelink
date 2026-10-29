function c = fieldConfig()
%fieldConfig THE ONE FILE TO EDIT for a waveform-level field scenario: N UEs dropped in a field.
%
%   r = runField();      % runs it, prints the report, returns the results
%
%   This is the waveform path: every packet goes app -> SDAP -> PDCP -> RLC -> MAC -> PHY -> IQ,
%   through a per-link path-loss + fading channel with thermal noise, and back up at every other
%   UE (+stack/, +harness/+field/). The radio configuration -- BWP, pool, PSCCH/PSSCH/PSFCH,
%   bearers, RLC/PDCP/MAC settings -- is NOT here: it comes from the stored preconfiguration
%   named below, exactly as a UE out of coverage would get it. This file holds only what the
%   preconfiguration cannot: where the UEs are, what the applications send, and the radio channel.
%
%   The scenario: five STATIC UEs dropped uniformly at random in a 1500 m x 1500 m field (an
%   open rural area -- RMa LOS). Every UE broadcasts CAMs. At t = 0.5 s UE3 detects a hazard and
%   broadcasts a DENM, repeated. UE1 runs a unicast sensor-sharing session with its nearest
%   neighbour, with HARQ feedback. Change c.ue.placementSeed for another drop.

c.cfgPath = '+cfg/configs/preconfig_example.json';     % the stored preconfiguration

% =====================================================================================
% UEs: N static UEs dropped uniformly at random in a field, and their Layer-2 IDs
% =====================================================================================
c.field.sizeM       = [1500 1500];     % x by y, metres
c.ue.n              = 5;
c.ue.placementSeed  = 7;               % the drop; independent of c.sim.seed (traffic, fading)
drop = RandStream('mt19937ar', 'Seed', c.ue.placementSeed);
c.ue.x    = rand(drop, 1, c.ue.n) * c.field.sizeM(1);
c.ue.y    = rand(drop, 1, c.ue.n) * c.field.sizeM(2);
c.ue.vMps = zeros(1, c.ue.n);          % static: no movement, no Doppler (speed is |v_i| + |v_j|)
c.ue.l2Id = hex2dec('100000') + (1:c.ue.n);
c.broadcastL2Id = hex2dec('FFFFFF');   % the ITS broadcast Destination Layer-2 ID

% =====================================================================================
% APPLICATIONS (ETSI ITS facilities layer, mapped to PC5 QoS by PQI)
% =====================================================================================
% CAM, ETSI EN 302 637-2: periodic awareness every 100 ms, every UE, broadcast.
c.cam.pqi = 58; c.cam.pfi = 1; c.cam.periodMs = 100; c.cam.sizeBytes = 300;
% DENM, ETSI EN 302 637-3: event-triggered warning, repeated while the event lasts. Broadcast,
% low latency (PQI 56: 20 ms PDB, priority 6 in +cfg/pqiTable, TS 23.287 Table 5.4.4-1).
c.denm.pqi = 56; c.denm.pfi = 2; c.denm.ueIdx = 3; c.denm.startMs = 500;
c.denm.repetitionMs = 100; c.denm.count = 5; c.denm.sizeBytes = 250;
% Unicast sensor sharing UE1 -> its nearest neighbour (PQI 23, GBR so unicast only, AM RLC, HARQ feedback on).
c.uni.pqi = 23; c.uni.pfi = 9; c.uni.from = 1; c.uni.periodMs = 100;
d = hypot(c.ue.x - c.ue.x(c.uni.from), c.ue.y - c.ue.y(c.uni.from));
d(c.uni.from) = Inf;
[~, c.uni.to] = min(d);                % the nearest neighbour of UE1
c.uni.sizeBytes = 400; c.uni.startMs = 50;

% =====================================================================================
% RADIO CHANNEL (the propagation between UEs -- not 3GPP configuration)
% =====================================================================================
c.radio.fcHz          = 5.9e9;      % ITS band, carrier the path loss and Doppler are evaluated at
c.radio.plModel       = 'rma';      % TR 38.901 Rural Macro (harness.chanmodel.pathlossModel)
c.radio.losMode       = 'los';
c.radio.hAntM         = 1.5;        % antenna height, both ends
c.radio.fading        = 'TDL-D';    % '' for no fading; TDL-D is the LOS multipath profile
c.radio.delaySpreadNs = 100;
c.radio.noiseFigureDb = 9;

% =====================================================================================
% UE IMPLEMENTATION CHOICES the specs leave open (everything else: stack.defaults)
% =====================================================================================
% PDCP t-Reordering at a groupcast/broadcast RECEIVER: TS 38.331 9.1.1.5 -- "selected by the
% receiving UE, up to UE implementation". TS 38.323 7.1 starts a new gc/bc receive entity half a
% window below the first SN it hears, so the FIRST packet from every new source waits this long.
% Against a 20 ms DENM PDB that is half the budget; 0 removes the hold (and reordering with it).
c.impl.tReorderingMs = 10;
% Mode-2 selection-window end T2 (TS 38.214 8.1.4: the UE picks T2 in [T2min, remaining PDB]).
% THIS IS THE LATENCY KNOB. Inf = T2 at the PDB, the resource drawn uniformly over the whole
% budget, so a 100 ms CAM waits ~50 ms on average even on an empty channel. A cap (ms) pulls T2
% toward T2min (20 ms here, from sl-SelectionWindowList n20 -- the floor), so access delay falls
% to ~T2/2 at the price of a smaller candidate set and more collisions.
c.impl.t2MaxMs = Inf;

% =====================================================================================
% RUN
% =====================================================================================
% The run lasts until c.sim.nPackets CAMs have been generated in total (200 per UE for 5 UEs:
% ~20 s of air time, ~7 min of wall clock with fading). Set durationMs (ms) to run for a fixed
% time instead; a non-empty durationMs wins.
c.sim.nPackets   = 1000;
c.sim.durationMs = [];
c.sim.seed       = 11;
end
