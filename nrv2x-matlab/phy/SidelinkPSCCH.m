classdef SidelinkPSCCH
%SidelinkPSCCH Physical Sidelink Control Channel (PSCCH)
%   Pure TS 38.211 Section 8.3 physical channel processing.
%   Does NOT include TS 38.212 encoding/decoding — that belongs in
%   SidelinkSCIEncoder. This separation matches how NRSidelinkResourcePool
%   splits outertransmit (coding) from physicalcodeup (38.211).
%
%   PSCCH carries the 1st-stage SCI and occupies the first 2-3 OFDM
%   symbols of the sidelink slot within sl_FreqResourcePSCCH PRBs of
%   the lowest allocated subchannel.
%
%   TX chain (TS 38.211 Sec 8.3.1):
%     SCI1 codeword → Scramble (cinit=1010) → QPSK mod → symbols
%
%   RX chain:
%     Extract REs → Ch est (PSCCH DMRS) → MMSE equalize →
%     QPSK demod → CSI weight → Descramble → soft bits (LLR)
%
%   The caller is responsible for:
%     TX: SCI1 info bits → SidelinkSCIEncoder.encodeSCI1 → codeword
%         Then pass codeword to SidelinkPSCCH.modulate
%     RX: SidelinkPSCCH.demodulate → LLR
%         Then pass LLR to SidelinkSCIEncoder.decodeSCI1
%
%   Methods:
%     modulate       - Scramble + QPSK modulate SCI1 codeword (TX)
%     demodulate     - Extract, equalize, QPSK demod, descramble (RX)
%     getResources   - Get PSCCH RE indices, DMRS, bit capacity
%     scramble       - Apply PSCCH scrambling (cinit=1010)
%     descramble     - Soft descramble LLRs (cinit=1010)
%
%   Legacy methods (combine coding + physical, for backward compat):
%     transmit       - encodeSCI1 + modulate (all-in-one TX)
%     receive        - demodulate + decodeSCI1 (all-in-one RX)
%
%   Uses 5G Toolbox: nrPRBS, nrSymbolModulate, nrSymbolDemodulate,
%     nrChannelEstimate, nrEqualizeMMSE, nrExtractResources

%   Copyright 2025. NR Sidelink Simulation Platform.
%   Spec refs: TS 38.211 Sec 8.3.1.1 (PSCCH scrambling)
%              TS 38.211 Sec 8.3.1.2 (PSCCH modulation)
%              TS 38.211 Sec 8.3.1.3 (PSCCH RE mapping)
%              TS 38.211 Sec 8.3.2   (PSCCH DMRS)

    methods (Static)

        %% ==============================================================
        %  Modular TX/RX — pure TS 38.211 (no coding)
        %  ==============================================================

        function symbols = modulate(sci1CW)
        %modulate Scramble and QPSK-modulate an SCI1 codeword
        %   SYM = modulate(SCI1CW)
        %   SCI1CW  - Polar-coded SCI1 bits from SidelinkSCIEncoder.encodeSCI1
        %   SYM     - Complex QPSK symbols for PSCCH RE mapping
        %
        %   Processing (TS 38.211 Sec 8.3.1):
        %     1. Scramble with cinit = 1010  (Sec 8.3.1.1)
        %     2. QPSK modulate               (Sec 8.3.1.2)

            % Scramble (Sec 8.3.1.1)
            scrBits = SidelinkPSCCH.scramble(sci1CW);

            % QPSK modulation (Sec 8.3.1.2)
            symbols = nrSymbolModulate(scrBits, 'QPSK');
        end

        function [softBits, noiseEst] = demodulate(rxGrid, carrier, slo, decAlgo)
        %demodulate Extract, equalize, demod and descramble PSCCH from grid
        %   [LLR, NVAR] = demodulate(GRID, CARRIER, SLO, DECALGO)
        %   GRID    - Received resource grid (after OFDM demod)
        %   CARRIER - nrCarrierConfig object
        %   SLO     - PSCCH resource struct from getResources
        %   DECALGO - struct with .PerfectChannelEstimator (and optionally
        %             .estChannelGrid, .noiseEst for perfect mode)
        %
        %   Returns:
        %     LLR  - Soft bits (CSI-weighted, descrambled) for polar decoder
        %     NVAR - Noise variance estimate
        %
        %   Processing:
        %     1. Channel estimation via PSCCH DMRS
        %     2. RE extraction + MMSE equalization
        %     3. QPSK soft demodulation
        %     4. CSI weighting of LLRs
        %     5. Soft descramble (cinit=1010)

            if nargin < 4
                decAlgo = struct('PerfectChannelEstimator', false);
            end

            % --- Channel estimation ---
            if decAlgo.PerfectChannelEstimator
                estChGrid = decAlgo.estChannelGrid;
                noiseEst  = decAlgo.noiseEst;
            else
                [estChGrid, noiseEst] = nrChannelEstimate(carrier, rxGrid, ...
                    slo.PSCCHDMRSIndices+1, slo.PSCCHDMRS, ...
                    'CDMLengths', [size(slo.PSCCHDMRS,2) 1], ...
                    'AveragingWindow', [0 1]);
            end

            % --- RE extraction + equalization ---
            [pscchRx, pscchHest] = nrExtractResources( ...
                slo.PSCCHIndices+1, rxGrid, estChGrid);
            [eqSym, csi] = nrEqualizeMMSE(pscchRx, pscchHest, noiseEst);

            % --- QPSK soft demodulation (Sec 8.3.1.2 reverse) ---
            % Single layer for PSCCH, take first column
            softBits = nrSymbolDemodulate(eqSym(:,1), 'QPSK', noiseEst);

            % --- CSI weighting ---
            % Expand CSI per bit (Qm=2 for QPSK)
            csiExp   = repmat(csi(:,1).', 2, 1);
            softBits = softBits .* csiExp(:);

            % --- Soft descramble (Sec 8.3.1.1 reverse) ---
            softBits = SidelinkPSCCH.descramble(softBits);
        end

        %% ==============================================================
        %  Scrambling utilities
        %  ==============================================================

        function scrBits = scramble(bits)
        %scramble Apply PSCCH scrambling (cinit = 1010)
        %   TS 38.211 Sec 8.3.1.1: PSCCH uses fixed cinit = 1010
        %   For TX hard bits: XOR with PRBS
            clen = length(bits);
            scrSeq = nrPRBS(1010, clen);
            scrBits = xor(bits, scrSeq);
        end

        function softBits = descramble(softBits)
        %descramble Soft descramble PSCCH LLRs (cinit = 1010)
        %   For RX soft bits: multiply by signed PRBS (+1/-1)
            clen = length(softBits);
            scrSeq = nrPRBS(1010, clen, 'MappingType', 'signed');
            softBits = softBits .* scrSeq;
        end

        %% ==============================================================
        %  Resource allocation (delegates to resource pool)
        %  ==============================================================

        function slo = getResources(pool, transmission)
        %getResources Compute PSCCH resource indices, DMRS, and capacity
        %   SLO = getResources(POOL, TRANSMISSION)
        %   Returns struct with fields:
        %     PSCCHIndices     - Linear RE indices (0-based)
        %     PSCCHDMRSIndices - DM-RS RE indices (0-based)
        %     PSCCHDMRS        - Complex DM-RS symbols
        %     PSCCHG           - Bit capacity (QPSK, single layer)
        %     PSCCHGd          - Symbol capacity
        %
        %   Delegates to NRSidelinkResourcePool.getPSCCHResources
            slo = pool.getPSCCHResources(transmission);
        end

        %% ==============================================================
        %  Legacy all-in-one methods (coding + physical channel)
        %  Kept for backward compatibility with existing callers.
        %  New code should use modulate/demodulate + SidelinkSCIEncoder.
        %  ==============================================================

        function [symbols, nxid] = transmit(sci1Bits, pscchG)
        %transmit Encode SCI1 and produce PSCCH QPSK symbols
        %   [SYM, NXID] = transmit(SCI1BITS, PSCCHG)
        %   Legacy all-in-one: encodeSCI1 + scramble + QPSK mod
        %   Prefer: SidelinkSCIEncoder.encodeSCI1 + SidelinkPSCCH.modulate

            % TS 38.212 Sec 8.3: Polar encode SCI1
            [codedBits, nxid] = SidelinkSCIEncoder.encodeSCI1(sci1Bits, pscchG);

            % TS 38.211 Sec 8.3.1: Scramble + QPSK modulate
            symbols = SidelinkPSCCH.modulate(codedBits);
        end

        function [sci1Bits, crcOK, nxid] = receive(rxGrid, carrier, slo, nSCI1Bits, decAlgo)
        %receive Decode SCI1 from received OFDM resource grid
        %   [BITS, OK, NXID] = receive(GRID, CARRIER, SLO, NSCI1, DECALGO)
        %   Legacy all-in-one: demodulate + decodeSCI1
        %   Prefer: SidelinkPSCCH.demodulate + SidelinkSCIEncoder.decodeSCI1

            if nargin < 5
                decAlgo = struct('PerfectChannelEstimator', false);
            end

            % TS 38.211: Extract, equalize, demod, descramble
            softBits = SidelinkPSCCH.demodulate(rxGrid, carrier, slo, decAlgo);

            % TS 38.212 Sec 8.3: Polar decode SCI1
            [sci1Bits, crcOK, nxid] = SidelinkSCIEncoder.decodeSCI1(softBits, nSCI1Bits);
        end
    end
end
