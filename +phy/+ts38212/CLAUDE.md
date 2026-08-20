# TS 38.212 — multiplexing and channel coding

Two waves. Wave A is B1 (coding primitives). Wave B is B2 (control information formats),
which precedes `+chan/` because the channels consume it.

## Wave A — coding primitives (B1)

| Module | Clause | Notes |
|---|---|---|
| `crcEncode` / `crcCheck` | §5.1 | CRC24A, 24B, 24C, 16, 11, 6 |
| `cbSegment` / `cbConcat` | §5.2.2 | with per-code-block CRC |
| `polarEncode` | §5.3.1 | subchannel allocation, frozen set, encoding |
| `polarRateMatch` / `polarDeRateMatch` | §5.4.1 | sub-block interleaver, repetition/puncturing/shortening |
| `ldpcEncode` | §5.3.2 | base graph selection, lifting size, parity |
| `ldpcRateMatch` / `ldpcDeRateMatch` | §5.4.2 | bit interleaving, HARQ buffer, RV start positions |

Build order: `crcEncode` → `cbSegment` → `polarEncode` → `polarRateMatch` → `ldpcEncode` →
`ldpcRateMatch`.

Decoders are **not** here. Polar SCL and LDPC layered min-sum live in `+phy/+lib/`, wrapped
in v1 and replaced in v2. Only the encoders are normative.

## Wave B — control information formats (B2)

| Module | Clause | Contents |
|---|---|---|
| `trivEncode` / `trivDecode` | cl. 8 (semantics in 38.214 cl. 8) | t2/t3 jointly packed via the folded RIV formula |
| `frivEncode` / `frivDecode` | cl. 8 (semantics in 38.214 cl. 8) | start subchannel and length, RIV style |
| `sci1aPack` / `sci1aUnpack` | cl. 8 | priority, FRIV, TRIV, reservation period index, DMRS pattern, 2nd-stage format, β-offset indicator, DMRS port count, MCS, reserved |
| `sci2aPack` / `sci2aUnpack` | cl. 8 | HARQ process ID, NDI, RV, source ID, destination ID, feedback enable, cast type, CSI request |
| `sci2bPack` / `sci2bUnpack` | cl. 8 | 2-A fields plus zone ID and communication range requirement |
| `mibSlPack` / `mibSlUnpack` | 38.331 | 56 bits: coverage indicator, TDD configuration, DFN, slot index, reserved |

Build order: TRIV → FRIV → SCI-1A → SCI-2A → SCI-2B → MIB-SL.

`mibSlPack` is defined in 38.331 but lives here because it is a bit-packing operation and it
belongs with its siblings. Cite 38.331 in its header, not 38.212.

## The interface point that gets missed
SCI-1A is not a fixed-width format. FRIV width depends on `sl-NumSubchannel`, TRIV width on
the maximum number of reserved resources, and the reserved-bit count is pool-configured.
**Pack and unpack therefore take the resource pool config as an input.** A signature without
it is wrong and will work for exactly one pool.

SCI-2 size depends on the β-offset indicator and the DMRS port count signalled in SCI-1A,
which is why `+chan/` cannot size the PSSCH SCI-2 region without this package.

## Tests
Wave B is where round-trip testing earns its keep. The legal field space is small enough to
enumerate completely.
- Exhaustive round trip over the **entire** legal space for TRIV and FRIV, for every
  `sl-NumSubchannel` the pool permits. Compute the space size and state it.
- Exhaustive or near-exhaustive round trip for each SCI format.
- Every illegal input rejected, including combinations individually legal and jointly
  forbidden.
- Structural assertions: a RIV must not exceed its bound; the folded TRIV range must be
  consistent with the N it implies.
- Wave A worked examples: the polar frozen-bit set for one (K, N) pair against the
  reliability sequence; the LDPC base graph and lifting size at a boundary K; one
  rate-matched output length at a puncturing boundary.

## Gate
Wave A: every primitive round-trips; polar and LDPC encode/decode recover over AWGN at
plausible SNR; a BLER-vs-SNR curve for the LDPC chain from our own encoder.
Wave B: round trip is the identity over the enumerated space, illegal inputs rejected,
worked examples agree.

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
