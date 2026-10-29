function tx = umTxEnqueue(tx, sdu, tag)
%umTxEnqueue Accept an RLC SDU from upper layer into a transmitting UM entity.
%Spec:   TS 38.322 V16.3.0, clause 4.2.1.2.2: "The transmitting UM RLC entity generates UMD
%        PDU(s) for each RLC SDU." Clause 4.2.1: SDUs are byte aligned. Clause 6.2.3.2: "The
%        maximum Data field size is the maximum size of a PDCP PDU."
%Inputs: tx   entity from umTxInit
%        sdu  1 x L row vector of octets, 1 <= L <= 65536 -- the 16-bit SO (clause 6.2.3.5)
%             can address no byte past 65535, so no longer SDU can be segmented
%        tag  integer -- caller's identifier, carried to every PDU the SDU produces
%Outputs: tx  updated entity
%
%No SN is assigned here. In UM, clause 5.2.2.1.1 assigns TX_Next only "if the UMD PDU contains
%a segment", i.e. at submission, and only to SDUs that end up segmented.

SO_BITS = 16;
checkOctets(sdu, 'umTxEnqueue', 'sdu');
if isempty(sdu) || numel(sdu) > 2^SO_BITS
    error('rlc:umTxEnqueue:badLength', 'umTxEnqueue: SDU length must be 1..%d bytes, got %d', 2^SO_BITS, numel(sdu));
end
tx.buf = [tx.buf, sdu];
tx.sduLen(end + 1) = numel(sdu);
tx.sduTag(end + 1) = tag;
tx.sduOffset(end + 1) = 0;
tx.sduSn(end + 1) = -1;
end
