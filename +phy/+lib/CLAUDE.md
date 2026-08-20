# Wrapped generics (B1')

Generic, mathematically unambiguous, not sidelink-specific. Wrapped in v1, replaced in v2.

| Module | Replaces |
|---|---|
| `ofdmMod` / `ofdmDemod` | CP handling per numerology |
| `polarDecode` | successive cancellation list |
| `ldpcDecode` | layered min-sum |
| `demodLLR` | LLR computation per modulation order |
| `goldSeq` | Gold sequence generator, 38.211 cl. 5.2.1 -- scrambling, DMRS, sync sequences |
| `modMap` | modulation mapper, BPSK through 256-QAM, 38.211 cl. 5.1 |
| `lowPaprSeq` | low-PAPR sequence generator, 38.211 cl. 5.2.2 -- PSFCH base sequences |
| `scramble` | generic XOR-with-`goldSeq`; per-channel `cinit` derivation stays at the call site |

## The wrapper contract
Each function has a signature **we** define and a toolbox body. When the C port happens, the
body changes and nothing above it does. Write the signature before the body, and write it as
though the toolbox did not exist — if the signature mentions a toolbox object, it is wrong.

This one rule is the difference between a port and a rewrite.

## Toolbox first
For every clause landing in this package: check whether the 5G Toolbox already has a function
for it (`nrPRBS` for `goldSeq`, `nrSymbolModulate` for `modMap`, `nrLowPAPRS` for
`lowPaprSeq`, and so on) before writing anything. If it does, the wrapper body is a thin call into it. If it does not,
hand-write the clause here instead of leaving the module unwrapped — "wrapped in v1" does not
mean "toolbox-backed in v1," it means "isolated behind our own signature in v1." Either way,
keep the same one-clause-one-function-one-header discipline normative code uses (see
`.claude/rules/normative-packages.md`): the header still names the clause and version; only
the body's origin — toolbox call or hand-written — differs, and state which one it is on the
header's first line.

## Tests
Split by which direction of the pair sits here.

- **Decode-side wrappers** (`ofdmDemod`, `polarDecode`, `ldpcDecode`, `demodLLR`): verified
  against the normative encoder each one inverts, over the full parameter range. A decoder
  that recovers what our encoder produced is doing its job; it does not need to match anyone
  else's decoder, because decoding is not normative.
- **Generation-side wrappers** (`ofdmMod`, `goldSeq`, `modMap`, `lowPaprSeq`): these feed the
  bit-exact resource grid, so a round trip against our own decoder is not enough — verified
  against a hand-computed worked example via the `independent-verifier` subagent, same as a
  normative module, even though the code itself lives outside `+ts38211/`.

## Gate
Every decode-side wrapper round-trips against its normative counterpart across the parameter
range; every generation-side wrapper matches its worked example. `module-auditor` reports
zero toolbox calls outside `+lib/` and `+rx/`.
