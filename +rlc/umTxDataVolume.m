function [dataBytes, headerBytes] = umTxDataVolume(tx)
%umTxDataVolume RLC data volume of a transmitting UM entity.
%Spec:   TS 38.322 V16.3.0, clause 5.5: "For the purpose of MAC buffer status reporting, the UE
%        shall consider the following as RLC data volume: RLC SDUs and RLC SDU segments that
%        have not yet been included in an RLC data PDU; RLC data PDUs that are pending for
%        initial transmission".
%Inputs: tx  entity from umTxInit
%Outputs: dataBytes    integer, >=0 -- SDU bytes not yet submitted. This is the clause-5.5
%                      quantity
%          headerBytes  integer, >=0 -- the RLC header bytes those SDUs need if each goes in
%                      one PDU: a complete-SDU header for an untouched SDU, an SO-bearing
%                      header for the remainder of a part-sent one. NOT part of the clause-5.5
%                      figure; returned because a grant sized to dataBytes alone is always
%                      one header short and forces a needless segmentation. Further
%                      segmentation needs more header than this, so it is a lower bound
%
%Nothing here is pre-built: every PDU is formed at the opportunity (umTxBuild), so "RLC data
%PDUs pending for initial transmission" is always empty for this implementation.

SI_COMPLETE = rlc.siValue(true, true);
SI_LAST = rlc.siValue(false, true);
dataBytes = sum(tx.sduLen - tx.sduOffset);
headerBytes = 0;
for k = 1:numel(tx.sduLen)
    if tx.sduOffset(k) == 0
        headerBytes = headerBytes + rlc.umdHeaderBytes(SI_COMPLETE, tx.cfg.snFieldLength);
    else
        headerBytes = headerBytes + rlc.umdHeaderBytes(SI_LAST, tx.cfg.snFieldLength);
    end
end
end
