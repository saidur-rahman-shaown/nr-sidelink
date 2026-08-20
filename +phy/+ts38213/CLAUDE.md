# TS 38.213 clause 16 — PHY procedures, control (B6)

Structure, timing, sync, and power. Partially parallel with `+chan/`.

| Module | Notes |
|---|---|
| `slotIsInPool` | `sl-TimeResource` bitmap resolved against DFN, TDD pattern, and S-SSB slots |
| `pscchCandidates` | where PSCCH may appear; drives blind decoding in `+phy/+rx/` |
| `slPowerControl` | open loop, per channel |
| `psfchResource` | (PSSCH slot, subchannel, source ID, member ID) → PRB + cyclic shift |
| `psfchTiming` | first PSFCH-bearing slot at or after `sl-MinTimeGapPSFCH` |
| `syncRefSelect` | priority hierarchy; GNSS at the top for out of coverage |
| `dfnFromGnss` | GNSS time → DFN and slot index |

`subchannelMap` (config → PRB ranges) is defined in 38.214 cl. 8 and lives in `+ts38214/`,
but almost everything here calls it. Take it as an input rather than recomputing it.

## Out of coverage
The DL-pathloss term in `slPowerControl` is absent. **Assert its absence rather than
defaulting it to zero.** A silent default produces a plausible power number, which is the
worst kind of wrong.

`syncRefSelect` for OOC resolves to GNSS or to another UE's S-SSB. There is no gNB branch;
assert that too rather than leaving dead code that implies one.

## Tests
- Property: `slotIsInPool` over a full DFN wrap; over a full `sl-TimeResource` bitmap period;
  with and without S-SSB slots present.
- Worked examples via `independent-verifier`: one PSFCH resource index for a stated
  (slot, subchannel, source, member) tuple; one DFN and slot index derived from a stated GNSS
  time; one transmit power for a stated pathloss and configuration.
- `syncRefSelect` as a truth table over the full priority hierarchy, including ties.

## Gate
Pool membership correct across a DFN wrap. PSFCH resource and timing match worked examples.
A GNSS-synced UE derives the correct DFN with no S-SSB present.

## Known traps
- Applying the logical-to-physical slot mapping twice, once here and once in the consumer.
  Decide where it happens, document it in the header, assert the other side does not repeat
  it.
- Hardcoded slot counts. Everything here scales with numerology.
- `psfchTiming` is "at or after" the minimum gap, resolved to the next PSFCH-bearing slot in
  the pool — not the minimum gap itself.
