classdef RFModule < handle
%RFModule Analog-equivalent RF front end for the sidelink transmitter.
%
%   Takes the OFDM-modulated complex baseband waveform and produces the
%   analog-equivalent transmit signal at the configured power (23 dBm
%   default, TS 38.101-1 power class 3):
%
%     1. Oversampling (FFT interpolation) approximating DAC reconstruction.
%     2. Optional PA nonlinearity (Rapp model) with input back-off.
%     3. Power scaling so mean(|y|^2) equals the target power in watts —
%        the complex envelope convention: |y|^2 is instantaneous power.
%
%   The signal stays a complex envelope at CenterFrequency_Hz (5.9 GHz,
%   band n47). A real passband at 5.9 GHz needs fs >= 11.8 GHz, so
%   toPassband() is provided for demonstration at scaled-down carriers
%   and asserts fc < fs/2.

    properties
        TxPower_dBm        = 23        % power class 3
        SampleRate         = 30.72e6   % input baseband rate
        OversampleFactor   = 4         % analog reconstruction approximation
        CenterFrequency_Hz = 5.9e9     % band n47 (metadata for the envelope)
        PAModel            = 'ideal'   % 'ideal' | 'rapp'
        RappSmoothness     = 2         % Rapp knee sharpness p
        PABackoff_dB       = 8         % input back-off from saturation
    end

    methods
        function obj = RFModule(varargin)
            for i = 1:2:numel(varargin)
                obj.(varargin{i}) = varargin{i+1};
            end
        end

        function [y, info] = transmit(obj, x)
            %transmit Baseband IQ -> analog-equivalent signal at TxPower_dBm.
            x = x(:);
            assert(any(abs(x) > 0), 'RFModule:zeroInput', ...
                'Input waveform has no energy.');

            % 1. oversample (band-limited FFT interpolation ~ DAC + filter)
            os = max(1, round(obj.OversampleFactor));
            if os > 1
                y = interpft(x, os * numel(x));
            else
                y = x;
            end

            % 2. normalise to unit average power, then PA
            y = y / sqrt(mean(abs(y).^2));
            evm = 0;
            if strcmpi(obj.PAModel, 'rapp')
                yLin = y;
                vsat = 10^(obj.PABackoff_dB / 20);   % saturation, unit-avg input
                p = obj.RappSmoothness;
                y = y ./ (1 + (abs(y) / vsat).^(2*p)).^(1/(2*p));
                y = y / sqrt(mean(abs(y).^2));       % restore unit avg power
                evm = sqrt(mean(abs(y - yLin).^2) / mean(abs(yLin).^2));
            end

            % 3. scale to target: mean |y|^2 = P_watts
            Pw = 10^((obj.TxPower_dBm - 30) / 10);   % 23 dBm -> 0.1995 W
            y  = y * sqrt(Pw);

            info.AvgPower_dBm  = 10*log10(mean(abs(y).^2)) + 30;
            info.PeakPower_dBm = 10*log10(max(abs(y).^2)) + 30;
            info.PAPR_dB       = info.PeakPower_dBm - info.AvgPower_dBm;
            info.EVM_pct       = 100 * evm;
            info.SampleRate    = obj.SampleRate * os;
            info.CenterFrequency_Hz = obj.CenterFrequency_Hz;
            info.NumSamples    = numel(y);
        end

        function s = toPassband(obj, y, fc)
            %toPassband Real passband signal (demo carriers only).
            %   s(t) = sqrt(2) * Re{ y(t) e^{j 2 pi fc t} }; the sqrt(2)
            %   keeps the passband average power equal to the envelope's.
            fs = obj.SampleRate * max(1, round(obj.OversampleFactor));
            assert(fc < fs/2, 'RFModule:carrierVsFs', ...
                'fc=%.3g needs fs > %.3g (got %.3g); use a demo carrier.', ...
                fc, 2*fc, fs);
            t = (0:numel(y)-1).' / fs;
            s = sqrt(2) * real(y .* exp(1j*2*pi*fc*t));
        end
    end
end
