# SDAP (B9) — TS 37.324

Module: `sdapMap` — PC5 QoS flow to sidelink radio bearer.

Small package, but it is the join between `+cfg/pqiTable` and everything that carries priority
downward. The priority that eventually reaches `candidateSet` as `p_j` originates here. Trace
that path explicitly in the header comment, because it crosses four packages and nothing else
documents it end to end.

## Tests
- Every PQI in the table maps to a bearer, and the mapping is total: no flow falls through.
- The priority value arriving at SCI-1A for a given PQI matches the table. Cross-package test,
  and it belongs here.
- An unmapped or unknown PQI is rejected at configuration time by `cfgValidate`, not at
  runtime by a default.

## Gate
Priority propagates correctly from PQI through bearer, MAC, and SCI-1A for every table row.
