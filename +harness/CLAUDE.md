# Harnesses (B10)

Two harnesses, both implementing the same intra-slot ordering. LLS at sample resolution, SLS
at slot resolution. The ordering is the contract between every package; it is fixed here and
asserted in both.

## Slot execution model

```
FOR each slot n:
  1. TIMING    advance DFN and slot index; resolve pool membership of n
  2. RX        (only if not transmitting in n — half-duplex)
               a. blind PSCCH decode → SCI-1A set
               b. SL-RSRP per decoded SCI
               c. sensing DB update + reservation projection
               d. PSSCH decode where SCI targets us → SCI-2 → SL-SCH → MAC
               e. PSFCH detection for our prior transmissions
     ELSE      mark n unmonitored
  3. MEASURE   SL-RSSI, CBR window, CR window
  4. MAC       a. re-evaluation check
               b. pre-emption check
               c. reselection trigger evaluation → selection if fired
               d. HARQ process management, RV selection
               e. LCP → build SL-SCH MAC PDU
  5. TX        SCI-1A → PSCCH; SCI-2 + SL-SCH → PSSCH; PSFCH for received PSSCH
  6. POWER     per 38.213 cl. 16
  7. LOG       KPI and vector dump
```

## Sub-packages
`+lls/` full waveform, 1 to 3 UEs. `+sls/` abstracted PHY, many UEs.
`+chanmodel/` TDL, CDL, and the 37.885 V2V models — **wrapped**, not part of the UE.
`+mobility/` trajectory generation.

## PHY abstraction — decide the key structure before generating any curves
The SLS consumes BLER tables produced by the LLS at B5 and B6. Design the table's key
structure at B5, before generating anything: at minimum MCS, SINR, channel model, speed, and
number of retransmissions. Adding a dimension later means regenerating every curve, which is
the most expensive avoidable mistake in this phase.

State the interpolation rule and the out-of-range behaviour. Extrapolating off the end of a
BLER table silently is how an SLS produces confident nonsense.

## Tests
- Ordering assertions in both harnesses, checking no step ran out of sequence.
- LLS and SLS agreement: for a scenario simple enough to run in both, PRR must agree within a
  stated tolerance. If it does not, the abstraction is wrong, not the LLS.
- Determinism: identical seed produces identical output, bit for bit, across runs and
  machines.

## Gate
A 50-UE scenario runs to completion and produces PRR-vs-distance of the expected shape. An
animated scenario view shows per-UE resource occupancy and live PRR.

## Known traps
- Reaching into module internals for convenience. Every KPI comes from the logging interface,
  never from a peek at private state, or the harness will not survive the port.
- Channel model wrapped means wrapped. No toolbox call escapes `+chanmodel/`.

## Built so far
The system-level path runs end to end: `+sls/scenarioInit` → `ueInit` → `slotStep` → `run`,
with `+chanmodel/`, `+phyabs/` and `kpiReport`. `+lls/` and `+mobility/` are not built.

| Module | What it does |
|---|---|
| `poolAllSlots` | the baseline pool — every slot a sidelink slot |
| `+sls/scenarioInit` | the scenario; derives L_subCH and TBS from the real clause-8 arithmetic |
| `+sls/ueInit` | per-UE state, aggregating each package's own state object |
| `+sls/slotStep` | one slot for the whole scenario |
| `+sls/run` | a whole run, returning KPIs |
| `+sls/runScenario` | a run from a PREPARED scenario, so it can be edited first |
| `+phyabs/psfchDetect` | PSFCH cyclic-shift detection probability, a **placeholder** |
| `+chanmodel/pathlossDb` | log-distance **placeholder**, not a 3GPP model |
| `+chanmodel/slotSinr` | per-link SINR for a slot, once for the whole scenario |
| `+phyabs/blerLookup` | SINR → BLER, a **placeholder curve on the real key structure** |
| `kpiReport` | latency, reliability, throughput |

### The intra-slot order, and the one place it departs from the list above
The list at the top of this file is the right order **for one UE**. A slot-synchronous
multi-UE simulator cannot use it literally: no UE's reception can be evaluated until every
UE's transmission for that slot exists. `slotStep` therefore runs

    TIMING -> APP -> EXPIRE -> TX -> CHANNEL -> RX -> MAC -> LOG

and preserves the per-UE order *in effect* rather than literally, because clause 8.1.4
guarantees `T1 >= T_proc,1 > 0`: a MAC decision taken in slot n can never produce a
transmission in slot n. Everything transmitted was decided at least T_proc,1 slots earlier, so
running TX first cannot let a UE react to something it has not yet heard.

Two orderings inside that are load-bearing:
- **EXPIRE before TX**, so a grant is never spent on data that is already dead.
- **The reservation period closes before the transmission that opens the next one.**
  `mac.grantOnTransmission` rejects marking an opportunity twice in a period — correctly, that
  is how a counter decrementing at the wrong rate gets caught — so a period boundary processed
  after the transmission raises on the first repeat of opportunity 1. It cost a debugging pass
  to find; it is a `periodPhase` call before `txPhase` now.

### Unicast and PSFCH
`scenarioInit(nUe, seed, 'unicast')` pairs UEs in a **ring** — UE i talks to UE i+1, the last to
the first — so every UE is both transmitter and receiver and the feedback path is exercised in
both directions on every UE. Disjoint pairs would leave half the population never receiving.

The feedback loop is real, not abstracted away: `psfchTiming` picks the slot, `psfchPrbRange`
and `psfchResource` pick the PRB and cyclic-shift pair, `psfchDetect` decides whether it is
heard, and `mac.harqOnFeedback` applies the result. Measured effect: **transmissions per
delivery falls from 1.98 to 1.09** against an otherwise identical broadcast run, because an ACK
suppresses the blind retransmission that broadcast must always spend.

- **PSFCH is not free, and the cost is visible.** Clause 8.1.3.2 subtracts the PSFCH symbols
  from N_RE, so enabling feedback shrinks **every** transport block in the pool whether or not a
  given transmission uses it: 372 → 233 bytes at L_subCH 3 here. The TBS table is computed with
  the real period so that shows up rather than being assumed away.
- **Half-duplex on PSFCH is per-SYMBOL, not per-slot.** A UE transmitting PSSCH in slot n can
  still receive PSFCH in that slot — clause 8.1.2.1 forbids PSSCH in the symbols configured for
  PSFCH, so the two never overlap. What a UE cannot do is transmit and receive PSFCH in the same
  slot. The deafness test in `psfchPhase` is therefore "did I transmit a PSFCH", a narrower set
  than the PSSCH test in `slotSinr`.
- **PSFCH collisions are modelled.** Clause 16.3 allocates the PRB and cyclic-shift pair from
  the PSSCH slot, sub-channel and source ID — not from who is replying — so two receivers
  answering different transmitters can land on the same resource and become indistinguishable.
  Treating PSFCH as a private channel would hide the one feedback failure mode that scales with
  load.
- **Feedback is owed on the CONTROL decode, not the data decode.** A NACK is precisely the
  report that the SCI was seen and the transport block was not. Owing feedback only on success
  would turn every data failure into a DTX — and DTX drives radio link failure (clause
  5.22.1.3.3), not retransmission, so lossy-but-alive links would be declared dead.

### The MAC receive path is wired, and delivery is EARNED
`+sls/slotStep` used to credit `air(k).ctxIds` on a successful decode. It now runs the real
clause 5.22.2 chain on the actual MAC PDU the transmitter built:

    mac.sciInterest -> mac.harqRxAssign -> mac.demuxSlSch -> mac.pduFilter -> mac.harqRxProcess

What the shortcut hid: a PDU addressed to someone else still counted as a delivery, so unicast
reliability was being measured over every listener rather than the intended one.

**Clause 5.22.2.2.1's interest gate has to come first**, and omitting it is expensive. "Each
Sidelink process is associated with SCI in which the MAC entity is interested." Without that
gate every neighbour allocates a receive process for every transmission it can hear *and*
answers it on PSFCH, colliding with the addressed UE's feedback — whose transmitter then sees a
DTX. Measured: wiring the receive path without the gate produced **8 spurious radio link
failures** in a 10-UE unicast run that should have had none. The gate is `mac.sciInterest`; the
bug is recorded because "the PDU gets discarded either way" is exactly the reasoning that makes
it look unnecessary.

**Feedback now comes from the HARQ entity, not from `gotTb`.** They differ in the case clause
5.22.2.2.2 singles out: a retransmission of a TB already decoded must still be ACKed, or the
transmitter keeps retransmitting something the receiver already has.

Measured after wiring, 12 UEs unicast: ACKs suppress the blind retransmission entirely at 20 m
(1.00 transmissions per delivery) and retransmissions return as the link lengthens (1.17 at
200 m and beyond), with radio link failure at zero on short links.

### Acquisition and blind detection run in the LLS, not the SLS
`+phy/+rx/+sync/` and `+det/pscchSearch` need a resource grid, and the system-level path has
none — it works from descriptors. So they are wired where a waveform exists:

- **`+lls/linkSlot` blind-searches for the PSCCH** across every sub-channel start instead of
  extracting at the transmitter's own indices, estimating and equalising each candidate from
  its own DM-RS. It reports `pscchFalseAlarm` alongside `pscchOk`, because this tree's own rule
  is that detection reports missed detection and false alarm **as a pair**.
- **`+lls/syncSlot` is the whole acquisition chain**: S-SSB through delay, frequency offset and
  noise, then `pssSearch` → align → `cfoEstimate` → correct → demodulate → `sssDetect` →
  `psbchRx`. Every link can break the one after it — timing feeds the demodulator, N_ID,2 feeds
  the S-SSS search, and the composed N_ID^SL feeds both the PSBCH descrambling and its DM-RS —
  so a per-module test can pass on all four while the chain fails. `.acquired` is the
  conjunction for that reason.

Measured: 100% acquisition at 0 and −5 dB, 30% at −10 dB, 0% at −15 dB. **Timing stays
reliable long after the chain stops acquiring** (100% at −10 dB, 95% at −15 dB) — the CFO
estimate degrades first and the PSBCH fails on the residual offset, which is the chain effect
the conjunction exists to expose.

The SLS still models sync as ideal, per `BUILD.md`'s deferral. Nothing in `+sls/` consumes
`+sync/`.

### The receiver SEARCHES; it is not handed the transmission list
Reception is a loop over candidate **positions** — the start of every sub-channel — not over
the transmissions that actually exist. Clause 8.1.2.2 puts the PSCCH in the lowest sub-channel
of whatever allocation carries it, and the receiver does not know the allocation until it has
decoded the SCI. Iterating the transmission list instead is genie-aided: it silently grants the
receiver knowledge of exactly what was sent and where.

Two transmissions starting at the same sub-channel put their PSCCHs on the same PRBs. The
receiver has **one hypothesis per position**, so at most one is decoded — the strongest, if it
survives the others as interference. That is the capture effect, and it is why a collision is
not automatically a double loss.

### The measured table, and how its grid was arrived at
`harness.phyabs.blerTable` is generated output — 121 SNR points, 5 MCS values, 3 attempts —
and it took three generations to get a grid that actually resolves what it measures. Both
failures are worth keeping, because both produce a table that *looks* fine:

1. **Uniform 1 dB grid.** An AWGN waterfall for a few-thousand-bit LDPC block is under 1 dB
   wide, so the transition was stored as two adjacent points, 1 and 0 — **zero interior points
   for two of five MCS**. The interpolation then invents a ramp across a decibel where reality
   is a cliff. `test_agreement` now asserts at least two interior points per MCS.
2. **Non-uniform grid fine only over the PSSCH band.** That left the PSCCH curve — which sits
   about 12 dB lower, and which every sensing decode reads — resolved only to the coarse 2 dB
   region.

The final grid is 0.25 dB across −12 to +16 dB, covering both waterfalls: 2–4 interior points
for PSSCH, 14–15 for PSCCH.

Measured HARQ combining gain by the third attempt is 3.75 dB at MCS 4 rising to 7.75 dB at
MCS 20 — it grows with the code rate, which is why the table has a retransmission dimension
rather than a per-attempt dB bonus.

### The PSCCH curve is MEASURED, and the old proxy was badly wrong at high MCS
While the BLER curve was a placeholder, the system-level model approximated PSCCH by reading
the PSSCH curve at a deliberately low `pscchEffectiveMcs`. The reasoning — control is a much
lower-rate code — was right; the magnitude was guessed. Measured, control's advantage over data
is **3.75 dB at MCS 4 rising to 16 dB at MCS 20**, because PSCCH's own code rate does not move
with the data's — its 50% point sits at about −2 dB whatever the PSSCH is doing, which is the
measurement confirming PSCCH is MCS-independent as clause 8.3.2 implies. No single proxy MCS can express an advantage that grows with the data rate, and
at high MCS the proxy understated control's reach badly. `harness.phyabs.pscchBler` reads the
measured curve; `pscchEffectiveMcs` is gone.

### Switching to measured curves changed system-level behaviour, and a test caught it
Pre-emption stopped firing at 40 UEs. Not a regression: the measured PSCCH curve is harsher than
the invented one, so fewer SCIs decode at range, each UE's sensing database holds fewer
reservations, fewer overlaps are detected, and pre-emption fires less. It fires 0, 1 and 2 times
at 40, 60 and 80 UEs, so the test moved to 60. Link-level PRR moved 0.926 → 0.890 for the same
reason.

PRR-versus-distance also became **sharper**: 0.42 at 300–400 m where the placeholder gave 0.61,
then a cliff. That is the real LDPC waterfall (about 1 dB wide) replacing a logistic that smeared
the transition over roughly 10 dB. The shape is now the channel's, not the curve-fit's.

### PSCCH SINR is not a bandwidth advantage — that was a bug
It is tempting to give PSCCH a noise advantage of `10*log10(L_subCH*subchSizeRb/pscchPrb)`
because it occupies fewer PRBs. **It does not have one.** At fixed total transmit power the
spectral density is constant, so signal and noise shrink together with the band and the SNR is
identical — this model predicted 4.8 dB on paper and measured 0.0 dB, which is the correct
answer. Control reaches further than data because of its far lower effective **code rate**, so
`+sls/` decodes SCI at `pscchEffectiveMcs` (the most robust point of the MCS table) rather than
at the signalled MCS. An earlier version used a flat `sciSinrAdvantageDb = 6` fudge; it is gone.

The separate PSCCH SINR is still computed, and is **not** redundant, because *interference*
differs even when noise does not: an interferer overlapping only part of the PSSCH still covers
all of the PSCCH's sub-channel, or none of it. Measured: a one-sub-channel interferer aligned
on the victim's lowest sub-channel gives PSSCH 5.06 dB and PSCCH −3.91 dB.

### The SCI reservation fields are encoded, and sensing is fed from the decode
`trivEncode`/`frivEncode`/`reservationPeriodIndex` fill SCI-1A's TRIV, FRIV and reservation
period; the receiver runs `trivDecode`/`frivDecode` and feeds
`phy.ts38214.sensingDbRecord` from **those** values, not from the transmitter's state. A
sensing database populated from a genie cannot be wrong about a reservation, so it cannot show
what an undecoded SCI costs — and announcing the reservation is the entire reason sensing
works.

Wiring the fields exposed a real spec violation in the selection policy: **TRIV can signal a
chained resource only 1..31 logical slots after the anchor**, while the selection window is
bounded by the PDB and is routinely hundreds of slots wide. Drawing each resource independently
produced a grant no conformant UE could announce — and nothing noticed, because a simulator
that never builds the SCI never discovers the field will not hold the value.
`phy.rx.policy.resourcePickChained` now draws the anchor freely and every chained resource from
the anchor's reachable window only, degrading N rather than failing when nothing is in reach.

### Clause 5.22.1.2a: re-evaluation and pre-emption
Both run **before** clause 5.22.1.2's reselection check, because they are what can make a grant
unusable: a resource failing either clears the grant, and the reselection check then sees "there
is no selected sidelink grant" and reselects. Running them after would let a doomed grant
survive one more period. `kpi.nReeval` and `kpi.nPreempt` report the counts.

**The check runs at exactly `m - T_3`, not anywhere in `[m - T_3, m)`.** This is correctness,
not performance. The comparison asks "is my reserved resource still in S_A?", and S_A is
enumerated over `[n + T1, n + T2]` with `T1 >= T_proc,1 = T_3`. A resource *closer* than T_3 to
now cannot appear in any legal candidate set — not because it is bad, but because it is too soon
to select anything there. Checking later makes every resource look excluded.

**Only the resources due at that instant are passed in.** Both modules re-derive due-ness from
`currentSlot >= grantSlot - T3`, which is also true for every resource **already in the past** —
and a past resource can never appear in a candidate set built forward from now, so it gets
flagged every time. Filtering to the due subset is what makes the modules' own due test agree
with the caller's rather than fight it.

Both bugs had the same quiet symptom: **transmissions per delivery collapsed to 1.00**, because
no grant survived long enough to reach its own retransmission opportunity, while delivery still
mostly worked and every other KPI looked plausible. The test pins `tx/delivery > 1.8`.

`signalled` is the exact partition between the two checks — resources **not yet** announced go to
re-evaluation, **already** announced to pre-emption, and the two never merge. For a periodic
grant: the anchor is announced by the *previous* period's SCI through the reservation-period
field, so it is signalled from the second period onward; the chained resources are announced by
*this* period's anchor SCI, so they become signalled when that transmission goes out. That is a
model of the announcement, not a quotation — the clause defines `m` per resource and leaves the
bookkeeping to the implementation.

**Pre-emption cannot fire in a single-priority population, and that is correct.** The comparison
is strict (`+mac/CLAUDE.md`: equal priorities must not pre-empt, or two UEs pre-empt each other
indefinitely and neither transmits). So `scen.prioByUe` is a per-UE *vector*: leaving priority a
scalar would make that structural impossibility indistinguishable from a wiring bug. Measured on
one seed and geometry, 40 UEs: uniform priority gives 0 pre-emptions, a quarter of the UEs
raised to priority 1 gives 2.

**Simplification, stated rather than hidden:** the whole grant is cleared and reselected instead
of replacing only the offending resource. `+mac/CLAUDE.md` lists "which replacement to pick after
re-evaluation or pre-emption" among the `+phy/+rx/+policy/` decisions that are not built, and
this is that gap. Clearing everything is conservative — it never keeps a resource the clause says
to drop — but it discards good resources with the bad, costing more reselections than a
conformant UE would perform.

### Five bugs that only a longer, harder run exposed
All five passed every short-run test and every KPI sanity check. Recorded because each has a
quiet signature rather than an error.

1. **The counter was never re-drawn on the keep branch.** See `+mac/CLAUDE.md`. Symptom: 18 of
   20 counters sitting at 0 after 6 s; reselection silently stops after the first keep.
   `mac.grantOnKeep` is the missing bullet. It runs **before** the data-availability return in
   `macPhase`, because a periodic grant's counter is maintained whether or not there is
   anything to send — gating it on pending data leaves the counter parked through idle periods.
2. **The reservation-period reference was read off `grant.txOppSlot(1)`.** Clause 5.22.1.2a's
   replacement re-sorts the grant and can put a new resource *earlier* than the old anchor, so
   the reference moved and the period index jumped with it — firing `grantOnPeriodEnd` the
   wrong number of times and decrementing the counter at the wrong rate. Now `ue.periodRefSlot`,
   fixed at selection.
3. **Flagged resource indices went stale mid-loop.** Each `grantReplaceResource` re-sorts, so an
   index captured before the first replacement points at a different resource after it: the
   second replacement swapped out a good resource and left the flagged one in place. Resources
   are now addressed by **slot**, re-found after every replacement.
4. **The HARQ process was keyed off `nextPktId`.** That is not a cycle — `nextPktId` advances on
   *generation* — so a TB built while an earlier one was still in flight could land on the same
   process and overwrite its buffer, losing the packets riding it. Now a round-robin that skips
   processes with unresolved contexts, and declines to transmit when all are occupied.
5. **`harqNewTransmission` was called with `feedbackEnabled = false` unconditionally**, so in
   unicast the HARQ entity believed every process was feedback-disabled while the SCI said
   otherwise. Now follows the cast type: 4 of 4 processes enabled in unicast, 0 of 4 in
   broadcast.

Plus one that did raise, honestly: **`maxEscalations` was a round 10.** Clause 8.1.4 step 7
climbs 3 dB per round until S_A reaches `sl-TxPercentage` of M_total, so the bound has to clear
the strongest signal any UE can sense. A 20 m neighbour at P_CMAX sits ~50 dB above a −110 dBm
threshold, and 10 rounds is 30 dB. `scenarioInit` now derives it from the deployment's closest
separation (18 for this scenario). The bound raising was it working correctly and reporting
that it had been set too low.

### Congestion control — CBR, CR and clause 8.1.6
The full chain runs: `phy.ts38215.cbr` over a rolling per-sub-channel RSSI window,
`phy.ts38214.cbrRangeIndex` to a CBR level, `phy.ts38215.cr` over the UE's own occupancy, and
`phy.ts38214.congestionControlCheck` for the limit. `kpi.cbrMean`, `kpi.cbrMax` and
`kpi.nCongestionDrop` report it.

- **MEASURE runs after RX, and that ordering is load-bearing.** The CBR window is `[n-a, n-1]`,
  so slot n's measurement is written *after* slot n's transmissions are evaluated and read by
  slot n+1's transmit decision. Measuring before RX would put slot n inside its own window.
- **An unmonitored slot is NaN, not idle.** A UE that transmitted measured nothing, and
  `phy.ts38215.cbr` reads NaN as "not measured". Scoring it idle would make a busy channel look
  emptier the busier it gets, since a UE transmits more when it has more to send.
- **CBR counts everyone; CR counts only this UE.** That is the whole difference between them.
  `usedHistory` records the UE's own occupied sub-channels per slot and nothing else —
  including other UEs' transmissions there would throttle a UE against traffic that is not its
  own.
- **The limit is normative, the response is not.** `congestionControlCheck` reports;
  `phy.rx.policy.congestionDrop` decides. Clause 8.1.6's closing sentence — "It is up to UE
  implementation how to meet the above limits, including dropping the transmissions in slot n"
  — is the split. Dropping is the bluntest response it permits; lowering the MCS, taking fewer
  sub-channels, or dropping only the retransmission all spend less channel without losing the
  packet, and all need a feedback path from the measurement into the selection policy that does
  not exist yet.
- **Congestion drops are counted separately from losses.** A packet the UE *chose* not to send
  is a different thing from one the channel destroyed, and the two are indistinguishable in a
  PRR figure — so a hard-throttling policy would otherwise read as a bad radio link.

Measured: CBR 0.026 / 0.059 / 0.067 / 0.072 at 10 / 30 / 60 / 100 UEs, and tightening the CR
limit gives a monotone response — 0, 243 and 332 drops at limits 1.0, 0.001 and 0.0005, with
goodput falling with each.

### `sl-PrioritisedBitRate` was 0, which made the token buckets inert
LCP's first pass is `SBj`-limited. With `sl-PrioritisedBitRate` at 0 the buckets never rise
above zero, that pass allocates nothing, and every byte is served by clause 5.22.1.4.1.3's
second ("regardless of the value of SBj") pass. **The totals still come out right**, so nothing
looks wrong — the prioritised-bit-rate mechanism that is the point of clause 5.22.1.4.1 is
simply not running. `mac.slLcpBucket` is now called once per slot, and the scenario configures
one CAM's worth of PBR with a 100 ms bucket.

### `harqFlush` — clause 5.22.1.3.1's fourth flush condition
An initial-transmission opportunity arriving with nothing to send flushes the buffer
("3> else: 4> flush the HARQ buffer"). Without it the *previous* MAC PDU stays in the buffer
and is retransmitted at this period's retransmission opportunity — a stale TB sent again under
a fresh grant, wasting the resource and delivering a duplicate whose packets were already
resolved.

### The two reliability figures, which are different numbers
- **`kpi.prr` is packet-level:** a packet counts as delivered if *any* receiver decoded it.
  This is what closes a latency figure — a packet has one latency, not one per listener — and
  it is the weakest possible reliability statement. In any dense scenario it reads **1.0
  regardless of the channel**, because the nearest neighbour always decodes. A 50-UE run over a
  channel whose links fail past 400 m still reports `prr = 1.0000`.
- **`kpi.prrByDistance` / `kpi.prrLink` are per-link:** of the receivers that could have heard a
  transmission, what fraction did. Half-duplex slots are excluded from the denominator — a UE
  that was transmitting did not *fail* to receive, it was never a link.

Both are reported and never conflated. Reporting only the first is how a simulator claims
perfect reliability over a channel that is failing most of its links.

### The path loss model is modular, and RMa is the default
Two functions are the whole interface: `harness.chanmodel.pathlossModel(name, params)`
**constructs** a descriptor and `harness.chanmodel.pathloss(model, d)` **evaluates** it. Nothing
else in the tree calls a path loss implementation directly, and none is reachable except through
those two. Adding TR 37.885's V2V models means one implementation file and one `case` — no
caller changes. `scen.radio.plModel` carries the descriptor; the loose `plExponent` /
`plRefDistM` fields are gone, because two sources of truth for one quantity is one too many, and
`test_chanmodel` asserts they have not come back.

| Model | Source |
|---|---|
| `rma` | TR 38.901 clause 7.4.1 Table 7.4.1-1, via the 5G Toolbox's `nrPathLoss` |

**The hand-rolled `logdistance` placeholder has been removed**, not deprecated. It was never the
default once RMa landed, but it remained *selectable* — and a placeholder that can still be
chosen is one that will eventually be chosen, most likely by a scenario copied from an older
one. The only path through `pathlossModel` is now a 3GPP model. The dispatcher stays with one
model behind it: its job is the module boundary, not the choice, and TR 37.885's V2V models
will be one implementation file and one `case`.

The comparison figures below are kept as a record of what the change was worth; the
`logdistance` row cannot be reproduced without restoring the deleted file.

There is no TR 38.901 PDF in `Documentations/`, so the model is taken from the toolbox rather
than transcribed from recall — the same discipline `+cfg/pqiTable.m` applies to its TS 23.287
rows, resolved the other way because here an implementation exists.

**RMa is a CELLULAR model on a V2V geometry.** It describes a base station (10–150 m) to a UE;
a V2V link is two vehicles at ~1.5 m, outside its range on the transmitter side. The LOS branch
tolerates it — path loss at 300 m moves 0.5 dB between a 1.5 m and a 35 m transmitter — but
tolerating is not validating. Measured end to end, 50 UEs on a 1 km line:

| Model | link PRR | PRR at 400–600 m | CBR |
|---|---|---|---|
| RMa LOS | 0.907 | 0.94 | 0.132 |
| `logdistance` | 0.545 | 0.04 | 0.067 |
| **RMa NLOS** | **0.060** | **0.00** | 0.006 |

RMa NLOS gives no communication past the nearest neighbour — 175 dB by 1 km at a 1.5 m
transmitter. That is a model far outside its fitted geometry, not a usable pessimistic bracket.
Use LOS; NLOS exists because the mode is part of the model.

**LOS is fixed, not drawn per link.** TR 38.901 Table 7.4.2-1 gives a distance-dependent LOS
probability and there is no local PDF to extract it from, so a fixed mode is stated rather than
a recalled formula quietly applied.

**TR 37.885's V2V Urban and Highway are the models a sidelink study should use.** No local PDF,
no toolbox implementation. RMa is a real, documented, standards-based model and a large
improvement on a hand-rolled curve; it is still not the right model. Both are true, and the
second is the one that gets forgotten once a number is in a plot.

**A better channel changes what the test scenario must be.** The PRR-versus-distance shape test
ran on 50 UEs at 20 m — a 1 km line, enough to reach the floor of the placeholder's curve. RMa
LOS reaches further and still delivers 0.34 at 800–1200 m, so that line would have tested the
scenario's length rather than the channel's shape. The test widens the spacing to 40 m: same UE
count, same runtime, 2 km span, and a full curve — 1.000 near, 0.960 at 400–600 m, 0.748 at
600–800 m, 0.172 at 800–1200 m, 0.000 beyond. The escalation bound is derived from the
*closest* separation, so it must be recomputed whenever the spacing changes.

### What is measured, and what is still a placeholder
**`blerLookup` is measured.** It reads `harness.phyabs.blerTable` — BLER measured by
`+harness/+lls/` over the real transmit chains, a real OFDM waveform, DM-RS channel estimation
and zero-forcing equalisation, with soft combining across redundancy versions. Its five-key
signature survived the switch, so no caller changed. An **off-key lookup is an error**, not a
substitution: it rejects a channel model or speed the table was not measured under, because
reading a table off-key is indistinguishable from having measured the right one.

**`psfchDetect` is still a placeholder** — a logistic with a low midpoint and a steep slope,
because a sequence detector works at SINRs where no coded block would. Reusing `blerLookup`
here would make feedback fail at roughly the same range as data, which is exactly backwards.
**Not modelled:** false alarm, and the ACK/NACK confusion from detecting the wrong shift of the
right sequence. Both are real and asymmetric — a false ACK loses a packet silently, a false
NACK only wastes a retransmission — so a real curve must report them as a pair.

**Still absent: fading, shadowing, antenna pattern**, and therefore the TDL half of B5's gate.
The BLER table is AWGN-only and says so in its own `.meta`. The link is deterministic in
distance, so a PRR-versus-distance curve carries none of the variance a real one would.

So: **link-level BLER and the abstraction that reads it are measured; the channel model is now
a documented standards model used slightly out of geometry; fading is absent.** Policy-versus-
policy comparisons on the same channel remain the soundest comparison this tree supports.

### Every packet lands in exactly one bucket
`kpiReport` asserts it. Delivered, PDB-expired, sl-MaxTransNum spent, dropped, or still in
flight — and the last is reported separately and excluded from every ratio.

The trap this closes: a packet dequeued into a transport block has **left the logical channel**,
so `sap.lchExpire` can no longer see it. Without a second expiry pass over the in-flight set it
sits unresolved forever and quietly leaves the denominator of every ratio, which flatters
reliability. It is invisible in a scenario where almost everything is delivered — a 6-UE
unicast run at 1500 m spacing reported 0 expired and 48 in flight before the fix, and 42
expired plus 6 in flight after.

`blerLookup`'s *interface* is not a placeholder: it takes all five table keys — MCS, SINR,
retransmission index, channel model, speed — even though the body reads three, precisely so
that Phase 3 changes no caller. Adding a key later means regenerating every curve.

## Superseded plan note
`poolAllSlots` — the baseline Mode-2 resource pool, in which **every slot of the DFN
period is a sidelink slot**. In Mode 2 there is no serving cell handing out a
tdd-UL-DL-ConfigurationCommon, and `BUILD.md` defers S-SSB end-to-end sync explicitly, so
nothing takes slots away and the pool is the whole period. Different pool configurations come
later; this is the one the first end-to-end runs use.

It wraps `phy.ts38214.poolSlotMap` rather than reimplementing it, and asserts that the result
is literally every slot.

### The bitmap length is load-bearing, and an all-ones bitmap is not enough
Clause 8's reserved-slot rule removes `(L mod L_bitmap)` slots **before** the bitmap is applied.
So "every slot" holds only when `L_bitmap` divides `10240*2^mu = 2^(11+mu) * 5`. Among the
lengths a configuration is likely to carry, **10, 16, 20, 40 and 160 divide it; 11, 12, 30, 50,
60 and 100 do not** — at `L_bitmap = 100` and mu = 1 an all-ones bitmap over a fully-sidelink
period still loses **80** slots, evenly spread, silently. `poolAllSlots` pins length 10, the
shortest legal value (SIZE(10..160)) that divides the period at every numerology, and asserts
the outcome so a later edit cannot quietly reintroduce the loss.

### The identity is a property of this configuration, not of the mapping
In the baseline, logical slot i **is** physical slot i. That makes the first runs easy to read,
and it is exactly the condition under which a caller that forgot to convert still produces
correct-looking output — until a real TDD pattern or S-SSB arrives. Convert through the arrays
anyway. `+test/+unit/+harness/test_poolAllSlots.m` carries a deliberately non-identity
configuration alongside the baseline for this reason, and a case showing that excluding one
slot removes ten (see `+phy/+ts38214/CLAUDE.md`).
