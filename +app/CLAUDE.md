# Application (B9) — traffic model

Module: `trafficModel` — periodic CAM-like, aperiodic, and variable-size generation, per
ETSI EN 302 637-2.

Not a 3GPP layer and not normative, but it drives everything the KPIs measure, so its
parameters need the same discipline as configuration: taken from config, seeded explicitly,
documented range.

## Rules
- Every generator takes an explicit seed. No implicit shuffling. A KPI run that cannot be
  reproduced exactly is not a result.
- Packet size distribution, generation period, and aperiodic burst statistics all come from
  config, with the source of each default stated in the header.
- Each generated packet carries its PQI from the moment of creation, so the priority path
  through `+sdap/` → `+mac/` → SCI-1A can be traced end to end for a single packet.
- Generation timestamps are recorded at creation, since `D_app` in the delay budget is
  measured from here and nowhere else.

## Tests
- Determinism: identical seed produces an identical packet stream, bit for bit.
- Statistical: generation period and size distribution match the configured parameters over a
  long run, asserted with a tolerance rather than exactly.
- End-to-end trace: one packet followed from generation through PDCP, RLC, MAC, and SCI, with
  its PQI and priority unchanged at every hop.

## Gate
Reproducible traffic streams whose statistics match configuration, with per-packet
end-to-end traceability.
