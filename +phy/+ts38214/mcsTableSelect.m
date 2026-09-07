function [modulation, Qm, targetCodeRate] = mcsTableSelect(IMcs, additionalMcsTableConfig, mcsTableIndicator)
%mcsTableSelect Modulation order and target code rate for a PSSCH MCS index.
%Spec:   TS 38.214 V16.17.0, clause 8.1.3.1 (MCS table selection) and Tables 8.1.3.1-1/-2
%        (indicator-to-table mapping); the tables themselves (5.1.3.1-1/-2/-3) are clause 5.1.3.1
%        content, reused verbatim here as required by clause 8.1.3.1's cross-reference.
%Inputs: IMcs                      integer, 0..31 -- 'Modulation and coding scheme' field of
%                                  SCI format 1-A, I_MCS
%        additionalMcsTableConfig  string, one of {'', 'table2', 'table3', 'table2table3'} --
%                                  sl-Additional-MCS-Table (as resolved by
%                                  +cfg/resourcePool.m's sl_Additional_MCS_Table_r16; '' means
%                                  the field is absent)
%        mcsTableIndicator         integer -- SCI format 1-A's 'Additional MCS table
%                                  indicator' field, decoded to its integer value. Field width
%                                  is 0 bits (value must be 0) if additionalMcsTableConfig=='',
%                                  1 bit (0 or 1) if 'table2' or 'table3' alone, 2 bits (0..3)
%                                  if 'table2table3' -- caller derives the width from the same
%                                  additionalMcsTableConfig value, per +phy/CLAUDE.md's rule
%                                  that SCI field widths come from the pool config
%Outputs: modulation      char row vector, one of {'QPSK','16QAM','64QAM','256QAM'} -- feeds
%                         tbsDetermine and the PSSCH modulation mapper
%         Qm              integer, one of {2,4,6,8} -- modulation order
%         targetCodeRate  real, 0 < R < 1 -- target code rate; feeds tbsDetermine
%
%Table 5.1.3.1-1/-2/-3 lookup is delegated to nrPDSCHMCSTables, per +phy/+ts38213/CLAUDE.md's
%precedent for calling a 5G Toolbox function that documents implementing exactly the cited
%clause (there, nrULSCH for TS 38.214 6.2.1-6.2.6; here, nrPDSCHMCSTables for TS 38.214
%5.1.3.1 -- its own help text states this explicitly). QAM64Table/QAM256Table/QAM64LowSETable
%correspond to Table 5.1.3.1-1/-2/-3 respectively; sidelink clause 8.1.3.1 reuses these same
%tables (they are defined once in clause 5, referenced by clause 8), not a sidelink-specific
%variant. A reserved MCS index (TargetCodeRate == NaN in the toolbox table, at I_MCS 28..31 or
%29..31 depending on table) is rejected rather than silently propagated -- this is exactly the
%boundary clause 8.1.3.1's closing sentence describes ("a UE is not expected to receive an SCI
%indicating 28<=IMCS<=31 if Table 5.1.3.1-2 is used, or 29<=IMCS<=31 otherwise").
if ~(IMcs >= 0 && IMcs <= 31 && mod(IMcs, 1) == 0)
    error('ts38214:mcsTableSelect:badIMcs', 'mcsTableSelect: IMcs must be an integer in 0..31, got %s', num2str(IMcs));
end

switch additionalMcsTableConfig
    case ''
        if mcsTableIndicator ~= 0
            error('ts38214:mcsTableSelect:badIndicator', 'mcsTableSelect: additionalMcsTableConfig is absent, so the indicator field does not exist -- expected mcsTableIndicator=0, got %d', mcsTableIndicator);
        end
        tableName = 'QAM64Table';
    case 'table2'
        if ~any(mcsTableIndicator == [0 1])
            error('ts38214:mcsTableSelect:badIndicator', 'mcsTableSelect: 1-bit indicator must be 0 or 1, got %d', mcsTableIndicator);
        end
        if mcsTableIndicator == 0, tableName = 'QAM64Table'; else, tableName = 'QAM256Table'; end
    case 'table3'
        if ~any(mcsTableIndicator == [0 1])
            error('ts38214:mcsTableSelect:badIndicator', 'mcsTableSelect: 1-bit indicator must be 0 or 1, got %d', mcsTableIndicator);
        end
        if mcsTableIndicator == 0, tableName = 'QAM64Table'; else, tableName = 'QAM64LowSETable'; end
    case 'table2table3'
        if ~any(mcsTableIndicator == [0 1 2 3])
            error('ts38214:mcsTableSelect:badIndicator', 'mcsTableSelect: 2-bit indicator must be 0..3, got %d', mcsTableIndicator);
        end
        switch mcsTableIndicator
            case 0, tableName = 'QAM64Table';
            case 1, tableName = 'QAM256Table';
            case 2, tableName = 'QAM64LowSETable';
            case 3
                error('ts38214:mcsTableSelect:reservedIndicator', 'mcsTableSelect: 2-bit indicator value 3 (''11'') is reserved (Table 8.1.3.1-2)');
        end
    otherwise
        error('ts38214:mcsTableSelect:badConfig', 'mcsTableSelect: additionalMcsTableConfig must be one of {'''',''table2'',''table3'',''table2table3''}, got "%s"', additionalMcsTableConfig);
end

mcsTables = nrPDSCHMCSTables;
tbl = mcsTables.(tableName);
row = tbl.MCSIndex == IMcs;
targetCodeRate = tbl.TargetCodeRate(row);
if isnan(targetCodeRate)
    error('ts38214:mcsTableSelect:reservedMcs', 'mcsTableSelect: IMcs=%d is reserved in %s (clause 8.1.3.1 out-of-coverage boundary)', IMcs, tableName);
end
modulation = tbl.Modulation{row};
Qm = tbl.Qm(row);
end
