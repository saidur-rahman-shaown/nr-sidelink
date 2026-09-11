function [ackBit, detected, metric] = psfchDetect(grid, carrier, pool, dpList, ackNackOnly, threshold)
%psfchDetect Sweep every PSFCH resource this UE is monitoring in one slot.
%Spec:   none -- detection is not specified. TS 38.213 clause 16.3 fixes WHICH resource carries
%        the feedback for a given transmission; finding out whether anything is there is this
%        function's job.
%Inputs: grid         nSubcarriers-by-nSymbols complex -- the demodulated received slot
%        carrier      scalar struct, slCarrierConfig
%        pool         scalar struct -- sl_PSFCH_Config_r16 fields
%        dpList       1 x nRes struct array -- one entry per monitored resource, each carrying
%                     the .m0/.lp/.nsf/.NsymbSlot/.startPRB/.symbol that clause 16.3 derived for
%                     one outstanding transmission. .mcs is ignored: it encodes the answer
%        ackNackOnly  1 x nRes logical -- per resource, since a UE can have unicast and
%                     NACK-only groupcast transmissions outstanding at the same time and the two
%                     are detected differently
%        threshold    real, >0 -- correlation threshold, shared across resources
%Outputs: ackBit    1 x nRes integer -- 0 NACK, 1 ACK, -1 DTX
%         detected  1 x nRes logical
%         metric    nRes x 2 real -- the [NACK ACK] correlations per resource
%
%A TRANSMITTER MONITORS SEVERAL RESOURCES AT ONCE
%--------------------------------------------------
%One UE can have several TBs outstanding -- up to four concurrent Sidelink processes in Mode 2
%(TS 38.321 clause 5.22.1.3.1) -- and clause 16.3 gives each its own PRB and cyclic-shift pair.
%So the receive side is a sweep, not a single decode, and each resource is judged
%independently: one DTX does not make the others DTX. Judging them jointly, for instance by
%taking the strongest correlation in the slot, would let a loud ACK from one peer mask another
%peer's silence -- turning a radio link failure into a healthy link.
%
%ackNackOnly IS PER RESOURCE, NOT PER SLOT
%-------------------------------------------
%The cast type is a property of the transmission being acknowledged, not of the receiving UE or
%the slot. A UE with a unicast peer and a NACK-only groupcast running concurrently must apply
%Table 16.3-2 to one resource and Table 16.3-3 to the other in the same slot. A single
%slot-wide flag gets one of them wrong, and the failure is silent: the NACK-only resource would
%be scored against an ACK hypothesis that Table 16.3-3 does not define.

nRes = numel(dpList);
if numel(ackNackOnly) ~= nRes
    error('rx:det:psfchDetect:sizeMismatch', 'psfchDetect: ackNackOnly must have one entry per monitored resource (%d), got %d', nRes, numel(ackNackOnly));
end

ackBit   = -ones(1, nRes);
detected = false(1, nRes);
metric   = zeros(nRes, 2);

for r = 1:nRes
    dp = dpList(r);
    % Locate the resource's content symbol. slPSFCHIndices needs a config, and the config needs
    % an mcs to resolve alpha -- so a placeholder is used purely to obtain the INDICES, which do
    % not depend on the cyclic shift. The detector then re-derives alpha per hypothesis itself.
    probe = dp;
    probe.mcs = 0;
    pcfg = phy.ts38211.slPSFCHConfig(pool, probe);
    ind = phy.ts38211.slPSFCHIndices(carrier, pcfg);

    if max(ind(:, 1)) + 1 > size(grid, 1) || max(ind(:, 2)) + 1 > size(grid, 2)
        continue;                       % the resource lies outside this grid
    end
    sym = grid(sub2ind(size(grid), ind(:, 1) + 1, ind(:, 2) + 1));

    [ackBit(r), detected(r), m] = phy.chan.psfchRx(sym, carrier, pool, dp, ackNackOnly(r), threshold);
    metric(r, :) = m;
end
end
