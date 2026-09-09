function [T1, T2, feasible] = selectionWindow(mu, remainingPdb)
%selectionWindow Choose the Mode-2 selection window offsets T1 and T2.
%Spec:   the BOUNDS are TS 38.214 V16.17.0 clause 8.1.4 ("T1 ... 0 <= T1 <= T_proc,1^SL" and
%        "T2 ... T2min <= T2 <= remaining packet delay budget, and T2 = the remaining packet
%        delay budget if T2min is larger than it"). The CHOICE inside those bounds is left to
%        UE implementation by the same clause, so it is made here and validated there:
%        phy.ts38214.candidateSet re-derives both bounds and rejects a violation.
%Inputs: mu            integer, 0..3 -- mu_SL, the SCS configuration of the SL BWP
%        remainingPdb  integer, >=0, slots -- remaining packet delay budget, from
%                      phy.rx.policy.remainingPdbSlots
%Outputs: T1        integer, 0..T_proc,1^SL, slots -- selection-window start offset
%         T2        integer, >=0, slots -- selection-window end offset
%         feasible  logical -- false when no legal non-empty window exists at all, i.e. the
%                   budget is already shorter than the processing time. The caller must
%                   DISCARD on this and must not call candidateSet, which would raise
%                   ts38214:candidateSet:emptyWindow.
%
%The policy, and its two consequences
%------------------------------------
%T1 = T_proc,1^SL -- the LATEST legal start, i.e. the full processing time. Clause 8.1.4 makes
%T_proc,1 a floor, not a target: any T1 below it asks the UE to transmit sooner after the
%trigger than Table 8.1.4-2 says it can prepare. Taking the floor exactly is the only choice
%that is correct on every implementation rather than on a fast one, and it is what "worst
%case" means here. At mu=1 this is 5 slots = 2.5 ms, the value this simulator is configured
%around; it is derived from mu via phy.ts38214.procTimeSelection, never written as 2.5 ms,
%because the .portability rule forbids a hardcoded numerology and the ms figure is different
%at every other mu (3 ms at mu=0, 2.25 at mu=2, 2.125 at mu=3).
%
%T2 = the remaining PDB -- the LATEST legal end. This is legal in BOTH of clause 8.1.4's
%branches without a test, which is why T2min is not an input: when T2min < PDB the permitted
%range is [T2min, PDB] and the PDB is its upper end; when T2min >= PDB the clause forces
%T2 = PDB outright. The bound never binds, so nothing here needs sl-SelectionWindowList.
%
%First consequence -- this maximises M_total. The window is as long as the budget allows, so
%clause 8.1.4 step 1 enumerates the most candidates it ever can, S_A is at its largest, and
%the probability that two UEs draw the same resource is at its lowest. That is the reason to
%start here: it is the collision-optimal end of the trade.
%
%Second consequence, and the reason this is a placeholder -- it is also the LATENCY-WORST end.
%phy.rx.policy.resourcePick draws uniformly from S_A, so the expected transmission delay is
%about half the window: a 100 ms PDB yields a ~50 ms mean access delay even on a completely
%empty channel, where a shorter T2 would have transmitted in a few ms. The KPI this tree
%exists to measure therefore sits almost entirely on this one line. An optimising policy
%shrinks T2 toward T2min while the channel is quiet (CBR from +phy/+ts38215/) and reopens it
%toward the PDB as contention rises; that policy replaces this function and nothing else.

if ~(mu >= 0 && mu <= 3 && mod(mu, 1) == 0)
    error('policy:selectionWindow:badMu', 'selectionWindow: mu must be an integer in 0..3, got %s', num2str(mu));
end
if ~(remainingPdb >= 0 && mod(remainingPdb, 1) == 0)
    error('policy:selectionWindow:badPdb', 'selectionWindow: remainingPdb must be a nonnegative integer number of slots, got %s', num2str(remainingPdb));
end

T1 = phy.ts38214.procTimeSelection(mu);   % Table 8.1.4-2, in slots
T2 = remainingPdb;

% A window is usable only if it contains at least the slot n+T1. remainingPdb < T_proc,1 means
% the packet cannot be prepared before its budget runs out -- discard, do not clamp T1 down:
% clamping would keep the packet alive by asking for a transmission the UE cannot produce.
feasible = (T2 >= T1);
end
