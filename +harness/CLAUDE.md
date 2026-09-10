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

### What is a placeholder, stated so no result is misread
- **`pathlossDb`** is log-distance with an exposed exponent. TR 37.885 — which carries the V2X
  models this should use — has **no local PDF**; `+cfg/specVersions.json` lists TS37885 among
  the unverified placeholders, so transcribing one from recall would only make it look
  authoritative. Same discipline `+cfg/pqiTable.m` applies to its TS 23.287 rows.
- **`blerLookup`** is a logistic whose midpoint rises with MCS. Right shape, invented numbers.
- No fading, no shadowing, no antenna pattern.

- **`psfchDetect`** is a logistic with a low midpoint and a steep slope, because a sequence
  detector works at SINRs where no coded block would. Reusing `blerLookup` here would make
  feedback fail at roughly the same range as data, which is exactly backwards. **Not modelled:**
  false alarm, and the ACK/NACK confusion from detecting the wrong shift of the right sequence.
  Both are real and asymmetric — a false ACK loses a packet silently, a false NACK only wastes a
  retransmission — so a real curve must report them as a pair.

**Comparisons between policies on the same channel are meaningful. Absolute PRR-versus-distance,
latency and throughput numbers are not, until Phase 3 replaces both with measured curves.**

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
