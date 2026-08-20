# MAC (B8) — TS 38.321 §5.22, §6.1.6

| Module | Notes |
|---|---|
| `reselectionTrigger` | every trigger as an independently testable predicate |
| `cresel` | `Cresel = 10 × SL_RESOURCE_RESELECTION_COUNTER`; draw range by reservation period; `sl-ProbResourceKeep` at expiry |
| `grantLifecycle` | selected grant → periodic reservation → decrement → keep or reselect |
| `reevaluation` | re-check reserved-but-unsignalled resources against the current `S_A` |
| `preemption` | higher-priority overlapping reservation above the RSRP threshold |
| `harqEntity` | up to 32 transmissions, process management, RV sequence, feedback and blind modes |
| `slLcp` | per-destination, per-logical-channel prioritisation |
| `muxSlSch` | SL-SCH MAC PDU, subheaders, LCID, source and destination L2 IDs |

Build order: `reselectionTrigger` → `cresel` → `grantLifecycle` → `muxSlSch` → `slLcp` →
`harqEntity` → `reevaluation` → `preemption`.

## The causality that must be visible in the code
In Mode 2: **data availability → the UE's own selection sizing → grant → LCP.**
This is the reverse of Mode 1, where the grant arrives externally and LCP fills it. Structure
the MAC tick so the ordering is explicit and cannot be accidentally inverted by a later
refactor. Write the assertion that fires if LCP runs before a grant exists.

MAC calls `+phy/+ts38214/candidateSet` and selects uniformly from what comes back. The
selection algorithm is not here; the trigger and the grant lifecycle are.

## Tests
- `reselectionTrigger` as a truth table: every condition, individually and in combination,
  with outcomes enumerated rather than sampled.
- `cresel`: the counter draw lands in the correct range per reservation period; the decrement
  happens once per reserved occasion, not once per slot; at expiry the keep branch retains the
  resource with the configured probability. Test that branch with a fixed seed over a large
  sample and assert the empirical rate, not a single draw.
- `harqEntity`: process allocation and release across the full process space; RV sequence
  order; both feedback and blind modes; behaviour at the transmission-count limit.
- Worked example: one full grant lifecycle from selection through several reservation periods
  to reselection, hand-computed.

## Gate
A periodic generator produces the correct reservation pattern. Cresel decrements correctly.
Reselection fires at expiry with the configured keep probability. Every state transition is
traceable in the log. A time-frequency plot of one UE over several seconds shows the SPS
pattern, a keep decision, and a reselection.

## Known traps
- `Cresel` is **ten times** the counter. The multiplier appears explicitly in the code and in
  the header, never folded into a constant.
- Re-evaluation and pre-emption operate on different resource sets with different timing.
  Never merge them; never let one call the other.
- Decrementing the counter on slots rather than on reserved occasions.
- Assuming a grant is for one transmission. It covers the initial transmission and its
  TRIV-indicated retransmissions.
