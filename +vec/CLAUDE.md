# Golden vectors

Produces the acceptance contract for the C and HDL port. Treat every file here as an external
deliverable, because that is what it is.

## Contents
Dump format definition and version, generation scripts per layer boundary, storage layout,
comparison tooling, frozen tagged sets.

## Format rules
- Every file records: dump format version, the frozen spec versions it was generated under,
  the config hash, the module and interface it came from, and its tag.
- Human-readable metadata header, machine-readable payload. Someone will open one of these in
  eighteen months with no context.
- A vector that cannot be traced to a configuration is worthless as an acceptance criterion
  and must not be tagged.

## Freeze policy
- Freeze after B5 for the PHY set, and per gate thereafter.
- A tagged set is never edited. A correction is a new tagged set with a written rationale for
  the difference. "The golden vectors changed" is the most expensive sentence in the hardware
  phase; the rationale document is what makes it survivable.
- Run `/vector-freeze` before tagging. It gates on regeneration from a clean checkout, which
  you must actually run rather than assume.
- Use `vector-differ` to compare sets rather than loading them into the session.

## Coverage statement
Every tagged set ships with a paragraph stating which parameter combinations it represents
**and which it does not**. Absence reads as "unconstrained" to whoever consumes this.
