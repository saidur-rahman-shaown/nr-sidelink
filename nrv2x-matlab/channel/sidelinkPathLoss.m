function [PL_dB, isLOS, sigmaSF_dB, info] = sidelinkPathLoss(d_m, fcHz, model, opts)
%SIDELINKPATHLOSS Large-scale path loss for NR sidelink (V2X) links.
%
%   [PL_dB, isLOS, sigmaSF_dB, info] = sidelinkPathLoss(d_m, fcHz, model, opts)
%
%   Returns the mean path loss (dB), a LOS flag, the shadow-fading
%   standard deviation appropriate for the chosen model, and a struct
%   with diagnostic intermediate values.
%
%   Models implemented:
%     'FSPL'      - Friis free-space path loss (best-case bound; matches
%                   the 3GPP RMa LOS curve only at very short range and
%                   is optimistic beyond the breakpoint).
%     'RMa-LOS'   - 3GPP TR 38.901 V17.0.0 Table 7.4.1-1, Rural-Macro LOS.
%                   sigma_SF = 4 dB.
%     'RMa-NLOS'  - 3GPP TR 38.901 RMa NLOS = max( PL_LOS, PL_NLOS' ).
%                   sigma_SF = 8 dB.
%
%   opts (struct, optional):
%     .h_TX_m              TX antenna height (m), default 1.5
%     .h_RX_m              RX antenna height (m), default 1.5
%     .AvgBuildingHeight_m h (m), default 5
%     .StreetWidth_m       W (m), default 20
%
%   Validity (TR 38.901 Table 7.4.1-1):
%     0.5 GHz <= fc <= 30 GHz
%     10 m <= d_2D <= 10 km
%     5 m <= h <= 50 m, 5 m <= W <= 50 m
%   Heights below 10 m are out-of-range for the cellular RMa model;
%   for V2V/V2X with low antennas (~1.5 m on tractors / vehicles)
%   the formula is widely re-used as a defensible LOS pathloss model
%   (see TR 37.885 Annex A and academic V2V literature).  d_2D is
%   floored at 10 m.
%
%   References:
%     3GPP TR 38.901 V17.0.0 Section 7.4.1, Table 7.4.1-1
%     3GPP TR 37.885 V16.0.0 Annex A (NR V2X evaluation methodology)

%   Copyright 2026. NR Sidelink Simulation Platform.

    if nargin < 3 || isempty(model)
        model = 'RMa-LOS';
    end
    if nargin < 4 || isempty(opts)
        opts = struct();
    end

    h_TX = getOpt(opts, 'h_TX_m',              1.5);
    h_RX = getOpt(opts, 'h_RX_m',              1.5);
    h_b  = getOpt(opts, 'AvgBuildingHeight_m', 5.0);
    W    = getOpt(opts, 'StreetWidth_m',       20.0);

    c0 = 3e8;
    fcGHz = fcHz / 1e9;

    d_2D = max(d_m, 10);                 % floor for short range
    d_3D = sqrt(d_2D.^2 + (h_TX - h_RX)^2);

    info = struct( ...
        'd_2D_m', d_2D, 'd_3D_m', d_3D, ...
        'h_TX_m', h_TX, 'h_RX_m', h_RX, ...
        'h_b_m',  h_b,  'W_m',    W, ...
        'fcGHz',  fcGHz);

    switch upper(model)
        case 'FSPL'
            d_km = max(d_m, 1e-3) / 1e3;
            fcMHz = fcHz / 1e6;
            PL_dB = 32.44 + 20*log10(d_km) + 20*log10(fcMHz);
            isLOS = true;
            sigmaSF_dB = 0;
            info.PL_LOS_dB  = PL_dB;
            info.PL_NLOS_dB = NaN;
            info.d_BP_m     = NaN;

        case 'RMA-LOS'
            [PL_dB, info] = rmaLOS(d_3D, fcGHz, h_TX, h_RX, h_b, info);
            isLOS = true;
            sigmaSF_dB = 4;

        case 'RMA-NLOS'
            [PL_LOS, info]  = rmaLOS(d_3D, fcGHz, h_TX, h_RX, h_b, info);
            PL_NLOS_prime   = rmaNLOSprime(d_3D, fcGHz, h_TX, h_RX, h_b, W);
            PL_dB           = max(PL_LOS, PL_NLOS_prime);
            isLOS           = false;
            sigmaSF_dB      = 8;
            info.PL_LOS_dB   = PL_LOS;
            info.PL_NLOS_dB  = PL_NLOS_prime;

        otherwise
            error('sidelinkPathLoss:UnknownModel', ...
                'Unknown path loss model "%s". Use FSPL, RMa-LOS or RMa-NLOS.', model);
    end
end

function [PL, info] = rmaLOS(d_3D, fcGHz, h_TX, h_RX, h_b, info)
%RMa LOS: TR 38.901 Table 7.4.1-1
    c0 = 3e8;
    fcHz = fcGHz * 1e9;
    d_BP = 2 * pi * h_TX * h_RX * fcHz / c0;        % breakpoint distance (m)

    PL1 = 20*log10(40*pi .* d_3D .* fcGHz / 3) ...
        + min(0.03 * h_b^1.72, 10) .* log10(d_3D) ...
        - min(0.044 * h_b^1.72, 14.77) ...
        + 0.002 * log10(h_b) .* d_3D;

    if d_3D <= d_BP
        PL = PL1;
    else
        PL1_atBP = 20*log10(40*pi * d_BP * fcGHz / 3) ...
            + min(0.03 * h_b^1.72, 10) * log10(d_BP) ...
            - min(0.044 * h_b^1.72, 14.77) ...
            + 0.002 * log10(h_b) * d_BP;
        PL = PL1_atBP + 40 * log10(d_3D ./ d_BP);
    end

    info.d_BP_m   = d_BP;
    info.PL_LOS_dB = PL;
end

function PL_NLOS_prime = rmaNLOSprime(d_3D, fcGHz, h_TX, h_RX, h_b, W)
%RMa NLOS' formula, TR 38.901 Table 7.4.1-1
    PL_NLOS_prime = 161.04 ...
        - 7.1*log10(W) + 7.5*log10(h_b) ...
        - (24.37 - 3.7*(h_b/h_TX).^2) .* log10(h_TX) ...
        + (43.42 - 3.1*log10(h_TX)) .* (log10(d_3D) - 3) ...
        + 20*log10(fcGHz) ...
        - (3.2 * (log10(11.75 * h_RX)).^2 - 4.97);
end

function v = getOpt(opts, name, default)
    if isfield(opts, name) && ~isempty(opts.(name))
        v = opts.(name);
    else
        v = default;
    end
end
