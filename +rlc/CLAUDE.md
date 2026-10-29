# RLC (B9) — TS 38.322 V16.3.0

## Status: built and tested standalone. NOT integrated.
UM and AM are complete per `Documentations/38322-g30.pdf`, with level-1 and level-2 tests
passing (`matlab -batch "test.runRlcTests"`). Nothing outside `+rlc/` calls this package yet:
MAC still moves raw SDUs through `+sap/lch*`, and `+harness/` knows nothing of RLC. Wiring it in
is a separate step (see "Integration notes" below).

TM (clause 5.2.1) is not built: a TMD PDU is the SDU unchanged, with no header, state or timer.
It carries SBCCH only, which the MIB-SL path in `+phy/` handles directly.

## Modules
| Module | Clause | Notes |
|---|---|---|
| `umConfig` / `amConfig` | 38.331 SL-RLC-Config-r16, §9.1.1.4/5 | ASN.1 labels → numbers; t-Reassembly / t-StatusProhibit are **receiver-selected**, so taken separately |
| `snDiff` | 7.1 | every SN comparison, against the clause's modulus base |
| `windowSize` | 7.2 | the four values as a table, not a formula |
| `siValue` | 6.2.3.4 | Table 6.2.3.4-1 |
| `umdHeaderBytes` / `umdPduPack` / `umdPduParse` | 6.2.2.3 | |
| `amdHeaderBytes` / `amdPduPack` / `amdPduParse` | 6.2.2.4 | |
| `statusPduBytes` / `statusPduPack` / `statusPduParse` | 6.2.2.5, 6.2.3.9–17 | |
| `rxBufInit/Insert/Covered/Complete/MissingBeforeLast/Assemble/Drop/Gaps/SnList` | 5.2.2.2, 5.2.3.2, 5.3.4 | the "byte segments with SN = x" object both receivers reason about |
| `umTxInit/Enqueue/Discard/Build/DataVolume` | 4.2.1.2.2, 5.2.2.1, 5.4, 5.5 | |
| `umRxInit` / `umRxPdu` / `umRxTimer` | 5.2.2.2, 7.1 | |
| `amTxInit/Enqueue/Discard/Build/OnStatus/Timer/DataVolume` | 5.2.3.1, 5.3.2, 5.3.3, 5.4, 5.5 | |
| `amRxInit` / `amRxPdu` / `amRxTimer` / `amRxStatusBuild` | 5.2.3.2, 5.3.4 | |
| `amTxOpportunity` / `amReceive` / `amDataVolume` | 5.2.3.1.1, 6.2.3.6, 5.5 | entity level: STATUS before data; route by D/C |

`private/` holds bit packing and three AM helpers (`considerRetx`, `txSubmitted`,
`txBufferState`, `amRxPollRecheck`), each clause-cited.

### Conventions
- **Octets are 0..255 integer row vectors; several PDUs are one flat vector plus a length
  vector** — the same `sduBytes`/`sduLen` form `mac.muxSlSch` takes, so RLC output drops
  straight into it.
- **Time is an input, in ms.** Timers are stored as deadlines (`-1` = not running). Nothing reads
  a clock. Per time step a caller runs `*Timer(…, now)` and then delivers PDUs. `umRxPdu` and
  `amRxPdu` start and stop timers but never expire them. A restarted t-Reassembly is timed
  from the **expiry instant**, not from `now`, so a coarse caller tick does not stretch it.
- **`tag`** is an opaque caller integer per SDU (a packet-context index, later). RLC never reads
  it. It comes back per UMD PDU (`pduTag`), on AM acknowledgement (`ackedTags`) and on
  max-retx (`maxRetxTags`).
- **One struct per entity side, one entity per (Source L2 ID, Destination L2 ID, LCID).**
  Clause 5.1.1. Keying is the caller's job.

## Known traps (each has a test)
- **UM binds the SN at submission, AM binds it at arrival.** §5.2.2.1.1 gives a UM SN only to a
  PDU that "contains a segment"; §5.2.3.1.1 binds the AM SN "for each RLC SDU received from the
  upper layer". Unsegmented UM SDUs never consume an SN.
- **AM discard must renumber.** Because the AM SN is bound at arrival, deleting an unsent SDU
  leaves a hole the peer waits on forever. `amTxDiscard` shifts every later SN down by one. This
  is safe only because of §5.4's own precondition, and the function asserts that.
- **The sidelink groupcast/broadcast receiver initialises from the first SN it sees** (§7.1).
  Initialised to 0, a receiver joining a stream at SN 40 discards everything until the stream
  wraps. `test_rlcUm` shows both.
- **"Forward" is only half the SN space.** With UM_Window_Size 32 in a 64-SN space, an SN more
  than 32 ahead is really behind, and lands in `[RX_Next_Highest − 32, RX_Next_Reassembly)`,
  where it is discarded. Both the verifier and a first draft of the test got this wrong in the
  same direction.
- **The delivered-SN set must be pruned to the window.** A delivered SDU's bytes leave the
  buffer, so "reassembled and delivered" needs its own record (`doneSn`). Left unpruned, it
  aliases the same SN one wrap later and a new SDU looks already delivered.
- **Completeness needs a last-byte marker.** Contiguous bytes from 0 are not complete until some
  Data field has SI 00/10. `rxBufInsert` keeps the marker even when the carrying Data field is
  otherwise a duplicate.
- **A missing tail is not a "missing byte segment before the last byte received".** Starting
  t-Reassembly on a missing tail would start it on every segmented SDU mid-flight.
- **AM t-Reassembly discards nothing.** It only moves `RX_Highest_Status` and triggers STATUS.
  Copying UM's discard into AM throws away the partial SDUs the NACK is about to repair.
- **A poll on a discarded (duplicate) PDU still triggers STATUS.** That duplicate is usually a
  retransmission sent because the ACK was lost. Ignoring it loops until max-retx.
- **Delayed polls must be re-checked** whenever `RX_Next` or `RX_Highest_Status` moves.
- **Poll counters count new data only.** The buffer-empty / window-stall poll applies to every PDU.
- **Retransmission has strict priority.** If a pending retransmission doesn't fit, new data does
  not overtake it.
- **RETX_COUNT is per SDU and moves at most once per STATUS PDU.** See pending-human (2) below.
- **STATUS truncation never splits an SDU.** Some NACK sets of SN s with ACK_SN = s would put a
  NACK at ACK_SN, which a correct transmitter rejects.
- **A STATUS PDU is validated whole before anything is applied.** An ACK_SN beyond highest
  submitted + 1, a NACK ≥ ACK_SN, or SOend < SOstart discards the report.
- **The dead-link max-retx path runs through t-PollRetransmit**, not through NACKs. No STATUS
  ever arrives, so only §5.3.3.4 expiries drive RETX_COUNT. The first expiry sets it to 0, so
  threshold t4 indicates on the fifth expiry.

## Verification
- **Level 2 (independent-verifier, blind to `+rlc/`), all in `+test/+unit/+rlc/`:**
  - PDU formats: 11 octet vectors plus all header and STATUS sizes, matched on the first run
    (`test_rlcFormats`).
  - AM receive STATUS for a stated loss pattern: the per-PDU state trace, the delayed poll, both
    STATUS PDUs octet for octet (9 and 32 bytes), and grant-truncation (`test_rlcWorkedExamples`
    §1). Matched on the first run.
  - UM receive, groupcast join at SN 40, two t-Reassembly expiries, three discards: every state
    variable (`test_rlcWorkedExamples` §2). Matched on the first run.
  - AM transmit ARQ/poll/RETX trace: matched on the first run through t=21. At t=66 the code
    takes one of the clause's two options; see pending-human (1).
- **Level 1:** exhaustive UMD/AMD(12-bit) header round trips; every STATUS E1/E2/E3 combination;
  UM segmentation at every grant boundary for six SDU sizes; 400-SDU UM streams across wraps;
  AM under 15% two-way loss; 5000 AM SDUs through a 4096-SN space; window stall; the B9 gate.
- **Gate (`test_rlcGate`): met standalone.** One UE runs a UM broadcast flow and an AM unicast
  flow. One AM middle segment is lost and recovered by retransmission. The UM flow delivers all
  100 SDUs with no gap longer than 2 slots.

## pending-human (per `+test/CLAUDE.md` level 2)
1. **§5.3.3.4's retransmission choice after the highest SN is already acknowledged.** The
   clause says "consider the RLC SDU with the highest SN among the RLC SDUs submitted … **or**
   consider any RLC SDU which has not been positively acknowledged". The verifier's literal
   first option re-sends an already-acknowledged SDU and later declares max-retx against it.
   `amTxTimer` uses the highest submitted SDU if it is still unacknowledged, and otherwise the
   lowest unacknowledged submitted SDU (the verifier's "Alternative A", which the test asserts).
2. **RETX_COUNT on the first STATUS PDU that NACKs several segments of one SDU.** Read per SDU,
   the first NACK set zeros it and the second increments it. That charges one loss as a
   retransmission, and `test_rlcAm` caught exactly that in the first draft. Read per segment,
   the second set zeros it again. `considerRetx` lets the zeroing spend that STATUS PDU's one
   action, so both readings give 0.
3. **pollByte's "kB" = 1000 bytes, "mB" = 10^6.** 38.331 says only "kB25 corresponds to 25
   kBytes".
4. **The "no new RLC SDU can be transmitted" poll condition** (§5.3.3.2) is read as window
   stalling, which its "e.g." and NOTE point to. The literal reading also polls whenever the
   transmission buffer holds nothing new, which adds polls on retransmissions. The verifier gave
   both readings and chose the same one.
5. **STATUS encoding choices** (§5.3.4 fixes what is reported, not every encoding): a single
   missing SDU → NACK_SN; two or more consecutive → NACK range; partial SDUs → one SO pair per
   gap, SOend 0xFFFF for an unknown tail; SO pair and range are never combined. All are legal.
   Peers may choose differently, and every parser here accepts all forms.

## Integration notes (not done)
- **MAC side:** `mac.slLcp` allocates bytes per logical channel. That figure is the
  `grantBytes` for `umTxBuild` / `amTxOpportunity`, **excluding MAC subheaders**, which stay
  LCP's to account (2–3 bytes per RLC PDU). `*DataVolume` returns the clause-5.5 figure plus a
  header estimate for sizing LCP's `dataAvailable`.
- **Receive side:** `mac.demuxSlSch` yields SDUs with LCID. Route each by (SRC, DST, LCID) to its
  entity (§5.1.1: a groupcast/broadcast UM receiver is created on the first PDU from a new pair).
- **Latency:** pass the packet-context index as `tag`, and stamp the context when `pduTag` /
  `ackedTags` come back. Segmentation means a packet's last byte, not its first, marks its
  transmit time.
- **PDCP discard (§5.4)** is `umTxDiscard` / `amTxDiscard`. It is a no-op once any byte has gone,
  which `+pdcp/`'s PDB discard must count as "sent late", not "discarded".
