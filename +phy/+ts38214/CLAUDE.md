# TS 38.214 clause 8 — PHY procedures, data (B7)

The centrepiece. §8.1.4 is the most-often-implemented-wrong part of the standard.

## Status: built, level-1 and level-2 tests passing. `candidateSet` steps 1-7 and
`tbsDetermine`'s clause-8.1.3.2 N_RE formula both got an independent-verifier worked example
(spec-only, blind to this code) after the initial implementation. `candidateSet` matched
exactly on the nominal case and every subtlety checked (Q=1 still means one projection is
checked, not zero; the ms-vs-slots distinction in step 6c's Q guard). `tbsDetermine` did NOT
match: the verifier's hand computation caught a real bug — this file's `N_RE'` formula had
silently dropped clause 8.1.3.2's `N_symb^sh = sl-LengthSymbols - 2` term entirely, using
`slLengthSymbols` directly. The bug was invisible to this package's own nrTBS cross-check test
because that test's manual reference computation mirrored the same omission on both sides —
exactly the "a consistently misread encoder and its matching decoder round-trip perfectly"
trap +test/CLAUDE.md warns about. Fixed in `tbsDetermine.m`; the test file's manual reference
computations were fixed to match and four more independent-verifier-supplied cases (the
PSFCH-period branch structure) were added as regression tests. The verifier's other finding —
`dmrsTimePattern` must be the whole *configured* `sl-PSSCH-DMRS-TimePatternList`, not the
per-transmission SCI-selected entry, since Table 8.1.3.2-1's multi-entry rows are the mean of
their singleton members — was a documentation/interface-contract fix, not a code fix (the
lookup table itself was already keyed correctly for whatever array it's given).

| Module | Clause | Notes |
|---|---|---|
| `subchannelMap` | 8 (preamble) | `sl-StartRB-Subchannel`/`sl-SubchannelSize`/`sl-NumSubchannel` → PRB ranges |
| `mcsTableSelect` | 8.1.3.1 | MCS table selection (Tables 8.1.3.1-1/-2) + Table 5.1.3.1-1/-2/-3 lookup via `nrPDSCHMCSTables` |
| `tbsDetermine` | 8.1.3.2 (+5.1.3.2 steps 2-4) | N_RE (incl. the PSCCH/2nd-stage-SCI subtraction) and TBS quantisation, hand-implemented and cross-checked against `nrTBS`/its internal reference — see the file's own header |
| `procTimeSensing` / `procTimeSelection` | 8.1.4, Tables 8.1.4-1/-2 | T_proc,0^SL / T_proc,1^SL lookup |
| `reservationPeriodToSlots` | 8.1.7 | P_rsvp (ms) → P'_rsvp (logical slots) |
| `sensingDbInit` / `sensingDbRecord` / `sensingDbMarkUnmonitored` | 8.1.4 step 2 | struct-of-parallel-arrays sensing history: decoded SCI-1A (incl. clause 8.1.5 TRIV/FRIV chaining, fixed-width up to 3 resources) + RSRP + the unmonitored-slot set |
| `candidateSet` | 8.1.4 steps 1-7 | the core algorithm; re-evaluation/pre-emption deliberately excluded, see below |

Build order followed: `subchannelMap` → `mcsTableSelect`/`tbsDetermine` → `procTimeSensing`/
`procTimeSelection`/`reservationPeriodToSlots` → `sensingDb*` → `candidateSet`.

## Design decisions made while building (read before extending this package)
- **Logical slots only.** Every slot quantity `candidateSet`/`sensingDb*` touch (trigger slot
  `n`, sensed-SCI slots, window bounds) is a TS 38.214 clause-8 logical pool slot index. The
  logical<->physical mapping — and the underlying full-DFN pool timeline (`slotIsInPool`,
  `T'_max`) — is **not built anywhere in this tree** (+phy/+ts38213/CLAUDE.md's own "Not
  built" list) and is taken as a caller-supplied input (`TmaxPrime`) rather than computed
  here, same as `+phy/+ts38213/mode2ResourceSelect.m` takes higher-layer selection as an
  input. One consequence: clause 8.1.4 step 6c's `n'` (="n if n belongs to the pool, else the
  next pool slot") collapses to just `n`, since every integer already denotes a pool slot once
  it's given in logical numbering — documented in `candidateSet.m`'s header, not silently
  assumed. A second consequence: no DFN-wrap (10240 ms) arithmetic is implemented; selection/
  sensing windows are orders of magnitude smaller than a real `T'_max`, so this never triggers
  in practice, but a caller spanning a wrap boundary would need to unwrap first.
- **T1/T2 are taken as given, not chosen.** Per this file's own note below, the actual pick
  within `[0,T_proc,1]` / `[T2min, remaining PDB]` is a UE-implementation policy decision that
  lives in `+phy/+rx/+policy/`. `candidateSet` validates both against their spec-mandated
  bounds (computing `T_proc,1` and the numerology-scaled `T2min` itself) but does not choose
  them.
- **`sl-SelectionWindow` numerology scaling happens here.** `+cfg/private/resolveEnum.m`
  stores the raw enum value (1/5/10/20) and explicitly comments that the `x2^mu` scaling is
  "a downstream (+phy/+ts38214) responsibility" — `candidateSet` is where that happens
  (`T2minRaw * 2^mu`).
- **`sl-Thres-RSRP-List` and `sl-TxPercentageList` are taken pre-resolved** (dBm and a 0..1
  ratio respectively) — the raw config fields are an unresolved `INTEGER(0..66)` index and a
  percentage label, and that resolution isn't built in `+cfg/` yet. Same pattern as
  `+phy/+ts38213/reservationPeriodIndex.m` taking a pre-resolved-to-ms period list.
- **Re-evaluation and pre-emption are not here.** They live in `+mac/`, with a different
  resource set, different timing, and a different trigger (clause 8.1.4's own closing
  paragraphs, and TS 38.321 §5.22.1.2a). `candidateSet` still returns the final escalated
  threshold offset, since `+mac/`'s pre-emption check needs "the final threshold after
  executing steps 1)-7)" verbatim.
- **Congestion control (clause 8.1.6, CR/CR_Limit) is out of scope** — it isn't in this
  package's original module list and needs CBR (TS 38.215, not built; see
  `Documentations/Notes/00-INDEX.md` gap list). Same for clause 8.2-8.6 (CSI-RS/DM-RS/PT-RS
  transmission and reception procedures, congestion control, CSI reporting) — not requested,
  not built.
- **Cross-checked against prior art, not copied from it.** `nrv2x-matlab/phy/sensing/` (a
  separate, non-normative legacy codebase in this same repo) has a spec-faithful sensing/
  selection implementation, and `Documentations/Notes/08-Mode2-Conformance-Audit.md` audits a
  *different* legacy scheduler against the same 20-item checklist this package's `candidateSet`
  targets — both were read for cross-checking design and known pitfalls (half-duplex exclusion,
  `M_total` recomputation, the `Q`/`C_resel` projection), but this package's code is a fresh,
  portable-rules-compliant implementation, not a port (the legacy code uses `classdef handle`,
  cell arrays, and `cfg` objects on its interfaces — all forbidden here).

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
This is where worked examples matter most. `+test/+unit/+phy/+ts38214/test_procedures.m` has:
- `candidateSet` against three hand-built sensing-history scenarios: a sensed reservation whose
  clause-8.1.5-projected repeat lands inside the selection window (asserting the exact excluded
  candidate), the same scenario with a tighter `X` forced through two 3 dB escalation rounds
  (asserting the exact round count and that the resource clears once `Th` passes its RSRP), and
  the step-5/5a hypothetical-SCI-exclusion-then-reinitialisation path (asserting it does *not*
  wrongly shrink `S_A`).
- `subchannelMap` for a pool whose geometry leaves unused PRBs.
- `tbsDetermine` cross-checked directly against a live `nrTBS` call in the no-SCI-overhead
  case, plus a PSFCH-overhead and a `N_RE^SCI,1`/`N_RE^SCI,2` subtraction case.
- **Boot with an empty sensing window: the UE transmits immediately** with degraded selection
  quality — Test C, an entirely empty database, reports every candidate unfiltered. Confirmed
  this falls out of step 5a's own re-initialisation rule rather than needing a special case.
- Property: `candidateSet` never returns a resource in slot n or earlier (guaranteed by
  construction, `T1>=0`); the escalation loop is bounded by an explicit `maxEscalations` guard.

Also added after the independent-verifier pass: a `candidateSet` case at `mu=1` with
`T'_max != 10240` specifically to discriminate a correct `Q=ceil(T_scal/P_rsvp_RX)` (both ms)
from a dimensionally-wrong `Q=ceil(T_scal/P'_rsvp_RX)` (ms over slots) — the verifier flagged
that every `mu=0`/`T'_max=10240` case up to that point was numerically blind to this class of
bug, since ms and logical slots coincide 1:1 there. And four `tbsDetermine` cases pinning the
PSFCH-period branch structure (period 0 and 1 must ignore the SCI overhead-indication bit;
only period 2/4 reads it) plus the DMRS configured-list-vs-selected-pattern distinction.

`pending-human` per +test/CLAUDE.md level 2: the independent-verifier's own residual-risk notes
on both worked examples (it checks against a misreading the *implementation* might have made,
not one it made itself) still want a human skim of the two agent transcripts, and one
degenerate input combination it flagged (a 7-symbol slot + PSFCH period 1 + a 4-symbol-only
DM-RS pattern, which drives `N_RE'` negative) is currently rejected by `tbsDetermine`'s own
precondition check rather than caught earlier at `+cfg/cfgValidate.m` — a reasonable place to
add that check later, not built now.

## Gate
`candidateSet` returns exactly the hand-computed `S_A`, escalation rounds included — met, and
cross-checked independently. `tbsDetermine`'s N_RE formula matches an independent worked
example across five cases (nominal plus four branch/boundary variants) after the `N_symb^sh`
fix above. The selection-window visualisation (excluded resources coloured by exclusion
reason, `S_A` highlighted, chosen resource marked) is **not built** — deferred, not requested
for this pass.

## Known traps
- **`N_symb^sh = sl-LengthSymbols - 2`, not `sl-LengthSymbols`.** `tbsDetermine.m` dropped this
  term entirely in its first version — the "-2" is easy to miss reading clause 8.1.3.2's dense
  formula, and this project's own nrTBS cross-check test didn't catch it because the test's
  manual reference computation mirrored the same omission. Only an independent-verifier pass
  (spec text only, no view of the code) caught it. If you touch this formula again, get a fresh
  worked example rather than trusting the existing test file to still be independent evidence.
- Recomputing `M_total` after threshold escalation. `candidateSet` computes it once, before
  the escalation loop, and reuses it every round — verified by TestA1 (escalating to full
  clearance still reports the same `Mtotal` the caller got at the start).
- `[n+T1, n+T2]` is an **inclusive endpoint pair, not a width** — `T2=5` with `T1=3` is a
  3-slot window `[53,55]`, not a 6-slot one. Caught during this package's own test-writing (a
  hand-traced `Mtotal` came out at half the expected value on first run); left here because the
  same slip is easy to make again reading clause 8.1.4's prose.
- Sensing and selection are different things: sensing is historical lookback, selection is a
  future-directed pick. Separate modules, explicit interface, never merged. `sensingDb*` never
  reads `req.T1`/`T2`/`Cresel`; `candidateSet` never mutates the database.
- Re-evaluation and pre-emption are **not here**. They live in `+mac/` with different
  resource sets, different timing, and different triggers.
- Hardcoded slot counts. Both windows scale with numerology (`mu`, taken as an explicit input
  to `candidateSet`, never assumed).
- Step 7's `+3dB` restarts from **step 4** (full re-initialisation), not step 6 — re-running
  steps 4/5/5a each round is redundant work (their result is threshold-independent) but is
  what the spec literally describes, and skipping the restart would misreport the escalation
  count. `candidateSet` re-derives `alive` from scratch every loop iteration for this reason.
