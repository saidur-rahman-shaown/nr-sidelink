function p = defaults()
%defaults Default UE-implementation choices for Mode-2 resource selection.
%Spec:   none, deliberately. Every field below is a quantity TS 38.214 clause 8.1.4 or
%        TS 38.321 clause 5.22.1.1 leaves to UE implementation, which is exactly why it lives
%        in +phy/+rx/+policy/ and not in a spec-named package. Nothing normative reads this
%        function; the values travel into +phy/+ts38214/ and +mac/ as ordinary inputs.
%Inputs: none
%Outputs: p  scalar struct, the policy constants:
%   .tbsBytesByLsubCH  1 x numSubchannel integer, bytes -- the transport block size for
%                    L_subCH = 1, 2, ..., numSubchannel **at .mcs**, from
%                    phy.ts38214.tbsDetermine. Empty here and REQUIRED to be filled by the
%                    caller: clause 8.1.3.2 needs a dozen pool parameters this package has no
%                    business holding, and the table is MCS-dependent so it cannot be a
%                    constant either.
%
%   THERE IS NO .LsubCH FIELD, DELIBERATELY.
%   L_subCH is not a policy constant. It is whatever the chosen MCS requires to carry the MAC
%   PDU actually pending, so phy.rx.policy.selectionRequest derives it per selection via
%   phy.rx.policy.subchannelsForTbs and there is no way to supply one blind. An earlier version
%   of this file did carry a default of 2, and it was wrong twice over: a 300-byte CAM at MCS 7
%   needs three sub-channels, not two, and nothing detected the shortfall -- the payload was
%   simply transmitted at the wrong size. A constant here also silently decouples L_subCH from
%   .mcs, so changing the MCS would leave the allocation stale.
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
%   .psfchProcSlots  integer, >=0 -- the UE-implementation half of TS 38.321 clause 5.22.1.1's
%                    minimum time gap: "a time required for PSFCH reception and processing plus
%                    sidelink retransmission preparation including multiplexing of necessary
%                    physical channels and any TX-RX/RX-TX switching time". The clause's own
%                    NOTE leaves it to implementation, so it is a knob rather than a constant.
%                    Default 1 slot -- the smallest non-zero value, and therefore deliberately
%                    OPTIMISTIC: a real UE needs longer, and a longer value pushes
%                    retransmissions further out and lengthens the latency tail.
%   .maxEscalations  positive integer -- safety bound handed to phy.ts38214.candidateSet for
%                    its clause 8.1.4 step 7 loop. Default 10. Not a spec quantity: the loop
%                    provably converges, and this turns a logic defect into an error rather
%                    than a hang.
%
%Changing a value here changes the experiment, not the compliance. That is the point: this is
%the surface an optimisation algorithm replaces, and every consumer takes these as arguments
%so a replacement needs no edit anywhere else.

p = struct( ...
    'tbsBytesByLsubCH', zeros(1, 0), ...
    'mcs',            7, ...
    'prsvpTxMs',      100, ...
    'numRetx',        1, ...
    'psfchProcSlots', 1, ...
    'maxEscalations', 10);
end
