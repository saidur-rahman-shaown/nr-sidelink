# TS 38.212 — multiplexing and channel coding

Two waves. Wave A is B1 (coding primitives). Wave B is B2 (control information formats),
which precedes `+chan/` because the channels consume it.

## Wave A — coding primitives (B1) — relocated to `+phy/+lib/+ts38212/`

All nine Wave A primitives have exact-clause-match 5G Toolbox functions (confirmed against the
installed toolbox source, not recalled — see `+phy/+lib/+ts38212/ch5-toolbox-survey.md`). CRC,
segmentation, polar and LDPC coding/rate-matching are generic 3GPP channel-coding procedures,
identical for Uu and sidelink, not sidelink-specific — so, mirroring `+phy/+ts38211/`'s own
clause-5 primitives, they live in `+phy/+lib/+ts38212/` as thin toolbox wrappers rather than
here. (This package briefly held them directly, under a temporary relaxation of
`.claude/rules/normative-packages.md`'s toolbox-call rule; that placement was a mistake, since
reverted — the rule change itself is left in place as a documented, currently-unused option for
some future normative package, not reverted along with the file move.) `+phy/+ts38212/` itself
now calls `phy.lib.ts38212.crcEncode` etc., same as `+ts38211/` calls `phy.lib.goldSeq`.

| Module | Clause | Notes |
|---|---|---|
| `crcEncode` / `crcCheck` | §5.1 | CRC24A, 24B, 24C, 16, 11, 6 |
| `cbSegment` | §5.2.2 | LDPC direction only; per-code-block CRC. No polar (§5.2.1) counterpart — see survey doc |
| `polarEncode` | §5.3.1 | frozen set and encoding; `nMax`/`iIL` are caller-supplied, not defaulted here |
| `polarRateMatch` / `polarDeRateMatch` | §5.4.1 | sub-block interleaver, repetition/puncturing/shortening |
| `ldpcEncode` | §5.3.2 | takes base graph number as given; *selection* of it stays a "Known trap" below, resolved at the `+phy/+chan/` call site |
| `ldpcRateMatch` / `ldpcDeRateMatch` | §5.4.2 + §5.5 | bit interleaving, HARQ buffer, RV start positions, **and code block concatenation in the same call** — no separate `cbConcat` module, see survey doc |

Build order: `crcEncode` → `cbSegment` → `polarEncode` → `polarRateMatch` → `ldpcEncode` →
`ldpcRateMatch`.

Decoders are **not** here. Polar SCL and LDPC layered min-sum live in `+phy/+lib/`, wrapped
in v1 and replaced in v2. Only the encoders are normative.

## Wave B — control information formats (B2) — done

All twelve functions below were built, spec-verified against locally-extracted PDF text (not
recalled), and passed an `independent-verifier` pass (TRIV formula, FRIV formula, SCI-1A field
table — three separate agent runs, none of which read any `.m` file in this package).
`+test/+unit/+phy/+ts38212/test_waveB.m` round-trips TRIV/FRIV exhaustively and SCI-1A/2A/2B/
MIB-SL across a pool-config sweep, plus the three independent-verifier worked examples as
regression cases — all passing in MATLAB.

**The independent-verifier pass caught a real bug, not a hypothetical one**: `frivEncode`/
`frivDecode`'s `maxReserve==3` branch was initially built with a linear summation term,
matching both this session's own first PDF reading of TS 38.214 clause 8.1.5 *and*
`nrv2x-matlab/phy/SidelinkResourceIndicator.m`'s independently-written implementation — two
supposedly-independent sources that turned out to share the identical error, because
`pdftotext -layout` flattens the term's exponent onto a stray line right next to the summation,
easy to drop in a fresh transcription either way. The correct formula squares that term. The
round-trip test suite passed with the wrong formula too — encode and decode were wrong the same
consistent way, exactly the failure mode `+test/CLAUDE.md` level 1 warns never proves
correctness. Only `independent-verifier`, deriving from spec text with zero code access, caught
it (via glyph-position analysis of the PDF plus a bijectivity argument against clause
8.3.1.1's own bit-width formula). Fixed; the corrected value (FRIV=157 for a specific worked
case) is now a locked-in regression test. **Do not treat `nrv2x-matlab` as a validated
cross-check for this specific formula** — it has the same bug.

| Module | Clause | Contents |
|---|---|---|
| `trivBitWidth` | 38.214 cl. 8.1.5 | 5 bits if `sl-MaxNumPerReserve`=2, else 9 |
| `trivEncode` / `trivDecode` | 38.214 cl. 8.1.5 | folds resource-2/3 time offsets `t1`,`t2` into TRIV; decode is exhaustive search over the legal (t1,t2) domain, correct by construction against encode |
| `frivBitWidth` | 38.212 cl. 8.3.1.1 (formula in 38.214 cl. 8.1.5) | `ceil(log2(v))`, triangular/tetrahedral `v` per `sl-MaxNumPerReserve` |
| `frivEncode` / `frivDecode` | 38.214 cl. 8.1.5 | folds resource-2/3 starting sub-channel indexes into FRIV; `LsubCH` is an external input, not decodable from FRIV alone; `maxReserve==3`'s summation term is **squared** — see the caught-bug note above and the Known traps entry below |
| `additionalMcsTableWidth` | 38.212 cl. 8.3.1.1 | 0/1/2 bits from `sl_Additional_MCS_Table_r16`'s resolved label |
| `sci1aPack` / `sci1aUnpack` | 38.212 cl. 8.3.1.1 | priority (packed as value−1), FRIV, TRIV, reservation period index, DMRS pattern index, 2nd-stage format, β-offset index, DMRS port count, MCS, additional-MCS-table index, PSFCH overhead, reserved (forced to zero) — takes the **whole** `resourcePool.m` struct, field widths span four different sub-IEs |
| `sci2aPack` / `sci2aUnpack` | 38.212 cl. 8.4.1.1 | all fixed-width (35 bits), no pool dependency; HARQ process ID, NDI, RV, source/destination ID, feedback enable, cast type, CSI request |
| `sci2bPack` / `sci2bUnpack` | 38.212 cl. 8.4.1.2 | all fixed-width (48 bits); 2-A's first six fields plus zone ID and communication range requirement |
| `mibSlPack` / `mibSlUnpack` | 38.331, IE `MasterInformationBlockSidelink` | **32 bits**, not 56 (this file previously said 56 — wrong, corrected after reading the ASN.1 directly: TDD-Config(12) + inCoverage(1) + DFN(10) + slotIndex(7) + reserved(2)). Field-order convention is inferred from the SCI packing rule, not independently confirmed for MIB-SL — flagged in the header, pending independent-verifier. |
| `bitsFromUint` / `uintFromBits` / `takeField` | not a spec clause | shared MSB-first bit⇄integer packing/slicing, used by every function above |

Build order: `trivBitWidth` → `trivEncode` → `trivDecode` → `frivBitWidth` → `frivEncode` →
`frivDecode` → `sci1aPack` → `sci1aUnpack` → `sci2aPack` → `sci2aUnpack` → `sci2bPack` →
`sci2bUnpack` → `mibSlPack` → `mibSlUnpack`.

`mibSlPack` is defined in 38.331 but lives here because it is a bit-packing operation and it
belongs with its siblings. Cite 38.331 in its header, not 38.212.

`trivEncode`/`frivEncode` do not choose resources — they fold an already-selected set of
resource offsets into the packed value, mirroring `slPSFCH.m` generating a sequence for a given
cyclic shift rather than choosing the shift. Resource *selection* is TS 38.214 Mode-2 sensing,
a `+phy/+ts38214/` concern, not built yet.

## The interface point that gets missed
SCI-1A is not a fixed-width format. FRIV width depends on `sl-NumSubchannel`, TRIV width on
the maximum number of reserved resources, and the reserved-bit count is pool-configured.
**Pack and unpack therefore take the resource pool config as an input.** A signature without
it is wrong and will work for exactly one pool.

SCI-2 size depends on the β-offset indicator and the DMRS port count signalled in SCI-1A,
which is why `+chan/` cannot size the PSSCH SCI-2 region without this package.

## Tests
Wave A splits by direction: `crcEncode`, `cbSegment`, `polarEncode`, `polarRateMatch`,
`ldpcEncode`, `ldpcRateMatch` are generation-side (their output is transmitted, bit-exact) —
per `+test/CLAUDE.md` level 2, a hand-computed worked example via `independent-verifier` is
required before their vectors are frozen, not just a toolbox round-trip. `crcCheck`,
`polarDeRateMatch`, `ldpcDeRateMatch` are decode-side (receiver-only reconstruction, never
transmitted) — round-trip against the matching generation-side wrapper is sufficient.
`+test/+unit/+phy/+lib/+ts38212/test_wrappers.m` currently covers structural shape and
round-trip only; worked examples are still open.

Wave B is where round-trip testing earns its keep. The legal field space is small enough to
enumerate completely, done in `test_waveB.m`:
- Exhaustive round trip over the **entire** legal space for TRIV (both `maxReserve` values,
  32 + 466 points) and FRIV (swept across representative `sl-NumSubchannel`/`maxReserve`/`L`
  combinations, 2400 points) — all round-trip, no collisions.
- SCI-1A round-tripped across a 96-combination pool-config sweep (varying `sl-NumSubchannel`,
  `sl-MaxNumPerReserve`, `sl-MultiReserveResource`, DMRS pattern count, additional-MCS-table
  label, PSFCH period) so every conditional field width is actually exercised. SCI-2A/2B/MIB-SL
  round-tripped directly (all fixed-width, no pool dependency).
- Illegal inputs rejected: out-of-range `t1`, `nStart1` beyond `Nsub-L`, `priority`,
  `destinationID`, `directFrameNumber`.
- `independent-verifier` worked examples (TRIV formula, FRIV formula, SCI-1A field table) —
  **done**, three separate agent runs, caught and led to fixing the FRIV squared-term bug
  described above. Locked in as regression assertions in `test_waveB.m`.
- Wave A worked examples (polar frozen-bit set, LDPC base graph/lifting size, a rate-matched
  output length at a puncturing boundary): still open, same `+test/CLAUDE.md` level-2
  reasoning — Wave A's toolbox round-trip is weaker evidence than it looks, per Wave B's own
  experience here.

## Gate
Wave A: every primitive round-trips; polar and LDPC encode/decode recover over AWGN at
plausible SNR; a BLER-vs-SNR curve for the LDPC chain from our own encoder. **Worked examples
not yet run** — see Tests above.
Wave B: round trip is the identity over the enumerated space (done), illegal inputs rejected
(done), worked examples agree (**done** — see Tests above).

## Known traps
- Bit ordering in CRC attachment and in rate matching. Fix one convention, document it in the
  package header, assert it at every boundary.
- LDPC base graph selection at the K thresholds; the lifting size lookup selects the smallest
  permitted value, not the nearest.
- Polar sub-block interleaving applied at the wrong point in the chain.
- Rate matching for the second and later redundancy versions, where the HARQ buffer wrap
  conditions live.
- **N is inferred from the TRIV value range, not signalled.** Decoding without reconstructing
  N first produces plausible wrong answers.
- Reserved bits are not free. Their count is configured and they participate in the size.
- **FRIV's `maxReserve==3` summation term is squared** (`sum((Nsub+1-i)^2)`), the `maxReserve==2`
  term is not. `pdftotext -layout` on `38214-gh0.pdf` flattens the exponent onto a stray line
  next to the summation — invisible unless you check glyph position or run the bijectivity
  argument against clause 8.3.1.1's bit-width formula. A linear reading round-trips against
  itself perfectly and silently disagrees with every other implementation. Caught only by
  `independent-verifier`, not by this package's own round-trip tests. If this formula is ever
  re-transcribed from the PDF, re-derive it, don't trust a fresh read to catch it either.
