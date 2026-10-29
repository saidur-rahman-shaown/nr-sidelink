function grid = slAgcSymbol(grid, firstSymbol, subcarriers)
%slAgcSymbol Duplicate the first PSSCH/PSCCH symbol into the symbol before it (the AGC symbol).
%Spec:   TS 38.211 V16.10.0, clause 8.2.1: "The first OFDM symbol of a PSSCH and its associated
%        PSCCH is duplicated as described in clauses 8.3.1.5 and 8.3.2.3." Clause 8.3.1.5: "The
%        resource elements used for the PSSCH in the first OFDM symbol in the mapping operation
%        above, including any DM-RS, PT-RS, or CSI-RS occurring in the first OFDM symbol, shall be
%        duplicated in the OFDM symbol immediately preceding the first OFDM symbol in the
%        mapping." Clause 8.3.2.3 says the same for the PSCCH.
%Inputs: grid         nSubcarriers-by-nSymbols complex -- the slot grid, PSCCH and PSSCH already
%                     mapped (the duplication copies what is there, so it runs LAST)
%        firstSymbol  integer, >=1 -- 0-based index l of the first mapped symbol; the AGC symbol
%                     is firstSymbol-1
%        subcarriers  1 x n integer -- 0-based subcarrier indices k of the allocation (the
%                     PSSCH's PRBs, which contain the PSCCH's)
%Outputs: grid  with column firstSymbol-1 equal to column firstSymbol on those subcarriers
%
%Only the allocation's own subcarriers are copied. A whole-column copy would also copy another
%UE's transmission sharing the slot in a different sub-channel -- harmless in a single-UE grid,
%wrong the moment two transmitters are summed.

if ~(firstSymbol >= 1 && firstSymbol < size(grid, 2) && mod(firstSymbol, 1) == 0)
    error('ts38211:slAgcSymbol:badSymbol', 'slAgcSymbol: firstSymbol must be an integer in 1..%d, got %s', size(grid, 2) - 1, num2str(firstSymbol));
end
if any(subcarriers < 0 | subcarriers >= size(grid, 1) | mod(subcarriers, 1) ~= 0)
    error('ts38211:slAgcSymbol:badSubcarrier', 'slAgcSymbol: subcarriers must be integers in 0..%d', size(grid, 1) - 1);
end
grid(subcarriers + 1, firstSymbol) = grid(subcarriers + 1, firstSymbol + 1);
end
