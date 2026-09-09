function test_txReq()
%test_txReq Unit tests for the PHY SAP -- what MAC hands to PHY.
%SPEC: field ranges are the SCI field widths, TS 38.212 V16.15.0 clauses 8.3.1.1 (SCI 1-A) and
%      8.4.1.1 (SCI 2-A); castType is Table 8.4.1.1-1; the sub-channel bound is TS 38.214
%      clause 8.1.2.2.

cast = sap.castTypes();

%% ---- the cast type table, which is NOT in the intuitive order -----------
% Table 8.4.1.1-1 read from Documentations/38212-gf0.pdf. Unicast is 2, not 1, and groupcast
% occupies both 1 and 3 split by feedback mode. Writing the obvious enumeration puts unicast
% traffic on a groupcast code point, and both decode without error.
assert(cast.broadcast == 0, 'castTypes: broadcast is 00');
assert(cast.groupcastAckNack == 1, 'castTypes: groupcast with ACK-or-NACK feedback is 01');
assert(cast.unicast == 2, 'castTypes: unicast is 10, NOT 01');
assert(cast.groupcastNackOnly == 3, 'castTypes: groupcast with NACK-only feedback is 11');
assert(numel(unique(struct2array(cast))) == 4, 'castTypes: the four code points must be distinct');

% They must round-trip through the SCI 2-A packer, which is the actual consumer.
for v = [cast.broadcast cast.groupcastAckNack cast.unicast cast.groupcastNackOnly]
    dp = struct('harqProcessNumber', 3, 'ndi', 1, 'rv', 2, 'sourceID', 200, ...
                'destinationID', 5000, 'harqFeedbackEnabled', 1, 'castType', v, 'csiRequest', 0);
    back = phy.ts38212.sci2aUnpack(phy.ts38212.sci2aPack(dp));
    assert(back.castType == v, 'castTypes: value %d must survive an SCI 2-A round trip, got %d', v, back.castType);
end

%% ---- a well-formed request, both cast types --------------------------------
t = sap.txReqInit();
t.slotPhysical = 1000; t.slotLogical = 1000;
t.startSubch = 2; t.LsubCH = 2; t.mcs = 7;
t.tb = true(520, 1);
t.harqId = 3; t.ndi = 1; t.rv = 0;
t.srcL2Id = 2^24 - 1; t.dstL2Id = 12345;
t.castType = cast.unicast; t.harqFeedbackEnabled = 1;
t.prioTx = 3; t.txPowerDbm = 23; t.ctxIds = [1 2 3];
tv = sap.txReqValidate(t, 10);
assert(isequal(tv, t), 'txReqValidate: a valid request must pass through unchanged');
assert(isempty(tv.waveform), 'txReqInit: the waveform must default to empty -- the system-level path builds none');

% Broadcast with feedback disabled, the other end of the scope.
b = t; b.castType = cast.broadcast; b.harqFeedbackEnabled = 0; b.dstL2Id = 2^24 - 1;
sap.txReqValidate(b, 10);
% Broadcast WITH feedback is not rejected: TS 38.214 clause 8.1 leaves the cast type to higher
% layers and no clause read forbids the combination. Asserting a convention as a rule is the
% over-constraint +mac/CLAUDE.md records the test suite making with NDI.
bf = b; bf.harqFeedbackEnabled = 1;
sap.txReqValidate(bf, 10);

%% ---- SCI field widths ---------------------------------------------------
% Each of these is a field the SCI must carry. Out of range means a transmission that cannot be
% signalled -- and, uncaught, a silently truncated field that decodes to a different LEGAL value.
mustError(@() sap.txReqValidate(setf(t, 'mcs', 32), 10), 'sap:txReqValidate:badField', 'mcs above the 5-bit field');
mustError(@() sap.txReqValidate(setf(t, 'harqId', 16), 10), 'sap:txReqValidate:badField', 'harqId above the 4-bit field');
mustError(@() sap.txReqValidate(setf(t, 'rv', 4), 10), 'sap:txReqValidate:badField', 'rv above the 2-bit field');
mustError(@() sap.txReqValidate(setf(t, 'castType', 4), 10), 'sap:txReqValidate:badField', 'a cast type outside Table 8.4.1.1-1');
mustError(@() sap.txReqValidate(setf(t, 'prioTx', 0), 10), 'sap:txReqValidate:badField', 'priority 0 (the field is 1..8)');
mustError(@() sap.txReqValidate(setf(t, 'prioTx', 9), 10), 'sap:txReqValidate:badField', 'priority 9');
mustError(@() sap.txReqValidate(setf(t, 'srcL2Id', 2^24), 10), 'sap:txReqValidate:badField', 'a Layer-2 ID above 24 bits');
mustError(@() sap.txReqValidate(setf(t, 'ndi', 2), 10), 'sap:txReqValidate:badField', 'a non-binary NDI');
% The top of each range is legal.
sap.txReqValidate(setf(setf(setf(t, 'mcs', 31), 'harqId', 15), 'rv', 3), 10);

%% ---- the sub-channel assignment must fit the pool ------------------------
% Clause 8.1.2.2: L_subCH contiguous sub-channels from startSubch, so the last must exist. An
% overrun becomes an out-of-band PRB allocation at the grid, far from its cause.
sap.txReqValidate(setf(setf(t, 'startSubch', 8), 'LsubCH', 2), 10);   % 8..9 of 10: exact fit
mustError(@() sap.txReqValidate(setf(setf(t, 'startSubch', 9), 'LsubCH', 2), 10), 'sap:txReqValidate:subchOverrun', 'an assignment running past the last sub-channel');
mustError(@() sap.txReqValidate(setf(t, 'LsubCH', 0), 10), 'sap:txReqValidate:badField', 'zero sub-channels');
mustError(@() sap.txReqValidate(t, 3), 'sap:txReqValidate:subchOverrun', 'a pool too small for this assignment');

%% ---- the transport block and its attribution ----------------------------
mustError(@() sap.txReqValidate(setf(t, 'tb', false(0, 1)), 10), 'sap:txReqValidate:emptyTb', 'an empty transport block');
mustError(@() sap.txReqValidate(setf(t, 'tb', true(1, 520)), 10), 'sap:txReqValidate:badTb', 'a row-vector transport block');
mustError(@() sap.txReqValidate(setf(t, 'tb', ones(520, 1)), 10), 'sap:txReqValidate:badTb', 'a numeric transport block');
% ctxIds is what makes latency close: without it a delivery cannot be attributed to a packet.
mustError(@() sap.txReqValidate(setf(t, 'ctxIds', zeros(1, 0)), 10), 'sap:txReqValidate:noCtxIds', 'a TB no packet can be attributed to');
mustError(@() sap.txReqValidate(setf(t, 'ctxIds', [1 2 2]), 10), 'sap:txReqValidate:duplicateCtxIds', 'the same packet twice in one TB');
mustError(@() sap.txReqValidate(setf(t, 'ctxIds', [1 0]), 10), 'sap:txReqValidate:badCtxIds', 'a zero packet id');

%% ---- the struct must come from txReqInit ---------------------------------
partial = rmfield(t, 'rv');
mustError(@() sap.txReqValidate(partial, 10), 'sap:txReqValidate:missingField', 'a struct missing a field');

%% ---- the waveform slot: empty for SLS, a column for LLS -----------------
w = t; w.waveform = complex(randn(4096, 1), randn(4096, 1));
sap.txReqValidate(w, 10);
mustError(@() sap.txReqValidate(setf(t, 'waveform', complex(randn(1, 4096), randn(1, 4096))), 10), 'sap:txReqValidate:badWaveform', 'a row-vector waveform');

fprintf('test_txReq: all assertions passed.\n');
end

function s = setf(s, name, value)
s.(name) = value;
end

function mustError(fh, expectedId, what)
try
    fh();
catch e
    assert(strcmp(e.identifier, expectedId), 'expected %s for %s, got %s', expectedId, what, e.identifier);
    return;
end
error('test_txReq:noError', 'expected an error for %s, none raised', what);
end
