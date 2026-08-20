# Build plan pack — clean layer layout

Unpack at the repo root:

    tar xzf slue-build-plan.tar.gz -C /path/to/slue

## Layout

    BUILD.md                         master sequence, gates, critical path
    +cfg/CLAUDE.md                   B0   38.331 preconfiguration, 23.287 PQI
    +phy/CLAUDE.md                   spec split map, slot assembly and execution contracts
    +phy/+ts38211/CLAUDE.md          B1/B3  sequences, modulation, signals, grid
    +phy/+ts38212/CLAUDE.md          B1/B2  coding primitives, SCI formats
    +phy/+ts38213/CLAUDE.md          B6   pool, sync, power, PSFCH resource and timing
    +phy/+ts38214/CLAUDE.md          B7   sensing, Mode 2 selection, MCS/TBS
    +phy/+ts38215/CLAUDE.md          B7   SL-RSRP, SL-RSSI, CBR, CR
    +phy/+chan/CLAUDE.md             B4   PSBCH/PSCCH/PSSCH/PSFCH chains
    +phy/+rx/CLAUDE.md               B5   sync, CE, EQ, detection, policy
    +phy/+lib/CLAUDE.md              B1'  wrapped OFDM and FEC decoders
    +mac/CLAUDE.md                   B8   38.321
    +rlc/ +pdcp/ +sdap/ +pc5s/ +app/ B9   38.322, 38.323, 37.324, 24.587, traffic
    +harness/CLAUDE.md               B10  LLS and SLS
    +vec/ +test/CLAUDE.md            B11  golden vectors, verification levels
    .claude/rules/                   normative-packages, portability, vector-discipline
    .claude/hooks/                   guard-norm, session-context
    .claude/agents/module-auditor.md updated for the new package names

## Replaces
This supersedes the `+norm/` / `+impl/` tree from the previous pack. **Delete the old
`.claude/rules/norm-impl-split.md` and `.claude/rules/matlab-portability.md`** — the new
`normative-packages.md` and `portability.md` replace them, and leaving both in place means
two rules disagreeing about paths that no longer exist.

Keep from the earlier packs: the five skills (`clause-sweep`, `norm-module`, `roundtrip`,
`worked-example`, `vector-freeze`) and the agents `spec-librarian`, `independent-verifier`,
`asn1-extractor`, `vector-differ`, `conformance-scout`. Only `module-auditor` needed
rewriting for the new package names.

## Normative vs implementation, under this layout
The old top-level `+norm/` / `+impl/` split is now a naming convention: **any package named
after a specification is normative**, plus `+chan/` and the stack layers. `+phy/+rx/`,
`+phy/+lib/`, `+harness/`, and `+app/` are not. The hook and the auditor enforce on that
basis; both were rewritten and neither will work against the old paths.
