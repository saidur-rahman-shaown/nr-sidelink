function [alloc, Sbj, selected] = slLcp(Sbj, priority, dataAvailable, harqFeedbackEnabled, eligible, grantBytes)
%slLcp Sidelink logical channel prioritisation: select channels and allocate the grant.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.4.1.2 (Selection of logical channels) and clause
%        5.22.1.4.1.3 (Allocation of sidelink resources). Bucket maintenance is slLcpBucket
%        (clause 5.22.1.4.1.1); this function assumes SBj is already up to date, as the clause's
%        own NOTE requires ("SBj is up to date at the time when a grant is processed by LCP").
%Inputs: Sbj                  1 x nLch real row vector, bytes -- current bucket levels, already
%                             advanced by slLcpBucket. May be negative.
%        priority             1 x nLch integer row vector, 1..8 -- sl-Priority, "where an
%                             INCREASING priority value indicates a LOWER priority level"
%                             (clause 5.22.1.4.1.1). So 1 is the highest priority, and
%                             "decreasing priority order" in the clause means ASCENDING numeric
%                             order. This inversion is the single easiest thing to get backwards
%                             here and it silently serves the least important traffic first.
%        dataAvailable        1 x nLch real row vector, bytes -- SL data available for
%                             transmission on each logical channel
%        harqFeedbackEnabled  1 x nLch logical row vector -- sl-HARQ-FeedbackEnabled per channel
%        eligible             1 x nLch logical row vector -- the caller's verdict on the
%                             remaining clause-5.22.1.4.1.2 conditions that are not modelled
%                             here: sl-configuredGrantType1Allowed for a Configured Grant Type 1,
%                             sl-AllowedCG-List including this grant's configured-grant index,
%                             and membership of the selected Destination. Destination selection
%                             is upstream because clause 5.22.1.4.1.2 NOTE 1 makes the tie-break
%                             "up to UE implementation"; pass eligible = false for channels of
%                             other Destinations. NOTE that the Destination-selection step is
%                             also where the SBj > 0 condition lives -- see below.
%        grantBytes           positive integer -- the usable grant size in bytes
%Outputs: alloc     1 x nLch real row vector, bytes -- bytes allocated to each logical channel
%         Sbj       1 x nLch real row vector -- buckets after decrementing by the FIRST pass's
%                   allocation only (see below)
%         selected  1 x nLch logical row vector -- the channels selected by clause 5.22.1.4.1.2
%
%WHERE THE SBj > 0 CONDITION ACTUALLY APPLIES. Clause 5.22.1.4.1.2 is two bullet lists, and the
%condition sits in the FIRST one only -- the list that picks a Destination ("select a Destination
%[...] among the logical channels that satisfy all the following conditions [...] SBj > 0, in
%case there is any logical channel having SBj > 0"). The SECOND list, which picks logical channels
%within the chosen Destination, has no SBj condition. So SBj gates which DESTINATION is served,
%not which of that Destination's channels are. That upstream test is also where the "in case there
%is any" qualifier does its work: it is a conditional filter, so a UE whose buckets have all gone
%negative still selects a Destination rather than deadlocking -- consistent with clause
%5.22.1.4.1.3's own NOTE that "The value of SBj can be negative".
%
%The HARQ-feedback rule, which decides the whole multiplex. Clause 5.22.1.4.1.3's last bullet is
%absolute: "A logical channel configured with sl-HARQ-FeedbackEnabled set to enabled and a
%logical channel configured with sl-HARQ-FeedbackEnabled set to disabled CANNOT be multiplexed
%into the same MAC PDU." Clause 5.22.1.4.1.2 resolves which value wins: the PDU takes the
%sl-HARQ-FeedbackEnabled of "the HIGHEST PRIORITY logical channel satisfying the above
%conditions", and every channel with the other value is dropped from this PDU. This function
%therefore picks the highest-priority eligible channel first and filters the rest to match it.
%
%Two passes, and the difference between them is the whole point of a token bucket:
%  Pass 1 (clause 5.22.1.4.1.3, first bullet) serves only channels with SBj > 0, in decreasing
%    priority order, each capped at its own SBj -- this is the prioritised-bit-rate guarantee.
%  Pass 2 (third bullet) then serves ALL selected channels "in a strict decreasing priority
%    order (REGARDLESS OF THE VALUE OF SBj) until either the data for that logical channel or the
%    SL grant is exhausted" -- this is what stops a grant going to waste.
%Only pass 1 decrements SBj (second bullet: "decrement SBj by the total size of MAC SDUs served
%to logical channel j above", where "above" is the first bullet). Decrementing for pass 2 as well
%is the classic LCP bug: it double-charges the bucket and starves the channel next time round.
%
%Not modelled here, deliberately: segmentation. The clause's rules ("the UE should not segment an
%RLC SDU if the whole SDU fits", "maximize the size of the segment to fill the grant") operate on
%RLC SDU boundaries, and this function allocates BYTE BUDGETS per logical channel. Turning a byte
%budget into SDUs and segments is RLC's job (+rlc/), and muxSlSch takes the resulting SDUs.
nLch = numel(Sbj);
if ~isrow(Sbj) || ~isequal(size(priority), size(Sbj)) || ~isequal(size(dataAvailable), size(Sbj)) ...
        || ~isequal(size(harqFeedbackEnabled), size(Sbj)) || ~isequal(size(eligible), size(Sbj))
    error('mac:slLcp:badShape', 'slLcp: Sbj, priority, dataAvailable, harqFeedbackEnabled and eligible must all be row vectors of the same length');
end
if any(priority < 1) || any(priority > 8) || any(mod(priority, 1) ~= 0)
    error('mac:slLcp:badPriority', 'slLcp: priority entries must be integers in 1..8 (sl-Priority)');
end
if any(dataAvailable < 0)
    error('mac:slLcp:badData', 'slLcp: dataAvailable entries must be nonnegative byte counts');
end
if grantBytes < 1 || mod(grantBytes, 1) ~= 0
    error('mac:slLcp:badGrant', 'slLcp: grantBytes must be a positive integer, got %s', num2str(grantBytes));
end
harqFeedbackEnabled = logical(harqFeedbackEnabled);
eligible = logical(eligible);

alloc = zeros(1, nLch);
selected = false(1, nLch);

% ---- clause 5.22.1.4.1.2: selection --------------------------------------
candidate = eligible & dataAvailable > 0;
if ~any(candidate)
    return;
end
% There is deliberately NO SBj filter here. Clause 5.22.1.4.1.2 has two bullet lists and the
% "SBj > 0, in case there is any logical channel having SBj > 0" condition appears ONLY in the
% first -- the one selecting a DESTINATION. The second list, "select the logical channels
% satisfying all the following conditions among the logical channels belonging to the selected
% Destination", conditions only on data availability, sl-configuredGrantType1Allowed,
% sl-AllowedCG-List and sl-HARQ-FeedbackEnabled. A channel with SBj <= 0 in the chosen
% Destination is therefore SELECTED; it simply wins nothing in the first allocation pass and is
% served by the second. Filtering it out here starves it permanently and leaves a large grant
% under-filled, which clause 5.22.1.4.1.3's "the UE should maximise the transmission of data"
% forbids. (Found by the independent-verifier pass; an earlier version of this function applied
% the filter here and had to be corrected.)

% The PDU's HARQ-feedback value is that of the highest-priority candidate; the rest must match.
idx = find(candidate);
[~, order] = sort(priority(idx));   % ascending numeric value == decreasing priority
highest = idx(order(1));
selected = candidate & (harqFeedbackEnabled == harqFeedbackEnabled(highest));

% ---- clause 5.22.1.4.1.3: allocation -------------------------------------
selIdx = find(selected);
[~, selOrder] = sort(priority(selIdx));
selIdx = selIdx(selOrder);          % strict decreasing priority order

% Pass 1: only SBj > 0, each capped by its own bucket. This is the pass that spends tokens.
remaining = grantBytes;
pass1 = zeros(1, nLch);
for k = 1:numel(selIdx)
    j = selIdx(k);
    if remaining <= 0
        break;
    end
    if Sbj(j) <= 0
        continue;
    end
    % An infinite sPBR bucket is not capped by SBj at all: clause 5.22.1.4.1.3 says to serve all
    % available data before meeting the sPBR of lower-priority channels.
    if isinf(Sbj(j))
        take = min(dataAvailable(j), remaining);
    else
        take = min([dataAvailable(j), Sbj(j), remaining]);
    end
    pass1(j) = take;
    alloc(j) = alloc(j) + take;
    remaining = remaining - take;
end
% "decrement SBj by the total size of MAC SDUs served to logical channel j above" -- pass 1 only.
Sbj = Sbj - pass1;

% Pass 2: "if any resources remain, all the logical channels selected [...] are served in a
% strict decreasing priority order (regardless of the value of SBj) until either the data for
% that logical channel or the SL grant is exhausted".
for k = 1:numel(selIdx)
    j = selIdx(k);
    if remaining <= 0
        break;
    end
    take = min(dataAvailable(j) - alloc(j), remaining);
    if take <= 0
        continue;
    end
    alloc(j) = alloc(j) + take;
    remaining = remaining - take;
end
end
