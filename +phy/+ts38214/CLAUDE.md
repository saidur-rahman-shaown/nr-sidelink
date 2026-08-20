# TS 38.214 clause 8 — PHY procedures, data (B7)

The centrepiece. §8.1.4 is the most-often-implemented-wrong part of the standard.

| Module | Notes |
|---|---|
| `subchannelMap` | `sl-StartRB-Subchannel`, `sl-SubchannelSize`, `sl-NumSubchannel` → PRB ranges |
| `mcsTbs` | MCS table selection, TBS determination |
| `sensingDb` | decoded SCI-1A + RSRP over the sensing window, plus the unmonitored-slot set |
| `candidateSet` | §8.1.4, the core algorithm |

Build order: `subchannelMap` → `mcsTbs` → `sensingDb` → `candidateSet`.

## Sensing — continuous, background
For every slot the UE is **not** transmitting in: blind-decode PSCCH (`+phy/+rx/`), measure
SL-RSRP with the pool-configured variant (`+ts38215/`), store source, priority, FRIV, TRIV,
reservation period index, RSRP, and slot, then **project reservations forward** — every
future resource each decoded SCI reserves, both the TRIV-indicated retransmissions and the
periodic repetitions, extended across the anticipated selection window.

The projection is what makes sensing predictive rather than a log. Without it `candidateSet`
has nothing to exclude on.

For every slot the UE **is** transmitting in: mark unmonitored. Half-duplex is a first-class
property of the database, not an impairment added later.

## Selection — triggered by MAC at slot n
Selection window `[n + T1, n + T2]`. T1 at or above the processing time. T2 between the
per-priority, numerology-scaled minimum and the remaining PDB. **The minimum is a floor, not
a ceiling** — T2 within its permitted range is a UE implementation choice and lives in
`+phy/+rx/+policy/`, configurable, so its effect can be studied rather than baked in.

Sensing window `[n − T0, n − T_proc,0]`.

Candidate set construction:
1. Enumerate all `R(x,y)`: `L_subCH` contiguous subchannels starting at subchannel x, in slot
   y within the selection window, for every valid (x,y). `M_total` is the count.
2. Initialise `S_A` to all of them. Set thresholds from the RSRP threshold list, indexed by
   the (received priority, own priority) pair.
3. Exclude candidates affected by unmonitored slots where a periodic reservation landing in
   the selection window cannot be ruled out.
4. Exclude candidates overlapping a projected reservation whose measured SL-RSRP exceeds
   `Th(p_i, p_j)`.
5. If `|S_A| < X · M_total`, raise every threshold by 3 dB and repeat from step 3.
6. Report `S_A` to MAC, which selects uniformly at random.

`M_total` is the **initial** total. Recomputing it after an escalation round changes the
termination behaviour and is the single most common defect in this algorithm.

## Tests
This is where worked examples matter most.
- `candidateSet` against a hand-built sensing history, asserting the exact `S_A` and the
  correct number of 3 dB escalation rounds.
- A `Th(p_i, p_j)` lookup at a table edge; a TBS at a quantisation step; a `subchannelMap`
  for a pool whose geometry leaves unused PRBs.
- Property: `candidateSet` never returns a resource in slot n or earlier; `S_A` is always a
  subset of the initial enumeration; the escalation loop terminates for every input.
- **Boot with an empty sensing window: the UE transmits immediately** with degraded selection
  quality. It does not block waiting for the window to fill. Test this explicitly.

## Gate
`candidateSet` returns exactly the hand-computed `S_A`, escalation rounds included.
The selection-window visualisation renders: excluded resources coloured by exclusion reason,
`S_A` highlighted, chosen resource marked. Build that plot properly — it explains Mode 2 to
any audience and you will use it in every talk and paper about this work.

## Known traps
- Recomputing `M_total` after threshold escalation.
- Sensing and selection are different things: sensing is historical lookback, selection is a
  future-directed pick. Separate modules, explicit interface, never merged.
- Re-evaluation and pre-emption are **not here**. They live in `+mac/` with different
  resource sets, different timing, and different triggers.
- Hardcoded slot counts. Both windows scale with numerology.
