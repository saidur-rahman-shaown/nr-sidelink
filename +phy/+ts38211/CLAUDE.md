# TS 38.211 — physical channels and modulation

Two waves. Wave A is B1 (sequence primitives, needed by everything). Wave B is B3 (sidelink
signals and channels, needs only wave A).

**Status: Wave A and Wave B implemented and passing (no formal `+test/+unit/` files yet, but
every module has been run and checked in MATLAB — see the scratch test scripts referenced in
session history).** All four channels (PSCCH, PSSCH, PSBCH, PSFCH), all sync/reference
signals except PT-RS and CSI-RS resource-element mapping (sequence generation for both exists;
their RE-mapping needs TS 38.214 parameters not in this repo — `slPSSCHIndices` accepts their
occupied-RE lists as an optional, currently-empty input so nothing breaks once they exist).
PSSCH's `dataStartIdx` (its 38.214-governed data-mapping start position) is likewise a
documented, defaulted-to-zero external input, not computed here. Clauses 4–7 (frame structure,
generic functions, uplink/downlink support procedures) are extracted at
`Documentations/Notes/10` through `13-....md`, closing every clause-8 cross-reference except
the two named above.

API convention: every Config is a plain scalar struct (never a MATLAB object — that would
violate `.claude/rules/portability.md`'s "flat numeric arrays and plain scalar structs only",
even though the toolbox's own `nrPDSCHConfig`-style objects are the ergonomic model this
mirrors). Every name uses an `sl` prefix, never `nr` — `.claude/hooks/guard-norm.sh` denies
any write matching `nr[A-Z]...(` in this package, so an `nr`-prefixed name would be blocked
the moment it's written here regardless of whether it calls the toolbox.

**Spec text**: `Documentations/38211-ga0.pdf` (V16.10.0, Release 16) is checked in, and clause
8 (the whole sidelink chapter) is extracted and cleaned up at
`Documentations/Notes/09-TS38211-Sidelink-Physical-Channels-and-Signals.md` — read that before
writing any function here rather than re-deriving from recall. That extraction pass corrected
two things this file previously got wrong from best-effort recall (see "Known traps"). It also
flagged and fixed a real `pdftotext` bug: exponents like `2^31` flatten onto the baseline as
`231` in raw extraction — every `c_init` formula in the Notes file was re-verified against a
rendered PDF page image, but re-check the exponent by eye anyway before trusting a `c_init`
formula copied from anywhere else.

## Wave A — hand-written primitives (B1)

| Module | Clause | Notes |
|---|---|---|
| `slMSeq` | §8.4.2.2.1 (S-PSS) is the only m-sequence in clause 8; generalise from it | configurable polynomial and initialisation; no toolbox equivalent found, hand-written here |
| `slResourceGrid` | §8.2.5 | plain `[K x L x P]` numeric array + an RE-addressing helper function, never an object |

`goldSeq`, `modMap`, `lowPaprSeq`, and `scramble` — originally planned as Wave A modules here —
turned out to have exact-clause-match 5G Toolbox functions (`nrPRBS`, `nrSymbolModulate`,
`nrLowPAPRS`, verified independently against hand-derived spec formulas — see
`+phy/+lib/ch5-toolbox-survey.md`). Per `+phy/+lib/CLAUDE.md`'s "Toolbox first" rule they live
there instead, as thin wrappers — this package calls `lib.goldSeq`/`lib.modMap`/
`lib.lowPaprSeq`/`lib.scramble`, never the toolbox functions directly (the hook would deny it
regardless). `slMSeq` has no toolbox match, so it stays here as genuine hand-written normative
code.

## Wave B — sidelink signals and channels (B3)

### Signals
| Module | Clause | Notes |
|---|---|---|
| `slSPSS` / `slSPSSIndices` | §8.4.2.2 | 127-length, BPSK, **one** m-sequence at cyclic shift `22 + 43*NID2` — i.e. shift 22 or 65, not two base sequences (see Known traps) |
| `slSSSS` / `slSSSSIndices` | §8.4.2.3 | 127-length, BPSK, product of two m-sequences (Uu-SSS-style, not the clause-5.2.1 Gold generator) at shifts derived from NID1/NID2 |
| `slPSSCHDMRS` / `slPSSCHDMRSIndices` | §8.4.1.1 | configuration type 1 and 2; time patterns of 2, 3 or 4 symbols |
| `slPSSCHPTRS` / `slPSSCHPTRSIndices` | §8.4.1.2 | PSSCH only — no PT-RS for PSCCH/PSBCH; driven by `sl-PTRS-Config-r16`, already in `+cfg/resourcePool.m` |
| `slPSCCHDMRS` / `slPSCCHDMRSIndices` | §8.4.1.3 | |
| `slPSBCHDMRS` / `slPSBCHDMRSIndices` | §8.4.1.4 (sequence); mapping is in §8.4.3 with the rest of the S-SS/PSBCH block | |
| `slCSIRS` / `slCSIRSIndices` | §8.4.1.5 | not in the original module list — sidelink does have CSI-RS; found during the clause-8 extraction |
| `slSSBlock` | §8.4.3 | the S-SS/PSBCH block time-frequency structure (Table 8.4.3.1-1) — where S-PSS/S-SSS/PSBCH/PSBCH-DMRS actually land together in one slot |
| `slAgcSymbol` | §8.2.1 | first symbol of PSSCH/PSCCH and of PSFCH each duplicate the symbol immediately after them |
| `slGuardSymbol` | §8.2.1 | exactly one guard symbol, positioned **after** the last symbol of PSSCH/PSFCH/S-SSB — there is no guard symbol *before* PSFCH (see Known traps) |

### Channels
Each channel is a `slXxxConfig` builder (adapts the matching `cfg.resourcePool()` slice plus
per-transmission dynamic parameters into a clean-named struct), a `slXxx` modulation function
(scrambling + modulation + RE-mapping of an already-coded codeword — mirrors `nrPDSCH`, which
also stops there; 38.212 coding is `+chan/`'s job, not built yet), and a `slXxxIndices`
function (mirrors `nrPDSCHIndices`).

| Channel | Clause | Notes |
|---|---|---|
| PSSCH | §8.3.1 | `slPSSCHConfig` / `slPSSCH` / `slPSSCHIndices` — scrambling 8.3.1.1, modulation 8.3.1.2, layer mapping 8.3.1.3, precoding 8.3.1.4, VRB mapping 8.3.1.5, VRB→PRB 8.3.1.6 |
| PSCCH | §8.3.2 | `slPSCCHConfig` / `slPSCCH` / `slPSCCHIndices` — scrambling 8.3.2.1, modulation 8.3.2.2, mapping 8.3.2.3 |
| PSBCH | §8.3.3 | `slPSBCHConfig` / `slPSBCH` / `slPSBCHIndices` — scrambling 8.3.3.1, modulation 8.3.3.2; RE mapping (8.3.3.3) defers to the shared S-SS/PSBCH block structure in §8.4.3, not self-contained |
| PSFCH | §8.3.4 | `slPSFCHConfig` / `slPSFCH` / `slPSFCHIndices` — format 0 only (§8.3.4.2: sequence generation 8.3.4.2.1, mapping 8.3.4.2.2); feedback is sequence/cyclic-shift selection, not a coded codeword, so this mirrors `nrPUCCH0`/`nrPUCCH1` rather than `nrPDSCH` |

## Interface rules
- `slPSSCHDMRS` takes the pattern index as an input. It never derives the pattern, because the
  pattern is signalled in SCI-1A and chosen by the transmitter from the pool-configured set.
- SLSS ID is composed from its two components at the caller, with the legal-range assertion
  at the composition point. Do not spread it across two modules.
- `slAgcSymbol` operates on the grid after the duplicated symbol is populated. See the slot
  assembly order in `+phy/CLAUDE.md`.
- `lib.scramble` is generic. The per-channel initialisation derivation stays visible at the
  call site here, never hidden in a shared helper.
- A shared `slCarrierConfig` struct (from `cfg.bootFromPreconfig()` + `cfg.bwpConfig()`) is
  passed to every channel/signal function alongside its own Config — mirrors `nrCarrierConfig`
  accompanying every toolbox Uu channel call.

## Tests
- Property: m-sequence period and balance; Gold cross-correlation bound; constant modulus for
  the sync sequences; constellation power normalisation per modulation order.
- Worked examples via `independent-verifier`: a gold sequence output at a stated
  initialisation; the S-PSS sequence at a stated N_ID2; the S-SSS at a stated SLSS ID; the
  DMRS symbol positions for each configured pattern.
- Structural: DMRS RE positions match the tables; guard symbol is empty; AGC symbol is
  bit-identical to the symbol it duplicates.

## Gate
Wave A: every primitive matches its worked example, property tests pass.
Wave B: every signal matches its worked example, DMRS positions match for every configured
pattern, AGC duplication is exact, and every channel's `slXxxIndices` output matches a
hand-computed RE map for a stated config.

## Known traps
- The Nc = 1600 offset in the Gold sequence initialisation, inside `lib.goldSeq` now rather
  than here — still worth re-verifying at the call site, since a wrong `cinit` derivation here
  produces the same silent, catastrophic-later failure the offset itself would.
- **Corrected by the §8 extraction**: S-PSS is **one** m-sequence read out at two different
  cyclic shifts (22 for NID2=0, 65 for NID2=1), not two distinct base sequences/polynomials.
  This file previously said "two candidate m-sequences," which is wrong — the real trap is the
  opposite of what that phrasing suggests: the risk is reusing Uu PSS's shift table
  `{0,43,86}` or forgetting the sidelink-specific `+22` offset, not picking the wrong
  polynomial. S-SSS *is* a genuine two-different-sequence product (§8.4.2.3), so don't
  over-correct and assume S-SSS is single-sequence too.
- **Corrected by the §8 extraction**: there is no guard symbol *before* PSFCH. §8.2.1 defines
  exactly one guard symbol, after the last symbol of PSSCH/PSFCH/S-SSB. The reason a UE can't
  transmit PSSCH in the slot position before a PSFCH occasion comes from TS 38.214 §8.1.2.1
  (not present locally), not from an §8.2.1 guard-symbol rule.
- DMRS pattern availability is pool-configured, so a pattern legal in the spec may be illegal
  in this pool. Assert against the config, not the spec range alone.
- `nrPDSCH`-style toolbox functions are the *ergonomic* model for `slPSSCH` etc., not a
  behavioural one — do not call them, even to "check" a result; that is exactly the
  `independent-verifier`'s job, done without seeing this code.
