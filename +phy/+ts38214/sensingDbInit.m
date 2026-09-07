function db = sensingDbInit()
%sensingDbInit Create an empty sensing database.
%Spec:   TS 38.214 V16.17.0, clause 8.1.4 step 2 (structure only; no formula)
%Outputs: db  scalar struct, struct-of-parallel-arrays, all fields initially empty columns:
%             .slot                      logical pool slot index of each decoded SCI-1A record
%             .startSubch                starting sub-channel (x) of that record's anchor
%                                         resource (the resource in the slot the SCI was
%                                         received in)
%             .lSubch                    L_subCH, contiguous sub-channels of the reservation
%                                         (shared by the anchor and any chained resources)
%             .priority                  prio_RX, 1..8
%             .rsrp                      measured SL-RSRP, dBm (variant per sl-RS-ForSensing;
%                                         which variant was used is the caller's concern, not
%                                         recorded here)
%             .reservationPeriodPresent  logical -- whether SCI's 'Resource reservation
%                                         period' field was present
%             .reservationPeriodMs       P_rsvp_RX, ms (valid only where
%                                         reservationPeriodPresent is true)
%             .chainedCount              0, 1, or 2 -- number of additional TS 38.214 clause
%                                         8.1.5 TRIV/FRIV-chained resources beyond the anchor
%                                         (N-1, where N is the TRIV-decoded resource count)
%             .chainedSlot1/.chainedStart1   2nd resource's (slot, start sub-channel); valid
%                                             only where chainedCount>=1
%             .chainedSlot2/.chainedStart2   3rd resource's (slot, start sub-channel); valid
%                                             only where chainedCount>=2
%             .unmonitoredSlot           logical pool slot indices the UE could not sense
%                                         (own-Tx slots; half-duplex)
%
%Field width is fixed at "anchor + up to 2 chained resources" rather than a cell array or
%ragged list, because sl-MaxNumPerReserve is at most 3 (TS 38.331) -- see +phy/+ts38214/
%CLAUDE.md and the normative-packages rule against cell arrays/dynamic shapes on an interface.
db.slot = zeros(0, 1);
db.startSubch = zeros(0, 1);
db.lSubch = zeros(0, 1);
db.priority = zeros(0, 1);
db.rsrp = zeros(0, 1);
db.reservationPeriodPresent = false(0, 1);
db.reservationPeriodMs = zeros(0, 1);
db.chainedCount = zeros(0, 1);
db.chainedSlot1 = zeros(0, 1);
db.chainedStart1 = zeros(0, 1);
db.chainedSlot2 = zeros(0, 1);
db.chainedStart2 = zeros(0, 1);
db.unmonitoredSlot = zeros(0, 1);
end
