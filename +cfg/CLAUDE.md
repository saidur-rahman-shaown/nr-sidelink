# Configuration and preconfiguration (B0)

Built first. Everything from B2 onward reads this tree, and several SCI field widths are
determined by it.

| Module | Spec | Notes |
|---|---|---|
| `specVersions` | — | frozen version string per spec. Written once, changed only by explicit decision |
| `preconfig` | 38.331 `SL-PreconfigurationNR-r16` | full tree to leaf level |
| `bwpConfig` | 38.331 `SL-BWP-Config`, `sl-BWP-Generic-r16` | |
| `resourcePool` | 38.331 `SL-ResourcePool-r16` | every field, including ones we do not use yet |
| `slrbPreconfig` | 38.331 `sl-RadioBearerPreConfigList-r16`, `sl-RLC-BearerPreConfigList-r16` | SDAP/PDCP/RLC/logical-channel leaves, kept as ASN.1 labels: each is resolved by its owning layer (`rlc.umConfig`/`amConfig`, `pdcp.pdcpConfig`, `mac.slLchConfig`), and `cfgValidate` checks 11-17 run them |
| `bwpLocation` | 38.214 5.1.2.2.2 RIV, N = 275 | BWP start and size; both RIV branches (check 18: BWP inside the carrier) |
| `pqiTable` | 23.287 V19.0.0 Table 5.4.4-1 | PQI → priority, PDB, PER, resource type, unicast-only (NOTE 1); all ten rows, from the PDF |
| `crLimitTable` | 38.331 `SL-CBR-PriorityTxConfigList-r16` → `SL-CBR-CommonTxConfigList-r16` | (priority, CBR range) → sl-CR-Limit, CBR range bounds, default range (TS 38.214 8.1.6's indirection) |
| `rrcReconfigSl` | 38.331 | unicast per-link configuration |
| `cfgValidate` | — | cross-field consistency with clause-cited diagnostics |
| `jsonIO` | — | serialise, deserialise, config hash |

Build order: `specVersions` → `jsonIO` → `bwpConfig` → `resourcePool` → `preconfig` →
`pqiTable` → `rrcReconfigSl` → `cfgValidate`. Write `cfgValidate` last but design its check
list first, because the checks tell you which fields the tree has to expose.

Use the `asn1-extractor` subagent for the 38.331 tree rather than reading it into the main
session.

## Two numerology resolutions — both mandatory at boot
1. `sl-SCS-SpecificCarrierList-r16` → carrier grid numerology
2. `subcarrierSpacing` inside `sl-BWP-Generic-r16` → slot structure numerology

`bootFromPreconfig` asserts both resolved. An out-of-coverage UE has no other source. A
silent default here produces a UE that runs and is wrong.

## Interface rules
- Field names are the ASN.1 identifiers verbatim, with the hyphen transliteration documented
  once. `sl-NumSubchannel`, never `numSubch`.
- The tree is never flattened. Convenience accessors are functions.
- Optional fields carry an explicit presence flag; absence and zero are different.
- Everything serialises to JSON and reloads bit-identically. Test this.

## Validator check list (minimum)
- `sl-StartRB-Subchannel + sl-NumSubchannel × sl-SubchannelSize ≤ BWP size`
- `sl-SubchannelSize` permitted for this SCS
- `sl-TimeResource` bitmap length permitted; its interaction with S-SSB slots leaves the
  claimed number of sidelink slots
- selection window list covers every priority in use
- RSRP threshold list indexed for every (p_i, p_j) pair the pool permits
- PSFCH period and `sl-MinTimeGapPSFCH` consistent with the pool slot set
- DMRS pattern set non-empty, every entry a permitted symbol count
- MCS table selection consistent with the modulation orders the pool allows
- both numerologies present and mutually consistent
- every PQI referenced by a configured flow exists in the table
- a groupcast or broadcast SLRB maps only Non-GBR PQIs (55..59): GBR and DC-GBR are unicast only
  (23.287 Table 5.4.4-1 NOTE 1)

Every failure names the clause it violates.

## The stored config drives the access stratum
`configs/preconfig_example.json` is what `+stack/` runs from. It carries three SLRBs: broadcast
(PQI 58, UM), broadcast low latency (PQI 56, UM, out-of-order), and unicast (PQI 23, GBR, AM). Each SLRB's `sl-DiscardTimer` equals its flows' PDB and its `sl-Priority` equals their PQI
priority (`test_slrbConfig`). Its old BWP `locationAndBandwidth` (1099) encoded a 273-PRB BWP on
a 51-PRB carrier; nothing decoded the RIV, so nothing noticed. It is now 13475 (50 PRB at 0).

## Gate
Three reference configs load and validate. One deliberately broken config is rejected with a
diagnostic naming the field and the clause. Loading a config prints the fully resolved slot
structure and subchannel map for a given DFN.

## Known traps
- **`pqiTable` was once transcribed from recall, and was wrong.** PQI 55 was 100 ms / 1e-1
  (the spec says 10 ms / 1e-4), 56-59 were missing, and thirteen rows did not exist in 23.287.
  Every system-level verdict built on it judged flows against the wrong targets. The table now
  comes from the PDF; never add a row that is not in it.
- Conflating carrier SCS with BWP SCS. Separate resolutions; they can differ.
- Treating a missing optional field as a default rather than an error in the OOC case.
- Deriving SCI-1A field widths anywhere other than from this tree.
