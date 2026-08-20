# TS 38.211 chapter 5 — MATLAB-provided functions

These are already provided by MATLAB (5G Toolbox). Use them directly; no need to reimplement.

| Clause | Function | Covers |
|---|---|---|
| §5.1 | `nrSymbolModulate` | Modulation mapper: pi/2-BPSK, BPSK, QPSK, 16QAM, 64QAM, 256QAM |
| §5.2.1 | `nrPRBS` | Pseudo-random (Gold) sequence generator, `c(n)`, Nc=1600 offset included |
| §5.2.2 | `nrLowPAPRS(u,v,alpha,m)` | Low-PAPR type-1 sequences, all lengths (internally: phase-table for m<30, cyclic-extended Zadoff-Chu for m>=30 — one clause, one call form) |

Note: `nrLowPAPRS` also accepts a `(u,cinit,m)` "type 2" syntax — that is TS 38.211 clause
5.2.3, a different sequence family for Rel-16 DM-RS transform precoding on PUSCH/PUCCH, not a
short-length variant of clause 5.2.2. Confirmed empirically it is **not** constant modulus.
Initially mis-documented here as "the <36-length branch of 5.2.2" — corrected after actually
running it and reading the toolbox source; see `+phy/+lib/lowPaprSeq.m`'s header.
