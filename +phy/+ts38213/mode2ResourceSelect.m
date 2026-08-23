function [N, t1, t2, nStart1, nStart2] = mode2ResourceSelect(candidates, y0, NmaxReserve)
%mode2ResourceSelect Select and fold a Mode-2 resource set into TRIV/FRIV encode inputs.
%Spec:   TS 38.213 V16.17.0, clause 16.4 (sidelink resource allocation mode 2 only -- mode 1 is
%        out of scope, see +phy/+ts38213/CLAUDE.md)
%Inputs: candidates   struct array, one entry per candidate resource {R_y} selected by higher
%                     layers (TS 38.321 sensing/Mode-2 selection, not performed here -- this
%                     function only implements clause 16.4's "which of the selected resources
%                     actually get signalled, and what TRIV/FRIV values they fold to" step):
%                       .slotIdx     integer -- y, the logical slot index (TS 38.214 numbering)
%                       .startSubch  integer, >=0 -- the resource's starting sub-channel index
%                     Must include the anchor resource itself (an entry with slotIdx==y0).
%        y0           integer -- the logical slot index where the PSCCH with SCI format 1-A
%                     carrying this reservation is transmitted (the anchor)
%        NmaxReserve  integer, 2 or 3 -- sl-MaxNumPerReserve
%Outputs: N        integer, 1, 2, or 3 -- number of actual resources selected (counts the
%                  anchor itself -- N=3 means the anchor plus two further resources, not three
%                  in addition to it); feeds trivEncode/frivBitWidth
%         t1       integer -- resource-2 time offset from y0; feeds trivEncode. 0 if N==1
%         t2       integer -- resource-3 time offset from y0; feeds trivEncode. 0 if N<3
%         nStart1  integer -- resource-2 starting sub-channel; feeds frivEncode. 0 if N==1
%         nStart2  integer -- resource-3 starting sub-channel; feeds frivEncode. 0 if N<3
%
%Two behaviours the spec leaves genuinely unstated, resolved here by explicit choice rather
%than left to fall out of the code: (1) when N<NmaxReserve, TS 38.214 clause 8.1.5 states the
%unused t/nStart outputs "are not used" -- don't-care, not defined as zero -- 0 is returned
%anyway because trivEncode/frivEncode both already document ignoring these inputs when N makes
%them inapplicable, so 0 never reaches a place that treats it as a real value. (2) candidates
%with slotIdx<y0 are silently excluded by the window condition (slots>=y0) rather than
%erroring -- the clause's selection chain is anchored at y0 and only ever runs upward, so a
%past-slot candidate is simply outside the definition, not an error condition.
allSlots = [candidates.slotIdx];
if ~any(allSlots == y0)
    error('ts38213:mode2ResourceSelect:noAnchor', 'mode2ResourceSelect: candidates must include an entry with slotIdx==y0=%d', y0);
end
slots = sort(allSlots);
inWindow = slots(slots >= y0 & slots <= y0 + 31);
Nselected = numel(inWindow);
N = min(Nselected, NmaxReserve);
selected = inWindow(1:N);

t1 = 0; t2 = 0; nStart1 = 0; nStart2 = 0;
if N >= 2
    t1 = selected(2) - y0;
    nStart1 = candidates(allSlots == selected(2)).startSubch;
end
if N >= 3
    t2 = selected(3) - y0;
    nStart2 = candidates(allSlots == selected(3)).startSubch;
end
end
