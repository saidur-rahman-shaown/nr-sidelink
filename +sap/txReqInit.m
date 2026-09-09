function t = txReqInit()
%txReqInit A zeroed transmission request -- the PHY SAP template.
%Spec:   none as a struct, but every field is a spec quantity; the citations are per-field
%        below. This is TS 38.321 Figure 4.2.2-3's LOWER boundary: what MAC hands to PHY.
%Inputs: none
%Outputs: t  scalar struct with every field present and zeroed. Fill it, then pass it through
%            +sap/txReqValidate before handing it to a PHY.
%
%   TIMING AND RESOURCE
%   .slotPhysical  integer -- the slot in wall-clock DFN numbering. What the harness schedules
%                  on, and what +sap/ context timestamps are measured in.
%   .slotLogical   integer -- the same slot in clause-8 pool numbering. What +phy/+ts38214/
%                  produced when it selected this resource. BOTH are carried deliberately: see
%                  the note below.
%   .startSubch    integer, >=0 -- lowest sub-channel, TS 38.214 clause 8.1.2.2
%   .LsubCH        integer, >=1 -- contiguous sub-channels occupied
%
%   TRANSPORT BLOCK
%   .mcs           integer, 0..31 -- I_MCS, SCI-1A 'Modulation and coding scheme'
%   .tb            logical column vector -- the SL-SCH transport block from +mac/muxSlSch
%   .harqId        integer, 0..15 -- SCI-2 'HARQ process number'
%   .ndi           integer, 0..1  -- SCI-2 'New data indicator'
%   .rv            integer, 0..3  -- SCI-2 'Redundancy version'
%
%   IDENTITY
%   .srcL2Id       integer, 0..2^24-1 -- FULL 24-bit Source Layer-2 ID
%   .dstL2Id       integer, 0..2^24-1 -- FULL 24-bit Destination Layer-2 ID
%   .castType      integer, 0..3 -- +sap/castTypes; TS 38.212 Table 8.4.1.1-1
%
%   CONTROL
%   .prioTx              integer, 1..8 -- SCI-1A 'Priority'. 1 is the HIGHEST
%   .harqFeedbackEnabled integer, 0..1 -- SCI-2 'HARQ feedback enabled/disabled indicator'
%   .csiRequest          integer, 0..1 -- SCI format 2-A only
%
%   SCI-1A RESERVATION FIELDS
%   .prsvpTxIdx    integer, >=0 -- 'Resource reservation period' index, TS 38.213 cl. 16.4
%   .trivIdx       integer, >=0 -- 'Time resource assignment', TS 38.212 cl. 8.3.1.1
%   .frivIdx       integer, >=0 -- 'Frequency resource assignment'
%
%   RF
%   .txPowerDbm    real, dBm -- from +phy/+ts38213/slPowerControl
%
%   KPI
%   .ctxIds        1 x n integer -- the .pktId of every context inside this TB. The only way a
%                  delivery at the receiver can be attributed back to the packets that produced
%                  it, and therefore the only way latency closes.
%
%   WAVEFORM (link-level path only)
%   .waveform      complex column vector, or empty. Empty is the normal case: the
%                  system-level PHY works from the descriptor alone and never builds samples.
%
%WHY THE FULL 24-BIT IDs, NOT THE SCI's TRUNCATED ONES
%-----------------------------------------------------
%SCI format 2-A carries an 8-bit Source ID and a 16-bit Destination ID, which +mac/CLAUDE.md
%records as the LSBs of the respective Layer-2 IDs -- while the MAC subheader carries the
%complementary MSBs. Neither layer alone identifies a peer. The SAP therefore carries the
%complete identifiers and lets the channel chain truncate, so there is one source of truth and
%the truncation happens where the field widths are.
%
%WHY BOTH SLOT NUMBERINGS
%------------------------
%A resource is selected in logical pool slots and transmitted in wall-clock time, and the
%conversion is not a scaling -- see +phy/+ts38214/poolSlotMap. Carrying both, converted once by
%the caller, means no consumer has to hold the map, and a mismatch between them is checkable
%(+sap/txReqValidate does not check it, since it has no map; the harness does).
%
%ON BROADCAST AND HARQ FEEDBACK
%-------------------------------
%A broadcast transmission conventionally has .harqFeedbackEnabled = 0, but this struct does NOT
%assert it. TS 38.214 clause 8.1 says only that "the UE shall set value of the 'Cast type
%indicator' field as indicated by higher layers", and no clause read here forbids the
%combination. Asserting a convention as a rule is the mistake +mac/CLAUDE.md records the test
%suite making with the first NDI value; the scenario decides this, not the SAP.

t = struct( ...
    'slotPhysical',        0, ...
    'slotLogical',         0, ...
    'startSubch',          0, ...
    'LsubCH',              1, ...
    'mcs',                 0, ...
    'tb',                  false(0, 1), ...
    'harqId',              0, ...
    'ndi',                 0, ...
    'rv',                  0, ...
    'srcL2Id',             0, ...
    'dstL2Id',             0, ...
    'castType',            0, ...
    'prioTx',              1, ...
    'harqFeedbackEnabled', 0, ...
    'csiRequest',          0, ...
    'prsvpTxIdx',          0, ...
    'trivIdx',             0, ...
    'frivIdx',             0, ...
    'txPowerDbm',          0, ...
    'ctxIds',              zeros(1, 0), ...
    'waveform',            complex(zeros(0, 1)));
end
