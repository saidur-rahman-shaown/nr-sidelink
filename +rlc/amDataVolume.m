function [dataBytes, headerBytes, statusBytes] = amDataVolume(tx, rx, nowMs)
%amDataVolume RLC data volume of an AM entity, including a pending STATUS PDU.
%Spec:   TS 38.322 V16.3.0, clause 5.5: the transmit-side volume (see rlc.amTxDataVolume), and
%        "In addition, if a STATUS PDU has been triggered and t-StatusProhibit is not running
%        or has expired, the UE shall estimate the size of the STATUS PDU that will be
%        transmitted in the next transmission opportunity, and consider this as part of RLC
%        data volume."
%Inputs: tx, rx  the two sides of one AM entity
%        nowMs   real, ms
%Outputs: dataBytes    integer -- as amTxDataVolume
%         headerBytes  integer -- as amTxDataVolume (not part of the clause-5.5 figure)
%         statusBytes  integer -- the STATUS PDU that would be built now with no size limit,
%                      0 when none is due. Part of the clause-5.5 figure
%
%The estimate is the real thing: amRxStatusBuild is run with an unbounded grant and its
%updated state thrown away. Nothing is changed -- this function returns no entity.

[dataBytes, headerBytes] = rlc.amTxDataVolume(tx);
[~, status] = rlc.amRxStatusBuild(rx, Inf, nowMs);
statusBytes = numel(status);
end
