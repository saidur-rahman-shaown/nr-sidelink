function c = outcomeCodes()
%outcomeCodes Terminal outcome codes for a packet context.
%Spec:   none -- KPI bookkeeping, not a protocol quantity.
%Inputs: none
%Outputs: c  scalar struct of integer codes:
%   .inFlight   0 -- not yet resolved
%   .delivered  1 -- decoded by at least one intended receiver
%   .pdbExpired 2 -- the packet delay budget ran out first
%   .maxTx      3 -- sl-MaxTransNum spent without success
%   .dropped    4 -- discarded before transmission (congestion control, queue overflow)
%
%Named because the alternative is a bare 2 in a comparison, which the normative-packages rule
%calls a defect and which here would be worse than a defect: `pdbExpired` counted as anything
%other than a LOSS inflates throughput and truncates the latency tail at the same time, in the
%same direction, so no other statistic contradicts it. Every consumer compares against these
%names, never against a literal.

c = struct('inFlight', 0, 'delivered', 1, 'pdbExpired', 2, 'maxTx', 3, 'dropped', 4);
end
