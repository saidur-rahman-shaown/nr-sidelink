# Policy — the Mode-2 selection research surface (non-normative)

## Status: built, first cut. Deliberately the simplest legal policy, not a good one.

Every value this package produces is one that TS 38.214 clause 8.1.4 or TS 38.321 clause
5.22.1.1 leaves to UE implementation. Nothing here is normative and nothing here can be wrong
against a spec — only inside or outside the bounds the spec does fix, which is what
`+test/+unit/+phy/+rx/+policy/test_policy.m` asserts by feeding this package's output straight
into `phy.ts38214.candidateSet` and letting *it* re-derive the bounds.

| Module | Decision | This cut |
|---|---|---|
| `defaults` | L_subCH, MCS, P_rsvp_TX, blind retx count, escalation guard | 2 sub-channels, MCS 7 (QPSK), 100 ms, 1 retx, 10 |
| `remainingPdbSlots` | how much budget is left, and when to discard | floor(PDB·2^µ) − elapsed, clamped at 0 |
| `selectionWindow` | T1, T2 | **T1 = T_proc,1^SL, T2 = the remaining PDB** |
| `selectionRequest` | assembles `candidateSet`'s `req` | glue; computes nothing normative |
| `resourcePick` | which resource out of S_A | uniform |

## This package is the MAC scheduler
There is no scheduler in the Uu sense anywhere in this tree, because in Mode 2 the UE
schedules itself. The job is split four ways: `+phy/+ts38214/candidateSet` says which resources
are *legal*, `+mac/`'s trigger and counter say *when* and *for how long*, `+mac/slLcp` says
*what goes in*, and **this package says which resource, at what size, at what MCS, over what
window** — the only part that is a choice rather than a derivation. `+mac/grantSelect` takes
the resources as inputs specifically so that the choice happens here.

## T1 = T_proc,1: the floor is the answer
Clause 8.1.4 bounds T1 by `0 <= T1 <= T_proc,1^SL`, and Table 8.1.4-2 gives T_proc,1 in slots:
3, 5, 9, 17 for µ = 0..3. It is a **floor on how long preparation takes**, not a target — a T1
below it asks the UE to transmit sooner after the trigger than it can prepare. Taking it
exactly is the choice that is correct on any implementation rather than on a fast one.

At µ=1 that is 5 slots = **2.5 ms**, which is the figure this simulator is configured around.
It is computed from µ via `phy.ts38214.procTimeSelection` and **never written as 2.5 ms**: the
portability rule forbids a hardcoded numerology, and the ms value is different at every other
µ (3 ms at µ=0, 2.25 at µ=2, 2.125 at µ=3) even though the slot counts come from one table.

## T2 = the remaining PDB: legal in both branches, and the latency knob
Clause 8.1.4 permits `T2min <= T2 <= remaining PDB`, and forces `T2 = remaining PDB` outright
when T2min exceeds it. Setting T2 to the PDB satisfies **both** branches with no test, which is
why `selectionWindow` does not take `sl-SelectionWindowList` at all — the T2min bound can never
bind. `test_policy` sweeps budgets either side of T2min at all four numerologies and checks
`candidateSet` accepts every one.

**This is the single line the whole KPI sits on.** Two opposed consequences:
- It **maximises M_total**. The longest legal window enumerates the most candidates, so S_A is
  at its largest and the probability two UEs draw the same resource is at its lowest. This is
  the collision-optimal end of the trade, which is why it is the right place to start.
- It is the **latency-worst** end. `resourcePick` draws uniformly, so mean access delay is
  about half the window: a 100 ms PDB gives a ~50 ms mean access delay **on a completely empty
  channel**, where a shorter T2 would have transmitted in a few ms.

An optimising policy shrinks T2 toward T2min while CBR (`+phy/+ts38215/`) is low and reopens it
toward the PDB as contention rises. That policy replaces `selectionWindow` and nothing else —
no caller, and no normative module, changes.

## Known traps
- **T2 = PDB and a uniform pick together are what produce the latency, not the channel.** On an
  empty pool this policy still reports tens of ms. Do not go looking for a bug in `+phy/` when
  the first end-to-end latency number comes back high; look here first. The two obvious fixes
  (shrink T2, or bias the draw earlier) trade collision probability for latency and must be
  *measured*, not assumed to be improvements.
- **`expired` must cause a DISCARD, never a late transmission.** A packet sent past its PDB
  counted as a slow success inflates throughput and truncates the latency tail simultaneously
  and in the same direction, so no other statistic contradicts it. This is the standard way
  sidelink KPI results go quietly wrong.
- **Infeasible is not an error.** `remainingPdb < T_proc,1` is routine under load. Both
  `selectionWindow` and `selectionRequest` report it as a `feasible` flag and still return a
  fully-formed `req` for the discard log; calling `candidateSet` anyway raises
  `ts38214:candidateSet:emptyWindow`. Never "fix" this by clamping T1 down — that keeps the
  packet alive by asking for a transmission the UE cannot produce.
- **Randomness is an input here too.** `resourcePick` takes the draw, following `+mac/`'s rule,
  so a grant lifecycle replays exactly from its seed. No `rand()` in this package even though
  the non-normative rules would allow it.
- **`defaults.LsubCH` is a stand-in for arithmetic that does not exist yet.** L_subCH should
  come from the MAC PDU size, by inverting `phy.ts38214.tbsDetermine` against the pool's
  sub-channel size. Until that module exists a constant sits there, and a payload that does not
  fit will not be detected — it will just be transmitted at the wrong size.

## Not built
- **MCS adaptation.** `defaults.mcs` is fixed. Broadcast has no CSI, so the interesting policy
  is CBR- or geometry-driven, not feedback-driven.
- **L_subCH from TBS**, per the trap above.
- **Congestion-control action.** `phy.ts38214.congestionControlCheck` reports a CR limit breach
  and clause 8.1.6 leaves the response ("including dropping the transmissions in slot n") to
  implementation. That response belongs here and is absent.
- **Keep-probability policy.** `sl-ProbResourceKeep` is config and `+mac/keepDecision` takes the
  draw, so there is nothing left to choose until the probability itself becomes adaptive.
- **Replacement choice after re-evaluation or pre-emption.** `+mac/reevaluation` and
  `+mac/preemption` flag a resource as needing replacement; which resource replaces it is a
  choice, and it is not made anywhere yet.

## Tests
`+test/+unit/+phy/+rx/+policy/test_policy.m`, run by `+test/runPhyTests.m`. Per
`+phy/+rx/CLAUDE.md` a policy gets no correctness test — it gets a **legality** test, a
plumbing test, and a KPI sweep. The first two are here; the sweep needs a harness.
- Legality: this policy's `req` fed to `candidateSet` at all four numerologies, over budgets
  spanning both of clause 8.1.4's T2 branches, with `candidateSet`'s own validation as the
  oracle. Every candidate asserted to lie in `[n+T1, n+T2]`.
- The feasibility boundary at exactly `T_proc,1` in both directions.
- `remainingPdbSlots` numerology scaling, the floor rather than round, and the clamp at 0.
- `resourcePick`: never returns a non-survivor over a full draw sweep, partitions `[0,1)` into
  exactly equal shares, and absorbs a draw at the top of the range into the last survivor.
- `defaults` asserted inside every consumer's documented range, with the default MCS resolved
  through `phy.ts38214.mcsTableSelect` to confirm it is QPSK.
