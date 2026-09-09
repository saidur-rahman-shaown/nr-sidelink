function Sbj = slLcpBucket(Sbj, sPBR, sBSD, elapsedSeconds)
%slLcpBucket Advance the sidelink LCP token buckets SBj.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.4.1.1: "The MAC entity shall initialize SBj of the
%        logical channel to zero when the logical channel is established. For each logical
%        channel j, the MAC entity shall: increment SBj by the product sPBR x T before every
%        instance of the LCP procedure, where T is the time elapsed since SBj was last
%        incremented; if the value of SBj is greater than the sidelink bucket size (i.e.
%        sPBR x sBSD): set SBj to the sidelink bucket size."
%Inputs: Sbj             1 x nLch real row vector, bytes -- the current bucket level of each
%                        logical channel. Zero at establishment. MAY BE NEGATIVE on entry: the
%                        clause's own NOTE in 5.22.1.4.1.3 says "The value of SBj can be
%                        negative", because the second allocation pass decrements it below zero.
%        sPBR            1 x nLch real row vector, bytes/second -- sl-PrioritisedBitRate per
%                        logical channel. Inf is legal and meaningful: clause 5.22.1.4.1.3 gives
%                        it a dedicated rule ("If the sPBR of a logical channel is set to
%                        infinity, the MAC entity shall allocate resources for all the data that
%                        is available for transmission on the logical channel before meeting the
%                        sPBR of the lower priority logical channel(s)").
%        sBSD            1 x nLch real row vector, seconds -- sl-BucketSizeDuration per logical
%                        channel. The bucket SIZE is the product sPBR x sBSD, not sBSD itself.
%        elapsedSeconds  real, >=0 -- T, "the time elapsed since SBj was last incremented".
%                        Seconds, matching sPBR's per-second units; a caller working in slots
%                        converts first.
%Outputs: Sbj  1 x nLch real row vector -- the advanced and capped bucket levels
%
%Both halves matter and they are easy to collapse into one. The increment is unbounded in time
%(sPBR x T can be arbitrarily large after a long idle stretch); the CAP is what makes the bucket
%a bucket. Skipping the cap lets a channel that has been silent for a minute claim the whole
%grant on its next appearance, which looks like a scheduler bug rather than an LCP bug.
%
%Inf x 0 is the one arithmetic trap here: a channel with sPBR = Inf advanced by T = 0 gives
%Inf*0 = NaN in IEEE arithmetic, which would poison every later comparison silently. The clause's
%intent is that an infinite-rate bucket is always full, so it is set to its (infinite) size
%directly rather than accumulated.
if ~isrow(Sbj) || ~isrow(sPBR) || ~isrow(sBSD)
    error('mac:slLcpBucket:badShape', 'slLcpBucket: Sbj, sPBR and sBSD must be row vectors');
end
if ~isequal(size(Sbj), size(sPBR)) || ~isequal(size(Sbj), size(sBSD))
    error('mac:slLcpBucket:badShape', 'slLcpBucket: Sbj, sPBR and sBSD must be the same length, got %d, %d, %d', numel(Sbj), numel(sPBR), numel(sBSD));
end
if ~isscalar(elapsedSeconds) || ~isreal(elapsedSeconds) || elapsedSeconds < 0
    error('mac:slLcpBucket:badElapsed', 'slLcpBucket: elapsedSeconds must be a real scalar >= 0, got %s', num2str(elapsedSeconds));
end
if any(sPBR < 0) || any(sBSD < 0)
    error('mac:slLcpBucket:badConfig', 'slLcpBucket: sPBR and sBSD must be nonnegative');
end
if any(isinf(sBSD))
    error('mac:slLcpBucket:badConfig', 'slLcpBucket: sBSD must be finite (sl-BucketSizeDuration is a duration); only sPBR may be infinite');
end

bucketSize = sPBR .* sBSD;   % clause 5.22.1.4.1.1: "the sidelink bucket size (i.e. sPBR x sBSD)"
for j = 1:numel(Sbj)
    if isinf(sPBR(j))
        % An infinite-rate bucket is always at its (infinite) size; accumulating Inf*0 would be
        % NaN and would silently corrupt every later SBj > 0 test.
        Sbj(j) = bucketSize(j);
        continue;
    end
    Sbj(j) = Sbj(j) + sPBR(j) * elapsedSeconds;
    if Sbj(j) > bucketSize(j)
        Sbj(j) = bucketSize(j);
    end
end
end
