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

### `+sync/` — acquisition
| Module | What it does |
|---|---|
| `pssSearch` | time-domain correlation for slot timing **and** N_ID,2, jointly |
| `sssDetect` | 336 S-SSS hypotheses → N_ID,1, composed into N_ID^SL |
| `cfoEstimate` | frequency offset from the S-PSS repetition across two symbols |

**Timing and N_ID,2 are acquired together, not in sequence.** The S-PSS sequence depends on
N_ID,2, so there is no "find the timing first, then read the identity". Correlating against one
hypothesis finds half the cells and locks onto a sidelobe for the other half.

**The reference is not trimmed to the S-PSS symbols.** It spans the whole block duration and is
non-zero only where the S-PSS is, so the peak lands on the **block start** — the timing a caller
actually wants. Trimming would put the peak on symbol 1 and force every caller to add back a
CP-aware, numerology-dependent offset, which is what `.claude/rules/portability.md` exists to
keep out of call sites. The correlation and its normalisation are both taken over the non-zero
support: normalising a two-symbol correlation by a thirteen-symbol norm depresses the peak by
about sqrt(2/13) and buries it in the sidelobes of a noisy search. Measured acquisition
(timing within 2 samples **and** correct N_ID,2): 100% at −10 dB, 96% at −15 dB, 32% at −20 dB.

**`cfoEstimate` has a documented constant bias.** The two S-PSS symbols carry identical
frequency-domain values but their time-domain useful parts are not identical samples, leaving a
residual correlation phase at zero offset — about **63 Hz** at µ=1, which is 0.2% of the
subcarrier spacing and 0.45% of the estimator's own unambiguous range (±14 kHz). The error is
flat across that range, so it is a bias and not a scale error. A locally generated zero-offset
reference was tried as a calibration and moved it only to 58 Hz, so it was removed rather than
kept as complexity that does not earn its place. Removing the bias properly needs a different
estimator — a per-subcarrier phase-slope fit — not a correction factor.

### `+det/` — blind detection
| Module | What it does |
|---|---|
| `pscchSearch` | decode attempt at **every sub-channel start**, not at known transmissions |
| `psfchDetect` | sweep every PSFCH resource this UE is monitoring, judged independently |

**The CRC is the detector.** A PSCCH candidate is "found" exactly when its 24-bit CRC checks
after polar decoding — the only honest present/absent test a control channel has. It is not
free of false alarms: roughly one in 16.8 million noise decodes passes, and a receiver sweeping
every sub-channel every slot takes that many draws faster than intuition suggests. This file's
own rule — report false alarm and missed detection **as a pair** — applies to whoever sweeps it.

**`psfchDetect` judges each resource independently, and `ackNackOnly` is per resource.** A UE can
have up to four Sidelink processes outstanding, each with its own PRB and shift pair, and can
have a unicast peer and a NACK-only groupcast running in the same slot. Taking the strongest
correlation in the slot would let a loud ACK from one peer mask another's silence — turning a
radio link failure into a healthy link. A single slot-wide `ackNackOnly` flag would score a
NACK-only resource against an ACK hypothesis Table 16.3-3 does not define.
