function k = defaults()
%defaults The UE-implementation choices the access-stratum stack needs, in one place.
%Spec:   none, deliberately. Each value is one the specifications leave to the UE, cited where
%        the spec says so. None of them is a configuration field: everything a network or
%        preconfiguration decides comes from the stored config through stack.poolGeometry and
%        stack.ueInit, never from here.
%Outputs: k  scalar struct:
%   .tReorderingMs      PDCP t-Reordering for a bearer over RLC UM, ms. TS 38.323 clause 7.3:
%                       "For NR sidelink communication, the t-Reordering timer is determined by
%                       the UE implementation." It only has to cover HARQ-level reordering.
%   .tReorderingAmMs    PDCP t-Reordering for a bearer over RLC AM, ms. It must outlast RLC ARQ
%                       recovery: NR RLC AM delivers out of order, so PDCP is what waits for the
%                       retransmitted SDU, and a timer shorter than the ARQ loop gives up on the
%                       gap, delivers the SDUs after it, and then DISCARDS the recovered SDU as
%                       COUNT < RX_DELIV. Found by the first end-to-end AM loss test: with 10 ms
%                       on both, every lost unicast packet was recovered by RLC and thrown away
%                       by PDCP.
%   .tReassemblyLbl     RLC t-Reassembly, a T-Reassembly label. TS 38.331 clause 9.1.1.4/9.1.1.5:
%                       "Selected by the receiving UE, up to UE implementation."
%   .tStatusProhibitLbl RLC t-StatusProhibit label, same source as t-Reassembly.
%   .sduType            PDCP SDU Type, 1 = Non-IP (TS 38.323 Table 6.3.12-1): V2X messages.
%   .mcs                I_MCS for PSSCH. Mode 2 leaves MCS to the UE within sl-MinMaxMCS-List
%                       (absent in the stored config). 7 = QPSK in every table.
%   .rvSequence         redundancy versions per transmission of a TB (TS 38.321 5.22.1.3.1).
%   .gcbcRxOutOfOrder   PDCP out-of-order delivery at a groupcast/broadcast RECEIVER. The receiver
%                       cannot know the transmitter's SLRB, and TS 38.331 9.1.1.5 leaves its
%                       reordering to the UE ("t-Reordering: Undefined, selected by the receiving
%                       UE"). true = deliver every PDU at once (no head-of-line hold); false =
%                       in-order with t-Reordering. Was hard-coded false, which held the FIRST
%                       packet from every new source for t-Reordering: the window starts below
%                       its SN (TS 38.323 7.1), so it waited 10 ms and missed a 20 ms PDB.
%   .decodeMarginSlots  slots kept free at the end of the PDB for the receiver after the
%                       transmission slot: the last usable slot moves this many earlier. 0 (the
%                       original behaviour) = up to the slot before the PDCP discard deadline;
%                       2 = the study's pipeline (1 slot on the air + 2 to receive, T2 = PDB - 3).
%   .prsvpTxMs          P_rsvp_TX, ms: 0 = a single-MAC-PDU grant per packet (dynamic);
%                       > 0 = sensing-based SPS (TS 38.321 5.22.1.1): one grant for multiple MAC
%                       PDUs, reused every P_rsvp_TX for SL_RESOURCE_RESELECTION_COUNTER periods,
%                       kept with sl-ProbResourceKeep, released after sl-ReselectAfter unused
%                       periods, and announced in SCI-1A. Must be an entry of the pool's
%                       sl-ResourceReservePeriodList with sl-MultiReserveResource enabled.
%   .congestionCapability  UE processing timing capability for congestion control, 1 or 2 (TS 38.214
%                       8.1.6, Tables 8.1.6-1/-2: N, the CBR/CR evaluation lag). One per UE.
%   .reevaluation       run TS 38.321 5.22.1.2a re-evaluation and pre-emption at m - T3 (true), or
%                       not (false: a grant keeps its resources whatever is sensed after selection).
%   .nHarqProcesses     transmitting Sidelink processes, <= 16 for single-MAC-PDU grants.
%   .pCmaxDbm           UE maximum power; phy.ts38213.slPowerControl is max-power by decision.
%   .maxPdbMs           remaining-PDB fallback when an SLRB has no discard timer, ms.
%   .controlPdbMs       the selection deadline for a Destination with ONLY RLC control PDUs
%                       (AM STATUS) pending, ms. A STATUS carries no PDB of its own, but the
%                       peer's ARQ loop waits on it.
%   .listSize, .maxIter polar SCL list size and LDPC iterations at the receiver.
%   .psfchProcSlots     the UE-implementation term of TS 38.321 5.22.1.1's minimum time gap: PSFCH
%                       reception and processing plus retransmission preparation, slots. The
%                       clause's NOTE leaves it to implementation.
%   .psfchThreshold     PSFCH correlation threshold (phy.rx.det.psfchDetect; detection is not
%                       specified -- TS 38.213 16.3.1 defers to TS 38.101-4 performance).
%   .psfchGateDb        energy gate for PSFCH, dB above the thermal noise per RE. The correlator is
%                       normalised to unit energy, so pure noise clears a 0.5 threshold ~5% of the
%                       time; without a gate a DTX (nothing sent) reads as a random ACK or NACK,
%                       and HARQ-based RLF (TS 38.321 5.22.1.3.3) can never be declared.
%   .noiseFigureDb      receiver noise figure for that thermal floor (rf.noiseFloorDbm).
%   .t2MaxMs            cap on the Mode-2 selection-window end T2, ms. TS 38.214 8.1.4 lets the UE
%                       pick T2 anywhere in [T2min, remaining PDB]; phy.rx.policy.selectionWindow
%                       takes the PDB end, and the resource is drawn uniformly in the window, so
%                       the access delay averages ~PDB/2 (50 ms for a 100 ms CAM). A cap pulls T2
%                       toward T2min (never below it: sl-SelectionWindowList is the floor) and
%                       trades collision probability for latency. Inf = no cap.
%   .lcidFirst          first LCID assigned to a new logical channel (TS 38.321 Table 6.2.4-1:
%                       4..19 identify sidelink logical channels; TS 38.331 5.8.9.1a.2.2 "assign a
%                       new LCID to this logical channel").

k = struct( ...
    'tReorderingMs',      10, ...
    'tReorderingAmMs',    1000, ...
    'tReassemblyLbl',     'ms20', ...
    'tStatusProhibitLbl', 'ms0', ...
    'sduType',            1, ...
    'mcs',                7, ...
    'rvSequence',         [0 2 3 1], ...
    'nHarqProcesses',     16, ...
    'pCmaxDbm',           23, ...
    'maxPdbMs',           100, ...
    'controlPdbMs',       10, ...
    'listSize',           8, ...
    'psfchProcSlots',     1, ...
    't2MaxMs',            Inf, ...
    'decodeMarginSlots',  0, ...
    'gcbcRxOutOfOrder',   true, ...
    'prsvpTxMs',          0, ...
    'congestionCapability', 1, ...
    'reevaluation',       true, ...
    'psfchThreshold',     0.5, ...
    'psfchGateDb',        6, ...
    'noiseFigureDb',      9, ...
    'maxIter',            12, ...
    'lcidFirst',          4);
end
