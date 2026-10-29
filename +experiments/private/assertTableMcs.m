function assertTableMcs(mcs, speedKmh)
%assertTableMcs Refuse a system-level run at an MCS the shipped BLER table does not hold.
%harness.phyabs.blerInterp answers an unmeasured MCS with the NEAREST measured row, silently, so
%an SLS run "at MCS 5" would really be a run at MCS 4. Every SLS-based experiment calls this
%first. MCS outside the table belong to experiments.linkCurves (link level).
% The table the run will READ: the one measured at its speed (registry), or the shipped one.
if nargin < 2, t = harness.phyabs.blerTable(); else, t = harness.phyabs.blerTableFor('tdld', speedKmh); end
if ~all(ismember(mcs, t.mcs))
    error('experiments:offTableMcs', ['MCS %s is not a row of harness.phyabs.blerTable (rows %s); ', ...
        'the SLS would silently read the nearest row. Use a table MCS, or experiments.linkCurves.'], ...
        mat2str(mcs(~ismember(mcs, t.mcs))), mat2str(t.mcs));
end
end
