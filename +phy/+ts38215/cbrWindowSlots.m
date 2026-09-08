function a = cbrWindowSlots(timeWindowSizeCBR, mu)
%cbrWindowSlots CBR measurement window length a, in slots.
%Spec:   TS 38.215 V16.7.0, clause 5.1.27: SL CBR is measured "over a CBR measurement window
%        [n-a, n-1], wherein a is equal to 100 or 100*2^mu slots, according to higher layer
%        parameter sl-TimeWindowSizeCBR".
%Inputs: timeWindowSizeCBR  char row vector, 'ms100' or 'slot100' -- sl-TimeWindowSizeCBR-r16
%                           (TS 38.331 V16.22.0, ENUMERATED {ms100, slot100}), as resolved by
%                           +cfg/private/resolveEnum.m, which deliberately keeps the label
%                           rather than a number because "units differ per label (ms vs slot)"
%                           and only this package knows the numerology to resolve it with.
%        mu                 integer, 0..3 -- mu_SL, the SCS configuration of the SL BWP. Used
%                           ONLY by the 'ms100' branch.
%Outputs: a  positive integer, slots -- the window length; the window is the CLOSED slot range
%            [n-a, n-1], i.e. a slots ENDING AT n-1, and does NOT include slot n itself.
%
%The two labels are not two spellings of one thing. 'slot100' is literally 100 slots regardless
%of numerology; 'ms100' is 100 MILLISECONDS, which is 100*2^mu slots because a slot is 1/2^mu ms
%(TS 38.211 clause 4.3.2). They coincide only at mu=0, so any test written solely at mu=0 is
%blind to a swap between them -- the same numerology-blindness trap +phy/+ts38214/CLAUDE.md
%records for its own Q formula.
if ~ischar(timeWindowSizeCBR) || ~isrow(timeWindowSizeCBR)
    error('ts38215:cbrWindowSlots:badLabel', 'cbrWindowSlots: timeWindowSizeCBR must be a char row vector, ''ms100'' or ''slot100''');
end
if ~(mu >= 0 && mu <= 3 && mod(mu, 1) == 0)
    error('ts38215:cbrWindowSlots:badMu', 'cbrWindowSlots: mu must be an integer in 0..3, got %s', num2str(mu));
end
baseSlots = 100;   % clause 5.1.27's "100 or 100*2^mu"; also the numeric part of both enum labels
switch timeWindowSizeCBR
    case 'slot100'
        a = baseSlots;
    case 'ms100'
        a = baseSlots * 2^mu;
    otherwise
        error('ts38215:cbrWindowSlots:badLabel', 'cbrWindowSlots: timeWindowSizeCBR must be ''ms100'' or ''slot100'' (sl-TimeWindowSizeCBR-r16), got ''%s''', timeWindowSizeCBR);
end
end
