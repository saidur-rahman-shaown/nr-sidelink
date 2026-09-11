function test_chanmodel()
%test_chanmodel Path loss models and the module boundary they sit behind.
%SPEC: 'rma' is TR 38.901 clause 7.4.1 Table 7.4.1-1, via the 5G Toolbox (no local PDF -- see
%      harness.chanmodel.pathlossRma). 'logdistance' has no spec behind it and says so. What is
%      assertable here is the INTERFACE contract and the physical sanity of each curve, not
%      bit-exactness against a document this repo does not carry.

fc = 5.9e9;

%% ---- the module boundary: construct through one door, evaluate through one
rma  = harness.chanmodel.pathlossModel('rma', struct('fcHz', fc, 'losMode', 'los', 'hTxM', 1.5, 'hRxM', 1.5));
logd = harness.chanmodel.pathlossModel('logdistance', struct('fcHz', fc, 'exponent', 2.7, 'refDistM', 1));
assert(strcmp(rma.name, 'rma') && strcmp(logd.name, 'logdistance'), 'the descriptor must carry its model name');
% An unknown model is rejected at construction, not silently substituted at evaluation.
mustError(@() harness.chanmodel.pathlossModel('tr37885', struct('fcHz', fc)), 'chanmodel:pathlossModel:unknownModel', 'a model that does not exist');
% Missing parameters are caught where the model is built, so a scenario cannot carry a
% half-specified model into a run.
mustError(@() harness.chanmodel.pathlossModel('rma', struct('fcHz', fc, 'losMode', 'los', 'hTxM', 1.5)), 'chanmodel:pathlossModel:missingParam', 'an rma model with no receiver height');
mustError(@() harness.chanmodel.pathlossModel('logdistance', struct('fcHz', fc, 'exponent', 2)), 'chanmodel:pathlossModel:missingParam', 'a logdistance model with no reference distance');
mustError(@() harness.chanmodel.pathlossModel('rma', struct('fcHz', fc, 'losMode', 'maybe', 'hTxM', 1.5, 'hRxM', 1.5)), 'chanmodel:pathlossModel:badLosMode', 'an LOS mode that is neither los nor nlos');
mustError(@() harness.chanmodel.pathloss(struct('nope', 1), 10), 'chanmodel:pathloss:badModel', 'a struct that did not come from pathlossModel');
mustError(@() harness.chanmodel.pathloss(rma, -1), 'chanmodel:pathloss:negativeDistance', 'a negative distance');

%% ---- shape: both models are monotone, and preserve input shape ---------
d = [10 30 100 300 1000 3000];
for m = {rma, logd}
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

%% ---- the two models genuinely differ, or swapping them means nothing ---
plLog = harness.chanmodel.pathloss(logd, d);
assert(max(abs(plL - plLog)) > 5, 'RMa and the placeholder must differ materially, else the model choice is cosmetic');

%% ---- the scenario carries a model descriptor, and only that ------------
scen = harness.sls.scenarioInit(4, 1);
assert(isfield(scen.radio, 'plModel') && isstruct(scen.radio.plModel), 'the scenario must carry a model descriptor');
assert(~isfield(scen.radio, 'plExponent') && ~isfield(scen.radio, 'plRefDistM'), ...
    'loose path loss parameters must not survive alongside the descriptor: two sources of truth is one too many');
% Swapping the model is a one-field change and nothing else needs touching.
alt = scen;
alt.radio.plModel = logd;
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
