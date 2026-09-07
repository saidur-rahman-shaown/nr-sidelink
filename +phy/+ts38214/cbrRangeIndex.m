function level = cbrRangeIndex(cbr, cbrRangeUpperBounds)
%cbrRangeIndex CBR range (level) containing a measured CBR.
%Spec:   TS 38.214 V16.17.0, clause 8.1.6 -- CR_limit(k) is the sl-CR-Limit "associated with
%        the priority value k and the CBR range which includes the CBR measured in slot n-N".
%        This function resolves the "which CBR range includes it" half of that sentence; the
%        priority half, and the sl-CBR-PriorityTxConfigList -> sl-Tx-ConfigIndexList ->
%        sl-CBR-PSSCH-TxConfigList indirection that turns (level, k) into an actual sl-CR-Limit
%        value, is +cfg/ machinery that is not built (see congestionControlCheck's header).
%        Range semantics from TS 38.331 V16.22.0, SL-CBR-CommonTxConfigList field description
%        for sl-CBR-RangeConfigList: "Each entry of the list indicates in SL-CBR-LevelsConfig
%        the upper bound of the CBR range for the respective entry. The upper bounds of the CBR
%        ranges are configured in ascending order [...] For the first entry [...] the lower
%        bound of the CBR range is 0."
%Inputs: cbr                 real, 0<=cbr<=1 -- the CBR measured in slot n-N, ALREADY RESOLVED
%                            from the raw SL-CBR-r16 INTEGER(0..100) to a ratio (TS 38.331:
%                            "Value 0 corresponds to 0, value 1 to 0.01, value 2 to 0.02, and
%                            so on"). Measuring it is TS 38.215's job (+phy/+ts38215/, not
%                            built) -- taken here as a caller-supplied input, the same
%                            pre-resolved-units pattern candidateSet uses for its RSRP
%                            threshold list.
%        cbrRangeUpperBounds 1 x nLevels row vector, real, each 0<=b<=1, STRICTLY ASCENDING --
%                            ONE SL-CBR-LevelsConfig-r16 entry resolved to ratios, entry j the
%                            inclusive upper bound of level j. Note sl-CBR-RangeConfigList is a
%                            list OF SL-CBR-LevelsConfig (a list of lists); which of its entries
%                            applies is chosen upstream by sl-CBR-ConfigIndex, so that outer
%                            selection is deliberately NOT this function's job. nLevels is
%                            1..maxCBR-Level-r16 (=4 in TS 38.331 Rel-16), but no upper limit is
%                            enforced here: the size constraint belongs to +cfg/, not to this
%                            lookup.
%Outputs: level  integer, 1..nLevels -- the 1-based index of the CBR range containing cbr, i.e.
%                the smallest j with cbr <= cbrRangeUpperBounds(j). Ranges are (b(j-1), b(j)]
%                with b(0)=0, except level 1 which is the closed [0, b(1)] so that cbr=0 has a
%                range (the field description fixes the first lower bound at 0, inclusive).
%
%The upper-inclusive/lower-exclusive partition above is INFERRED, not quoted: TS 38.331's field
%description never uses the words "inclusive" or "exclusive", and never states the lower bound
%of ranges 2..N at all. It is forced by consistency, in three steps: (1) the stated lower bound
%of range 1 is 0, and SL-CBR-r16's "Value 0 corresponds to 0" makes cbr=0 a legal measurement,
%so range 1 must contain its own lower edge; (2) given that, upper bounds inclusive on EVERY
%range would make ranges j and j+1 overlap at the shared point b(j), so the lower edges of
%ranges 2..N must be exclusive; (3) the top end confirms it -- SL-CBR-r16 reaches 100 = 1.00, so
%a configured top bound of 1.0 must be able to classify a measured cbr of exactly 1.0, which
%upper-inclusive achieves and upper-exclusive does not. Independent-verifier confirmed this
%reading and flagged it `pending-human` (the exact-bound cases are the ONLY boundary behaviour a
%real config can produce, since SL-CBR-r16 quantises both cbr and the bounds to multiples of
%0.01 -- so the inclusivity choice is not a corner case, it is 1-in-100 of the input domain).
if ~isvector(cbrRangeUpperBounds) || isempty(cbrRangeUpperBounds)
    error('ts38214:cbrRangeIndex:badBounds', 'cbrRangeIndex: cbrRangeUpperBounds must be a non-empty vector (sl-CBR-RangeConfigList, SIZE(1..maxCBR-Level))');
end
if any(cbrRangeUpperBounds < 0) || any(cbrRangeUpperBounds > 1)
    error('ts38214:cbrRangeIndex:badBounds', 'cbrRangeIndex: every cbrRangeUpperBounds entry must be in [0,1] (SL-CBR-r16 resolved to a ratio)');
end
if any(diff(cbrRangeUpperBounds) <= 0)
    error('ts38214:cbrRangeIndex:notAscending', 'cbrRangeIndex: cbrRangeUpperBounds must be strictly ascending (TS 38.331: sl-CBR-RangeConfigList upper bounds "configured in ascending order")');
end
if ~(cbr >= 0 && cbr <= 1)
    error('ts38214:cbrRangeIndex:badCbr', 'cbrRangeIndex: cbr must be in [0,1], got %s', num2str(cbr));
end

nLevels = numel(cbrRangeUpperBounds);
level = 0;
for j = 1:nLevels
    if cbr <= cbrRangeUpperBounds(j)
        level = j;
        break;
    end
end
if level == 0
    % No configured range includes this CBR. Genuinely undefined: neither clause 8.1.6 nor the
    % TS 38.331 field description says whether to clamp to the top level or treat CR_limit as
    % absent (independent-verifier flagged this as a decision the specs do not make, and it is
    % `pending-human`). Erroring is chosen over clamping because clause 8.1.6 assumes a range
    % always exists for the measured CBR, so a list whose top bound is below 1 is an incomplete
    % configuration -- a +cfg/cfgValidate.m check waiting to be written, not a runtime condition
    % to absorb silently here.
    error('ts38214:cbrRangeIndex:noRange', 'cbrRangeIndex: cbr=%g exceeds the highest configured CBR range upper bound (%g); sl-CBR-RangeConfigList must cover the whole [0,1] CBR domain', cbr, cbrRangeUpperBounds(nLevels));
end
end
