# TS 38.215 clause 5.1 — sidelink measurements (B7, before 38.214)

Small package, built immediately before sensing, because sensing cannot be validated without
it. **Sidelink aspects only** — TS 38.215 defines dozens of measurements (DL/UL RSRP, RSRQ,
SINR, PRS, SRS…) and this package implements exactly the six whose "Applicable for" row reads
*Sidelink*: clauses 5.1.22–5.1.27. Everything else in the spec is deliberately absent.

## Status: built, level-1 and level-2 tests passing.
An independent-verifier worked example (spec text only, blind to this code) **matched every
value computed** — the two-port PSSCH-RSRP sum, the single-port average, the SL RSSI
2nd-symbol exclusion, CBR's 4/7, and CR's 12/50. It nonetheless changed the code in two places
and left one disagreement on record; see the three sections below.

| Module | Clause | Notes |
|---|---|---|
| `slRsrp` | 5.1.22 / 5.1.23 / 5.1.24 | **three variants** — PSBCH-, PSSCH- and PSCCH-DM-RS-based. One definition, differing only in which DM-RS is averaged and in the antenna-port rule. Variant is an explicit input |
| `slRssi` | 5.1.25 | total received power over a sub-channel, from the 2nd OFDM symbol |
| `cbrWindowSlots` | 5.1.27 | `sl-TimeWindowSizeCBR` + µ → window length `a` |
| `crWindowSlots` | 5.1.26 NOTE 1 | `sl-TimeWindowSizeCR` + µ → total window `a+b+1` |
| `cbr` | 5.1.27 | channel busy ratio over its window |
| `cr` | 5.1.26 | channel occupancy ratio over its window |

The original plan in this file listed four modules and "two variants" of `slRsrp`. Both counts
were low: there are **three** sidelink RSRP clauses (PSBCH-RSRP, 5.1.22, matters for sync
reference selection, not just for sensing), and the two window-length lookups were split out
as their own modules because they are where numerology scaling happens and they are worth
testing independently.

## Spec version — changed during this build
`+cfg/specVersions.json` pinned TS38215 at **V16.6.0**, a recalled placeholder from when this
spec had no local PDF. It has one now, and its title page reads **V16.7.0 (2023-12)** — so the
pin was corrected, which `+cfg/CLAUDE.md` requires be an explicit decision rather than a
drive-by edit. Not cosmetic: V16.7.0's change history carries two Rel-16 CRs aimed squarely at
these clauses ("Corrections to Applicable RRC States for Sidelink Measurements", "CR on
applicability of sidelink measurements"). Every header here cites V16.7.0, the document that
was actually read.

## The one thing that matters most here
**Do not conflate the SL-RSRP variants.** Which one applies is a pool configuration choice,
they measure different reference signals, and they are not interchangeable. Conflate them once
and every PRR curve downstream is quietly wrong with no symptom that points back here. Take
the variant as an explicit input; never infer it inside the function.

`slRsrp` enforces what it can — the variant label selects the antenna-port rule, and a
multi-port grid is rejected for the two variants that define no port summation. It cannot
enforce the rest: **nothing verifies that `dmrsInd` actually came from the matching `+ts38211`
generator**, so handing PSCCH DM-RS indices to a call declaring `'pssch'` returns a plausible
wrong number in silence. Pairing the index set to the variant is the caller's obligation and
is the single easiest way to misuse this package.

## `P` is transmit ports, not receive branches
The verifier's highest-value finding, and it changed the interface documentation rather than
the arithmetic. `K x L x P` is this tree's grid convention, but for a *received* grid the third
dimension is ambiguous in a way that changes the answer:

- **Transmit DM-RS ports** (1000/1001 for PSSCH) — clause 5.1.23's "summed over the antenna
  ports" applies, so per-port averages are summed. This is what `slRsrp` implements and what
  `P` means here.
- **Receive branches** — governed by a completely different sentence, present in all of
  5.1.22/23/24/25: the reported value "shall not be lower than the corresponding [value] of
  any of the individual receiver branches". That is a **lower bound relative to the best
  branch, not a sum**.

Summing receive branches would inflate RSRP with the receive-antenna count and silently
corrupt every TS 38.214 clause 8.1.4 threshold comparison downstream. So: **branch combining
happens before these functions are called**, and the spec's bound is the caller's obligation —
38.215 supplies a bound and never a formula, so this package refuses to guess. `slRssi`
rejects `P > 1` outright for the same reason.

## Disagreement on record: the ms-vs-slot enumerands
Resolved in favour of what `cbrWindowSlots`/`crWindowSlots` implement, with the reasoning
written into `crWindowSlots.m` so it can be re-litigated rather than rediscovered:

|  | this package | the verifier's reading |
|---|---|---|
| `'ms100'` / `'ms1000'` | `100·2^µ` / `1000·2^µ` slots | `100` / `1000` slots |
| `'slot100'` / `'slot1000'` | `100` / `1000` slots | `100·2^µ` / `1000·2^µ` slots |

Clause 5.1.27 says only "a is equal to 100 or 100·2^µ slots, according to higher layer
parameter sl-TimeWindowSizeCBR" — it never names which enumerand gives which. The reading here
is dimensional: the labels name the **unit** of the window they configure, so `'ms100'` is 100
*milliseconds*, and a slot lasts `1/2^µ` ms (TS 38.211 clause 4.3.2), making 100 ms equal to
`100·2^µ` slots; `'slot100'` already counts slots and needs no conversion. The verifier's own
gloss undermines its position — it read `'ms1000'` as "1000 slots' worth of 1 ms, i.e. the
literal value 1000", which holds only at µ=0, the one numerology where the two enumerands
coincide and the question is moot. Per `+test/CLAUDE.md` the disagreement is reported, not
harmonised away. **`pending-human`**: a two-way choice with no explicit normative sentence
behind either side, and getting it backwards scales every CBR/CR window by `2^µ`.

## Taken pre-resolved, not computed here
Same pattern `+phy/+ts38214/` uses for `sl-Thres-RSRP-List`:
- **`sl-ThreshS-RSSI-CBR`** — `+cfg/resourcePool.m` stores the raw `INTEGER(0..45)` and does
  not resolve it; `cbr` takes dBm. TS 38.331's mapping is `(-112 + n*2) dBm`: −112 dBm at n=0
  through −22 dBm at n=45, no reserved codepoints.
- **The received grid itself.** These functions average what they are handed; absolute power
  calibration belongs to whatever produced the grid. No RX pipeline exists in this tree yet
  (`+phy/+ts38213/CLAUDE.md` records the same gap), so in practice the caller is a test or a
  harness with a synthetic grid.
- **The CR occupancy counts.** `cr` takes "sub-channels used" and "sub-channels granted" as
  integers; deciding what is granted is `+mac/`'s job (5.1.26 NOTE 6 defers to TS 38.321), and
  projecting the current grant across `[n+1, n+b]` (NOTE 3) is the caller's.

## What is deliberately not chosen here
`a` and `b` for CR are "determined by UE implementation" (5.1.26 NOTE 1), so picking them is a
`+phy/+rx/+policy/` decision — the same split `+phy/+ts38214/` applies to T1/T2. `cr`
*validates* a chosen split fully (a≥1, b≥0, `b < (a+b+1)/2`, and `a+b+1` equal to the
`windowSlotsTotal` from `crWindowSlots`) but chooses nothing. That last check exists because
the verifier caught its absence: an earlier version validated a, b and the halving rule but
accepted **any** window length, so the test suite's own scaled-down `a=8, b=1` fixture (total
10, conformant to nothing) would have passed as though it were a real configuration. The one
NOTE 1 constraint `cr` still cannot check is "n+b shall not exceed the last transmission
opportunity of the grant", which needs the grant itself, not just its size.

## Known traps
- **The 2nd-OFDM-symbol rule is applied inside `slRssi`, exactly once.** Clause 5.1.25 measures
  "starting from the 2nd OFDM symbol", so `slRssi` drops `slotSymbols(1)` and the caller must
  not pre-strip it. That symbol is the AGC symbol, which by construction duplicates the symbol
  after it (`+phy/CLAUDE.md`'s slot assembly order) and is measured while receiver gain is
  still settling. Strip it twice and every CBR built on top is biased; strip it never and a
  loud AGC symbol dominates the average. The verifier flagged a residual drafting ambiguity —
  "2nd of the slot" vs "2nd of the configured PSCCH/PSSCH set" — which only bites when
  `sl-StartSymbol != 0`; this package drops the first *configured* symbol, which is the reading
  that keeps the AGC symbol excluded in every case.
- **CR's window `[n-a, n+b]` is inclusive at both ends** — `a+b+1` slots, not `a+b`. NOTE 1
  confirms it by naming `a+b+1` itself. Slot `n` belongs to the *granted* half (the clause
  splits at "used in `[n-a, n-1]`" and "granted in `[n, n+b]`"), so a caller that also counts
  slot `n` as used double-counts it and inflates CR.
- **`ms`/`slot` enumerands coincide only at µ=0.** Any test written solely at µ=0 is blind to a
  swap — the same numerology-blindness that bit `+phy/+ts38214/`'s Q formula. See the
  disagreement section above.
- **"Exceed" in clause 5.1.27 is strict.** An SL RSSI landing exactly on `sl-ThreshS-RSSI-CBR`
  does not count as busy.
- **CBR is a property of the channel; CR is a property of the UE's own traffic.** CR counts
  only "its transmissions" — counting other UEs' occupancy inflates CR and throttles the UE
  against traffic that is not its own. There is no per-priority CBR; there *is* a per-priority
  CR (5.1.26 NOTE 5), and its denominator stays the whole pool over the whole window, which is
  exactly what makes TS 38.214 clause 8.1.6's `Σ_{i≥k} CR(i)` meaningful — the per-priority
  numerators partition the total, so the eight CR(i) sum to the UE's total CR.
- **CR slot indices are PHYSICAL** (5.1.26 NOTE 4), unlike TS 38.214 clause 8.1.4's logical
  pool slots. `+phy/CLAUDE.md`'s "logical-to-physical mapping applied exactly once" rule bites
  at this boundary.
- **An absent measurement is not a zero one.** `NaN` plus a sample count of 0. `CBR = NaN` must
  never be read as `CBR = 0` ("channel idle, transmit freely") — that is the boot case, before
  the first full CBR window has elapsed.

## Interface rules
- Every measurement takes its window from `+cfg/`, scaled by numerology. No literal window
  lengths. `cbrWindowSlots`/`crWindowSlots` are where that scaling happens —
  `+cfg/private/resolveEnum.m` deliberately keeps `sl-TimeWindowSizeCBR`/`CR` as their raw
  *labels* because "units differ per label (ms vs slot)" and only this package knows the µ.
- Measurements return a value plus the number of samples it was computed from. A measurement
  over an empty window is not zero; it is absent.
- Values are returned in **both W and dBm**. The clauses define these quantities in [W], but
  every consumer in this tree is dBm-based (`sensingDbRecord` takes RSRP in dBm;
  `sl-Thres-RSRP-List` and `sl-ThreshS-RSSI-CBR` are both dBm), and a silent W-vs-dBm mix-up
  across that boundary is exactly the "quietly wrong with no symptom" failure above.

## Tests
`+test/+unit/+phy/+ts38215/test_measurements.m`. Synthetic grids with known per-RE power, so
every expected value is a hand computation rather than a regression capture:
- `slRsrp`: the two-port PSSCH case where the correct sum-of-per-port-averages (5 W) and a
  joint average over all (port, RE) pairs (2.5 W) differ; a single-port uneven-power case
  proving the average is over `|RE|²` and not `|RE|`; the empty-index-set absent case; and
  rejection of a multi-port grid for a variant with no port summation.
- `slRssi`: an AGC symbol loaded 50× hotter than the rest, so including it gives 26.5 W against
  the correct 2 W — a 13× error, chosen because this exclusion is easy to drop and easy to
  apply twice. Plus a sub-channel offset case (PRB 2 must read subcarriers 24–35), an
  all-REs-count case (empty REs drag the average down, they are not skipped), and the
  single-symbol region that becomes absent once the rule is applied.
- `cbr`: the strict-inequality boundary in isolation, a NaN sample leaving *both* numerator and
  denominator, and the all-NaN window reporting absent rather than idle.
- `cr`: a conformant 1000-slot window as the primary case, the `a+b+1` vs `a+b` denominator
  isolated on a small window where they differ visibly (50 vs 45), `b=0`, all three NOTE 1
  rejections, and per-priority CRs summing to the total.
- `cbrWindowSlots`/`crWindowSlots`: both labels at µ=0 where they coincide, and at µ≥1 where
  they do not.

## `pending-human` per +test/CLAUDE.md level 2
Four items, all flagged by the verifier as inference rather than quotation:
1. **The ms-vs-slot enumerand mapping** (see the disagreement section) — the only one where the
   verifier and this package actually differ, and the one with the largest blast radius.
2. **CBR's denominator granularity.** Clause 5.1.27 says "portion of sub-channels … sensed over
   a CBR measurement window" without spelling out the denominator. This package counts
   (slot, sub-channel) *samples* across the window, since SL RSSI is defined per sub-channel
   per slot and so a sub-channel has no single RSSI over a window. A per-sub-channel reading
   (denominator = sub-channel count alone) is grammatically available.
3. **NaN / unsensed samples.** 5.1.27 says nothing at all about slots the UE could not measure
   — no exclusion rule, no substitution. Excluding them from both numerator and denominator
   keeps CBR an unbiased estimate and avoids counting the UE's own transmission as busy or
   idle, but a UE that treated its own TX slots as busy would not be textually violating the
   clause.
4. **Per-priority CR's denominator** (5.1.26 NOTE 5 is a one-line stub). Priority-independence
   is derived from "configured … in the transmission pool" plus the 38.214 clause 8.1.6
   summation-consistency argument, not from explicit text.

## Gate
All three RSRP variants match their worked examples independently. CBR and CR match
hand-computed occupancy patterns including the window edges. Met, and cross-checked
independently — subject to the four `pending-human` items above.
