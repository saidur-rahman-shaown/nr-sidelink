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
`+policy/` (see its own CLAUDE.md), plus `+ce/` and `+eq/`. `+sync/` and `+det/` are still
empty.

| Module | What it does |
|---|---|
| `+ce/gridExtract` | pull a channel's data and DM-RS REs out of a received grid, in mapping order |
| `+ce/dmrsEstimate` | least-squares channel estimate at the pilots, interpolated to the data REs, plus a noise-variance estimate from the pilot residual |
| `+eq/zfEqualise` | zero forcing, returning **per-RE** post-equalisation noise variance |

### The receiver is not given the channel or the noise
Both are estimated. A perfect-CSI receiver produces BLER curves 1 to 2 dB optimistic and every
system-level result built on them inherits that bias with nothing anywhere to reveal it — and
since the whole point of `+harness/+lls/` is to replace an invented curve with a measured one,
measuring it against a receiver that knows the answer would defeat the exercise. The measured
cost is about 2 dB against an idealised loopback at the same operating point.

### Per-RE noise variance is the output that matters
Zero forcing divides the noise by the channel, so an RE in a fade comes out with its noise
multiplied by `1/|h|²`. Returning one scalar for the allocation tells the demapper a deeply
faded RE is as reliable as a strong one, and the LLR magnitudes come out confidently wrong
exactly where the errors are. Over AWGN the distinction vanishes (|h| is flat), which is why it
survives a flat-channel test and only costs dB once a frequency-selective channel arrives.

MMSE is the obvious next equaliser — it does not amplify noise in a fade at all. Zero forcing
came first because it has no tuning and no dependence on the noise estimate, so a bug in the
noise estimate cannot hide inside it.

### `+sync/` and `+det/` are still empty, deliberately
`phy.lib.ofdmDemod` assumes the waveform is already time-aligned and frequency-corrected, and
says so. Acquisition is `+sync/`'s job; a demodulator that silently searched for its own timing
would hide every synchronisation failure inside a channel-estimation error. The system-level
path models sync as ideal, per `BUILD.md`'s explicit deferral.
