---
paths:
  - "+phy/**"
  - "+mac/**"
  - "+rlc/**"
  - "+pdcp/**"
  - "+sdap/**"
  - "+pc5s/**"
  - "+cfg/**"
---
This code is a specification that will be ported to C and HDL.

- Every numeric quantity gets a documented dynamic range in the header. "double" is not an
  answer to "what does this need in fixed point".
- Integer quantities are integer-valued, not doubles carrying integers implicitly. State the
  intended width.
- Configuration mirrors the ASN.1 to leaf level with 3GPP field names verbatim
  (`sl-NumSubchannel`, not `numSubch`). Convenience accessors are functions, never a parallel
  flattened copy.
- Numerology is never hardcoded. Every window, offset, and slot count scales with µ from
  `+cfg/`.
- The logical-to-physical slot mapping is applied exactly once. Document which side applies
  it and assert the other side does not repeat it.
