function c = simConfig()
%simConfig THE ONE FILE TO EDIT to define a simulation scenario.
%
%   Everything a run depends on is here. Edit this file, then:
%
%       k = runSim();          % runs it and plots latency and throughput
%
%   Nothing else needs changing for an ordinary experiment. The scenario is assembled from this
%   struct by harness.sls.scenarioFromConfig, which resolves every derived quantity (transport
%   block size, L_subCH, escalation bounds, measurement windows) from the values below rather
%   than letting them be set independently -- two sources of truth for one quantity is one too
%   many, and it is how a scenario ends up internally inconsistent.
%
%   Fields that are DERIVED and therefore absent here on purpose:
%     - L_subCH        comes from the MAC PDU size at the chosen MCS (clause 8.1.3.2)
%     - T1             is T_proc,1^SL from TS 38.214 Table 8.1.4-2: 5 slots at 30 kHz
%     - transport block size, MAC overhead, escalation bound, CBR/CR window lengths

% =====================================================================================
% LINK: who talks to whom
% =====================================================================================
% The default is the simplest useful case: ONE link, UE1 -> UE2.
c.link.nUe        = 2;            % number of UEs in the scenario
c.link.spacingM   = 100;          % separation between adjacent UEs, metres
c.link.txUeIds    = 1;            % which UEs GENERATE traffic. [] means all of them.
                                  %   1     -> a single link, UE1 transmitting to UE2
                                  %   []    -> every UE transmits (a full mesh)
c.link.castType   = 'unicast';    % 'unicast' (PSFCH feedback) or 'broadcast' (blind retx)

% =====================================================================================
% POOL: the shared resource pool both UEs are configured with (TS 38.331 SL-ResourcePool)
% =====================================================================================
c.pool.mu                 = 1;        % SCS configuration: 1 = 30 kHz, so a slot is 0.5 ms
c.pool.numSubchannel      = 10;       % sl-NumSubchannel
c.pool.subchSizeRb        = 10;       % sl-SubchannelSize, PRBs per sub-channel
c.pool.slLengthSymbols    = 12;       % sl-LengthSymbols
c.pool.pscchPrb           = 10;       % sl-FreqResourcePSCCH
c.pool.pscchSymbols       = 2;        % sl-TimeResourcePSCCH
c.pool.maxNumPerReserve   = 2;        % sl-MaxNumPerReserve (chained resources per SCI)
c.pool.sensingWindowMs    = 100;      % sl-SensingWindow
c.pool.selectionWindowRaw = 20;       % sl-SelectionWindow: T2min before numerology scaling
c.pool.thresRsrpDbm       = -110;     % sl-Thres-RSRP-List, one value for all priority pairs
c.pool.txPercentage       = 0.2;      % sl-TxPercentage: the size S_A must reach
c.pool.probResourceKeep   = 0.4;      % sl-ProbResourceKeep
c.pool.preemptionEnable   = 'enabled';% sl-PreemptionEnable: '', 'enabled', or 'pl1'..'pl8'
c.pool.psfchPeriodSlots   = 1;        % sl-PSFCH-Period; forced to 0 when castType is broadcast
c.pool.minTimeGapPsfch    = 2;        % sl-MinTimeGapPSFCH
c.pool.threshSRssiCbrDbm  = -94;      % sl-Thres-RSSI-CBR
c.pool.cbrRangeUpperBounds = [0.2 0.4 0.6 0.8 1.0];   % SL-CBR-LevelsConfig, as ratios
c.pool.crLimitByLevel      = [1.0 0.6 0.3 0.12 0.05]; % sl-CR-Limit per CBR level

% =====================================================================================
% APPLICATION: what traffic the transmitting UEs generate
% =====================================================================================
c.app.pqi            = 55;    % PC5 5QI -> priority and PDB come from +cfg/pqiTable
c.app.periodMs       = 100;   % generation period (CAM-like)
c.app.sizeBytes      = 300;   % SDU payload size
c.app.lcid           = 4;     % logical channel id (Table 6.2.4-1: 4..19 is STCH)
c.app.pdbMsOverride  = [];    % [] uses the PQI's own PDB; set a number to override it

% =====================================================================================
% SELECTION POLICY: the part the spec leaves to UE implementation
% =====================================================================================
% T1 is NOT here -- it is T_proc,1^SL from Table 8.1.4-2, which is 5 slots at 30 kHz. The
% policy takes that floor exactly, because it is the earliest a conformant UE can prepare a
% transmission. See phy.rx.policy.selectionWindow.
%
% T2 is the remaining PDB LESS the decoding allowance below. The PDB is a deadline for
% DELIVERY, so a packet transmitted exactly at the deadline is late by however long the
% receiver takes to decode it.
c.policy.decodeMarginSlots = 2;    % slots reserved for the receiver to decode.
                                   %   T2 = remaining PDB - this
c.policy.mcs               = 7;    % I_MCS (QPSK at 7 in every selectable table)
c.policy.prsvpTxMs         = 100;  % P_rsvp_TX, the reservation period
c.policy.numRetx           = 1;    % blind retransmissions beyond the initial transmission

% =====================================================================================
% RADIO
% =====================================================================================
c.radio.fcHz          = 5.9e9;    % ITS band
c.radio.noiseFigureDb = 9;
c.radio.pCmaxDbm      = 23;
c.radio.losMode       = 'los';    % 'los' or 'nlos' for the TR 38.901 RMa model
c.radio.hTxM          = 1.5;      % antenna heights, metres
c.radio.hRxM          = 1.5;

% =====================================================================================
% RUN
% =====================================================================================
c.sim.nSlots  = 4000;   % PHYSICAL slots. At mu=1 a slot is 0.5 ms, so 4000 = 2 s
c.sim.seed    = 7;      % reproduces a run exactly
c.sim.plot    = true;   % draw the latency and throughput figures
c.sim.plotDir = '';     % '' shows the figures; a path saves PNGs there instead
end
