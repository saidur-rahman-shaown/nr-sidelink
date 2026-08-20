# TS 38.211 §5 — Generic Functions

> **Source:** 3GPP TS 38.211 V16.10.0 (2022-06), Release 16 — *NR; Physical channels and modulation*
> **Scope:** clause 5 in full — the modulation mapper (§5.1), the pseudo-random/Gold sequence
> generator (§5.2.1) and low-PAPR sequence generators types 1 and 2 (§5.2.2, §5.2.3), and OFDM
> baseband signal generation / modulation and upconversion (§5.3, §5.4). This is the clause TS
> 38.211 §8 (sidelink, file 09) points to for every "modulated as described in clause 5.1" and
> "scrambling sequence `c(i)` is given by clause 5.2.1" statement.
> **Status:** verbatim spec extract for §5.1, §5.2.1, §5.2.2 (needed by this project); §5.2.3,
> §5.3.2, §5.3.3 are **stubbed** (heading + one-paragraph summary, not transcribed in full) —
> see "Gaps in this extraction" for why, and cross-check against a rendered PDF page if full
> detail is ever needed there.
> **Priority context:** per the task that produced this file, clause 5's content is **lower
> priority** than clauses 6–7 — the Gold sequence generator and modulation mapper are already
> implemented in `+phy/+lib` and independently verified against the 5G Toolbox (see
> `+phy/+lib/ch5-toolbox-survey.md`). Extracted here for completeness of the notes series and to
> resolve file 09's gap-table row for §5.2.1/§5.1, not because anything is currently blocked on
> it — **except** Table 5.2.2.2-2 (the 12-point low-PAPR base sequence table), which **is**
> load-bearing: PSFCH's cyclic-shifted sequence (file 09 §8.3.4.2.1, this project's blocked
> `slPSFCH.m`) is exactly length 12 and uses this table.

## Contents

- [5 Generic functions](#5-generic-functions)
  - [5.1 Modulation mapper](#51-modulation-mapper)
    - [5.1.1 π/2-BPSK](#511-π2-bpsk)
    - [5.1.2 BPSK](#512-bpsk)
    - [5.1.3 QPSK](#513-qpsk)
    - [5.1.4 16QAM](#514-16qam)
    - [5.1.5 64QAM](#515-64qam)
    - [5.1.6 256QAM](#516-256qam)
  - [5.2 Sequence generation](#52-sequence-generation)
    - [5.2.1 Pseudo-random sequence generation](#521-pseudo-random-sequence-generation)
    - [5.2.2 Low-PAPR sequence generation type 1](#522-low-papr-sequence-generation-type-1)
      - [5.2.2.1 Base sequences of length 36 or larger](#5221-base-sequences-of-length-36-or-larger)
      - [5.2.2.2 Base sequences of length less than 36](#5222-base-sequences-of-length-less-than-36)
    - [5.2.3 Low-PAPR sequence generation type 2 (stub — not used by sidelink)](#523-low-papr-sequence-generation-type-2-stub--not-used-by-sidelink)
  - [5.3 OFDM baseband signal generation](#53-ofdm-baseband-signal-generation)
    - [5.3.1 OFDM baseband signal generation for all channels except PRACH and RIM-RS](#531-ofdm-baseband-signal-generation-for-all-channels-except-prach-and-rim-rs)
    - [5.3.2 OFDM baseband signal generation for PRACH (stub — not used by sidelink)](#532-ofdm-baseband-signal-generation-for-prach-stub--not-used-by-sidelink)
    - [5.3.3 OFDM baseband signal generation for RIM-RS (stub — not used by sidelink)](#533-ofdm-baseband-signal-generation-for-rim-rs-stub--not-used-by-sidelink)
  - [5.4 Modulation and upconversion](#54-modulation-and-upconversion)
- [Gaps in this extraction](#gaps-in-this-extraction)

---

## 5 Generic functions

### 5.1 Modulation mapper

The modulation mapper takes binary digits, 0 or 1, as input and produces complex-valued
modulation symbols as output.

#### 5.1.1 π/2-BPSK

In case of π/2-BPSK modulation, bit `b(i)` is mapped to complex-valued modulation symbol `d(i)`
according to

```
d(i) = e^(jπ/2·(i mod 2)) · (1/√2) · [(1−2b(i)) + j(1−2b(i))]
```

#### 5.1.2 BPSK

In case of BPSK modulation, bit `b(i)` is mapped to complex-valued modulation symbol `d(i)`
according to

```
d(i) = (1/√2) · [(1−2b(i)) + j(1−2b(i))]
```

#### 5.1.3 QPSK

In case of QPSK modulation, pairs of bits `b(2i), b(2i+1)` are mapped to complex-valued modulation
symbols `d(i)` according to

```
d(i) = (1/√2) · [(1−2b(2i)) + j(1−2b(2i+1))]
```

#### 5.1.4 16QAM

In case of 16QAM modulation, quadruplets of bits `b(4i), b(4i+1), b(4i+2), b(4i+3)` are mapped to
complex-valued modulation symbols `d(i)` according to

```
d(i) = (1/√10) · { (1−2b(4i))·[2−(1−2b(4i+2))] + j(1−2b(4i+1))·[2−(1−2b(4i+3))] }
```

#### 5.1.5 64QAM

In case of 64QAM modulation, hextuplets of bits `b(6i)…b(6i+5)` are mapped to complex-valued
modulation symbols `d(i)` according to

```
d(i) = (1/√42) · { (1−2b(6i))·[4−(1−2b(6i+2))·[2−(1−2b(6i+4))]]
                  + j(1−2b(6i+1))·[4−(1−2b(6i+3))·[2−(1−2b(6i+5))]] }
```

#### 5.1.6 256QAM

In case of 256QAM modulation, octuplets of bits `b(8i)…b(8i+7)` are mapped to complex-valued
modulation symbols `d(i)` according to

```
d(i) = (1/√170) · { (1−2b(8i))·[8−(1−2b(8i+2))·[4−(1−2b(8i+4))·[2−(1−2b(8i+6))]]]
                    + j(1−2b(8i+1))·[8−(1−2b(8i+3))·[4−(1−2b(8i+5))·[2−(1−2b(8i+7))]]] }
```

> These six formulas are what every sidelink "modulated as described in clause 5.1" reference
> (file 09 §8.3.1.2 PSSCH, §8.3.2.2 PSCCH, §8.3.3.2 PSBCH) resolves to. This project's existing
> modulation-mapper implementation was already verified against the 5G Toolbox per
> `+phy/+lib/ch5-toolbox-survey.md` — nothing here should be new, this is the spec citation for
> what is already implemented.

### 5.2 Sequence generation

#### 5.2.1 Pseudo-random sequence generation

Generic pseudo-random sequences are defined by a length-31 Gold sequence. The output sequence
`c(n)` of length `M_PN`, where `n = 0,1,…,M_PN−1`, is defined by

```
c(n)      = (x1(n+N_C) + x2(n+N_C)) mod 2
x1(n+31)  = (x1(n+3) + x1(n)) mod 2
x2(n+31)  = (x2(n+3) + x2(n+2) + x2(n+1) + x2(n)) mod 2
```

where `N_C = 1600` and the first m-sequence `x1(n)` shall be initialized with `x1(0)=1`,
`x1(n)=0` for `n=1,2,…,30`. The initialization of the second m-sequence `x2(n)` is denoted by
`c_init = Σ_{i=0}^{30} x2(i)·2^i`, with the value depending on the application of the sequence.

> This is the generator every `c_init` formula in file 09 (PSSCH/PSCCH/PSBCH scrambling, all four
> DM-RS types, CSI-RS) initializes. File 09 already documents and fixes the `pdftotext -layout`
> bug where `2^15`, `2^16`, `2^17`, `2^31` collapse onto the baseline as `215`, `216`, `217`,
> `231` in the raw extraction — the same bug reappears in this clause's own exponents (`N_C=1600`
> has no such bug, but `c_init`'s `2^i` sum and the `x1/x2` recursions' `+31`/`+3`/`+2`/`+1` index
> offsets were re-verified against a rendered page image to confirm none of them are mis-collapsed
> exponents; they are not — they are ordinary additive index offsets, correctly extracted).

#### 5.2.2 Low-PAPR sequence generation type 1

The low-PAPR sequence `r_u,v^(α,δ)(n)` is defined by a cyclic shift `α` of a base sequence
`r_u,v(n)` according to

```
r_u,v^(α,δ)(n) = e^(jαn) · r_u,v(n),     0 ≤ n < M_ZC
```

where `M_ZC = m·N_sc^RB / 2^δ` is the length of the sequence. Multiple sequences are defined from
a single base sequence through different values of `α` and `δ`.

Base sequences `r_u,v(n)` are divided into groups, where `u ∈ {0,1,…,29}` is the group number and
`v` is the base sequence number within the group, such that each group contains one base sequence
(`v=0`) of each length `M_ZC = m·N_sc^RB/2^δ`, `1/2 ≤ m/2^δ ≤ 5`, and two base sequences (`v=0,1`)
of each length `M_ZC = m·N_sc^RB/2^δ`, `6 ≤ m/2^δ`. The definition of the base sequence
`r_u,v(0),…,r_u,v(M_ZC−1)` depends on the sequence length `M_ZC`.

> **This is the clause 6.3.2.2 (file 12) points to as `r_u,v^(α,δ)(n)`.** PSFCH (file 09
> §8.3.4.2.1) needs this with `N_sc^RB = 12`, `δ = 0` ⟹ `M_ZC = 12`, which falls into
> §5.2.2.2 below (the "length less than 36" branch, specifically the `M_ZC=12` phase table).

##### 5.2.2.1 Base sequences of length 36 or larger

For `M_ZC ≥ 3·N_sc^RB`, the base sequence `r_u,v(0),…,r_u,v(M_ZC−1)` is given by

```
r_u,v(n) = x_q(n mod N_ZC)
x_q(m)   = e^(-j·π·q·m·(m+1) / N_ZC)

q  = floor(q̄ + 1/2) + v·(−1)^floor(2q̄)
q̄  = N_ZC · (u+1) / 31
```

`N_ZC` is the largest prime number such that `N_ZC < M_ZC`.

> **Not needed by this project.** PSFCH's `M_ZC = 12 < 36`, so it never reaches this branch. Kept
> for completeness of the generic definition only.

##### 5.2.2.2 Base sequences of length less than 36

For `M_ZC ∈ {6,12,18,24}`, the base sequence is given by

```
r_u,v(n) = e^(jφ(n)π/4),     0 ≤ n ≤ M_ZC−1
```

where the value of `φ(n)` is given by Tables 5.2.2.2-1 to 5.2.2.2-4 (one table per length).

For `M_ZC = 30`, the base sequence `r_u,v(0),…,r_u,v(M_ZC−1)` is given by

```
r_u,v(n) = e^(-jπ(u+1)(n+1)(n+2)/31),     0 ≤ n ≤ M_ZC−1
```

> **PSFCH uses `M_ZC=12`, so Table 5.2.2.2-2 below is the load-bearing one** for
> `slPSFCH.m`'s cyclic-shift/base-sequence generation. Tables 5.2.2.2-1, -3, -4 (`M_ZC=6,18,24`)
> are included for clause completeness but are not needed by any sidelink channel — see "Gaps in
> this extraction" for how they are presented (fixed-width block, not a reflowed Markdown table,
> to keep transcription-error risk low on data this project does not consume).

**Table 5.2.2.2-2: Definition of φ(n) for M_ZC = 12** *(needed for PSFCH — reconstructed as a full
Markdown table, cross-checked against the source page)*

| u | φ(0)…φ(11) |
|---|---|
| 0 | −3 1 −3 −3 −3 3 −3 −1 1 1 1 −3 |
| 1 | −3 3 1 −3 1 3 −1 −1 1 3 3 3 |
| 2 | −3 3 3 1 −3 3 −1 1 3 −3 3 −3 |
| 3 | −3 −3 −1 3 3 3 −3 3 −3 1 −1 −3 |
| 4 | −3 −1 −1 1 3 1 1 −1 1 −1 −3 1 |
| 5 | −3 −3 3 1 −3 −3 −3 −1 3 −1 1 3 |
| 6 | 1 −1 3 −1 −1 −1 −3 −1 1 1 1 −3 |
| 7 | −1 −3 3 −1 −3 −3 −3 −1 1 −1 1 −3 |
| 8 | −3 −1 3 1 −3 −1 −3 3 1 3 3 1 |
| 9 | −3 −1 −1 −3 −3 −1 −3 3 1 3 −1 −3 |
| 10 | −3 3 −3 3 3 −3 −1 −1 3 3 1 −3 |
| 11 | −3 −1 −3 −1 −1 −3 3 3 −1 −1 1 −3 |
| 12 | −3 −1 3 −3 −3 −1 −3 1 −1 −3 3 3 |
| 13 | −3 1 −1 −1 3 3 −3 −1 −1 −3 −1 −3 |
| 14 | 1 3 −3 1 3 3 3 1 −1 1 −1 3 |
| 15 | −3 1 3 −1 −1 −3 −3 −1 −1 3 1 −3 |
| 16 | −1 −1 −1 −1 1 −3 −1 3 3 −1 −3 1 |
| 17 | −1 1 1 −1 1 3 3 −1 −1 −3 1 −3 |
| 18 | −3 1 3 3 −1 −1 −3 3 3 −3 3 −3 |
| 19 | −3 −3 3 −3 −1 3 3 3 −1 −3 1 −3 |
| 20 | 3 1 3 1 3 −3 −1 1 3 1 −1 −3 |
| 21 | −3 3 1 3 −3 1 1 1 1 3 −3 3 |
| 22 | −3 3 3 3 −1 −3 −3 −1 −3 1 3 −3 |
| 23 | 3 −1 −3 3 −3 −1 3 3 3 −3 −1 −3 |
| 24 | −3 −1 1 −3 1 3 3 3 −1 −3 3 3 |
| 25 | −3 3 1 −1 3 3 −3 1 −1 1 −1 1 |
| 26 | −1 1 3 −3 1 −1 1 −1 −1 −3 1 −1 |
| 27 | −3 −3 3 3 3 −3 −1 1 −3 3 1 −3 |
| 28 | 1 −1 3 1 1 −1 −1 −1 1 3 −3 1 |
| 29 | −3 3 −3 3 −3 −3 3 −1 −1 1 3 −3 |

**Tables 5.2.2.2-1, -3, -4 (M_ZC = 6, 18, 24 — not needed by sidelink, included for completeness)**

```
Table 5.2.2.2-1: Definition of φ(n) for M_ZC = 6

  u    φ(0),...,φ(5)
  0    -3 -1  3  3 -1 -3
  1    -3  3 -1 -1  3 -3
  2    -3 -3 -3  3  1 -3
  3     1  1  1  3 -1 -3
  4     1  1  1 -3 -1  3
  5    -3  1 -1 -3 -3 -3
  6    -3  1  3 -3 -3 -3
  7    -3 -1  1 -3  1 -1
  8    -3 -1 -3  1 -3 -3
  9    -3 -3  1 -3  3 -3
 10    -3  1  3  1 -3 -3
 11    -3 -1 -3  1  1 -3
 12     1  1  3 -1 -3  3
 13     1  1  3  3 -1  3
 14     1  1  1 -3  3 -1
 15     1  1  1 -1  3 -3
 16    -3 -1 -1 -1  3 -1
 17    -3 -3 -1  1 -1 -3
 18    -3 -3 -3  1 -3 -1
 19    -3  1  1 -3 -1 -3
 20    -3  3 -3  1  1 -3
 21    -3  1 -3 -3 -3 -1
 22     1  1 -3  3  1  3
 23     1  1 -3 -3  1 -3
 24     1  1  3 -1  3  3
 25     1  1 -3  1  3  3
 26     1  1 -1 -1  3 -1
 27     1  1 -1  3 -1 -1
 28     1  1 -1  3 -3 -1
 29     1  1 -3  1 -1 -1

Table 5.2.2.2-3: Definition of φ(n) for M_ZC = 18

  u    φ(0),...,φ(17)
  0   -1  3 -1 -3  3  1 -3 -1  3 -3 -1 -1  1  1  1 -1 -1 -1
  1    3 -3  3 -1  1  3 -3 -1 -3 -3 -1 -3  3  1 -1  3 -3  3
  2   -3  3  1 -1 -1  3 -3 -1  1  1  1  1  1 -1  3 -1 -3 -1
  3   -3 -3  3  3  3  1 -3  1  3  3  1 -3 -3  3 -1 -3 -1  1
  4    1  1 -1 -1 -3 -1  1 -3 -3 -3  1 -3 -1 -1  1 -1  3  1
  5    3 -3  1  1  3 -1  1 -1 -1 -3  1  1 -1  3  3 -3  3 -1
  6   -3  3 -1  1  3  1 -3 -1  1  1 -3  1  3  3 -1 -3 -3 -3
  7    1  1 -3  3  3  1  3 -3  3 -1  1  1 -1  1 -3 -3 -1  3
  8   -3  1 -3 -3  1 -3 -3  3  1 -3 -1 -3 -3 -3 -1  1  1  3
  9    3 -1  3  1 -3 -3 -1  1 -3 -3  3  3  3  1  3 -3  3 -3
 10   -3 -3 -3  1 -3  3  1  1  3 -3 -3  1  3 -1  3 -3 -3  3
 11   -3 -3  3  3  3 -1 -1 -3 -1 -1 -1  3  1 -3 -3 -1  3 -1
 12   -3 -1 -3 -3  1  1 -1 -3 -1 -3 -1 -1  3  3 -1  3  1  3
 13    1  1 -3 -3 -3 -3  1  3 -3  3  3  1 -3 -1  3 -1 -3  1
 14   -3  3 -1 -3 -1 -3  1  1 -3 -3 -1 -1  3 -3  1  3  1  1
 15    3  1 -3  1 -3  3  3 -1 -3 -3 -1 -3 -3  3 -3 -1  1  3
 16   -3 -1 -3 -1 -3  1  3 -3 -1  3  3  3  1 -1 -3  3 -1 -3
 17   -3 -1  3  3 -1  3 -1 -3 -1  1 -1 -3 -1 -1 -1  3  3  1
 18   -3  1 -3 -1 -1  3  1 -3 -3 -3 -1 -3 -3  1  1  1 -1 -1
 19    3  3  3 -3 -1 -3 -1  3 -1  1 -1 -3  1 -3 -3 -1  3  3
 20   -3  1  1 -3  1  1  3 -3 -1 -3 -1  3 -3  3 -1 -1 -1 -3
 21    1 -3 -1 -3  3  3 -1 -3  1 -3 -3 -1 -3 -1  1  3  3  3
 22   -3 -3  1 -1 -1  1  1 -3 -1  3  3  3  3 -1  3  1  3  1
 23    3 -1 -3  1 -3 -3 -3  3  3 -1  1 -3 -1  3  1  1  3  3
 24    3 -1 -1  1 -3 -1 -3 -1 -3 -3 -1 -3  1  1  1 -3 -3  3
 25   -3 -3  1 -3  3  3  3 -1  3  1  1 -3 -3 -3  3 -3 -1 -1
 26   -3 -1 -1 -3  1 -3  3 -1 -1 -3  3  3 -3 -1  3 -1 -1 -1
 27   -3 -3  3  3 -3  1  3 -1 -3  1 -1 -3  3 -3 -1 -1 -1  3
 28   -1 -3  1 -3 -3 -3  1  1  3  3 -3  3  3 -3 -1  3 -3  1
 29   -3  3  1 -1 -1 -1 -1  1 -1  3  3 -3 -1  1  3 -1  3 -1

Table 5.2.2.2-4: Definition of φ(n) for M_ZC = 24

  u    φ(0),...,φ(23)
  0  -1 -3  3 -1  3  1  3 -1  1 -3 -1 -3 -1  1  3 -3 -1 -3  3  3  3 -3 -3 -3
  1  -1 -3  3  1  1 -3  1 -3 -3  1 -3 -1 -1  3 -3  3  3  3 -3  1  3  3 -3 -3
  2  -1 -3 -3  1 -1 -1 -3  1  3 -1 -3 -1 -1 -3  1  1  3  1 -3 -1 -1  3 -3 -3
  3   1 -3  3 -1 -3 -1  3  3  1 -1  1  1  3 -3 -1 -3 -3 -3 -1  3 -3 -1 -3 -3
  4  -1  3 -3 -3 -1  3 -1 -1  1  3  1  3 -1 -1 -3  1  3  1 -1 -3  1 -1 -3 -3
  5  -3 -1  1 -3 -3  1  1 -3  3 -1 -1 -3  1  3  1 -1 -3 -1 -3  1 -3 -3 -3 -3
  6  -3  3  1  3 -1  1 -3  1 -3  1 -1 -3 -1 -3 -3 -3 -3 -1 -1 -1  1  1 -3 -3
  7  -3  1  3 -1  1 -1  3 -3  3 -1 -3 -1 -3  3 -1 -1 -1 -3 -1 -1 -3  3  3 -3
  8  -3  1 -3  3 -1 -1 -1 -3  3  1 -1 -3 -1  1  3 -1  1 -1  1 -3 -3 -3 -3 -3
  9   1  1 -1 -3 -1  1  1 -3  1 -1  1 -3  3 -3 -3  3 -1 -3  1  3 -3  1 -3 -3
 10  -3 -3 -3 -1  3 -3  3  1  3  1 -3 -1 -1 -3  1  1  3  1 -1 -3  3  1  3 -3
 11  -3  3 -1  3  1 -1 -1 -1  3  3  1  1  1  3  3  1 -3 -3 -1  1 -3  1  3 -3
 12   3 -3  3 -1 -3  1  3  1 -1 -1 -3 -1  3 -3  3 -1 -1  3  3 -3 -3  3 -3 -3
 13  -3  3 -1  3 -1  3  3  1  1 -3  1  3 -3  3 -3 -3 -1  1  3 -3 -1 -1 -3 -3
 14  -3  1 -3 -1 -1  3  1  3 -3  1 -1  3  3 -1 -3  3 -3 -1 -1 -3 -3 -3  3 -3
 15  -3 -1 -1 -3  1 -3 -3 -1 -1  3 -1  1 -1  3  1 -3 -1  3  1  1 -1 -1 -3 -3
 16  -3 -3  1 -1  3  3 -3 -1  1 -1 -1  1  1 -1 -1  3 -3  1 -3  1 -1 -1 -1 -3
 17   3 -1  3 -1  1 -3  1  1 -3 -3  3 -3 -1 -1 -1 -1 -1 -3 -3 -1  1  1 -3 -3
 18  -3  1 -3  1 -3 -3  1 -3  1 -3 -3 -3 -3 -3  1 -3 -3  1  1 -3  1  1 -3 -3
 19  -3 -3  3  3  1 -1 -1 -1  1 -3 -1  1 -1  3 -3 -1 -3 -1 -1  1 -3  3 -1 -3
 20  -3 -3 -1 -1 -1 -3  1 -1 -3 -1  3 -3  1 -3  3 -3  3  3  1 -1 -1  1 -3 -3
 21   3 -1  1 -1  3 -3  1  1  3 -1 -3  3  1 -3  3 -1 -1 -1 -1  1 -3 -3 -3 -3
 22  -3  1 -3  3 -3  1 -3  3  1 -1 -3 -1 -3 -3 -3 -3  1  3 -1  1  3  3  3 -3
 23  -3 -1  1 -3 -1 -1  1  1  1  3  3 -1  1 -1  1 -1 -1 -3 -3 -3  3  1 -1 -3
 24  -3  3 -1 -3 -1 -1 -1  3 -1 -1  3 -3 -1  3 -3  3 -3 -1  3  1  1 -1 -3 -3
 25  -3  1 -1 -3 -3 -1  1 -3 -1 -3  1  1 -1  1  1  3  3  3 -1  1 -1  1 -1 -3
 26  -1  3 -1 -1  3  3 -1 -1 -1  3 -1 -3  1  3  1  1 -3 -3 -3 -1 -3 -1 -3 -3
 27   3 -3 -3 -1  3  3 -3 -1  3  1  1  1  3 -1  3 -3 -1  3 -1  3  1 -1 -3 -3
 28  -3  1 -3  1 -3  1  1  3  1 -3 -3 -1  1  3 -1 -3  3  1 -1 -3 -3 -3 -3 -3
 29   3 -3 -1  1  3 -1 -1 -3 -1  3 -1 -3 -1 -3  3 -1  3  1  1 -3  3 -3 -3 -3
```

### 5.2.3 Low-PAPR sequence generation type 2 (stub — not used by sidelink)

Defines `r_u,v^(α,δ)(n) = r̄_u,v(n)` as a DFT-precoded base sequence (π/2-BPSK-modulated Gold
sequence for `M ≥ 30`, or a fixed phase/bit table for `M ∈ {6,12,18,24}`), as an alternative to
the type-1 (Zadoff-Chu-family) generator of §5.2.2.

**Not extracted in full.** Every sidelink and PUCCH-format-0/1/3/4 reference to a low-PAPR
sequence in this project's dependency chain (file 09 §8.3.4.2.1 PSFCH → file 12 §6.3.2.2 → this
file's §5.2.2) explicitly cites **type 1** (`clause 5.2.2`), never type 2. Type 2 is used
elsewhere in the spec (e.g. certain PUCCH/SRS configurations outside this project's scope) but
nothing in TS 38.211 clause 8 or TS 38.213 clause 16 (sidelink PSFCH resource configuration)
routes through it. See PDF pages 22–26 for the full text and Tables 5.2.3.2-1 to -4 if ever
needed.

### 5.3 OFDM baseband signal generation

#### 5.3.1 OFDM baseband signal generation for all channels except PRACH and RIM-RS

The time-continuous signal `s_l^(p,µ)(t)` on antenna port `p` and subcarrier spacing
configuration `µ` for OFDM symbol `l = 0,1,…,N_symb^subframe,slot − 1` in a subframe, for any
physical channel or signal except PRACH, is defined by

```
s_l^(p,µ)(t) = { s̄_l^(p,µ)(t)   for t_start,l^µ ≤ t < t_start,l^µ + T_symb,l^µ
               { 0               otherwise

s̄_l^(p,µ)(t) = Σ_{k=0}^{N_grid,x^size,µ·N_sc^RB − 1}  a_{k,l}^(p,µ) ·
                e^(j2π(k + k0^µ − N_grid,x^size,µ·N_sc^RB/2)·Δf·(t − N_CP,l^µ·T_c − t_start,l^µ))

k0^µ = (N_grid,x^start,µ + N_grid,x^size,µ/2)·N_sc^RB
       − (N_grid,x0^start,µ0 + N_grid,x0^size,µ0/2)·N_sc^RB·2^(µ0−µ)

T_symb,l^µ = (N_u^µ + N_CP,l^µ)·T_c
```

where `t=0` at the start of the subframe, and

```
N_u^µ    = 2048·κ·2^(−µ)
N_CP,l^µ = { 512·κ·2^(−µ)                  extended cyclic prefix
           { 144·κ·2^(−µ) + 16·κ           normal cyclic prefix, l=0 or l=7·2^µ
           { 144·κ·2^(−µ)                  normal cyclic prefix, l≠0 and l≠7·2^µ
```

and `Δf` is given by clause 4.2, `µ` is the subcarrier spacing configuration, and `µ0` is the
largest `µ` value among the subcarrier spacing configurations given by `scs-SpecificCarrierList`
for each of uplink/downlink and by `sl-SCS-SpecificCarrierList` for sidelink.

> This is the generic OFDM-symbol time-domain waveform formula behind every physical channel and
> signal in this document, including sidelink's; nothing in file 09 restates it (sidelink §8 only
> ever operates on the resource-element grid `a_{k,l}^(p,µ)`, never the continuous-time waveform).
> Relevant context for `slResourceGrid`/OFDM-modulation work if and when it is built, but not
> currently exercised by anything in `+phy`.

**Not extracted here:** the cyclic-prefix-extension addendum to this subclause (for dynamically
scheduled or configured-grant PUSCH/SRS/PUCCH under shared-spectrum channel access, Tables
5.3.1-1 and 5.3.1-2) is a Uu-only, NR-U-only mechanism with no sidelink applicability and is
omitted; see PDF page 27 if ever needed.

#### 5.3.2 OFDM baseband signal generation for PRACH (stub — not used by sidelink)

Defines the PRACH-specific continuous-time signal (preamble sequence `L_RA`, subcarrier spacing
`Δf_RA`, timing offset `t_start^RA`, cyclic prefix `N_CP,l^RA`) for the four PRACH preamble
formats (long `{839}` and short `{139,571,1151}`). Sidelink has no PRACH-equivalent physical
channel — PSFCH is the closest analog and is fully specified in file 09 §8.3.4.2, independent of
this subclause. **Not extracted in full;** see PDF pages 27–30 if ever needed.

#### 5.3.3 OFDM baseband signal generation for RIM-RS (stub — not used by sidelink)

Defines the Remote Interference Management reference signal's continuous-time waveform — a gNB-
to-gNB inter-cell interference measurement mechanism with no UE-side or sidelink role at all.
**Not extracted in full;** see PDF page 30 if ever needed (very unlikely for this project).

### 5.4 Modulation and upconversion

Modulation and upconversion to the carrier frequency `f0` of the complex-valued OFDM baseband
signal for antenna port `p`, subcarrier spacing configuration `µ`, and OFDM symbol `l` in a
subframe assumed to start at `t=0`, is given by:

- for PRACH: `Re{ s_l^(p,µ)(t) · e^(j2πf0t) }`
- for RIM-RS: `Re{ s_l^(p,µ)(t) · e^(j2πf0^RIM·(t − t_start,l0^µ − N_CP^RIM·T_c)) }`, where
  `f0^RIM` is the configured reference point for RIM-RS
- for all other channels and signals:
  `Re{ s_l^(p,µ)(t) · e^(j2πf0·(t − t_start,l^µ − N_CP,l^µ·T_c)) }`

> The third bullet is the one relevant to every sidelink channel/signal in file 09.

---

## Gaps in this extraction

### What was fully extracted vs. stubbed, and why

Per the task's stated priority ordering, clause 5 is lower priority than clauses 6–7 because the
modulation mapper and Gold-sequence generator are already implemented and independently verified
(`+phy/+lib/ch5-toolbox-survey.md`). Effort was allocated accordingly:

- **Fully extracted:** §5.1 (all six modulation schemes), §5.2.1 (Gold sequence generator),
  §5.2.2 and §5.2.2.1/§5.2.2.2 (low-PAPR type 1, including the `M_ZC=12` table needed by PSFCH),
  §5.3.1 (core OFDM baseband formula), §5.4 (modulation/upconversion).
- **Stubbed** (heading + summary only, not transcribed): §5.2.3 (low-PAPR type 2 — confirmed
  unused by any sidelink or PSFCH-adjacent clause via direct citation-chain tracing, not merely
  assumed), §5.3.2 (PRACH baseband — no sidelink PRACH-equivalent exists), §5.3.3 (RIM-RS
  baseband — gNB-only mechanism, zero UE/sidelink relevance), and the §5.3.1 cyclic-prefix-
  extension addendum (Uu/NR-U-only).

This mirrors the "extract for completeness but don't spend disproportionate effort" instruction
for this clause: everything actually load-bearing for `slPSFCH.m` or already-implemented modules
is extracted verbatim and cross-checked; content with no sidelink citation path is stubbed with an
explicit pointer to the PDF page range, not silently dropped.

### `2^n`-collapse bug: checked, one place worth flagging

File 09 documented `pdftotext -layout` collapsing superscripted exponents (`2^15` → `215`, etc.)
onto the baseline. This clause's formulas were checked against that bug:

- §5.2.1's `c_init = Σ x2(i)·2^i` and the Gold-sequence recursions extracted cleanly as ordinary
  additive offsets (`n+31`, `n+3`, etc.), not mis-collapsed exponents — confirmed by the fact that
  no bare 2- or 3-digit run appears where an exponent would be expected.
- §5.3.1's `N_u^µ = 2048·κ·2^(−µ)` and `N_CP,l^µ` formulas use `2^(−µ)` (negative exponent) — the
  raw `pdftotext -layout` output rendered this correctly as `2^−µ` in context (verified against
  the source page), not collapsed, likely because the exponent here is a variable (`−µ`) rather
  than a fixed digit run like `15` or `31`; file 09's bug specifically affects fixed numeric
  exponents typeset as superscript digit glyphs, which `−µ` is not.
- No corrupted exponent was found anywhere in clause 5 as extracted.

### Tables 5.2.2.2-1, -3, -4 presented as fixed-width blocks, not reflowed Markdown tables

Table 5.2.2.2-2 (`M_ZC=12`, needed for PSFCH) was reconstructed as a full Markdown table with
each cell individually verified. Tables 5.2.2.2-1, -3, -4 (`M_ZC=6,18,24`) are not consumed by
any code in this project — PSFCH is always exactly 1 resource block (`N_sc^RB=12` subcarriers),
so `M_ZC` is always 12. These three tables are included as fixed-width preformatted blocks
(copied directly from the already well-aligned `pdftotext -layout` output, which rendered them
correctly with one row per line and consistent column spacing) rather than manually retyped into
pipe-delimited Markdown tables, to avoid introducing transcription errors in 90 rows of φ(n) data
this project does not use. If any of these three tables is ever needed for exact values, treat the
fixed-width block as a first-pass extraction and cross-check against a rendered PDF page image
before using it normatively, following the same standard file 09 applied to every table it
reconstructed.
