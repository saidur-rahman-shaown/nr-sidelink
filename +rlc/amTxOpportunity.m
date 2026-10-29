function [tx, rx, pduBytes, pduLen] = amTxOpportunity(tx, rx, grantBytes, nowMs)
%amTxOpportunity Serve one transmission opportunity for an AM entity: STATUS first, then data.
%Spec:   TS 38.322 V16.3.0, clause 5.2.3.1.1: "The transmitting side of an AM RLC entity shall
%        prioritize transmission of RLC control PDUs over AMD PDUs." Clause 4.2.1: "If an RLC
%        entity submits/receives RLC control PDUs to/from lower layer, it submits/receives them
%        through the same logical channel it submits/receives the RLC data PDUs through."
%        Clause 4.3.2: the opportunity comes "together with the total size of the RLC PDU(s)".
%Inputs: tx, rx      the two sides of one AM entity (amTxInit / amRxInit)
%        grantBytes  integer, >=0 -- total size of RLC PDUs for this logical channel
%        nowMs       real, ms
%Outputs: tx, rx    updated
%         pduBytes  1 x sum(pduLen) octets -- the STATUS PDU (if any) then the AMD PDUs
%         pduLen    1 x nPdu integer
%
%The two sides are separate structs because clause 4.2.1.3 describes them separately and
%their state never mixes; this is the one place their outputs meet, since they share a logical
%channel and therefore a grant.

[rx, status] = rlc.amRxStatusBuild(rx, grantBytes, nowMs);
[tx, dataBytes, dataLen] = rlc.amTxBuild(tx, grantBytes - numel(status), nowMs);
if isempty(status)
    pduBytes = dataBytes;
    pduLen = dataLen;
else
    pduBytes = [status, dataBytes];
    pduLen = [numel(status), dataLen];
end
end
