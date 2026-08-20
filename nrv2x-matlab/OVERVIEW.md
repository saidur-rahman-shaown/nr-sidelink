# nrv2x-matlab — Implementation Overview

A Rel-16 NR sidelink Mode 2 UE in MATLAB: sensing-based SPS resource
selection, re-evaluation and pre-emption per TS 38.214 §8.1.4 / TS 38.321
§5.22, a 5G Toolbox PSCCH/PSSCH physical layer, a TR 38.901 RMa
distance-based channel arranged as a **UE graph**, and a 23 dBm
analog-equivalent RF stage. Companion to [../Plan.md](../Plan.md).

> **Naming note:** sidelink has no PDCCH/PDSCH. The control channel is the
> **PSCCH** (carries SCI format 1-A) and the data channel is the **PSSCH**
> (carries the second-stage SCI plus the SL-SCH transport block). They are
> the sidelink analogues of PDCCH/PDSCH and are what this document
> describes.

```
nrv2x-matlab/
  SidelinkUE.m       the integrated UE (MAC + sensing + PHY + RF)
  setupPaths.m
  config/            preconfiguration, logical slot map, spec tables
  phy/               5G Toolbox PSCCH/PSSCH chain (from Version 3)
    sensing/         TS 38.214 8.1.4 — the analytical core (original)
  mac/               MAC entity (original) + HARQEntitySL
  channel/           TR 38.901 RMa pathloss + ChannelGraph + TDL fading
  l2/                RLC UM/AM, PDCP, SDAP        (M2 scope, not wired yet)
  app/               ETSI CAM/DENM, SAE PC5-S     (M2 scope, not wired yet)
  rf/                RFModule (23 dBm), toolbox OFDM test waveform
  tests/             10 test files + runAllTests + output/ plots
```

---

## 1. Configuration and the time base

`config/defaultPreconfig.m` mirrors the Rel-16 ASN.1 IEs
(`SL-ResourcePool-r16`, `SL-UE-SelectedConfigRP-r16`,
`SL-UE-SelectedConfig-r16`) as a validated struct: 20 MHz, 30 kHz SCS
(`mu=1`, 0.5 ms slots), 5 sub-channels x 10 PRB, `sl-SensingWindow = 100 ms`,
`sl-Thres-RSRP-List` (64 entries), `sl-TxPercentageList = 20%`,
`sl-MaxNumPerReserve = 3`, `sl-PreemptionEnable = enabled`,
`sl-MaxTxTransNumPSSCH = 3`.

`config/deriveLogicalSlots.m` builds the **logical pool slot map** — the
single most bug-prone piece of Mode 2 (Plan.md §4.2). A slot belongs to
the pool iff it is not an S-SSB slot, passes the TDD UL mask, and its
`sl-TimeResource-r16` bitmap position (the bitmap advances only over
surviving candidates) is 1. It returns both direction maps and
**`T'_max`** (pool slots in 10240 ms), which feeds the §8.1.7 conversion

```
P'_rsvp = ceil( (T'_max / 10240 ms) * P_rsvp )      % ceil, never round
```

Every window bound, projection and counter in the sensing/MAC code runs on
logical indices; conversion happens once at the edges.
`config/procTimeTable.m` holds Tables 8.1.4-1/-2 (`T_proc,0 = 1`,
`T_proc,1 = 5` slots at 30 kHz). `config/creselDraw.m` holds both counter
branches (§3).

## 2. PHY sensing — TS 38.214 §8.1.4 (phy/sensing/)

Runs **in PHY**, per the normative split: PHY determines the candidate set
`S_A` and *reports it to higher layers*; MAC picks from it. The MAC never
computes an RSRP or threshold.

`SensingDatabase.m` — one record per decoded SCI-1A (`rxSlot`,
sub-channels, priority, reservation period, RSRP, same-TB TRIV slots,
source L2 ID for diagnostics) plus the `monitored(t')` vector. Slots
default to **unmonitored** (a booting UE has heard nothing); the harness
marks each listened slot, and the UE's own TX slots are forced
unmonitored (half-duplex).

`selectCandidateResources.m` — the procedure, steps 1–7:

1. **Selection window** `[n+T1, n+T2]`, `T1 = T_proc,1` (never 0),
   `T2 = remaining PDB` clamped against `T2min(prio)`.
2. **Sensing window** `[n−T0, n−T_proc,0)` — right end exclusive.
3. **Threshold** `Th(p_i,p_j) = sl-Thres-RSRP-List[p_i + (p_j−1)·8]` — the
   64-entry lookup, not a linear approximation.
4. Initialise `S_A` to all candidates.
5. **Unmonitored-slot exclusion with the hypothetical SCI**: every slot
   the UE could not hear is assumed to carry an SCI reserving *all*
   sub-channels at *every* allowed periodicity; condition (c) is applied.
   This is what makes half-duplex cost something.
   **5a.** If `|S_A| < X·M_total`, re-initialise (rescues the boot case).
6. **Sensed-reservation exclusion**, all three conditions, with the
   **two-sided periodic projection** (`condCMask.m`): the sensed SCI's
   resources (slot + TRIV slots) recur `q = 1..Q` (guarded:
   `Q = ceil(T_scal/P_rsvp_RX)` only if `P_rsvp_RX < T_scal` and
   `n'−m ≤ P'_rsvp_RX`), and **our own candidate** recurs
   `j = 0..C_resel−1` at `P'_rsvp_TX`. `C_resel = 10 × counter` comes from
   MAC through the request.
7. If `|S_A| < X·M_total`: **+3 dB on every priority pair, restart from
   step 4** (so step-5 exclusions are re-applied) — no invented threshold
   ceiling; an iteration cap asserts instead. Returns `S_A`, `M_total`
   and the final offset (pre-emption needs the final threshold).

`isExcludedByStep6.m` re-tests a single resource at the final threshold
and reports the strongest excluding priority — the pre-emption input.

## 3. MAC — TS 38.321 §5.22 (mac/MacEntity.m)

**Grant lifecycle / SPS.** On trigger, MAC draws
`SL_RESOURCE_RESELECTION_COUNTER` (uniform `[5,15]` for `P ≥ 100 ms`;
`[5k,15k]`, `k = ceil(100/max(20,P))` below — the short-period branch),
computes `C_resel = 10×counter`, requests `S_A` from PHY, picks the
initial resource **uniformly at random**, then up to
`min(sl-MaxTxTransNumPSSCH−1, sl-MaxNumPerReserve−1)` blind-retransmission
resources within 31 slots. The occurrence repeats every `P'_rsvp_TX`
logical slots; the counter decrements once per occurrence; at zero the
`sl-ProbResourceKeep` draw either keeps the grant (counter redrawn) or
clears it.

**All seven reselection triggers** (§5.22.1.2): counter expiry + failed
keep-draw; pool reconfiguration; no grant; one second without any
(re)transmission; `sl-ReselectAfter` consecutive unused opportunities;
SDU-too-large; PDB-not-met.

**Re-evaluation / pre-emption** at `T3 = T_proc,1` before each pending
resource: if the resource fell out of a fresh `S_A` —
*not yet signalled* → re-evaluate (replace, redraw from `S_A`);
*already signalled* → pre-empt only if it is step-6-excluded at the
**final** threshold **and** the priority condition of
`sl-PreemptionEnable` holds (`enabled`: other UE outranks us;
`plK`: additionally `prio_RX < prio_pre`; absent: never). Only the
affected resource is replaced; the grant and counter survive.

**HARQ** (`HARQEntitySL.m`, MathWorks): one entity, ≤16 processes, NDI/RV
sequence `[0 2 3 1]`, blind retransmission mode — no PSFCH feedback enters
HARQ state (feedback disabled per Plan.md §0.3).

### How MCS is selected

By **fixed policy, not adaptation** (Plan.md §0.4): QPSK at target code
rate 308/1024, set in `SidelinkPHYEntity.configureFromParams`. The TBS
then follows the TS 38.214 §8.1.3.2 procedure inside
`NRSidelinkResourcePool.getTBS` (RE counting minus PSCCH, SCI-2, DM-RS,
AGC and guard overheads → `nrTBS`), giving 1256 bits for 2 sub-channels.
There is deliberately **no link adaptation**: SL-CSI is out of scope with
PSFCH disabled, so a fixed `I_MCS` clamped to the pool's MCS range is the
declared, reproducible policy. The CBR-indexed
`SL-PSSCH-TxParameters-r16` selection (speed + CBR → MCS range, #retx,
#sub-channels) is specified in Plan.md §7.2 step 0 and is **not yet
implemented** — the retx count currently comes directly from
`sl_MaxTxTransNumPSSCH`.

## 4. How PSCCH and PSSCH are put together (phy/)

Everything below is the 5G Toolbox chain harvested from Version 3
(`SidelinkPHYEntity` + `NRSidelinkResourcePool` + channel classes), driven
per slot:

1. `NRSidelinkResourcePool.getPSCCHResources` → PSCCH RE indices, DM-RS.
2. **SCI-1A**: 24-bit CRC → `nrPolarEncode` → rate match to the PSCCH bit
   capacity (`SidelinkSCIEncoder.encodeSCI1`). The CRC also yields
   **NXID**, the scrambling identity the PSSCH DM-RS and data derive from
   — receiver-side, decoding SCI-1 is what unlocks the PSSCH.
3. `getPSSCHResources(NXID)` → PSSCH indices, DM-RS, and the split of the
   PSSCH bit budget `G = [G_SCI2, G_SLSCH]` (SCI-2 capacity per TS 38.212
   §8.4.4, `calculateQprimeSCI2`).
4. **SL-SCH**: TB → CRC, LDPC base-graph selection, segmentation,
   `nrLDPCEncode`, rate matching with `I_LBRM = 0`, RV from HARQ
   (`SidelinkSLSCH`).
5. **SCI-2**: polar-coded (`I_BIL = 1`) to `G_SCI2`.
6. **PSCCH**: scramble (`c_init = 1010`) → QPSK (`SidelinkPSCCH`).
7. **PSSCH**: SCI-2 and SL-SCH codewords multiplexed, scrambled with
   `c_init = 2^15·NXID + 1010`, modulated, layer-mapped
   (`SidelinkPSSCH`).
8. **Grid assembly**: PSCCH occupies `sl-TimeResourcePSCCH` symbols
   (default 3) in the lowest `sl-FreqResourcePSCCH` PRBs of the
   allocation, starting the symbol after AGC; PSSCH fills the allocated
   sub-channels up to the guard; DM-RS per the configured time pattern;
   **AGC symbol** = copy of the first data symbol; **guard symbol** =
   last symbol, empty (TX/RX turnaround).
9. `nrOFDMModulate` → baseband IQ.

See `tests/output/slot_structure.png` (from `test_SlotStructure`) for the
labelled RE map, and the receive pipeline in `SidelinkPHYEntity.receiveSlot`
(OFDM demod → PSCCH demod → SCI-1 polar decode → NXID → PSSCH demod →
SCI-2 decode → LDPC decode → CRC).

## 5. Multi-UE deployment — the channel graph (channel/)

**Yes — it is a graph: every UE is a node, every UE pair is an edge, and
the edge *is* the channel.** `ChannelGraph.m`:

- **Nodes**: UE ID, 24-bit source L2 ID, 2-D position.
- **Edges**: distance → **TR 38.901 Table 7.4.1-1 RMa** pathloss
  (`sidelinkPathLoss.m`, harvested from Version 3 — LOS with the
  breakpoint at `d_BP = 2π·h_TX·h_RX·f_c/c ≈ 278 m`, NLOS as
  `max(PL_LOS, PL'_NLOS)`, FSPL as the optimistic bound) plus one static
  lognormal shadow-fading draw per edge (`σ = 4/8 dB` LOS/NLOS), seeded
  for reproducibility. Edges are symmetric (reciprocal channel).
- **Link RSRP** `= 23 dBm − PL − SF`: at 200 m rural LOS,
  `23 − 94.6 − SF ≈ −72 dBm`, comfortably above the −110 dBm sensing
  threshold. `asGraph()` returns a native MATLAB `graph` object (RSRP
  edge weights) for inspection/plotting; `adjacencyRSRP()` the matrix
  form. Positions are mutable (mobility); the pathloss follows, the
  edge's SF draw persists.

The RMa antenna heights default to 1.5 m/1.5 m (vehicle-to-vehicle); the
cellular RMa formulas are reused below their nominal 10 m validity floor,
the standard practice for V2X evaluation (TR 37.885 Annex A) — recorded
in `sidelinkPathLoss.m`'s header.

**Transmission/reception between UEs** runs a two-phase slot protocol
(Plan.md §4.3): first every UE's `txPhase(n)` (MAC decides, own slot
marked unmonitored), then every UE's `rxPhase(n, rxList)` where the
harness delivers each transmitter's SCI to each receiver with the RSRP
read off the graph edge. **Half-duplex is enforced twice**: a
transmitting UE ignores all deliveries in that slot *and* the slot is
excluded from its sensing history — so it pays the step-5 hypothetical-SCI
penalty for it. SCI decode success is currently threshold-abstracted
(delivered whenever the edge RSRP is meaningful); the SINR→BLER link
abstraction of Plan.md §11 is the designated upgrade path.

## 6. RF stage (rf/RFModule.m)

Baseband IQ → analog-equivalent transmit signal at exactly **23 dBm**
(power class 3): FFT-interpolation oversampling (DAC + reconstruction
approximation), optional Rapp PA with input back-off (PAPR compression +
EVM reporting), power scaling to `mean|y|² = 199.5 mW`. Complex-envelope
convention at 5.9 GHz; `toPassband()` produces a real passband signal for
demo carriers (a true 5.9 GHz passband needs `fs ≥ 11.8 GHz`) with the
`√2` scaling that preserves average power.

## 7. Test coverage (tests/, 10/10 passing)

| Test | Verifies |
|---|---|
| `test_SlotMap` | bitmap/TDD/S-SSB slot map vs brute force; `T'_max`; `ceil` in §8.1.7; inverse maps |
| `test_CreselAndProc` | counter ranges incl. `<100 ms` branch (items 14, 19); Tables 8.1.4-1/-2 |
| `test_Sensing814` | checklist items 1–6, 8–13: window edges, logical slots, hypothetical SCI, step 5a, 64-entry index, two-sided projection, `Q` guard, +3 dB restart-from-step-4, uniform pick |
| `test_MacTriggers` | items 15–16: all seven triggers, SPS spacing = `P'`, keep path |
| `test_ReEvalPreemption` | items 17–18: re-evaluation, pre-emption at final threshold, priority negatives, absent-IE negative |
| `test_ChannelModel` | RMa hand-computed 88.25 dB @100 m; breakpoint continuity; NLOS ≥ LOS; graph reciprocity, mobility, MATLAB `graph` view |
| `test_RFModule` | exact 23 dBm; slot-duration/CP accounting vs `nrOFDMInfo`; Rapp PAPR/EVM; passband power |
| `test_TwoUEIntegration` | graph-driven two-UE scenario: **zero slot+sub-channel overlaps** after warm-up; half-duplex bookkeeping; RF at 23 dBm |
| `test_SlotStructure` | **plot** `output/slot_structure.png`: AGC / PSCCH / PSCCH-DMRS / PSSCH / PSSCH-DMRS / guard placement, with structural assertions |
| `test_SensingSelectionWindows` | **plot** `output/sensing_selection_windows.png`: sensing + selection windows, sensed SCIs, available `S_A`, and excluded resources labelled with the reserving UE's **L2 ID** |

Run: `setupPaths; cd tests; runAllTests`

## 8. Known gaps (tracked in Plan.md milestones)

- **Congestion control** (checklist item 20): CR per §8.1.6 and abstract
  CBR — Plan.md M6b.
- **CBR/speed-indexed TxParameters** selection at grant creation (§3
  above) — Plan.md §7.2 step 0.
- **Bit-exact SCI-1A field packing** from pool config
  (TRIV/FRIV widths); `SidelinkResourceIndicator.m` and `SidelinkMCS.m`
  are staged in `phy/` for this — Plan.md M3.
- **SINR→BLER link abstraction** for dense multi-UE runs — Plan.md §11.
- **l2/ and app/** (RLC/PDCP/SDAP, CAM/DENM) are migrated but not yet
  wired into `SidelinkUE` — Plan.md M2.
- `sl-RS-ForSensing` routing (PSSCH- vs PSCCH-RSRP) is abstracted:
  checklist item 7 is bypassed-by-design until TS 38.215 is on disk.
- `condCMask` implements `Q = ceil(T_scal/P_rsvp_RX)` in ms/ms; note 06
  writes `P'` there — flagged `%TODO` for verification against
  `38214-gh0.pdf` before M4 sign-off.

## 9. Provenance

Version 3 was dissolved per Plan.md §18: the 5G Toolbox PHY chain, HARQ
entity, RMa pathloss, TDL channel, RLC/PDCP/SDAP and the V2X application
generators were migrated here; the non-conformant MAC/schedulers, Rel-17
IUC paths, Rel-18 LBT, and top-level UE classes were deleted. Full
history remains at `github.com:saidur-rahman-shaown/nr-sidelink`.
`Documentations/` (Rel-16 spec PDFs + extracted notes) is retained: the
M3/M4 extractions and the conformance checklist depend on it.
