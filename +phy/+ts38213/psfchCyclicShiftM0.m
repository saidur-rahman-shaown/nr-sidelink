function m0 = psfchCyclicShiftM0(csPairIndex, NCS)
%psfchCyclicShiftM0 m0 value for a PSFCH cyclic shift, from a cyclic-shift-pair index.
%Spec:   TS 38.213 V16.17.0, clause 16.3, Table 16.3-1
%Inputs: csPairIndex  integer, 0..(number of pairs for NCS)-1 -- cyclic-shift pair index, from
%                     psfchResource
%        NCS          integer, one of {1,2,3,6} -- N_CS^PSFCH, sl-NumMuxCS-Pair
%Outputs: m0  integer, 0..11 -- the m0 value; feeds TS 38.211's cyclic shift alpha formula
%             (phy.ts38211.slPSFCHAlpha)
%
%Table confirmed by independent-verifier via pdftotext -bbox column-geometry cross-check
%(catches the same class of merged-cell/column-misassociation risk already seen in this
%project's other tables), not by -layout text alone.
switch NCS
    case 1
        table = 0;
    case 2
        table = [0 3];
    case 3
        table = [0 2 4];
    case 6
        table = [0 1 2 3 4 5];
    otherwise
        error('ts38213:psfchCyclicShiftM0:badNCS', 'psfchCyclicShiftM0: NCS must be one of {1,2,3,6}, got %s', num2str(NCS));
end
if ~(csPairIndex >= 0 && csPairIndex <= numel(table) - 1 && mod(csPairIndex, 1) == 0)
    error('ts38213:psfchCyclicShiftM0:badIndex', 'psfchCyclicShiftM0: csPairIndex must be an integer in 0..%d for NCS=%d, got %s', numel(table) - 1, NCS, num2str(csPairIndex));
end
m0 = table(csPairIndex + 1);
end
