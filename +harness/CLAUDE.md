# Harnesses (B10)

Two harnesses, both implementing the same intra-slot ordering. LLS at sample resolution, SLS
at slot resolution. The ordering is the contract between every package; it is fixed here and
asserted in both.

## Slot execution model

```
FOR each slot n:
  1. TIMING    advance DFN and slot index; resolve pool membership of n
  2. RX        (only if not transmitting in n — half-duplex)
               a. blind PSCCH decode → SCI-1A set
               b. SL-RSRP per decoded SCI
               c. sensing DB update + reservation projection
               d. PSSCH decode where SCI targets us → SCI-2 → SL-SCH → MAC
               e. PSFCH detection for our prior transmissions
     ELSE      mark n unmonitored
  3. MEASURE   SL-RSSI, CBR window, CR window
  4. MAC       a. re-evaluation check
               b. pre-emption check
               c. reselection trigger evaluation → selection if fired
               d. HARQ process management, RV selection
               e. LCP → build SL-SCH MAC PDU
  5. TX        SCI-1A → PSCCH; SCI-2 + SL-SCH → PSSCH; PSFCH for received PSSCH
  6. POWER     per 38.213 cl. 16
  7. LOG       KPI and vector dump
```

## Sub-packages
`+lls/` full waveform, 1 to 3 UEs. `+sls/` abstracted PHY, many UEs.
`+chanmodel/` TDL, CDL, and the 37.885 V2V models — **wrapped**, not part of the UE.
`+mobility/` trajectory generation.

## PHY abstraction — decide the key structure before generating any curves
The SLS consumes BLER tables produced by the LLS at B5 and B6. Design the table's key
structure at B5, before generating anything: at minimum MCS, SINR, channel model, speed, and
number of retransmissions. Adding a dimension later means regenerating every curve, which is
the most expensive avoidable mistake in this phase.

State the interpolation rule and the out-of-range behaviour. Extrapolating off the end of a
BLER table silently is how an SLS produces confident nonsense.

## Tests
- Ordering assertions in both harnesses, checking no step ran out of sequence.
- LLS and SLS agreement: for a scenario simple enough to run in both, PRR must agree within a
  stated tolerance. If it does not, the abstraction is wrong, not the LLS.
- Determinism: identical seed produces identical output, bit for bit, across runs and
  machines.

## Gate
A 50-UE scenario runs to completion and produces PRR-vs-distance of the expected shape. An
animated scenario view shows per-UE resource occupancy and live PRR.

## Known traps
- Reaching into module internals for convenience. Every KPI comes from the logging interface,
  never from a peek at private state, or the harness will not survive the port.
- Channel model wrapped means wrapped. No toolbox call escapes `+chanmodel/`.
