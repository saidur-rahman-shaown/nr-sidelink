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
`poolAllSlots` only — the baseline Mode-2 resource pool, in which **every slot of the DFN
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
