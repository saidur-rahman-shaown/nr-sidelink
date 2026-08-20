classdef SidelinkRefSignals
%SidelinkRefSignals Sidelink reference signal transmission/reception
%   TS 38.214 Section 8.2 (transmit) and 8.4 (receive)
%
%   Implements:
%     8.2.1 — CSI-RS transmission decision and scaling
%     8.2.2 — PSSCH DM-RS pattern selection and coexistence check
%     8.2.3 — PT-RS support check (FR2 only)
%     8.2.4 — SL PRS resource allocation helpers
%     8.4.2 — RSRP computation mode (PSSCH-RSRP vs PSCCH-RSRP)
%     8.5   — CSI reporting framework (CQI table, triggering)
%
%   Usage:
%     tx = SidelinkRefSignals.shouldTransmitCSIRS(cfg, csiReqField);
%     pat = SidelinkRefSignals.selectDMRSPattern(cfg, dmrsPatField);
%     beta = SidelinkRefSignals.computeCSIRSScaling(1.0, 2, 2);

    methods (Static)

        %% =============================================================
        %  8.2.1 — CSI-RS Transmission
        %  =============================================================

        function tf = shouldTransmitCSIRS(csiAcquisitionEnabled, csiRequestField)
        %shouldTransmitCSIRS Decide whether to transmit SL CSI-RS
        %   UE transmits CSI-RS within unicast PSSCH if:
        %     - sl-CSI-Acquisition is enabled, AND
        %     - 'CSI request' field in SCI 2-A/2-C/2-D = 1

            tf = csiAcquisitionEnabled && (csiRequestField == 1);
        end

        function beta = computeCSIRSScaling(betaPSSCH_DMRS, numCSIRSPorts, numLayers)
        %computeCSIRSScaling β_CSI-RS scaling factor (clause 8.2.1)
        %   β_CSI-RS = β_PSSCH_DMRS · √(ν / Q_csi)
        %
        %   Inputs:
        %     betaPSSCH_DMRS  — PSSCH DM-RS amplitude scaling
        %     numCSIRSPorts   — Number of CSI-RS ports (1 or 2)
        %     numLayers       — Number of PSSCH layers ν (1 or 2)

            beta = betaPSSCH_DMRS * sqrt(numLayers / numCSIRSPorts);
        end

        %% =============================================================
        %  8.2.2 — PSSCH DM-RS
        %  =============================================================

        function pattern = selectDMRSPattern(cfg, dmrsPatternField)
        %selectDMRSPattern Select DM-RS time-domain pattern
        %   If one pattern configured → use it directly.
        %   Otherwise → 'DMRS pattern' field in SCI 1-A selects from list.
        %
        %   Returns the number of DM-RS symbols (2, 3, or 4).

            patList = cfg.DMRSPatternList;
            if length(patList) == 1
                pattern = patList(1);
            else
                idx = dmrsPatternField + 1;  % 0-based → 1-based
                assert(idx >= 1 && idx <= length(patList), ...
                    'SidelinkRefSignals:DMRSIdx', ...
                    'DMRS pattern index %d out of range for list of length %d', ...
                    dmrsPatternField, length(patList));
                pattern = patList(idx);
            end
        end

        function ok = checkDMRSPSCCHCoexistence(subchannelSizePRBs)
        %checkDMRSPSCCHCoexistence §8.2.2: Can DM-RS and PSCCH share a symbol?
        %   Only supported if sl-SubchannelSize ≥ 20 PRBs.
            ok = (subchannelSizePRBs >= 20);
        end

        %% =============================================================
        %  8.2.3 — PT-RS
        %  =============================================================

        function supported = isPTRSSupported(frequencyRange)
        %isPTRSSupported §8.2.3: PT-RS is only supported in FR2
        %   Input: 'FR1' or 'FR2'
            supported = strcmpi(frequencyRange, 'FR2');
        end

        %% =============================================================
        %  8.2.4 — SL PRS Helpers
        %  =============================================================

        function [startSym, numSym] = determineSLPRSSymbols(cfg, prsResourceID, isSharedPool)
        %determineSLPRSSymbols Determine SL PRS time-domain allocation
        %   For shared pool: mapped to last L consecutive symbols meeting
        %   all restrictions (clause 8.2.4.1.1).
        %   For dedicated pool: from sl-PRS-starting-symbol and sl-NumberOfSymbols.
        %
        %   This is a placeholder — actual implementation depends on the
        %   SL PRS resource configuration from higher layers.

            if isSharedPool
                % Shared pool: SL PRS at tail of PSSCH allocation
                numSym = 2;   % placeholder; from mNumberOfSymbols
                startSym = cfg.LengthSymbols - 2 - numSym;  % approximate
            else
                % Dedicated pool: from per-resource config
                numSym = 2;   % from sl-NumberOfSymbols
                startSym = 4; % from sl-PRS-starting-symbol (placeholder)
            end
        end

        %% =============================================================
        %  8.4.2.1 — RSRP Measurement Mode for Mode 2 Sensing
        %  =============================================================

        function rsType = getRSRPMeasurementType(rsForSensing)
        %getRSRPMeasurementType §8.4.2.1: Which RS to use for RSRP
        %   Input: 'pssch' or 'pscch' (from sl-RS-ForSensing)
        %   Output: description string

            switch lower(rsForSensing)
                case 'pssch'
                    rsType = 'PSSCH-RSRP over PSSCH DM-RS REs';
                case 'pscch'
                    rsType = 'PSCCH-RSRP over PSCCH DM-RS REs';
                otherwise
                    rsType = 'PSCCH-RSRP over PSCCH DM-RS REs';  % default
            end
        end

        %% =============================================================
        %  8.5 — CSI Reporting Framework
        %  =============================================================

        function cqiTable = getCQITable(mcsTableName)
        %getCQITable §8.5.2.1.1: Map MCS table name → CQI table
            switch mcsTableName
                case 'table1', cqiTable = 'cqi-Table1';
                case 'table2', cqiTable = 'cqi-Table2';
                case 'table3', cqiTable = 'cqi-Table3';
                otherwise,     cqiTable = 'cqi-Table1';
            end
        end

        function nDMRS = csiRefResourceDMRS(dmrsPatternList)
        %csiRefResourceDMRS §8.5.2.3: Assume smallest DM-RS count for CSI ref
            nDMRS = min(dmrsPatternList);
        end
    end
end
