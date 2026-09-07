function pRsvpSlots = reservationPeriodToSlots(pRsvpMs, TmaxPrime)
%reservationPeriodToSlots Reservation period converted from milliseconds to logical pool slots.
%Spec:   TS 38.214 V16.17.0, clause 8.1.7
%Inputs: pRsvpMs    real, > 0 -- a resource reservation period in milliseconds (P_rsvp_TX or
%                   P_rsvp_RX); an absent/aperiodic reservation is not a valid input here --
%                   callers branch on presence before calling this
%        TmaxPrime  positive integer -- T'_max, the number of logical slots belonging to the
%                   resource pool within 10240 ms (clause 8, not yet computed anywhere in this
%                   tree -- +phy/+ts38213/CLAUDE.md flags the underlying slotIsInPool/pool
%                   timeline as not built; taken here as a caller-supplied input)
%Outputs: pRsvpSlots  positive integer -- P'_rsvp, the period in logical pool slots; feeds
%                     candidateSet's step 6c overlap projection
if pRsvpMs <= 0
    error('ts38214:reservationPeriodToSlots:badPeriod', 'reservationPeriodToSlots: pRsvpMs must be > 0 (aperiodic reservations are not converted), got %g', pRsvpMs);
end
pRsvpSlots = ceil((TmaxPrime / 10240) * pRsvpMs);
end
