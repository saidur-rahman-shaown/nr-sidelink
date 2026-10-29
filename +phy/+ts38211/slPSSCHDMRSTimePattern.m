function lbar = slPSSCHDMRSTimePattern(ld, pscchSymbols, nDmrs)
%slPSSCHDMRSTimePattern PSSCH DM-RS symbol positions l-bar for a slot.
%Spec:   TS 38.211 V16.10.0, clause 8.4.1.1.2, Table 8.4.1.1.2-1 ("PSSCH DM-RS time-domain
%        location"): "l_d is the duration of the scheduled resources for transmission of PSSCH
%        and the associated PSCCH, including the OFDM symbol duplicated as described in clauses
%        8.3.1.5 and 8.3.2.3", and l is "relative to the start of the scheduled resources ...
%        including the OFDM symbol duplicated".
%Inputs: ld            integer, 6..13 -- l_d in symbols (the duplicated AGC symbol INCLUDED, the
%                      guard symbol EXCLUDED: a 14-symbol sidelink slot with no PSFCH has l_d=13)
%        pscchSymbols  integer, 2 or 3 -- sl-TimeResourcePSCCH
%        nDmrs         integer, 2..4 -- the number of PSSCH DM-RS symbols, i.e. the entry of
%                      sl-PSSCH-DMRS-TimePatternList that SCI-1A's 'DMRS pattern' field selects
%Outputs: lbar  1 x nDmrs integer row vector, ascending -- symbol indices l relative to the
%               first (duplicated) symbol of the allocation
%
%The table has holes: 3 DM-RS needs l_d >= 9 and 4 DM-RS needs l_d >= 11. Those combinations
%are not "use the nearest row" -- the transmitter cannot select them -- so they raise.
%
%Transcribed from the rendered table, not from pdftotext, because the text extraction of this
%table runs the PSCCH-2 and PSCCH-3 column groups together.

LD_MIN = 6;
LD_MAX = 13;
if ~(ld >= LD_MIN && ld <= LD_MAX && mod(ld, 1) == 0)
    error('ts38211:slPSSCHDMRSTimePattern:badLd', 'slPSSCHDMRSTimePattern: l_d must be an integer in %d..%d, got %s', LD_MIN, LD_MAX, num2str(ld));
end
if ~any(pscchSymbols == [2 3])
    error('ts38211:slPSSCHDMRSTimePattern:badPscch', 'slPSSCHDMRSTimePattern: PSCCH duration must be 2 or 3 symbols, got %s', num2str(pscchSymbols));
end
if ~any(nDmrs == [2 3 4])
    error('ts38211:slPSSCHDMRSTimePattern:badCount', 'slPSSCHDMRSTimePattern: DM-RS count must be 2, 3 or 4, got %s', num2str(nDmrs));
end

lbar = [];
switch nDmrs
    case 2
        if ld <= 8
            lbar = [1 5];
        elseif ld <= 10
            if pscchSymbols == 2, lbar = [3 8]; else, lbar = [4 8]; end
        else
            if pscchSymbols == 2, lbar = [3 10]; else, lbar = [4 10]; end
        end
    case 3
        if ld >= 9 && ld <= 10
            lbar = [1 4 7];
        elseif ld >= 11 && ld <= 12
            lbar = [1 5 9];
        elseif ld == 13
            lbar = [1 6 11];
        end
    case 4
        if ld >= 11
            lbar = [1 4 7 10];
        end
end
if isempty(lbar)
    error('ts38211:slPSSCHDMRSTimePattern:notInTable', ...
        'slPSSCHDMRSTimePattern: Table 8.4.1.1.2-1 has no entry for l_d=%d with %d DM-RS symbols', ld, nDmrs);
end
end
