function tddConfig = slTddConfigEncode(allOnesCase, pattern1, pattern2, mu, muRef, cyclicPrefix, startSymbol)
%slTddConfigEncode Derive the 12-bit sl-TDD-Config value (a0..a11) for MIB-SL.
%Spec:   TS 38.213 V16.17.0, clause 16.1 (Table 16.1-1, Table 16.1-2; pattern1/pattern2 field
%        semantics -- P/uSlots/uSym below -- per clause 11.1, read to resolve what those
%        symbols mean: P = dl-UL-TransmissionPeriodicity, uSlots = nrofUplinkSlots, uSym =
%        nrofUplinkSymbols of TDD-UL-DL-ConfigurationCommon or sl-TDD-Configuration).
%Inputs: allOnesCase  logical scalar -- true for paired spectrum, or for unpaired spectrum
%                     with no TDD-UL-DL-ConfigurationCommon/sl-TDD-Configuration provided on a
%                     PC5-only-interface band (TS 38.101-1 Table 5.2E.1-1) -- both are
%                     band/duplex-mode determinations outside this clause's own formula,
%                     caller-supplied. When true, all 12 bits are '1' and the remaining inputs
%                     are ignored.
%        pattern1     scalar struct: .P (real, ms -- the resolved dl-UL-TransmissionPeriodicity
%                     value, one of Table 16.1-1/16.1-2's period values), .uSlots (nonnegative
%                     integer, nrofUplinkSlots), .uSym (nonnegative integer, nrofUplinkSymbols).
%                     Ignored if allOnesCase.
%        pattern2     scalar struct, same shape as pattern1, or [] if only pattern1 is
%                     provided. [] vs a real struct is exactly what determines a0.
%        mu           integer, 0..3 -- SL SCS numerology (0=15kHz,1=30kHz,2=60kHz,3=120kHz)
%        muRef        integer, 0..3 -- reference SCS numerology of
%                     TDD-UL-DL-ConfigurationCommon/sl-TDD-Configuration
%        cyclicPrefix char, 'normal' or 'extended' -- selects L=14 or L=12
%        startSymbol  nonnegative integer -- Y, higher-layer parameter sl-StartSymbol
%Outputs: tddConfig  12-by-1 logical column, a0 first -- ready for mibSlPack's .tddConfig field
if allOnesCase
    tddConfig = true(12, 1);
    return;
end

% Table 16.1-1 (single pattern) and Table 16.1-2 (dual pattern), verified against a rendered
% page image, not pdftotext alone (pdftotext merges the granularity w cells across rows in a
% way that is easy to misread -- see +phy/+ts38213/CLAUDE.md Known traps).
codes = (0:15)';
tbl2P    = [0.5 0.625 1 0.5  1.25 2   1 2 3 1 2   2.5 3 4 5  10]';
tbl2P2   = [0.5 0.625 1 2    1.25 0.5 3 2 1 4 3   2.5 2 1 5  10]';
tbl2w15  = [1   1     1 1    1    1   1 1 1 1 1   1   1 1 1  1]';
tbl2w30  = [1   1     1 1    1    1   1 1 1 1 1   1   1 1 1  2]';
tbl2w60  = [1   1     1 1    1    1   1 1 1 1 1   1   1 1 2  4]';
tbl2w120 = [1   1     1 1    1    1   2 2 2 2 2   2   2 2 4  8]';
tbl1codes = codes(1:9);
tbl1P = [0.5 0.625 1 1.25 2 2.5 4 5 10]';

L = ts38213Local_L(cyclicPrefix);

if isempty(pattern2)
    a0 = false;
    code = tbl1codes(tbl1P == pattern1.P);
    if isempty(code)
        error('ts38213:slTddConfigEncode:badP', 'slTddConfigEncode: pattern1.P=%g is not a legal Table 16.1-1 period', pattern1.P);
    end
    a1234 = phy.ts38212.bitsFromUint(code, 4);
    I1 = ts38213Local_indicator(pattern1.uSym, mu, muRef, L, startSymbol);
    uSlotsSL = pattern1.uSlots * 2^(mu - muRef) + floor(pattern1.uSym * 2^(mu - muRef) / L) + I1;
else
    a0 = true;
    rowMask = (tbl2P == pattern1.P) & (tbl2P2 == pattern2.P);
    code = codes(rowMask);
    if isempty(code)
        error('ts38213:slTddConfigEncode:badP', 'slTddConfigEncode: (pattern1.P,pattern2.P)=(%g,%g) is not a legal Table 16.1-2 row', pattern1.P, pattern2.P);
    end
    a1234 = phy.ts38212.bitsFromUint(code, 4);
    switch mu
        case 0, w = tbl2w15(rowMask);
        case 1, w = tbl2w30(rowMask);
        case 2, w = tbl2w60(rowMask);
        case 3, w = tbl2w120(rowMask);
        otherwise
            error('ts38213:slTddConfigEncode:badMu', 'slTddConfigEncode: mu must be 0..3, got %s', num2str(mu));
    end
    I1 = ts38213Local_indicator(pattern1.uSym, mu, muRef, L, startSymbol);
    I2 = ts38213Local_indicator(pattern2.uSym, mu, muRef, L, startSymbol);
    term1 = pattern1.uSlots * 2^(mu - muRef) + floor(pattern1.uSym * 2^(mu - muRef) / L) + I1;
    term2 = pattern2.uSlots * 2^(mu - muRef) + floor(pattern2.uSym * 2^(mu - muRef) / L) + I2;
    uSlotsSL = floor(term2 / w) * ceil((pattern1.P * 2^mu + 1) / w) + floor(term1 / w);
end

if ~(uSlotsSL >= 0 && uSlotsSL <= 127 && mod(uSlotsSL, 1) == 0)
    error('ts38213:slTddConfigEncode:badUSlotsSL', 'slTddConfigEncode: derived u_slots^SL=%g does not fit in the 7-bit a5..a11 field', uSlotsSL);
end
a5to11 = phy.ts38212.bitsFromUint(uSlotsSL, 7);

tddConfig = [a0; a1234; a5to11];
end

function L = ts38213Local_L(cyclicPrefix)
switch cyclicPrefix
    case 'normal'
        L = 14;
    case 'extended'
        L = 12;
    otherwise
        error('ts38213:slTddConfigEncode:badCyclicPrefix', 'slTddConfigEncode: cyclicPrefix must be ''normal'' or ''extended'', got ''%s''', cyclicPrefix);
end
end

function I = ts38213Local_indicator(uSym, mu, muRef, L, Y)
I = double(mod(uSym * 2^(mu - muRef), L) >= L - Y);
end
