function test_pdcp()
%test_pdcp Sidelink PDCP: formats, SN/COUNT, discard timer, reordering, gc/bc initialisation.
%SPEC: TS 38.323 V16.8.0 clauses 5.2.1-5.2.4, 5.3, 5.10, 6.2.2.4/6/7, 6.3.x, 7.1-7.3.
%
%Level 2: the octet vectors and the groupcast receive trace below were computed by the
%independent-verifier subagent from the spec text (exponents of clauses 7.1/7.2 read from the
%rendered PDF), blind to +pdcp/. Level 1: the round trips prove self-consistency only.

hex = @(s) hex2dec(strsplit(s, ' '))';
cfgOf = @(cast, sizeLbl, ooo) pdcp.pdcpConfig(struct( ...
    'sl_DiscardTimer_r16_Present', true, 'sl_DiscardTimer_r16', 'ms100', ...
    'sl_PDCP_SN_Size_r16_Present', ~isempty(sizeLbl), 'sl_PDCP_SN_Size_r16', sizeLbl, ...
    'sl_OutOfOrderDelivery', ooo), cast, 10, 1);
gc = cfgOf('groupcast', '', false);
uc12 = cfgOf('unicast', 'len12bits', false);
uc18 = cfgOf('unicast', 'len18bits', false);

%% ---- Level 2: verifier octets (Part A) -------------------------------------
assert(isequal(pdcp.pdcpPduPack(2748, hex('55'), gc), hex('2A BC 55')), 'A1 gc/bc 12-bit Non-IP');
assert(isequal(pdcp.pdcpPduPack(1, [1 2], uc12), hex('90 01 00 00 01 02')), 'A2 unicast 12-bit, KNRP-sess ID 0');
assert(isequal(pdcp.pdcpPduPack(131073, hex('AA'), uc18), hex('92 00 01 00 00 AA')), 'A3 unicast 18-bit');
assert(isequal(pdcp.pdcpPduPack(4095, 7, gc), [hex('2F FF') 7]), 'gc/bc SN 4095');
assert(isequal(pdcp.pdcpPduPack(262143, 7, uc18), [hex('93 FF FF 00 00') 7]), 'unicast 18-bit SN max');
assert(gc.Window_Size == 2048 && uc18.Window_Size == 131072, 'Window_Size = 2^(SN-1), clause 7.2');

%% ---- Level 1: round trip over the whole SN space ---------------------------
for c = {gc, uc12}
    cf = c{1};
    for sn = 0:2^cf.snFieldLength - 1
        [v, s2, d2] = pdcp.pdcpPduParse(pdcp.pdcpPduPack(sn, [mod(sn, 256), 9], cf), cf);
        assert(v && s2 == sn && isequal(d2, [mod(sn, 256) 9]), 'round trip at SN %d (%s)', sn, cf.format);
    end
end
for sn = [0 1 4095 4096 131071 131072 262143]
    [v, s2] = pdcp.pdcpPduParse(pdcp.pdcpPduPack(sn, 1, uc18), uc18);
    assert(v && s2 == sn, '18-bit round trip at %d', sn);
end

%% ---- clause 5.10: invalid PDUs ---------------------------------------------
assert(~pdcp.pdcpPduParse(hex('5A 00 01'), gc), 'SDU Type 010 is reserved: discard');
assert(pdcp.pdcpPduParse(hex('30 00 01'), gc), 'a set R bit is ignored, not invalid (6.3.6)');
bad = pdcp.pdcpPduPack(1, 1, uc12); bad(3) = 1;
assert(~pdcp.pdcpPduParse(bad, uc12), 'non-zero KNRP-sess ID on an unprotected SLRB is invalid');
bad = pdcp.pdcpPduPack(1, 1, uc12); bad(1) = bitand(bad(1), 127);
assert(~pdcp.pdcpPduParse(bad, uc12), 'unicast D/C = 0 (a control PDU) is not accepted here');
mustError(@() cfgOf('broadcast', 'len18bits', false), 'pdcp:pdcpConfig:gcBcSnSize', '18-bit SN on broadcast');

%% ---- security stub is a pass-through, and refuses to pretend --------------
assert(isequal(pdcp.securityProtect([1 2 3], 5, gc, 'protect'), [1 2 3]), 'pass-through when security is inactive');
sec = gc; sec.securityActive = true;
mustError(@() pdcp.securityProtect([1 2 3], 5, sec, 'protect'), 'pdcp:securityProtect:notBuilt', 'active security');

%% ---- TX: COUNT, SN wrap, discard timer -------------------------------------
tx = pdcp.pdcpTxInit(gc);
for k = 1:4097
    [tx, pdu, count] = pdcp.pdcpTxSdu(tx, 1, k, k);
end
[~, sn] = pdcp.pdcpPduParse(pdu, gc);
assert(count == 4096 && sn == 0 && tx.TX_NEXT == 4097, 'the 4097th SDU has COUNT 4096 and SN 0');
tx = pdcp.pdcpTxInit(gc);
[tx, ~, c0] = pdcp.pdcpTxSdu(tx, 1, 11, 0);
[tx, ~, c1] = pdcp.pdcpTxSdu(tx, 1, 12, 50);
[tx, dc, dt] = pdcp.pdcpTxTimer(tx, 99.9);
assert(isempty(dc), 'nothing expires before 100 ms');
[tx, dc, dt] = pdcp.pdcpTxTimer(tx, 100);
assert(isequal(dc, c0) && isequal(dt, 11) && tx.nTimerExpired == 1, 'the first SDU expires at exactly ms100');
[tx, dc] = pdcp.pdcpTxTimer(tx, 150);
assert(isequal(dc, c1) && tx.nTimerExpired == 2 && isempty(tx.discCount), 'the second at 150');

%% ---- Level 2: groupcast receive trace (Part B, in order) --------------------
rx = pdcp.pdcpRxInit(gc);
pduOf = @(sn) pdcp.pdcpPduPack(sn, mod(sn, 256), gc);
ev = {0, 100; 1, 102; 2, 101; 3, 101; 5, 104; 30, 3; 31, 105};
%          t  RX_NEXT RX_DELIV RX_REORD deadline   delivered COUNTs
expPdu = {0, [4197 3172 4197 10], []; 1, [4199 3172 4197 10], []; 2, [4199 3172 4197 10], []; ...
          3, [4199 3172 4197 10], []; 5, [4201 3172 4197 10], []; 30, [4201 4201 4201 -1], []; ...
          31, [4202 4202 4201 -1], 4201};
e = 1;
for t = 0:60
    [rx, ~, ~, cc] = pdcp.pdcpRxTimer(rx, t);
    if t == 10
        assert(isequal(cc, [4196 4197 4198]) && rx.RX_DELIV == 4199 && rx.RX_REORD == 4201 && rx.tReorderingExpiry == 20, ...
            't=10 expiry releases 4196..4198 and restarts with RX_REORD 4201');
    elseif t == 20
        assert(isequal(cc, 4200) && rx.RX_DELIV == 4201 && rx.tReorderingExpiry < 0, 't=20: 4200 released, SN 103 abandoned');
    else
        assert(isempty(cc), 'nothing released by the timer at t=%d', t);
    end
    while e <= size(ev, 1) && ev{e, 1} == t
        [rx, ~, ~, cc] = pdcp.pdcpRxPdu(rx, pduOf(ev{e, 2}), t);
        got = [rx.RX_NEXT rx.RX_DELIV rx.RX_REORD rx.tReorderingExpiry];
        assert(isequal(got, expPdu{e, 2}) && isequal(reshape(cc, 1, []), reshape(expPdu{e, 3}, 1, [])), ...
            'PDCP rx after SN %d at t=%d: got %s', ev{e, 2}, t, mat2str(got));
        e = e + 1;
    end
end
assert(rx.nDiscarded == 2, 'the duplicate SN 101 and the old SN 3 are discarded');

% Part B with outOfOrderDelivery: each SDU goes up once, on arrival.
rx = pdcp.pdcpRxInit(cfgOf('groupcast', '', true));
expo = {0, 4196; 1, 4198; 2, 4197; 3, []; 5, 4200; 30, []; 31, 4201};
e = 1; total = zeros(1, 0);
for t = 0:60
    [rx, ~, ~, cc] = pdcp.pdcpRxTimer(rx, t);
    total = [total cc]; %#ok<AGROW>
    assert(isempty(cc), 'nothing is delivered twice by the timer under out-of-order delivery (t=%d)', t);
    while e <= size(ev, 1) && ev{e, 1} == t
        [rx, ~, ~, cc] = pdcp.pdcpRxPdu(rx, pduOf(ev{e, 2}), t);
        assert(isequal(reshape(cc, 1, []), reshape(expo{e, 2}, 1, [])), 'OOO delivery at t=%d', t);
        total = [total cc]; %#ok<AGROW>
        e = e + 1;
    end
end
assert(numel(unique(total)) == numel(total), 'each SDU exactly once');

%% ---- unicast starts at 0 and reorders a small window completely -------------
for perm = perms(0:3)'
    rx = pdcp.pdcpRxInit(uc12);
    out = zeros(1, 0);
    for sn = perm'
        [rx, ~, ~, cc] = pdcp.pdcpRxPdu(rx, pdcp.pdcpPduPack(sn, sn, uc12), 0);
        out = [out cc]; %#ok<AGROW>
    end
    assert(isequal(out, 0:3), 'in-order delivery for arrival order %s', mat2str(perm'));
end
% HFN rollover on unicast: 4096 SDUs in sequence then the next wraps the SN.
tx = pdcp.pdcpTxInit(uc12); rx = pdcp.pdcpRxInit(uc12); n = 0;
for k = 1:5000
    [tx, pdu] = pdcp.pdcpTxSdu(tx, mod(k, 256), k, 0);
    [rx, ~, l] = pdcp.pdcpRxPdu(rx, pdu, 0);
    n = n + numel(l);
end
assert(n == 5000 && rx.RX_DELIV == 5000, 'COUNT carries across the SN wrap (HFN increments)');
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
