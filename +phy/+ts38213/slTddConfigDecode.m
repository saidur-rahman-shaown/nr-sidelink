function info = slTddConfigDecode(tddConfig, mu)
%slTddConfigDecode Decode the 12-bit sl-TDD-Config value (a0..a11) from MIB-SL.
%Spec:   TS 38.213 V16.17.0, clause 16.1 (Table 16.1-1, Table 16.1-2) -- inverse of
%        slTddConfigEncode, but only to the extent the signal itself is invertible: a0..a4
%        recover the slot configuration period(s) P/P2 (and granularity w, if a0=1) exactly,
%        via the same tables. a5..a11 recover u_slots^SL as a raw value -- this is what a
%        receiving UE actually needs (a timing/boundary reference), not the original
%        pattern1/pattern2 nrofUplinkSlots/nrofUplinkSymbols, which the floor/mod combination
%        inside u_slots^SL does not preserve and this function does not attempt to recover.
%Inputs: tddConfig  12-by-1 logical (or 0/1) column, a0 first -- mibSlUnpack's .tddConfig field
%        mu         integer, 0..3 -- SL SCS numerology (0=15kHz,1=30kHz,2=60kHz,3=120kHz),
%                   needed only to select the granularity column when a0=1
%Outputs: info  scalar struct:
%           .allOnesCase  logical -- true if all 12 bits are 1 (paired spectrum / no TDD
%                         config case); if true, no other field is meaningful
%           .a0           logical -- false = pattern1 only, true = pattern1 and pattern2
%           .P            real, ms -- pattern1's slot configuration period
%           .P2           real, ms, or [] if .a0 is false -- pattern2's slot configuration
%                         period
%           .w            integer, or [] if .a0 is false -- granularity in slots for the
%                         given mu
%           .uSlotsSL     nonnegative integer, 0..127 -- the raw u_slots^SL value from a5..a11
if numel(tddConfig) ~= 12
    error('ts38213:slTddConfigDecode:badLength', 'slTddConfigDecode: tddConfig must have 12 elements, got %d', numel(tddConfig));
end
tddConfig = logical(tddConfig(:));
info.allOnesCase = all(tddConfig);
if info.allOnesCase
    info.a0 = []; info.P = []; info.P2 = []; info.w = []; info.uSlotsSL = [];
    return;
end

codes = (0:15)';
tbl2P    = [0.5 0.625 1 0.5  1.25 2   1 2 3 1 2   2.5 3 4 5  10]';
tbl2P2   = [0.5 0.625 1 2    1.25 0.5 3 2 1 4 3   2.5 2 1 5  10]';
tbl2w15  = [1   1     1 1    1    1   1 1 1 1 1   1   1 1 1  1]';
tbl2w30  = [1   1     1 1    1    1   1 1 1 1 1   1   1 1 1  2]';
tbl2w60  = [1   1     1 1    1    1   1 1 1 1 1   1   1 1 2  4]';
tbl2w120 = [1   1     1 1    1    1   2 2 2 2 2   2   2 2 4  8]';
tbl1codes = codes(1:9);
tbl1P = [0.5 0.625 1 1.25 2 2.5 4 5 10]';

info.a0 = tddConfig(1);
code = phy.ts38212.uintFromBits(tddConfig(2:5));

if ~info.a0
    idx = find(tbl1codes == code, 1);
    if isempty(idx)
        error('ts38213:slTddConfigDecode:reservedCode', 'slTddConfigDecode: a1..a4 code %d is Reserved in Table 16.1-1', code);
    end
    info.P = tbl1P(idx);
    info.P2 = [];
    info.w = [];
else
    idx = codes == code;
    info.P = tbl2P(idx);
    info.P2 = tbl2P2(idx);
    switch mu
        case 0, info.w = tbl2w15(idx);
        case 1, info.w = tbl2w30(idx);
        case 2, info.w = tbl2w60(idx);
        case 3, info.w = tbl2w120(idx);
        otherwise
            error('ts38213:slTddConfigDecode:badMu', 'slTddConfigDecode: mu must be 0..3, got %s', num2str(mu));
    end
end

info.uSlotsSL = phy.ts38212.uintFromBits(tddConfig(6:12));
end
