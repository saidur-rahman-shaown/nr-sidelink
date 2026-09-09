# nrSidelink — project guide

A 3GPP Rel-16 NR sidelink (V2X, Mode 2) protocol stack in MATLAB, written as an executable
specification: clause-cited, portable to C and HDL, and verified against the specs rather than
against itself. The end goal is a system-level simulator measuring **latency (PDB) and
throughput** end-to-end, from logical channels at the MAC SAP down through PHY, RF and channel,
and back up at the receiver.

## Read these first
- `BUILD.md` — the master build sequence B0…B11, the gate for each package, and the dependency
  graph. This is the plan of record.
- `.claude/rules/normative-packages.md` — what "normative" means here and the coding rules that
  follow from it (flat interfaces, no hidden state, no magic numbers, clause-cited headers).
- `.claude/rules/portability.md` — the C/HDL port constraints (documented dynamic ranges,
  verbatim 3GPP field names, numerology never hardcoded).
- `.claude/rules/vector-discipline.md` — golden-vector rules.
- `+test/CLAUDE.md` — the four verification levels and what each one does and does not prove.
- The `CLAUDE.md` inside each package — status, module table, known traps, and what is
  deliberately not built. **Read the one for the directory you are about to touch.** They carry
  the hard-won detail; this file only routes you to it.

## Layout
Directory structure is the protocol stack; inside `+phy/` the split is by specification.

    +cfg/        38.331 preconfiguration, 23.287 PQI, validator      (B0, built)
    +phy/
      +ts38211/  sequences, modulation, scrambling, signals, RE map  (built)
      +ts38212/  CRC, polar, LDPC, rate matching, SCI formats        (built)
      +ts38213/  control procedures: sync, PSFCH, Mode-2 control     (built)
      +ts38214/  data procedures: sensing, Mode-2 selection, MCS/TBS (built)
      +ts38215/  measurements: SL-RSRP, SL-RSSI, CBR, CR             (built)
      +chan/     PSBCH/PSCCH/PSSCH/PSFCH transmit chains             (planned, B4)
      +rx/       non-normative receiver                              (planned, B5)
      +lib/      wrapped generics (OFDM, polar SCL, LDPC, LLR)
    +mac/        38.321 §5.22 §6.1.6 — Mode-2 TX path                (B8, built)
    +rlc/ +pdcp/ +sdap/ +pc5s/ +app/   upper layers                  (planned, B9)
    +harness/    link-level and system-level simulation              (planned, B10)
    +vec/ +test/ golden vectors and verification

## Normative vs ours
Any package named after a specification, plus `+chan/`, `+mac/`, `+rlc/`, `+pdcp/`, `+sdap/`,
`+pc5s/`, `+cfg/`, is **normative**: bit-exact against any other compliant implementation, and
subject to every rule in `.claude/rules/normative-packages.md`. `+phy/+rx/`, `+phy/+lib/`,
`+harness/`, `+app/` and any `+policy/` package are ours to tune and replace — toolbox calls are
expected there, but their interfaces to normative packages must stay flat, and a change there
must never force a change on the normative side.

## Do not use `nrv2x-matlab/`
`nrv2x-matlab/` is an **earlier, unverified prototype** kept in-tree for reference only. None of
it has been checked against the specs — no worked examples, no independent verification. It is
not part of the build, not on the critical path, and must not be read, cited, ported, reused, or
treated as a source of truth for anything in `+phy/`, `+mac/`, or `+cfg/`. When a question is
"what does the spec say", the answer comes from the PDF in `Documentations/`, never from there.
Ignore it in searches, audits, and reviews unless explicitly asked about it by name.

The same caution, weaker, applies to `Documentations/Notes/*.md`: they are reformatted notes and
have been caught dropping mathematics (a lost division bar in the `+mac/` counter-draw range, a
dropped exponent in `+phy/+ts38214/`). **Read the PDF for anything mathematical.**

## Session pattern
1. `/clause-sweep` the clause range before writing anything.
2. `/norm-module` per function — clause, interface, test list, then body.
3. `/worked-example` for every normative module, computed by the `independent-verifier`
   subagent, which never sees the code. This is **required, not optional**: it has already
   caught real formula and scoping bugs that both round-trip tests and the prototype missed.
4. `/roundtrip` for every inverse pair.
5. `module-auditor` at each gate; `/vector-freeze` before tagging.

No package advances past its gate with an outstanding `TODO(spec):`, an unverified worked
example, or a module lacking a test file.

## Running tests
    matlab -batch "test.runAllTests"     % all packages
    matlab -batch "test.runPhyTests"     % +phy/
    matlab -batch "test.runMacTests"     % +mac/
