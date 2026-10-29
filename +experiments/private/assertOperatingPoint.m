function assertOperatingPoint(scen)
%assertOperatingPoint Refuse to run an SLS scenario off the suite's operating point.
%The point is experiments.settings().op: mu = 1 (30 kHz), 5 sub-channels x 10 PRB = 50 PRB (the
%20 MHz channel), P_CMAX 23 dBm, TR 38.901 RMa path loss. The first version of this suite ran its
%system-level experiments on the SLS default pool (10 x 10 PRB, a 40 MHz channel) without anything
%noticing; this check is why that cannot happen again.
op = experiments.settings().op;
% The path-loss model is not checked: it belongs to the link (settings().link), which a run may
% override (fieldScenario's .link); the channel bandwidth, pool, power and timing may not change.
got = struct('mu', scen.mu, 'numSubchannel', scen.numSubchannel, 'subchSizeRb', scen.subchSizeRb, ...
    'pCmaxDbm', scen.pCmaxDbm, 'plModel', scen.radio.plModel.name);
ok = got.mu == op.mu && got.numSubchannel == op.numSubchannel && got.subchSizeRb == op.subchSizeRb && ...
    got.pCmaxDbm == op.pCmaxDbm;
ok = ok && ~isnan(scen.radio.plModel.antennaGainDb) && scen.decodeMarginSlots == op.decodeMarginSlots;
if ~ok
    error('experiments:offOperatingPoint', ['scenario is off the operating point: mu %d, %d x %d PRB, ' ...
        '%g dBm, %s (expected mu %d, %d x %d PRB, %g dBm, %s)'], got.mu, got.numSubchannel, ...
        got.subchSizeRb, got.pCmaxDbm, got.plModel, op.mu, op.numSubchannel, op.subchSizeRb, ...
        op.pCmaxDbm, op.plModel);
end
end
