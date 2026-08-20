# PDCP (B9) — TS 38.323

Modules: `pdcpTx`, `pdcpRx` — sequence numbering, header construction, discard timer,
reordering.

## Why this small package matters
**PDCP discard is where the packet delay budget becomes enforceable.** Until the discard timer
is wired to the PQI's PDB from `+cfg/pqiTable`, every latency requirement in the project is an
annotation rather than a mechanism, and the SLS will report latencies that no component is
actually bounding.

Wire the discard timer to the PDB at the same time you write the timer, not later.

## Tests
- Round trip: header pack and unpack over the full SN space including wrap.
- Reordering: out-of-order delivery over every permutation of a small window; duplicate
  detection; the reordering timer expiry path.
- Discard: a packet whose PDB expires while queued is discarded **and counted**, not
  transmitted late. Assert the counter — silent discard and silent late transmission look
  identical in a KPI plot.
- The security stub (33.536, deferred) sits in the chain as a pass-through with the correct
  interface shape. Assert it is a pass-through rather than assuming it.

## Gate
SN wrap handled; reordering window correct; discard fires at the PDB and is counted.
