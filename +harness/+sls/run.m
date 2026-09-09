function [kpi, ue, scen] = run(nUe, nSlots, seed, castLabel)
%run Execute a system-level scenario and return its KPIs.
%Spec:   none -- the simulator's top level.
%Inputs: nUe     integer, >=2
%        nSlots  integer, >=1 -- PHYSICAL slots to execute
%        seed    integer -- reproduces a run exactly
%        castLabel  char, 'broadcast' (default) or 'unicast'
%Outputs: kpi   from +harness/kpiReport
%         ue    final per-UE state, for inspection
%         scen  the scenario, including its advanced RNG stream
%
%Every packet is accounted for at the end: delivered, PDB-expired, or still in flight. The
%last is asserted to be only what a longer run would have resolved -- a packet quietly left in
%flight leaves the denominator, and that is the arithmetic that makes a reliability figure
%look better than the run was.

if nargin < 4
    castLabel = 'broadcast';
end
scen = harness.sls.scenarioInit(nUe, seed, castLabel);
[kpi, ue, scen] = harness.sls.runScenario(scen, nSlots);
end
