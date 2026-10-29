function [b, nNew] = rxBufInsert(b, sn, so, data, containsLastByte)
%rxBufInsert Store a received Data field, keeping only bytes not already held.
%Spec:   TS 38.322 V16.3.0, clause 5.2.3.2.2: "place the received AMD PDU in the reception
%        buffer; if some byte segments of the RLC SDU contained in the AMD PDU have been
%        received before: discard the duplicate byte segments." Clause 5.2.2.2.2 for UM.
%Inputs: b                 reception buffer from rxBufInit
%        sn                integer -- SN of the SDU the Data field belongs to
%        so                integer, 0..65535 -- byte offset of data(1) within that SDU
%        data              1 x n row vector of octets, n >= 1
%        containsLastByte  logical -- the Data field ends at the SDU's last byte (SI 00 / 10)
%Outputs: b     updated buffer
%         nNew  integer, 0..n -- bytes actually added. 0 means the whole Data field was a
%               duplicate; the caller decides what that means (AM discards it earlier via
%               rxBufCovered, so reaching here with 0 is a caller bug in AM)
%
%A new Data field may straddle several held runs, so it can split into several new runs. The
%last-byte marker must survive the trim: if byte z (the SDU's last) is already held under a
%run that did not know it was last -- impossible for a conformant peer, since every PDU
%containing an SDU's last byte says so in SI, but cheap to make robust -- the marker is moved
%onto the run that holds z. Losing it would leave the SDU forever "incomplete".

SO_MAX = 65535;     % clause 6.2.3.5, 16-bit SO
checkOctets(data, 'rxBufInsert', 'data');
n = numel(data);
if n < 1
    error('rlc:rxBufInsert:emptyData', 'rxBufInsert: data must hold at least one byte');
end
if so < 0 || so > SO_MAX
    error('rlc:rxBufInsert:badSo', 'rxBufInsert: SO %d outside 0..%d', so, SO_MAX);
end

y = so;
z = so + n - 1;

% Held runs of this SN, sorted by start.
idx = find(b.sn == sn);
[~, order] = sort(b.so(idx));
idx = idx(order);

nNew = 0;
cur = y;
for k = 1:numel(idx)
    s = b.so(idx(k));
    e = s + b.len(idx(k)) - 1;
    if e < cur
        continue;
    end
    if s > z
        break;
    end
    if s > cur
        b = appendRun(b, sn, cur, data(cur - y + 1 : s - 1 - y + 1), false);
        nNew = nNew + (s - cur);
    end
    cur = max(cur, e + 1);
end
if cur <= z
    b = appendRun(b, sn, cur, data(cur - y + 1 : end), containsLastByte);
    nNew = nNew + (z - cur + 1);
elseif containsLastByte
    % z was already held: carry the marker onto the run that holds it.
    for k = 1:numel(b.sn)
        if b.sn(k) == sn && b.so(k) <= z && z <= b.so(k) + b.len(k) - 1
            b.last(k) = true;
        end
    end
end
end

function b = appendRun(b, sn, so, bytes, isLast)
b.sn(end + 1) = sn;
b.so(end + 1) = so;
b.len(end + 1) = numel(bytes);
b.last(end + 1) = isLast;
b.data = [b.data, bytes];
end
