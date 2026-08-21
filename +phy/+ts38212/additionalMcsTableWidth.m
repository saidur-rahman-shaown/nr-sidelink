function n = additionalMcsTableWidth(sl_Additional_MCS_Table_r16)
%additionalMcsTableWidth Bit width of SCI-1A's "Additional MCS table indicator" field.
%Spec:   TS 38.212 V16.15.0, clause 8.3.1.1 (semantics of the higher-layer parameter in TS
%        38.214 clause 8.1.3.1, not extracted locally -- this only counts how many tables the
%        pool's resolved enum names, it does not interpret what the indicator value selects)
%Inputs: sl_Additional_MCS_Table_r16  char, pool.sl_Additional_MCS_Table_r16 as resolved by
%        +cfg/resourcePool.m: '' (not configured), 'qam256' or 'qam64LowSE' (one table), or
%        'qam256-qam64LowSE' (two tables)
%Outputs: n  0, 1, or 2 -- "1 bit if one MCS table is configured... 2 bits if two... 0 bit
%           otherwise"
switch sl_Additional_MCS_Table_r16
    case ''
        n = 0;
    case 'qam256-qam64LowSE'
        n = 2;
    case {'qam256', 'qam64LowSE'}
        n = 1;
    otherwise
        error('ts38212:additionalMcsTableWidth:badLabel', 'additionalMcsTableWidth: unrecognised sl_Additional_MCS_Table_r16 value "%s"', sl_Additional_MCS_Table_r16);
end
end
