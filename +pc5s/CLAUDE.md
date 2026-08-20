# PC5-S (B9) — TS 24.587

Module: `pc5sLink` — Direct Link Establishment, Modification, Release, keepalive, and
Layer-2 ID management.

Security (33.536) is deferred but interface-stubbed: the stub sits where the security
procedures would, with the correct call shape, so adding it later is a body change.

Build order: L2 ID management → establishment → keepalive → modification → release.

L2 ID management first because every other procedure carries the identifiers, and because the
source and destination IDs also appear in SCI-2 and in `psfchResource`. The derivation from
full L2 ID to the truncated identifiers used in SCI and PSFCH is worth a worked example.

## Tests
- State machine: every transition, including ones that should not happen. A message arriving
  in the wrong state is rejected and the state is unchanged; assert both.
- Timers: keepalive expiry releases the link; establishment retry limit.
- Worked example: the truncated identifiers derived from a stated full L2 ID pair, checked
  against the same values as they appear in SCI-2 and in the PSFCH resource calculation.

## Gate
A unicast link is established over PC5-S and carries AM traffic with correct retransmission on
loss, while a broadcast flow runs concurrently over UM on the same UE.
