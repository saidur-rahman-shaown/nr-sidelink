function rs = fieldLatencyStudy()
%fieldLatencyStudy Why the latencies are what they are: the same field run at several T2 caps.
%   Mode 2 draws each resource uniformly in [n + T1, n + T2]. With T2 at the remaining PDB (the
%   default, phy.rx.policy.selectionWindow) the access delay is ~PDB/2. fieldConfig's
%   c.impl.t2MaxMs caps T2 (never below T2min = 20 ms from sl-SelectionWindowList). This runs
%   the scenario at each cap with everything else fixed and writes
%   plots/field/latency_t2_compare.png, plus each run's own figures in plots/field_t2_<cap>/.
caps = [Inf 50 20];
rs = cell(1, numel(caps)); labels = cell(1, numel(caps));
for q = 1:numel(caps)
    c = fieldConfig();
    c.impl.t2MaxMs = caps(q);
    rs{q} = harness.field.run(c);
    if isfinite(caps(q))
        labels{q} = sprintf('T2 cap %g ms', caps(q));
        harness.field.plotField(rs{q}, fullfile('plots', sprintf('field_t2_%g', caps(q))));
    else
        labels{q} = 'T2 = remaining PDB (default)';
    end
    fprintf('\n##### %s\n', labels{q});
    harness.field.report(rs{q});
end
f = harness.field.plotCompare(rs, labels, fullfile('plots', 'field'), 'latency_t2_compare.png');
fprintf('\nWrote %s\n', f);
end
