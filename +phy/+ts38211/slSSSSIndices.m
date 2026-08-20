function ind = slSSSSIndices()
%slSSSSIndices S-SSS resource element indices within one S-SS/PSBCH block.
%Spec:   TS 38.211 V16.10.0, clause 8.4.3.1.2, Table 8.4.3.1-1
%Inputs: none (the mapping is fixed; nothing about it is config-dependent)
%Outputs: ind  254-by-2 integer matrix, columns [k l], 0-based and relative to
%              the S-SS/PSBCH block's own origin. k spans 2..128 (127 values)
%              at l=3, then the identical 127 k-values again at l=4 -- the
%              same 127-value slSSSS() sequence is placed once per symbol, in
%              increasing k order within each symbol, per clause 8.4.3.1.2.
k = (2:128)';
ind = [repmat(k, 2, 1), [3*ones(127, 1); 4*ones(127, 1)]];
end
