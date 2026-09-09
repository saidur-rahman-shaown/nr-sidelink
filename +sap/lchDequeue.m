function [lchSet, served] = lchDequeue(lchSet, allocBytes)
%lchDequeue Remove the SDUs an LCP allocation actually serves, oldest first.
%Spec:   TS 38.321 clause 5.22.1.4.1.3 allocates resources to logical channels; turning a
%        per-channel byte budget into specific SDUs is the multiplexing step, and the
%        SDU-boundary rules belong to +rlc/. See the simplification below.
%Inputs: lchSet      from +sap/lchInit
%        allocBytes  1 x nLch real row vector -- +mac/slLcp's `alloc` output
%Outputs: lchSet  with the served contexts removed
%         served  1 x nServed struct array of contexts, in queue order, still in flight.
%                 The caller transmits them and calls +sap/ctxTransmitted on each.
%
%SIMPLIFICATION: WHOLE SDUs ONLY, NO SEGMENTATION
%-------------------------------------------------
%A channel's allocation is spent on its queued SDUs oldest-first while the next one fits
%entirely. An SDU larger than the remaining allocation is left queued rather than split, and
%the leftover bytes go unused. Real segmentation operates on RLC SDU boundaries and is
%+rlc/'s job (+mac/CLAUDE.md's "Not built" list says so); until +rlc/ exists there is nothing
%to segment with.
%
%What this costs, so it is not mistaken for a result: throughput is under-reported whenever an
%allocation ends with a partial SDU's worth of room, and the under-report grows as SDUs get
%large relative to the grant. It never over-reports. It does not distort latency, since an SDU
%left behind is simply served by a later grant and carries its own timestamps with it.

if numel(allocBytes) ~= lchSet.nLch
    error('sap:lchDequeue:sizeMismatch', 'lchDequeue: allocBytes must be 1-by-%d, got %d', lchSet.nLch, numel(allocBytes));
end
if any(allocBytes < 0)
    error('sap:lchDequeue:negativeAlloc', 'lchDequeue: an allocation cannot be negative');
end

remaining = allocBytes;
takeMask  = false(1, numel(lchSet.q));

for k = 1:numel(lchSet.q)                       % queue order is arrival order, oldest first
    ch = lchSet.qLch(k);
    if lchSet.q(k).sizeBytes <= remaining(ch)
        remaining(ch) = remaining(ch) - lchSet.q(k).sizeBytes;
        takeMask(k)   = true;
    end
    % No `break` on a channel that cannot fit its head SDU: a later, smaller SDU on the same
    % channel may still fit. That is a deliberate departure from strict FIFO within a channel,
    % and it is bounded -- it only ever reorders around an SDU too large for THIS grant. Strict
    % head-of-line blocking would be the alternative; it wastes more of the grant and the
    % difference disappears entirely once +rlc/ can segment.
end

served      = lchSet.q(takeMask);
lchSet.q    = lchSet.q(~takeMask);
lchSet.qLch = lchSet.qLch(~takeMask);
end
