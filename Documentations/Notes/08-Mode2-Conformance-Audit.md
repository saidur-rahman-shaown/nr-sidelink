# Mode-2 Sensing — Conformance Audit of `Version 3`

Audited against the 20-item checklist in
[06-Mode2-Sensing-WORKING-REFERENCE.md](06-Mode2-Sensing-WORKING-REFERENCE.md#14-implementation-checklist).

**Code audited:** `../../Version 3/mac/SidelinkMode2Scheduler.m`,
`SidelinkSchedulerBase.m`, `mac/sidelink_modules/SidelinkResourceSelection.m`.

---

## Headline

There are **two** Mode-2 implementations in the tree, and the more spec-faithful
one is not the one that runs.

| | `SidelinkMode2Scheduler.m` | `SidelinkResourceSelection.m` |
|---|---|---|
| Role | the active scheduler | static helpers |
| Called from | MAC, all experiments | only `SCIGenerator.m:521–524` |
| Candidate set | raw slot offsets | correct — iterates `slotPool` |
| `T_proc,0/1` tables | absent | correct (Tables 8.1.4-1/-2) |
| `X · M_total` test | hardcoded `X = 0.2` | correct, `X` is a parameter |
| `P'_rsvp` conversion | absent | correct (§8.1.7) |
| CR limit | absent | implemented but **never called** |

The helper class already encodes several things the scheduler gets wrong. Wiring
the scheduler to it closes a large share of the gap.

---

## Item-by-item

Legend: ✅ conformant · ⚠️ approximated · ❌ absent

| # | Requirement | Status | Evidence |
|---|---|---|---|
| 1 | Sensing window `[n−T_0, n−T^SL_proc,0)` | ⚠️ | `SidelinkSchedulerBase.m:161` keeps `SlotNum ≥ n − windowSlots`, i.e. `[n−T_0, n]`. The `−T^SL_proc,0` guard is missing, so the UE senses slots it could not physically have processed yet. |
| 2 | Own-Tx slots excluded (half-duplex) | ❌ | No filtering of own transmissions anywhere in `updateSensingData`. |
| 3 | `T_1 ≤ T^SL_proc,1` | ❌ | `SelectionWindowMin = 1` fixed (`SidelinkSchedulerBase.m:49`); never derived from SCS. |
| 4 | `T_2` clamped by `T_2min` and PDB | ❌ | `SelectionWindowMax = 32` fixed (line 50). No PDB input reaches the scheduler. |
| 5 | Logical pool slots throughout | ❌ | `buildCandidateSet` (line 283) iterates `SelectionWindowMin:SelectionWindowMax` as *physical* slot offsets. `initCandidates` does this correctly but is unused. |
| 6 | `Th` from `sl-Thres-RSRP-List`, `i = p_i+(p_j−1)×8` | ⚠️ | `SidelinkMode2Scheduler.m:198–200` uses `threshold + 3×(OwnPriority − Priority)` — a linear model standing in for the 64-entry table. The comment says as much. `sl-Thres-RSRP-List` **is** available in [file 04](04-TS38331-RRC-ASN1-IEs-and-Messages.md). |
| 7 | RSRP source honours `sl-RS-ForSensing` | ❌ | Single `sd.RSRP_dBm` field; no PSSCH-RSRP / PSCCH-RSRP distinction. |
| 8 | Step 5 unmonitored-slot exclusion | ❌ | Not implemented. `applySensingExclusion` covers step 6 only. This is the exclusion that charges the UE for half-duplex blindness. |
| 9 | Step 5a re-init when `\|S_A\| < X·M_total` | ❌ | No re-initialisation before step 6. |
| 10 | Step 6c overlap over `q` **and** `j = 0…C_resel−1` | ⚠️ | Line 207: `reservedSlots = sd.SlotNum + (0:10)*sd.ReservationPeriod` — the sensed side repeats a hardcoded 11 times; **our own** candidate's `C_resel` future repetitions are never projected. Under-excludes. |
| 11 | `Q` formula incl. `n'−m ≤ P'_rsvp_RX` guard | ❌ | Hardcoded `0:10` in place of `Q = ceil(T_scal / P'_rsvp_RX)`. |
| 12 | Step 7 `+3 dB`, loop back to step 4 | ⚠️ | Lines 96–104 do loop, **but**: (a) `threshold < -70` is an invented cap with no basis in §8.1.4; (b) line 98 resets `excludeFlags` and re-applies *only* sensing — occupancy and IUC exclusions are silently dropped after the first iteration. |
| 13 | Random selection from `S_A`, equal probability | ✅ | Line 122, `randi` over surviving candidates. |
| 14 | Counter draw incl. `<100 ms` branch | ⚠️ | `randi([5 15])` is right for `P_rsvp ≥ 100 ms`; the `5×⌈100/max(20,P_rsvp)⌉` scaling branch is absent. |
| 15 | `sl-ProbResourceKeep` grant-keep path | ✅ | `SidelinkSchedulerBase.m:124`. |
| 16 | All seven reselection triggers | ⚠️ | Counter-expiry and no-grant are handled; the other five (pool reconfig, 1-second inactivity, `sl-ReselectAfter`, SDU-too-large, PDB-not-met) are not. |
| 17 | Re-evaluation at `T_3` | ❌ | Absent from the MAC entirely. |
| 18 | Pre-emption at final threshold | ❌ | Absent. |
| 19 | `C_resel = 10 × counter` | ❌ | The property named `Cresel` is the *counter range* `[5 15]`, not `C_resel`. The ×10 factor never appears, so reservations are modelled 10× shorter than the spec. |
| 20 | CR limit `Σ_{i≥k} CR(i) ≤ CR_Limit(k)` | ❌ | `checkCongestion` exists (`SidelinkResourceSelection.m:129`) but has **no callers**. |

**Tally:** 2 conformant, 6 approximated, 12 absent.

---

## What this does to the KPIs

The deviations are not neutral — they bias in a consistent direction.

- **Items 2, 8 absent** → the UE is never penalised for slots it could not hear.
  Half-duplex collisions are under-counted, so **PDR and PRR read optimistically**,
  and the error grows with UE density — exactly the regime Experiments 3 and 4
  target.
- **Items 10, 11, 19 absent/approximate** → periodic reservations are projected
  over the wrong horizon (10 fixed repetitions instead of `C_resel`, which the
  spec puts at `10 × [5,15]` = 50–150). Sensing therefore **misses most future
  collisions** on long-lived SPS grants.
- **Item 5** → mixing physical and logical slots misplaces every window boundary
  whenever the pool is not fully contiguous in time.
- **Item 12(b)** → after the first 3 dB bump, multi-UE occupancy exclusion
  vanishes. In dense runs the scheduler silently degrades toward random selection.
- **Item 20 absent** → no congestion control, so **CBR/CR never bound the
  offered load**. Throughput at high density is unconstrained.

Net: the current results are best read as a **sensing-assisted lower bound on
collisions**, not as Rel-16 Mode-2 conformant behaviour. Density and bandwidth
sweeps are the most affected; the 2-UE distance sweeps (Experiment 1) are largely
unaffected, since with two UEs there is little to sense.

---

## Suggested order of work

Grouped so each stage is independently testable.

**Stage A — correctness of the existing path** (small, high value)
1. Item 12(b): recompute occupancy/IUC exclusions inside the threshold loop, and
   drop the `-70` cap. *(bug fix, ~10 lines)*
2. Item 19: introduce `C_resel = 10 × counter` and use it for reservation horizon.
3. Item 6: replace the linear priority model with a real 64-entry
   `sl-Thres-RSRP-List` lookup.
4. Item 14: add the `<100 ms` counter-scaling branch.

**Stage B — the missing exclusion steps** (this is what moves the KPIs)
5. Item 2: record own-Tx slots; exclude them from sensing.
6. Item 8: implement step 5, incl. the hypothetical-SCI test.
7. Item 9: implement step 5a.
8. Items 10–11: implement the real `Q` and the `j = 0…C_resel−1` projection.

**Stage C — windows on a proper time base**
9. Items 3–5: derive `T_1`/`T_2` from `T^SL_proc,1`, `T_2min` and remaining PDB;
   move the candidate set onto logical pool slots by adopting
   `SidelinkResourceSelection.initCandidates`.
10. Item 1: add the `−T^SL_proc,0` guard.

**Stage D — feedback loops**
11. Items 17–18: re-evaluation and pre-emption.
12. Item 20: wire `checkCongestion`; needs CBR, which needs **TS 38.215** — see
    the gap list in [00-INDEX.md](00-INDEX.md#1-ts-38215--missing-entirely-no-pdf-no-notes-).
13. Item 16: the remaining reselection triggers.

Stages A and B together should be enough to make the density results defensible.
Stage D item 12 is blocked until TS 38.215 is obtained.
