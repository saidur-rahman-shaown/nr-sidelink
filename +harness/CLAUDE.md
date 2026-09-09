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

**Comparisons between policies on the same channel are meaningful. Absolute PRR-versus-distance,
latency and throughput numbers are not, until Phase 3 replaces both with measured curves.**

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
