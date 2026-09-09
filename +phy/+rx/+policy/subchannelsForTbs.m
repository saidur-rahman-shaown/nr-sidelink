function LsubCH = subchannelsForTbs(pduBytes, tbsBytesByLsubCH)
%subchannelsForTbs Smallest L_subCH whose transport block holds a MAC PDU of this size.
%Spec:   none. TS 38.321 clause 5.22.1.1 says the UE selects "an amount of frequency resources"
%        and leaves the amount to UE implementation, so this is a policy decision and lives
%        here. The transport block sizes it chooses between are clause 8.1.3.2's arithmetic,
%        computed by phy.ts38214.tbsDetermine and passed in.
%Inputs: pduBytes           integer, >=1 -- the MAC PDU to be carried, INCLUDING subheaders
%        tbsBytesByLsubCH   1 x numSubchannel integer -- transport block size in bytes for
%                           L_subCH = 1, 2, ..., numSubchannel, at the chosen MCS. Passed in
%                           rather than computed here because clause 8.1.3.2 needs a dozen pool
%                           parameters this package has no business holding
%Outputs: LsubCH  integer, 1..numSubchannel -- the smallest allocation that fits
%
%SMALLEST THAT FITS, WHICH IS A POLICY AND NOT THE ONLY ONE
%-----------------------------------------------------------
%Occupying the least spectrum leaves the most for other UEs and lowers the collision
%probability for everyone -- the right default in a shared pool with no coordination. The
%alternative, a larger allocation at the same MCS, buys a lower effective code rate and so
%better range for this UE at everyone else's expense. Which wins depends on load, and that is
%measurable rather than obvious, so it is a knob here rather than a constant elsewhere.
%
%This closes the gap +phy/+rx/+policy/CLAUDE.md recorded: `defaults.LsubCH` was a constant
%standing in for exactly this arithmetic, and a payload too large for it was not detected --
%it was simply transmitted at the wrong size.

if ~(pduBytes >= 1 && mod(pduBytes, 1) == 0)
    error('policy:subchannelsForTbs:badPdu', 'subchannelsForTbs: pduBytes must be a positive integer, got %s', num2str(pduBytes));
end
if isempty(tbsBytesByLsubCH) || ~isrow(tbsBytesByLsubCH)
    error('policy:subchannelsForTbs:badTable', 'subchannelsForTbs: tbsBytesByLsubCH must be a non-empty row vector');
end
if any(diff(tbsBytesByLsubCH) < 0)
    error('policy:subchannelsForTbs:notMonotone', 'subchannelsForTbs: transport block size must not shrink as L_subCH grows; got %s', mat2str(tbsBytesByLsubCH));
end

LsubCH = find(tbsBytesByLsubCH >= pduBytes, 1);
if isempty(LsubCH)
    error('policy:subchannelsForTbs:doesNotFit', 'subchannelsForTbs: a %d-byte MAC PDU does not fit even the largest allocation (%d bytes at L_subCH = %d); lower the payload, raise the MCS, or widen the pool', pduBytes, tbsBytesByLsubCH(end), numel(tbsBytesByLsubCH));
end
end
