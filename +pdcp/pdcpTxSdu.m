function [tx, pdu, count] = pdcpTxSdu(tx, sdu, tag, nowMs)
%pdcpTxSdu Accept a PDCP SDU from upper layer and build its PDCP Data PDU.
%Spec:   TS 38.323 V16.8.0, clause 5.2.1: "At reception of a PDCP SDU from upper layers, the
%        transmitting PDCP entity shall: start the discardTimer associated with this PDCP SDU (if
%        configured). For a PDCP SDU received from upper layers, the transmitting PDCP entity
%        shall: associate the COUNT value corresponding to TX_NEXT to this PDCP SDU; perform
%        header compression ...; perform integrity protection, and ciphering using the TX_NEXT
%        ...; set the PDCP SN of the PDCP Data PDU to TX_NEXT modulo 2^[pdcp-SN-SizeUL];
%        increment TX_NEXT by one; submit the resulting PDCP Data PDU to lower layer". Clause
%        5.2.3 replaces the modulus with 2^[sl-PDCP-SN-Size] and applies ROHC only "if SDU Type is
%        IP". Clause 6.3.5: "COUNT does not wrap around."
%Inputs: tx     entity from pdcpTxInit
%        sdu    1 x n octets -- the PDCP SDU (an SDAP PDU)
%        tag    integer -- caller's identifier for this SDU, returned on discard
%        nowMs  real, ms -- starts the discardTimer
%Outputs: tx     updated entity
%         pdu    1 x m octets -- the PDCP Data PDU, to be submitted to the associated RLC entity
%                at once (one RLC entity per SLRB, so clause 5.2.1's routing reduces to that)
%         count  integer -- the COUNT bound to this SDU. A caller passes it to RLC as the RLC
%                SDU's tag, so a later discard can be indicated to RLC by COUNT (clause 5.3)
%
%ROHC is not applied: header compression is configured only for IP SDUs (clause 5.2.3) and the
%sidelink V2X messages this tree carries are Non-IP. With sduType = IP the function raises
%rather than sending uncompressed IP while claiming ROHC.

SDU_TYPE_IP = 0;
COUNT_LIMIT = 2^32;          % clause 6.3.5, 32-bit COUNT that "does not wrap around"

if tx.cfg.sduType == SDU_TYPE_IP
    error('pdcp:pdcpTxSdu:rohc', 'pdcpTxSdu: ROHC for IP SDUs (clause 5.7) is not built');
end
if tx.TX_NEXT >= COUNT_LIMIT
    error('pdcp:pdcpTxSdu:countExhausted', 'pdcpTxSdu: COUNT does not wrap around (clause 6.3.5)');
end

count = tx.TX_NEXT;
if isfinite(tx.cfg.discardTimerMs)
    tx.discCount(end + 1) = count;
    tx.discTag(end + 1) = tag;
    tx.discExpiry(end + 1) = nowMs + tx.cfg.discardTimerMs;
end
protectedSdu = pdcp.securityProtect(sdu, count, tx.cfg, 'protect');
pdu = pdcp.pdcpPduPack(mod(count, 2^tx.cfg.snFieldLength), protectedSdu, tx.cfg);
tx.TX_NEXT = tx.TX_NEXT + 1;
end
