# Integration plan — logical channels to the air and back

Companion to `BUILD.md`. `BUILD.md` sequences the *packages*; this file sequences the
*connections between them*, which is the remaining work. The deliverable is an end-to-end
Mode-2 sidelink simulator whose measured outputs are **latency (against the PDB) and
throughput**.

## The principle

**Close the loop end to end at low fidelity, on frozen interfaces, then raise fidelity behind
those interfaces.**

The natural order is bottom-up — B4 → B5 → B9 → B10 — and it is the wrong one here. It yields
no KPI until the last step, and every interface gets designed months before anything consumes
it. Instead: freeze the SAPs first, stand up the whole chain with the PHY abstracted, get a
latency and throughput number early, and then replace pieces behind unchanged interfaces. Every
later change is then validated by whether the KPI moves in a way you can explain.

## The path

    +app/          traffic generation, packet born with PQI, PDB and tGen
      |  SDU + context
    +sdap/ +pdcp/ +rlc/     (thin at first: UM, no reordering, no ciphering)
      |  RLC PDU per logical channel
    ===== MAC SAP =====  <-- the entry point: logical channels into MAC
    +mac/          LCP, multiplexing, HARQ, grant lifecycle
      |  asks: when? -> +mac/reselectionTrigger, +mac/cresel
      |  asks: which resources are legal? -> +phy/+ts38214/candidateSet
      |  asks: which one, what size, what MCS? -> +phy/+rx/+policy/   [the scheduler]
      |  MAC PDU + resource + MCS + priority
    ===== PHY SAP =====
    +phy/+chan/    SCI-1A -> PSCCH, SCI-2 + SL-SCH -> PSSCH   (LLS)
      OR
    +harness/+phyabs/   BLER lookup, no waveform                (SLS)
      |  baseband samples (LLS) or a transmission descriptor (SLS)
    ===== RF SAP =====
    +rf/           power amplification, noise figure, filtering
      |
    ===== CHANNEL SAP =====
    +harness/+chanmodel/   pathloss, fading, per-link SINR; TR 38.901 / 37.885
      |
    +rf/           receive chain
    +phy/+rx/      sync, CE, EQ, blind PSCCH decode, PSSCH decode, SL-RSRP
      |
    +mac/          RX HARQ, disassembly       (not built -- clause 5.22.2)
      |
    +rlc/ +pdcp/ +sdap/ +app/   delivery, tRx recorded, latency closed

## Frozen interfaces (Phase 0's real content)

Six structs. Flat, scalar or array, per `.claude/rules/normative-packages.md`. Once frozen,
changing one is a cross-package event that gets discussed, not an edit.

### 1. `ctx` — the packet context  — **BUILT**, in `+sap/`
Created once in `+app/`, threaded through every SAP **unchanged except for appending
timestamps**. Lives in a top-level `+sap/` package that depends on nothing, so every layer can
depend on it without a cycle; see `+sap/CLAUDE.md`. This is the latency measurement, and it must exist before anything else is built —
retrofitting per-packet instrumentation into a working stack is the step that always fails.

    pktId       uint32   unique, monotonic per UE
    srcL2Id     uint32   24-bit Source Layer-2 ID
    dstL2Id     uint32   24-bit Destination Layer-2 ID
    pqi         uint8    from +cfg/pqiTable
    prio        uint8    1..8, 1 is HIGHEST
    pdbMs       double   from +cfg/pqiTable's PDB_ms
    sizeBytes   uint16
    lcid        uint8
    tGenSlot    uint32   set by +app/ -- the ONE reference point for D_app
    tMacSlot    uint32   arrival at the MAC SAP
    tGrantSlot  uint32   slot in which a grant covering it was selected
    tTxSlot     uint32   first transmission
    tRxSlot     uint32   successful delivery, or 0
    nTx         uint8    transmissions spent, including blind retx
    outcome     uint8    0 in flight, 1 delivered, 2 PDB-expired, 3 max-retx

**Rule: instrument at SAP boundaries only.** No module reaches inside another to time it, and
no KPI is computed from private state. `+harness/CLAUDE.md` already names the alternative as a
trap.

### 2. MAC SAP — logical channels in
The entry point. A per-logical-channel queue array plus the LCP parameters clause 5.22.1.4.1
needs. `+mac/slLcpBucket` and `+mac/slLcp` already consume the parameters; nothing holds the
queues.

    lch(k).lcid, .prio, .dstL2Id, .pbr, .bsd, .sbj, .harqFeedbackEnabled
    lch(k).sdu   -- an array of ctx, oldest first

### 3. PHY SAP — MAC out
Deliberately **not** waveform-shaped, because the SLS path has no waveform. This is the single
most consequential interface in the tree: it is what lets the same stack run at both
fidelities.

    slotLogical, slotPhysical   uint32
    startSubch, LsubCH          uint8
    mcs                         uint8
    tbBits                      uint32
    tb                          logical column vector
    prioTx                      uint8
    harqId, ndi, rv             uint8
    srcL1Id, dstL1Id            uint32   (the SCI halves; see +mac/CLAUDE.md)
    prsvpTxIdx, trivIdx, frivIdx uint16  SCI-1A reservation fields
    txPowerDbm                  double
    ctxIds                      uint32 array -- which packets are inside, for KPI closure

### 4. RF SAP
`+rf/` is a **new non-normative package**, kept out of `+phy/` so the baseband is separable, as
required. Waveform in, waveform out, plus the descriptor. In the SLS path it contributes only
the power figure and the noise figure.

    waveform    complex column vector, or empty in the SLS path
    fc, fs      double
    pTxDbm, noiseFigureDb, evmDb

### 5. Channel SAP
One call per slot for the whole scenario, not per link, so interference is computed once.
Wraps every toolbox channel model; nothing escapes it.

    tx(i)   -- the RF SAP struct plus .ueId, .posXY
    rx(j).ueId, .posXY
    -> link(i,j).pathlossDb, .sinrDb, .rxWaveform (LLS only)

### 6. RX SAP — into MAC
    slotLogical, crcPass, tb, sci1a fields, sci2 fields, rsrpDbm, sinrDb, ctxIds

## Phases

### Phase 0 — freeze the SAPs, build the walking skeleton
No algorithms. The six structs above, constructors and validators for each, and
`+harness/+sls/slotLoop.m` running the exact intra-slot ordering already specified in
`+harness/CLAUDE.md`, with every layer a stub that returns a well-formed empty result.

**Blocker cleared here:** the **logical ↔ physical slot mapping did not exist anywhere in this
tree.** `+phy/+ts38214/` declares itself the logical side and never converts;
`+phy/+ts38213/CLAUDE.md` listed `slotIsInPool` in its own "Not built", noting it was "not
found in clause 16.1/16.3/16.4's own text". That note was right, and the reason is that the
pool slot set is **not in TS 38.213 at all** — it is defined in the **TS 38.214 clause 8
preamble**, alongside the sub-channel definition `+phy/+ts38214/subchannelMap` already
implements. Built as `+phy/+ts38214/poolSlotMap`, which returns both directions of the map
from one pass, so the conversion is applied **exactly once** and the two directions cannot
disagree — `.claude/rules/portability.md`.

Also decided here, not later: the **BLER table key structure** (MCS, SINR, channel model,
speed, retransmission index at minimum). `+harness/CLAUDE.md` is right that adding a dimension
after the curves exist means regenerating all of them.

*Done when:* the slot loop runs 1000 slots with stub layers, the ordering assertions pass, and a
`ctx` created in `+app/` arrives back at `+app/` with every timestamp filled.

### Phase 1 — close the loop with an abstracted PHY
The first real KPI. New: `+harness/+phyabs/` (an SINR → BLER lookup with a placeholder analytic
curve), `+harness/+chanmodel/` at pathloss-plus-shadowing fidelity, `+app/trafficModel`, a
minimum-viable `+rlc/` (UM, no segmentation), and `+mac/`'s **receive** side — clause 5.22.2 is
in `+mac/CLAUDE.md`'s "Not built" list and the loop cannot close without it.

The PDB discard rule from `+phy/+rx/+policy/remainingPdbSlots` is wired in here, at both the MAC
SAP and the selection trigger. Without it latency and throughput both come out flattered, in the
same direction, with no statistic contradicting them.

*Done when:* 20 UEs run for 10 s and produce a latency CDF against the PDB, a throughput figure,
and a PRR-vs-distance curve of roughly the expected shape.

### Phase 2 — the real waveform, behind the same PHY SAP
B4 and B5: `+phy/+chan/` transmit chains and `+phy/+rx/` sync, CE, EQ and detection, as
`+harness/+lls/`. Same SAPs, so the two fidelities become swappable by configuration — which is
what `+harness/CLAUDE.md`'s LLS/SLS agreement test needs in order to exist.

*Done when:* loopback with no channel is bit-exact, and PSCCH/PSSCH BLER over AWGN and TDL has
the expected shape.

### Phase 3 — generate the real BLER tables
Run Phase 2 across the key structure fixed in Phase 0; replace Phase 1's placeholder curve.
State the interpolation rule and the out-of-range behaviour explicitly — silent extrapolation
off the end of a BLER table is how an SLS produces confident nonsense.

*Done when:* LLS and SLS agree on PRR, within a stated tolerance, for a scenario simple enough
to run in both. If they disagree, the abstraction is wrong, not the LLS.

### Phase 4 — deepen the upper layers
Real RLC segmentation and AM, PDCP, SDAP, PC5-S. These shape the latency **tail**, not whether
the loop exists, which is why they come last rather than in `BUILD.md`'s B9 position.

## Where the KPIs actually come from

- **Latency** = `tRxSlot − tGenSlot`, in slots, converted at the end. Reported as a CDF against
  the PDB, never as a mean. The mean of a delivered-only latency distribution is the statistic
  that hides every interesting failure.
- **Reliability** = delivered / generated, with PDB-expired packets counted as **losses**, not
  as slow successes. See the trap in `+phy/+rx/+policy/CLAUDE.md`.
- **Throughput** = delivered payload bytes / wall time, per UE and aggregate.
- **Access delay** = `tTxSlot − tMacSlot`. Worth separating, because under this policy
  (`T2 = PDB`, uniform draw) it dominates the total and it is the term an optimised policy moves.

Every one of these closes on `ctx`. Nothing else is needed, and nothing is read from inside a
module.

## Expect the first latency number to be high, and know why

The current policy sets `T2 =` the remaining PDB and draws uniformly from S_A. That is the
collision-optimal choice and the latency-worst one: mean access delay is about half the
selection window, so a 100 ms PDB yields roughly 50 ms **on an empty channel**. This is a
property of `+phy/+rx/+policy/selectionWindow`, not a bug in `+phy/`. It is also precisely the
knob the optimisation work is aimed at, so Phase 1 measuring it is the point, not a problem.

## Open decisions

1. **Is the bit-exact waveform loop (Phases 2–3) needed for the result?** It is the larger half
   of the remaining work. If the deliverable is latency/throughput vs density and distance, a
   validated abstraction with published or analytically-derived BLER curves may be sufficient,
   with the waveform chain as later validation rather than a prerequisite.
2. **Unicast with PSFCH/HARQ feedback, or broadcast only?** Feedback-driven retransmission
   dominates the latency tail, and `+phy/+ts38213/` has the PSFCH resource machinery already.
   Broadcast with blind retransmission is much less work and is the standard V2X assumption.
3. **Scenario scale.** The gate in `BUILD.md` says 50 UEs; the SLS cost is set by the sensing
   database and the per-slot link matrix, both of which are quadratic in UE count.
