function [rx, sduBytes, sduLen, sduCount, expired] = pdcpRxTimer(rx, nowMs)
%pdcpRxTimer Run t-Reordering expiry on a receiving PDCP entity, if it is due.
%Spec:   TS 38.323 V16.8.0, clause 5.2.2.2: "When t-Reordering expires, the receiving PDCP entity
%        shall: deliver to upper layers in ascending order of the associated COUNT value after
%        performing header decompression, if not decompressed before: all stored PDCP SDU(s) with
%        associated COUNT value(s) < RX_REORD; all stored PDCP SDU(s) with consecutively
%        associated COUNT value(s) starting from RX_REORD; update RX_DELIV to the COUNT value of
%        the first PDCP SDU which has not been delivered to upper layers, with COUNT value >=
%        RX_REORD; if RX_DELIV < RX_NEXT: update RX_REORD to RX_NEXT; start t-Reordering."
%Inputs: rx     entity from pdcpRxInit
%        nowMs  real, ms
%Outputs: rx        updated entity
%         sduBytes  1 x sum(sduLen) octets -- SDUs released, ascending COUNT
%         sduLen    1 x d integer
%         sduCount  1 x d integer
%         expired   logical
%
%This is where a LOST PDCP SDU is given up on: the COUNTs between the old RX_DELIV and the first
%stored SDU are skipped and never delivered. The restart is timed from the expiry instant, not
%from nowMs, as in rlc.umRxTimer, so a coarse caller tick does not stretch the timer.

sduBytes = zeros(1, 0); sduLen = zeros(1, 0); sduCount = zeros(1, 0);
expired = false;
while rx.tReorderingExpiry >= 0 && nowMs >= rx.tReorderingExpiry
    expired = true;
    tExpiry = rx.tReorderingExpiry;
    rx.tReorderingExpiry = -1;

    % "all stored PDCP SDU(s) with associated COUNT value(s) < RX_REORD", ascending
    below = sort(rx.bufCount(rx.bufCount < rx.RX_REORD));
    for c = below
        [rx, sduBytes, sduLen, sduCount] = take(rx, c, sduBytes, sduLen, sduCount);
    end
    % "all stored PDCP SDU(s) with consecutively associated COUNT value(s) starting from RX_REORD"
    c = rx.RX_REORD;
    while any(rx.bufCount == c)
        [rx, sduBytes, sduLen, sduCount] = take(rx, c, sduBytes, sduLen, sduCount);
        c = c + 1;
    end
    rx.RX_DELIV = c;
    if rx.RX_DELIV < rx.RX_NEXT
        rx.RX_REORD = rx.RX_NEXT;
        rx.tReorderingExpiry = tExpiry + rx.cfg.t_Reordering;
    end
end
end

function [rx, b, l, cc] = take(rx, count, b, l, cc)
% Deliver (unless already delivered out of order) and remove the stored SDU with this COUNT.
k = find(rx.bufCount == count, 1);
start = 1 + sum(rx.bufLen(1:k - 1));
if ~rx.bufDelivered(k)
    b = [b, rx.bufData(start : start + rx.bufLen(k) - 1)];
    l(end + 1) = rx.bufLen(k);
    cc(end + 1) = count;
end
rx.bufData(start : start + rx.bufLen(k) - 1) = [];
rx.bufCount(k) = [];
rx.bufLen(k) = [];
rx.bufDelivered(k) = [];
end
