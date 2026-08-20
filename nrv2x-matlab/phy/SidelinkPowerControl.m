classdef SidelinkPowerControl < handle
%SidelinkPowerControl NR Sidelink UE transmit power control
%   Scales baseband TX waveforms to a target power level (dBm) and
%   enforces the 3GPP maximum UE output power limit.
%
%   The module separates two concerns:
%     1. Waveform scaling — normalises the IQ samples to the target dBm
%        (referenced to 1 mW into 50 Ω, i.e. standard dBm convention).
%     2. Effective SNR — adjusts the nominal link-budget SNR when TX power
%        deviates from the reference power at which SNRdB was defined.
%        effectiveSNR = nominalSNR + (actualTxPow - refPow)  [dB]
%
%   Spec ref: 3GPP TS 38.101-4 Table 6.2.1-1
%     Power Class 3 (PC3) V2X UE — P_UMAX = 23 dBm
%
%   Usage:
%     pc = SidelinkPowerControl();                   % defaults: 23/23/23 dBm
%     pc = SidelinkPowerControl('TxPowerdBm', 15);   % reduce TX power
%
%     [txScaled, actualPow] = pc.apply(bbWaveform);
%     ue1.Channel.SNRdB = pc.effectiveSNRdB(cfg.SNRdB);
%
%   Power sweep example:
%     for txPow = -10:5:23
%         pc.TxPowerdBm = txPow;
%         [bbScaled, ~] = pc.apply(bb);
%         ch.SNRdB = pc.effectiveSNRdB(nominalSNR);
%         ... run sim ...
%     end

%   Copyright 2025. NR Sidelink Simulation Platform.

    properties
        TxPowerdBm    (1,1) double = 23   % Desired TX power (dBm)
        MaxTxPowerdBm (1,1) double = 23   % Hard ceiling — TS 38.101-4 PC3
        RefPowerdBm   (1,1) double = 23   % Power at which cfg.SNRdB is defined
    end

    properties (SetAccess = private)
        ActualTxPowerdBm (1,1) double = NaN  % Last applied power (after clamp)
    end

    %% ----------------------------------------------------------------
    methods

        function obj = SidelinkPowerControl(varargin)
        %SidelinkPowerControl Construct with optional name-value pairs
        %   pc = SidelinkPowerControl('TxPowerdBm', 15, 'MaxTxPowerdBm', 23)
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        %% ---------------------------------------------------------------
        function [scaledWfm, actualPowdBm] = apply(obj, waveform)
        %apply Scale waveform to target TX power (clamped to max)
        %   [WFM, POW] = apply(WFM_IN)
        %   WFM_IN     - Complex baseband waveform (samples × antennas)
        %   WFM        - Power-scaled copy of the waveform
        %   POW        - Actual applied TX power in dBm (after clamping)
        %
        %   If TxPowerdBm exceeds MaxTxPowerdBm the power is silently
        %   clamped (a warning is issued once per clamp event).

            % Clamp to maximum
            target = obj.TxPowerdBm;
            if target > obj.MaxTxPowerdBm
                warning('SidelinkPowerControl:Clamped', ...
                    'TxPowerdBm %.1f dBm exceeds MaxTxPowerdBm %.1f dBm — clamped.', ...
                    target, obj.MaxTxPowerdBm);
                target = obj.MaxTxPowerdBm;
            end
            obj.ActualTxPowerdBm = target;
            actualPowdBm = target;

            % Current waveform power (linear, baseband units)
            currentPow = mean(abs(waveform(:)).^2);
            if currentPow == 0
                scaledWfm = waveform;
                return;
            end

            % Target power: dBm → watts  (P[W] = 10^(P[dBm]/10) × 10^-3)
            targetPowW = 10^(target / 10) * 1e-3;

            % Amplitude scale factor
            scaleFactor = sqrt(targetPowW / currentPow);
            scaledWfm   = waveform * scaleFactor;
        end

        %% ---------------------------------------------------------------
        function snrdB = effectiveSNRdB(obj, nominalSNRdB)
        %effectiveSNRdB Compute effective SNR after power control
        %   SNR = effectiveSNRdB(NOMINAL_SNR)
        %   NOMINAL_SNR - SNR (dB) defined at RefPowerdBm
        %
        %   Returns NOMINAL_SNR adjusted for the delta between the actual
        %   TX power and the reference power.  Apply() must be called first.
        %
        %   Formula: effective_SNR = nominal_SNR + (P_actual - P_ref)  [dB]

            if isnan(obj.ActualTxPowerdBm)
                % apply() not yet called — use TxPowerdBm (clamped)
                actual = min(obj.TxPowerdBm, obj.MaxTxPowerdBm);
            else
                actual = obj.ActualTxPowerdBm;
            end
            snrdB = nominalSNRdB + (actual - obj.RefPowerdBm);
        end

        %% ---------------------------------------------------------------
        function powdBm = measurePowerdBm(~, waveform)
        %measurePowerdBm Measure instantaneous waveform power in dBm
        %   POW = measurePowerdBm(WFM)
        %   Returns -Inf for an all-zero waveform.
            powW = mean(abs(waveform(:)).^2);
            if powW == 0
                powdBm = -Inf;
            else
                powdBm = 10 * log10(powW / 1e-3);
            end
        end

        %% ---------------------------------------------------------------
        function disp(obj)
            fprintf('  SidelinkPowerControl\n');
            fprintf('    TxPowerdBm    : %.1f dBm', obj.TxPowerdBm);
            if obj.TxPowerdBm > obj.MaxTxPowerdBm
                fprintf('  → clamped to %.1f dBm', obj.MaxTxPowerdBm);
            end
            fprintf('\n');
            fprintf('    MaxTxPowerdBm : %.1f dBm  (3GPP PC3 limit)\n', obj.MaxTxPowerdBm);
            fprintf('    RefPowerdBm   : %.1f dBm  (SNR reference)\n', obj.RefPowerdBm);
            if ~isnan(obj.ActualTxPowerdBm)
                snrEffect = obj.ActualTxPowerdBm - obj.RefPowerdBm;
                fprintf('    SNR offset    : %+.1f dB\n', snrEffect);
            end
        end

    end
end
