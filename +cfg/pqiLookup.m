function row = pqiLookup(table, pqi)
%pqiLookup Convenience accessor: find the pqiTable() row for a given PQI value.
%Spec:   TS 23.287 clause 5.4.4 (see pqiTable.m for the caveat on row provenance)
%Inputs: table  1xN struct array as returned by cfg.pqiTable()
%        pqi    positive integer, the PC5 5QI value to look up
%Outputs: row  scalar struct, the matching table row
%
%A convenience accessor rather than a second, flattened copy of the table -- see
%+cfg/CLAUDE.md interface rule "the tree is never flattened."
idx = find([table.PQI] == pqi, 1);
if isempty(idx)
    error('cfg:pqiLookup:unknownPQI', 'PQI %d is not present in the PQI table', pqi);
end
row = table(idx);
end
