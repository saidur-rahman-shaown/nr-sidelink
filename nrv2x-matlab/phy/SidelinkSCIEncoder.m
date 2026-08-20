classdef SidelinkSCIEncoder
%SidelinkSCIEncoder NR Sidelink Control Information encoder/decoder
%   Low-level CRC/Polar/RateMatch pipeline for SCI per TS 38.212
%   Sections 8.3 (SCI1) and 8.4 (SCI2).
%
%   Processing chain:
%   TX: SCI bits -> CRC24C attach -> Polar encode -> Rate match
%   RX: Rate recover -> Polar decode -> CRC24C check
%
%   SCI1 (1st stage, on PSCCH): I_BIL=0 (no bit interleaving)
%   SCI2 (2nd stage, on PSSCH): I_BIL=1 (bit interleaving enabled)
%
%   Uses 5G Toolbox: nrCRCEncode, nrCRCDecode, nrPolarEncode,
%     nrPolarDecode, nrRateMatchPolar, nrRateRecoverPolar
%
%   Methods:
%     encodeSCI1 - Encode SCI format 1-A for PSCCH
%     decodeSCI1 - Decode SCI format 1-A from PSCCH
%     encodeSCI2 - Encode SCI format 2-A/B/C for PSSCH
%     decodeSCI2 - Decode SCI format 2-A/B/C from PSSCH
%
%   CHANGE LOG (vs. original):
%   [REMOVED] packSCI1, unpackSCI1, packSCI2, unpackSCI2
%       Reason: These duplicated SCIGenerator.formatSCI1A / formatSCI2A
%       with hardcoded, incomplete field widths (missing MCS, Additional
%       MCS table, PSFCH overhead, Reserved bits, COT sharing flag,
%       Conflict info receiver flag). All bit-packing now lives solely
%       in SCIGenerator which derives field widths from configuration.
%   [UNCHANGED] Core encode/decode pipeline (sciEncode / sciDecode)
%       already correct: uses nrCRCEncode/nrCRCDecode, correctly sets
%       I_BIL=false for SCI1, I_BIL=true for SCI2.

%   Copyright 2025. NR Sidelink Simulation Platform.
%   Spec refs: TS 38.212 Sec 8.3 (1st-stage SCI encoding)
%              TS 38.212 Sec 8.4 (2nd-stage SCI encoding)
%              TS 38.212 Sec 7.3.2-7.3.4 (CRC, polar, rate match)

    methods (Static)

        function [sciCW, crcVal] = encodeSCI1(sciBits, E)
        %encodeSCI1 Encode 1st-stage SCI (SCI format 1-A) for PSCCH
        %   [CW, CRC] = encodeSCI1(BITS, E)
        %   BITS - SCI1 information bits (column vector)
        %   E    - Output codeword length (bit capacity of PSCCH)
        %   CRC  - Decimal CRC value (NXID, used for PSSCH scrambling init)
        %
        %   Per TS 38.212 Sec 8.3:
        %   - CRC24C attachment with RNTI=0 and 24-bit padding
        %   - Polar encoding (nMax=9)
        %   - Rate matching with I_BIL=0 (no bit interleaving for SCI1)
            [sciCW, crcVal] = SidelinkSCIEncoder.sciEncode(sciBits, E, false);
        end

        function [sciBits, crcOK, crcVal] = decodeSCI1(sciLLR, K, L)
        %decodeSCI1 Decode 1st-stage SCI from PSCCH soft bits
        %   [BITS, OK, CRC] = decodeSCI1(LLR, K, L)
        %   LLR - Soft bits (LLR column vector, length E)
        %   K   - Expected SCI1 payload length in bits (before CRC)
        %   L   - Polar decoder list length (default 8)
        %   OK  - CRC pass (true) or fail (false)
        %   CRC - Decoded CRC value (NXID)
            if nargin < 3, L = 8; end
            [sciBits, crcOK, crcVal] = SidelinkSCIEncoder.sciDecode(sciLLR, K, L, false);
        end

        function [sciCW, crcVal] = encodeSCI2(sciBits, E)
        %encodeSCI2 Encode 2nd-stage SCI (SCI format 2-A/B/C/D) for PSSCH
        %   [CW, CRC] = encodeSCI2(BITS, E)
        %   BITS - SCI2 information bits (column vector)
        %   E    - Output codeword length G^SCI2 = Q'_SCI2 * Q^SCI2_m
        %          where Q^SCI2_m = 2 (QPSK, always).
        %          Caller computes E via the Q'_SCI2 formula (Sec 8.4.4):
        %            Q'_SCI2 = min(
        %              ceil((O_SCI2+L_SCI2)*beta_offset/(Q^SCI2_m*R)),
        %              floor(alpha * sum(M_SCI2(l)))
        %            ) + gamma
        %          See SCIGenerator.calculateSCI2RateMatch.
        %
        %   Per TS 38.212 Sec 8.4:
        %   - CRC24C attachment (Sec 8.4.2)
        %   - Polar encoding    (Sec 8.4.3)
        %   - Rate matching with I_BIL=1 (Sec 8.4.4)
        %   - G^SCI2 capped at 4096 per Sec 8.4.4

            % Enforce G^SCI2 <= 4096 (TS 38.212 Sec 8.4.4)
            E = min(E, 4096);

            [sciCW, crcVal] = SidelinkSCIEncoder.sciEncode(sciBits, E, true);
        end

        function [sciBits, crcOK, crcVal] = decodeSCI2(sciLLR, K, L)
        %decodeSCI2 Decode 2nd-stage SCI from PSSCH soft bits
        %   [BITS, OK, CRC] = decodeSCI2(LLR, K, L)
            if nargin < 3, L = 8; end
            [sciBits, crcOK, crcVal] = SidelinkSCIEncoder.sciDecode(sciLLR, K, L, true);
        end

    end

    methods (Static, Access = private)

        function [sciCW, crcVal] = sciEncode(sciBits, E, isBIL)
        %sciEncode Core SCI encoding (shared by SCI1 and SCI2)
        %   Per TS 38.212 Sec 7.3.2-7.3.4:
        %   1. Prepend 24 ones, attach CRC24C with RNTI=0
        %   2. Polar encode to length N
        %   3. Rate match to output length E (I_BIL per stage)

            rnti = 0;
            Ibil = logical(isBIL);

            % CRC attachment (Sec 7.3.2)
            padded = nrCRCEncode([ones(24,1,'int8'); sciBits(:)], '24C', rnti);
            cVec = padded(25:end);

            % Extract CRC decimal value (NXID for PSSCH scrambling)
            crcBits = cVec(end-23:end);
            crcVal = sum((2.^(23:-1:0)') .* double(logical(crcBits)));

            % Polar encoding (Sec 7.3.3)
            encOut = nrPolarEncode(cVec, E);

            % Rate matching (Sec 7.3.4 / 8.3.4 / 8.4.4)
            K = length(cVec);
            sciCW = nrRateMatchPolar(encOut, K, E, Ibil);
        end

        function [sciBits, crcOK, crcVal] = sciDecode(sciLLR, Kout, L, isBIL)
        %sciDecode Core SCI decoding (shared by SCI1 and SCI2)

            rnti = 0;
            Ibil = logical(isBIL);
            E = length(sciLLR);
            K = Kout + 24;       % K includes CRC
            nMax = 9;
            N = nr5g.internal.polar.getN(K, E, nMax);

            % Rate recovery (Sec 7.3.4)
            recBlk = nrRateRecoverPolar(sciLLR, K, N, Ibil);

            % Polar decoding (Sec 7.3.3)
            padCRC = true;
            decBlk = nrPolarDecode(recBlk, K, E, L, padCRC, rnti);

            % CRC decoding (Sec 7.3.2)
            [padBits, mask] = nrCRCDecode([ones(24,1); decBlk], '24C', rnti);
            sciBits = cast(padBits(25:end), 'int8');
            crcOK = (mask == 0);

            % CRC decimal value
            crcVal = sum((2.^(23:-1:0)') .* double(logical(decBlk(end-23:end))));
        end
    end
end
