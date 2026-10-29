function [rx, sduBytes, sduLen, sduCount] = pdcpRxPdu(rx, pdu, nowMs)
%pdcpRxPdu Receive one PDCP Data PDU from lower layer: COUNT, duplicate check, reorder, deliver.
%Spec:   TS 38.323 V16.8.0,
%        clause 5.2.2.1 (RCVD_COUNT from RCVD_SN against RX_DELIV and Window_Size; discard if
%          RCVD_COUNT < RX_DELIV or received before; store; RX_NEXT update; outOfOrderDelivery;
%          in-order delivery from RX_DELIV; t-Reordering stop and start),
%        clause 5.2.4 (sidelink receive operation: as 5.2.2, ROHC only for IP SDUs),
%        clause 7.1 (groupcast/broadcast initial values: "the initial value of the SN part of
%          RX_NEXT is (x+1) modulo 2^[sl-PDCP-SN-Size]" and "the initial value of the SN part of
%          RX_DELIV is (x - 0.5 x 2^[sl-PDCP-SN-Size-1]) modulo 2^[sl-PDCP-SN-Size], where x is the
%          SN of the first received PDCP Data PDU" -- exponents read from the rendered page,
%          pdftotext drops them), clause 7.2 (Window_Size = 2^[sl-PDCP-SN-Size]-1), 5.10.
%Inputs: rx     entity from pdcpRxInit
%        pdu    1 x n octets -- one PDCP Data PDU (an RLC SDU)
%        nowMs  real, ms -- starts t-Reordering
%Outputs: rx        updated entity
%         sduBytes  1 x sum(sduLen) octets -- PDCP SDUs delivered to upper layer (SDAP), in
%                   ascending COUNT order, concatenated
%         sduLen    1 x d integer
%         sduCount  1 x d integer -- their COUNTs
%
%Call pdcp.pdcpRxTimer for the same instant too: this function never expires t-Reordering.
%
%THE GROUPCAST/BROADCAST START HOLDS THE FIRST SDU FOR t-Reordering -- BY DESIGN OF CLAUSE 7.1
%----------------------------------------------------------------------------------------------
%RX_DELIV starts HALF A WINDOW below the first SN heard, so that SDUs sent just before it (still
%arriving through HARQ and RLC) fall inside the window rather than being discarded as old. The
%cost is that the first SDU is not at RX_DELIV, so in-order delivery cannot release it: it waits
%for t-Reordering to expire. With sl-OutOfOrderDelivery configured it is delivered at once. This
%is a real latency term on the first packet of every new gc/bc receiver, not an artefact.
%
%The HFN part of that initial state is "up to UE implementation ... such that initial value of
%RX_DELIV should be a positive value" (clause 7.1 NOTE). It is taken as 1: the first SDU's COUNT
%is 2^N + x, which keeps RX_DELIV = COUNT - Window_Size/2 >= 2^N - 2^(N-2) > 0.

SDU_TYPE_IP = 0;
FIRST_HFN = 1;               % clause 7.1 NOTE: UE choice, keeps RX_DELIV positive
RX_DELIV_HALF = 0.5;         % clause 7.1: x - 0.5 x 2^[sl-PDCP-SN-Size-1]

sduBytes = zeros(1, 0); sduLen = zeros(1, 0); sduCount = zeros(1, 0);
[valid, rcvdSn, data] = pdcp.pdcpPduParse(pdu, rx.cfg);
if ~valid
    rx.nDiscarded = rx.nDiscarded + 1;                % clause 5.10
    return;
end
N = rx.cfg.snFieldLength;
M = 2^N;
W = rx.cfg.Window_Size;

if ~rx.initialised
    firstCount = FIRST_HFN * M + rcvdSn;
    rx.RX_NEXT = firstCount + 1;                      % SN part (x+1) mod 2^N
    rx.RX_DELIV = firstCount - RX_DELIV_HALF * 2^(N - 1);       % SN part (x - 0.5*2^(N-1)) mod 2^N
    rx.initialised = true;
end

% ---- RCVD_COUNT, clause 5.2.2.1 -------------------------------------------
hfnDeliv = floor(rx.RX_DELIV / M);
snDeliv = mod(rx.RX_DELIV, M);
if rcvdSn < snDeliv - W
    rcvdHfn = hfnDeliv + 1;
elseif rcvdSn >= snDeliv + W
    rcvdHfn = hfnDeliv - 1;
else
    rcvdHfn = hfnDeliv;
end
if rcvdHfn < 0
    rx.nDiscarded = rx.nDiscarded + 1;                % no such COUNT: state variables are >= 0
    return;
end
rcvdCount = rcvdHfn * M + rcvdSn;

data = pdcp.securityProtect(data, rcvdCount, rx.cfg, 'verify');   % deciphering + verification
if rcvdCount < rx.RX_DELIV || any(rx.bufCount == rcvdCount)
    rx.nDiscarded = rx.nDiscarded + 1;                % "discard the PDCP Data PDU"
    return;
end
if rx.cfg.sduType == SDU_TYPE_IP
    error('pdcp:pdcpRxPdu:rohc', 'pdcpRxPdu: ROHC decompression for IP SDUs (clause 5.7) is not built');
end

% "store the resulting PDCP SDU in the reception buffer"
rx.bufCount(end + 1) = rcvdCount;
rx.bufLen(end + 1) = numel(data);
rx.bufDelivered(end + 1) = false;
rx.bufData = [rx.bufData, data];
if rcvdCount >= rx.RX_NEXT
    rx.RX_NEXT = rcvdCount + 1;
end
if rx.cfg.outOfOrderDelivery
    [rx, sduBytes, sduLen, sduCount] = deliverOne(rx, rcvdCount, sduBytes, sduLen, sduCount);
end
if rcvdCount == rx.RX_DELIV
    % "deliver ... all stored PDCP SDU(s) with consecutively associated COUNT value(s) starting
    % from COUNT = RX_DELIV; update RX_DELIV to the COUNT value of the first PDCP SDU which has
    % not been delivered to upper layers, with COUNT value > RX_DELIV"
    c = rx.RX_DELIV;
    while any(rx.bufCount == c)
        [rx, sduBytes, sduLen, sduCount] = deliverOne(rx, c, sduBytes, sduLen, sduCount);
        rx = removeOne(rx, c);
        c = c + 1;
    end
    rx.RX_DELIV = c;
end

if rx.tReorderingExpiry >= 0 && rx.RX_DELIV >= rx.RX_REORD
    rx.tReorderingExpiry = -1;                        % "stop and reset t-Reordering"
end
if rx.tReorderingExpiry < 0 && rx.RX_DELIV < rx.RX_NEXT
    rx.RX_REORD = rx.RX_NEXT;
    rx.tReorderingExpiry = nowMs + rx.cfg.t_Reordering;
end
end

function [rx, b, l, c] = deliverOne(rx, count, b, l, c)
% Deliver the stored SDU with this COUNT unless it already went up out of order.
k = find(rx.bufCount == count, 1);
if isempty(k) || rx.bufDelivered(k)
    return;
end
start = 1 + sum(rx.bufLen(1:k - 1));
b = [b, rx.bufData(start : start + rx.bufLen(k) - 1)];
l(end + 1) = rx.bufLen(k);
c(end + 1) = count;
rx.bufDelivered(k) = true;
end

function rx = removeOne(rx, count)
k = find(rx.bufCount == count, 1);
start = 1 + sum(rx.bufLen(1:k - 1));
rx.bufData(start : start + rx.bufLen(k) - 1) = [];
rx.bufCount(k) = [];
rx.bufLen(k) = [];
rx.bufDelivered(k) = [];
end
