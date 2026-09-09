# Receiver (B5) — non-normative

Not specified anywhere. This is where our performance comes from and where a vendor
differentiates. Toolbox calls are permitted here and in `+phy/+lib/`, nowhere else.

| Sub-package | Contents |
|---|---|
| `+sync/` | correlation search, CFO estimation and correction, timing tracking |
| `+ce/` | channel estimation, interpolation, noise estimation |
| `+eq/` | equalisation, SINR estimation |
| `+det/` | blind PSCCH decoding, PSFCH energy detection |
| `+policy/` | T2 selection, MCS policy for broadcast, keep-probability policy |

## `+policy/` is the research surface
T2 within its permitted range, MCS choice for broadcast with no CSI feedback, and the
keep-probability decision are UE implementation choices. Every policy function takes its
parameters from config and has a documented default with a stated rationale. A policy
hardcoded in a spec-named package is both a portability defect and a lost experiment.

## Tests — different in kind from the normative packages
There is no bit-exactness to assert here.
- Sync: acquisition probability and timing error distribution vs SNR, **and explicitly vs
  CFO**, since a free-running oscillator is the case that matters on hardware.
- CE and EQ: MSE vs SNR against a perfect-knowledge bound.
- Detection: false alarm and missed detection rates, reported as a pair. Either alone is
  meaningless.
- Policy: no correctness test. Sweep the parameter and report the KPI effect.

## Gate
Loopback with no channel is bit-exact. Over AWGN and TDL, PSCCH and PSSCH BLER curves have
the expected shape. Round trip passes for every SCI format with a real receiver in the loop.

## Known traps
- Letting a receiver limitation drive a change in a normative package. If that seems
  necessary the interface is wrong; stop and say so rather than editing normative code.
- Toolbox leakage upward. The `guard-norm` hook blocks the obvious cases; `module-auditor`
  catches the rest.

## Built so far
`+policy/` only — see `+phy/+rx/+policy/CLAUDE.md`. `+sync/`, `+ce/`, `+eq/` and `+det/` are
still empty; B5 has not started.
