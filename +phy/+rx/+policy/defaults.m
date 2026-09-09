function p = defaults()
%defaults Default UE-implementation choices for Mode-2 resource selection.
%Spec:   none, deliberately. Every field below is a quantity TS 38.214 clause 8.1.4 or
%        TS 38.321 clause 5.22.1.1 leaves to UE implementation, which is exactly why it lives
%        in +phy/+rx/+policy/ and not in a spec-named package. Nothing normative reads this
%        function; the values travel into +phy/+ts38214/ and +mac/ as ordinary inputs.
%Inputs: none
%Outputs: p  scalar struct, the policy constants:
%   .LsubCH          integer, >=1 -- L_subCH, contiguous sub-channels per candidate resource.
%                    Default 2. This SHOULD be derived from the MAC PDU size via
%                    phy.ts38214.tbsDetermine inverted against the pool's sub-channel size;
%                    that module does not exist yet, so a constant stands in. Two sub-channels
%                    of the usual 10 PRB carry a ~300-byte CAM at the default MCS with margin.
%   .mcs             integer, 0..31 -- I_MCS for PSSCH. Default 7: QPSK in every one of
%                    clause 8.1.3.1's selectable tables. Broadcast sidelink has no CSI
%                    feedback, so the MCS cannot track the channel and must instead close the
%                    link at the range the KPI is measured over; QPSK at roughly half rate is
%                    the conventional operating point for that.
%   .prsvpTxMs       real, >=0 -- P_rsvp_TX, the reservation period in ms. Default 100, which
%                    matches both the nominal CAM generation period and the P value that
%                    +mac/creselCounterRange's clause 5.22.1.1 draw range is written around.
%                    0 selects aperiodic transmission (and then Cresel must be 1).
%   .numRetx         integer, >=0 -- blind retransmissions per MAC PDU, in addition to the
%                    initial transmission. Default 1 (so two transmissions in total). With
%                    HARQ feedback disabled, which is the broadcast case, blind repetition is
%                    the only diversity available.
%   .maxEscalations  positive integer -- safety bound handed to phy.ts38214.candidateSet for
%                    its clause 8.1.4 step 7 loop. Default 10. Not a spec quantity: the loop
%                    provably converges, and this turns a logic defect into an error rather
%                    than a hang.
%
%Changing a value here changes the experiment, not the compliance. That is the point: this is
%the surface an optimisation algorithm replaces, and every consumer takes these as arguments
%so a replacement needs no edit anywhere else.

p = struct( ...
    'LsubCH',         2, ...
    'mcs',            7, ...
    'prsvpTxMs',      100, ...
    'numRetx',        1, ...
    'maxEscalations', 10);
end
