# TS 38.212 clause 5 — MATLAB-provided functions

These are already provided by MATLAB (5G Toolbox). Use them directly; no need to reimplement.
Every signature below was read from the installed toolbox source
(`/Applications/MATLAB_R2025b.app/toolbox/5g/5g/nr*.m`), not recalled, and cross-checked
against clause 5 of `Documentations/38212-gf0.pdf` (V16.15.0).

| Clause | Function | Covers |
|---|---|---|
| §5.1 | `nrCRCEncode(blk,poly)` | CRC calculation and attachment, all six polynomials (6, 11, 16, 24A, 24B, 24C) |
| §5.1 (inverse) | `nrCRCDecode(blkcrc,poly)` | CRC verification and removal |
| §5.2.2 | `nrCodeBlockSegmentLDPC(blk,bgn)` | LDPC code block segmentation and per-block CRC attachment |
| §5.3.1 | `nrPolarEncode(in,E,nMax,iIL)` | Polar frozen-bit determination, input interleaving, encoding |
| §5.4.1 | `nrRateMatchPolar(in,K,E,iBIL)` | Polar sub-block interleaving, bit selection, coded-bit interleaving |
| §5.4.1 (inverse) | `nrRateRecoverPolar(in,K,N,iBIL)` | Polar rate-matching recovery |
| §5.3.2 | `nrLDPCEncode(in,bgn)` | LDPC encoding (base graph given, not selected) |
| §5.4.2 + §5.5 | `nrRateMatchLDPC(in,outlen,rv,modulation,nlayers,Nref)` | LDPC bit selection, bit interleaving, **and code block concatenation** — see finding below |
| §5.4.2 + §5.5 (inverse) | `nrRateRecoverLDPC(in,trblklen,R,rv,modulation,nlayers,numCB)` | Inverse of the above |

## Finding: no separate `cbConcat` wrapper

`+phy/+ts38212/CLAUDE.md` originally paired `cbConcat` with `cbSegment` under §5.2.2. Two
things were wrong with that:

1. **Clause number.** Code block concatenation is its own top-level clause, **§5.5**
   (`Code block concatenation`), not part of §5.2.2 (`Code block segmentation`). Confirmed by
   reading the PDF directly (§5.5 starts at the section titled "Code block concatenation",
   a simple sequential-vertcat operation over per-code-block rate-matched sequences `f_r`).

2. **It doesn't need its own wrapper.** `nrRateMatchLDPC`'s own help text states it "includes
   the stages of bit selection and interleaving defined for LDPC encoded data and code block
   concatenation (see TS 38.212 Sections 5.4.2 and 5.5)". Called with the full `K`-by-`C`
   matrix of code blocks (one column per block, the natural output of `cbSegment` →
   `ldpcEncode`), it already returns the single concatenated `G`-length output vector.
   `nrRateRecoverLDPC` is the matching inverse.

Building a standalone `cbConcat`/`cbDeconcat` pair would be dead code for the one chain that
needs concatenation (SL-SCH/LDPC) — `ldpcRateMatch`/`ldpcDeRateMatch` already do it. The polar
chain never reaches `C > 1` for the control channels this project builds (SCI/MIB-SL payloads
are far below the §5.2.1 polar segmentation threshold), so concatenation is a non-issue there
too. Decision: no `cbConcat` module. If a future channel genuinely needs concatenation
decoupled from rate matching, add it then with a real caller in hand, not speculatively.

## Not wrapped, and why

- **§5.2.1 polar code block segmentation** — no toolbox function exposes this as a standalone
  call; polar-coded channels (PBCH/PDCCH/PUCCH-style, and this project's SCI/MIB-SL) stay at a
  single code block in practice, so this branch is never exercised here.
- **Base graph selection** (which `bgn` to pass `ldpcEncode`/`cbSegment`) — a K/R threshold
  rule, not itself a clause-5 primitive; belongs at the `+phy/+chan/` SL-SCH call site, already
  flagged as a "Known trap" in `+phy/+ts38212/CLAUDE.md`.
- **§5.3.3 / §5.4.3 channel coding and rate matching of small block lengths** (1-bit, 2-bit,
  and other small-K special cases) — used for very small UCI/CSI payloads on PUCCH in Uu; no
  sidelink control channel this project builds falls into that range (SCI-1A/2A/2B and MIB-SL
  are all dozens of bits), so this is out of scope, matching the omission already in
  `+phy/+ts38212/CLAUDE.md`'s Wave A table.
- **Polar/LDPC decoders** (`nrPolarDecode`, `nrLDPCDecode` — SCL and layered min-sum) — these
  are the `polarDecode`/`ldpcDecode` entries already tracked separately in
  `+phy/+lib/CLAUDE.md`'s B1' table, not part of this clause-5 encode-side survey.
