function db = sensingDbMarkUnmonitored(db, slot)
%sensingDbMarkUnmonitored Record that the UE could not sense a slot (half-duplex, own Tx).
%Spec:   TS 38.214 V16.17.0, clause 8.1.4 step 2 ("except for those in which its own
%        transmissions occur"); +phy/CLAUDE.md's slot execution order ("mark unmonitored" for
%        a slot the UE transmits in)
%Inputs: db    struct from sensingDbInit/a prior sensingDbRecord/sensingDbMarkUnmonitored call
%        slot  integer -- logical pool slot the UE transmitted in and therefore did not sense
%Outputs: db  updated struct, slot appended to db.unmonitoredSlot
db.unmonitoredSlot(end+1, 1) = slot;
end
