classdef SidelinkDMRS
%SidelinkDMRS Demodulation Reference Signal generation for NR Sidelink
%   Generates DM-RS sequences for all sidelink physical channels per
%   TS 38.211 Section 8.3.2 (PSCCH DMRS), Section 8.4.1.1.2 (PSSCH DMRS),
%   and Section 8.6.2 (PSBCH DMRS).
%
%   DM-RS characteristics:
%   - PSCCH DMRS: 3 RE per PRB per symbol, same symbols as PSCCH data,
%     cinit based on sl_DMRS_ScrambleID and slot/symbol number
%   - PSSCH DMRS: Type 1 config, 6 RE per PRB, symbols from Table 8.4.1.1.2-1,
%     cinit based on NXID (PSCCH CRC) and slot/symbol number
%   - PSBCH DMRS: similar to PBCH DMRS, cinit based on NIDSL
%
%   All DM-RS use QPSK modulated PRBS sequences:
%     cinit = mod(2^17*(Nsymb*Nslot + l + 1)*(2*NID + 1) + 2*NID, 2^31)
%
%   Methods:
%     generatePSCCHDMRS - Generate PSCCH DM-RS sequence
%     generatePSSCHDMRS - Generate PSSCH DM-RS sequence
%     lookupDMRSPositions - Get PSSCH DM-RS OFDM symbol positions

%   Copyright 2025. NR Sidelink Simulation Platform.
%   Spec refs: TS 38.211 Sec 8.3.2 (PSCCH DMRS)
%              TS 38.211 Sec 8.4.1.1.2 (PSSCH DMRS)
%              TS 38.211 Table 8.4.1.1.2-1 (DMRS symbol positions)

    methods (Static)

        function [dmrsSeq, indices] = generatePSCCHDMRS(carrier, pool, firstrbre, numPRB, symbols)
        %generatePSCCHDMRS Generate PSCCH DM-RS sequence
        %   [SEQ, IDX] = generatePSCCHDMRS(CARRIER, POOL, FIRSTRBRE, NUMPRB, SYMBOLS)
        %   CARRIER  - nrCarrierConfig object
        %   POOL     - NRSidelinkResourcePool object
        %   FIRSTRBRE- First RE index of PSCCH allocation
        %   NUMPRB   - Number of PSCCH PRBs (sl_FreqResourcePSCCH)
        %   SYMBOLS  - PSCCH OFDM symbol indices (0-based)
        %
        %   Per TS 38.211 Sec 8.3.2:
        %   cinit(l) = mod(2^17*(Nsymb*Nslot+l+1)*(2*NID+1)+2*NID, 2^31)
        %   NID = sl_DMRS_ScrambleID_r16, 3 DMRS RE/PRB at positions 1,5,9

            nslotsymb = carrier.SymbolsPerSlot;
            nslot = carrier.NSlot;
            dmrsNID = pool.sl_DMRS_ScrambleID_r16;

            cinit = @(nsym) mod(2^17*(nslotsymb*nslot+nsym+1)*(2*dmrsNID+1)+2*dmrsNID, 2^31);

            % Generate PRBS for each symbol
            allDMRS = [];
            allIdx = [];
            for si = 1:length(symbols)
                nsym = symbols(si);
                % PRBS covers from carrier start to end of PSCCH
                prbsLen = 2 * 3 * (carrier.NStartGrid + firstrbre/12 + numPRB);
                prbsOffset = 2 * 3 * (carrier.NStartGrid + firstrbre/12);
                prbs = nrPRBS(cinit(nsym), [prbsOffset, numPRB * 3 * 2]);

                % QPSK modulation of PRBS pairs
                bpsk = 1/sqrt(2) * (1 - 2*reshape(prbs, 2, []).');
                dmrs = complex(bpsk(:,1), bpsk(:,2));
                allDMRS = [allDMRS; dmrs]; %#ok<AGROW>

                % RE indices: positions 1,5,9 in each PRB
                reIdx = (firstrbre+1 : 4 : firstrbre+12*numPRB-1)';
                symOffset = 12 * carrier.NSizeGrid * nsym;
                allIdx = [allIdx; symOffset + reIdx]; %#ok<AGROW>
            end

            dmrsSeq = allDMRS;
            indices = allIdx;
        end

        function [dmrsSeq, indices] = generatePSSCHDMRS(carrier, nxid, numLayers, ...
                allocRBStart, allocRBEnd, dmrsSymbols)
        %generatePSSCHDMRS Generate PSSCH DM-RS sequence
        %   [SEQ, IDX] = generatePSSCHDMRS(CARRIER, NXID, NLAYERS, RBSTART, RBEND, DMRSSYMS)
        %   CARRIER    - nrCarrierConfig
        %   NXID       - Scrambling ID from PSCCH CRC
        %   NLAYERS    - Number of layers (1 or 2)
        %   RBSTART    - First RE of PSSCH per DM-RS symbol
        %   RBEND      - Last RE of PSSCH allocation
        %   DMRSSYMS   - DM-RS OFDM symbol indices (0-based)
        %
        %   Per TS 38.211 Sec 8.4.1.1.2:
        %   Type 1 DM-RS: 6 RE per PRB at offset positions 1,3,5,7,9,11
        %   cinit(l) = mod(2^17*(Nsymb*Nslot+l+1)*(2*NID+1)+2*NID, 2^31)
        %   NID = NXID (decimal PSCCH CRC value)
        %   For 2 layers: w_f = [+1,+1; +1,-1] OCC across ports

            if isempty(nxid), nxid = 0; end
            nslotsymb = carrier.SymbolsPerSlot;
            nslot = carrier.NSlot;

            cinit = @(nsym) mod(2^17*(nslotsymb*nslot+nsym+1)*(2*nxid+1)+2*nxid, 2^31);

            allDMRS = [];
            allIdx = [];

            for si = 1:length(dmrsSymbols)
                nsym = dmrsSymbols(si);
                rbStart = allocRBStart(min(si, numel(allocRBStart)));

                % PRBS length covers allocation
                prbsOffset = 12*carrier.NStartGrid + rbStart;
                prbsLen = allocRBEnd + 1 - rbStart;
                prbs = nrPRBS(cinit(nsym), [prbsOffset, prbsLen]);

                % QPSK: pairs of PRBS bits
                bpsk = 1/sqrt(2) * (1 - 2*reshape(prbs, 2, []).');
                dmrs = complex(bpsk(:,1), bpsk(:,2));

                % Expand across layers with OCC
                mask = [1 1; 1 -1];
                fullMask = repmat(mask(:, 1:numLayers), length(dmrs)/2, 1);
                dmrsLayered = repmat(dmrs, 1, numLayers) .* fullMask;

                allDMRS = [allDMRS; dmrsLayered]; %#ok<AGROW>

                % RE indices: stride 2 starting at offset 1 in each PRB
                symOffset = 12 * carrier.NSizeGrid * nsym;
                reIdx = (rbStart+1 : 2 : allocRBEnd)';

                % Expand across layers/ports
                portOffsets = 12 * carrier.NSizeGrid * nslotsymb * (0:numLayers-1);
                layerIdx = portOffsets + reIdx;
                allIdx = [allIdx; layerIdx]; %#ok<AGROW>
            end

            dmrsSeq = allDMRS;
            indices = allIdx;
        end

        function dmrsPositions = lookupDMRSPositions(slLengthSymbols, pscchDuration, numDMRSPos)
        %lookupDMRSPositions Get PSSCH DM-RS OFDM symbol positions
        %   POS = lookupDMRSPositions(SLLEN, PSCCHDUR, NDMRS)
        %   From TS 38.211 Table 8.4.1.1.2-1.
        %   Returns 0-based symbol indices relative to SL start.

            % Duration includes AGC symbol but not guard
            ld = slLengthSymbols - 2 + 1;  % Active symbols + AGC

            persistent dmrsTable;
            if isempty(dmrsTable)
                dmrsTable = cell(13, 2, 3);  % [duration, pscchDur, numDMRS]
                % 2 PSCCH symbols tables
                dmrsTable{6,1,1}=[1,5]; dmrsTable{7,1,1}=[1,5]; dmrsTable{8,1,1}=[1,5];
                dmrsTable{9,1,1}=[3,8]; dmrsTable{9,1,2}=[1,4,7];
                dmrsTable{10,1,1}=[3,8]; dmrsTable{10,1,2}=[1,4,7];
                dmrsTable{11,1,1}=[3,10]; dmrsTable{11,1,2}=[1,5,9]; dmrsTable{11,1,3}=[1,4,7,10];
                dmrsTable{12,1,1}=[3,10]; dmrsTable{12,1,2}=[1,5,9]; dmrsTable{12,1,3}=[1,4,7,10];
                dmrsTable{13,1,1}=[3,10]; dmrsTable{13,1,2}=[1,6,11]; dmrsTable{13,1,3}=[1,4,7,10];
                % 3 PSCCH symbols tables
                dmrsTable{6,2,1}=[1,5]; dmrsTable{7,2,1}=[1,5]; dmrsTable{8,2,1}=[1,5];
                dmrsTable{9,2,1}=[4,8]; dmrsTable{9,2,2}=[1,4,7];
                dmrsTable{10,2,1}=[4,8]; dmrsTable{10,2,2}=[1,4,7];
                dmrsTable{11,2,1}=[4,10]; dmrsTable{11,2,2}=[1,5,9]; dmrsTable{11,2,3}=[1,4,7,10];
                dmrsTable{12,2,1}=[4,10]; dmrsTable{12,2,2}=[1,5,9]; dmrsTable{12,2,3}=[1,4,7,10];
                dmrsTable{13,2,1}=[4,10]; dmrsTable{13,2,2}=[1,6,11]; dmrsTable{13,2,3}=[1,4,7,10];
            end

            pscchIdx = 1 + (pscchDuration > 2);
            dmrsIdx = numDMRSPos - 1;

            if ld >= 1 && ld <= 13 && dmrsIdx >= 1 && dmrsIdx <= 3
                positions = dmrsTable{ld, pscchIdx, dmrsIdx};
                if ~isempty(positions)
                    dmrsPositions = positions;
                    return;
                end
            end

            % Fallback: find nearest valid config
            for d = min(dmrsIdx, 3):-1:1
                if ld <= 13 && ~isempty(dmrsTable{max(ld,6), pscchIdx, d})
                    dmrsPositions = dmrsTable{max(ld,6), pscchIdx, d};
                    return;
                end
            end
            dmrsPositions = [];
        end
    end
end
