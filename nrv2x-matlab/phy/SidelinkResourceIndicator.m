classdef SidelinkResourceIndicator
%SidelinkResourceIndicator TRIV, FRIV, PRIV encode/decode
%   Pure static utility — TS 38.214 Section 8.1.5, 8.1.5A, 8.2.4.2A
%
%   TRIV (Time Resource Indicator Value)
%     Encodes the number of reserved resources N ∈ {1,2,3} and their
%     logical-slot offsets (t₁, t₂) relative to the SCI format 1-A slot.
%     Field: 'Time resource assignment' in SCI 1-A (5 or 9 bits).
%
%   FRIV (Frequency Resource Indicator Value)
%     Encodes L_subCH and starting sub-channel indices for resources 2, 3.
%     Resource 1's sub-channel is determined from PSCCH (clause 8.1.2.2).
%     Field: 'Frequency resource assignment' in SCI 1-A.
%
%   PRIV (PRS Resource ID Value)
%     Encodes SL PRS resource IDs for resources 2, 3 in dedicated pool.
%     Field: 'Resource ID indication' in SCI 1-B.
%
%   Usage:
%     triv = SidelinkResourceIndicator.encodeTRIV(3, 4, 12, 3);
%     [N, t1, t2] = SidelinkResourceIndicator.decodeTRIV(triv, 3);
%
%     friv = SidelinkResourceIndicator.encodeFRIV(2, 3, 10, 3, 7);
%     [~, n1, n2] = SidelinkResourceIndicator.decodeFRIV(friv, 2, 10, 3);

    methods (Static)

        %% =============================================================
        %  TRIV — Time Resource Indicator Value (§8.1.5)
        %  =============================================================

        function triv = encodeTRIV(N, t1, t2, maxReserve)
        %encodeTRIV Encode time offsets into TRIV
        %
        %   N=1: TRIV = 0
        %   N=2: TRIV = t₁                              (1 ≤ t₁ ≤ 31)
        %   N=3, gap ≤ 15: TRIV = 30·(t₂−t₁−1) + t₁ + 31
        %   N=3, gap > 15: TRIV = 30·(31−t₂+t₁) + 62 − t₁
        %
        %   Inputs:
        %     N          — Number of reserved resources (1, 2, or 3)
        %     t1         — Logical-slot offset of 2nd resource (0 if N=1)
        %     t2         — Logical-slot offset of 3rd resource (0 if N≤2)
        %     maxReserve — sl-MaxNumPerReserve (2 or 3)

            if N == 1
                triv = 0;
                return;
            end

            if maxReserve == 2
                assert(N == 2 && t1 >= 1 && t1 <= 31, ...
                    'SidelinkResourceIndicator:TRIV', ...
                    'N must be ≤2 and 1≤t1≤31 for maxReserve=2');
                triv = t1;
                return;
            end

            % maxReserve == 3
            if N == 2
                assert(t1 >= 1 && t1 <= 31, ...
                    'SidelinkResourceIndicator:TRIV', '1≤t1≤31 required');
                triv = t1;
            elseif N == 3
                assert(t1 >= 1 && t1 <= 30 && t2 > t1 && t2 <= 31, ...
                    'SidelinkResourceIndicator:TRIV', ...
                    '1≤t1≤30, t1<t2≤31 required for N=3');
                gap = t2 - t1 - 1;
                if gap <= 15
                    triv = 30 * gap + t1 + 31;
                else
                    triv = 30 * (31 - t2 + t1) + 62 - t1;
                end
            else
                error('SidelinkResourceIndicator:TRIV', 'N must be 1, 2, or 3');
            end
        end

        function [N, t1, t2] = decodeTRIV(triv, maxReserve)
        %decodeTRIV Decode TRIV back to (N, t₁, t₂)

            if triv == 0
                N = 1; t1 = 0; t2 = 0;
                return;
            end

            if maxReserve == 2
                N = 2; t1 = triv; t2 = 0;
                return;
            end

            % maxReserve == 3
            if triv >= 1 && triv <= 31
                N = 2; t1 = triv; t2 = 0;
                return;
            end

            % N = 3: small-gap case first
            N = 3;
            val = triv - 31;
            t1 = mod(val, 30);
            gap = floor(val / 30);
            if gap >= 0 && gap <= 15 && t1 >= 1 && t1 <= 30
                t2 = gap + 1 + t1;
                if t1 < t2 && t2 <= 31, return; end
            end

            % large-gap case
            for u = 0:15
                t1c = 62 - triv + 30 * u;
                if t1c >= 1 && t1c <= 30
                    t2c = 31 - u + t1c;
                    if (t2c - t1c - 1) > 15 && t1c < t2c && t2c <= 31
                        t1 = t1c; t2 = t2c;
                        return;
                    end
                end
            end
            error('SidelinkResourceIndicator:TRIV', ...
                'Cannot decode TRIV=%d with maxReserve=%d', triv, maxReserve);
        end

        function bits = trivBitWidth(maxReserve)
        %trivBitWidth Bit width of TRIV field in SCI 1-A
            if maxReserve == 2, bits = 5; else, bits = 9; end
        end

        %% =============================================================
        %  FRIV — Frequency Resource Indicator Value (§8.1.5)
        %  =============================================================

        function friv = encodeFRIV(L_subCH, n_start_1, N_sub, maxReserve, n_start_2)
        %encodeFRIV Encode sub-channel allocation into FRIV
        %
        %   max=2: FRIV = n₁ + Σ_{i=1}^{L-1}(N+1−i)
        %   max=3: FRIV = n₁ + n₂·(N+1−L) + Σ_{i=1}^{L-1}(N+1−i)
        %
        %   Inputs:
        %     L_subCH    — Contiguous sub-channels per resource
        %     n_start_1  — Starting sub-channel of 2nd resource
        %     N_sub      — Total sub-channels in the pool
        %     maxReserve — 2 or 3
        %     n_start_2  — Starting sub-channel of 3rd resource (max=3 only)

            triSum = sum(N_sub + 1 - (1:(L_subCH - 1)));

            if maxReserve == 2
                friv = n_start_1 + triSum;
            else
                if nargin < 5, n_start_2 = 0; end
                friv = n_start_1 + n_start_2 * (N_sub + 1 - L_subCH) + triSum;
            end
        end

        function [L_subCH, n_start_1, n_start_2] = decodeFRIV(friv, L_subCH, N_sub, maxReserve)
        %decodeFRIV Decode FRIV back to starting sub-channels
        %   L_subCH must be known from the initial resource allocation.

            triSum = sum(N_sub + 1 - (1:(L_subCH - 1)));
            remainder = friv - triSum;

            if maxReserve == 2
                n_start_1 = remainder;
                n_start_2 = 0;
            else
                denom = N_sub + 1 - L_subCH;
                n_start_2 = floor(remainder / denom);
                n_start_1 = mod(remainder, denom);
            end
        end

        function bits = frivBitWidth(N_sub, maxReserve)
        %frivBitWidth Bit width of FRIV field in SCI 1-A
            if maxReserve == 2
                v = N_sub * (N_sub + 1) / 2;
            else
                v = N_sub * (N_sub + 1) * (2 * N_sub + 1) / 6;
            end
            bits = ceil(log2(max(v, 2)));
        end

        function bits = frivBitWidthInterlaced(N_sub, N_RBset, maxReserve)
        %frivBitWidthInterlaced FRIV bits for interlaced RB: X + Y
            Y = SidelinkResourceIndicator.frivBitWidth(N_sub, maxReserve);
            X = SidelinkResourceIndicator.frivBitWidth(N_RBset, maxReserve);
            bits = X + Y;
        end

        %% =============================================================
        %  PRIV — PRS Resource ID Value (§8.2.4.2A)
        %  =============================================================

        function priv = encodePRIV(r1, N_SL_PRS, maxReserve, r2)
        %encodePRIV Encode SL PRS resource ID for dedicated pool
        %   max=2: PRIV = r₁
        %   max=3: PRIV = r₂ · N_SL_PRS + r₁
            if maxReserve == 2
                priv = r1;
            else
                if nargin < 4, r2 = 0; end
                priv = r2 * N_SL_PRS + r1;
            end
        end

        function [r1, r2] = decodePRIV(priv, N_SL_PRS, maxReserve)
        %decodePRIV Decode PRIV back to (r₁, r₂)
            if maxReserve == 2
                r1 = priv; r2 = 0;
            else
                r2 = floor(priv / N_SL_PRS);
                r1 = mod(priv, N_SL_PRS);
            end
        end

        %% =============================================================
        %  High-level builder: resources → (TRIV, FRIV)
        %  =============================================================

        function [triv, friv] = buildResourceAssignment(offsets, startSubChs, L_subCH, N_sub, maxReserve)
        %buildResourceAssignment Convert human-readable resources to (TRIV, FRIV)
        %
        %   Inputs:
        %     offsets      — [0, t1, t2] logical-slot offsets (first is always 0)
        %     startSubChs  — [s0, s1, s2] starting sub-channel per resource
        %     L_subCH      — Contiguous sub-channels per resource
        %     N_sub        — Sub-channels in pool
        %     maxReserve   — 2 or 3
        %
        %   Outputs:
        %     triv, friv   — Values for SCI 1-A fields

            N = length(offsets);
            assert(offsets(1) == 0, 'First offset must be 0');
            RI = SidelinkResourceIndicator;  % just for shorter calls

            switch N
                case 1
                    triv = 0;
                    if maxReserve == 3
                        friv = RI.encodeFRIV(L_subCH, 0, N_sub, 3, 0);
                    else
                        friv = RI.encodeFRIV(L_subCH, 0, N_sub, 2);
                    end
                case 2
                    t1 = offsets(2);
                    if t1 < 1 || t1 > 31
                        % Out-of-range offset — degrade to N=1 (single resource)
                        triv = 0;
                        if maxReserve == 3
                            friv = RI.encodeFRIV(L_subCH, 0, N_sub, 3, 0);
                        else
                            friv = RI.encodeFRIV(L_subCH, 0, N_sub, 2);
                        end
                        return;
                    end
                    triv = RI.encodeTRIV(2, t1, 0, maxReserve);
                    if maxReserve == 3
                        friv = RI.encodeFRIV(L_subCH, startSubChs(2), N_sub, 3, 0);
                    else
                        friv = RI.encodeFRIV(L_subCH, startSubChs(2), N_sub, 2);
                    end
                case 3
                    triv = RI.encodeTRIV(3, offsets(2), offsets(3), maxReserve);
                    friv = RI.encodeFRIV(L_subCH, startSubChs(2), N_sub, 3, startSubChs(3));
                otherwise
                    error('SidelinkResourceIndicator:N', 'N must be 1, 2, or 3');
            end
        end
    end
end
