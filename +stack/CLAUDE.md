# Stack (non-normative) — one UE's sidelink access stratum, application packet to IQ and back

## Status: built and tested (`test.runStackTests`, about 10 s for the end-to-end test).
Every layer of the user plane on real bytes and a real waveform, configured **only** from the
stored JSON (`+cfg/configs/preconfig_example.json` via `cfg.loadConfig`). Nothing here is
normative: it composes the normative packages and makes the choices the specs leave to the UE.
Those choices are all in `stack.defaults`, each with the clause that leaves it open.

Not wired into `+harness/+sls/`, whose system-level path is still abstracted (zero-filled
payloads, no PDCP/SDAP). It **is** the UE of `+harness/+field/`: N UEs, real traffic, a real
path-loss + fading channel (`runField`, `FIELD.md`).

## The pipeline, transmit side (`stack.appSend` + `stack.txSlot`)

| # | Layer | What happens | Module(s) | Config it reads |
|---|---|---|---|---|
| 1 | Application | V2X message with its **PQI**, PFI, destination L2 ID, cast type | caller | — |
| 2 | SDAP | PQI + cast → **SLRB**; 1-byte header D/C·R·QFI | `sdap.sdapTxMap`, `sdapPduPack` | `sl-SDAP-Config` (mapped PQIs, default, header) |
| 3 | PDCP | COUNT, SN, discardTimer started (= the PDB), 2-byte (gc/bc) or 4/5-byte (unicast) header | `pdcp.pdcpTxSdu` | `sl-PDCP-Config` (SN size, discard timer, out-of-order) |
| 4 | RLC | SDU into the UM or AM transmission buffer, tagged with the PDCP COUNT | `rlc.umTxEnqueue` / `amTxEnqueue` | `sl-RLC-Config` (mode, SN length, AM polling/retx) |
| 5 | MAC: timers | PDCP discard expiries handed to RLC (dropped only if unsent); AM t-PollRetransmit, t-Reassembly | `pdcp.pdcpTxTimer`, `rlc.*Discard`, `rlc.amTxTimer` | — |
| 6 | MAC: selection | one dynamic grant per Destination with data: window [n+T1, n+T2], T2 ≤ remaining PDB, S_A from sensing, initial + chained retransmission resources | `phy.rx.policy.selectionRequest`, `phy.ts38214.candidateSet`, `phy.rx.policy.resourcePickChained` | pool: sensing window, selection windows, RSRP thresholds, tx percentage, sl-MaxNumPerReserve |
| 7 | MAC: LCP | buckets SBj, allocation across the Destination's logical channels by `sl-Priority` | `mac.slLcpBucket`, `mac.slLcp` | `sl-MAC-LogicalChannelConfig` (priority, PBR, BSD) |
| 8 | RLC build | each channel fills its allocation: segment, SN, SO, poll bit; AM STATUS first | `rlc.umTxBuild`, `rlc.amTxOpportunity` | — |
| 9 | MAC PDU | SL-SCH subheader (SRC 16 MSB, DST 8 MSB), R/F/LCID/L subheaders, padding to the TBS | `mac.muxSlSch` | TBS from `phy.ts38214.tbsDetermine` at the pool geometry and MCS |
| 10 | HARQ | Sidelink process, NDI toggle, RV sequence; blind retransmission on the chained resources | `mac.harqNewTransmission` / `harqRetransmission` / `harqFlush` | — |
| 11 | SCI | SCI-1A (priority, FRIV, TRIV, DM-RS pattern, β indicator, MCS) and SCI-2A (HARQ id, NDI, RV, SRC 8 LSB, DST 16 LSB, feedback flag, cast) | `phy.ts38212.sci1aPack`, `sci2aPack`, `frivEncode`, `trivEncode` | pool field widths |
| 12 | PSCCH | CRC24C → polar → rate match → scramble (c_init 1010) → QPSK → REs; DM-RS | `phy.chan.pscchTx` | `sl-PSCCH-Config` |
| 13 | PSSCH | N_ID = PSCCH CRC mod 2^16; SCI-2 (polar) + SL-SCH (LDPC) multiplexed, scrambled, modulated; DM-RS at the Table 8.4.1.1.2-1 symbols; mapped around the PSCCH | `stack.pscchCrcNid`, `phy.chan.psschTx`, `phy.ts38211.slPSSCHDMRSTimePattern` | `sl-PSSCH-Config` (DM-RS patterns, β list, scaling) |
| 14 | Slot | AGC symbol = copy of symbol 1 on the allocation; guard symbol empty | `phy.ts38211.slAgcSymbol` | `sl-LengthSymbols`, `sl-StartSymbol` |
| 15 | OFDM | 50 PRB × 14 symbols → 15360 samples at 30.72 MHz (µ = 1) | `phy.lib.ofdmMod` | BWP SCS and size (RIV via `cfg.bwpLocation`) |
| 16 | RF | scaled to the transmit power (23 dBm, max-power policy) | `phy.ts38213.slPowerControl`, `rf.txFrontEnd` | — |

The output of step 16 is the IQ handed to a channel. The receive side, `stack.rxSlot`, runs it
backwards. It does OFDM demodulation, then a **blind** PSCCH search over every sub-channel
start. From the decoded SCI-1A it takes L_subCH (FRIV, `phy.ts38212.frivLsubch`), MCS, DM-RS
pattern and β, and N_ID from the PSCCH CRC. It then does DM-RS channel estimation, ZF
equalisation and PSSCH decode, and records the PSSCH-RSRP sensing entry (`slRsrp`). MAC follows:
interest, receive HARQ with duplicate handling, PDU filter and demux. The two halves of each L2
ID are rejoined. Each MAC SDU goes to its RLC entity by (source, destination, LCID); a gc/bc one
is created on its first PDU. Then RLC reassembly/ARQ, PDCP reordering, SDAP header removal, and
delivery to the application.

## What `test_stack` proves
- Configuration reaches every layer (BWP 50 PRB; PSFCH every slot so l_d 10, DM-RS at 3/8, PSFCH
  on symbol 12; β 1.125; sub-channels).
- **For every PQI the stored config maps (55, 70, 3, 89), the SCI-1A priority decoded from the
  waveform equals the PQI table's priority, and the payload arrives byte-exact with its QFI.**
- Two broadcast flows on two SLRBs share a MAC PDU and are delivered byte-exact. The IQ is
  23 dBm; the grid's guard symbol is empty and its AGC symbol is exact.
- **B9 gate, at waveform level:** UE A runs unicast AM to B alongside broadcast UM. Every copy of
  A's first unicast MAC PDU is lost. RLC AM recovers it through B's STATUS PDUs, and every
  broadcast packet arrives.
- An unsent SDU past its discardTimer is discarded and counted. A flow that maps to no SLRB is
  refused and counted.

## Three things the first end-to-end runs found
1. **LCP asked for one MAC subheader too few per channel.** Every RLC allocation came out 3 bytes
   short, so RLC split each SDU's last 3 bytes into a PDU of their own, stranded until a later
   grant. Symptom: nothing delivered at all. `volumes()` now includes the subheader.
2. **One grant per UE starves a second Destination.** A unicast grant drawn deep into its 200 ms
   window made the 100 ms broadcast flow wait, and its packets expired in PDCP (correctly
   counted, but lost for no radio reason). Now there is one grant per Destination (TS 38.321
   5.22.1.1 allows a grant per Sidelink process), and the UE's own reserved slots are excluded
   from new selections.
3. **PDCP t-Reordering must outlast RLC ARQ on AM bearers.** See `+pdcp/CLAUDE.md`. Also, a
   STATUS-only Destination now gets a short selection deadline (`controlPdbMs`). With the 100 ms
   data fallback, B's first STATUS went out ~170 ms after it was triggered.

## Scope (asserted in `stack.poolGeometry`, not silently assumed)
- Every slot is a pool slot and there is no S-SSB, so logical slot = physical slot. Any other
  pool needs `phy.ts38214.poolSlotMap` threaded through.
- PSFCH period `sl0` or `sl1` (every slot). With sl1, l_d = 14 − guard − 2 PSFCH − gap = 10, and
  the PSFCH RB set and starting sub-channel must make M_PRB,set a multiple of N_subch (asserted).
  Periods 2 and 4 need the PSFCH-slot mapping threaded through and are rejected.
- BWP and pool start at PRB 0 (what `pscchSearch` assumes).
- One transmit pool and one receive pool; MCS fixed by the UE (`stack.defaults.mcs`).
- **SPS is built** (`stack.defaults.prsvpTxMs` > 0, default 0 = one grant per packet): see "SPS"
  below. **Re-evaluation, pre-emption and congestion control are built too**: see "Re-evaluation,
  pre-emption, congestion control" below.
- Feedback is ACK/NACK unicast only. Groupcast NACK-only needs SCI-2B zone/range, not sent.
- Sync is ideal and the receiver is time aligned. There is no channel model in this package:
  tests add a small AWGN floor, and `+harness/+field/` supplies the real one.

## Not modelled, and why it is not "data transmission AS"
- **PC5-S (TS 24.587)** is NAS-level link-management signalling and has no local PDF.
  **PC5-RRC** (`RRCReconfigurationSidelink`) carries configuration, not user data.
  `stack.unicastSetup` sets up their outcome directly: matching AM entities on matching LCIDs at
  both UEs.
- Security (TS 33.536), ROHC, CSI reporting, power control beyond max power, S-SSB/PSBCH
  transmission in this chain.

## HARQ feedback (unicast), soft combining, half duplex
- **Feedback is requested by the MAC PDU, not the bearer.** A PDU requests it iff any logical
  channel in it has `sl-HARQ-FeedbackEnabled`. Such a grant's resources are spaced by the PSFCH
  minimum gap (`phy.rx.policy.minResourceGapSlots`), so a retransmission can follow the feedback
  for the transmission before it. The process stays busy until its last PSFCH resolves.
- **The PSFCH a transmitter waits on** (`ue.psfchWait`) and **the PSFCH a receiver owes**
  (`ue.psfchOut`) are a slot, a PRB and an m0 from TS 38.213 16.3 (`stack.psfchResourceFor`):
  P_ID = the SCI-2 Source ID, M_ID = 0. Feedback is owed on the SCI decode. A NACK means "SCI
  seen, TB not decoded"; a repeat of a TB already decoded is ACKed (`harqRxDuplicateFeedback`).
- **Silence is DTX, and an energy gate makes it so.** `phy.rx.det.psfchDetect` is scale-free, so
  pure noise correlates as some ACK or NACK. `rxSlot` gates on `psfchGateDb` (6 dB) above the
  thermal floor per RE before believing either. DTX counts toward `sl-MaxNumConsecutiveDTX` (RLF).
- **Combining is real** (`stack.harqCombineDecode`): each RV is rate-recovered into its
  circular-buffer positions and summed per receive process (`ue.rxSoft`). RV 2 alone after a
  lost RV 0 usually fails. Measured: at −4/−3 dB the combined retransmission rescues the TB.
- **Half duplex is per channel.** Sending PSSCH blocks PSSCH reception in that slot but not PSFCH
  (different symbols). Sending PSFCH blocks PSFCH reception.

## Found by the field run (`+harness/+field/`), invisible with two UEs
1. **`pdbNotMet` (TS 38.321 5.22.1.2).** CAM and DENM share the broadcast Destination and so one
   grant. A DENM (20 ms) arriving behind a CAM's grant drawn up to 100 ms out was late or
   discarded. `selectAll` now clears an unused grant whose first resource is at or past the
   remaining PDB, only while more than T_proc,1 remains (`stats.pdbReselect`). A grant whose TB
   is already built does not block: new data gets its own grant and process.
2. **Round-robin HARQ processes.** The lowest free process reused process 1 for every
   Destination. NDI toggles per process, so a Destination's next TB could repeat its last NDI,
   and the receiver (keyed on source, destination, process) discarded it as a duplicate within
   its window. It lost a broadcast packet at 60 dB SNR in the B9 gate test once a second grant
   appeared.
3. **The deadline slot is not usable.** Timers run first in `txSlot`, so a resource in the slot
   where the discard timer expires finds its SDU gone. The remaining PDB in slots is now
   `ceil(Δ/slot) − 1`.
4. **Noise per sub-channel at the receiver.** A one-sub-channel collision left confident wrong
   LLRs that combining carried into a clean retransmission. `phySlotRx` now asks
   `phy.rx.ce.dmrsEstimate` for noise plus interference per sub-channel.

## SPS (sensing-based semi-persistent scheduling), TS 38.321 5.22.1.1
`k.prsvpTxMs` > 0 makes every selection a grant for multiple MAC PDUs, driven by the normative MAC
state machine the SLS uses (`mac.grantSelect`, `grantOnTransmission`, `grantOnPeriodEnd`,
`keepDecision`, `grantOnKeep`):
- selection draws SL_RESOURCE_RESELECTION_COUNTER and asks `candidateSet` with C_resel = 10 x it,
  so resources whose future periods would collide with a sensed reservation are excluded;
- each period builds a new MAC PDU on its first resource (a new HARQ process), with blind
  retransmissions on its chained resources; a period with nothing to send is skipped and counts
  toward `sl-ReselectAfter`;
- at period end the counter is decremented; at 0 the `sl-ProbResourceKeep` draw keeps or releases.
  In the last period the draw is made early so SCI-1A announces 0 ms when the grant will go;
- SCI-1A carries the period (`sl-MultiReserveResource`, now enabled in the stored config) and the
  receiver records it in its sensing database (it was recorded as absent before);
- an SPS grant that can no longer carry the pending data is reselected rather than segmented
  (5.22.1.2), and a grant whose resource was skipped (another grant took the slot) moves on
  (`grantHousekeeping`).
`test_stack` pins it: 6 periodic packets ride one grant, the receiver records the 100 ms
reservation, and every packet gets its retransmission.

## Defects found by the first full-stack run (2026-10-28) -- resolved
1. **SCI-2 did not decode whenever its polar code was punctured or shortened** (E < N): MCS 5,
   9, 11, 16, 20 in the stored pool. `phy.lib.ts38212.polarDecode` passed the mother length N
   where `nrPolarDecode` takes the rate-matched length E, so its frozen set differed from the
   encoder's. Fixed there (all three polar decoders: SCI-1A, SCI-2, PSBCH); `test_chains` now
   round-trips repetition, puncturing and shortening. Since the stack decodes the data only after
   SCI-2, this lost most transport blocks at those MCS.
2. **Not a defect: a retransmission at RV 2 does not decode on its own.** In NR LDPC only RV 0 and
   RV 3 are self-decodable; RV 2 starts half way round the circular buffer and misses the core
   parity. It is meant to be soft-combined, which `harqCombineDecode` does.
3. **An SPS grant could have no retransmission resource for its whole life** when its anchor was
   drawn at the end of the window: `phy.rx.policy.resourcePickChained` looked for chained
   resources only after the anchor. It now looks before it too, within TRIV's 31-slot reach.

4. **MCS 27 never decoded, and every high MCS ran above its nominal code rate**: the PSSCH data
   mapping started at the first DM-RS symbol, so symbols 1-2 outside the PSCCH were left empty while
   the TBS counted them. TS 38.214 8.1.2.1 starts PSSCH at sl-StartSymbol + 1; `slPSSCHIndices` now
   maps SCI-2 from the first DM-RS symbol and data from symbol 1 (effective rate at MCS 27: 0.85-0.87).
   **The BLER tables and Part B curves were measured with the old mapping and are stale.**
5. **The first packet from a new gc/bc source missed a 20 ms PDB by 1.5 ms**: the gc/bc receiver's
   PDCP was hard-coded in-order, so the first PDU waited t-Reordering (10 ms) because the receive
   window starts below its SN (TS 38.323 7.1). TS 38.331 9.1.1.5 leaves the receiver's reordering to
   the UE; `stack.defaults.gcbcRxOutOfOrder` (default true) delivers at once, and the stored config
   sets sl-OutOfOrderDelivery on every SLRB.

## Re-evaluation, pre-emption, congestion control
- **Re-evaluation / pre-emption** (`txSlot` `reevalPreempt`, `stack.defaults.reevaluation`): at
  exactly m - T3 (T3 = T_proc,1) before each reserved resource, `phy.ts38214.candidateSet` is rerun
  with T1 = T3 and T2 from the remaining PDB. A resource not yet announced goes to
  `mac.reevaluation`; an announced one to `mac.preemption` (pool `sl-PreemptionEnable`, the escalated
  threshold offset). Announced = after a transmission of the grant in the first period; every
  resource from the second SPS period on (the previous SCI-1A reserved them with P_rsvp_TX; the SLS
  counts only the anchor). Each flagged resource is replaced on its own
  (`phy.rx.policy.resourceReplace`, `mac.grantReplaceResource` for the SPS MAC state); with no
  replacement the grant is released.
- **Congestion control** (`txSlot` `congestionOk`): SL RSSI per sub-channel per slot is measured in
  `rxSlot` (`phy.ts38215.slRssi` on the power-calibrated grid; NaN when transmitting, -Inf when nothing
  arrived) into a ring of a + N + 1 slots. Before each transmission: CBR over [n-N-a, n-N-1]
  (`phy.ts38215.cbr`), the range and sl-CR-Limit per priority (`cfg.crLimitTable`,
  `phy.ts38214.cbrRangeIndex`; the default Tx config before any measurement), CR per priority at
  n-N with b = N (`phy.ts38215.cr`, own transmissions from `ue.txHist`), and
  `phy.ts38214.congestionControlCheck`. A violating transmission is dropped (the clause's own
  example); the resource is skipped and the data stays in RLC if it was the first.
- A retransmission is now "the grant holds a MAC PDU" (`gr.proc > 0`), not "next > 1": a dropped or
  missed first resource used to send the next resource as a retransmission of a TB never built.
- **SL RSSI is the sub-channel's total power per symbol** (TS 38.215 5.1.25 read with 5.1.3's NR
  carrier RSSI), resolved 2026-10-28 in `phy.ts38215.slRssi`; it averaged per RE before. With
  sl-ThreshS-RSSI-CBR 9 = -94 dBm and a thermal floor of about -110 dBm per 10-PRB sub-channel, a
  sub-channel is busy at 16 dB above noise.

## Known defects (found 2026-10-28) -- the original entries, superseded by the section above
Found by the first full-stack two-UE run, confirmed by a noise-free loopback
(`stack.phySlotTx` -> `stack.phySlotRx`, no channel, no RF):

1. **A retransmission (RV 2) does not decode on its own**, for almost every MCS and width,
   noise-free. The link-level chain (`harness.lls.linkSlot`, same `phy.chan.psschTx/psschRx`) fails
   the same cases at 40 dB, so the fault is in the shared normative PSSCH chain (LDPC rate
   matching / recovery for RV != 0, TS 38.212 5.4.2), not in this package. A failed RV 2 is then
   soft-combined (`harqCombineDecode`), so every packet that needs its retransmission is exposed.
2. **MCS 9, 16 and 20 do not decode even on RV 0**, at every width, noise-free. The link-level
   chain decodes them, so this one is here: `phySlotRx` decodes the data only after SCI-2 (it needs
   the RV), and SCI-2 decoding fails at those code rates. The SCI-2 RE count depends on the PSSCH
   code rate and beta offset (TS 38.212 8.4.4); suspect the SCI-2 rate matching or its RE count.

Until both are fixed, full-stack results are valid only for first transmissions at MCS that decode
(MCS 7, 10, 11, 13 in the loopback), and `test_stack` must cover RV 2 and MCS 9/16/20.
