# GRM build plan — master sequence

Directory is the protocol stack. Inside `+phy/`, the split is by specification, since the
five PHY specs divide the work along real functional lines: 38.211 is what goes on the grid,
38.212 is what goes into the bits, 38.213 is control-plane procedure, 38.214 is data-plane
procedure, 38.215 is measurement.

Per-package plans live as `CLAUDE.md` in each directory and load only when work touches that
directory. This file is the sequence, the gates, and the dependency graph.

## Layout

    +cfg/          38.331 preconfiguration, 23.287 PQI table, validator
    +phy/
      +ts38211/    sequences, modulation, scrambling, signals, RE mapping
      +ts38212/    CRC, segmentation, polar, LDPC, rate matching, SCI formats
      +ts38213/    PHY procedures — control: pool/slot, sync, power, PSFCH resource
      +ts38214/    PHY procedures — data: sensing, Mode 2 selection, MCS/TBS
      +ts38215/    measurements: SL-RSRP, SL-RSSI, CBR, CR
      +chan/       channel composition — PSBCH/PSCCH/PSSCH/PSFCH chains
      +rx/         non-normative receiver: sync, channel estimation, equalisation, detection
      +lib/        wrapped generics: OFDM, polar SCL decode, LDPC decode, LLR demap
    +mac/          38.321
    +rlc/          38.322
    +pdcp/         38.323
    +sdap/         37.324
    +pc5s/         24.587
    +app/          traffic model, ETSI EN 302 637-2
    +harness/      link-level and system-level
    +vec/          golden vectors
    +test/         verification

## Normative vs implementation, under this layout
The `+norm/` / `+impl/` split is now a **naming convention rather than a top-level
directory**: any package named after a specification is normative and must be bit-exact
against any other compliant implementation. `+phy/+rx/`, `+phy/+lib/`, and any `+policy/`
package are ours to tune and replace.

This is the answer to "which parts must match exactly": the spec-named packages, plus
`+chan/`, `+mac/`, `+rlc/`, `+pdcp/`, `+sdap/`, `+pc5s/`. The toolbox ban and the header
requirements apply to all of those. The hook and the auditor enforce it on that basis.

## Read order vs build order
Read the specs in numerical order. Do not build in it. A channel spans 38.211 and 38.212
simultaneously, and everything from B2 onward needs the configuration tree from 38.331.

## Sequence

| # | Package | Wave | Specs | Gate |
|---|---|---|---|---|
| B0 | `+cfg/` | — | 38.331, 23.287 | validator accepts 3 good configs, rejects 1 broken with a clause-cited diagnostic |
| B1 | `+phy/+ts38212/` A, `+phy/+ts38211/` A | coding + sequence primitives | 38.212 §5, 38.211 §5 | every primitive round-trips; polar and LDPC recover over AWGN |
| B1' | `+phy/+lib/` | wrappers | — | wrapper contract fixed; no toolbox call outside `+lib/` and `+rx/` |
| B2 | `+phy/+ts38212/` B | SCI formats, TRIV/FRIV | 38.212 cl. 8 | exhaustive round trip over the complete legal field space |
| B3 | `+phy/+ts38211/` B | signals | 38.211 cl. 8 | sequence properties verified; DMRS positions match worked examples |
| B4 | `+phy/+chan/` | channel chains | 38.211 + 38.212 cl. 8 | full SL slot waveform; every RE attributable to a clause |
| B5 | `+phy/+rx/` | receiver | — | loopback bit-exact; BLER curves have the expected shape |
| B6 | `+phy/+ts38213/` | control procedures | 38.213 cl. 16 | pool membership, PSFCH resource and timing, SyncRef, DFN |
| B7 | `+phy/+ts38215/`, `+phy/+ts38214/` | measurement, sensing, selection | 38.215 cl. 5, 38.214 §8.1.4 | candidate set matches a hand-computed S_A including escalation rounds |
| B8 | `+mac/` | — | 38.321 §5.22 | Cresel lifecycle and reselection traceable in the log |
| B9 | `+pdcp/`, `+rlc/`, `+sdap/`, `+pc5s/`, `+app/` | — | 38.323, 38.322, 37.324, 24.587 | unicast AM link and broadcast UM flow concurrently |
| B10 | `+harness/` | LLS + SLS | 37.885 | 50-UE run produces PRR-vs-distance of the expected shape |
| B11 | `+vec/`, `+test/` | validation | 38.101-4, 38.521-4 | calibration matches published curves; golden set tagged |

**Critical path:** B0 → B1 → B2 → B3 → B4 → B5 → B7 → B8 → B10.
B6 partially parallel with B4. S-SSB end-to-end sync and PSFCH/HARQ are deferrable; an SLS
with idealised sync and blind-retransmission-only HARQ is still useful and both back-fill.

## Why B0 first
`sl-NumSubchannel`, `sl-SubchannelSize`, `sl-StartRB-Subchannel`, `sl-TimeResource`, and both
numerology resolutions feed nearly every module from B2 onward. SCI-1A field widths are
themselves config-dependent.

## Why 38.212 splits into two waves either side of 38.211
Wave A is the coding primitives, which everything needs. Wave B is the SCI formats, which are
small, exhaustively testable, and consumed by the channels — so they precede `+chan/`. The
38.211 signals sit between them because they need only the sequence primitives.

## Gate discipline
No package advances past its gate with a `TODO(spec):` marker outstanding, an unverified
worked example, or a module lacking a test file. Run `module-auditor` before declaring any
gate met. Freezing vectors is separately gated by `/vector-freeze`.

## Standing session pattern
1. `/clause-sweep` on the clause range before writing anything.
2. `/norm-module` per function: clause, interface, test list, then body.
3. `/worked-example` for every normative module, computed by `independent-verifier`, which
   never sees the code.
4. `/roundtrip` for every inverse pair.
5. `module-auditor` at the gate, `/vector-freeze` before tagging.
