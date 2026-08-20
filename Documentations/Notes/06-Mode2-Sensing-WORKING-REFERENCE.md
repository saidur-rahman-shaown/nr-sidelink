# Mode-2 Sensing & Resource Selection — Working Reference

> **Purpose:** the one page to implement and verify sensing-based Mode-2 against.
> Consolidates TS 38.214 §8.1.4/§8.1.6/§8.1.7/§8.4.2.1, TS 38.321 §5.22.1.1/§5.22.1.2/§5.22.1.2a,
> and the TS 38.331 IEs that parameterise them.
>
> **Why this file exists:** in the raw paste of TS 38.214, clause 8.1.4 lost every
> subscript and superscript — `T^SL_proc,0` became `𝑇𝑝𝑟𝑜𝑐,0` on one line and `𝑆𝐿` on the
> next — and every table collapsed into an unlabelled run-on of numbers
> (Table 8.1.4-1 survives only as `... 0 1 1 1 2 2 3 4`, with no way to tell rows
> from columns). Everything below is re-derived from the source PDF
> (`../38214-gh0.pdf`, pp. 160–164) with the math and the table grids restored.
> Symbols use `X_sub^sup` ASCII form so they survive copy/paste into MATLAB.

---

## Contents

- [1. Symbol table](#1-symbol-table)
- [2. Trigger: when selection runs (MAC)](#2-trigger-when-selection-runs-mac)
- [3. Inputs from higher layers](#3-inputs-from-higher-layers)
- [4. The selection window (step 1)](#4-the-selection-window-step-1)
- [5. The sensing window (step 2)](#5-the-sensing-window-step-2)
- [6. RSRP threshold table (step 3)](#6-rsrp-threshold-table-step-3)
- [7. Exclusion: unmonitored slots (steps 4–5a)](#7-exclusion-unmonitored-slots-steps-45a)
- [8. Exclusion: sensed reservations (step 6)](#8-exclusion-sensed-reservations-step-6)
- [9. Threshold adaptation and report (step 7)](#9-threshold-adaptation-and-report-step-7)
- [10. Re-evaluation and pre-emption](#10-re-evaluation-and-pre-emption)
- [11. Reselection counter and grant reuse (MAC)](#11-reselection-counter-and-grant-reuse-mac)
- [12. Congestion control: CBR / CR](#12-congestion-control-cbr--cr)
- [13. Timing constants (all tables)](#13-timing-constants-all-tables)
- [14. Implementation checklist](#14-implementation-checklist)

---

## 1. Symbol table

| Symbol | Meaning | Source |
|---|---|---|
| `n` | slot in which higher layers trigger resource selection | 38.214 §8.1.4 |
| `T_0` | sensing window length, in slots (from `sl-SensingWindow`, msec) | §8.1.4 |
| `T^SL_proc,0` | sensing processing time, slots — [Table 8.1.4-1](#13-timing-constants-all-tables) | §8.1.4 |
| `T^SL_proc,1` | selection processing time, slots — [Table 8.1.4-2](#13-timing-constants-all-tables) | §8.1.4 |
| `T_1` | start of selection window, `0 ≤ T_1 ≤ T^SL_proc,1` | §8.1.4 |
| `T_2` | end of selection window, bounded by `T_2min` and remaining PDB | §8.1.4 |
| `T_2min` | min selection window, from `sl-SelectionWindowList(prio_TX)` | §8.1.4 |
| `T_3` | re-evaluation / pre-emption lead time, `= T^SL_proc,1` | §8.1.4 |
| `L_subCH` | number of contiguous sub-channels per candidate resource | §8.1.4 |
| `R_x,y` | candidate single-slot resource: sub-channels `x…x+L_subCH−1` in slot `t'^SL_y` | §8.1.4 |
| `S_A` | surviving candidate set, reported to higher layers | §8.1.4 |
| `M_total` | total number of candidate single-slot resources | §8.1.4 |
| `X` | required survivor ratio, from `sl-TxPercentageList(prio_TX)` | §8.1.4 |
| `Th(p_i,p_j)` | RSRP exclusion threshold for priority pair | §8.1.4 |
| `prio_TX` / `prio_RX` | L1 priority of own Tx / of decoded SCI | §8.1.4 |
| `prio_pre` | pre-emption priority threshold, from `sl-PreemptionEnable` | §8.1.4 |
| `P_rsvp_TX` / `P_rsvp_RX` | reservation interval, msec (own / sensed) | §8.1.4 |
| `P'_rsvp` | same interval converted to **logical slots** | §8.1.7 |
| `C_resel` | number of reserved periods, `= 10 × SL_RESOURCE_RESELECTION_COUNTER` | §8.1.5 |
| `t'^SL_i` | i-th slot **belonging to the resource pool** (logical slot index) | §8.1.4 |
| `T'_max` | number of slots belonging to the resource pool in 10240 ms | §8.1.7 |

> **The single most common implementation bug:** `t'^SL` indices are *logical
> pool slots*, not physical slots. Every window bound, reservation period and
> overlap test in §8.1.4 is expressed in logical slots. Convert once, at the
> boundary, and never mix the two.

---

## 2. Trigger: when selection runs (MAC)

Resource (re-)selection is triggered by the **TX resource (re-)selection check**,
TS 38.321 §5.22.1.2. Any one of these fires it:

1. `SL_RESOURCE_RESELECTION_COUNTER == 0` **and** when it was 1, the UE drew
   a uniform value in `[0,1]` **above** `sl-ProbResourceKeep`; or
2. the pool is (re)configured by RRC; or
3. there is no selected sidelink grant on the pool; or
4. no (re)transmission occurred on the grant during the **last second**; or
5. `sl-ReselectAfter` is configured and the count of consecutive unused
   transmission opportunities equals it; or
6. the grant cannot fit an RLC SDU at `sl-MaxMCS-PSSCH` and the UE chooses not
   to segment; or
7. the grant cannot meet the remaining PDB and the UE chooses not to fall back
   to a single MAC PDU.

On trigger: clear the selected grant, then run the §8.1.4 procedure.

---

## 3. Inputs from higher layers

Provided by MAC in slot `n` (38.214 §8.1.4):

- the resource pool to report from;
- `prio_TX` (L1 priority);
- the remaining packet delay budget;
- `L_subCH`, sub-channels per slot;
- optionally `P_rsvp_TX` in msec;
- for re-evaluation: a set `(r_0, r_1, r_2, …)`;
- for pre-emption: a set `(r'_0, r'_1, r'_2, …)`.

RRC parameters that shape it (`SL-ResourcePool` / `SL-UE-SelectedConfig`, 38.331 §6.3.5):

| Parameter | Effect |
|---|---|
| `sl-SensingWindow` | `T_0` (msec → slots) |
| `sl-SelectionWindowList` | `T_2min` per `prio_TX` |
| `sl-Thres-RSRP-List` | 64-entry threshold table → `Th(p_i,p_j)` |
| `sl-RS-ForSensing` | `'pssch'` → PSSCH-RSRP, `'pscch'` → PSCCH-RSRP |
| `sl-ResourceReservePeriodList` | allowed reservation periods (also used for the hypothetical-SCI test in step 5) |
| `sl-TxPercentageList` | `X` per `prio_TX` (percentage → ratio) |
| `sl-PreemptionEnable` | absent / `'enabled'` / else `prio_pre` |
| `sl-MultiReserveResource` | whether a reservation may point beyond the current TB |

---

## 4. The selection window (step 1)

A candidate single-slot resource `R_x,y` is `L_subCH` contiguous sub-channels
(`x+j`, `j = 0 … L_subCH−1`) in pool slot `t'^SL_y`. Every such set inside

```
[ n + T_1 , n + T_2 ]
```

is one candidate. Bounds:

```
0 ≤ T_1 ≤ T^SL_proc,1                          (UE implementation choice)

if T_2min < remaining PDB (in slots):
    T_2min ≤ T_2 ≤ remaining PDB               (UE implementation choice)
else:
    T_2 = remaining PDB (in slots)
```

`M_total` = total number of candidates in the window.

> `T_1` is a *processing-delay floor*, not a free parameter: the UE cannot act on
> sensing results sooner than `T^SL_proc,1`. Setting `T_1 = 0` in a simulator
> silently grants zero-latency processing.

---

## 5. The sensing window (step 2)

```
[ n − T_0 , n − T^SL_proc,0 )        ← right end is EXCLUSIVE
```

- `T_0` comes from `sl-SensingWindow` (typically 100 ms or 1100 ms).
- The UE monitors every slot of the pool in this window **except slots where it
  transmitted itself** (half-duplex: it cannot sense while transmitting).
- Decisions in later steps use only PSCCH decoded and RSRP measured in these slots.

---

## 6. RSRP threshold table (step 3)

```
Th(p_i, p_j) = sl-Thres-RSRP-List[ i ],    i = p_i + (p_j − 1) × 8
```

where `p_i` = `Priority` field of the received SCI format 1-A, and `p_j` = own
`prio_TX`. Priorities are 1…8, so the list has 64 entries.

**RSRP measurement (§8.4.2.1)** — which one depends on `sl-RS-ForSensing`:

- `'pssch'` → **PSSCH-RSRP**, over the PSSCH DM-RS REs, per the received SCI format 1-A;
- `'pscch'` → **PSCCH-RSRP**, over the PSCCH DM-RS REs of the PSCCH carrying that SCI.

---

## 7. Exclusion: unmonitored slots (steps 4–5a)

**Step 4.** Initialise `S_A` = all candidate single-slot resources.

**Step 5.** Exclude `R_x,y` if **both** hold:

- the UE did not monitor slot `t'^SL_m` in step 2; **and**
- for *any* periodicity in `sl-ResourceReservePeriodList`, a **hypothetical**
  SCI format 1-A received in `t'^SL_m` — carrying that periodicity and reserving
  *all* sub-channels of the pool in that slot — would satisfy condition (c) of
  step 6.

> This is the step most often skipped. It is what makes half-duplex cost
> something: slots the UE could not hear are treated as potentially reserved.
> Omitting it inflates `|S_A|` and under-reports collisions.

**Step 5a.** If `|S_A| < X · M_total`, re-initialise `S_A` to all candidates (as step 4).

---

## 8. Exclusion: sensed reservations (step 6)

Exclude `R_x,y` from `S_A` if **all three** conditions hold:

**(a)** the UE received an SCI format 1-A in slot `t'^SL_m`, whose
`Resource reservation period` field (if present) and `Priority` field indicate
`P_rsvp_RX` and `prio_RX` (per TS 38.213 §16.4);

**(b)** the RSRP measured for that SCI (§8.4.2.1) is **higher than**
`Th(prio_RX, prio_TX)`;

**(c)** the received SCI — or the same SCI assumed to recur in slots
`t'^SL_{m + q × P'_rsvp_RX}` **iff** the `Resource reservation period` field is
present — determines (per §8.1.5) a set of RBs and slots overlapping

```
R_{x, y + j × P'_rsvp_TX}     for q = 1…Q,  j = 0…C_resel − 1
```

with

```
P'_rsvp_RX = P_rsvp_RX converted to logical slots (§8.1.7)

Q = ceil( T_scal / P'_rsvp_RX )   if P_rsvp_RX < T_scal and n' − m ≤ P'_rsvp_RX
Q = 1                              otherwise

T_scal = T_2 converted to msec

t'^SL_n' = n           if slot n belongs to (t'^SL_0, …, t'^SL_{T'_max−1})
t'^SL_n' = first pool slot after n   otherwise
```

> Condition (c) is a **periodic** overlap test on both sides: the sensed
> reservation repeats `Q` times, and *our own* candidate repeats `C_resel` times.
> Checking only the first occurrence of either is the classic under-exclusion bug.

---

## 9. Threshold adaptation and report (step 7)

```
while |S_A| < X · M_total:
    Th(p_i, p_j) += 3 dB     for every priority pair
    go to step 4
```

The increment applies to **all** priority values, and the loop restarts from
step 4 (re-initialising `S_A`), not from step 6. When the loop exits, the UE
**reports `S_A` to higher layers**; MAC then randomly selects from `S_A` with
equal probability.

---

## 10. Re-evaluation and pre-emption

Checked at `T_3 = T^SL_proc,1` before slot `m`, where `m` is the slot in which
the SCI first signals the resource (re-evaluation) or the slot where the
resource sits (pre-emption). MAC side: TS 38.321 §5.22.1.2a.

**Re-evaluation** — for a reserved-but-not-yet-signalled resource:

```
r_i ∉ S_A   →   report re-evaluation of r_i
```

**Pre-emption** — for a resource already signalled by a prior SCI. Report if
**all** hold:

1. `r'_i ∉ S_A`; **and**
2. `r'_i` meets the step-6 exclusion conditions with `Th(prio_RX, prio_TX)` at
   the **final** threshold after steps 1)–7), i.e. including every 3 dB
   increment applied to reach `X · M_total`; **and**
3. the associated `prio_RX` satisfies one of:
   - `sl-PreemptionEnable` is `'enabled'` **and** `prio_TX > prio_RX`; or
   - `sl-PreemptionEnable` is provided and **not** `'enabled'` **and**
     `prio_RX < prio_pre` **and** `prio_TX > prio_RX`.

On either indication MAC removes the resource from the grant and randomly
re-selects a replacement from the reported set.

---

## 11. Reselection counter and grant reuse (MAC)

From TS 38.321 §5.22.1.1. On a fresh selection, draw
`SL_RESOURCE_RESELECTION_COUNTER` uniformly from:

```
P_rsvp_TX ≥ 100 ms :  [ 5 , 15 ]

P_rsvp_TX <  100 ms :  [ 5 × ceil(100 / max(20, P_rsvp_TX)) ,
                        15 × ceil(100 / max(20, P_rsvp_TX)) ]
```

The counter decrements once per reservation period. At 0, the UE either
reselects or — with probability `sl-ProbResourceKeep` — **keeps** the existing
grant and redraws the counter.

`C_resel = 10 × SL_RESOURCE_RESELECTION_COUNTER` if configured, else `C_resel = 1`
(§8.1.5).

Also selected at this point, from `sl-PSSCH-TxConfigList` intersected with
`sl-CBR-PriorityTxConfigList` at the measured CBR:

- number of HARQ retransmissions (`sl-MaxTxTransNumPSSCH`);
- amount of frequency resources, between `sl-MinSubChannelNumPSSCH` and
  `sl-MaxSubchannelNumPSSCH`.

If no CBR measurement is available, `sl-defaultTxConfigIndex` applies.

---

## 12. Congestion control: CBR / CR

**Channel Busy Ratio (CBR)** is measured per TS 38.215 §5.1.27 — *not present in
these notes, see the gap list in [`00-INDEX.md`](00-INDEX.md)*. It is the
fraction of pool sub-channels whose S-RSSI exceeds a threshold, over a 100-slot
window.

**Channel occupancy Ratio (CR)**, TS 38.214 §8.1.6. With `sl-CR-Limit`
configured, for any priority `k` the UE must ensure:

```
Σ_{i ≥ k} CR(i)  ≤  CR_Limit(k)
```

`CR(i)` is evaluated in slot `n − N` for PSSCH transmissions with SCI `Priority`
= `i`; `N` is the congestion control processing time
([Tables 8.1.6-1/-2](#13-timing-constants-all-tables)). How to meet the limit —
including dropping transmissions in slot `n` — is UE implementation.

---

## 13. Timing constants (all tables)

**Table 8.1.4-1 — `T^SL_proc,0` (sensing processing), slots**

| `μ_SL` | SCS | `T^SL_proc,0` |
|---|---|---|
| 0 | 15 kHz | 1 |
| 1 | 30 kHz | 1 |
| 2 | 60 kHz | 2 |
| 3 | 120 kHz | 4 |

**Table 8.1.4-2 — `T^SL_proc,1` (selection processing), slots**

| `μ_SL` | SCS | `T^SL_proc,1` |
|---|---|---|
| 0 | 15 kHz | 3 |
| 1 | 30 kHz | 5 |
| 2 | 60 kHz | 9 |
| 3 | 120 kHz | 17 |

**Table 8.1.6-1 — congestion control processing time `N`, capability 1**

| `μ` | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| `N` [slots] | 2 | 2 | 4 | 8 |

**Table 8.1.6-2 — congestion control processing time `N`, capability 2**

| `μ` | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| `N` [slots] | 2 | 4 | 8 | 16 |

**§8.1.7 — reservation period in logical slots**

```
P'_rsvp = ceil( (T'_max / 10240 ms) × P_rsvp )
```

`T'_max` = number of slots belonging to the pool within 10240 ms.

---

## 14. Implementation checklist

Map each item to code and tick only when a test covers it.

| # | Requirement | Clause |
|---|---|---|
| 1 | Sensing window `[n−T_0, n−T^SL_proc,0)`, right end exclusive | 8.1.4 step 2 |
| 2 | Own-Tx slots excluded from sensing (half-duplex) | 8.1.4 step 2 |
| 3 | Selection window `[n+T_1, n+T_2]` with `T_1 ≤ T^SL_proc,1` | 8.1.4 step 1 |
| 4 | `T_2` clamped by `T_2min` and remaining PDB | 8.1.4 step 1 |
| 5 | All windows/periods in **logical pool slots** | 8.1.4, 8.1.7 |
| 6 | `Th` indexed `i = p_i + (p_j−1)×8` from `sl-Thres-RSRP-List` | 8.1.4 step 3 |
| 7 | RSRP source honours `sl-RS-ForSensing` | 8.4.2.1 |
| 8 | Step 5 unmonitored-slot exclusion **with hypothetical SCI** | 8.1.4 step 5 |
| 9 | Step 5a re-init when `|S_A| < X·M_total` | 8.1.4 step 5a |
| 10 | Step 6 periodic overlap over `q=1…Q` **and** `j=0…C_resel−1` | 8.1.4 step 6c |
| 11 | `Q` formula incl. the `n'−m ≤ P'_rsvp_RX` guard | 8.1.4 step 6c |
| 12 | Step 7 `+3 dB` on **all** pairs, loop back to **step 4** | 8.1.4 step 7 |
| 13 | Random selection from `S_A` with equal probability | 38.321 §5.22.1.1 |
| 14 | Counter draw incl. the `<100 ms` scaling branch | 38.321 §5.22.1.1 |
| 15 | `sl-ProbResourceKeep` grant-keep path | 38.321 §5.22.1.2 |
| 16 | All seven reselection triggers | 38.321 §5.22.1.2 |
| 17 | Re-evaluation at `T_3` before first signalling | 8.1.4 / §5.22.1.2a |
| 18 | Pre-emption incl. **final** threshold and priority conditions | 8.1.4 / §5.22.1.2a |
| 19 | `C_resel = 10 × counter` | 8.1.5 |
| 20 | CR limit `Σ_{i≥k} CR(i) ≤ CR_Limit(k)` | 8.1.6 |
