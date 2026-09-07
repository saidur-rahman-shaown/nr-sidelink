function db = sensingDbRecord(db, slot, startSubch, lSubch, priority, rsrp, reservationPeriodPresent, reservationPeriodMs, N, t1, t2, nStart1, nStart2)
%sensingDbRecord Append one decoded SCI-1A observation to the sensing database.
%Spec:   TS 38.214 V16.17.0, clause 8.1.4 step 2 (what is stored); clause 8.1.5 (the N/t1/t2/
%        nStart1/nStart2 resource-chaining fields consumed here)
%Inputs: db                        struct from sensingDbInit/a prior sensingDbRecord/
%                                  sensingDbMarkUnmonitored call
%        slot                      integer -- logical pool slot t'_m the SCI-1A was received in
%        startSubch                integer, >=0 -- x, starting sub-channel of the anchor
%                                  resource (observed directly from the PSCCH's own location,
%                                  clause 8.1.2.2 -- not signalled, so not decoded from FRIV)
%        lSubch                    integer, >=1 -- L_subCH, shared by the anchor and any
%                                  chained resources
%        priority                  integer, 1..8 -- prio_RX, SCI-1A 'Priority' field
%        rsrp                      real, dBm -- measured SL-RSRP for this SCI (clause 8.4.2.1)
%        reservationPeriodPresent  logical scalar -- whether the 'Resource reservation period'
%                                  field was present in this SCI-1A
%        reservationPeriodMs       real -- P_rsvp_RX, ms; ignored if
%                                  reservationPeriodPresent is false
%        N                         integer, 1..3 -- number of actual resources this
%                                  reservation signals, from TS 38.212's trivDecode
%                                  (phy.ts38212.trivDecode) applied to this SCI's TRIV field
%        t1, t2                    integer -- resource-2/3 time offsets from slot, from the
%                                  same trivDecode call (0 where not applicable, i.e. t2 unused
%                                  when N<3)
%        nStart1, nStart2          integer -- resource-2/3 starting sub-channels, from TS
%                                  38.212's frivDecode (phy.ts38212.frivDecode) applied to this
%                                  SCI's FRIV field (0 where not applicable)
%Outputs: db  updated struct, one row appended
if ~(N >= 1 && N <= 3 && mod(N, 1) == 0)
    error('ts38214:sensingDbRecord:badN', 'sensingDbRecord: N must be an integer in 1..3, got %s', num2str(N));
end
if ~(priority >= 1 && priority <= 8 && mod(priority, 1) == 0)
    error('ts38214:sensingDbRecord:badPriority', 'sensingDbRecord: priority must be an integer in 1..8, got %s', num2str(priority));
end

db.slot(end+1, 1) = slot;
db.startSubch(end+1, 1) = startSubch;
db.lSubch(end+1, 1) = lSubch;
db.priority(end+1, 1) = priority;
db.rsrp(end+1, 1) = rsrp;
db.reservationPeriodPresent(end+1, 1) = logical(reservationPeriodPresent);
db.reservationPeriodMs(end+1, 1) = reservationPeriodMs;

chainedCount = N - 1;
db.chainedCount(end+1, 1) = chainedCount;
if chainedCount >= 1
    db.chainedSlot1(end+1, 1) = slot + t1;
    db.chainedStart1(end+1, 1) = nStart1;
else
    db.chainedSlot1(end+1, 1) = 0;
    db.chainedStart1(end+1, 1) = 0;
end
if chainedCount >= 2
    db.chainedSlot2(end+1, 1) = slot + t2;
    db.chainedStart2(end+1, 1) = nStart2;
else
    db.chainedSlot2(end+1, 1) = 0;
    db.chainedStart2(end+1, 1) = 0;
end
end
