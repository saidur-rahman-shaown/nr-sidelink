function idx = reservationPeriodIndex(periodMs, periodList)
%reservationPeriodIndex Index into sl-ResourceReservePeriodList for a given reservation period.
%Spec:   TS 38.213 V16.17.0, clause 16.4
%Inputs: periodMs    real scalar, ms -- the reservation period provided by higher layers (TS
%                    38.321), the value to look up
%        periodList  vector, real, ms -- the pool's sl-ResourceReservePeriodList values,
%                    already resolved to ms (e.g. +cfg/resourcePool.m's
%                    sl_ResourceReservePeriod_ms fields), in list order
%Outputs: idx  nonnegative integer, 0-based -- the list index matching periodMs; feeds
%             sci1aPack's dynamicParams.reservationPeriodIndex
match = find(periodList(:) == periodMs, 1) - 1;
if isempty(match)
    error('ts38213:reservationPeriodIndex:notFound', 'reservationPeriodIndex: periodMs=%g does not match any entry in periodList', periodMs);
end
idx = match;
end
