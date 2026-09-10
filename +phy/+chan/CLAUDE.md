# Channel composition (B4)

## Status: PSCCH and PSSCH built and bit-exact in loopback. PSBCH and PSFCH not built.

| Module | State |
|---|---|
| `pscchTx` / `pscchRx` | built; loopback bit-exact, AWGN waterfall 0.99 → 0.00 between −10 and −2 dB |
| `psschTx` / `psschRx` | built; loopback bit-exact for both SCI-2 and the transport block |
| `psbchTx` / `psbchRx` | **not built** |
| `psfchTx` / `psfchRx` | **not built** |

PSBCH was skipped despite this file's own build-order argument ("PSBCH first because it is the
simplest complete chain and exercises every coding primitive end to end"). That argument is
sound and the risk it guards against was covered another way: the coding primitives were
exercised end to end by round-tripping `sci1aChainEncode`, `sci2ChainEncode` and `slSchEncode`
against their new decoders *before* any channel chain was written, which is the same validation
without the RE mapping. PSBCH remains unbuilt because nothing consumes it — sync is idealised —
and PSFCH because the system-level path models it at sequence-detection level rather than
through a waveform. Both are additions, not corrections.

## What the `*Rx` functions do and do not do
Normative inverses only, as this file always said: descramble, demap, de-rate-match, decode.
They take **already-equalised symbols**. Grid extraction, channel estimation and equalisation
are `+phy/+rx/`'s (`+ce/`, `+eq/`), and the signature is where that line lands.

## Traps found while building these
- **PSSCH scrambling RESTARTS at the SCI-2/data boundary.** Clause 8.3.1.1 applies
  `c(i − M~_i,j)` with `M~_i,j = 0` over the SCI-2 portion and `M_bit,SCI2` over the data
  portion — the same sequence twice, not one continuous run across the concatenation. The first
  draft of `psschRx` descrambled it continuously. The error is **silent**: the SCI-2 portion
  descrambles correctly either way because its offset is zero, so control decodes, the receiver
  looks alive, and only the transport block fails — at every SNR, which reads as a coding or
  rate-matching fault rather than a scrambling one. The descrambling sequence now mirrors
  `phy.ts38211.slPSSCHScramble` index for index instead of being re-derived from the clause.
- **Rate-matched lengths are derived from the allocation, never passed in.** `E = 2 × (PSCCH
  data REs)` and `G^SL-SCH = (available REs − SCI-2 REs) × Qm`, both read off the index lists
  *after* DM-RS and the PSCCH REs have been excluded. A length passed in from outside can
  exceed what the allocation carries, and the symptom is REs left unwritten at the end of the
  mapping — noise at the receiver, looking like a channel problem.
- **Per-RE noise variance must be sliced with the symbols.** `psschRx` demodulates the SCI-2
  and data portions at different modulations; handing either the other's variances misweights
  every LLR in the block. Only visible once the equaliser stops returning a scalar.


Composes 38.211 and 38.212 into the four channel chains. Normative: bit-exact, toolbox-free.

The `*Rx` functions here are the **normative inverse operations only** — descramble, demap,
de-rate-match. Detection, equalisation, and channel estimation are not normative and live in
`+phy/+rx/`.

| Module | Chain |
|---|---|
| `psbchTx` / `psbchRx` | 56-bit MIB-SL → CRC → polar → rate match → scramble → QPSK → map |
| `pscchTx` / `pscchRx` | SCI-1A → CRC → polar → rate match → scramble → QPSK → map |
| `psschTx` / `psschRx` | two multiplexed streams, see below |
| `psfchTx` / `psfchRx` | sequence in 1 PRB repeated over 2 symbols, first serving as AGC |

Build order: PSBCH → PSCCH → PSSCH → PSFCH. PSBCH first because it is the simplest complete
chain and exercises every coding primitive end to end. If PSBCH does not round-trip, nothing
downstream will.

## PSSCH is the hard one
Two independently coded streams into one channel:
- **SCI-2 (2-A or 2-B):** CRC → polar → rate match. Resource size determined by the β-offset
  and the DMRS port count signalled in SCI-1A. Size it from those inputs; do not pass a size
  in from outside.
- **SL-SCH:** CRC24A → code block segmentation → LDPC → rate match → concatenation →
  scramble → modulate.

**RE mapping order within the PSSCH region is strict: DM-RS first, then SCI-2, then data.**
Getting this wrong leaves everything working at high SNR and failing subtly at low SNR, which
is the most expensive failure mode in the project because it will not surface until B10.
Assert the order and write a structural test that reads the grid back and confirms which REs
hold what.

## Tests
- Round trip per channel with no impairment: bit-exact recovery.
- Worked examples: the scrambling initialisation value per channel for a stated
  configuration; the SCI-2 resource element count for a stated β-offset and port count; the
  PSFCH sequence for a stated resource index.
- Structural: every RE in a generated slot is attributable to exactly one channel, signal, or
  guard. Write the accounting test; it catches overlaps no BLER curve will explain.

## Gate
A complete SL slot IQ waveform is generated. Every RE is accounted for and attributable to a
clause. The resource grid visualisation matches the slot structure by inspection.

## Known traps
- Scrambling initialisation differs per channel and depends on identities arriving from
  different places. Keep the per-channel derivation visible at the call site.
- PSFCH occupies 1 PRB repeated over 2 OFDM symbols with the first serving as AGC. Not a
  2-PRB allocation, not a single symbol.
- The PSSCH region excludes the PSCCH REs in the first subchannel of the allocation. Rate
  match around them; do not write over them.
