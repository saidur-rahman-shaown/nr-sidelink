function nLog = slotToLogical(scen, nPhys)
%slotToLogical Physical slot to logical pool slot, ACROSS DFN wraps.
%Spec:   the mapping itself is TS 38.214 clause 8's, via phy.ts38214.poolSlotMap. The wrap is
%        not: that function's header states plainly that "no DFN-wrap (10240 ms) arithmetic is
%        implemented" and that a caller spanning a wrap boundary must unwrap first. This is that
%        caller.
%Inputs: scen   the scenario, for .logicalOfPhys and .TmaxPrime
%        nPhys  integer, >=0 -- physical slot, UNBOUNDED. A run longer than one DFN period is
%               the normal case, not an edge case: 20480 slots is only 10.24 s at mu=1
%Outputs: nLog  integer -- logical pool slot, monotonically increasing without bound, or -1
%               where the slot is not in the pool
%
%THE NUMBERING CONTINUES RATHER THAN RESETTING
%-----------------------------------------------
%The pool's slot pattern repeats every DFN period, so the LOOKUP wraps -- but the returned index
%does not. Period k's logical slot j is reported as k*T'max + j, so the numbering is monotone
%across the whole run.
%
%That is the only choice that keeps clause 8's arithmetic working. Every window in that clause
%is a DIFFERENCE of logical slot indices -- the selection window [n+T1, n+T2], the sensing
%window [n-T0, n-T_proc,0], TRIV's chained offsets, the reservation period. If the numbering
%reset at each wrap, every one of those differences would go hugely negative for any window
%straddling a boundary, once every 10.24 s. The failures would be sparse, periodic, and
%extremely hard to attribute.
%
%The windows are at most a few hundred slots against a 20480-slot period, so nothing else about
%the wrap is observable: a window either lies wholly inside one period or straddles exactly one
%boundary, and monotone numbering handles both identically.
%
%This is where the wrap is applied, and it is applied ONLY here and in the inverse,
%harness.sls.slotToPhysical -- .claude/rules/portability.md's "applied exactly once".

nDfn = numel(scen.logicalOfPhys);
if any(nPhys < 0 | mod(nPhys, 1) ~= 0)
    error('sls:slotToLogical:badSlot', 'slotToLogical: nPhys must be a nonnegative integer');
end

period = floor(nPhys / nDfn);
within = mod(nPhys, nDfn);
base   = scen.logicalOfPhys(within + 1);

nLog = base;
inPool = base >= 0;
nLog(inPool) = period(inPool) * scen.TmaxPrime + base(inPool);
end
