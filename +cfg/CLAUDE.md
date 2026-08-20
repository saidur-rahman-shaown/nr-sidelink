# Configuration and preconfiguration (B0)

Built first. Everything from B2 onward reads this tree, and several SCI field widths are
determined by it.

| Module | Spec | Notes |
|---|---|---|
| `specVersions` | — | frozen version string per spec. Written once, changed only by explicit decision |
| `preconfig` | 38.331 `SL-PreconfigurationNR-r16` | full tree to leaf level |
| `bwpConfig` | 38.331 `SL-BWP-Config`, `sl-BWP-Generic-r16` | |
| `resourcePool` | 38.331 `SL-ResourcePool-r16` | every field, including ones we do not use yet |
| `pqiTable` | 23.287 | PQI → priority, PDB, PER, resource type |
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

Every failure names the clause it violates.

## Gate
Three reference configs load and validate. One deliberately broken config is rejected with a
diagnostic naming the field and the clause. Loading a config prints the fully resolved slot
structure and subchannel map for a given DFN.

## Known traps
- Conflating carrier SCS with BWP SCS. Separate resolutions; they can differ.
- Treating a missing optional field as a default rather than an error in the OOC case.
- Deriving SCI-1A field widths anywhere other than from this tree.
