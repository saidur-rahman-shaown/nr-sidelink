function s = settings()
%settings Shared settings for every experiment in +experiments/: where output goes, and how big.
%Spec:   none -- experiment configuration. Ours, not normative.
%Outputs: s  scalar struct:
%   .plotRoot   char -- figures go to <plotRoot>/<experiment>/
%   .dataRoot   char -- each experiment saves its raw results to <dataRoot>/<experiment>.mat
%   .scale      'full' or 'quick'. quick shrinks run lengths and sweep grids about 5x so the
%               whole suite can be smoke-tested in minutes; full is what the report figures use.
%               Override per call: s = experiments.settings(); s.scale = 'quick';
%   .seeds      integer vector -- independent drops/traffic seeds averaged in the SLS sweeps
%   .useParallel logical -- parfor over sweep points when the Parallel Computing Toolbox is present
%   .radio      the channel every experiment shares, so link-level and system-level results
%               describe the same world:
%                 .channel   TDL profile; also the key the shipped BLER table was measured under
%                 .speedKmh  Doppler speed, |v_i| + |v_j| (see harness.chanmodel.tdlChannel)
%                 .delaySpreadNs
%                 .fcHz, .pCmaxDbm, .noiseFigureDb, .losMode, .hAntM
%
%Change these here and every experiment follows; an experiment never re-declares them.

s.plotRoot    = fullfile('plots', 'experiments');
s.dataRoot    = fullfile('plots', 'experiments', 'data');
s.scale       = 'full';
s.seeds       = [7 11 23];
s.useParallel = ~isempty(ver('parallel'));
s.nWorkers    = 6;      % a 120-UE SLS run needs ~1-2 GB; more workers than RAM/2 GB thrashes

% THE OPERATING POINT every experiment runs at: a 20 MHz ITS channel at 30 kHz SCS (mu = 1), which
% TS 38.101-1 Table 5.3.2-1 fills with 51 PRB; the stored preconfiguration's BWP uses 50 of them as
% 5 sub-channels x 10 PRB. Every SLS run is checked against this by runLogged (assertOperatingPoint)
% and every LLS curve by its .meta, so a run cannot silently fall back to the SLS's own default
% pool (10 x 10 PRB = a 40 MHz channel), which the first version of this suite did.
s.op = struct('mu', 1, 'scsKHz', 30, 'channelMHz', 20, 'numSubchannel', 5, 'subchSizeRb', 10, ...
    'pCmaxDbm', 23, 'plModel', 'rma', 'txSlots', 1, 'rxProcSlots', 2, 'decodeMarginSlots', 2);
% THE LATENCY PIPELINE. A packet that arrives in slot n and is sent in slot n + k is delivered at
% n + k + txSlots + rxProcSlots: the transmission slot itself (the TB was built during T1, which is
% what T_proc,1 is for), then two for the receiver to demodulate, decode and hand it up. So the shortest possible latency is
% T1 + 3 slots = 8 slots = 4 ms at mu = 1, and a packet meets its PDB only if k <= PDB - 3 slots:
% the selection window ends at T2 = PDB - 3 slots, so that the transmission ENDS 2 slots before
% the deadline. In the SLS that is decodeMarginSlots = rxProcSlots (phy.rx.policy.pdbLogicalSlots:
% the last start is n + PDB - margin - 1); every latency the study reports adds the 3 slots
% (private/linkPackets).
% THE LINK every study part uses (Parts B and C, and Part A's SLS runs). Every value is a stated
% deployment assumption or a standard figure, not a fitted one:
%   path loss       TR 38.901 RMa, LOS (an open agricultural field), harness.chanmodel.pathloss
%   antenna height  3 m at both ends: agricultural machinery, antenna on the cab roof (TR 37.885's
%                   passenger-vehicle default is 1.5 m)
%   antenna gain    3 dBi per antenna, 6 dB combined (TX + RX)
%   noise figure    9 dB, TR 37.885 V15.3.0 Table 6.1.1-1 (vehicle and pedestrian UE)
%   speed           the BLER tables are read at 20 mph (TDL-D, measured by experiments.measureSpeeds)
% With these, MCS 5's first transmission reaches ~1500 m, which is what the field showed. Note RMa
% is specified for base stations at 10-150 m; at 3 m both ends its breakpoint distance is
% 2*pi*h*h*fc/c = 1112 m, beyond which the loss grows at 40 dB per decade.
s.link = struct('plModel', 'rma', 'losMode', 'los', 'antennaHeightM', 3, 'antennaGainDbi', 3, ...
    'antennaGainDb', 6, 'noiseFigureDb', 9, 'speedKmh', 20 * 1.609344);

s.radio = struct( ...
    'channel',       'TDL-D', ...   % LOS multipath; the shipped BLER table's key is 'tdld'
    'speedKmh',      120, ...       % two vehicles at 60 km/h, double mobility
    'delaySpreadNs', 100, ...
    'fcHz',          5.9e9, ...     % ITS band
    'pCmaxDbm',      23, ...
    'noiseFigureDb', 9, ...         % TR 37.885 V15.3.0 Table 6.1.1-1
    'losMode',       'los', ...
    'hAntM',         s.link.antennaHeightM);
end
