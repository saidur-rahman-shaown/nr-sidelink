function ind = slSPSSIndices()
%slSPSSIndices S-PSS resource element indices within one S-SS/PSBCH block.
%Spec:   TS 38.211 V16.10.0, clause 8.4.3.1.1, Table 8.4.3.1-1
%Inputs: none (the mapping is fixed; nothing about it is config-dependent)
%Outputs: ind  254-by-2 integer matrix, columns [k l], 0-based and relative to
%              the S-SS/PSBCH block's own origin (k = 0..131 across the
%              block's 132 subcarriers, l = 0..Nsymb^S-SSB-1). k spans 2..128
%              (127 values) at l=1, then the identical 127 k-values again at
%              l=2 -- the same 127-value slSPSS() sequence is placed once per
%              symbol (a repetition for robustness, not one continuous
%              254-long sequence), in increasing k order within each symbol,
%              per clause 8.4.3.1.1.
k = (2:128)';
ind = [repmat(k, 2, 1), [ones(127, 1); 2*ones(127, 1)]];
end
