function [dataBytes, headerBytes] = amTxDataVolume(tx)
%amTxDataVolume RLC data volume of the transmitting side of an AM entity.
%Spec:   TS 38.322 V16.3.0, clause 5.5: "RLC SDUs and RLC SDU segments that have not yet been
%        included in an RLC data PDU; RLC data PDUs that are pending for initial transmission;
%        RLC data PDUs that are pending for retransmission (RLC AM)."
%Inputs: tx  entity from amTxInit
%Outputs: dataBytes    integer -- unsent SDU bytes plus bytes pending retransmission. SDUs
%                      waiting outside the transmitting window count: they are data the entity
%                      holds, even though no grant can move them yet
%          headerBytes  integer -- AMD headers for sending each of those as one PDU (a lower
%                      bound, as umTxDataVolume). Not part of the clause-5.5 figure
%
%The STATUS PDU share of clause 5.5 belongs to the receiving side; rlc.amDataVolume adds it.

snLen = tx.cfg.snFieldLength;
dataBytes = sum(tx.sduLen - tx.sduSent) + sum(tx.retxEnd - tx.retxSo + 1);
headerBytes = 0;
for k = 1:numel(tx.sduLen)
    if tx.sduSent(k) < tx.sduLen(k)
        headerBytes = headerBytes + rlc.amdHeaderBytes(tx.sduSent(k) > 0, snLen);
    end
end
for r = 1:numel(tx.retxSn)
    headerBytes = headerBytes + rlc.amdHeaderBytes(tx.retxSo(r) > 0, snLen);
end
end
