function [tbs, NRE] = tbsDetermine(Qm, targetCodeRate, nLayers, nPRB, slLengthSymbols, slPsfchPeriod, psfchOverheadIndicated, nOhPRB, dmrsTimePattern, nReSci1, nReSci2)
%tbsDetermine PSSCH transport block size.
%Spec:   TS 38.214 V16.17.0, clause 8.1.3.2 (N_RE' and N_RE, including the PSCCH/2nd-stage-SCI
%        subtraction unique to PSSCH), then "Steps 2), 3), and 4) in clause 5.1.3.2" for TBS
%        quantisation, Table 8.1.3.2-1 (N_RE^DMRS), Table 5.1.3.2-1 (TBS quantisation table)
%Inputs: Qm                      integer, one of {2,4,6,8} -- modulation order, from
%                                mcsTableSelect
%        targetCodeRate          real, 0<R<1 -- from mcsTableSelect
%        nLayers                 integer, 1 or 2 -- number of PSSCH transmission layers
%        nPRB                    positive integer -- n_PRB, total allocated PRBs for the PSSCH
%        slLengthSymbols         integer, 7..14 -- sl-LengthSymbols
%        slPsfchPeriod           integer, one of {0,1,2,4} -- sl-PSFCH-Period (slots; 0 =
%                                PSFCH disabled)
%        psfchOverheadIndicated  logical scalar -- SCI format 1-A 'PSFCH overhead indication'
%                                field (only meaningful, and only read, when slPsfchPeriod is
%                                2 or 4)
%        nOhPRB                  integer, one of {0,3,6,9} -- sl-X-Overhead, N_oh^PRB
%        dmrsTimePattern         row vector, integer, values in 2..4, 1-3 entries, no repeats
%                                -- the FULL CONFIGURED sl-PSSCH-DMRS-TimePatternList (every
%                                entry the pool permits), NOT the single pattern the SCI 'DMRS
%                                pattern' field selects for this specific transmission. Table
%                                8.1.3.2-1 is keyed on "higher layer parameter
%                                sl-PSSCH-DMRS-TimePatternList" -- the parameter itself, i.e.
%                                the whole configured list -- confirmed via independent-verifier
%                                against 38.211 Table 8.4.1.1.2-1 and 38.212 8.3.1.1: the
%                                list's entries are DM-RS symbol COUNTS (not positions), the SCI
%                                field selects one entry per transmission, and Table 8.1.3.2-1's
%                                multi-entry rows are exactly the arithmetic mean of their
%                                singleton members ({2,3}->15=avg(12,18), {2,4}->18=avg(12,24),
%                                {3,4}->21=avg(18,24), {2,3,4}->18=avg(12,18,24)) -- which only
%                                makes sense if the row represents the configured SET, making
%                                TBS invariant to the per-transmission SCI selection. A single-
%                                entry list (only one pattern configured) is unaffected by this
%                                distinction, since "configured" and "selected" then coincide.
%        nReSci1                 nonnegative integer -- N_RE^SCI,1, total REs occupied by the
%                                PSCCH and its DM-RS (external to this clause; supplied by
%                                whatever computes the PSCCH/PSSCH resource-grid overlap)
%        nReSci2                 nonnegative integer -- N_RE^SCI,2, coded modulation symbols
%                                for the 2nd-stage SCI per TS 38.212 clause 8.4.4 with gamma=0
%                                (external to this clause; not yet built -- +ts38212/ gap)
%Outputs: tbs  nonnegative integer, bits -- the transport block size
%         NRE  positive integer -- N_RE, the final RE count fed into clause 5.1.3.2 steps 2-4
%              (returned for diagnostics/tests, not itself consumed further here)
%
%Steps 2)-4) (quantisation) are hand-implemented rather than delegated to nrTBS: nrTBS's public
%general-form signature computes N_RE internally from (nPRB, NREPerPRB, xOh) as
%min(156,NREPerPRB-xOh)*nPRB, with no way to inject the additional lump-sum N_RE^SCI,1/SCI,2
%subtraction clause 8.1.3.2 requires -- that subtraction happens on the *total*, after the
%per-PRB cap and the *nPRB multiplication, which is a different shape to every public nrTBS
%entry point. Forcing it through nrTBS's per-PRB abstraction (e.g. by folding the lump sum into
%xOh via nPRB) would require a non-integer xOh, which nrTBS rejects, and would still leave the
%156-per-PRB cap and cwd/layer-splitting machinery doing work this call never needs. The
%quantisation algorithm itself (Table 5.1.3.2-1's 93 entries and the >3824 branch's formula) is
%cross-checked against the 5G Toolbox's own internal reference implementation
%(+nr5g/+internal/TBSDetermination.m, function getTBS/getTBSFromTable) rather than re-derived
%from the PDF by hand, given this project's own prior experience of pdftotext corrupting
%exponents in dense formulas. This function's test file additionally cross-checks the
%non-SCI-overhead-adjusted case (nReSci1=nReSci2=0) directly against a live nrTBS call, which
%independently confirms the quantisation path.
%
%The clause-8.1.3.2-specific N_RE' formula (incl. N_symb^PSFCH's period-1-vs-period-{2,4}
%branching and the dmrsTimePattern semantics above) was independent-verifier confirmed against
%a nominal case and four branch/boundary variants (period 0/1/2/4, the overhead-indication bit
%ignored outside the {2,4} branch) -- all matched. One input combination the clause itself does
%not guard against was flagged: a short slot (sl-LengthSymbols=7) combined with PSFCH period 1
%(always 3 symbols) and a 4-symbol-only DM-RS pattern drives N_RE' negative; this function
%already rejects that (the NREPrime<=0 check below) rather than propagating it, which is the
%independent-verifier's own recommended resolution -- +cfg/cfgValidate.m catching this
%combination earlier, at config-validation time, is a natural follow-up but is not built.
if ~any(nLayers == [1 2])
    error('ts38214:tbsDetermine:badNLayers', 'tbsDetermine: nLayers must be 1 or 2, got %s', num2str(nLayers));
end
if ~any(slPsfchPeriod == [0 1 2 4])
    error('ts38214:tbsDetermine:badPsfchPeriod', 'tbsDetermine: slPsfchPeriod must be one of {0,1,2,4}, got %s', num2str(slPsfchPeriod));
end
if ~any(Qm == [2 4 6 8])
    error('ts38214:tbsDetermine:badQm', 'tbsDetermine: Qm must be one of {2,4,6,8}, got %s', num2str(Qm));
end
if ~(targetCodeRate > 0 && targetCodeRate < 1)
    error('ts38214:tbsDetermine:badTargetCodeRate', 'tbsDetermine: targetCodeRate must be in (0,1), got %s', num2str(targetCodeRate));
end
if nPRB <= 0 || mod(nPRB, 1) ~= 0
    error('ts38214:tbsDetermine:badNPRB', 'tbsDetermine: nPRB must be a positive integer, got %s', num2str(nPRB));
end
if slLengthSymbols < 7 || slLengthSymbols > 14 || mod(slLengthSymbols, 1) ~= 0
    error('ts38214:tbsDetermine:badLengthSymbols', 'tbsDetermine: slLengthSymbols must be an integer in 7..14, got %s', num2str(slLengthSymbols));
end
if ~any(nOhPRB == [0 3 6 9])
    error('ts38214:tbsDetermine:badOhPRB', 'tbsDetermine: nOhPRB must be one of {0,3,6,9} (sl-X-Overhead), got %s', num2str(nOhPRB));
end

switch slPsfchPeriod
    case 0
        nSymbPsfch = 0;   % clause 8.1.3.2: sl-PSFCH-Period=0 (disabled) -> N_symb^PSFCH=0
    case 1
        nSymbPsfch = 3;   % clause 8.1.3.2: sl-PSFCH-Period=1 -> N_symb^PSFCH=3 always
    otherwise   % 2 or 4
        % clause 8.1.3.2: period 2 or 4 -> 3 if 'PSFCH overhead indication'=1, else 0
        if psfchOverheadIndicated, nSymbPsfch = 3; else, nSymbPsfch = 0; end
end

nReDmrs = dmrsRePerPrb(dmrsTimePattern);

NscRB = 12;   % TS 38.214 clause 8.1.3.2, N_sc^RB -- fixed by 38.211 clause 4.4.4.1, not a config field
NsymbSh = slLengthSymbols - 2;   % clause 8.1.3.2: N_symb^sh = sl-LengthSymbols - 2 (excludes the
                                  % PSCCH-region-adjacent guard symbol and AGC symbol; independent-
                                  % verifier confirmed this term after an earlier version of this
                                  % file omitted it entirely)
NREPrime = NscRB * (NsymbSh - nSymbPsfch) - nOhPRB - nReDmrs;
if NREPrime <= 0
    error('ts38214:tbsDetermine:noRE', 'tbsDetermine: N_RE'' = %d <= 0 (slLengthSymbols=%d, NsymbSh=%d, nSymbPsfch=%d, nOhPRB=%d, nReDmrs=%d)', NREPrime, slLengthSymbols, NsymbSh, nSymbPsfch, nOhPRB, nReDmrs);
end

NRE = NREPrime * nPRB - nReSci1 - nReSci2;
if NRE <= 0
    error('ts38214:tbsDetermine:noRE', 'tbsDetermine: N_RE = %d <= 0 after subtracting nReSci1=%d, nReSci2=%d', NRE, nReSci1, nReSci2);
end

Ninfo = NRE * targetCodeRate * Qm * nLayers;
tbs = quantiseTBS(Ninfo, targetCodeRate);
end

function nReDmrs = dmrsRePerPrb(pattern)
%Table 8.1.3.2-1: N_RE^DMRS according to the CONFIGURED sl-PSSCH-DMRS-TimePatternList (not the
%per-transmission SCI-selected pattern -- see this file's header)
p = sort(pattern(:)');
if isequal(p, [2]),     nReDmrs = 12; return; end
if isequal(p, [3]),     nReDmrs = 18; return; end
if isequal(p, [4]),     nReDmrs = 24; return; end
if isequal(p, [2 3]),   nReDmrs = 15; return; end
if isequal(p, [2 4]),   nReDmrs = 18; return; end
if isequal(p, [3 4]),   nReDmrs = 21; return; end
if isequal(p, [2 3 4]), nReDmrs = 18; return; end
error('ts38214:tbsDetermine:badDmrsPattern', 'tbsDetermine: dmrsTimePattern must be one of {2},{3},{4},{2,3},{2,4},{3,4},{2,3,4} (Table 8.1.3.2-1), got [%s]', num2str(pattern));
end

function tbs = quantiseTBS(Ninfo, R)
%TS 38.214 clause 5.1.3.2, steps 2)-4). Table 5.1.3.2-1 and the >3824 formula cross-checked
%against 5G Toolbox +nr5g/+internal/TBSDetermination.m (getTBS/getTBSFromTable), R2025b.
if Ninfo <= 3824   % clause 5.1.3.2 step 2/3 branch boundary: Table 5.1.3.2-1's largest entry
    % step 2: n = max(3, floor(log2(Ninfo))-6); quantise to the nearest multiple of 2^n, floor,
    % floored at 24 bits (Table 5.1.3.2-1's smallest entry)
    n = max(3, floor(log2(Ninfo)) - 6);
    NdInfo = max(24, (2^n) * floor(Ninfo / 2^n));
    tbsTable = [24 32 40 48 56 64 72 80 88 96 104 112 120 128 136 144 152 160 168 176 184 192 208 224 240 256 272 288 304 320 ...
                336 352 368 384 408 432 456 480 504 528 552 576 608 640 672 704 736 768 808 848 888 928 984 1032 1064 1128 1160 1192 1224 1256 ...
                1288 1320 1352 1416 1480 1544 1608 1672 1736 1800 1864 1928 2024 2088 2152 2216 2280 2408 2472 2536 2600 2664 2728 2792 2856 2976 3104 3240 3368 3496 ...
                3624 3752 3824];   % Table 5.1.3.2-1, all 93 valid TBS values, smallest entry not less than NdInfo
    idx = find(tbsTable >= NdInfo, 1);
    tbs = tbsTable(idx);
else
    % step 3: n = floor(log2(Ninfo-24))-5; quantise to the nearest multiple of 2^n, round,
    % floored at 3840 bits
    n = floor(log2(Ninfo - 24)) - 5;
    NdInfo = max(3840, (2^n) * round((Ninfo - 24) / 2^n));
    if R <= 1/4   % clause 5.1.3.2 step 4: code rate threshold selecting the code-block-size cap
        C = ceil((NdInfo + 24) / 3816);   % max code block size 8424 minus 24-bit CRC minus 8*... => 3816-bit segmentation cap for R<=1/4
    elseif NdInfo > 8424   % max code block size K_cb=8424 (24-bit CRC included) for R>1/4
        C = ceil((NdInfo + 24) / 8424);
    else
        C = 1;
    end
    tbs = 8 * C * ceil((NdInfo + 24) / (8 * C)) - 24;   % step 4: TBS rounded to a byte (8-bit) multiple per code block, minus the 24-bit CRC
end
end
