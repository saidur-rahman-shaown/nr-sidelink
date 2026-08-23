# TS 38.213 clause 16 — PHY procedures, control (B6)

Structure, timing, sync, and power. Partially parallel with `+chan/`.

## Clause 16.1, 16.3, 16.4 — done; clause 16.2 — simplified (max power always)

| Module | Clause | Notes |
|---|---|---|
| `sSsbSlotIndex` | 16.1 | S-SS/PSBCH block slot index within a 16-frame period |
| `slTddConfigEncode` / `slTddConfigDecode` | 16.1 | the 12-bit `sl-TDD-Config` value for MIB-SL (Table 16.1-1 single-pattern, Table 16.1-2 dual-pattern+granularity); feeds `mibSlPack`'s `.tddConfig` field directly, closing the gap that field was left opaque for in Wave B |
| `slPowerControl` | 16.2 (+16.2.4) | **simplified — always returns `pCmax`** (max-power-always policy), not clause 16.2's open-loop formula, per explicit user decision. See "Simplification: clause 16.2" below. |
| `psfchOccasionCheck` | 16.3 | is logical slot `k` a PSFCH transmission occasion |
| `psfchTiming` | 16.3 | first PSFCH-bearing slot at or after `sl-MinTimeGapPSFCH` |
| `psfchPrbRange` | 16.3 | PRB range for a (PSSCH-slot, sub-channel) pair |
| `psfchResource` | 16.3 | resource-index → (PRB offset, cyclic-shift-pair index); **`startSubCH` only**, `allocSubCH` (`Ntype>1`) errors — see Known traps |
| `psfchCyclicShiftM0` / `psfchCyclicShiftMcs` | 16.3, Tables 16.3-1/2/3 | cyclic-shift value lookups; close the `m0`/`mcs` gap `+phy/+ts38211/slPSFCHAlpha.m` already documents as waiting on this clause |
| `harqAckCombine` | 16.3.1 | RX-side cast-type-dependent ACK/NACK combination |
| `reservationPeriodIndex` | 16.4 | reservation period (ms) → `sl-ResourceReservePeriodList` index |
| `mode2ResourceSelect` | 16.4 | Mode-2 resource set → `(N,t1,t2,nStart1,nStart2)`, feeds `trivEncode`/`frivEncode` directly. **Mode 2 only** — Mode 1 (network-scheduled) is out of scope, no `+cfg/` fields exist for it yet. |

Not built, and not found in clause 16.1/16.3/16.4's own text despite appearing in this
package's earlier module list: `slotIsInPool`, `pscchCandidates`, `syncRefSelect`,
`dfnFromGnss`. `syncRefSelect` and `dfnFromGnss` in particular look like they actually cite TS
38.331 (RRC sidelink sync procedures), not TS 38.213 — flagged rather than silently built or
dropped; revisit with an explicit ask before touching them.

`subchannelMap` (config → PRB ranges) is defined in 38.214 cl. 8 and lives in `+ts38214/`,
but almost everything here calls it. Take it as an input rather than recomputing it.

## Simplification: clause 16.2 (power control)

`slPowerControl` always returns `pCmax` — a max-power-always policy, not clause 16.2's real
open-loop formula — per explicit user decision. Every real formula in clause 16.2 (S-SSB/
PSSCH/PSCCH/PSFCH power, plus 16.2.4's prioritization rules) depends on pathloss (a *different*
clause, 7.1.1, not built), CBR/RSRP measurements (no RX measurement pipeline exists), and
resource-grid RB counts (`+ts38214/`/`+chan/`, not built). 16.2.4 additionally reads as
scheduler decision-logic over simultaneous SL/UL/E-UTRA events rather than a pure PHY formula.
The function's other inputs (`p0`, `alpha`, `pathloss`, `mu`, `mRB`) are kept in the signature
for interface stability with a future real implementation but are unused; only `channel`
(validated against the four legal names) and `pCmax` (returned as-is) matter today. Revisit
once pathloss and the measurement pipeline exist.

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
