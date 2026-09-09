# MAC (B8) — TS 38.321 §5.22, §6.1.6

## Status: built, level-1 and level-2 tests passing.
An independent-verifier worked example (spec text only, blind to this code) over clauses
5.22.1.1 / 5.22.1.2 / 5.22.1.4.1 **caught a real bug in `slLcp`** — the `SBj > 0` condition was
applied to logical-channel selection when clause 5.22.1.4.1.2 scopes it to *Destination*
selection. See the trap below; fixed, with the two discriminating cases (a large grant, and a
grant-truncated first pass) added as regression tests. Everything else it checked matched: all
six `creselCounterRange` intervals, the `keepDecision` boundary and its draw-at-1/act-at-0
timing, the once-per-MAC-PDU counter decrement, the per-interval `sl-ReselectAfter` count, and
the whole LCP allocation including the `SBj` outcome that separates charging one pass from
charging both.

A second pass over clauses 5.22.1.2a / 5.22.1.3.x / 6.1.6 / 6.2.4 / 6.1.3.35 confirmed the
16-octet MAC PDU worked example **octet for octet** (`00 AB CD 12 04 03 01 02 03 3E A8 3F 00 00
00 00`) and every HARQ reading, and found **two real gaps**:
- **`sl-PreemptionEnable` is a three-way gate and was not modelled at all.** TS 38.214 clause
  8.1.4 has two pre-emption bullets, *both* beginning "sl-PreemptionEnable is provided" — so with
  the field absent nothing is ever pre-empted, while `'plN'` adds a *second* strict test
  `prio_RX < prio_pre` on top of `prio_TX > prio_RX`. `preemption` now takes the label and
  implements all three cases. Re-evaluation carries no such gate.
- **Clause 5.22.1.3.1's fourth flush condition was missing** — an initial-transmission grant for
  which the multiplexing entity produced no MAC PDU ("3> else: 4> flush the HARQ buffer"). Added
  as `harqFlush`, kept separate from `harqOnFeedback` because it is not feedback-driven.

It also caught the test suite **over-constraining the spec**: the first NDI value was asserted
absolutely, but clause 5.22.1.3.1 NOTE 2 leaves "the initial value of the NDI set to the very
first transmission" to UE implementation. Only the toggle *relation* is normative, and that is
what the test now asserts.

| Module | Clause | Notes |
|---|---|---|
| `reselectionTrigger` | 5.22.1.2 | all seven conditions as one predicate each, reported individually |
| `creselCounterRange` | 5.22.1.1 | the `SL_RESOURCE_RESELECTION_COUNTER` draw range by reservation period |
| `cresel` | 38.214 §8.1.4 | `C_resel = 10 × counter`, or 1 when no counter is configured |
| `keepDecision` | 5.22.1.1 / 5.22.1.2 | the `sl-ProbResourceKeep` branch at counter expiry |
| `grantInit` / `grantSelect` / `grantOnTransmission` / `grantOnPeriodEnd` / `grantClear` | 5.22.1.1 | selected grant → periodic reservation → decrement → keep or reselect |
| `muxSlSch` | 6.1.6, 6.2.4, 6.1.3.35 | SL-SCH MAC PDU, subheaders, LCID, source and destination L2 IDs |
| `slLcpBucket` / `slLcp` | 5.22.1.4.1 | per-destination, per-logical-channel prioritisation |
| `harqInit` / `harqNewTransmission` / `harqRetransmission` / `harqOnFeedback` / `harqFlush` | 5.22.1.3.1, .1a, .3.3 | process management, RV sequence, feedback, DTX-based RLF |
| `reevaluation` | 5.22.1.2a | re-check reserved-but-unsignalled resources against the current `S_A` |
| `preemption` | 5.22.1.2a + 38.214 §8.1.4 | higher-priority overlapping reservation above the RSRP threshold |

Built in the documented order. The plan of record listed 8 modules; the tree has more files
because several of those are state machines rather than single functions — the grant lifecycle
and the HARQ entity each need an init plus explicit transitions, since the normative-packages
rule bans `persistent`/`global` and requires state to "live in explicit objects that serialise
and diff". `cresel` was likewise split from `creselCounterRange` and `keepDecision`: the counter's
draw range, its ×10 projection and its expiry branch are three different quantities consumed by
three different callers, and folding them into one function is what makes the ×10 easy to lose.

## The causality that must be visible in the code
In Mode 2: **data availability → the UE's own selection sizing → grant → LCP.** The reverse of
Mode 1, where the grant arrives externally and LCP fills it. `slLcp` takes `grantBytes` as an
input and cannot run without one, which is the structural form of that assertion — there is no
code path that produces an allocation before a grant exists.

MAC calls `+phy/+ts38214/candidateSet` and selects uniformly from what comes back. The selection
algorithm is not here; the trigger and the grant lifecycle are. Likewise `grantSelect` chooses
nothing — P_rsvp_TX, the counter draw, the retransmission count, L_subCH and the resources all
arrive as inputs, because clause 5.22.1.1 routes them through UE implementation or through the
physical layer.

## Randomness is always an input, never generated here
`keepDecision` takes the `[0,1]` draw; `grantSelect` takes the counter value; `grantOnPeriodEnd`
takes the next keep draw. No `rand()` anywhere in the package. This is forced by the
no-hidden-state rule, but it also buys the thing the gate asks for: a grant lifecycle that can be
replayed exactly and diffed, so "every state transition is traceable" is a property of the design
rather than of the logging.

## The keep draw is taken one MAC PDU early
Both clause 5.22.1.1 and clause 5.22.1.2 say the draw happens "when
`SL_RESOURCE_RESELECTION_COUNTER` **was equal to 1**" and is acted on once the counter reads 0.
`grantOnPeriodEnd` therefore captures it on the 1→0 transition into `g.keepDraw`, and
`keepDecision` consumes the stored value. Drawing fresh at zero produces the same long-run keep
rate and so passes any statistical test — this is a timing bug that a "test the empirical rate
over a large sample" check cannot see, which is why the capture point is pinned by an assertion
in the lifecycle test instead.

## A formula the reformatted notes get wrong
`Documentations/Notes/01-TS38321-MAC-Sidelink-Procedures.md` renders clause 5.22.1.1's counter
draw range with the **division bar lost**, as `5 × ceil(100 max(20, P_rsvp_TX))` — which reads as
a product and is off by orders of magnitude. The correct interval is
`[5 × ceil(100 / max(20, P_rsvp_TX)), 15 × ceil(100 / max(20, P_rsvp_TX))]`, re-read from
`Documentations/38321-gm0.pdf` directly. Same class of failure as the `N_symb^sh` term
`+phy/+ts38214/CLAUDE.md` records. **Read the PDF for anything mathematical in this spec.**

## Known traps
- **`C_resel` is TEN times the counter.** The multiplier appears explicitly in `cresel.m`, never
  folded into the draw bounds or a constant. The two quantities are consumed by different things
  and change at different rates: the counter decrements once per MAC PDU, `C_resel` is a
  projection horizon handed to the physical layer and never decrements at all.
- **The counter decrements once per RESERVED OCCASION, not per transmission.** A grant with an
  initial transmission plus two retransmission opportunities carries one MAC PDU per period and
  costs **one** count, not three. Decrementing per transmission shortens every grant's life by
  the retransmission multiple while still drawing a plausible-looking SPS pattern.
- **`counter == 0` is not by itself a reselection trigger.** Clause 5.22.1.1's keep branch and
  clause 5.22.1.2's reselect branch partition the `counter == 0` case by the `sl-ProbResourceKeep`
  draw. Treating zero as an unconditional trigger makes `sl-ProbResourceKeep` a no-op, and
  nothing else in the system would reveal it.
- **`sl-ReselectAfter` counts unused PERIODS and is "equal to", not ">=".** Clause 5.22.1.2
  increments only "when none of the resources of the selected sidelink grant within a resource
  reservation interval is used", so a single transmission anywhere in the period clears the
  streak. Counting per slot or per resource fires reselection early.
- **`sl-Priority` is inverted: 1 is the HIGHEST.** So clause 5.22.1.4.1.3's "decreasing priority
  order" means **ascending** numeric order. Reading it as descending silently serves the least
  important traffic first, and every allocation still sums to the grant so the totals look right.
- **Only LCP's first pass spends bucket tokens.** Clause 5.22.1.4.1.3 decrements `SBj` by "the
  total size of MAC SDUs served to logical channel j **above**", where "above" is the first
  bullet — the SBj-limited pass. The third bullet's "regardless of the value of SBj" pass is not
  charged. Charging both double-spends the bucket and starves the channel next round.
- **The `SBj > 0` condition gates DESTINATION selection, not logical-channel selection.** Clause
  5.22.1.4.1.2 is two bullet lists. "SBj > 0, in case there is any logical channel having SBj > 0"
  appears **only in the first**, which picks a Destination. The second list — "select the logical
  channels satisfying all the following conditions among the logical channels belonging to the
  selected Destination" — has no SBj condition at all. So a channel with `SBj <= 0` in the chosen
  Destination **is selected**; it simply wins nothing in the first allocation pass and is served
  by the second. This is the bug the independent-verifier pass caught in `slLcp`'s first version,
  which applied the filter to channel selection: the nominal case still produced the right
  numbers (the negative-bucket channel gets nothing either way when the grant is small), but a
  grant large enough to reach the second pass under-filled by exactly that channel's share and
  starved it permanently — against clause 5.22.1.4.1.3's "the UE should maximise the transmission
  of data". The "in case there is any" qualifier makes the upstream Destination test conditional
  too, so an all-negative-bucket UE still selects a Destination rather than deadlocking, which is
  consistent with 5.22.1.4.1.3's NOTE that "The value of SBj can be negative".
- **Enabled and disabled HARQ feedback cannot share a MAC PDU.** The highest-priority selected
  channel decides the PDU's value and every channel with the other value is dropped from it.
- **Pre-emption's priority comparison is STRICT.** Only a numerically smaller `sl-Priority`
  pre-empts. An equal-priority reservation must not, or two same-priority UEs pre-empt each other
  indefinitely and neither ever transmits. Writing `<=` produces exactly that livelock and is
  invisible in any test where the two priorities differ.
- **Pre-emption uses the ESCALATED threshold.** `preemption` takes `candidateSet`'s
  `thresholdOffsetFinalDb` — "the final threshold after executing steps 1)-7)" — which
  `+phy/+ts38214/CLAUDE.md` records as being returned specifically for this. Using the raw table
  value makes a congested pool pre-empt far more than it should.
- **Re-evaluation and pre-emption operate on different resource sets with different timing.**
  Never merge them; never let one call the other. Re-evaluation covers resources **not yet**
  announced by an SCI, with `m` = the slot the SCI first signals them; pre-emption covers
  **already-announced** resources, with `m` = the slot the resource is located in. They are exact
  complements in `signalledBySci`, and the two functions share no code.
- **A grant is not one transmission.** It covers the initial transmission and its TRIV-indicated
  retransmissions, repeating at P_rsvp_TX for as long as the counter lasts.
- **A retransmission grant for an empty HARQ buffer is IGNORED, not an error.** Clause 5.22.1.3.1
  says so explicitly, and it happens routinely: the grant was selected before the ACK arrived.
  `harqRetransmission` returns `ignored` as a value for this reason — a caller that raises on it
  reports phantom failures on every successful early ACK.
- **`numConsecutiveDTX` resets on ANY PSFCH reception, including a NACK.** Clause 5.22.1.3.3
  counts *absence*, not negativity. A received NACK proves the peer is alive. Resetting only on
  ACK turns a lossy-but-live link into a false radio link failure.
- **Sixteen processes, or FOUR.** Clause 5.22.1.3.1 caps transmitting Sidelink processes at 16 in
  general but at 4 "for transmissions of multiple MAC PDUs with Sidelink resource allocation mode
  2". Over-allocating lets a simulation run more concurrent TBs than any conformant UE, inflating
  throughput without failing anything.
- **The MAC subheader and the SCI carry COMPLEMENTARY halves of each identity.** Clause 6.2.4:
  SRC is the 16 **most** significant bits of the Source Layer-2 ID, DST the 8 **most** significant
  bits of the Destination Layer-2 ID. Clause 5.22.1.3.1: the SCI's Source Layer-1 ID is the 8
  **LSB** of the Source Layer-2 ID and its Destination Layer-1 ID the 16 **LSB** of the
  Destination Layer-2 ID. Neither layer alone identifies a peer.

## Not built
- **Clause 5.22.1.5 Scheduling Request, 5.22.1.6 Buffer Status Reporting, 5.22.1.7 CSI
  reporting.** Not in the package's module list. SR and SL-BSR are mode-1 machinery (they inform
  a serving gNB) and this tree is a Mode-2 simulator; `muxSlSch` does carry the Sidelink CSI
  Reporting MAC CE, but what *triggers* a CSI report is clause 5.22.1.7 and is absent.
- **Clause 5.22.2 SL-SCH data reception** — the receive-side HARQ entity, SCI reception and
  disassembly. The package covers the transmit path only.
- **Clause 5.23 SL-BCH data transfer.** One paragraph each way; nothing to model until there is a
  transmit chain to drive.
- **Mode 1 grant reception** (the PDCCH / SL-RNTI / SL-CS-RNTI branches of clause 5.22.1.1, and
  configured grant Type 1/2 activation). `harqNewTransmission` accepts a `harqProcessId` so a
  mode-1 caller can associate one, and clause 5.22.1.1's configured-grant formula
  `floor(CURRENT_slot / PeriodicitySL) mod sl-NrOfHARQ-Processes + sl-HARQ-ProcID-offset` is
  recorded there, but nothing computes it.
- **Segmentation.** `slLcp` allocates byte budgets per logical channel; turning a budget into RLC
  SDUs and segments is `+rlc/`'s job, and clause 5.22.1.4.1.3's segmentation rules operate on RLC
  SDU boundaries.
- **The `+phy/+rx/+policy/` decisions** these modules defer to: which resource to draw from `S_A`,
  which replacement to pick after re-evaluation or pre-emption, whether to segment, whether to
  fall back to a single MAC PDU when the PDB cannot be met.

## Tests
`+test/+unit/+mac/test_macSidelink.m`, run by `+test/runMacTests.m` (and `+test/runAllTests.m`,
which drives both package runners — `runPhyTests` documents itself as covering `+phy/`, so `+mac/`
got its own rather than being smuggled into it).
- `reselectionTrigger` as a **truth table**: every one of the seven conditions individually,
  asserted to fire *and* to be reported in its own slot; two at once; and a missing field
  rejected rather than defaulted to false.
- `creselCounterRange` at P = 100, 200, 50, 20, 10, 1 — including the case that catches a dropped
  `max(20, ·)` floor (P=10 must equal P=20's range, not double it) and a check that both endpoints
  scale together.
- **A full hand-traced grant lifecycle**: counter 7, three opportunities per period, transmitting
  on all three and asserting the counter falls by one per period, not three; that the keep draw is
  captured on the 1→0 transition and not before; that the same draw keeps under
  `sl-ProbResourceKeep` 0.4 and reselects under 0.2; and that `counter == 0` with a successful
  draw does **not** trigger the check.
- `slLcp` against the hand-computed A=350 / B=50 / C=0 allocation, asserting the `SBj` outcome
  `[0 0 -20]` that distinguishes charging the first pass only from charging both; the
  priority-inversion case; the all-negative-buckets case that must not deadlock; and the
  HARQ-feedback exclusivity rule decided by priority rather than position.
- `muxSlSch` octet by octet against a hand-assembled 16-byte PDU, plus the exact-fit and
  one-spare-octet padding cases, the F=0/F=1 boundary at 256 bytes, subPDU ordering with two SDUs,
  and clause 5.22.1.4.1.3's refusal to build a PDU with no SDUs and no CSI CE.
- `harq*`: both process limits, the NDI toggling across two TBs, the RV sequence walking and
  wrapping, the ignored-grant path on an empty buffer, `sl-MaxTransNum` flushing without an ACK,
  and the DTX counter resetting on a received NACK then firing RLF exactly once on the crossing.
- `reevaluation` / `preemption`: the `signalledBySci` complement in both directions, the
  `m - T_3` due point, and pre-emption's strict priority comparison, threshold test, escalated
  offset, frequency-overlap requirement and chained-resource case.

## `pending-human` per +test/CLAUDE.md level 2
Two points the verifier flagged as inference rather than quotation, both in the counter
lifecycle:
- **`sl-ProbResourceKeep = 0` with a draw of exactly 0.** The literal text ("less than or equal
  to") keeps the grant, but the evident intent of a zero keep probability is "always reselect".
  `keepDecision` implements the literal text. Measure-zero for a continuous RNG, reachable for a
  quantised one.
- **The `sl-ReselectAfter` reset.** Clause 5.22.1.2 states the *increment* rule explicitly but
  never states a reset; resetting to zero on any used interval is inferred from the word
  "consecutive". `grantOnPeriodEnd` resets. The alternative reading — a count that only ever
  rises — would eventually fire reselection on any grant with sporadic idle periods.
- **Whether RLF is indicated once or repeatedly.** Clause 5.22.1.3.3 says "if numConsecutiveDTX
  **reaches** sl-maxNumConsecutiveDTX" and never resets the counter on indication, so a further
  DTX leaves it above the threshold. `harqOnFeedback` reads "reaches" as the crossing and
  indicates exactly once. A `>=` reading would re-indicate on every subsequent DTX. Usually
  invisible in practice — RRC releases the connection on the first indication — but a MAC-only
  test can see it.
- **The Sidelink CSI Reporting MAC CE's fixed-size property is inferred.** Clause 6.1.3.35 never
  says "fixed size", unlike most other CEs in 6.1.3.x. It follows from the fields summing to
  exactly one octet with no length or extension field, from clause 6.2.4 defining L only for "the
  corresponding MAC SDU", and from 6.2.4's "**the** fixed-sized MAC CE" presupposing one exists.
  `muxSlSch` gives it the R/LCID subheader accordingly.
- **Padding octet VALUES are undefined.** Nothing in TS 38.321 fixes them; clause 6.1.5 says only
  that "Presence and length of padding is implicit based on TB size". `muxSlSch` writes zeros and
  its test asserts them, which pins this package's own choice rather than a spec requirement — a
  conformant encoder may emit anything there.
- **The 24-bit Layer-2 ID width** used to check that the MAC and SCI halves reconstitute each
  identifier comes from TS 23.287, for which there is no local PDF (`+cfg/specVersions.json` still
  lists TS23287 as an unverified placeholder). The arithmetic is self-consistent — 16+8 and 8+16
  both reach 24 — which corroborates it, but it is not extracted from a document in this repo.

## Gate
A periodic generator produces the correct reservation pattern. Cresel decrements correctly.
Reselection fires at expiry with the configured keep probability. Every state transition is
traceable in the log — met by construction, since the whole lifecycle is an explicit struct and
all randomness is an input. **Not built:** the time-frequency plot of one UE over several seconds
showing the SPS pattern, a keep decision and a reselection; that needs a harness, which does not
exist yet.
