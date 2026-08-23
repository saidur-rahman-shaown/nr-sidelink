# Wrapped generics (B1')

Generic, mathematically unambiguous, not sidelink-specific. Wrapped in v1, replaced in v2.

## Layout: flat here, subfoldered per spec once a second spec arrives

The original four TS 38.211 wrappers stay flat, directly in `+phy/+lib/`. Starting with TS
38.212, each additional spec's wrapper set gets its own `+phy/+lib/+tsXXXXX/` subfolder instead
of adding to the flat list — keeps each spec's primitives easy to find and cross-check against
that spec's PDF, and the toolbox-survey doc lives alongside its wrappers in the same subfolder
rather than one shared file with rows from multiple specs. Call as `phy.lib.ts38212.crcEncode`,
etc. `module-auditor`'s "zero toolbox calls outside `+lib/` and `+rx/`" gate still holds — every
subfolder here is still inside `+lib/`.

| Module | Replaces |
|---|---|
| `ofdmMod` / `ofdmDemod` | CP handling per numerology |
| `polarDecode` | successive cancellation list |
| `ldpcDecode` | layered min-sum |
| `demodLLR` | LLR computation per modulation order |
| `goldSeq` | Gold sequence generator, 38.211 cl. 5.2.1 -- scrambling, DMRS, sync sequences |
| `modMap` | modulation mapper, BPSK through 256-QAM, 38.211 cl. 5.1 |
| `lowPaprSeq` | low-PAPR sequence generator, 38.211 cl. 5.2.2 -- PSFCH base sequences |
| `scramble` | generic XOR-with-`goldSeq`; per-channel `cinit` derivation stays at the call site |

### `+ts38212/` subfolder

| Module | Replaces |
|---|---|
| `crcEncode` / `crcCheck` | CRC calculation/verification, 38.212 cl. 5.1 |
| `cbSegment` | LDPC code block segmentation and per-block CRC, 38.212 cl. 5.2.2 |
| `polarEncode` | polar encoding, 38.212 cl. 5.3.1 |
| `polarRateMatch` / `polarDeRateMatch` | polar rate matching, 38.212 cl. 5.4.1 |
| `ldpcEncode` | LDPC encoding, 38.212 cl. 5.3.2 |
| `ldpcRateMatch` / `ldpcDeRateMatch` | LDPC rate matching **and code block concatenation**, 38.212 cl. 5.4.2 + 5.5 -- one call does both, no separate `cbConcat`, see `+ts38212/ch5-toolbox-survey.md` |
| `dciCrcEncode` / `dciCrcCheck` | CRC attachment for DCI/SCI-style payloads (24-ones prepend + CRC24C + optional RNTI mask), 38.212 cl. 7.3.2 -- built on top of `crcEncode`/`crcCheck`, not a reimplementation of clause 5.1 |

`tbCrcSelect` (clause 6.2.1 CRC-polynomial-by-payload-size) and `ldpcBaseGraphSelect` (clause
6.2.2 base-graph threshold formula) were built here, then removed: `+phy/+ts38212/slSchEncode`
switched to calling `nrULSCH` directly (its own documentation states it implements exactly
clause 6.2.1-6.2.6), which handles both selections internally, and nothing else in the tree
called either function. See `+phy/+ts38212/CLAUDE.md`'s Wave C section for the bit-exact
cross-check done before making that switch, and its Known traps for the clause 6.2.2 operator
lesson (`pdftotext` drops the comparison operators in that clause entirely).

Wave B (SCI-1A/2A/2B, MIB-SL, and the TRIV/FRIV resource-indicator formulas) and Wave C (the
SL-BCH/SL-SCH/SCI transport-channel chains and the clause 8.2.1 multiplexing algorithm) do
**not** move here — they're genuinely sidelink-specific with no toolbox equivalent, and stay
hand-written in `+phy/+ts38212/` directly. See `+phy/+ts38212/CLAUDE.md`.

Note: `.claude/rules/normative-packages.md` was, for a time, relaxed to permit calling 5G
Toolbox `nrXxx` functions directly from normative packages, and this Wave A subfolder briefly
lived in `+phy/+ts38212/` under that relaxation before moving back here. The rule relaxation
itself was left in place (a deliberate, separate decision, not tied to this file move) even
though nothing currently in the tree exercises it — Wave B never needed a toolbox call, and
Wave A is back to routing through `+lib/`.

## The wrapper contract
Each function has a signature **we** define and a toolbox body. When the C port happens, the
body changes and nothing above it does. Write the signature before the body, and write it as
though the toolbox did not exist — if the signature mentions a toolbox object, it is wrong.

This one rule is the difference between a port and a rewrite.

## Toolbox first
For every clause landing in this package: check whether the 5G Toolbox already has a function
for it (`nrPRBS` for `goldSeq`, `nrSymbolModulate` for `modMap`, `nrLowPAPRS` for
`lowPaprSeq`, and so on) before writing anything. If it does, the wrapper body is a thin call into it. If it does not,
hand-write the clause here instead of leaving the module unwrapped — "wrapped in v1" does not
mean "toolbox-backed in v1," it means "isolated behind our own signature in v1." Either way,
keep the same one-clause-one-function-one-header discipline normative code uses (see
`.claude/rules/normative-packages.md`): the header still names the clause and version; only
the body's origin — toolbox call or hand-written — differs, and state which one it is on the
header's first line.

## Tests
Split by which direction of the pair sits here.

- **Decode-side wrappers** (`ofdmDemod`, `polarDecode`, `ldpcDecode`, `demodLLR`): verified
  against the normative encoder each one inverts, over the full parameter range. A decoder
  that recovers what our encoder produced is doing its job; it does not need to match anyone
  else's decoder, because decoding is not normative.
- **Generation-side wrappers** (`ofdmMod`, `goldSeq`, `modMap`, `lowPaprSeq`): these feed the
  bit-exact resource grid, so a round trip against our own decoder is not enough — verified
  against a hand-computed worked example via the `independent-verifier` subagent, same as a
  normative module, even though the code itself lives outside `+ts38211/`.

## Gate
Every decode-side wrapper round-trips against its normative counterpart across the parameter
range; every generation-side wrapper matches its worked example. `module-auditor`'s "zero
toolbox calls outside `+lib/` and `+rx/`" gate no longer applies repo-wide since
`.claude/rules/normative-packages.md` now permits direct `nrXxx` calls in normative packages
too — it still holds for whichever code chooses to route through here instead.
