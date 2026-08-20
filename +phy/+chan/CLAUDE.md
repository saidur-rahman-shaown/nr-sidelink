# Channel composition (B4)

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
