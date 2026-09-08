function total = crWindowSlots(timeWindowSizeCR, mu)
%crWindowSlots Total CR evaluation window length a+b+1, in slots.
%Spec:   TS 38.215 V16.7.0, clause 5.1.26 NOTE 1: "a is a positive integer and b is 0 or a
%        positive integer; a and b are determined by UE implementation with a+b+1 = 1000 or
%        1000*2^mu slots, according to higher layer parameter sl-TimeWindowSizeCR, b <
%        (a+b+1)/2, and n+b shall not exceed the last transmission opportunity of the grant for
%        the current transmission."
%Inputs: timeWindowSizeCR  char row vector, 'ms1000' or 'slot1000' -- sl-TimeWindowSizeCR-r16
%                          (TS 38.331 V16.22.0, ENUMERATED {ms1000, slot1000}), as resolved by
%                          +cfg/private/resolveEnum.m (label kept, not a number, because the
%                          units differ per label)
%        mu                integer, 0..3 -- mu_SL. Used ONLY by the 'ms1000' branch.
%Outputs: total  positive integer, slots -- a+b+1, the TOTAL span of the CR window
%                [n-a, n+b] INCLUDING slot n. This is a constraint on the split, not the split
%                itself: how the caller divides it into a (past) and b (future) is explicitly
%                "determined by UE implementation", so choosing them is a +phy/+rx/+policy/
%                decision, the same split +phy/+ts38214/ applies to T1/T2. cr() validates a
%                chosen (a,b) pair against this total and against b < (a+b+1)/2; it does not
%                choose one either.
%
%As with cbrWindowSlots, 'slot1000' is literally 1000 slots and 'ms1000' is 1000 milliseconds =
%1000*2^mu slots; they coincide only at mu=0.
%
%DISAGREEMENT ON RECORD, resolved in favour of the mapping implemented here. The
%independent-verifier pass over this clause read the correspondence the other way round --
%'ms1000' -> 1000 slots, 'slot1000' -> 1000*2^mu -- and flagged its own reading as an
%inference, noting that NOTE 1 "does not name the enumerands explicitly" (it says only "1000 or
%1000*2^mu slots, according to higher layer parameter sl-TimeWindowSizeCR"). Per +test/CLAUDE.md
%the disagreement is reported rather than harmonised away, and it is resolved here on grounds
%the verifier's own sentence undermines itself on: it glossed 'ms1000' as "1000 slots' worth of
%1 ms, i.e. the literal value 1000", which holds only at mu=0, the one numerology where the two
%enumerands coincide and the question is moot. Dimensionally the labels name the UNIT of the
%window they configure -- 'ms1000' is 1000 MILLISECONDS, and a slot lasts 1/2^mu ms
%(TS 38.211 clause 4.3.2), so 1000 ms IS 1000*2^mu slots; 'slot1000' already counts slots and
%needs no conversion. The same argument applies to cbrWindowSlots' 'ms100'/'slot100'. This is
%flagged `pending-human` in +phy/+ts38215/CLAUDE.md: it is a two-way choice with no explicit
%normative sentence behind either side, and getting it backwards scales every CR window by
%2^mu.
if ~ischar(timeWindowSizeCR) || ~isrow(timeWindowSizeCR)
    error('ts38215:crWindowSlots:badLabel', 'crWindowSlots: timeWindowSizeCR must be a char row vector, ''ms1000'' or ''slot1000''');
end
if ~(mu >= 0 && mu <= 3 && mod(mu, 1) == 0)
    error('ts38215:crWindowSlots:badMu', 'crWindowSlots: mu must be an integer in 0..3, got %s', num2str(mu));
end
baseSlots = 1000;   % clause 5.1.26 NOTE 1's "1000 or 1000*2^mu"; also both labels' numeric part
switch timeWindowSizeCR
    case 'slot1000'
        total = baseSlots;
    case 'ms1000'
        total = baseSlots * 2^mu;
    otherwise
        error('ts38215:crWindowSlots:badLabel', 'crWindowSlots: timeWindowSizeCR must be ''ms1000'' or ''slot1000'' (sl-TimeWindowSizeCR-r16), got ''%s''', timeWindowSizeCR);
end
end
