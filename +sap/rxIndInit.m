function r = rxIndInit()
%rxIndInit A zeroed reception indication -- the RX SAP template.
%Spec:   none as a struct. It is the return path of TS 38.321 Figure 4.2.2-3's lower boundary:
%        what PHY hands back up after decoding a slot.
%Inputs: none
%Outputs: r  scalar struct with every field present and zeroed:
%   .rxUeId .txUeId    integer -- who heard whom
%   .slotPhysical .slotLogical  integer -- both numberings, as on the transmit side
%   .sciPass   logical -- SCI-1A (PSCCH) decoded. **Independent of crcPass**: see below
%   .crcPass   logical -- the PSSCH transport block decoded
%   .srcL2Id .dstL2Id .castType .prioTx .harqId .ndi .rv .harqFeedbackEnabled
%   .startSubch .LsubCH .prsvpTxIdx .trivIdx   -- what the SCI announced
%   .ctxIds    1 x n integer -- packets inside the TB; meaningful only where crcPass
%   .sinrDb    real, dB
%   .rsrpDbm   real, dBm -- SL-RSRP, TS 38.215 clause 5.1.27/5.1.28
%
%SCI AND TB DECODE ARE SEPARATE, AND THAT IS THE WHOLE POINT
%------------------------------------------------------------
%PSCCH carries SCI-1A at a fixed, robust format; PSSCH carries the transport block at the
%announced MCS. A UE routinely decodes the control and fails the data -- that is the normal
%case at range, and it is what makes sensing work: `sciPass` without `crcPass` still yields a
%reservation to record in the sensing database and an SL-RSRP to measure against the threshold.
%Collapsing the two into one flag makes sensing blind to exactly the far-away UEs whose
%reservations matter most, and the pool then looks emptier than it is.

r = struct( ...
    'rxUeId', 0, 'txUeId', 0, ...
    'slotPhysical', 0, 'slotLogical', 0, ...
    'sciPass', false, 'crcPass', false, ...
    'srcL2Id', 0, 'dstL2Id', 0, 'castType', 0, 'prioTx', 1, ...
    'harqId', 0, 'ndi', 0, 'rv', 0, 'harqFeedbackEnabled', 0, ...
    'startSubch', 0, 'LsubCH', 1, 'prsvpTxIdx', 0, 'trivIdx', 0, ...
    'ctxIds', zeros(1, 0), 'sinrDb', NaN, 'rsrpDbm', NaN);
end
