function g = grantClear(g)
%grantClear Clear the selected sidelink grant, TS 38.321 clause 5.22.1.2.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.2: once any (re-)selection condition holds, "clear the
%        selected sidelink grant associated to the Sidelink process, if available; trigger the TX
%        resource (re-)selection". Also clause 5.22.1.1's keep branch, which begins "clear the
%        selected sidelink grant, if available" before redrawing the counter.
%Inputs: g  struct, with or without a grant installed ("if available" -- clearing an already
%           empty state is explicitly legal and is a no-op, not an error)
%Outputs: g  a fresh empty lifecycle state
%
%Clearing is total: the resources, the counter, the sl-ReselectAfter streak and any pending
%sl-ProbResourceKeep draw all go. Carrying the unused-period streak across a reselection would
%let an old grant's idleness fire sl-ReselectAfter on a brand-new one.
g = mac.grantInit();
end
