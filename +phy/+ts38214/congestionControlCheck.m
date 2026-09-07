function [withinLimit, crCumulative, violated] = congestionControlCheck(crPerPriority, crLimitPerPriority, crLimitPresent)
%congestionControlCheck Sidelink congestion control limit test, TS 38.214 clause 8.1.6.
%Spec:   TS 38.214 V16.17.0, clause 8.1.6 ("Sidelink congestion control in sidelink resource
%        allocation mode 2"). The clause in full: "If a UE is configured with higher layer
%        parameter sl-CR-Limit and transmits PSSCH in slot n, the UE shall ensure the following
%        limits for any priority value k;  sum_{i>=k} CR(i) <= CR_limit(k)  where CR(i) is the
%        CR evaluated in slot n-N for the PSSCH transmissions with 'Priority' field in the SCI
%        set to i, and CR_limit(k) corresponds to the high layer parameter sl-CR-Limit that is
%        associated with the priority value k and the CBR range which includes the CBR measured
%        in slot n-N, where N is the congestion control processing time."
%Inputs: crPerPriority       1 x 8 row vector, real, each 0<=CR<=1 -- CR(i) for i=1..8, the
%                            channel occupancy ratio evaluated in slot n-N (N from
%                            procTimeCongestion) restricted to PSSCH transmissions whose SCI
%                            'Priority' field is i. Measuring CR is TS 38.215's job
%                            (+phy/+ts38215/, not built), so this is taken as a caller-supplied
%                            input. Entry i is priority value i, with 1 the HIGHEST priority
%                            and 8 the lowest -- see the summation-direction note below.
%        crLimitPerPriority  1 x 8 row vector, real, each 0<=limit<=1 -- CR_limit(k) for k=1..8,
%                            ALREADY RESOLVED from the raw sl-CR-Limit-r16 INTEGER(0..10000) to
%                            a ratio (TS 38.331: "Value 0 corresponds to 0, value 1 to 0.0001
%                            [...] until value 10000, which corresponds to 1"), and ALREADY
%                            SELECTED for the CBR range containing the CBR measured in slot n-N
%                            (see cbrRangeIndex for that lookup). The remaining
%                            sl-CBR-PriorityTxConfigList -> sl-CBR-ConfigIndex ->
%                            sl-Tx-ConfigIndexList -> sl-CBR-PSSCH-TxConfigList indirection
%                            that turns a (CBR level, priority) pair into one sl-CR-Limit value
%                            is not built in +cfg/ -- same "pre-resolved units taken as input"
%                            pattern candidateSet uses for sl-Thres-RSRP-List and
%                            sl-TxPercentageList. Entries where crLimitPresent is false are
%                            ignored and need not be meaningful.
%        crLimitPresent      1 x 8 logical row vector -- whether sl-CR-Limit is configured for
%                            priority value k. sl-CR-Limit-r16 is OPTIONAL in TS 38.331, and
%                            clause 8.1.6's limit applies only "if a UE is configured with
%                            higher layer parameter sl-CR-Limit", so an absent entry imposes no
%                            limit at that k. Carried as an explicit presence flag rather than
%                            encoding absence as a limit of 1, per +cfg/CLAUDE.md's rule that
%                            absence and a value are different things.
%Outputs: withinLimit   logical scalar -- true if every k with a configured limit satisfies
%                       clause 8.1.6's inequality, i.e. the UE may transmit in slot n as
%                       planned. What to DO when it is false ("It is up to UE implementation
%                       how to meet the above limits, including dropping the transmissions in
%                       slot n") is deliberately NOT decided here -- that is a UE-implementation
%                       policy living in +phy/+rx/+policy/, the same split candidateSet applies
%                       to the T1/T2 choice. This function reports; it does not drop.
%         crCumulative  1 x 8 row vector, real, each >=0 -- the left-hand side sum_{i>=k} CR(i)
%                       for k=1..8, returned for diagnostics and tests. Non-increasing in k by
%                       construction.
%         violated      1 x 8 logical row vector -- true at each k whose configured limit is
%                       exceeded. Always false where crLimitPresent is false.
%
%Summation direction is the trap here. Priority value 1 is the HIGHEST priority and 8 the
%lowest (TS 38.214 clause 8.1.4's prio_TX/prio_RX use the same 1..8 numbering, as does this
%package's candidateSet). "sum_{i>=k}" therefore accumulates DOWNWARD in priority: the limit at
%k=1 covers every priority's occupancy (the whole sum), and the limit at k=8 covers only the
%lowest-priority traffic. Writing it as a forward cumulative sum -- summing i<=k -- inverts the
%meaning and still produces plausible-looking ratios in [0,1], so it fails silently. The loop
%below is written as the clause states it rather than as a cumsum for exactly this reason (the
%normative-packages rule: "Write the loop the spec describes").
%The SCI-to-priority-value offset is applied OUTSIDE this function, exactly once. Clause 8.1.6
%speaks of "priority value" i and k, which this interface fixes at 1..8 (matching clause 8.1.4's
%prio_TX/prio_RX and this package's candidateSet), whereas the SCI format 1-A 'Priority' field
%is 3 bits carrying codepoints 0..7. Whoever indexes crPerPriority from a decoded SCI applies
%the +1; this function never does. Independent-verifier's own flag on this: an off-by-one there
%"would silently shift every limit by one priority level and would be invisible to all three of
%these test cases" -- it is a +phy/CLAUDE.md "applied exactly once" obligation on the caller.
numPriorities = 8;   % priority values 1..8; the SCI format 1-A 'Priority' field is 3 bits
                     % (TS 38.212 clause 8.3.1.1) and clause 8.1.4 indexes prio_TX/prio_RX 1..8

if ~isvector(crPerPriority) || numel(crPerPriority) ~= numPriorities
    error('ts38214:congestionControlCheck:badCr', 'congestionControlCheck: crPerPriority must have %d entries (one per priority value), got %d', numPriorities, numel(crPerPriority));
end
if ~isvector(crLimitPerPriority) || numel(crLimitPerPriority) ~= numPriorities
    error('ts38214:congestionControlCheck:badCrLimit', 'congestionControlCheck: crLimitPerPriority must have %d entries (one per priority value), got %d', numPriorities, numel(crLimitPerPriority));
end
if ~isvector(crLimitPresent) || numel(crLimitPresent) ~= numPriorities
    error('ts38214:congestionControlCheck:badPresence', 'congestionControlCheck: crLimitPresent must have %d entries (one per priority value), got %d', numPriorities, numel(crLimitPresent));
end
if any(crPerPriority < 0) || any(crPerPriority > 1)
    error('ts38214:congestionControlCheck:badCr', 'congestionControlCheck: every crPerPriority entry must be in [0,1] (CR is an occupancy ratio)');
end
present = logical(crLimitPresent(:)');
limits = crLimitPerPriority(:)';
if any(limits(present) < 0) || any(limits(present) > 1)
    error('ts38214:congestionControlCheck:badCrLimit', 'congestionControlCheck: every present crLimitPerPriority entry must be in [0,1] (sl-CR-Limit resolved to a ratio)');
end

cr = crPerPriority(:)';
crCumulative = zeros(1, numPriorities);
violated = false(1, numPriorities);
for k = 1:numPriorities
    % clause 8.1.6: sum_{i>=k} CR(i)
    s = 0;
    for i = k:numPriorities
        s = s + cr(i);
    end
    crCumulative(k) = s;
    if present(k)
        violated(k) = s > limits(k);
    end
end
withinLimit = ~any(violated);
end
