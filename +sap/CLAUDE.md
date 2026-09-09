# SAP — the cross-layer vocabulary (non-normative)

## Status: the packet context is built. The other five SAP structs are not.

`+sap/` holds the structs that cross layer boundaries, and nothing else: no algorithms, no
state machines, no protocol logic. It depends on nothing and everything depends on it, which is
what keeps it from becoming a place things get hidden. Not a 3GPP layer — see the note on the
word "SAP" below.

| Module | What it is |
|---|---|
| `ctxInit` | create a packet context at generation |
| `ctxStamp` | record one SAP-boundary crossing (`mac`, `grant`, `tx`, `rx`) |
| `ctxTransmitted` | count a transmission; stamps `tx` on the first only |
| `ctxFinish` | resolve a packet with a terminal outcome |
| `outcomeCodes` | the five outcome constants |

## Why the context comes first, before any of the layers it crosses
`INTEGRATION.md` puts this in Phase 0 rather than with the KPI work, because retrofitting
per-packet instrumentation into a working stack is the step that reliably fails: by then the
layers have been written to hand each other payloads, and threading a context through
afterwards means touching every interface at once. Built first, it is just an argument
everything already carries.

Every KPI the simulator reports is a difference between two fields of this struct. Nothing
reads a timing out of a module's internals — `+harness/CLAUDE.md` already names that as a trap,
and this struct is what makes avoiding it easy rather than disciplined.

## PHYSICAL slots, everywhere in this struct
The logical pool numbering `+phy/+ts38214/` uses is a pool-relative re-indexing that *skips
slots*, so a difference of logical indices is not a duration. Latency is wall-clock. Every
timestamp here is a physical slot index, converted to ms once, at report time, by `2^mu`.
`phy.ts38214.poolSlotMap` is the only place the two numberings meet.

## Known traps
- **`tGenSlot` is the one reference point and never moves.** `+app/CLAUDE.md` fixes it: D_app is
  measured from creation and nowhere else. A later layer that "corrects" it to arrival time
  turns end-to-end latency into MAC latency and drops the queueing delay, which is usually the
  dominant term.
- **A retransmission must not move `tTxSlot`.** `ctxTransmitted` stamps only the first. Moving
  it makes access delay read as "delay of the *last* attempt", so every retransmitting UE looks
  faster than it is, exactly in the regime where the number matters. This is why `nTx` and
  `tTxSlot` are updated by one function rather than by the caller.
- **`pdbExpired` is a LOSS.** It is a distinct code only so a run can report *why* it failed.
  Every reliability figure must count it on the failure side. Scored as a slow success it
  inflates throughput and truncates the latency tail simultaneously and in the same direction,
  so no other statistic contradicts it.
- **A packet left `inFlight` leaves the denominator.** That silently improves the reliability
  figure. The harness must assert no context is still in flight when a run stops, and
  `ctxFinish` refuses a second resolution so the assertion cannot be satisfied by double
  counting.
- **The event name is a `switch`, not a dynamic field name.** A typo must be an error, not a new
  field that quietly absorbs every subsequent stamp. Dynamic field names are banned on
  normative interfaces anyway; the same reasoning applies here for a different reason.

## "SAP" is being used loosely here, and only two of them are real
3GPP names a Service Access Point at an inter-layer boundary: the **MAC SAP** carries *logical
channels* (SBCCH, SCCH, STCH) and the **PHY SAP** carries *transport channels* (SL-BCH,
SL-SCH). Those two are genuine. The RF and channel boundaries in `INTEGRATION.md` are our own
interfaces with the same discipline applied — there is no "RF SAP" in any specification. Do not
go looking for one in TS 38.321.

## Not built
The other five structs `INTEGRATION.md` freezes — the MAC SAP logical-channel queues, the PHY
SAP transmission descriptor, the RF SAP, the channel SAP and the RX SAP. They land as the
layers that need them do.

## Tests
`+test/+unit/+sap/test_ctx.m`, run by `+test/runSapTests.m`. There is no correctness to assert
against a spec, so the tests assert that the *measurement* cannot be corrupted by ordinary
misuse: no boundary stamped twice, no packet resolved twice, no terminal code confusable with
`inFlight`, `tGenSlot` immutable, causality (no stamp before generation, same-slot allowed),
every field range at its boundary, and a cross-check that a context built from `cfg.pqiTable`
and `phy.rx.policy.remainingPdbSlots` agree on how much budget a packet has.
