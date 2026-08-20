# TS 38.215 clause 5 — measurements (B7, before 38.214)

Small package, built immediately before sensing, because sensing cannot be validated without
it.

| Module | Notes |
|---|---|
| `slRsrp` | **two variants** — PSCCH-DMRS-based and PSSCH-DMRS-based. Pool-configured |
| `slRssi` | measurement window per the pool configuration |
| `cbr` | channel busy ratio over its window |
| `cr` | channel occupancy ratio over its window |

## The one thing that matters most here
**Do not conflate the two SL-RSRP variants.** Which one applies is a pool configuration
choice, they measure different reference signals, and they are not interchangeable. Conflate
them once and every PRR curve downstream is quietly wrong with no symptom that points back
here. Take the variant as an explicit input; never infer it inside the function.

## Interface rules
- Every measurement takes its window from `+cfg/`, scaled by numerology. No literal window
  lengths.
- Measurements return a value plus the number of samples it was computed from. A measurement
  over an empty window is not zero; it is absent, and the caller must be able to tell.

## Tests
- Worked examples: an RSRP value for a synthetic grid with known reference-signal power, for
  each variant separately; a CBR for a hand-constructed occupancy pattern.
- Property: CBR and CR both lie in [0, 1]; CR accounting includes our own transmissions and
  CBR does not double-count a slot.
- Boundary: an empty window returns absent, not zero.

## Gate
Both RSRP variants match their worked examples independently. CBR and CR match hand-computed
occupancy patterns including the window edges.
