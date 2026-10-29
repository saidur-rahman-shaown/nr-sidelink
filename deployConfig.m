function c = deployConfig()
%deployConfig THE ONE FILE TO EDIT for the continuous-time, waveform-level multi-UE deployment.
%
%   r = runDeploy();          % runs it, prints per-UE statistics, writes figures
%
%   Every UE is a full +stack/ (SDAP..PHY) producing real IQ. Each transmitted slot goes through
%   that UE's transmitter hardware (rf.txHardware: DAC, IQ imbalance, phase noise, carrier error,
%   Rapp PA calibrated to 23 dBm at the antenna port), then, for every receiver, through its own
%   link: RMa path loss, a TDL-D fading channel advanced in continuous time, and the true
%   propagation delay plus both ends' timing errors. All arriving waveforms are ADDED, sample by
%   sample, in a continuous per-receiver stream (energy crosses slot boundaries), and the sum goes
%   through the receiver hardware (rf.rxHardware: thermal noise at the noise figure, LO error,
%   IQ imbalance, AGC on the AGC symbol, ADC) before the stack decodes it. Nothing about
%   interference is computed by formula: it is whatever the summed waveform does to the decoder.
%   The 3GPP configuration (pool, bearers, PSFCH, ...) comes from the stored preconfiguration.

c.cfgPath = '+cfg/configs/preconfig_example.json';

% =====================================================================================
% DEPLOYMENT: UEs as a Poisson point process, moving
% =====================================================================================
c.field.sizeM       = [500 500];   % metres
c.ue.densityPerKm2  = 160;         % PPP intensity -> N ~ Poisson(density x area); [] -> c.ue.n
c.ue.n              = 40;
c.ue.dropSeed       = 7;
c.ue.speedKmh       = [30 70];     % each UE drives at a uniform speed in this range ...
c.ue.headingDeg     = [];          % ... in a uniform random heading ([] = random per UE)
c.ue.boundary       = 'reflect';   % vehicles bounce off the field edge (no teleporting)
c.ue.xy             = [];          % N x 2 fixed positions (m) instead of the drop; [] = drop
c.broadcastL2Id     = hex2dec('FFFFFF');

% =====================================================================================
% TRAFFIC (ETSI ITS messages mapped to PC5 QoS by PQI)
% =====================================================================================
c.cam  = struct('pqi', 58, 'pfi', 1, 'periodMs', 100, 'sizeBytes', 300, 'txUe', []);   % periodic; txUe [] = every UE
c.evt  = struct('pqi', 56, 'pfi', 2, 'meanMs', 500, 'sizeBytes', 250);        % every UE, Poisson

% =====================================================================================
% RADIO CHANNEL
% =====================================================================================
c.radio.fcHz          = 5.9e9;
c.radio.plModel       = 'rma';
c.radio.losMode       = 'los';
c.radio.hAntM         = 1.5;
c.radio.fading        = 'TDL-D';   % per directed link, continuous in time; '' disables
c.radio.delaySpreadNs = 100;
c.radio.antennaGainDb = 0;         % TX + RX antenna gain combined, dB
c.radio.dopplerKmh    = [];        % [] = |v_i| + |v_j| per link; a number sets every link's Doppler
c.radio.pruneMarginDb = 15;        % a link is simulated while its mean received power is within
                                   % this margin BELOW the receiver's thermal noise; weaker links
                                   % are dropped from the graph (they cannot change a decision)

% =====================================================================================
% HARDWARE (rf.hwDefaults; edit there or override here)
% =====================================================================================
c.hw = rf.hwDefaults();

% =====================================================================================
% UE IMPLEMENTATION CHOICES (stack.defaults)
% =====================================================================================
c.impl.t2MaxMs       = Inf;
c.impl.tReorderingMs = 10;
c.impl.mcs           = 7;          % stack.defaults().mcs
c.impl.decodeMarginSlots = 0;      % 2 = T2 = PDB - 3 slots (1 slot on air + 2 to receive)
c.impl.prsvpTxMs     = 0;          % P_rsvp_TX: 0 = one selection per packet, 100 = sensing-based SPS

% =====================================================================================
% RUN
% =====================================================================================
% The run lasts until c.sim.nPackets CAMs have been generated in total over the dropped UEs (~40
% UEs: 25 each, ~2.6 s of air time, roughly 40-60 min of wall clock on 6 workers). The Poisson
% events run alongside at their own rate. Set durationMs (ms) to run for a fixed time instead.
c.sim.nPackets   = 1000;
c.sim.durationMs = [];
c.sim.seed       = 11;
c.sim.rangeM     = 300;            % intended receivers for per-link statistics
c.sim.nWorkers   = 6;              % parallel workers; each permanently owns a subset of UEs
c.sim.outDir     = fullfile('plots', 'deploy');
end
