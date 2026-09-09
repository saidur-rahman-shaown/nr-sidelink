function lchSet = lchInit(lcid, prio, dstL2Id, pbr, bsd, harqFeedbackEnabled)
%lchInit Create the MAC SAP: a set of sidelink logical channels with empty queues.
%Spec:   the MAC SAP is TS 38.321 Figure 4.2.2-3's upper boundary -- SBCCH, SCCH and STCH, the
%        sidelink logical channels. The per-channel parameters are clause 5.22.1.4.1.1's
%        (sl-PrioritisedBitRate, sl-BucketSizeDuration, sl-Priority, sl-HARQ-FeedbackEnabled).
%        The queue itself is not specified: TS 38.321 says what to do with data available for
%        transmission, never where it waits.
%Inputs: lcid                 1 x nLch integer, 0..63 -- logical channel IDs, distinct
%        prio                 1 x nLch integer, 1..8 -- sl-Priority. 1 is the HIGHEST
%        dstL2Id              1 x nLch integer, 0..2^24-1 -- Destination Layer-2 ID per channel.
%                             Several channels may share one; that group is a Destination in
%                             clause 5.22.1.4.1.2's sense
%        pbr                  1 x nLch real, >=0, bytes/second -- sl-PrioritisedBitRate
%        bsd                  1 x nLch real, >=0, seconds -- sl-BucketSizeDuration
%        harqFeedbackEnabled  1 x nLch logical -- sl-HARQ-FeedbackEnabled
%Outputs: lchSet  scalar struct: the six inputs as parallel 1 x nLch row vectors, plus
%   .nLch  integer
%   .Sbj   1 x nLch real, bytes -- bucket levels, clause 5.22.1.4.1.1. Start at zero: the
%          clause initialises Bj to zero when the channel is established.
%   .q     1 x M struct array of +sap/ctxInit contexts -- ONE queue for all channels
%   .qLch  1 x M integer -- which channel each queued context belongs to
%
%WHY ONE QUEUE AND AN INDEX, NOT A QUEUE PER CHANNEL
%----------------------------------------------------
%A per-channel queue means a cell array or a nested variable-length field, and this struct
%crosses into +mac/, which is normative and bans both. One flat context array with a parallel
%index vector is the portable shape: it is two arrays, it serialises and diffs, and selecting a
%channel's SDUs is a mask rather than an indirection. The same reason +mac/slLcp takes six
%parallel row vectors rather than a struct array of channels.
%
%Arrival order is preserved globally, so `q` is oldest-first within every channel as well --
%which is what makes the head of a channel's queue its oldest SDU without a sort.

nLch = numel(lcid);
if nLch < 1
    error('sap:lchInit:noChannels', 'lchInit: at least one logical channel is required');
end
sizes = [numel(prio) numel(dstL2Id) numel(pbr) numel(bsd) numel(harqFeedbackEnabled)];
if any(sizes ~= nLch)
    error('sap:lchInit:sizeMismatch', 'lchInit: every parameter must be 1-by-%d, got lengths %s', nLch, mat2str([nLch sizes]));
end
if numel(unique(lcid)) ~= nLch
    error('sap:lchInit:duplicateLcid', 'lchInit: logical channel IDs must be distinct, got %s', mat2str(lcid));
end
if any(lcid < 0 | lcid > 63 | mod(lcid, 1) ~= 0)
    error('sap:lchInit:badLcid', 'lchInit: every lcid must be an integer in 0..63 (the 6-bit subheader field)');
end
if any(prio < 1 | prio > 8 | mod(prio, 1) ~= 0)
    error('sap:lchInit:badPrio', 'lchInit: every sl-Priority must be an integer in 1..8 (1 is highest)');
end
if any(pbr < 0) || any(bsd < 0)
    error('sap:lchInit:badBucket', 'lchInit: sl-PrioritisedBitRate and sl-BucketSizeDuration must be nonnegative');
end
if ~islogical(harqFeedbackEnabled)
    error('sap:lchInit:badHarqFlag', 'lchInit: harqFeedbackEnabled must be logical');
end

% An empty context array with the right fields, so every downstream isfield/indexing works
% before anything has been enqueued.
template = sap.ctxInit(1, 0, 0, 1, 1, 1, 1, 0, 0);

lchSet = struct( ...
    'nLch',                nLch, ...
    'lcid',                lcid(:)', ...
    'prio',                prio(:)', ...
    'dstL2Id',             dstL2Id(:)', ...
    'pbr',                 pbr(:)', ...
    'bsd',                 bsd(:)', ...
    'harqFeedbackEnabled', harqFeedbackEnabled(:)', ...
    'Sbj',                 zeros(1, nLch), ...
    'q',                   repmat(template, 1, 0), ...
    'qLch',                zeros(1, 0));
end
