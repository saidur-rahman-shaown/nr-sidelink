function bytes = lchDataAvailable(lchSet)
%lchDataAvailable SL data available for transmission, per logical channel.
%Spec:   TS 38.321 clause 5.22.1.4.1.3 uses this quantity throughout ("if the data available
%        for transmission on the logical channel is..."); +mac/slLcp takes it as its
%        `dataAvailable` input. Clause 5.22.1.5's own definition of the quantity for Buffer
%        Status Reporting is not modelled -- this is a Mode-2 tree and SL-BSR is mode-1
%        machinery (see +mac/CLAUDE.md "Not built").
%Inputs: lchSet  from +sap/lchInit
%Outputs: bytes  1 x nLch real row vector -- queued SDU bytes per channel, in the exact shape
%                +mac/slLcp expects
%
%Payload bytes only. MAC subheader overhead belongs to +mac/muxSlSch, which is what actually
%builds the PDU and knows whether each subheader carries an 8- or 16-bit L field; counting it
%here would double-count it there.

bytes = zeros(1, lchSet.nLch);
for k = 1:numel(lchSet.q)
    ch = lchSet.qLch(k);
    bytes(ch) = bytes(ch) + lchSet.q(k).sizeBytes;
end
end
