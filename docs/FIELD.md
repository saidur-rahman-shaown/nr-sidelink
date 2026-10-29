# Five UEs in a field — the field scenario, and how every channel is configured

`runField()` runs it and writes its figures to `plots/field/`. `fieldConfig.m` is the only file
to edit for placement, traffic, the radio channel and the UE latency policy. Everything
3GPP-configured comes from the stored preconfiguration `+cfg/configs/preconfig_example.json`, the
way an out-of-coverage UE gets it. This page has three parts:

1. **The scenario**: what five UEs exchange, and what the run measures, including collisions.
2. **Channel configuration, layer by layer**: logical channels, bearers, the transport channel,
   PSCCH/PSSCH/PSFCH, the resource pool and the BWP. For each field: its stored value, what it
   turns into, and which module reads it.
3. **The radio channel between the UEs**: path loss, fading, noise, interference, half duplex.

Every packet in this run is real bytes through every layer and a real waveform. Application →
SDAP → PDCP → RLC → MAC → SCI/PSCCH/PSSCH → OFDM IQ, then the channel, then the reverse at every
other UE (`+stack/`, `+harness/+field/`). Nothing is abstracted to a BLER table.

---

## 1. The scenario

Five **static** UEs dropped uniformly at random in a **1500 m × 1500 m** field
(`c.field.sizeM`, `c.ue.placementSeed` = 7; `plots/field/geometry_field.png`). No movement, so
no Doppler: the TDL fading on each link is a fixed realisation for the run.

| Traffic | Who | What | QoS (PQI → PDB, priority) | SLRB / RLC / LCID | Feedback |
|---|---|---|---|---|---|
| **CAM**: periodic awareness (ETSI EN 302 637-2) | every UE, 10 Hz, unsynchronised phases | 300 B, broadcast to FF:FF:FF | PQI 55 → 100 ms, priority 6 | SLRB 1, UM, LCID 4 | none (broadcast) |
| **DENM**: event warning (EN 302 637-3) | UE3 detects a hazard at t = 500 ms; repeats every 100 ms, 5 times | 250 B, broadcast | PQI 70 → 20 ms, priority 3 | SLRB 2, UM, LCID 5 | none |
| **Sensor sharing**: unicast | UE1 → **its nearest neighbour**, every 100 ms from t = 50 ms | 400 B | PQI 89 → 200 ms, priority 3 | SLRB 3, AM, LCID 4 (at that Destination) | **PSFCH HARQ-ACK** |

What happens over time in a run:

- **t = 0 to 500 ms.** Five CAM streams, each UE on its own 100 ms phase. Each CAM triggers a
  Mode-2 selection (TS 38.214 8.1.4): the UE excludes resources its sensing database shows
  reserved above the RSRP threshold, then draws an initial resource and one chained
  retransmission resource within the remaining PDB. Every UE decodes every SCI it can hear, so
  sensing databases fill from real decodes. In parallel, UE1 opens unicast to its neighbour: AM
  RLC, HARQ feedback on, and ACKs on PSFCH releasing the retransmission resource early.
- **t = 500 ms.** UE3 raises a DENM. CAM and DENM share one Destination (broadcast), so
  without intervention the DENM would ride the grant UE3 had already drawn for its next CAM,
  which can be up to 100 ms out against a 20 ms PDB. The MAC's §5.22.1.2 `pdbNotMet` check
  clears that grant and reselects within 20 ms (`pdbRes` counter). The DENM and the waiting CAM
  then go out together, prioritised by LCP (DENM's channel is priority 3, CAM's 6).
- **t = 600 to 900 ms.** Four DENM repeats.

### What this drop measured (1.5 s, TDL-D, seed 11)
| Flow | Copies expected | On time | PRR | p50 / p95 latency |
|---|---|---|---|---|
| CAM | 280 | 119 | 0.425 | 51.0 / 95.0 ms |
| DENM | 20 | 5 | 0.250 | 12.5 / 18.5 ms |
| Unicast UE1 → UE3 | 13 | 0 | 0.000 | — |

**A 1.5 km square is larger than this link reaches.** At 23 dBm, 1.5 m antennas, RMa LOS and
MCS 7 on a 3-sub-channel CAM, broadcast PRR is 1.0 on every link up to 520 m. It drops to 0.57
at 823 m and to 0 from 886 m (`plots/field/prr_vs_distance.png`). The drop put UE1 886–1354 m
from everyone (−2.7 to 4.7 dB SNR at 10 PRB, about 5 dB less spread over 30 PRB), so:
- UE1 is effectively isolated. Its CAMs reach no one, and its unicast to the nearest neighbour
  (UE3, 886 m) never gets through: 44 DTX at UE1, no ACK, and radio link failure after
  `sl-MaxNumConsecutiveDTX` = 8.
- UE3, the DENM source, has only UE4 (519 m) in range, so the DENM reaches one receiver of four.
- Of the 161 lost CAM copies, 154 are radio and 7 collisions. Nothing is lost to scheduling or
  half duplex.

That is the scenario working: range, not the protocol, decides a sparse field. Try another
`c.ue.placementSeed`, a smaller `c.field.sizeM`, or more UEs.

### Collision data (`harness.field.collisions`, `plots/field/collisions.png`)
Yes, the run records collisions, from both sides. The transmit log says which PSSCH shared a
slot and sub-channels. The receive log (`stack.rxSlot`'s third output) says, per receiver, which
SCIs and TBs it decoded. Together they give every (transmission, receiver) outcome.

| | value |
|---|---|
| PSSCH transmissions | 199 |
| collided (same slot, ≥ 1 common sub-channel) | 8 (4.0%) |
| of which same starting sub-channel (PSCCH on PSCCH) | 2 |
| slot shared with another transmission (senders deaf to each other) | 10 |
| TB decode rate at listening receivers, clean initial transmissions | 0.311 (dominated by range) |
| same, collided initial transmissions | 0.267 |
| **capture**: collided receptions decoded at SIR ≥ 3 dB / < 3 dB | **4 of 4 / 0 of 11** |

The capture split is the useful number: a collision only costs a receiver for whom the
interferer is not at least ~3 dB weaker than the wanted UE. Outcomes are scored on initial
transmissions (RV 0) only, because a blind retransmission's RV 2 is not self-decodable and is
judged by combining. The report prints all of this. The resource grid marks every collision with
a red ▽. Why collisions happen at all here: grants are dynamic (no reservation period), so an
initial transmission is never announced in advance, and two UEs selecting in the same instant
cannot see each other's choice. Only the chained retransmission is protected by sensing.

### Why the CAM latency median is ~50 ms, and where that is configured
Two settings together, only one of them in the JSON:

1. **The deadline, from the JSON.** PQI → `sl-DiscardTimer` (100 / 20 / 200 ms) is the PDB the
   MAC selects against.
2. **Where inside the deadline, a UE policy and not in the JSON.** TS 38.214 §8.1.4 lets the UE
   choose the window end T2 anywhere in [T2min, remaining PDB] and draw the resource randomly in
   [n + T1, n + T2]. `phy.rx.policy.selectionWindow` takes **T2 = the remaining PDB**, the
   collision-optimal end, and the draw is uniform. So the access delay is uniform over the whole
   budget, mean ≈ PDB/2. That is the near-straight CAM CDF in `plots/field/latency_cdf.png`.

The knob is **`fieldConfig.impl.t2MaxMs`** (`stack.defaults.t2MaxMs`, default Inf). It caps T2
but never below T2min, which is 20 ms here from `sl-SelectionWindowList` n20. `fieldLatencyStudy`
runs the same scenario at three caps (`plots/field/latency_t2_compare.png`):

| T2 | CAM PRR / median / p95 | DENM PRR | collided PSSCH |
|---|---|---|---|
| remaining PDB (default) | 0.425 / 51.0 / 95.0 ms | 0.250 | 8 / 199 (4.0%) |
| cap 50 ms | 0.400 / 27.8 / 49.8 ms | 0.250 | 15 / 216 (6.9%) |
| cap 20 ms (= T2min) | 0.414 / 11.8 / 22.0 ms | 0.150 | 12 / 216 (5.6%) |

(Field drop above: PRR is capped by range, so only latency and collisions move.) The trade is
now measured rather than asserted. A short window cuts CAM latency 4×, and packs everyone's
transmissions into fewer candidate resources, so collisions rise by roughly half. In the 20 ms
run, 6 of the DENM's lost copies are collisions. An adaptive policy would shrink T2 only while
CBR is low. On the earlier road layout (all UEs in range) the same caps took CAM from
54.5 → 12 ms median at PRR 0.96 → 0.98. Unicast never connects in this drop (see above).

### Three things this scenario found that two-UE tests could not
1. **A DENM missed its PDB behind a CAM's grant.** The fix is TS 38.321 §5.22.1.2
   `pdbNotMet`, gated so it only fires while more than T_proc,1 remains (otherwise the UE thrashes).
2. **The lowest-free HARQ process caused false duplicates.** NDI toggles per process. Process 1
   alternated between the unicast and broadcast Destinations, so the broadcast TB came back with
   the NDI it had last time, and the receiver's duplicate filter (§5.22.2.2.1 NOTE 1a) discarded a
   new TB. Processes are now chosen round-robin.
3. **A partial collision poisoned HARQ combining.** A one-sub-channel collision left that
   sub-channel's LLRs confidently wrong, and combining carried them into a clean retransmission.
   The receiver now estimates noise plus interference per sub-channel
   (`phy.rx.ce.dmrsEstimate(..., groupSc)`), so collided REs become erasures.

Plus one off-by-one: a resource in the deadline slot itself always finds its SDU already
discarded, so T2 now stops one slot short of the deadline.

### A latency cost you configure without seeing it: t-Reordering at broadcast receivers
TS 38.323 §7.1 starts a new groupcast/broadcast receive entity **half a window below** the first
SN it hears, so the first packet from each new source waits t-Reordering before delivery. A gap
(a lost CAM) makes the next one wait too. TS 38.331 §9.1.1.5 leaves this receiver t-Reordering
"up to UE implementation"; `fieldConfig.impl.tReorderingMs` sets it, default 10 ms. Against
DENM's 20 ms PDB that is half the budget. The test (`test_field`) measures the hold at exactly
t-Reordering, to within one slot. The one late CAM in the run above (107.5 ms against a 100 ms
PDB) is this hold after a lost predecessor.

---

## 2. Channel configuration, layer by layer

Read top to bottom, this is the path a packet takes. "Stored" is the JSON value. "Consumed by"
is the module that reads it on the way.

### 2.1 Application → SDAP: QoS flow to radio bearer
| Field (TS 38.331 `SL-RadioBearerConfig`) | SLRB 1 | SLRB 2 | SLRB 3 | Consumed by |
|---|---|---|---|---|
| `sl-MappedQoS-FlowsList` (PQI) | 55 | 70, 3 | 89 | `sdap.sdapRules` → `sdapTxMap`: PQI + cast → SLRB |
| `sl-CastType` | broadcast | broadcast | unicast | same; a flow whose cast does not match is not mapped |
| `sl-SDAP-Header` | absent | absent | **present** | `sdap.sdapPduPack/Parse`. TS 37.324 §6.2.1: gc/bc never carry one; unicast: 1 byte D/C·R·QFI |
| `sl-DefaultRB` | false | false | **true** | only a bearer with a header may be default, so only unicast. `cfgValidate` checks 16c/17 enforce both |

PQI → priority and PDB come from `cfg.pqiTable` (TS 23.287 Table 5.4.4-1). A flow that maps to
no SLRB is refused and counted (`noBearer`), never sent on a guess.

### 2.2 PDCP
| Field | SLRB 1 | SLRB 2 | SLRB 3 | Effect / consumer |
|---|---|---|---|---|
| `sl-DiscardTimer` | ms100 | ms20 | ms200 | `pdcp.pdcpTxTimer`. **This is the PDB** in this stack: the MAC reads the earliest running discard deadline as "remaining PDB" for selection and for `pdbNotMet` |
| `sl-PDCP-SN-Size` | 12 bits | 12 | 12 | 2-byte data PDU header. No security, so no MAC-I |
| `sl-OutOfOrderDelivery` | — | true | — | the TX config. A gc/bc *receiver* uses §9.1.1.5 defaults, not this, because it does not know the sender's SLRB |
| t-Reordering | (receiver choice) | | | `stack.defaults.tReorderingMs` 10 ms (UM), `tReorderingAmMs` 1000 ms (AM: must outlast RLC ARQ) |

### 2.3 RLC
| Field (`SL-RLC-Config`) | RLC bearer 1 | 2 | 3 | Consumer |
|---|---|---|---|---|
| mode | UM | UM | **AM** | `rlc.um*` / `rlc.am*` |
| SN field length | 6 bits | 6 | 12 | header size and window: UM window 32, AM 2048 (`rlc.windowSize`) |
| `sl-T-PollRetransmit` | | | ms45 | `rlc.amTxTimer` |
| `sl-PollPDU` / `sl-PollByte` | | | p4 / kB25 | poll bit in `rlc.amTxBuild` |
| `sl-MaxRetxThreshold` | | | t4 | `amTxOnStatus`. Reaching it is counted (`maxRetx`) |
| t-Reassembly, t-StatusProhibit | UE choice (§9.1.1.4/5) | | | `stack.defaults`: ms20, ms0 |

### 2.4 MAC: logical channels
Each RLC bearer is one **STCH** logical channel. The LCID is assigned per Destination in SLRB
order from 4 (TS 38.321 Table 6.2.4-1), so a broadcast transmitter carries LCIDs 4 (CAM) and 5
(DENM), and the unicast Destination's AM channel is LCID 4 at that Destination.

| Field (`SL-LogicalChannelConfig`) | LCH 1 (CAM) | LCH 2 (DENM) | LCH 3 (unicast) | Consumer |
|---|---|---|---|---|
| `sl-Priority` | 6 | 3 | 3 | LCP order (`mac.slLcp`), the selection's prio_TX (TX percentage, RSRP threshold row), **SCI-1A Priority** = the highest priority in the MAC PDU |
| `sl-PrioritisedBitRate` | 64 kB/s | 64 kB/s | 64 kB/s | token bucket SBj (`mac.slLcpBucket`) |
| `sl-BucketSizeDuration` | 100 ms | 50 ms | 100 ms | bucket cap |
| `sl-HARQ-FeedbackEnabled` | disabled | disabled | **enabled** | a MAC PDU requests PSFCH feedback iff any channel in it is enabled. Selection then enforces the PSFCH minimum time gap between resources |

Preconfiguration-wide MAC fields: `sl-MaxNumConsecutiveDTX` n8 → radio link failure after 8
consecutive DTX (`mac.harqOnFeedback`). `sl-ReselectAfter` n5 and `sl-ProbResourceKeep` v0 apply
to periodic reservations, which this stack does not make.

### 2.5 Transport channel: SL-SCH
One MAC PDU per grant: the SL-SCH subheader (4 bytes: SRC 16 MSB, DST 8 MSB), then
R/F/LCID/L subheaders and SDUs, padded to the TBS (`mac.muxSlSch`). The TBS comes from TS 38.214
§8.1.3 at the pool geometry below and the UE's MCS (`stack.defaults.mcs` = 7: QPSK, R = 0.514;
Mode 2 leaves MCS to the UE). For L_subCH = 1…5 it is **80 / 201 / 317 / 437 / 560 bytes**,
smaller than without PSFCH, because clause 8.1.3.2 removes the PSFCH symbols from every slot.
Coding: CRC, LDPC base graph, rate matching per TS 38.212 §6/5.4.2. HARQ: 16 Sidelink processes,
RV sequence 0-2-3-1, one blind retransmission resource (`sl-MaxNumPerReserve` = 2, the
`cfg.resourcePool` default, since the JSON omits it).

### 2.6 BWP and numerology
| Field | Stored | Derived | Consumer |
|---|---|---|---|
| `subcarrierSpacing` | kHz30 | µ = 1, 0.5 ms slot, 20 slots/frame | everything slot-timed. µ is never hardcoded |
| `locationAndBandwidth` | 13475 | RIV (N = 275) → start PRB 0, **50 PRB** | `cfg.bwpLocation` |
| `carrierBandwidth` | 51 PRB | carrier ≥ BWP | `cfgValidate` |
| `sl-StartSymbol` / `sl-LengthSymbols` | sym0 / sym14 | full slot for sidelink | `stack.poolGeometry` |
| `sl-AbsoluteFrequencyPointA` | 620000 | 3.300 GHz (n78 raster) | **not used by the waveform or the channel**. See §3 |

OFDM: 600 subcarriers × 14 symbols → 15 360 samples per slot at 30.72 MHz (`phy.lib.ofdmMod`).

### 2.7 Resource pool (one TX pool = the RX pool)
| Field | Stored | Derived | Consumer |
|---|---|---|---|
| `sl-SubchannelSize` / `sl-NumSubchannel` / `sl-StartRB-Subchannel` / `sl-RB-Number` | n10 / 5 / 0 / 50 | 5 sub-channels of 10 PRB at PRB 0, 10, …, 40 | selection, FRIV, blind PSCCH search starts |
| `sl-TimeResource` | 20-bit all ones | every slot is a pool slot (logical = physical; asserted) | `stack.poolGeometry` |
| `sl-SensingWindow` | ms100 | T0 = 100 ms of sensing history | `phy.ts38214.candidateSet` |
| `sl-SelectionWindowList` | n20 for every priority | T2,min = 20·2^µ slots = 20 ms, cut to the remaining PDB when shorter | `phy.rx.policy.selectionRequest` |
| `sl-Thres-RSRP-List` | index 20 everywhere | −128 + (20−1)·2 = **−90 dBm**, raised 3 dB per round until enough candidates survive | `candidateSet` steps 5–7 |
| `sl-TxPercentageList` | 50/50/35/35/20/20/20/20 % by priority | X: the share of candidates that must survive exclusion | same |
| `sl-ResourceReservePeriodList` | {0, 100 ms} | SCI-1A reservation-period field (1 bit) and the periods sensing projects | encoder and sensing. This stack transmits 0 (dynamic) |
| `sl-RS-ForSensing` | pssch | RSRP is measured on PSSCH DM-RS | `phy.ts38215.slRsrp` |
| `sl-PreemptionEnable` | enabled | | used by `+harness/+sls/`, not by `+stack/` |

### 2.8 PSCCH (carries SCI-1A)
| Field | Stored | Derived |
|---|---|---|
| `sl-TimeResourcePSCCH` | n2 | symbols 1–2 (after the AGC symbol) |
| `sl-FreqResourcePSCCH` | n10 | 10 PRB at the bottom of the allocation's first sub-channel |
| `sl-DMRS-ScrambleID` | 0 | PSCCH DM-RS N_ID |
| `sl-NumReservedBits` | 2 | SCI-1A reserved field. SCI-1A is 25 bits in this pool; every width comes from the pool (`phy.ts38212.sci1aPack`) |

SCI-1A carries priority, FRIV (sub-channels of the chained resource), TRIV (its slot offset,
reach 1–31), reservation period, DM-RS pattern, β-offset index, MCS. Chain: CRC24C → polar →
rate match → scramble → QPSK (`phy.chan.pscchTx`). The receiver tries **every** sub-channel start
blind; the CRC is the detector (`phy.rx.det.pscchSearch`).

### 2.9 PSSCH (carries SCI-2A + SL-SCH)
| Field (`sl-PSSCH-Config`) | Stored | Derived |
|---|---|---|
| `sl-PSSCH-DMRS-TimePatternList` | {2, 3} | the UE signals index 0 → 2 DM-RS symbols. With l_d = 10 (Table 8.4.1.1.2-1) they land on symbols **3 and 8** |
| `sl-BetaOffsets2ndSCI` | {0, 2, 4, 6} | index 0 → β = 1.125 (TS 38.213 Table 9.3-2), which sizes SCI-2's REs |
| `sl-Scaling` | f1 | α = 1, the cap on SCI-2's share |

Slot layout with PSFCH every slot: 0 = AGC (copy of 1); 1–9 = PSSCH, with PSCCH in 1–2 on its
10 PRB and DM-RS at 3, 8; 10 = gap; 11 = PSFCH AGC; 12 = PSFCH; 13 = guard. SCI-2A (35 bits:
HARQ id, NDI, RV, SRC 8 LSB, DST 16 LSB, feedback flag, cast type, CSI request) is polar-coded
ahead of the data, both scrambled with N_ID = PSCCH CRC mod 2^16 (`phy.chan.psschTx`).

### 2.10 PSFCH (HARQ feedback, unicast only here)
| Field (`sl-PSFCH-Config`) | Stored | Derived / meaning |
|---|---|---|
| `sl-PSFCH-Period` | sl1 | a PSFCH occasion in **every** slot |
| `sl-PSFCH-RB-Set` | first 10 of 50 PRB | M_PRB,set = 10 → 10 / (5 sub-channels × 1 slot) = **2 PRB per sub-channel** |
| `sl-NumMuxCS-Pair` | n2 | 2 cyclic-shift pairs per PRB |
| `sl-PSFCH-CandidateResourceType` | startSubCH | resources follow the starting sub-channel only: R = 1 × 2 × 2 = 4 per PSSCH |
| `sl-MinTimeGapPSFCH` | sl2 | feedback for slot n goes in the first PSFCH slot ≥ n + 2 (`phy.ts38213.psfchTiming`) |
| `sl-PSFCH-HopID` | 0 | sequence hopping ID |

The receiver picks index (P_ID + M_ID) mod R with P_ID = the SCI-2 Source ID and M_ID = 0 for
unicast (`phy.ts38213.psfchResource`). ACK is cyclic shift 6, NACK 0 (`psfchCyclicShiftM0`).
The transmitter correlates both hypotheses and gates on energy (`psfchGateDb` 6 dB above
thermal noise), so silence reads as **DTX**, not as a noise ACK. On ACK the remaining
retransmission resources are released. On NACK or DTX the next one is used, soft-combined at
the receiver. Broadcast never requests feedback: it simply uses its blind retransmission.

### 2.11 Power
P_CMAX 23 dBm, max-power policy (`phy.ts38213.slPowerControl`). PSFCH and PSSCH in one slot
share it. No open-loop path-loss power control (TS 38.213 §16.2 is a placeholder by decision).

---

## 3. The radio channel between the UEs (`fieldConfig.radio`, `harness.field.run`)

None of this is 3GPP configuration. It is the physics the waveform passes through, applied per
**directed link** every slot:

    y_j = Σ_{i transmitting, i≠j}  h_ij(t) * ( x_i · 10^(−PL(d_ij(t))/20) )  +  n_j

| Knob | Value | How it is applied |
|---|---|---|
| `fcHz` | 5.9 GHz (ITS band) | path loss and Doppler are evaluated here. The report prints it beside the preconfiguration's Point A (3.3 GHz) because the two disagree: the stored ARFCN is an example value, and the waveform never reads it. Make them agree if a run should be self-consistent |
| `plModel`, `losMode`, `hAntM` | TR 38.901 RMa, LOS, 1.5 m | `harness.chanmodel.pathloss` (toolbox `nrPathLoss`): 89.9 dB at 120 m, 106.0 at 450 m, 113.6 at 700 m. Positions move with each UE's velocity every slot (zero in the static drop), so path loss tracks the geometry |
| `fading`, `delaySpreadNs` | TDL-D, 100 ns | one `nrTDLChannel` per directed link (`harness.chanmodel.tdlChannel`). Its time is set to the slot's **wall-clock time** each use, so a link fades continuously even though it is only exercised when its transmitter speaks. Filter delay (7 samples) compensated. Max Doppler from **\|v_i\| + \|v_j\|** (double mobility, static scatterers). With the static drop it is 0: each link keeps one frequency-selective realisation for the whole run |
| `noiseFigureDb` | 9 dB | thermal kT·B·NF per **sample** at 30.72 MHz = −90.1 dBm, i.e. −120.2 dBm per 30 kHz RE. The receiver's PSFCH energy gate uses the same floor |
| interference | — | every transmitter in the slot is summed at every receiver: PSCCH/PSSCH collisions, PSFCH collisions and partial sub-channel overlaps are physical, not flagged |
| half duplex | — | `stack.rxSlot`: a UE that sent PSSCH cannot decode PSSCH in that slot, but still hears PSFCH (different symbols). A UE that sent PSFCH cannot hear PSFCH |

What the receiver is **not** told: the channel and the noise are both estimated from DM-RS
(least squares, interpolated). Noise plus interference is estimated per sub-channel. Nothing is
genie-aided except time/frequency synchronisation.

---

## 4. What is not in this scenario, stated rather than hidden

- **Periodic reservations are off by default.** `stack.defaults.prsvpTxMs` = 0 gives a
  single-MAC-PDU grant per packet; set it to 100 for sensing-based SPS (one grant reused every
  100 ms and announced in SCI-1A, `+stack/CLAUDE.md` "SPS"). The field scenario still uses 0.
- **No congestion control** (CBR/CR, TS 38.214 §8.1.6) and no pre-emption or re-evaluation in
  `+stack/`. Both run in `+harness/+sls/`.
- **Ideal synchronisation.** No S-SSB/PSBCH in the field chain, no CFO, no timing offset.
- **No shadowing; fading is not reciprocal.** h_ij and h_ji are independent draws. RMa is a
  cellular model used at vehicle antenna heights. TR 37.885's V2V highway model is the right one,
  but there is no local PDF or toolbox implementation of it.
- **Groupcast** is configurable but has no flow here. PC5-S/PC5-RRC link setup is replaced by
  `stack.unicastSetup`. No security, no ROHC.

## Files
| File | Role |
|---|---|
| `fieldConfig.m` | the scenario: positions, speeds, L2 IDs, CAM/DENM/unicast traffic, radio channel, UE implementation knobs |
| `runField.m` | runs it, prints the report, writes figures to `plots/field/` |
| `fieldLatencyStudy.m` | same run at T2 = PDB / 50 / 20 ms; `plots/field/latency_t2_compare.png`, per-cap figures in `plots/field_t2_<cap>/` |
| `+harness/+field/plotField.m`, `plotCompare.m` | the figures: road geometry, space-time trajectories, link SNR, latency CDF and timeline, resource occupancy |
| `+harness/+field/run.m` | moves the UEs, generates traffic, applies the channel, drives `stack.txSlot` / `stack.rxSlot` |
| `+harness/+field/report.m` | PRR and latency against the PDB per flow, loss causes, link SNRs, per-UE counters |
| `+test/+unit/+harness/test_field.m` | pins the DENM PDB, the reselection, the HARQ process fix, unicast-only PSFCH, and the t-Reordering hold |
