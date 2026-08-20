classdef SidelinkMCS
%SidelinkMCS MCS table lookup and Transport Block Size determination
%   Pure static utility — TS 38.214 Sections 8.1.3, 5.1.3
%
%   Implements:
%     8.1.3.1 — Modulation order and target code rate determination
%     8.1.3.2 — Transport block size (TBS) determination
%     Table 8.1.3.2-1 — N^DMRS_RE mapping
%     Tables 5.1.3.1-1/2/3 — MCS index tables
%     Table 5.1.3.2-2 — Small TBS lookup table
%
%   Usage:
%     [Qm, R] = SidelinkMCS.lookupMCS(15, 'table1');
%     tbs = SidelinkMCS.determineTBS(cfg, 15, 0, 50, 72, 80, 0, 0);

    methods (Static)

        %% =============================================================
        %  8.1.3.1 — MCS Table Selection
        %  =============================================================

        function tblName = selectMCSTable(additionalMCSTableBits, additionalMCSInd)
        %selectMCSTable Determine which MCS table to use
        %   Per Tables 8.1.3.1-1 and 8.1.3.1-2
        %
        %   Inputs:
        %     additionalMCSTableBits — 0, 1, or 2 (from config)
        %     additionalMCSInd       — Additional MCS table indicator field

            switch additionalMCSTableBits
                case 0
                    tblName = 'table1';
                case 1
                    if additionalMCSInd == 0
                        tblName = 'table1';
                    else
                        tblName = 'table2';
                    end
                case 2
                    switch additionalMCSInd
                        case 0, tblName = 'table1';
                        case 1, tblName = 'table2';
                        case 2, tblName = 'table3';
                        otherwise
                            error('SidelinkMCS:Reserved', 'MCS indicator 11 is reserved');
                    end
                otherwise
                    tblName = 'table1';
            end
        end

        %% =============================================================
        %  8.1.3.1 — Modulation Order and Code Rate Lookup
        %  =============================================================

        function [Qm, R] = lookupMCS(I_MCS, tblName)
        %lookupMCS Get modulation order and code rate from MCS index
        %
        %   Outputs:
        %     Qm — Modulation order (2=QPSK, 4=16QAM, 6=64QAM, 8=256QAM)
        %     R  — Target code rate (0..1)

            tbl = SidelinkMCS.getMCSTable(tblName);
            assert(I_MCS + 1 <= size(tbl, 1), ...
                'SidelinkMCS:Reserved', 'I_MCS=%d is reserved in %s', I_MCS, tblName);
            Qm = tbl(I_MCS + 1, 2);
            R  = tbl(I_MCS + 1, 3) / 1024;
        end

        %% =============================================================
        %  Table 8.1.3.2-1 — N^DMRS_RE
        %  =============================================================

        function N = getDMRS_RE(dmrsPatternList)
        %getDMRS_RE N^DMRS_RE from configured DMRS pattern list
        %   dmrsPatternList is a vector, e.g. [2], [2 3], [3 4], [2 3 4]
            key = sort(dmrsPatternList(:)).';
            switch mat2str(key)
                case '[2]',     N = 12;
                case '[3]',     N = 18;
                case '[4]',     N = 24;
                case '[2 3]',   N = 15;
                case '[2 4]',   N = 18;
                case '[3 4]',   N = 21;
                case '[2 3 4]', N = 18;
                otherwise
                    error('SidelinkMCS:DMRSPattern', ...
                        'Invalid DMRS pattern list: %s', mat2str(key));
            end
        end

        %% =============================================================
        %  8.1.3.2 — TBS Determination
        %  =============================================================

        function tbs = determineTBS(cfg, I_MCS, additionalMCSInd, nPRB, ...
                nRE_PSCCH, nRE_SCI2, psfchOHIndicator, nSLPRS_symb)
        %determineTBS Transport Block Size for PSSCH
        %   Per TS 38.214 clause 8.1.3.2.
        %
        %   Inputs:
        %     cfg               — SidelinkConfig object
        %     I_MCS             — MCS index from SCI 1-A
        %     additionalMCSInd  — Additional MCS table indicator
        %     nPRB              — Total allocated PRBs for PSSCH
        %     nRE_PSCCH         — Total REs occupied by PSCCH + PSCCH DM-RS
        %     nRE_SCI2          — Coded modulation symbols for 2nd-stage SCI (γ=0)
        %     psfchOHIndicator  — PSFCH overhead indication (0 or 1)
        %     nSLPRS_symb       — SL PRS symbols (0 if not SCI 2-D)

            % Step 0: Qm and R from MCS table
            tblName = SidelinkMCS.selectMCSTable(cfg.AdditionalMCSTableBits, additionalMCSInd);
            [Qm, R] = SidelinkMCS.lookupMCS(I_MCS, tblName);
            nu = cfg.NumLayers;

            % Step 1: N'_RE per PRB
            N_sl_symb = cfg.effectiveSymbols();  % sl-LengthSymbols - 2

            % N_PSFCH_symb
            if cfg.PSFCHPeriod == 2 || cfg.PSFCHPeriod == 4
                N_PSFCH = 3 * psfchOHIndicator;
            elseif cfg.PSFCHPeriod == 1
                N_PSFCH = 3;
            else
                N_PSFCH = 0;
            end

            N_DMRS = SidelinkMCS.getDMRS_RE(cfg.DMRSPatternList);
            N_OH   = cfg.XOverhead;

            N_RE_prime = 12 * N_sl_symb - N_PSFCH - nSLPRS_symb - N_OH - N_DMRS;

            % Step 1b: Total N_RE
            N_RE = max(N_RE_prime * nPRB - nRE_PSCCH - nRE_SCI2, 0);

            % Step 2: N_info
            N_info = N_RE * R * Qm * nu;

            % Steps 2–4 of clause 5.1.3.2
            tbs = SidelinkMCS.nInfoToTBS(N_info, R);
        end

        %% =============================================================
        %  CQI table mapping (§8.5.2.1.1)
        %  =============================================================

        function cqiTable = getCQITable(mcsTableName)
        %getCQITable Map MCS table to CQI table for CSI reporting
            switch mcsTableName
                case 'table1', cqiTable = 'cqi-Table1';
                case 'table2', cqiTable = 'cqi-Table2';
                case 'table3', cqiTable = 'cqi-Table3';
                otherwise,     cqiTable = 'cqi-Table1';
            end
        end

        function names = getAvailableTables()
        %getAvailableTables Ordered list of supported 3GPP sidelink MCS tables
            names = {'table1', 'table2', 'table3'};
        end

        function ind = getAdditionalMCSIndicator(tblName)
        %getAdditionalMCSIndicator SCI 1-A indicator value for a table
            switch tblName
                case 'table1', ind = 0;
                case 'table2', ind = 1;
                case 'table3', ind = 2;
                otherwise
                    error('SidelinkMCS:Table', 'Unknown MCS table: %s', tblName);
            end
        end

        function modulation = modulationFromOrder(Qm)
        %modulationFromOrder Convert modulation order to toolbox label
            switch Qm
                case 2, modulation = 'QPSK';
                case 4, modulation = '16QAM';
                case 6, modulation = '64QAM';
                case 8, modulation = '256QAM';
                otherwise
                    error('SidelinkMCS:Modulation', ...
                        'Unsupported modulation order Qm=%d', Qm);
            end
        end

        function tableInfo = getTableEntries(tblName)
        %getTableEntries Return public metadata for one MCS table
            tbl = SidelinkMCS.getMCSTable(tblName);
            tableInfo = repmat(struct( ...
                'TableName', '', ...
                'TableNumber', 0, ...
                'TableDisplayName', '', ...
                'AdditionalMCSIndicator', 0, ...
                'I_MCS', 0, ...
                'Qm', 0, ...
                'Modulation', '', ...
                'CodeRateX1024', 0, ...
                'TargetCodeRate', 0, ...
                'SpectralEfficiency', 0, ...
                'ShortLabel', '', ...
                'Label', ''), size(tbl, 1), 1);

            tableNum = SidelinkMCS.tableNumber(tblName);
            tableDisplay = SidelinkMCS.tableDisplayName(tblName);
            addInd = SidelinkMCS.getAdditionalMCSIndicator(tblName);

            for idx = 1:size(tbl, 1)
                imcs = tbl(idx, 1);
                qm = tbl(idx, 2);
                rateX1024 = tbl(idx, 3);
                rate = rateX1024 / 1024;
                modulation = SidelinkMCS.modulationFromOrder(qm);

                tableInfo(idx).TableName = tblName;
                tableInfo(idx).TableNumber = tableNum;
                tableInfo(idx).TableDisplayName = tableDisplay;
                tableInfo(idx).AdditionalMCSIndicator = addInd;
                tableInfo(idx).I_MCS = imcs;
                tableInfo(idx).Qm = qm;
                tableInfo(idx).Modulation = modulation;
                tableInfo(idx).CodeRateX1024 = rateX1024;
                tableInfo(idx).TargetCodeRate = rate;
                tableInfo(idx).SpectralEfficiency = qm * rate;
                tableInfo(idx).ShortLabel = sprintf('T%d-M%02d', tableNum, imcs);
                tableInfo(idx).Label = sprintf( ...
                    'Table %d | I_{MCS}=%d | %s | R=%d/1024', ...
                    tableNum, imcs, modulation, rateX1024);
            end
        end

        function profiles = getAllProfiles()
        %getAllProfiles Flatten all supported sidelink MCS profiles
            names = SidelinkMCS.getAvailableTables();
            profiles = struct([]);
            for ni = 1:numel(names)
                entries = SidelinkMCS.getTableEntries(names{ni});
                if isempty(profiles)
                    profiles = entries;
                else
                    profiles = [profiles; entries]; %#ok<AGROW>
                end
            end
        end

        function profiles = getSelectedProfiles()
        %getSelectedProfiles 50 representative MCS profiles across 3 tables
        %   Selects uniformly-spaced entries from each table to cover the
        %   full spectral efficiency range while reducing simulation time.
        %
        %   Selection: ~17 per table (every-other index + endpoints)
        %     Table 1 (29 entries): I_MCS 0,2,4,6,8,10,12,14,16,18,20,22,24,26,28 → 15
        %     Table 2 (28 entries): I_MCS 0,2,4,6,8,10,12,14,16,18,20,22,24,26,27 → 15
        %     Table 3 (29 entries): I_MCS 0,2,4,6,8,10,12,14,16,18,20,22,24,26,28 → 15
        %   Total: 45 profiles (covers QPSK→256QAM, R=30/1024→948/1024)

            all = SidelinkMCS.getAllProfiles();

            % Table 1: even indices 0:2:28
            t1_idx = 0:2:28;
            % Table 2: even indices 0:2:26, plus last (27)
            t2_idx = [0:2:26, 27];
            % Table 3: even indices 0:2:28
            t3_idx = 0:2:28;

            mask = false(numel(all), 1);
            for k = 1:numel(all)
                switch all(k).TableNumber
                    case 1, mask(k) = ismember(all(k).I_MCS, t1_idx);
                    case 2, mask(k) = ismember(all(k).I_MCS, t2_idx);
                    case 3, mask(k) = ismember(all(k).I_MCS, t3_idx);
                end
            end
            profiles = all(mask);
        end

        function profiles = getPracticalProfiles()
        %getPracticalProfiles 30 MCS profiles — 3 code rates per modulation per table
        %   For each modulation order within each MCS table, selects three
        %   code rate entries: lowest, center, and highest.  This captures the
        %   operating range of every modulation without sweeping all entries.
        %
        %   Yields:
        %     Table 1: QPSK(3) + 16QAM(3) + 64QAM(3)           =  9
        %     Table 2: QPSK(3) + 16QAM(3) + 64QAM(3) + 256QAM(3) = 12
        %     Table 3: QPSK(3) + 16QAM(3) + 64QAM(3)           =  9
        %   Total: 30 profiles
        %
        %   Selection per modulation group:
        %     Low  = first entry (lowest code rate)
        %     Mid  = entry at ceil(nEntries/2)
        %     High = last entry (highest code rate)

            names = SidelinkMCS.getAvailableTables();
            profiles = struct([]);

            for ni = 1:numel(names)
                tbl = SidelinkMCS.getMCSTable(names{ni});
                entries = SidelinkMCS.getTableEntries(names{ni});
                modOrders = unique(tbl(:,2), 'stable');

                for mi = 1:numel(modOrders)
                    qm = modOrders(mi);
                    groupIdx = find(tbl(:,2) == qm);
                    nEntries = numel(groupIdx);

                    % Pick low, center, high
                    pickIdx = [groupIdx(1), ...
                               groupIdx(ceil(nEntries/2)), ...
                               groupIdx(end)];
                    pickIdx = unique(pickIdx, 'stable');  % deduplicate if <=2 entries

                    if isempty(profiles)
                        profiles = entries(pickIdx);
                    else
                        profiles = [profiles; entries(pickIdx)]; %#ok<AGROW>
                    end
                end
            end
        end

        function profiles = getRealisticProfiles()
        %getRealisticProfiles 9 MCS profiles for realistic system-level evaluation
        %   Returns 3 profiles per table: low, mid, high spectral efficiency.
        %   Designed for dense multi-UE scenarios where the full MCS sweep
        %   is impractical due to channel starvation at high density.
        %
        %   Selection (representative of operating regions):
        %     Table 1: I_MCS 4 (QPSK, R=308), 14 (16QAM, R=490), 24 (64QAM, R=873)
        %     Table 2: I_MCS 4 (QPSK, R=308), 14 (16QAM, R=490), 24 (256QAM, R=873)
        %     Table 3: I_MCS 4 (QPSK, R=120), 14 (16QAM, R=340), 24 (64QAM, R=616)
        %
        %   These span QPSK→256QAM, R=120/1024→873/1024, covering:
        %     - Robust (low MCS): survives interference, low throughput
        %     - Balanced (mid MCS): typical V2X operating point
        %     - Aggressive (high MCS): high throughput, fragile to interference

            all = SidelinkMCS.getAllProfiles();

            t1_idx = [4, 14, 24];   % Table 1: QPSK → 16QAM → 64QAM
            t2_idx = [4, 14, 24];   % Table 2: QPSK → 16QAM → 256QAM
            t3_idx = [4, 14, 24];   % Table 3: QPSK → 16QAM → 64QAM

            mask = false(numel(all), 1);
            for k = 1:numel(all)
                switch all(k).TableNumber
                    case 1, mask(k) = ismember(all(k).I_MCS, t1_idx);
                    case 2, mask(k) = ismember(all(k).I_MCS, t2_idx);
                    case 3, mask(k) = ismember(all(k).I_MCS, t3_idx);
                end
            end
            profiles = all(mask);
        end
    end

    %% =================================================================
    %  Internal helpers
    %  =================================================================
    methods (Static, Access = private)

        function tableNum = tableNumber(name)
            switch name
                case 'table1', tableNum = 1;
                case 'table2', tableNum = 2;
                case 'table3', tableNum = 3;
                otherwise
                    error('SidelinkMCS:Table', 'Unknown MCS table: %s', name);
            end
        end

        function label = tableDisplayName(name)
            switch name
                case 'table1', label = 'Table 1 (baseline up to 64QAM)';
                case 'table2', label = 'Table 2 (up to 256QAM)';
                case 'table3', label = 'Table 3 (low spectral efficiency)';
                otherwise
                    error('SidelinkMCS:Table', 'Unknown MCS table: %s', name);
            end
        end

        function tbs = nInfoToTBS(N_info, R)
        %nInfoToTBS Steps 2–4 of clause 5.1.3.2
            if N_info <= 3824
                n = max(3, floor(log2(max(N_info, 1))) - 6);
                Np = max(24, 2^n * floor(N_info / 2^n));
                tbs = SidelinkMCS.findClosestTBS(Np);
            else
                n = floor(log2(N_info - 24)) - 5;
                Np = max(3840, 2^n * round((N_info - 24) / 2^n));
                if R <= 0.25
                    C = ceil((Np + 24) / 3816);
                    tbs = 8 * C * ceil((Np + 24) / (8 * C)) - 24;
                elseif Np + 24 > 8424
                    C = ceil((Np + 24) / 8424);
                    tbs = 8 * C * ceil((Np + 24) / (8 * C)) - 24;
                else
                    tbs = 8 * ceil((Np + 24) / 8) - 24;
                end
            end
            tbs = max(tbs, 0);
        end

        function tbs = findClosestTBS(Np)
        %findClosestTBS Smallest TBS ≥ Np from Table 5.1.3.2-2
            T = [24 32 40 48 56 64 72 80 88 96 104 112 120 128 136 144 ...
                 152 160 168 176 184 192 208 224 240 256 272 288 304 320 ...
                 336 352 368 384 408 432 456 480 504 528 552 576 608 640 ...
                 672 704 736 768 808 848 888 928 984 1032 1064 1128 1160 ...
                 1192 1224 1256 1288 1320 1352 1416 1480 1544 1608 1672 ...
                 1736 1800 1864 1928 2024 2088 2152 2216 2280 2408 2472 ...
                 2536 2600 2664 2728 2792 2856 2976 3104 3240 3368 3496 ...
                 3624 3752 3824];
            idx = find(T >= Np, 1, 'first');
            if isempty(idx), tbs = T(end); else, tbs = T(idx); end
        end

        function tbl = getMCSTable(name)
        %getMCSTable Return [I_MCS, Qm, Rx1024] matrix
            switch name
                case 'table1'  % 5.1.3.1-1 (64QAM)
                    tbl = [ 0 2 120; 1 2 157; 2 2 193; 3 2 251; 4 2 308;
                            5 2 379; 6 2 449; 7 2 526; 8 2 602; 9 2 679;
                           10 4 340;11 4 378;12 4 434;13 4 490;14 4 553;
                           15 4 616;16 4 658;17 6 438;18 6 466;19 6 517;
                           20 6 567;21 6 616;22 6 666;23 6 719;24 6 772;
                           25 6 822;26 6 873;27 6 910;28 6 948];
                case 'table2'  % 5.1.3.1-2 (256QAM)
                    tbl = [ 0 2 120; 1 2 193; 2 2 308; 3 2 449; 4 2 602;
                            5 4 378; 6 4 434; 7 4 490; 8 4 553; 9 4 616;
                           10 4 658;11 6 466;12 6 517;13 6 567;14 6 616;
                           15 6 666;16 6 719;17 6 772;18 6 822;19 6 873;
                           20 8 682;21 8 711;22 8 754;23 8 797;24 8 841;
                           25 8 885;26 8 916;27 8 948];
                case 'table3'  % 5.1.3.1-3 (low SE, 64QAM)
                    tbl = [ 0 2  30; 1 2  40; 2 2  50; 3 2  64; 4 2  78;
                            5 2  99; 6 2 120; 7 2 157; 8 2 193; 9 2 251;
                           10 2 308;11 2 379;12 2 449;13 2 526;14 2 602;
                           15 4 340;16 4 378;17 4 434;18 4 490;19 4 553;
                           20 4 616;21 6 438;22 6 466;23 6 517;24 6 567;
                           25 6 616;26 6 666;27 6 719;28 6 772];
                otherwise
                    error('SidelinkMCS:Table', 'Unknown MCS table: %s', name);
            end
        end
    end
end
