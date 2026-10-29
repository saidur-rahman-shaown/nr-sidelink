function c = twoUeConfig()
%twoUeConfig THE ONE FILE TO EDIT for the two-UE latency experiment.
%
%   r = runTwoUe();      % runs it with this configuration, prints the numbers, saves the figure
%
%   UE 1 sends one flow to UE 2 at a fixed distance, nothing else on the channel, through the FULL
%   stack at waveform level (harness.deploy.run): application -> SDAP -> PDCP -> RLC -> MAC -> PHY ->
%   IQ at 30.72 Msps -> transmitter hardware (PA at 23 dBm) -> channel (path loss, TDL-D fading,
%   propagation delay, thermal noise) -> receiver hardware (AGC, ADC) -> PHY -> MAC -> RLC -> PDCP
%   -> SDAP -> application. Output: the latency of every packet as a line plot, a box plot and a
%   CDF (experiments.twoUeLatency).
%
%   Fixed elsewhere, on purpose:
%   - the 3GPP configuration (BWP, pool, bearers, PDCP discard = PDB, RLC, MAC, PSFCH) comes from
%     the stored preconfiguration +cfg/configs/preconfig_example.json, as a UE out of coverage gets it;
%   - the study's timing (+experiments/settings.m): T1 = 5 slots, T2 = PDB - 3 slots, latency =
%     delivery slot - generation + 1 slot on the air + 2 slots to receive;
%   - the number of blind retransmissions is the preconfiguration's sl-MaxNumPerReserve, and
%     sl-ReselectAfter comes from it too (sl-UE-SelectedPreConfig); the keep probability is below.
%   Cost: roughly 1-2 s of wall clock per second of air time for two UEs; 1000 packets at 10 Hz is
%   100 s of air.

% =====================================================================================
% TRAFFIC
% =====================================================================================
% The PQI sets the PDB, the PER target and the priority (TS 23.287 Table 5.4.4-1). It must be mapped
% to a sidelink radio bearer in the stored preconfiguration: broadcast 56 (20 ms, SLRB 2) or
% 58 (100 ms, SLRB 1). Others need an SLRB added to the JSON first.
c.pqi       = 56;
c.periodMs  = 100;           % 100 ms = 10 Hz, periodic. A whole number of 0.5 ms slots
c.sizeBytes = 300;           % application payload per packet
c.nPackets  = 1000;          % the run lasts until this many have been generated and resolved
c.mcs       = 11;            % PSSCH MCS (QPSK 0-9, 16QAM 10-16, 64QAM 17-27 in the default table)
c.prsvpTxMs = 100;           % P_rsvp_TX: 100 = sensing-based SPS (one grant reused every 100 ms,
                             %   as a production UE runs periodic traffic); 0 = a new selection
                             %   per packet. Must be in the pool's sl-ResourceReservePeriodList {0, 100}
c.probResourceKeep = 0.8;    % sl-ProbResourceKeep: when an SPS grant's reselection counter runs
                             %   out, the chance it KEEPS its resources (with a new counter) instead
                             %   of reselecting (TS 38.321 5.22.1.1). One of {0 0.2 0.4 0.6 0.8}.
                             %   0.8 = the SAE J3161 deployment-profile value, also the stored
                             %   preconfiguration's default; [] = use the stored one

% =====================================================================================
% GEOMETRY
% =====================================================================================
c.distM     = 100;           % TX-RX distance, metres; both UEs static

% =====================================================================================
% CHANNEL
% =====================================================================================
c.link.plModel        = 'rma';   % 'rma' (TR 38.901 Rural Macro) or 'freespace'
c.link.losMode        = 'los';   % RMa only: 'los' or 'nlos'
c.link.antennaHeightM = 3;       % both ends; RMa's breakpoint 2*pi*h^2*fc/c depends on it
c.link.antennaGainDb  = 6;       % TX + RX combined (3 dBi each)
c.link.noiseFigureDb  = 9;       % TR 37.885 V15.3.0 Table 6.1.1-1 (vehicle / pedestrian UE)
c.speedMph            = 20;      % Doppler speed of the TDL-D channel (any value: the fading is real)
c.delaySpreadNs       = 100;     % TDL-D delay spread

% =====================================================================================
% HARDWARE AND UE IMPLEMENTATION
% =====================================================================================
c.hw            = rf.hwDefaults();   % PA (23 dBm out, Rapp), IQ imbalance, phase noise, CFO, ADC
c.tReorderingMs = 10;                % PDCP t-Reordering at the receiver (UE choice, TS 38.331 9.1.1.5)

% =====================================================================================
% RUN
% =====================================================================================
c.seed      = 5;             % traffic phase, selections, fading, noise
c.nWorkers  = 2;             % parallel workers (each owns one UE)
end
