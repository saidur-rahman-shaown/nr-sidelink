classdef SidelinkPSSCH
%SidelinkPSSCH Physical Sidelink Shared Channel (PSSCH)
%   Pure TS 38.211 Section 8.4 physical channel processing.
%   Does NOT include TS 38.212 encoding/decoding — that belongs in
%   SidelinkSCIEncoder (SCI2) and SidelinkSLSCH (SL-SCH data).
%   This separation matches how NRSidelinkResourcePool splits
%   outertransmit (coding) from physicalcodeup (38.211).
%
%   PSSCH carries two multiplexed components:
%     1. SCI2 (2nd-stage control): always QPSK, polar coded
%     2. SL-SCH (data): QPSK/16QAM/64QAM/256QAM, LDPC coded
%
%   TX chain (TS 38.211 Sec 8.4.1):
%     SCI2 CW + SL-SCH CW → Scramble (cinit) → Mod → Layer map → symbols
%
%   RX chain:
%     Extract REs → Ch est → Equalize → Layer demap →
%     Demod → CSI weight → Descramble → {SCI2 LLR, SL-SCH LLR}
%
%   The caller is responsible for:
%     TX: SCI2 bits → SidelinkSCIEncoder.encodeSCI2 → sci2CW
%         TB bits  → SidelinkSLSCH.encode           → slschCW
%         Then pass both to SidelinkPSSCH.modulate
%     RX: SidelinkPSSCH.demodulate → {sci2LLR, slschLLR}
%         Then: SidelinkSCIEncoder.decodeSCI2(sci2LLR, ...)
%               SidelinkSLSCH.decode(slschLLR, ...)
%
%   Methods:
%     modulate     - Scramble + modulate + layer map (TX, pure 38.211)
%     demodulate   - Extract, equalize, demod, descramble (RX, pure 38.211)
%     getResources - Get PSSCH RE indices, DMRS, bit capacities
%
%   Legacy methods (combine coding + physical, for backward compat):
%     transmit     - encodeSCI2 + modulate (all-in-one TX)
%     receive      - demodulate + decodeSCI2 (all-in-one RX)
%
%   Uses 5G Toolbox: nrPRBS, nrSymbolModulate, nrSymbolDemodulate,
%     nrLayerMap, nrLayerDemap, nrChannelEstimate, nrEqualizeMMSE

%   Copyright 2025. NR Sidelink Simulation Platform.
%   Spec refs: TS 38.211 Sec 8.4.1.1   (PSSCH scrambling)
%              TS 38.211 Sec 8.4.1.2   (PSSCH modulation)
%              TS 38.211 Sec 8.4.1.3   (PSSCH layer mapping)
%              TS 38.211 Sec 8.4.1.4   (PSSCH RE mapping)
%              TS 38.211 Sec 8.4.1.1.2 (PSSCH DMRS)

    methods (Static)

        %% ==============================================================
        %  Modular TX — pure TS 38.211 Sec 8.4.1 (no coding)
        %  ==============================================================

        function symbols = modulate(sci2CW, slschCW, transmission, nxid)
        %modulate Scramble, modulate, and layer-map PSSCH
        %   SYM = modulate(SCI2CW, SLSCHCW, TX, NXID)
        %   SCI2CW  - Polar-coded SCI2 bits (from SidelinkSCIEncoder.encodeSCI2)
        %   SLSCHCW - LDPC-coded SL-SCH bits (from SidelinkSLSCH.encode)
        %   TX      - Struct with .Modulation, .NumLayers
        %   NXID    - CRC decimal from SCI1 (for scrambling init)
        %
        %   Returns layered symbols ready for RE mapping.
        %
        %   Processing:
        %     1. Scramble SCI2 + SL-SCH (cinit = 2^15*NXID + 1010)
        %        SCI2: placeholder insertion for multi-layer (Sec 8.4.1.1)
        %        SL-SCH: standard XOR scrambling
        %     2. Modulate: SCI2 always QPSK, SL-SCH per MCS (Sec 8.4.1.2)
        %     3. Layer mapping (Sec 8.4.1.3)

            if nargin < 4 || isempty(nxid), nxid = 0; end
            nLayers = transmission.NumLayers;

            % --- Scrambling (TS 38.211 Sec 8.4.1.1) ---
            cinit  = 2^15 * mod(nxid, 2^16) + 1010;
            clen   = max(numel(sci2CW), numel(slschCW));
            scrSeq = nrPRBS(cinit, clen);

            % SCI2 part: insert placeholder bit-pairs for layer duplication,
            % then scramble non-placeholder bits. Placeholder positions get
            % a copy of the previous scrambled QPSK symbol's bits.
            %   For nLayers=1: no placeholders, just XOR
            %   For nLayers=2: interleave [b0 b1 -1 -1] per QPSK symbol
            sci2Exp = reshape([ ...
                reshape(sci2CW, 2, []); ...
                -1 * ones(2*(nLayers-1), length(sci2CW)/2)], [], 1);

            sSCI2 = zeros(size(sci2Exp));
            npb = (sci2Exp >= 0);                              % non-placeholder mask
            sSCI2(npb) = xor(sci2Exp(npb), scrSeq(1:nnz(npb)));
            pb = find(~npb);                                   % placeholder indices
            sSCI2(pb) = sSCI2(pb - 2);                         % repeat previous symbol

            % SL-SCH part: standard scrambling
            sSLSCH = xor(slschCW, scrSeq(1:numel(slschCW)));

            % --- Modulation (TS 38.211 Sec 8.4.1.2) ---
            sci2Sym = nrSymbolModulate(sSCI2, 'QPSK');                    % SCI2 always QPSK
            dataSym = nrSymbolModulate(sSLSCH, transmission.Modulation);  % SL-SCH per MCS
            combined = [sci2Sym; dataSym];

            % --- Layer mapping (TS 38.211 Sec 8.4.1.3) ---
            symbols = nrLayerMap(combined, nLayers);
        end

        %% ==============================================================
        %  Modular RX — pure TS 38.211 reverse (no decoding)
        %  ==============================================================

        function [sci2LLR, slschLLR, noiseEst] = demodulate(rxGrid, carrier, ...
                transmission, slo, decAlgo)
        %demodulate Extract, equalize, demod, descramble PSSCH from grid
        %   [SCI2LLR, SLSCHLLR, NVAR] = demodulate(GRID, CARRIER, TX, SLO, DEC)
        %   GRID    - Received resource grid (after OFDM demod)
        %   CARRIER - nrCarrierConfig object
        %   TX      - Struct with .Modulation, .NumLayers, .NXID
        %   SLO     - PSSCH resource struct from getResources
        %   DEC     - struct with .PerfectChannelEstimator (optional)
        %
        %   Returns:
        %     SCI2LLR  - Descrambled soft bits for SCI2 polar decoder
        %     SLSCHLLR - Descrambled soft bits for SL-SCH LDPC decoder
        %     NVAR     - Noise variance estimate
        %
        %   Processing:
        %     1. Channel estimation via PSSCH DMRS
        %     2. RE extraction + MMSE equalization
        %     3. Layer demapping
        %     4. SCI2: QPSK demod → CSI weight → layer combine → descramble
        %     5. SL-SCH: QAM demod → CSI weight → descramble

            if nargin < 5
                decAlgo = struct('PerfectChannelEstimator', false);
            end

            % --- Channel estimation ---
            if decAlgo.PerfectChannelEstimator
                estChGrid = decAlgo.estChannelGrid;
                noiseEst  = decAlgo.noiseEst;
            else
                [estChGrid, noiseEst] = nrChannelEstimate(carrier, rxGrid, ...
                    slo.PSSCHDMRSIndices+1, slo.PSSCHDMRS, ...
                    'CDMLengths', [size(slo.PSSCHDMRS,2) 1], ...
                    'AveragingWindow', [0 1]);
            end

            % --- RE extraction + equalization ---
            [psschRx, psschHest] = nrExtractResources( ...
                slo.PSSCHIndices+1, rxGrid, estChGrid);
            [eqSym, csi] = nrEqualizeMMSE(psschRx, psschHest, noiseEst);

            % --- Layer demapping ---
            csi   = nrLayerDemap(csi);   csi   = csi{1};
            eqSym = nrLayerDemap(eqSym); eqSym = eqSym{1};

            % --- Scrambling sequence for descrambling ---
            nxid = transmission.NXID;
            if isempty(nxid), nxid = 0; end
            cinit  = 2^15 * mod(nxid, 2^16) + 1010;
            clen   = max(slo.PSSCHG);
            scrSeq = nrPRBS(cinit, clen, 'MappingType', 'signed');

            % --- SCI2 part (QPSK, always) ---
            % Number of SCI2 QPSK symbols across all layers
            nSymSCI2 = (slo.PSSCHG(1)/2) * transmission.NumLayers;

            % QPSK soft demodulation
            sci2LLR = nrSymbolDemodulate(eqSym(1:nSymSCI2), 'QPSK', noiseEst);

            % CSI weighting (Qm=2 for QPSK)
            csiSCI2 = repmat(csi(1:nSymSCI2).', 2, 1);
            sci2LLR = sci2LLR .* csiSCI2(:);

            % Soft combine layers for SCI2 (2-layer: add LLR pairs)
            if transmission.NumLayers > 1
                sci2LLR = reshape(sci2LLR, 4, []);
                sci2LLR = reshape(sci2LLR(1:2,:) + sci2LLR(3:4,:), [], 1);
            end

            % Descramble SCI2
            sci2LLR = sci2LLR .* scrSeq(1:length(sci2LLR));

            % --- SL-SCH part ---
            slschSym = eqSym(nSymSCI2+1:end);

            % QAM soft demodulation (per MCS modulation order)
            slschLLR = nrSymbolDemodulate(slschSym, transmission.Modulation, noiseEst);

            % CSI weighting (Qm depends on modulation)
            bps = sum([1,2,4,6,8] .* (upper(transmission.Modulation) == ...
                  ["BPSK","QPSK","16QAM","64QAM","256QAM"]));
            csiSLSCH = repmat(csi(nSymSCI2+1:end).', bps, 1);
            slschLLR = slschLLR .* csiSLSCH(:);

            % Descramble SL-SCH
            slschLLR = slschLLR .* scrSeq(1:length(slschLLR));
        end

        %% ==============================================================
        %  Resource allocation (delegates to resource pool)
        %  ==============================================================

        function slo = getResources(pool, transmission)
        %getResources Compute PSSCH resource indices, DMRS, capacities
        %   SLO = getResources(POOL, TRANSMISSION)
        %   Returns struct with fields:
        %     PSSCHIndices      - Linear RE indices (0-based, all layers)
        %     PSSCHIndicesSplit - {SCI2 indices, SL-SCH indices}
        %     PSSCHDMRSIndices  - DM-RS RE indices (0-based, all layers)
        %     PSSCHDMRS         - Complex DM-RS symbols (per layer)
        %     PSSCHG            - [G_SCI2, G_SLSCH] bit capacities
        %     Gamma             - RB boundary alignment offset
            slo = pool.getPSSCHResources(transmission);
        end

        %% ==============================================================
        %  Legacy all-in-one methods (coding + physical channel)
        %  Kept for backward compatibility with existing callers.
        %  New code should use modulate/demodulate separately.
        %  ==============================================================

        function [symbols, nxid] = transmit(sci2Bits, slschCW, transmission, slo, nxidOverride)
        %transmit Encode SCI2 and produce PSSCH modulated symbols
        %   [SYM, NXID] = transmit(SCI2, SLSCHCW, TX, SLO, NXID_IN)
        %   Legacy all-in-one: encodeSCI2 + modulate
        %   Prefer: SidelinkSCIEncoder.encodeSCI2 + SidelinkPSSCH.modulate

            % Resolve NXID
            if nargin >= 5 && ~isempty(nxidOverride)
                nxid = nxidOverride;
            elseif ~isempty(transmission.NXID)
                nxid = transmission.NXID;
            else
                nxid = 0;
            end

            % TS 38.212 Sec 8.4: Polar encode SCI2
            sci2CW = SidelinkSCIEncoder.encodeSCI2(sci2Bits, slo.PSSCHG(1));

            % TS 38.211 Sec 8.4.1: Scramble + modulate + layer map
            symbols = SidelinkPSSCH.modulate(sci2CW, slschCW, transmission, nxid);
        end

        function [sci2Bits, slschSoftBits, sci2OK, nVarD] = receive(rxGrid, carrier, ...
                transmission, slo, ~, decAlgo)
        %receive Decode SCI2 and SL-SCH from received grid
        %   [SCI2, SLSCHLLR, OK, NVAR] = receive(GRID, CARRIER, TX, SLO, ~, DEC)
        %   Legacy all-in-one: demodulate + decodeSCI2
        %   5th arg (slschrx) is unused — SL-SCH decoding is now external.
        %   Prefer: SidelinkPSSCH.demodulate + SidelinkSCIEncoder.decodeSCI2

            if nargin < 6
                decAlgo = struct('PerfectChannelEstimator', false);
            end

            % TS 38.211: Extract, equalize, demod, descramble
            [sci2LLR, slschSoftBits, nVarD] = SidelinkPSSCH.demodulate( ...
                rxGrid, carrier, transmission, slo, decAlgo);

            % TS 38.212 Sec 8.4: Polar decode SCI2
            [sci2Bits, sci2OK] = SidelinkSCIEncoder.decodeSCI2( ...
                sci2LLR, transmission.OSCI2);
        end
    end
end
