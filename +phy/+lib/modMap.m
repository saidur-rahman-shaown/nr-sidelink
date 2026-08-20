function symbols = modMap(bits, modScheme)
%modMap Modulation mapper. Toolbox body: nrSymbolModulate.
%Spec:   TS 38.211 V16.10.0, clause 5.1
%Inputs: bits       column vector of 0/1 (or logical), length a multiple of the
%                   scheme's bits-per-symbol
%        modScheme  char, one of 'pi/2-BPSK','BPSK','QPSK','16QAM','64QAM','256QAM'
%                   -- the six Rel-16 sidelink modulation orders. The toolbox's
%                   '1024QAM' is a later-release addition, out of this project's
%                   scope (see +cfg/CLAUDE.md scope decision), so it is rejected
%                   here even though nrSymbolModulate itself would accept it.
%Outputs: symbols  column vector of complex modulation symbols, unit average power
%
%Verified: QPSK output matches TS 38.211 Table 5.1.3-1 exactly; unit average
%power confirmed for all six schemes. See +phy/+lib/ch5-toolbox-survey.md.
legalSchemes = {'pi/2-BPSK', 'BPSK', 'QPSK', '16QAM', '64QAM', '256QAM'};
if ~ismember(modScheme, legalSchemes)
    error('lib:modMap:badScheme', 'modMap: "%s" is not a Rel-16 sidelink modulation scheme', modScheme);
end
symbols = nrSymbolModulate(bits(:), modScheme);
end
