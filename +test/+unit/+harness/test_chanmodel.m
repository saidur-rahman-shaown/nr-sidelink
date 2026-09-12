function test_chanmodel()
%test_chanmodel Path loss models and the module boundary they sit behind.
%SPEC: 'rma' is TR 38.901 clause 7.4.1 Table 7.4.1-1, via the 5G Toolbox (no local PDF -- see
%      harness.chanmodel.pathlossRma). What is assertable here is the INTERFACE contract and the
%      physical sanity of the curve, not bit-exactness against a document this repo does not
%      carry.

fc = 5.9e9;

%% ---- the module boundary: construct through one door, evaluate through one
rma = harness.chanmodel.pathlossModel('rma', struct('fcHz', fc, 'losMode', 'los', 'hTxM', 1.5, 'hRxM', 1.5));
assert(strcmp(rma.name, 'rma'), 'the descriptor must carry its model name');
% The hand-rolled log-distance placeholder was REMOVED, not deprecated: a placeholder that can
% still be selected is one that will eventually be selected, most likely by a scenario copied
% from an older one. Only a 3GPP model may be constructed now.
mustError(@() harness.chanmodel.pathlossModel('logdistance', struct('fcHz', fc, 'exponent', 2.7, 'refDistM', 1)), ...
    'chanmodel:pathlossModel:unknownModel', 'the removed log-distance placeholder');
% An unknown model is rejected at construction, not silently substituted at evaluation.
mustError(@() harness.chanmodel.pathlossModel('tr37885', struct('fcHz', fc)), 'chanmodel:pathlossModel:unknownModel', 'a model that does not exist');
% Missing parameters are caught where the model is built, so a scenario cannot carry a
% half-specified model into a run.
mustError(@() harness.chanmodel.pathlossModel('rma', struct('fcHz', fc, 'losMode', 'los', 'hTxM', 1.5)), 'chanmodel:pathlossModel:missingParam', 'an rma model with no receiver height');
mustError(@() harness.chanmodel.pathlossModel('rma', struct('fcHz', fc, 'losMode', 'maybe', 'hTxM', 1.5, 'hRxM', 1.5)), 'chanmodel:pathlossModel:badLosMode', 'an LOS mode that is neither los nor nlos');
mustError(@() harness.chanmodel.pathloss(struct('nope', 1), 10), 'chanmodel:pathloss:badModel', 'a struct that did not come from pathlossModel');
mustError(@() harness.chanmodel.pathloss(rma, -1), 'chanmodel:pathloss:negativeDistance', 'a negative distance');

%% ---- shape: monotone, and preserves input shape ------------------------
d = [10 30 100 300 1000 3000];
for m = {rma}
    pl = harness.chanmodel.pathloss(m{1}, d);
    assert(isequal(size(pl), size(d)), '%s: output shape must match the input', m{1}.name);
    assert(all(diff(pl) > 0), '%s: path loss must increase with distance, got %s', m{1}.name, mat2str(round(pl, 1)));
    assert(all(isfinite(pl)), '%s: path loss must be finite everywhere', m{1}.name);
end
% A 2-D input comes back 2-D: slotSinr passes a row per transmission.
pl2 = harness.chanmodel.pathloss(rma, [10 100; 300 1000]);
assert(isequal(size(pl2), [2 2]), 'a matrix of distances must return a matrix');

%% ---- RMa's validity floor is a CLAMP, not an extrapolation -------------
% TR 38.901's RMa expressions start at 10 m. Below it the formula is undefined and a co-located
% pair would otherwise give unbounded gain. Clamping is the same rule blerInterp applies at its
% table edges, for the same reason: a silent extrapolation off the end of a model is
% indistinguishable from a measurement.
floorPl = harness.chanmodel.pathloss(rma, 10);
assert(harness.chanmodel.pathloss(rma, 0) == floorPl, 'zero distance must clamp to the 10 m floor');
assert(harness.chanmodel.pathloss(rma, 5) == floorPl, 'below 10 m must clamp, not extrapolate');
assert(harness.chanmodel.pathloss(rma, 11) > floorPl, 'above the floor the model must vary again');

%% ---- NLOS must be worse than LOS, and by a growing margin --------------
rmaN = harness.chanmodel.pathlossModel('rma', struct('fcHz', fc, 'losMode', 'nlos', 'hTxM', 1.5, 'hRxM', 1.5));
plL = harness.chanmodel.pathloss(rma,  d);
plN = harness.chanmodel.pathloss(rmaN, d);
assert(all(plN > plL), 'NLOS must lose more than LOS at every distance');
assert(all(diff(plN - plL) > 0), 'the NLOS penalty must grow with distance, got %s', mat2str(round(plN - plL, 1)));

%% ---- the curve is RMa's, not free space --------------------------------
% Free-space loss is 20*log10(4*pi*d*f/c). RMa must depart from it materially at range, or the
% model is not doing anything a constant could not: TR 38.901's RMa LOS has a breakpoint beyond
% which the exponent rises, so the gap grows with distance.
c = 299792458;
fspl = 20 * log10(4 * pi * d * fc / c);
gap  = plL - fspl;
assert(gap(end) > gap(1) + 5, 'RMa must diverge from free space with distance, gap went %.1f -> %.1f dB', gap(1), gap(end));
assert(all(plL > fspl - 1), 'RMa must not be optimistic relative to free space');

%% ---- the scenario carries a model descriptor, and only that ------------
scen = harness.sls.scenarioInit(4, 1);
assert(isfield(scen.radio, 'plModel') && isstruct(scen.radio.plModel), 'the scenario must carry a model descriptor');
assert(~isfield(scen.radio, 'plExponent') && ~isfield(scen.radio, 'plRefDistM'), ...
    'loose path loss parameters must not survive alongside the descriptor: two sources of truth is one too many');
assert(strcmp(scen.radio.plModel.name, 'rma'), 'the scenario must run RMa, got ''%s''', scen.radio.plModel.name);
% Swapping the model is a one-field change and nothing else needs touching -- the property the
% dispatcher exists for, demonstrated here with the LOS/NLOS variants since they are the only
% two models that exist.
alt = scen;
alt.radio.plModel = rmaN;
a = harness.chanmodel.pathloss(scen.radio.plModel, 200);
b = harness.chanmodel.pathloss(alt.radio.plModel, 200);
assert(a ~= b, 'swapping the descriptor must change the channel');

fprintf('test_chanmodel: all assertions passed.\n');
end

function mustError(fh, expectedId, what)
try
    fh();
catch e
    assert(strcmp(e.identifier, expectedId), 'expected %s for %s, got %s', expectedId, what, e.identifier);
    return;
end
error('test_chanmodel:noError', 'expected an error for %s, none raised', what);
end
