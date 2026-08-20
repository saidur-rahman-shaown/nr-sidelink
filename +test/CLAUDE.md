# Verification

Four levels, weakest to strongest. Every module needs at least levels 1 and 2 before its
vectors are frozen.

## 1. Round-trip property tests
Every TX/RX inverse pair over the complete valid parameter range. Cheapest, highest bug yield,
run on every commit.

**They prove self-consistency, never correctness.** A consistently misread encoder and its
matching decoder round-trip perfectly. Every test file this level produces says so in its
header.

## 2. Hand-computed worked examples
The only defence against a spec misreading. Values computed from the specification
independently of the implementation, via the `independent-verifier` subagent, which never sees
the code.

**The residual risk, stated plainly:** the verifier is the same model reading the same text.
Isolation removes anchoring on the implementation; it does not remove a misreading the model
would make either way. These are a filter, not a proof. A human checks a sample by hand, and
the sample includes every case where the code and the verifier agreed on something surprising.
Tests awaiting that check are marked `pending-human` and the count is printed at session start.

## 3. Conformance vectors
38.101-4 demodulation requirements and reference measurement channels; 38.521-4 test cases.
The strongest available evidence that the PHY matches other vendors' reading rather than only
our own. This is the level that actually retires the risk in level 2.

Use `conformance-scout` to pull applicable cases as early as each module allows, rather than
saving them for B11.

## 4. Calibration
SLS output against published 37.885 calibration for the same scenario. If PRR-vs-distance does
not match, the model is wrong regardless of how clean the code is.

## Layout
`+unit/` one file per normative function, mirroring the package tree.
`+roundtrip/` inverse-pair property tests. `+conformance/` from 38.101-4 and 38.521-4.
`+calib/` 37.885.

## Standing rules
- A normative module with no test file is a gate failure. `module-auditor` lists orphans.
- A `pending-human` count that grows across three consecutive sessions means the human check
  has stopped happening. Raise it rather than letting it accumulate silently.
- Never adjust an implementation and its worked example together to make them agree. Report
  the disagreement.
