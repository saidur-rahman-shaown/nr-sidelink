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

## Wave C — transport-channel processing chains — done

Wave B built the SCI-1A/2A/2B/MIB-SL bit *layouts* only — which bits mean what. It never
composed those bits through CRC → coding → rate-matching → multiplexing into the actual coded
bit sequence a transmitter sends. Wave C closes that gap: clause 8.1 (SL-BCH), 8.2+8.2.1
(SL-SCH + multiplexing), 8.3.2–8.3.4 (SCI-1A chain), 8.4.2–8.4.4 (SCI-2 chain + sizing). Every
chain stops at coded/multiplexed bits — scrambling, modulation, and RE mapping are TS 38.211's
job (`+chan/`'s, not built yet), never this package's.

Two of clause 8's cross-references turned out to hide real content, not just "call this generic
procedure":

- **Clause 7.3.2's CRC (used by SCI-1A via 8.3.2, SCI-2 via 8.4.2) is not clause 5.1's CRC.** It
  prepends 24 ones to the payload before computing CRC24C, then discards the ones from the
  output (keeping only payload + new parity). `dciCrcEncode`/`dciCrcCheck` implement this;
  `crcEncode` alone would silently produce a wrong-but-plausible answer. Independent-verifier
  confirmed the prepend-and-discard behaviour and the exact parity value for a worked example,
  plus the RNTI-masking split (top 8 parity bits never masked, low 16 masked MSB-first) — not
  that sidelink ever uses non-empty `rnti`; SCI explicitly skips this step per clause 8.3.2/
  8.4.2's "except that scrambling is not performed."
- **SCI-2's rate matching uses `iBIL=1`** (clause 8.4.4), unlike SCI-1A (`iBIL=0`, via 8.3.4→
  7.3.4) and SL-BCH (`iBIL=0`, via 8.1→7.1.5). Easy to get backwards without re-reading each
  clause's own statement.
- **`slSchEncode`'s legal modulation set is `{QPSK,16QAM,64QAM,256QAM}` only — no BPSK of
  either form.** Confirmed against a rendered TS 38.211 Table 8.3.1.2-1 (Supported modulation
  schemes for PSSCH data), not recalled. This matters because it disagrees with *two* other
  things in this codebase that look like they should govern it: `ldpcRateMatch` (clause 5.4.2,
  generic — correctly allows all six Rel-16 schemes, since it's reused across channels, same
  pattern as `modMap`) and `nrULSCH` itself (permits `'pi/2-BPSK'`, legal for Uu PUSCH but not
  sidelink PSSCH data). Neither generic layer enforces the sidelink-specific restriction —
  `slSchEncode` has to, matching the restriction already independently present in
  `+phy/+ts38211/slPSSCHConfig.m`. This was a real gap in the first version of this file, caught
  when the user asked to verify the swap to `nrULSCH` empirically rather than trust the
  docstring match.

| Module | Clause | Notes |
|---|---|---|
| `slBchEncode` | 8.1 (→ 7.1.3-7.1.5) | mibSlPack's output → CRC24C → polar(nMax=9,iIL=true) → rate match(iBIL=false, E=1386 normal CP / 1782 extended CP) |
| `slSchEncode` | 8.2 (→ 6.2.1-6.2.6) | stops before 8.2.1 multiplexing, produces g^SL-SCH; `I_LBRM=0` always (sidelink fixes this, unlike Uu's UL-SCH). **Toolbox body: `nrULSCH`** — the one Wave C function that calls a toolbox object directly rather than composing Wave A primitives, since `nrULSCH`'s own documentation states it implements exactly "Section 6.2.1 to 6.2.6, without 6.2.7." Verified bit-identical against the original hand-composed chain (`crcEncode`→`cbSegment`→`ldpcEncode`→`ldpcRateMatch`) across both base graphs, the A=3824/3825 CRC-polynomial boundary, and 1-/2-layer transmission before switching — see the file's own header for the comparison. |
| `sci1aChainEncode` | 8.3.2-8.3.4 (→ 7.3.2-7.3.4) | `dciCrcEncode(rnti=[])` → polar(nMax=9,iIL=true) → rate match(iBIL=false) |
| `sci2OutputLength` | 8.4.4 | Q'_SCI2/G^SCI2 sizing formula; γ added *outside* the min{}, no clamp at the "not expected to exceed 4096" figure (a UE-capability statement, not a formula bound) — both independent-verifier-confirmed |
| `sci2ChainEncode` | 8.4.2-8.4.3 + rate match | `dciCrcEncode(rnti=[])` → polar(nMax=9,iIL=true) → rate match(**iBIL=true**) |
| `sci12Multiplex` | 8.2.1 (also serves 8.4.5) | NL=1 fully implemented (independent-verifier-confirmed: plain concatenation, gSci2 then gSlSch, no interleaving); NL=2 raises `nl2NotSupported` — see Known traps |

`slBchEncode`/`sci1aChainEncode`/`sci2ChainEncode`/`sci12Multiplex` compose Wave A primitives by
hand and touch no toolbox function directly. `slSchEncode` is the one exception (see table row
above) — `+phy/+lib/+ts38212/tbCrcSelect`/`ldpcBaseGraphSelect` were built first, then removed
once `nrULSCH` was confirmed to subsume both (clause 6.2.1 CRC-polynomial selection and clause
6.2.2 base-graph selection happen inside `nrULSCH` automatically); nothing else in the tree
called them, so they were dead code once `slSchEncode` stopped needing them.

`dciCrcEncode`/`dciCrcCheck` (clause 7.3.2, generic, reused by both SCI chains) remain in
`+phy/+lib/+ts38212/` alongside Wave A.

`+test/+unit/+phy/+ts38212/test_chains.m` covers structural shape checks and the
independent-verifier worked examples as regression assertions.

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

Wave C: `independent-verifier` worked examples for all four genuinely new hand-derived
procedures (clause 7.3.2's CRC prepend, clause 6.2.2's base graph formula, clause 8.2.1's NL=1
multiplexing, clause 8.4.4's sizing formula) — **done**, locked in as regression assertions in
`test_chains.m`. One of the four checks (dciCrcEncode's A=34 worked example) turned out to be
the verifier's own arithmetic slip, not an implementation bug — confirmed by independently
re-deriving the masked parity via a plain `bitxor` and matching the implementation's output
exactly; the other four cases (including the same masking step at two other RNTI values)
already matched, which is why this was treated as the verifier's error rather than reason to
distrust the earlier matches. Structural/round-trip tests alone (`test_chains.m`'s own
assertions) are the same weak evidence Wave B's FRIV bug already showed they are.

## Gate
Wave A: every primitive round-trips; polar and LDPC encode/decode recover over AWGN at
plausible SNR; a BLER-vs-SNR curve for the LDPC chain from our own encoder. **Worked examples
not yet run** — see Tests above.
Wave B: round trip is the identity over the enumerated space (done), illegal inputs rejected
(done), worked examples agree (**done** — see Tests above).
Wave C: every chain's output length matches its formula (done); `independent-verifier` worked
examples agree (**done** — see Tests above). NL=2 sidelink multiplexing is not implemented —
see Known traps.

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
- **`sci12Multiplex` does not support `NL=2`** (SL-SCH mapped to 2 layers). Clause 8.2.1's NL=2
  branch writes an explicit placeholder bit into the second layer's SCI-2 positions and never
  assigns it a value in this clause — independent-verifier traced the placeholder's actual
  resolution to TS 38.211 clause 8.3.1.1 (PSSCH scrambling: `if b(i)=x, b̃(i)=b̃(i-2)`, i.e. it
  copies the already-scrambled bit two positions earlier). That is not computable from this
  function's pre-scrambling output — implementing NL=2 here would mean either inventing a
  sentinel value or pulling scrambling forward across a stage boundary. Revisit once 38.211
  scrambling exists and the two stages can be composed properly.
- **Clause 6.2.2's base graph formula uses non-strict `≤` throughout** — worth remembering even
  though it now lives inside `nrULSCH` rather than a standalone function in this package.
  Confirmed by rendering the PDF page, not by `pdftotext`, which drops the comparison operators
  in this clause entirely (a different failure mode than the FRIV exponent, same root cause:
  don't trust a text-only PDF extraction for anything with special glyphs). `R ≤ 0.25` selects
  base graph 2 regardless of `A`, even far above the 3824 threshold — the third condition is
  not gated by the first two. If this formula is ever needed standalone again (independent of
  `nrULSCH`), re-derive the operators from a rendered page, don't trust a fresh `pdftotext` read.
