function scen = scenarioFromConfig(c)
%scenarioFromConfig Build a runnable scenario from simConfig's struct.
%Spec:   none -- configuration assembly. Every 3GPP quantity is still resolved by the package
%        that owns it; this function only routes the user's choices into scenarioInit's output.
%Inputs: c  the struct simConfig returns
%Outputs: scen  a scenario, ready for harness.sls.runScenario
%
%WHY THIS OVERRIDES scenarioInit RATHER THAN REPLACING IT
%----------------------------------------------------------
%scenarioInit derives a dozen quantities from each other -- the transport block table from the
%MCS and pool geometry, L_subCH from the TB table and the payload, the escalation bound from the
%closest separation, the CBR and CR window lengths from the numerology. Rebuilding those here
%would duplicate the derivations and let them drift. So the config's primitive choices are
%applied FIRST, scenarioInit runs its derivations over them, and only the fields that are pure
%inputs are set afterwards.
%
%That ordering is why this is a function and not a struct literal: several of the fields below
%must be in place before the derivations run, and several others only make sense after.

% Flatten the config's grouped struct into the flat override list scenarioInit consumes. The
% grouping exists for the reader's benefit in simConfig; scenarioInit wants one namespace.
ov = struct();
groups = {'pool', 'app', 'policy', 'radio'};
for g = 1:numel(groups)
    if ~isfield(c, groups{g}), continue; end
    f = fieldnames(c.(groups{g}));
    for k = 1:numel(f)
        ov.(f{k}) = c.(groups{g}).(f{k});
    end
end
ov.spacingM = c.link.spacingM;

scen = harness.sls.scenarioInit(c.link.nUe, c.sim.seed, c.link.castType, ov);

% ---- pure inputs, safe to apply after the derivations --------------------
scen.txUeMask = false(1, c.link.nUe);
if isempty(c.link.txUeIds)
    scen.txUeMask(:) = true;
else
    if any(c.link.txUeIds < 1 | c.link.txUeIds > c.link.nUe)
        error('sls:scenarioFromConfig:badTxUe', 'scenarioFromConfig: txUeIds must lie in 1..%d', c.link.nUe);
    end
    scen.txUeMask(c.link.txUeIds) = true;
end
if ~any(scen.txUeMask)
    error('sls:scenarioFromConfig:noTransmitter', 'scenarioFromConfig: no UE generates traffic; the run would be empty');
end
end
