function test_rlcFormats()
%test_rlcFormats PDU formats and configuration decoding, TS 38.322 clause 6.2 / TS 38.331.
%SPEC: TS 38.322 V16.3.0 clauses 6.2.2.3 (UMD), 6.2.2.4 (AMD), 6.2.2.5 (STATUS), 6.2.3.x (fields),
%      5.6.1 (invalid PDUs); TS 38.331 V16.22.0 SL-RLC-Config-r16 and clause 6.3.2 enumerations.
%
%Level 2 (+test/CLAUDE.md): the octet vectors in the first section were computed by the
%independent-verifier subagent from the spec text alone, blind to +rlc/, and matched on the
%first run. Level 1: the round trips below prove self-consistency only -- a consistently
%misread packer and parser round-trip perfectly.

hex = @(s) hex2dec(strsplit(s, ' '))';

%% ---- Level 2: independent-verifier octet vectors --------------------------
assert(isequal(rlc.umdPduPack(2, 37, 300, hex('AA'), 6), hex('A5 01 2C AA')), 'UMD 6-bit SN last segment with SO');
assert(isequal(rlc.umdPduPack(1, 2748, 0, hex('11'), 12), hex('4A BC 11')), 'UMD 12-bit SN first segment, no SO');
assert(isequal(rlc.umdPduPack(0, 0, 0, [1 2], 6), hex('00 01 02')), 'UMD complete SDU: SI + six R bits, no SN');
assert(isequal(rlc.umdPduPack(3, 4095, 65535, 255, 12), hex('CF FF FF FF FF')), ...
    'UMD 12-bit middle segment: the two R bits must stay 0 under an all-ones SN and SO');
assert(isequal(rlc.amdPduPack(1, 3, 192753, 4660, hex('55'), 18), hex('F2 F0 F1 12 34 55')), 'AMD 18-bit SN with SO');
assert(isequal(rlc.amdPduPack(0, 0, 1000, 0, 1, 12), hex('83 E8 01')), 'AMD 12-bit complete SDU still carries its SN');
assert(isequal(rlc.amdPduPack(1, 2, 4095, 7, 9, 12), hex('EF FF 00 07 09')), 'AMD 12-bit last segment');
assert(isequal(rlc.amdPduPack(0, 1, 131073, 0, 2, 18), hex('92 00 01 02')), 'AMD 18-bit: SN bit 17 and bit 0 only');
assert(isequal(rlc.statusPduPack(100, [90 92 95], [-1 10 -1], [-1 65535 -1], [0 0 3], 12), ...
    hex('00 64 80 05 A8 05 CC 00 0A FF FF 05 F2 03')), 'STATUS 12-bit: plain, SO pair, NACK range');
assert(isequal(rlc.statusPduPack(200000, 199990, 5, 20, 2, 18), hex('0C 35 02 C3 4D 98 00 05 00 14 02')), ...
    'STATUS 18-bit: SO pair and range on one set');
assert(isequal(rlc.statusPduPack(5, [], [], [], [], 12), hex('00 05 00')), 'STATUS 12-bit, no NACK');
assert(isequal(rlc.statusPduPack(5, [], [], [], [], 18), hex('00 00 14')), ...
    'STATUS 18-bit, no NACK: ACK_SN straddles into octet 3 with E1 after it');
assert(rlc.statusPduBytes([false true false], [false false true], 12) == 14, 'STATUS size, case I');
assert(rlc.statusPduBytes(true, true, 18) == 11, 'STATUS size, case J');

% Header sizes, same verifier report.
assert(rlc.umdHeaderBytes(0, 6) == 1 && rlc.umdHeaderBytes(0, 12) == 1, 'UMD complete header is 1 byte');
assert(rlc.umdHeaderBytes(1, 6) == 1 && rlc.umdHeaderBytes(1, 12) == 2, 'UMD first-segment header');
assert(rlc.umdHeaderBytes(2, 6) == 3 && rlc.umdHeaderBytes(3, 12) == 4, 'UMD SO-bearing header');
assert(rlc.amdHeaderBytes(false, 12) == 2 && rlc.amdHeaderBytes(true, 12) == 4, 'AMD 12-bit header');
assert(rlc.amdHeaderBytes(false, 18) == 3 && rlc.amdHeaderBytes(true, 18) == 5, 'AMD 18-bit header');

%% ---- SI is a table, not a bit pair ----------------------------------------
assert(rlc.siValue(true, true) == 0 && rlc.siValue(true, false) == 1 && ...
       rlc.siValue(false, true) == 2 && rlc.siValue(false, false) == 3, 'Table 6.2.3.4-1');

%% ---- Level 1: UMD round trip over the whole SN space, every SI ------------
for snLen = [6 12]
    for sn = 0:2^snLen - 1
        for si = 1:3
            so = 0;
            if si ~= 1, so = mod(sn * 7919, 65536); end
            data = mod(sn + (1:3), 256);
            [v, si2, sn2, so2, d2] = rlc.umdPduParse(rlc.umdPduPack(si, sn, so, data, snLen), snLen);
            assert(v && si2 == si && sn2 == sn && so2 == so && isequal(d2, data), ...
                'UMD round trip failed at SN length %d, SN %d, SI %d', snLen, sn, si);
        end
    end
    [v, si2, sn2, so2, d2] = rlc.umdPduParse(rlc.umdPduPack(0, 0, 0, [9 8 7], snLen), snLen);
    assert(v && si2 == 0 && sn2 == -1 && so2 == 0 && isequal(d2, [9 8 7]), 'a complete UMD PDU carries no SN');
end

%% ---- Level 1: AMD round trip, 12-bit exhaustive, 18-bit sampled -----------
for snLen = [12 18]
    if snLen == 12, sns = 0:4095; else, sns = [0 1 2^17 - 1 2^17 2^18 - 2 2^18 - 1 mod((1:500) * 524287, 2^18)]; end
    for sn = sns
        for si = 0:3
            so = 0;
            if si >= 2, so = mod(sn, 65535) + 1; end
            p = mod(sn + si, 2) == 1;
            [v, p2, si2, sn2, so2, d2] = rlc.amdPduParse(rlc.amdPduPack(p, si, sn, so, [1 2], snLen), snLen);
            assert(v && p2 == p && si2 == si && sn2 == sn && so2 == so && isequal(d2, [1 2]), ...
                'AMD round trip failed at SN length %d, SN %d, SI %d', snLen, sn, si);
        end
    end
end

%% ---- Level 1: STATUS round trip over every E1/E2/E3 combination -----------
for snLen = [12 18]
    M = 2^snLen;
    for combo = 0:15
        % four NACK sets, each with its own E2/E3 pattern
        nackSn = mod([10 20 M - 1 5] + combo, M);
        s0 = [-1 3 -1 0]; s1 = [-1 65535 -1 17];
        r = [0 0 7 255];
        if bitand(combo, 1), s0(1) = 4; s1(1) = 9; end
        if bitand(combo, 2), r(2) = 2; end
        if bitand(combo, 4), s0(3) = 0; s1(3) = 0; end
        if bitand(combo, 8), r(4) = 0; end
        pdu = rlc.statusPduPack(mod(combo * 97, M), nackSn, s0, s1, r, snLen);
        assert(numel(pdu) == rlc.statusPduBytes(s0 >= 0, r > 0, snLen), 'STATUS size must match statusPduBytes');
        [v, a, n, x0, x1, rr] = rlc.statusPduParse(pdu, snLen);
        assert(v && a == mod(combo * 97, M) && isequal(n, nackSn) && isequal(x0, s0) && isequal(x1, s1) && isequal(rr, r), ...
            'STATUS round trip failed, SN length %d, combo %d', snLen, combo);
        % Trailing octets after the E1 = 0 set do not change the report.
        [v2, a2, n2] = rlc.statusPduParse([pdu 0 0 255], snLen);
        assert(v2 && a2 == a && isequal(n2, n), 'octets after the last NACK set must be ignored');
    end
end

%% ---- clause 5.6.1: invalid PDUs are reported, not mis-parsed ---------------
[v] = rlc.umdPduParse(hex('4A'), 12);                     % first-segment header, no data byte
assert(~v, 'a UMD PDU with an empty Data field is invalid');
[v] = rlc.amdPduParse(rlc.statusPduPack(5, [], [], [], [], 12), 12);
assert(~v, 'D/C = 0 is not an AMD PDU');
bad = rlc.statusPduPack(5, [], [], [], [], 12); bad(1) = bitor(bad(1), 16);    % CPT = 001
[v] = rlc.statusPduParse(bad, 12);
assert(~v, 'a reserved CPT must be discarded (Table 6.2.3.9-1)');
full = rlc.statusPduPack(100, [90 92], [-1 10], [-1 65535], [0 0], 12);
[v] = rlc.statusPduParse(full(1:end - 1), 12);
assert(~v, 'a truncated STATUS PDU is invalid');
zeroRange = rlc.statusPduPack(100, 90, -1, -1, 1, 12); zeroRange(end) = 0;
[v] = rlc.statusPduParse(zeroRange, 12);
assert(~v, 'E3 = 1 with NACK range 0 announces zero lost SDUs and is invalid');
mustError(@() rlc.statusPduPack(1, 2, 3, -1, 0, 12), 'rlc:statusPduPack:soPair', 'SOstart without SOend');
mustError(@() rlc.amdPduPack(0, 2, 1, 0, 1, 12), 'rlc:amdPduPack:badSo', 'a last segment at SO 0');
mustError(@() rlc.umdPduPack(1, 1, 5, 1, 6), 'rlc:umdPduPack:badSo', 'a first segment with SO > 0');
mustError(@() rlc.umdPduPack(0, 0, 0, [], 6), 'rlc:umdPduPack:emptyData', 'an empty Data field');

%% ---- clause 7.2 windows, and the mode/length pairing ----------------------
assert(rlc.windowSize('am', 12) == 2048 && rlc.windowSize('am', 18) == 131072, 'AM_Window_Size');
assert(rlc.windowSize('um', 6) == 32 && rlc.windowSize('um', 12) == 2048, 'UM_Window_Size');
mustError(@() rlc.windowSize('um', 18), 'rlc:windowSize:badLength', 'an 18-bit UM entity');
mustError(@() rlc.windowSize('am', 6), 'rlc:windowSize:badLength', 'a 6-bit AM entity');
assert(rlc.snDiff(3, 60, 6) == 7 && rlc.snDiff(60, 3, 6) == 57, 'clause 7.1 modulus base arithmetic across the wrap');

%% ---- configuration decoding ------------------------------------------------
am = struct('sl_SN_FieldLengthAM_r16', 'size18', 'sl_T_PollRetransmit_r16', 'ms45', ...
    'sl_PollPDU_r16', 'pInfinity', 'sl_PollByte_r16', 'mB8', 'sl_MaxRetxThreshold_r16', 't32');
c = rlc.amConfig(am, 'ms35', 'ms0');
assert(c.snFieldLength == 18 && c.AM_Window_Size == 131072 && c.t_PollRetransmit == 45 && ...
    isinf(c.pollPDU) && c.pollByte == 8e6 && c.maxRetxThreshold == 32 && c.t_Reassembly == 35 && ...
    c.t_StatusProhibit == 0, 'amConfig must decode every enumeration');
am.sl_PollByte_r16 = 'kB25';
c = rlc.amConfig(am, 'ms200', 'ms2400');
assert(c.pollByte == 25000 && c.t_Reassembly == 200 && c.t_StatusProhibit == 2400, 'kB and extreme timer values');
am.sl_PollByte_r16 = 'infinity';
c = rlc.amConfig(am, 'ms0', 'ms5');
assert(isinf(c.pollByte), 'pollByte infinity');
am.sl_T_PollRetransmit_r16 = 'ms7';
mustError(@() rlc.amConfig(am, 'ms0', 'ms0'), 'rlc:amConfig:badTPollRetransmit', 'a label that parses but is not in the enumeration');
am.sl_T_PollRetransmit_r16 = 'ms45';
mustError(@() rlc.amConfig(am, 'ms105', 'ms0'), 'rlc:amConfig:badTReassembly', ...
    'ms105 is a T-StatusProhibit value but NOT a T-Reassembly one (T-Reassembly goes 100, 110)');
um = rlc.umConfig(struct('sl_SN_FieldLengthUM_r16', 'size6'), 'ms50');
assert(um.snFieldLength == 6 && um.UM_Window_Size == 32 && um.t_Reassembly == 50, 'umConfig');
mustError(@() rlc.umConfig(struct(), 'ms50'), 'rlc:umConfig:missingField', 'an absent SN length');
end

function mustError(f, id, what)
try
    f();
catch e
    assert(strcmp(e.identifier, id), 'expected %s for %s, got %s: %s', id, what, e.identifier, e.message);
    return;
end
error('test:noError', 'expected an error (%s) for %s', id, what);
end
