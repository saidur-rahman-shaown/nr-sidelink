function [gapStart, gapEnd] = rxBufGaps(b, sn)
%rxBufGaps The missing byte runs of SDU sn, in increasing byte order.
%Spec:   TS 38.322 V16.3.0, clause 5.3.4: "for a continuous sequence of byte segments of a
%        partly received RLC SDU that have not been received yet: include in the STATUS PDU a
%        set of NACK_SN, SOstart and SOend"; clause 6.2.3.15: 'The special SOend value
%        "1111111111111111" is used to indicate that the missing portion of the RLC SDU
%        includes all bytes to the last byte of the RLC SDU.'
%Inputs: b   reception buffer
%        sn  integer
%Outputs: gapStart  1 x G integer -- first missing byte of each run
%         gapEnd    1 x G integer -- last missing byte, or -1 for "to the last byte of the SDU"
%                   (the SOend special value). A run is open-ended exactly when the SDU's last
%                   byte has not been received, because then its length is unknown
%
%Nothing held for sn returns the single open run [0, -1] -- the whole SDU -- which is how a
%caller can tell "missing entirely" from "partly received" without a second query (clause
%5.3.4 encodes the two differently).

idx = find(b.sn == sn);
[~, order] = sort(b.so(idx));
idx = idx(order);

gapStart = zeros(1, 0);
gapEnd = zeros(1, 0);
cur = 0;
sawLast = false;
for k = 1:numel(idx)
    s = b.so(idx(k));
    e = s + b.len(idx(k)) - 1;
    if s > cur
        gapStart(end + 1) = cur;      %#ok<AGROW>
        gapEnd(end + 1) = s - 1;      %#ok<AGROW>
    end
    cur = max(cur, e + 1);
    sawLast = sawLast || b.last(idx(k));
end
if ~sawLast
    gapStart(end + 1) = cur;
    gapEnd(end + 1) = -1;
end
end
