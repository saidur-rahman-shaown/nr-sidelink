function beta = betaOffsetSci2(betaOffsets2ndSci, indicator)
%betaOffsetSci2 beta_offset^SCI2 for a 2nd-stage SCI, from SCI-1A's indicator and the pool list.
%Spec:   TS 38.212 V16.15.0, clause 8.3.1.1, Table 8.3.1.1-2 ("Mapping of Beta_offset indicator
%        values to indexes in Table 9.3-2 of [5, TS38.213]": indicator 00..11 selects the 1st..4th
%        index provided by sl-BetaOffsets2ndSCI); TS 38.213 V16.17.0, clause 9.3, Table 9.3-2
%        ("Mapping of beta_offset values for CSI and the index signalled by higher layers");
%        TS 38.331 sl-BetaOffsets2ndSCI: "The value indicates the index of Table 9.3-2".
%Inputs: betaOffsets2ndSci  1 x 4 integer, each 0..18 -- sl-BetaOffsets2ndSCI-r16
%        indicator          integer, 0..3 -- SCI format 1-A 'Beta_offset indicator'
%Outputs: beta  real, 1.125..20.000
%
%Indices 19..31 of Table 9.3-2 are "Reserved" and raise rather than map to anything.

TABLE_9_3_2 = [1.125 1.250 1.375 1.625 1.750 2.000 2.250 2.500 2.875 3.125 ...
               3.500 4.000 5.000 6.250 8.000 10.000 12.625 15.875 20.000];   % indices 0..18
N_CANDIDATES = 4;     % SEQUENCE (SIZE (4)) OF SL-BetaOffsets-r16

if numel(betaOffsets2ndSci) ~= N_CANDIDATES
    error('ts38213:betaOffsetSci2:badList', 'betaOffsetSci2: sl-BetaOffsets2ndSCI has exactly %d entries, got %d', N_CANDIDATES, numel(betaOffsets2ndSci));
end
if ~(indicator >= 0 && indicator < N_CANDIDATES && mod(indicator, 1) == 0)
    error('ts38213:betaOffsetSci2:badIndicator', 'betaOffsetSci2: the Beta_offset indicator is 2 bits (0..3), got %s', num2str(indicator));
end
if any(betaOffsets2ndSci < 0 | betaOffsets2ndSci >= numel(TABLE_9_3_2) | mod(betaOffsets2ndSci, 1) ~= 0)
    error('ts38213:betaOffsetSci2:reserved', 'betaOffsetSci2: every sl-BetaOffsets2ndSCI entry must index Table 9.3-2 (0..18)');
end
idx = betaOffsets2ndSci(indicator + 1);
if ~(idx >= 0 && idx < numel(TABLE_9_3_2) && mod(idx, 1) == 0)
    error('ts38213:betaOffsetSci2:reserved', 'betaOffsetSci2: Table 9.3-2 index %s is reserved or invalid', num2str(idx));
end
beta = TABLE_9_3_2(idx + 1);
end
