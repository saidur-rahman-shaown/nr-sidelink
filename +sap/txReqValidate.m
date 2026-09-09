function t = txReqValidate(t, numSubchannel)
%txReqValidate Check a transmission request before it crosses the PHY SAP.
%Spec:   the field ranges are the SCI field widths -- TS 38.212 V16.15.0 clauses 8.3.1.1
%        (SCI 1-A) and 8.4.1.1/8.4.1.2 (SCI 2-A/2-B) -- and TS 38.214 clause 8.1.2.2 for the
%        sub-channel bound.
%Inputs: t              scalar struct, from +sap/txReqInit with fields filled in
%        numSubchannel  integer, >=1 -- sl-NumSubchannel for the pool this transmits in
%Outputs: t  the input, unchanged, once every check passes
%
%Every check here is a field the SCI must carry, so a value out of range is a transmission that
%cannot be signalled. Catching it at the SAP names the offending field; catching it inside a
%packer names a bit position, and catching it nowhere produces a truncated field that decodes
%to a different, legal value at the receiver -- the worst of the three.
%
%What this deliberately does NOT check:
%  - that slotLogical and slotPhysical denote the same slot. That needs the pool map, which
%    this package does not hold; the harness checks it where the map lives.
%  - that .tb is the right length for .mcs and .LsubCH. That is phy.ts38214.tbsDetermine's
%    arithmetic and belongs to whoever built the TB.
%  - broadcast versus HARQ feedback -- see +sap/txReqInit; that is a scenario convention, not
%    a rule any clause read here states.

req = {'slotPhysical', 'slotLogical', 'startSubch', 'LsubCH', 'mcs', 'tb', 'harqId', 'ndi', ...
       'rv', 'srcL2Id', 'dstL2Id', 'castType', 'prioTx', 'harqFeedbackEnabled', 'csiRequest', ...
       'prsvpTxIdx', 'trivIdx', 'frivIdx', 'txPowerDbm', 'ctxIds', 'waveform'};
for k = 1:numel(req)
    if ~isfield(t, req{k})
        error('sap:txReqValidate:missingField', 'txReqValidate: field ''%s'' is missing; build the struct from sap.txReqInit', req{k});
    end
end

intField(t.slotPhysical, 0, inf,       'slotPhysical');
intField(t.slotLogical,  0, inf,       'slotLogical');
intField(t.startSubch,   0, inf,       'startSubch');
intField(t.LsubCH,       1, inf,       'LsubCH');
intField(t.mcs,          0, 31,        'mcs');            % SCI-1A field is 5 bits
intField(t.harqId,       0, 15,        'harqId');         % SCI-2 field is 4 bits
intField(t.ndi,          0, 1,         'ndi');
intField(t.rv,           0, 3,         'rv');
intField(t.srcL2Id,      0, 2^24 - 1,  'srcL2Id');
intField(t.dstL2Id,      0, 2^24 - 1,  'dstL2Id');
intField(t.castType,     0, 3,         'castType');       % Table 8.4.1.1-1
intField(t.prioTx,       1, 8,         'prioTx');         % SCI-1A field is 3 bits, values 1..8
intField(t.harqFeedbackEnabled, 0, 1,  'harqFeedbackEnabled');
intField(t.csiRequest,   0, 1,         'csiRequest');
intField(t.prsvpTxIdx,   0, inf,       'prsvpTxIdx');
intField(t.trivIdx,      0, inf,       'trivIdx');
intField(t.frivIdx,      0, inf,       'frivIdx');

if ~(numSubchannel >= 1 && mod(numSubchannel, 1) == 0)
    error('sap:txReqValidate:badNumSubchannel', 'txReqValidate: numSubchannel must be a positive integer, got %s', num2str(numSubchannel));
end
% Clause 8.1.2.2: the assignment is L_subCH contiguous sub-channels starting at startSubch, so
% the last one must exist. An over-run here becomes an out-of-band PRB allocation at the grid.
if t.startSubch + t.LsubCH > numSubchannel
    error('sap:txReqValidate:subchOverrun', 'txReqValidate: sub-channels %d..%d exceed the pool''s %d (sl-NumSubchannel)', t.startSubch, t.startSubch + t.LsubCH - 1, numSubchannel);
end

if ~islogical(t.tb) || (~isempty(t.tb) && ~iscolumn(t.tb))
    error('sap:txReqValidate:badTb', 'txReqValidate: tb must be a logical column vector');
end
if isempty(t.tb)
    error('sap:txReqValidate:emptyTb', 'txReqValidate: tb is empty; TS 38.321 clause 5.22.1.4.1.3 forbids building a MAC PDU with no content, so there is nothing to transmit');
end

if ~isempty(t.ctxIds) && (~isrow(t.ctxIds) || any(t.ctxIds < 1) || any(mod(t.ctxIds, 1) ~= 0))
    error('sap:txReqValidate:badCtxIds', 'txReqValidate: ctxIds must be a row vector of positive integer packet ids');
end
if numel(unique(t.ctxIds)) ~= numel(t.ctxIds)
    error('sap:txReqValidate:duplicateCtxIds', 'txReqValidate: a packet may appear only once in a transport block, got %s', mat2str(t.ctxIds));
end
% A retransmission (ndi unchanged) still carries its ctxIds; an initial transmission with none
% is a TB nothing can be attributed to, and its delivery would never close a latency figure.
if isempty(t.ctxIds)
    error('sap:txReqValidate:noCtxIds', 'txReqValidate: ctxIds is empty; a transport block no packet can be attributed to cannot close any KPI');
end

if ~isempty(t.waveform) && ~iscolumn(t.waveform)
    error('sap:txReqValidate:badWaveform', 'txReqValidate: waveform must be a column vector, or empty for the system-level path');
end
end

function intField(v, lo, hi, name)
if ~isscalar(v) || ~isnumeric(v) || mod(v, 1) ~= 0 || v < lo || v > hi
    error('sap:txReqValidate:badField', 'txReqValidate: %s must be an integer in %s..%s, got %s', name, num2str(lo), num2str(hi), mat2str(v));
end
end
