function [dataSym, dmrsSym] = gridExtract(grid, dataInd, dmrsInd)
%gridExtract Pull a channel's data and DM-RS resource elements out of a received grid.
%Spec:   none -- extraction is a receiver operation, not a transmitted quantity.
%Inputs: grid     nSubcarriers-by-nSymbols complex matrix -- the demodulated received grid
%        dataInd  N-by-2 integer [k l] -- the data RE positions the transmit chain used
%        dmrsInd  M-by-2 integer [k l] -- the DM-RS RE positions
%Outputs: dataSym  N-by-1 complex column, in the same order as dataInd
%         dmrsSym  M-by-1 complex column, in the same order as dmrsInd
%
%ORDER IS PRESERVED, WHICH IS THE WHOLE CONTRACT
%------------------------------------------------
%The index lists come back from the transmit chain in mapping order, and the demodulator
%downstream assumes the symbols arrive in that same order. Sorting or uniquifying here -- which
%is tempting, since sub2ind does not care -- would silently permute the coded bit stream and
%produce a decoder that fails at every SNR.

if size(dataInd, 2) ~= 2 || (~isempty(dmrsInd) && size(dmrsInd, 2) ~= 2)
    error('rx:ce:gridExtract:badIndices', 'gridExtract: index lists must be N-by-2 [k l]');
end
sz = size(grid);
dataSym = grid(sub2ind(sz, dataInd(:, 1) + 1, dataInd(:, 2) + 1));
if isempty(dmrsInd)
    dmrsSym = complex(zeros(0, 1));
else
    dmrsSym = grid(sub2ind(sz, dmrsInd(:, 1) + 1, dmrsInd(:, 2) + 1));
end
end
