classdef SidelinkPHYEntity < handle
%SidelinkPHYEntity NR Sidelink PHY layer entity for a single UE
%   Orchestrates the complete PHY processing pipeline using modular classes.
%   Each class handles one 3GPP spec section — no monolithic resource pool
%   calls. NRSidelinkResourcePool is used ONLY for resource allocation
%   (RE indices, DMRS, capacities) and carrier configuration.
%
%   Module responsibilities:
%     SidelinkSCIEncoder   — TS 38.212 Sec 8.3/8.4 (SCI polar coding)
%     SidelinkSLSCH        — TS 38.212 Sec 8.2/6.2 (SL-SCH LDPC coding)
%     SidelinkPSCCH        — TS 38.211 Sec 8.3     (PSCCH physical channel)
%     SidelinkPSSCH        — TS 38.211 Sec 8.4     (PSSCH physical channel)
%     NRSidelinkResourcePool — Resource indices, DMRS, TBS, carrier config
%
%   TX pipeline (per slot):
%     1. Get resources from pool (RE indices, DMRS, capacities)
%     2. SL-SCH: TB → LDPC encode → slschCW          (SidelinkSLSCH)
%     3. SCI1:   bits → Polar encode → sci1CW + NXID  (SidelinkSCIEncoder)
%     4. SCI2:   bits → Polar encode → sci2CW          (SidelinkSCIEncoder)
%     5. PSCCH:  sci1CW → scramble → QPSK → symbols   (SidelinkPSCCH)
%     6. PSSCH:  sci2CW+slschCW → scramble → mod → layer → symbols
%                                                       (SidelinkPSSCH)
%     7. Map symbols + DMRS to resource grid
%     8. OFDM modulate → baseband IQ
%
%   RX pipeline (per slot):
%     1. OFDM demodulate → resource grid
%     2. PSCCH: grid → demodulate → sci1LLR            (SidelinkPSCCH)
%     3. SCI1:  sci1LLR → Polar decode → sci1Bits+NXID (SidelinkSCIEncoder)
%     4. PSSCH: grid → demodulate → {sci2LLR, slschLLR}(SidelinkPSSCH)
%     5. SCI2:  sci2LLR → Polar decode → sci2Bits      (SidelinkSCIEncoder)
%     6. SL-SCH: slschLLR → LDPC decode → TB           (SidelinkSLSCH)
%
%   Properties:
%     Pool         - NRSidelinkResourcePool (resource calculator only)
%     Transmission - Transmission parameters struct
%     SLSCH        - SidelinkSLSCH transport channel processor
%
%   Methods:
%     transmitSlot    - Full modular TX processing for one slot
%     receiveSlot     - Full modular RX processing for one slot
%     getTBS          - Get TBS for current configuration
%     getResources    - Get PSCCH + PSSCH resources for current config
%     configureFromRMC- Configure from reference measurement channel

%   Copyright 2025. NR Sidelink Simulation Platform.
%   Spec refs: TS 38.211 (physical channels & modulation)
%              TS 38.212 (multiplexing & channel coding)
%              TS 38.214 Sec 8.1.3.2 (TBS determination)

    properties
        Pool             % NRSidelinkResourcePool (resource calc only)
        Transmission     % Transmission parameter struct
        SLSCH            % SidelinkSLSCH transport channel
        ChannelModel     % SidelinkChannelModel (optional)
    end

    properties (SetAccess = private)
        TBS        = 0   % Current transport block size
        TxCount    = 0
        RxCount    = 0
        ErrorCount = 0
    end

    methods
        function obj = SidelinkPHYEntity(varargin)
        %SidelinkPHYEntity Create PHY entity
        %   PHY = SidelinkPHYEntity()                        % defaults
        %   PHY = SidelinkPHYEntity('RMC', rmcName, bw, scs) % RMC preset (conformance)
        %   PHY = SidelinkPHYEntity('Pool', pool, 'Transmission', tx)
        %
        %   Preferred for simulation use:
        %     phy.configureFromParams(bw, scs, mod, cr, nSubch, nDMRS)

            if numel(varargin) >= 2 && strcmpi(varargin{1}, 'RMC')
                obj.configureFromRMC(varargin{2:end});
            else
                for i = 1:2:numel(varargin)
                    obj.(varargin{i}) = varargin{i+1};
                end
                if isempty(obj.Pool)
                    % No pool supplied — use direct params with defaults
                    obj.configureFromParams();
                    return;  % configureFromParams sets SLSCH and TBS
                end
            end

            if isempty(obj.SLSCH)
                obj.SLSCH = SidelinkSLSCH( ...
                    'MultipleHARQProcesses', true, ...
                    'TargetCodeRate', obj.Transmission.TargetCodeRate);
            end

            obj.TBS = obj.Pool.getTBS(obj.Transmission);
        end

        %% ==============================================================
        %  TX — fully modular, no transmitInPool
        %  ==============================================================

        function [baseband, txData] = transmitSlot(obj, sci1Bits, sci2Bits, trBlk)
        %transmitSlot Full modular TX processing for one slot
        %   [BB, TXDATA] = transmitSlot(PHY, SCI1, SCI2, TB)
        %   All args optional — [] or omit for auto-generate.

            tx = obj.Transmission;

            % --- Default inputs ---
            if nargin < 4 || isempty(trBlk)
                trBlk = randi([0 1], obj.TBS, 1);
            end
            if nargin < 2 || isempty(sci1Bits)
                sci1Bits = randi([0 1], tx.OSCI1, 1, 'int8');
            end
            if nargin < 3 || isempty(sci2Bits)
                sci2Bits = randi([0 1], tx.OSCI2, 1, 'int8');
            end

            % --- 1. PSCCH resources (don't need NXID) ---
            sloc = obj.Pool.getPSCCHResources(tx);

            % --- 2. SCI1 encode → get NXID (needed for PSSCH DMRS) ---
            [sci1CW, nxid] = SidelinkSCIEncoder.encodeSCI1( ...
                sci1Bits, sloc.PSCCHG);

            % --- 3. PSSCH resources (MUST use correct NXID for DMRS) ---
            tx.NXID = nxid;
            obj.Transmission.NXID = nxid;
            slod = obj.Pool.getPSSCHResources(tx);

            % --- 4. TS 38.212: Channel coding ---
            % SL-SCH: TB → LDPC encode (Sec 8.2 / 6.2, I_LBRM=0)
            obj.SLSCH.TargetCodeRate = tx.TargetCodeRate;
            slschCW = obj.SLSCH.encode(trBlk, tx.Modulation, ...
                tx.NumLayers, slod.PSSCHG(2), ...
                tx.RedundancyVersion, tx.HARQProcessID);

            % SCI2: Polar encode (Sec 8.4, I_BIL=1, G≤4096)
            sci2CW = SidelinkSCIEncoder.encodeSCI2( ...
                sci2Bits, slod.PSSCHG(1));

            % --- 5. TS 38.211: Physical channel processing ---
            % PSCCH: scramble(cinit=1010) → QPSK (Sec 8.3.1)
            pscchSym = SidelinkPSCCH.modulate(sci1CW);

            % PSSCH: scramble(cinit=2^15*NXID+1010) → mod → layer
            psschSym = SidelinkPSSCH.modulate( ...
                sci2CW, slschCW, tx, nxid);

            % --- 6. RE mapping + OFDM modulation ---
            carrier = obj.Pool.SCSCarrier;
            grid = nrResourceGrid(carrier, tx.NumLayers);

            % PSCCH
            grid(sloc.PSCCHIndices+1)     = pscchSym;
            grid(sloc.PSCCHDMRSIndices+1) = sloc.PSCCHDMRS;

            % PSSCH (DMRS now uses correct NXID)
            grid(slod.PSSCHIndices+1)     = psschSym;
            grid(slod.PSSCHDMRSIndices+1) = slod.PSSCHDMRS;

            % AGC symbol replication (symbol 0 = copy of symbol 1)
            startSym = obj.Pool.sl_StartSymbol_r16;
            grid(:, startSym+1, :) = grid(:, startSym+2, :);

            % OFDM modulate
            baseband = nrOFDMModulate(carrier, grid, 'Windowing', 0);

            % --- Build output data struct ---
            txData = struct();
            txData.ResourceGrid   = grid;
            txData.TransportBlock = trBlk;
            txData.TBS            = obj.TBS;
            txData.NXID           = nxid;
            txData.SCI1Bits       = sci1Bits;
            txData.SCI2Bits       = sci2Bits;
            txData.SLSCHBits      = trBlk;
            txData.PSCCHSymbols   = pscchSym;
            txData.PSSCHSymbols   = psschSym;
            txData.PSCCH          = sloc;
            txData.PSSCH          = slod;

            obj.TxCount = obj.TxCount + 1;
        end

        %% ==============================================================
        %  RX — fully modular, no receiveInPool
        %  ==============================================================

        function [rxData, eset] = receiveSlot(obj, baseband, decAlgo)
        %receiveSlot Full modular RX processing for one slot
        %   [RXDATA, ESET] = receiveSlot(PHY, BB, DECALGO)

            if nargin < 3
                decAlgo = struct('PerfectChannelEstimator', false, ...
                                 'DecodeSLSCH', true);
            end

            tx = obj.Transmission;
            carrier = obj.Pool.SCSCarrier;
            eset = struct('SCI1', true, 'SCI2', true, 'SLSCH', true);

            % --- 1. OFDM demodulate ---
            rxGrid = nrOFDMDemodulate(carrier, baseband);

            % --- 2. Resource allocation ---
            [sloc, slod] = obj.getResources();

            % --- 3. PSCCH: demodulate → soft bits (TS 38.211) ---
            sci1LLR = SidelinkPSCCH.demodulate( ...
                rxGrid, carrier, sloc, decAlgo);

            % --- 4. SCI1: Polar decode (TS 38.212 Sec 8.3) ---
            [sci1Bits, sci1OK, nxid] = SidelinkSCIEncoder.decodeSCI1( ...
                sci1LLR, tx.OSCI1);
            eset.SCI1 = ~sci1OK;

            % Use decoded NXID for PSSCH (unless overridden)
            if isempty(tx.NXID)
                txForPSSCH = tx;
                txForPSSCH.NXID = nxid;
            else
                txForPSSCH = tx;
            end

            % --- 5. PSSCH: demodulate → {sci2LLR, slschLLR} (TS 38.211) ---
            [sci2LLR, slschLLR, noiseEst] = SidelinkPSSCH.demodulate( ...
                rxGrid, carrier, txForPSSCH, slod, decAlgo);

            % --- 6. SCI2: Polar decode (TS 38.212 Sec 8.4) ---
            [sci2Bits, sci2OK] = SidelinkSCIEncoder.decodeSCI2( ...
                sci2LLR, tx.OSCI2);
            eset.SCI2 = ~sci2OK;

            % --- 7. SL-SCH: LDPC decode (TS 38.212 Sec 8.2/6.2) ---
            slschBits = [];
            if isfield(decAlgo, 'DecodeSLSCH') && decAlgo.DecodeSLSCH
                obj.SLSCH.Decoder.TransportBlockLength = obj.TBS;
                obj.SLSCH.Decoder.TargetCodeRate = tx.TargetCodeRate;
                [slschBits, blkErr] = obj.SLSCH.decode( ...
                    slschLLR, tx.Modulation, tx.NumLayers, ...
                    tx.RedundancyVersion, tx.HARQProcessID);
                % Older MATLAB versions may return cell array from decoder
                if iscell(slschBits), slschBits = slschBits{1}; end
                eset.SLSCH = logical(blkErr);
            else
                eset.SLSCH = false;
            end

            % --- Build output ---
            rxData = struct();
            rxData.SCI1Bits  = sci1Bits;
            rxData.SCI2Bits  = sci2Bits;
            rxData.SLSCHBits = slschBits;
            rxData.NXID      = nxid;
            rxData.NoiseEst  = noiseEst;
            rxData.Errors    = eset;

            obj.RxCount = obj.RxCount + 1;
            if eset.SLSCH
                obj.ErrorCount = obj.ErrorCount + 1;
            end
        end

        %% ==============================================================
        %  Resource helpers — thin wrappers over pool
        %  ==============================================================

        function [sloc, slod] = getResources(obj)
        %getResources Get PSCCH and PSSCH resources for current config
        %   [PSCCH, PSSCH] = getResources(PHY)
            sloc = obj.Pool.getPSCCHResources(obj.Transmission);
            slod = obj.Pool.getPSSCHResources(obj.Transmission);
        end

        function tbs = getTBS(obj)
        %getTBS Compute TBS per TS 38.214 Sec 8.1.3.2
            tbs = obj.Pool.getTBS(obj.Transmission);
            obj.TBS = tbs;
        end

        function advanceSlot(obj)
        %advanceSlot Advance resource pool carrier to next slot
            obj.Pool = obj.Pool.advanceToNextSlot();
        end

        %% ==============================================================
        %  Configuration
        %  ==============================================================

        function configureFromParams(obj, bw, scs, modulation, codeRate, numSubchPerTx, numDMRSPos)
        %configureFromParams Configure PHY directly — no RMC preset required
        %   configureFromParams(PHY)                       % all defaults
        %   configureFromParams(PHY, BW, SCS, MOD, CR, NSUBCH, NDMRS)
        %
        %   BW         - Bandwidth MHz:  5,10,15,20,25,40,50,100  (default 20)
        %   SCS        - Subcarrier spacing kHz: 15,30,60          (default 30)
        %   MOD        - 'QPSK','16QAM','64QAM','256QAM'           (default 'QPSK')
        %   CR         - Target code rate 0..1                     (default 308/1024)
        %   NSUBCH     - Subchannels per transmission               (default 2)
        %   NDMRS      - DMRS positions: 2,3,4                     (default 2)
        %
        %   Uses 'FRC' internally to get pool geometry (NRB table + subchannel
        %   sizing) from BW/SCS, then overrides all transmission parameters
        %   with the caller-supplied values.  No conformance preset is applied.

            if nargin < 7 || numDMRSPos    <= 0, numDMRSPos    = 2;        end
            if nargin < 6 || numSubchPerTx <= 0, numSubchPerTx = 2;        end
            if nargin < 5 || codeRate      <= 0, codeRate      = 308/1024; end
            if nargin < 4 || isempty(modulation), modulation   = 'QPSK';   end
            if nargin < 3 || scs           <= 0, scs           = 30;       end
            if nargin < 2 || bw            <= 0, bw            = 20;       end

            % 'FRC' gives the correct pool geometry (NRB, PSFCH period)
            % without imposing any specific MCS or allocation.
            [tx, pool, ~] = NRSidelinkResourcePool.rmcTestConfiguration( ...
                'FRC', bw, scs, modulation);

            % Fix subchannel size to 10 PRBs for consistency across BWs.
            % The FRC path picks variable subchannel sizes to maximize PRB
            % utilization, which creates inconsistent TBS across bandwidths
            % (e.g., 10 MHz gets subchSize=12 while 20 MHz gets 10).
            pool.sl_SubchannelSize_r16 = 10;
            pool.sl_NumSubchannel_r16  = pool.MaxNumSubchannels;

            % Override all transmission parameters with caller's values
            tx.SubchannelAllocation = [0, min(numSubchPerTx, pool.MaxNumSubchannels)];
            tx.Modulation           = modulation;
            tx.TargetCodeRate       = codeRate;
            tx.NumDMRSPositions     = numDMRSPos;
            tx.NumDMRSPositionsList = repmat(numDMRSPos, 1, 2);

            obj.Pool         = pool;
            obj.Transmission = tx;

            if isempty(obj.SLSCH)
                obj.SLSCH = SidelinkSLSCH( ...
                    'MultipleHARQProcesses', true, 'TargetCodeRate', codeRate);
            else
                obj.SLSCH.TargetCodeRate = codeRate;
            end
            obj.TBS = pool.getTBS(tx);
        end

        function configureFromRMC(obj, rmcName, bw, scs, modOverride)
        %configureFromRMC Configure from reference measurement channel
        %   Kept for conformance / RAN4 testing against specific RMC presets.
        %   For general simulation use configureFromParams instead.
        %   configureFromRMC(PHY, 'R.PSSCH.2-1.1')
        %   configureFromRMC(PHY, 'R.PSSCH.2-1.2', 20, 30)

            if nargin < 5, modOverride = 'QPSK'; end
            if nargin < 4, scs = 30; end
            if nargin < 3, bw = 20; end

            [tx, pool, ~] = NRSidelinkResourcePool.rmcTestConfiguration( ...
                rmcName, bw, scs, modOverride);
            obj.Pool = pool;
            obj.Transmission = tx;
            obj.TBS = pool.getTBS(tx);
        end

        %% ==============================================================
        %  Channel model
        %  ==============================================================

        function [rxWaveform, pathGains, sampleTimes] = applyChannel(obj, txWaveform)
        %applyChannel Pass waveform through configured channel model
            if isempty(obj.ChannelModel)
                error('SidelinkPHYEntity:NoChannel', ...
                    'ChannelModel not configured.');
            end
            [rxWaveform, pathGains, sampleTimes] = ...
                obj.ChannelModel.apply(txWaveform);
        end

        %% ==============================================================
        %  Info / display / reset
        %  ==============================================================

        function info = getInfo(obj)
        %getInfo Get PHY entity status summary
            info.TBS        = obj.TBS;
            info.Modulation = obj.Transmission.Modulation;
            info.CodeRate   = obj.Transmission.TargetCodeRate;
            info.NumLayers  = obj.Transmission.NumLayers;
            info.SubchannelAllocation = obj.Transmission.SubchannelAllocation;
            info.BandwidthRB = obj.Pool.SCSCarrier.NSizeGrid;
            info.SCS_kHz    = obj.Pool.SCSCarrier.SubcarrierSpacing;
            info.NSlot      = obj.Pool.SCSCarrier.NSlot;
            info.TxCount    = obj.TxCount;
            info.RxCount    = obj.RxCount;
            info.BLER       = obj.ErrorCount / max(1, obj.RxCount);
            info.SampleRate = nrOFDMInfo(obj.Pool.SCSCarrier).SampleRate;
        end

        function displayResources(obj)
        %displayResources Show PSCCH/PSSCH resource grid visualization
            obj.Pool.displayTransmissionResources(obj.Transmission);
        end

        function reset(obj)
        %reset Reset counters and soft buffers
            obj.TxCount = 0;
            obj.RxCount = 0;
            obj.ErrorCount = 0;
            if ~isempty(obj.SLSCH), obj.SLSCH.reset(); end
            if ~isempty(obj.ChannelModel), obj.ChannelModel.reset(); end
        end
    end
end
