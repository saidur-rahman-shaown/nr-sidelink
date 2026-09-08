function [crRatio, nUsed, nConfigured] = cr(subchUsedPast, subchGrantedFuture, numSubchannel, a, b, windowSlotsTotal)
%cr Sidelink channel occupancy ratio (SL CR).
%Spec:   TS 38.215 V16.7.0, clause 5.1.26: "Sidelink Channel Occupancy Ratio (SL CR) evaluated
%        at slot n is defined as the total number of sub-channels used for its transmissions in
%        slots [n-a, n-1] and granted in slots [n, n+b] divided by the total number of
%        configured sub-channels in the transmission pool over [n-a, n+b]."
%Inputs: subchUsedPast       nonnegative integer -- the total number of sub-channels the UE
%                            USED FOR ITS OWN TRANSMISSIONS over the past window [n-a, n-1],
%                            summed across slots (a sub-channel occupied in each of 3 slots
%                            counts 3, not 1). "its transmissions" is the UE's own: CR is a
%                            self-occupancy measure, which is exactly what makes it different
%                            from CBR. Counting other UEs' transmissions here inflates CR and
%                            throttles the UE against traffic that is not its own.
%        subchGrantedFuture  nonnegative integer -- the total number of sub-channels GRANTED
%                            over [n, n+b], INCLUDING slot n itself, summed the same way.
%                            NOTE 6: "A resource is considered granted if it is a member of a
%                            selected sidelink grant as defined in TS 38.321" -- so the grant
%                            set comes from +mac/, not from this package. NOTE 3: "the UE shall
%                            assume the transmission parameter used at slot n is reused
%                            according to the existing grant(s) in slot [n+1, n+b] without
%                            packet dropping", i.e. the future half is a projection of the
%                            current grant, not a prediction; producing it is the caller's job.
%        numSubchannel       integer, >=1 -- sl-NumSubchannel, the configured sub-channels of
%                            the transmission pool
%        a                   integer, >=1 -- past window length. Clause 5.1.26 NOTE 1: "a is a
%                            positive integer [...] determined by UE implementation".
%        b                   integer, >=0 -- future window length. NOTE 1: "b is 0 or a positive
%                            integer [...] determined by UE implementation", subject to
%                            b < (a+b+1)/2, asserted below.
%        windowSlotsTotal    positive integer, slots -- the a+b+1 total NOTE 1 requires the
%                            chosen split to sum to, from crWindowSlots(sl-TimeWindowSizeCR, mu).
%                            Passed in rather than derived because only the caller holds the
%                            config and the numerology; asserted here so that NOTE 1's window-
%                            size constraint is actually enforced somewhere. An independent-
%                            verifier pass caught that an earlier version of this function
%                            checked a, b and b<(a+b+1)/2 but silently accepted any window
%                            length at all, which would let a scaled-down test fixture (a=8,
%                            b=1, total 10) pass as though it were a conformant configuration.
%Outputs: crRatio      real, >=0 -- the occupancy ratio. Normally in [0,1]; it is NOT clamped,
%                      because a value above 1 means the caller double-counted sub-channels and
%                      should see that rather than have it hidden. TS 38.331 quantises the
%                      configured LIMIT (sl-CR-Limit) to [0,1] in steps of 0.0001.
%         nUsed        nonnegative integer -- the numerator, subchUsedPast + subchGrantedFuture
%         nConfigured  positive integer -- the denominator, numSubchannel*(a+b+1)
%
%The window is [n-a, n+b] INCLUSIVE at both ends, so it spans a+b+1 slots, not a+b. Slot n is
%counted once, on the GRANTED side (the clause splits at "[n-a, n-1]" used and "[n, n+b]"
%granted, so n belongs to the future half) -- a caller that also counts slot n in
%subchUsedPast double-counts it.
%
%This function does not choose a and b: NOTE 1 makes them "determined by UE implementation", so
%that is a +phy/+rx/+policy/ decision, the same split +phy/+ts38214/ applies to T1/T2. It does
%validate them fully -- a>=1, b>=0, b<(a+b+1)/2, and a+b+1 == windowSlotsTotal. The one NOTE 1
%constraint it CANNOT check is the last ("n+b shall not exceed the last transmission opportunity
%of the grant for the current transmission"), which needs the grant, not just its size.
%
%Per-priority CR: clause 5.1.26 NOTE 5, "SL CR can be computed per priority level". This
%function is the scalar formula; per-priority CR(i) as TS 38.214 clause 8.1.6 requires is this
%same call made with subchUsedPast/subchGrantedFuture restricted to the transmissions whose SCI
%'Priority' field is i. The loop over i belongs to the caller, which then hands the eight
%results to +phy/+ts38214/congestionControlCheck. Note the denominator does NOT change per
%priority -- it is the whole pool over the whole window in every case -- so the eight CR(i)
%values sum to the UE's total CR, which is what makes clause 8.1.6's sum_{i>=k} CR(i) meaningful.
%
%NOTE 4: "The slot index is based on physical slot index" -- unlike TS 38.214 clause 8.1.4's
%logical pool slots. a and b are therefore counts of PHYSICAL slots here. +phy/CLAUDE.md's
%"logical-to-physical mapping applied exactly once" rule bites at this boundary: a caller
%feeding this function window lengths it derived in logical pool slots is measuring a different
%window than the clause specifies.
if numSubchannel < 1 || mod(numSubchannel, 1) ~= 0
    error('ts38215:cr:badNumSubchannel', 'cr: numSubchannel must be a positive integer (sl-NumSubchannel), got %s', num2str(numSubchannel));
end
if a < 1 || mod(a, 1) ~= 0
    error('ts38215:cr:badA', 'cr: a must be a positive integer (clause 5.1.26 NOTE 1), got %s', num2str(a));
end
if b < 0 || mod(b, 1) ~= 0
    error('ts38215:cr:badB', 'cr: b must be 0 or a positive integer (clause 5.1.26 NOTE 1), got %s', num2str(b));
end
if subchUsedPast < 0 || mod(subchUsedPast, 1) ~= 0
    error('ts38215:cr:badUsed', 'cr: subchUsedPast must be a nonnegative integer, got %s', num2str(subchUsedPast));
end
if subchGrantedFuture < 0 || mod(subchGrantedFuture, 1) ~= 0
    error('ts38215:cr:badGranted', 'cr: subchGrantedFuture must be a nonnegative integer, got %s', num2str(subchGrantedFuture));
end

if windowSlotsTotal < 1 || mod(windowSlotsTotal, 1) ~= 0
    error('ts38215:cr:badWindowTotal', 'cr: windowSlotsTotal must be a positive integer (from crWindowSlots), got %s', num2str(windowSlotsTotal));
end

windowSlots = a + b + 1;   % clause 5.1.26: [n-a, n+b] inclusive at both ends
if windowSlots ~= windowSlotsTotal
    error('ts38215:cr:badWindowTotal', 'cr: clause 5.1.26 NOTE 1 requires a+b+1 to equal the sl-TimeWindowSizeCR total, got a=%d, b=%d (a+b+1=%d) against windowSlotsTotal=%d', a, b, windowSlots, windowSlotsTotal);
end
if ~(b < windowSlots / 2)
    error('ts38215:cr:badSplit', 'cr: clause 5.1.26 NOTE 1 requires b < (a+b+1)/2, got b=%d and a+b+1=%d', b, windowSlots);
end

nUsed = subchUsedPast + subchGrantedFuture;
nConfigured = numSubchannel * windowSlots;
crRatio = nUsed / nConfigured;
end
