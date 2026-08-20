classdef SidelinkChannelModel < handle
%SidelinkChannelModel Propagation channel model for NR Sidelink
%   Wraps MATLAB 5G Toolbox channel models (nrTDLChannel, nrCDLChannel)
%   for V2X sidelink link-level simulations, plus AWGN.
%
%   Supported channel profiles per TS 38.101-4 Annex A.6:
%   - AWGN (no fading)
%   - TDLA30 (Doppler 180-2700 Hz, typical V2X highway)
%   - TDLC300 (urban intersection)
%   - CDL-D (LOS highway platooning)
%   - Custom TDL/CDL profiles
%
%   Properties:
%     DelayProfile     - Channel profile ('AWGN','TDLA30','TDLC300','CDL-D')
%     MaxDopplerShift  - Maximum Doppler shift in Hz
%     SampleRate       - Baseband sample rate in Hz
%     SNRdB            - Target SNR in dB
%     NumTxAntennas    - Number of TX antennas (default 1)
%     NumRxAntennas    - Number of RX antennas (default 2)
%     DelaySpread      - RMS delay spread in seconds (default 30e-9)
%     PerfectEstimation- Return perfect channel estimate (default false)
%
%   Methods:
%     apply            - Pass signal through channel + AWGN
%     getChannelInfo   - Get channel filter delay and info
%     getPerfectEstimate - Get noiseless channel frequency response

%   Copyright 2025. NR Sidelink Simulation Platform.
%   Spec refs: TS 38.101-4 Sec 11 (V2X demod requirements)
%              TS 38.101-4 Annex A.6.2 (PSSCH RMC test configs)

    properties
        DelayProfile      (1,:) char   = 'TDLA30'
        MaxDopplerShift   (1,1) double = 400
        SampleRate        (1,1) double = 15.36e6
        SNRdB             (1,1) double = 10
        NumTxAntennas     (1,1) {mustBePositive,mustBeInteger} = 1
        NumRxAntennas     (1,1) {mustBePositive,mustBeInteger} = 2
        DelaySpread       (1,1) double = 30e-9
        PerfectEstimation (1,1) logical = false
    end

    properties (SetAccess = private)
        Channel         % nrTDLChannel or nrCDLChannel object
        ChannelInfo     % Channel filter info
        PathGains       % Latest path gains for perfect estimation
        SampleTimes     % Latest sample times
    end

    methods
        function obj = SidelinkChannelModel(varargin)
        %SidelinkChannelModel Create channel model
            for i = 1:2:numel(varargin)
                obj.(varargin{i}) = varargin{i+1};
            end
            obj.createChannel();
        end

        function [rxWaveform, pathGains, sampleTimes] = apply(obj, txWaveform)
        %apply Pass transmit waveform through channel and add AWGN
        %   [RX, PG, ST] = apply(CH, TX)
        %   TX - Transmit baseband waveform (time × antennas)
        %   RX - Received waveform with fading + AWGN
        %   PG - Path gains for perfect channel estimation
        %   ST - Sample times
        %
        %   For AWGN profile, no fading is applied.
        %   AWGN noise power is computed from SNRdB and signal power.

            if strcmpi(obj.DelayProfile, 'AWGN')
                % AWGN only (no fading)
                fadedWaveform = txWaveform;
                pathGains = [];
                sampleTimes = [];
            else
                % Fading channel
                [fadedWaveform, pathGains, sampleTimes] = obj.Channel(txWaveform);
                obj.PathGains = pathGains;
                obj.SampleTimes = sampleTimes;
            end

            % Add AWGN
            sigPower = mean(abs(fadedWaveform(:)).^2);
            snrLinear = 10^(obj.SNRdB/10);
            noisePower = sigPower / snrLinear;
            noise = sqrt(noisePower/2) * (randn(size(fadedWaveform)) + ...
                    1i*randn(size(fadedWaveform)));
            rxWaveform = fadedWaveform + noise;
        end

        function info = getChannelInfo(obj)
        %getChannelInfo Get channel model information
        %   INFO = getChannelInfo(CH)
        %   Returns channel filter info including maximum delay.
            if strcmpi(obj.DelayProfile, 'AWGN')
                info.MaximumChannelDelay = 0;
                info.PathDelays = 0;
                info.AveragePathGains = 0;
            else
                info = obj.Channel.info;
            end
        end

        function [estChannelGrid, noiseEst] = getPerfectEstimate(obj, carrier, pathGains, sampleTimes)
        %getPerfectEstimate Get perfect channel estimate in frequency domain
        %   [HEST, NVAR] = getPerfectEstimate(CH, CARRIER, PG, ST)
        %   Uses nrPerfectChannelEstimate from 5G Toolbox.

            if nargin < 3
                pathGains = obj.PathGains;
                sampleTimes = obj.SampleTimes;
            end

            if isempty(pathGains)
                % AWGN: identity channel
                gridSize = [carrier.NSizeGrid*12, carrier.SymbolsPerSlot, ...
                           obj.NumRxAntennas, obj.NumTxAntennas];
                estChannelGrid = ones(gridSize);
                noiseEst = 10^(-obj.SNRdB/10);
            else
                pathFilters = getPathFilters(obj.Channel);
                estChannelGrid = nrPerfectChannelEstimate(carrier, pathGains, ...
                    pathFilters, 0, sampleTimes);
                noiseEst = 10^(-obj.SNRdB/10);
            end
        end

        function configure(obj, carrier)
        %configure Configure sample rate from carrier
        %   configure(CH, CARRIER)
            ofdmInfo = nrOFDMInfo(carrier);
            obj.SampleRate = ofdmInfo.SampleRate;
            obj.createChannel();
        end

        function reset(obj)
        %reset Reset channel model state
            if ~strcmpi(obj.DelayProfile, 'AWGN') && ~isempty(obj.Channel)
                obj.Channel.reset();
            end
            obj.PathGains = [];
            obj.SampleTimes = [];
        end
    end

    methods (Access = private)
        function createChannel(obj)
        %createChannel Instantiate the appropriate channel model

            if strcmpi(obj.DelayProfile, 'AWGN')
                obj.Channel = [];
                return;
            end

            if startsWith(upper(obj.DelayProfile), 'CDL')
                % CDL channel model
                obj.Channel = nrCDLChannel;
                obj.Channel.DelayProfile = obj.DelayProfile;
                obj.Channel.DelaySpread = obj.DelaySpread;
                obj.Channel.MaximumDopplerShift = obj.MaxDopplerShift;
                obj.Channel.SampleRate = obj.SampleRate;
                % Antenna configuration
                obj.Channel.TransmitAntennaArray.Size = [1 1 obj.NumTxAntennas 1 1];
                obj.Channel.ReceiveAntennaArray.Size = [1 1 obj.NumRxAntennas 1 1];
            else
                % TDL channel model
                obj.Channel = nrTDLChannel;
                obj.Channel.DelayProfile = obj.DelayProfile;
                obj.Channel.DelaySpread = obj.DelaySpread;
                obj.Channel.MaximumDopplerShift = obj.MaxDopplerShift;
                obj.Channel.SampleRate = obj.SampleRate;
                obj.Channel.NumTransmitAntennas = obj.NumTxAntennas;
                obj.Channel.NumReceiveAntennas = obj.NumRxAntennas;
            end
        end
    end
end
