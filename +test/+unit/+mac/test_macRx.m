function test_macRx()
%test_macRx Unit tests for the SL-SCH RECEIVE path, TS 38.321 clause 5.22.2.
%SPEC: TS 38.321 V16.22.0 clause 5.22.2.2.1 (Sidelink HARQ Entity, RX), 5.22.2.2.2 (Sidelink
%      process, including feedback generation), 5.22.2.3 / 6.1.6 / 6.2.4 (disassembly).
%
%Hand-computed expectations throughout. Per +test/CLAUDE.md level 2 an independent-verifier
%pass is required before these are trusted.

%% ---- demuxSlSch inverts muxSlSch, field for field ----------------------
src = hex2dec('ABCD12'); dst = hex2dec('345678');
sdu = double(uint8(1:9));
[pdu, nPad] = mac.muxSlSch(src, dst, sdu, [4 5], [4 5], true, 1, 10, 32);
[sh, dh, sb, sl, slc, cp, ri, cq] = mac.demuxSlSch(pdu);
assert(sh == bitshift(src, -8),  'SRC must be the 16 MSB of the Source Layer-2 ID: got %04X want %04X', sh, bitshift(src, -8));
assert(dh == bitshift(dst, -16), 'DST must be the 8 MSB of the Destination Layer-2 ID: got %02X want %02X', dh, bitshift(dst, -16));
assert(isequal(sl, [4 5]) && isequal(slc, [4 5]), 'SDU lengths and LCIDs must round-trip');
assert(isequal(sb, sdu), 'SDU octets must round-trip exactly');
assert(cp && ri == 1 && cq == 10, 'the CSI Reporting MAC CE must round-trip: present=%d RI=%d CQI=%d', cp, ri, cq);
assert(nPad > 0, 'the test PDU must contain padding, or the stop-at-padding rule is untested');

% Parsing must STOP at the padding subheader. Clause 6.1.5 gives padding no length field, so
% anything after it is padding to the end of the TB; continuing to parse reads padding octets
% as subheaders and manufactures SDUs out of them.
assert(sum(sl) == 9, 'only the real SDUs may be returned, got %d octets', sum(sl));

% The F/L pairing is fixed by clause 6.2.4, so the 256-byte boundary must round-trip both ways.
big = double(uint8(mod(0:299, 251)));
[pduBig, ~] = mac.muxSlSch(src, dst, big, 300, 4, false, 0, 0, 340);
[~, ~, sbBig, slBig] = mac.demuxSlSch(pduBig);
assert(slBig == 300 && isequal(sbBig, big), 'a 300-byte SDU needs a 16-bit L field and must round-trip');
small = double(uint8(1:255));
[pduSm, ~] = mac.muxSlSch(src, dst, small, 255, 4, false, 0, 0, 280);
[~, ~, sbSm, slSm] = mac.demuxSlSch(pduSm);
assert(slSm == 255 && isequal(sbSm, small), 'a 255-byte SDU uses an 8-bit L field and must round-trip');

% Malformed input is rejected rather than silently mis-parsed.
bad = pdu; bad(1:4) = [1 1 1 1];                 % V field non-zero
mustError(@() mac.demuxSlSch(bad), 'mac:demuxSlSch:badVersion', 'a non-zero V field');
mustError(@() mac.demuxSlSch(pdu(1:20)), 'mac:demuxSlSch:notByteAligned', 'a bit count that is not a multiple of 8');

%% ---- pduFilter: the two halves of each identity must BOTH match --------
me = hex2dec('AABBCC'); peer = hex2dec('112233'); bcast = hex2dec('FFFFFF');
% Broadcast: the subheader's DST high 8 and the SCI's low 16 must both point at an address
% this UE monitors.
assert(mac.pduFilter(0, bitshift(bcast, -16), bitshift(peer, -8), bitand(bcast, 65535), bitand(peer, 255), me, bcast, 4, false), ...
    'a broadcast to a monitored address must be delivered');
assert(~mac.pduFilter(0, bitshift(bcast, -16), bitshift(peer, -8), bitand(bcast, 65535) - 1, bitand(peer, 255), me, bcast, 4, false), ...
    'the SCI half must match too -- checking only the subheader half accepts one address in 65536 wrongly');
assert(~mac.pduFilter(0, bitshift(bcast, -16) - 1, bitshift(peer, -8), bitand(bcast, 65535), bitand(peer, 255), me, bcast, 4, false), ...
    'the subheader half must match too');

% Unicast, and the CROSSED direction: the subheader's DST is checked against this UE's own
% SOURCE ids, its SRC against the DESTINATION ids it holds for peers. Matching DST against own
% destinations would make a UE accept only traffic it sent itself.
assert(mac.pduFilter(2, bitshift(me, -16), bitshift(peer, -8), bitand(me, 65535), bitand(peer, 255), me, peer, 4, false), ...
    'a unicast addressed to this UE from a known peer must be delivered');
assert(~mac.pduFilter(2, bitshift(peer, -16), bitshift(me, -8), bitand(peer, 65535), bitand(me, 255), me, peer, 4, false), ...
    'traffic this UE sent must NOT come back to it -- that is what the crossed check prevents');
assert(~mac.pduFilter(2, bitshift(me, -16), 9999, bitand(me, 65535), 77, me, peer, 4, false), ...
    'a unicast from an unknown peer on a data LCID must be rejected');
% ...except the establishment path: LCID 0 or 1 on the first TB, where no peer identity exists
% yet. Dropping this branch makes a unicast link that can never start.
assert(mac.pduFilter(2, bitshift(me, -16), 9999, bitand(me, 65535), 77, me, peer, 0, true), ...
    'SCCH on the first TB must be admitted so a link can be established');
assert(~mac.pduFilter(2, bitshift(me, -16), 9999, bitand(me, 65535), 77, me, peer, 0, false), ...
    'the establishment exemption applies to the FIRST TB only');
mustError(@() mac.pduFilter(4, 0, 0, 0, 0, me, peer, 4, false), 'mac:pduFilter:badCastType', 'a cast type outside Table 8.4.1.1-1');

%% ---- harqRxAssign: processes are keyed on the TRIPLE -------------------
h = mac.harqRxInit(4);
% A first reception is a new transmission whatever the NDI, so a receiver joining mid-stream
% does not wait for a toggle.
[h, p1, new1] = mac.harqRxAssign(h, 77, 5000, 3, 0);
assert(p1 >= 1 && new1, 'the first reception for a triple must be a new transmission');
% Same triple, same NDI: a retransmission on the same process.
[h, p2, new2] = mac.harqRxAssign(h, 77, 5000, 3, 0);
assert(p2 == p1 && ~new2, 'an unchanged NDI on a known triple is a retransmission on the same process');
% Same triple, toggled NDI: a new TB, same process re-allocated.
[h, p3, new3] = mac.harqRxAssign(h, 77, 5000, 3, 1);
assert(new3, 'a toggled NDI must start a new transmission');
% A DIFFERENT peer on the SAME Sidelink process ID must get its own process. Keying on the
% process number alone would share a soft buffer between two peers, so one peer's
% retransmission is combined into another's TB and decodes to noise.
hh = mac.harqRxInit(4);
[hh, a, ~] = mac.harqRxAssign(hh, 77, 5000, 3, 0);
[hh, b, ~] = mac.harqRxAssign(hh, 88, 5000, 3, 0);
[hh, c, ~] = mac.harqRxAssign(hh, 77, 6000, 3, 0);
assert(numel(unique([a b c])) == 3, 'src, dst and process id are all part of the key: got processes %d %d %d', a, b, c);
% Exhausting the processes is a drop, reported as a value (NOTE 1 leaves it to implementation).
hFull = mac.harqRxInit(1);
[hFull, ~, ~] = mac.harqRxAssign(hFull, 1, 1, 0, 0);
[~, pNone, ~] = mac.harqRxAssign(hFull, 2, 2, 1, 0);
assert(pNone == 0, 'with no free process the TB must be dropped, reported as procIdx 0');
mustError(@() mac.harqRxAssign(h, 1, 1, 0, 2), 'mac:harqRxAssign:badNdi', 'a non-binary NDI');
mustError(@() mac.harqRxAssign(h, 1, 1, 16, 0), 'mac:harqRxAssign:badHarqId', 'a process id above the 4-bit SCI field');

%% ---- harqRxProcess: deliver once, acknowledge always -------------------
h = mac.harqRxInit(2);
[h, p, new] = mac.harqRxAssign(h, 77, 5000, 3, 0);
[h, dl, fb, cmb] = mac.harqRxProcess(h, p, new, false, true, 2, true, true);
assert(~dl && strcmp(fb, 'nack') && ~cmb, 'a failed first attempt: no delivery, a NACK, nothing to combine');
assert(h.softValid(p) && h.occupied(p), 'a failed attempt must leave the soft buffer and keep the process');
[h, p, new] = mac.harqRxAssign(h, 77, 5000, 3, 0);
[h, dl, fb, cmb] = mac.harqRxProcess(h, p, new, true, true, 2, true, true);
assert(dl && strcmp(fb, 'ack') && cmb, 'a successful retransmission must combine, deliver and ACK');
assert(~h.occupied(p), 'a completed TB must leave the process unoccupied');

% A PDU that decodes but fails the identity filter is still RECEIVED: it must not be delivered,
% must still be acknowledged, and must free its process. Holding the process open would leak
% one to every neighbour this UE can hear but is not addressed by.
h = mac.harqRxInit(2);
[h, p, new] = mac.harqRxAssign(h, 1, 2, 0, 0);
[h, dl, fb] = mac.harqRxProcess(h, p, new, true, false, 2, true, true);
assert(~dl && strcmp(fb, 'ack'), 'a decoded but unaddressed PDU is acknowledged, not delivered');
assert(~h.occupied(p), 'and its process must be released');

%% ---- feedback rules, per cast type -------------------------------------
% Broadcast never generates feedback, even if the SCI flag were set.
h = mac.harqRxInit(2); [h, p, new] = mac.harqRxAssign(h, 1, 2, 0, 0);
[~, ~, fbB] = mac.harqRxProcess(h, p, new, false, true, 0, true, true);
assert(strcmp(fbB, 'none'), 'broadcast must never generate feedback, got %s', fbB);
% Feedback disabled by the SCI: silence whatever the cast type.
h = mac.harqRxInit(2); [h, p, new] = mac.harqRxAssign(h, 1, 2, 0, 0);
[~, ~, fbD] = mac.harqRxProcess(h, p, new, false, true, 2, false, true);
assert(strcmp(fbD, 'none'), 'a disabled feedback flag must silence the receiver, got %s', fbD);
% NACK-only groupcast: silence on success, NACK only on failure AND in range. A receiver that
% ACKed here would transmit on a PSFCH resource the scheme does not allocate to it.
for tc = {{true, true, 'none'}, {false, true, 'nack'}, {false, false, 'none'}, {true, false, 'none'}}
    h = mac.harqRxInit(2); [h, p, new] = mac.harqRxAssign(h, 1, 2, 0, 0);
    [~, ~, fbG] = mac.harqRxProcess(h, p, new, tc{1}{1}, true, 3, true, tc{1}{2});
    assert(strcmp(fbG, tc{1}{3}), 'NACK-only groupcast, decoded=%d inRange=%d: expected %s, got %s', tc{1}{1}, tc{1}{2}, tc{1}{3}, fbG);
end

fprintf('test_macRx: all assertions passed.\n');
end

function mustError(fh, expectedId, what)
try
    fh();
catch e
    assert(strcmp(e.identifier, expectedId), 'expected %s for %s, got %s', expectedId, what, e.identifier);
    return;
end
error('test_macRx:noError', 'expected an error for %s, none raised', what);
end
