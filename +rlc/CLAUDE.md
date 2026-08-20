# RLC (B9) — TS 38.322

Modules: `rlcUm`, `rlcAm`.

UM carries broadcast and groupcast; AM carries unicast. Both run concurrently on one UE, on
different logical channels to different destinations, and that concurrency is the gate.

Build order: `rlcUm` first. Segmentation and reassembly without ARQ is the smaller problem
and it exercises the segmentation logic AM also needs. Then `rlcAm`.

## Tests
- Segmentation and reassembly over every segment-size boundary, including a PDU that segments
  into exactly two and one that segments into many.
- UM: reassembly timer expiry discards a partial SDU and does not stall the entity.
- AM: status reporting under loss, retransmission, poll triggering, and the retransmission
  count limit.
- Worked example: one status PDU bitmap hand-computed for a stated loss pattern.

## Gate
AM recovers a lost segment via retransmission while a UM flow runs uninterrupted on the same
UE.

## Known traps
- Reassembly buffers keyed by destination as well as by logical channel. A single-key buffer
  works until the second destination appears.
- The AM retransmission limit path, easy to write and never tested.
