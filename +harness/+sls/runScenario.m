function [kpi, ue, scen] = runScenario(scen, nSlots)
%runScenario Execute a PREPARED scenario and return its KPIs.
%Spec:   none -- the simulator's top level.
%Inputs: scen    from +harness/+sls/scenarioInit, optionally edited first
%        nSlots  integer, >=1 -- PHYSICAL slots to execute
%Outputs: kpi   from +harness/kpiReport
%         ue    final per-UE state, for inspection
%         scen  the scenario, including its advanced RNG stream
%
%Split from +harness/+sls/run so a caller can change the scenario before running it -- widen
%the UE spacing, move a UE, alter the policy. Without this seam every scenario variation would
%need a parameter on scenarioInit, and the ones worth testing (a link far enough for its
%feedback to be lost, say) are exactly the ones nobody thinks to parameterise in advance.
%
%Every packet is accounted for at the end: delivered, PDB-expired, or still in flight. The last
%is asserted to be only what a longer run would have resolved -- a packet quietly left in
%flight leaves the denominator, and that is the arithmetic that makes a reliability figure look
%better than the run was.

ue = harness.sls.ueInit(1, scen);
for i = 2:scen.nUe
    ue(i) = harness.sls.ueInit(i, scen);
end

resolved = repmat(sap.ctxInit(1, 0, 0, 1, 1, 1, 1, 0, 0), 1, 0);
nTx      = 0;
nRlf     = 0;
nReeval  = 0;
nPreempt = 0;
nCongDrop = 0;
rxDist   = zeros(1, 0);
rxOk     = false(1, 0);
for n = 0:nSlots - 1
    [ue, scen, done, air, rxLog, rlf, nR, nP, nC] = harness.sls.slotStep(ue, scen, n);
    nCongDrop = nCongDrop + nC;
    nReeval  = nReeval + nR;
    nPreempt = nPreempt + nP;
    resolved = [resolved done];  %#ok<AGROW>
    nTx      = nTx + numel(air);
    nRlf     = nRlf + rlf;
    rxDist   = [rxDist rxLog.distM];  %#ok<AGROW>
    rxOk     = [rxOk rxLog.ok];       %#ok<AGROW>
end

nGenerated = sum([ue.nextPktId]) - scen.nUe;   % nextPktId starts at 1 on every UE
cbrByUe = arrayfun(@(x) x.cbr, ue);
kpi = harness.kpiReport(resolved, nGenerated, nSlots, scen, nTx, rxDist, rxOk, nRlf, nReeval, nPreempt, nCongDrop, cbrByUe);
end
