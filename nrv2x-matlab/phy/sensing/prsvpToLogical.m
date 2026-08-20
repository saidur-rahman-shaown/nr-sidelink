function Pp = prsvpToLogical(Prsvp_ms, slotMap)
%prsvpToLogical Reservation period in logical pool slots.
%SPEC: TS 38.214 8.1.7 — P'_rsvp = ceil( (T'_max / 10240 ms) * P_rsvp ).
%   ceil, not round and not truncation (Plan.md §4.2).

if Prsvp_ms <= 0
    Pp = 0;
    return;
end
Pp = ceil((slotMap.TmaxPrime / 10240) * Prsvp_ms);
end
