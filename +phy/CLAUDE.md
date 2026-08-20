# PHY — spec split and shared contracts

Sub-packages are named after the specification that governs them. If you cannot decide which
one a module belongs in, the answer is in this table.

| Package | Owns | Test |
|---|---|---|
| `+ts38211/` | anything that determines **what appears on the resource grid**: sequences, scrambling, modulation mapping, DMRS, sync signals, AGC and guard symbols, RE mapping, grid object | "does this place or shape REs?" |
| `+ts38212/` | anything that determines **what the bits are**: CRC, segmentation, polar, LDPC, rate matching, and the SCI and MIB-SL formats | "does this transform a bit vector?" |
| `+ts38213/` | control-plane procedure: pool and slot determination, sync reference selection, DFN, power control, PSFCH resource and timing | "is this a rule about when or where or how loud?" |
| `+ts38214/` | data-plane procedure: sensing, Mode 2 resource selection, MCS and TBS | "is this a rule about which resource to use?" |
| `+ts38215/` | measurement definitions only: SL-RSRP, SL-RSSI, CBR, CR | "does this produce a number from received signal?" |
| `+chan/` | composition of 38.211 and 38.212 into the four channel chains | "does this span both?" |
| `+rx/` | non-normative receive processing | not specified anywhere |
| `+lib/` | wrapped generic DSP and FEC decoders | generic, not sidelink |

The spec-named packages plus `+chan/` are normative: bit-exact, toolbox-free, clause-cited
headers. `+rx/` and `+lib/` are not.

## Slot assembly order — the shared contract
Fixed here because three packages depend on it. Assert it in `+chan/`.

    DMRS → SCI-2 → data → PSCCH region → PSFCH region → guard symbols → AGC symbol last

The AGC symbol duplicates the symbol after it, so it is populated after that symbol exists.
This is why AGC generation is an operation on the grid rather than a signal generator.

## Slot execution order — the runtime contract
Both harnesses implement this and assert it. Full form in `+harness/CLAUDE.md`.

    TIMING → RX (or mark unmonitored) → MEASURE → MAC → TX → POWER → LOG

Half-duplex is not an impairment added later. A slot the UE transmits in is a slot it did not
sense, and the sensing database records that as a first-class fact.

## Cross-package rules
- Numerology is never hardcoded. Every window, offset, and slot count scales with µ and takes
  it from `+cfg/`.
- The logical-to-physical slot mapping is applied **exactly once**. Producer and consumer both
  applying it is the most common defect across `+ts38213/` and `+ts38214/`.
- SCI-1A field widths come from the pool config, not from constants. Any function packing or
  unpacking SCI takes the config as an input.
