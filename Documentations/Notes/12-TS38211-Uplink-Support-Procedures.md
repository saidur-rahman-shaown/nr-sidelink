# TS 38.211 §6 — Uplink (Support Procedures Referenced by Sidelink)

> **Source:** 3GPP TS 38.211 V16.10.0 (2022-06), Release 16 — *NR; Physical channels and modulation*
> **Scope:** clause 6 ("Uplink") is ~59 pages (PDF pages 31–89) covering PUSCH, all five PUCCH
> formats, PRACH, and SRS in full generality. This file extracts **only the subclauses TS 38.211
> §8 (sidelink, file 09) actually cites**, plus enough surrounding structure (headings, short
> overview paragraphs, format tables) to keep the clause navigable. Everything else is a
> heading-plus-one-paragraph **stub** with an explicit "not extracted" note and a PDF page
> pointer — see "Gaps in this extraction" for the full list and rationale.
> **Status:** the extracted subclauses are verbatim spec text, reformatted; stubs are this
> project's own summary, clearly marked as such, never presented as spec text.
> **Priority context:** this file resolves the two **highest-priority** items blocking this
> project — §6.3.1.5 (precoding, needed to finish `+phy/+ts38211/slPSSCH.m`) — and the
> **second-priority** item §6.3.2.2/§6.4.1.1.3 (PSFCH cyclic shift and PSSCH DM-RS RE-mapping
> template, needed for `slPSFCH.m` and PSSCH DM-RS mapping respectively).

## Contents

- [6 Uplink](#6-uplink)
  - [6.1 Overview](#61-overview)
  - [6.2 Physical resources](#62-physical-resources)
  - [6.3 Physical channels](#63-physical-channels)
    - [6.3.1 Physical uplink shared channel](#631-physical-uplink-shared-channel)
      - [6.3.1.1 Scrambling (stub)](#6311-scrambling-stub)
      - [6.3.1.2 Modulation (stub)](#6312-modulation-stub)
      - [6.3.1.3 Layer mapping](#6313-layer-mapping)
      - [6.3.1.4 Transform precoding (stub)](#6314-transform-precoding-stub)
      - [6.3.1.5 Precoding — full](#6315-precoding--full)
      - [6.3.1.6 and 6.3.1.7 — VRB/PRB mapping (stub)](#6316-and-6317--vrbprb-mapping-stub)
    - [6.3.2 Physical uplink control channel](#632-physical-uplink-control-channel)
      - [6.3.2.1 General](#6321-general)
      - [6.3.2.2 Sequence and cyclic shift hopping — full](#6322-sequence-and-cyclic-shift-hopping--full)
        - [6.3.2.2.1 Group and sequence hopping](#63221-group-and-sequence-hopping)
        - [6.3.2.2.2 Cyclic shift hopping](#63222-cyclic-shift-hopping)
      - [6.3.2.3 PUCCH format 0](#6323-pucch-format-0)
      - [6.3.2.4–6.3.2.6 PUCCH formats 1, 2, 3, 4 (stub)](#6324–6326-pucch-formats-1-2-3-4-stub)
    - [6.3.3 Physical random-access channel (stub)](#633-physical-random-access-channel-stub)
  - [6.4 Physical signals](#64-physical-signals)
    - [6.4.1 Reference signals](#641-reference-signals)
      - [6.4.1.1 Demodulation reference signal for PUSCH](#6411-demodulation-reference-signal-for-pusch)
        - [6.4.1.1.1 Sequence generation (stub)](#64111-sequence-generation-stub)
        - [6.4.1.1.2 (void)](#64112-void)
        - [6.4.1.1.3 Precoding and mapping to physical resources — full](#64113-precoding-and-mapping-to-physical-resources--full)
      - [6.4.1.2 Phase-tracking reference signals for PUSCH (stub)](#6412-phase-tracking-reference-signals-for-pusch-stub)
      - [6.4.1.3 Demodulation reference signal for PUCCH (stub)](#6413-demodulation-reference-signal-for-pucch-stub)
      - [6.4.1.4 Sounding reference signal (stub)](#6414-sounding-reference-signal-stub)
- [Gaps in this extraction](#gaps-in-this-extraction)

---

## 6 Uplink

### 6.1 Overview

An uplink physical channel corresponds to a set of resource elements carrying information
originating from higher layers. The following uplink physical channels are defined: **Physical
Uplink Shared Channel (PUSCH)**, **Physical Uplink Control Channel (PUCCH)**, **Physical Random
Access Channel (PRACH)**.

An uplink physical signal is used by the physical layer but does not carry information
originating from higher layers. The following uplink physical signals are defined:
**Demodulation reference signals (DM-RS)**, **Phase-tracking reference signals (PT-RS)**,
**Sounding reference signal (SRS)**.

### 6.2 Physical resources

The frame structure and physical resources the UE shall use when transmitting in the uplink are
defined in clause 4 (file 10).

The following antenna ports are defined for the uplink:

- Antenna ports starting with 0 for DM-RS for PUSCH
- Antenna ports starting with 1000 for SRS, PUSCH
- Antenna ports starting with 2000 for PUCCH
- Antenna port 4000 for PRACH

*(Compare sidelink's own antenna-port ranges in file 09 §8.2.4: 1000/2000/3000/4000/5000 for
PSSCH/PSCCH/CSI-RS/S-SS-PSBCH/PSFCH — a completely disjoint numbering scheme from the Uu uplink
ranges above; there is no port-number collision to reason about between the two.)*

The remaining paragraphs of §6.2 define when a UE may infer channel large-scale properties across
symbols on the same uplink antenna port (PUSCH repetition Type B same-repetition case; no
intra-slot frequency hopping same-slot case; intra-slot frequency hopping same-hop case) — Uu
scheduling detail with no sidelink counterpart, not reproduced here.

### 6.3 Physical channels

#### 6.3.1 Physical uplink shared channel

##### 6.3.1.1 Scrambling (stub)

PUSCH scrambling follows the same `b̃(i) = (b(i) + c(i)) mod 2` pattern as every other channel in
this document (Gold sequence from clause 5.2.1, file 11), with a `c_init` built from `n_RNTI`,
`n_ID`, and — uniquely to PUSCH — special handling of UCI placeholder bits `x`/`y` (repeat-last-
bit and force-to-1 rules) that has no PSSCH/PSCCH/PSBCH analog. **Not extracted in full** — this
placeholder-bit mechanism is PUSCH-UCI-multiplexing-specific and not referenced by any sidelink
clause; see PDF page 32 if ever needed.

##### 6.3.1.2 Modulation (stub)

Standard clause-5.1 modulation mapping using Table 6.3.1.2-1 (QPSK/16QAM/64QAM/256QAM without
transform precoding; π/2-BPSK/QPSK/16QAM/64QAM/256QAM with transform precoding enabled). Same
scheme set as sidelink Table 8.3.1.2-1 (file 09) minus the "transform precoding enabled" column,
which sidelink never uses (PSSCH is CP-OFDM only, no DFT-s-OFDM option). **Not extracted in full.**

##### 6.3.1.3 Layer mapping

> For the single codeword `q=0`, the complex-valued modulation symbols for the codeword to be
> transmitted shall be mapped onto up to four layers according to **Table 7.3.1.3-1**.
> Complex-valued modulation symbols `d^(q)(0),…,d^(q)(M_symb^(q)−1)` for codeword `q` shall be
> mapped onto the layers `x(i) = [x^(0)(i) … x^(ν−1)(i)]^T`, `i = 0,1,…,M_symb^layer−1`, where `ν`
> is the number of layers and `M_symb^layer` is the number of modulation symbols per layer.

**PUSCH layer mapping is literally the same generic table as PDSCH layer mapping** — this
subclause does not define its own formula, it points straight at Table 7.3.1.3-1, which is
reproduced in full in file 13 §7.3.1.3 (the top-priority item for this project's layer-mapping
work: sidelink §8.3.1.3, file 09, in turn points at clause 7.3.1.3 directly, bypassing this
subclause entirely — see file 13 for the actual table and the layer-mapping answer).

##### 6.3.1.4 Transform precoding (stub)

If transform precoding is *not* enabled (the only case PSSCH is analogous to — sidelink is
CP-OFDM only), `y^(λ)(i) = x^(λ)(i)` for each layer `λ` — i.e. a pure pass-through, no operation.
If transform precoding *is* enabled (DFT-s-OFDM, `ν=1` only), a DFT precoding formula applies
sample blocks of size `M_sc^PUSCH` per OFDM symbol. **Not extracted in full** — PSSCH has no
transform-precoding option at all (clause 8.3.1 has no "transform precoding" subclause), so the
enabled-case DFT formula is entirely inapplicable; the disabled-case pass-through is stated above
in full since it is one line. See PDF pages 33–34 for the DFT formula if ever needed elsewhere.

##### 6.3.1.5 Precoding — full

> The block of vectors `[y^(0)(i) … y^(ν−1)(i)]^T`, `i = 0,1,…,M_symb^layer−1`, shall be precoded
> according to
>
> ```
> [z^(p0)(i)]       [y^(0)(i)  ]
> [   ⋮     ]  =  W [   ⋮      ]
> [z^(pρ-1)(i)]     [y^(ν-1)(i)]
> ```
>
> where `i = 0,1,…,M_symb^ap−1`, `M_symb^ap = M_symb^layer`. The set of antenna ports
> `{p0,…,pρ−1}` shall be determined according to the procedure in [6, TS 38.214].
>
> **For non-codebook-based transmission, the precoding matrix `W` equals the identity matrix.**
>
> For codebook-based transmission, the precoding matrix `W` is given by `W=1` for single-layer
> transmission on a single antenna port, otherwise by Tables 6.3.1.5-1 to 6.3.1.5-7 with the TPMI
> index obtained from the DCI scheduling the uplink transmission or the higher-layer parameters
> according to the procedure in [6, TS 38.214].
>
> When the higher-layer parameter `txConfig` is not configured, the precoding matrix `W = 1`.

**This is the entire normative content of PUSCH precoding**, and it is the clause sidelink
§8.3.1.4 (file 09) points to: *"the block of vectors `[x^(0)(i) … x^(ν−1)(i)]^T` shall be
precoded according to clause 6.3.1.5 where the precoding matrix `W` equals the identity matrix
and `M_symb^ap = M_symb^layer`."* Sidelink hard-codes the **non-codebook-based** branch — `W = I`
— unconditionally; the codebook-based branch (Tables 6.3.1.5-1 to -7, TPMI selection) never
applies to PSSCH at all. With `W` the identity matrix, the block equation above collapses to
`z^(pi)(i) = y^(i)(i)` for `i = 0,…,ν−1` — **each layer's sample stream is copied straight to its
own antenna port, with no linear combination across layers.** This confirms this project's
existing assumption exactly: for PSSCH, "precoding" is a pure identity pass-through.

**Tables 6.3.1.5-1 to 6.3.1.5-7 (codebook-based TPMI precoding matrices) are not extracted.**
These seven tables define the single-layer/2-antenna-port, single-layer/4-antenna-port (transform
precoding enabled and disabled), two-/three-/four-layer/4-antenna-port precoding matrices selected
by TPMI index for codebook-based PUSCH — a UE-capability-gated Uu feature. Since sidelink always
takes the non-codebook-based (`W=I`) branch per clause 8.3.1.4, none of these seven tables is ever
consulted by any sidelink code path. See PDF pages 34–37 if a future non-sidelink use ever needs
them.

##### 6.3.1.6 and 6.3.1.7 — VRB/PRB mapping (stub)

§6.3.1.6 maps precoded symbols to virtual resource blocks (amplitude-scaled, in increasing `k′`
then `l` order, skipping DM-RS/PT-RS/other-UE-DM-RS REs). §6.3.1.7 maps virtual to physical
resource blocks, non-interleaved (`n → n`) except for two RAR/TC-RNTI edge cases. **Not extracted
in full** — sidelink has its own, simpler VRB/PRB mapping in file 09 §8.3.1.5/§8.3.1.6 (no
interleaved option, no RAR/TC-RNTI special case), which fully supersedes this for PSSCH purposes.

#### 6.3.2 Physical uplink control channel

##### 6.3.2.1 General

The physical uplink control channel supports multiple formats as shown in Table 6.3.2.1-1. In
case intra-slot frequency hopping is configured for PUCCH formats 1, 3, or 4 (clause 9.2.1 of
[5, TS 38.213]), the number of symbols in the first hop is given by `floor(N_symb^PUCCH / 2)`
where `N_symb^PUCCH` is the length of the PUCCH transmission in OFDM symbols.

**Table 6.3.2.1-1: PUCCH formats**

| PUCCH format | Length in OFDM symbols (N_symb^PUCCH) | Number of bits |
|---|---|---|
| 0 | 1–2 | ≤2 |
| 1 | 4–14 | ≤2 |
| 2 | 1–2 | >2 |
| 3 | 4–14 | >2 |
| 4 | 4–14 | >2 |

> **PSFCH format 0 (file 09 §8.3.4.2) is the sidelink analog of PUCCH format 0** — same "≤2 bits,
> 1–2 symbols" shape, same low-PAPR-sequence-plus-cyclic-shift construction. PUCCH formats 1–4 are
> not used by anything in this project (see §6.3.2.4–6.3.2.6 stub below).

##### 6.3.2.2 Sequence and cyclic shift hopping — full

> PUCCH formats 0, 1, 3, and 4 use sequences `r_u,v^(α,δ)(n)` given by clause 5.2.2 (file 11)
> with `δ=0`, where the sequence group `u` and sequence number `v` depend on the sequence hopping
> in clause 6.3.2.2.1, and the cyclic shift `α` depends on the cyclic shift hopping in clause
> 6.3.2.2.2.

**This is the clause sidelink §8.3.4.2.1 (file 09, PSFCH) points to for `r_u,v^(α,δ)(n)`**, with
PSFCH-specific overrides for `m_cs`, `m_0`, `l`, `l′`, `u`, `v`, and `c_init` (repeated below in
context). The base-sequence formula itself lives in clause 5.2.2 (file 11); this subclause
supplies the `u`, `v`, and `α` parameters that feed it.

###### 6.3.2.2.1 Group and sequence hopping

The sequence group `u = (f_gh + f_ss) mod 30`, and the sequence number `v` within the group,
depend on the higher-layer parameter `pucch-GroupHopping`:

- **`'neither'`:** `f_gh = 0`; `f_ss = n_ID mod 30`; `v = 0` — where `n_ID` is given by
  `hoppingId` if configured, otherwise `n_ID = N_ID^cell`.
- **`'enable'`:** `f_gh = (Σ_{m=0}^{7} 2^m·c(8·n_s,f^μ + m)) mod 30`; `f_ss = n_ID mod 30`;
  `v = 0` — where `c(i)` is the clause 5.2.1 Gold sequence, initialized at the start of each radio
  frame with `c_init = floor(n_ID / 30)`.
- **`'disable'`:** `f_gh = 0`; `f_ss = n_ID mod 30`; `v = c(2·n_s,f^μ + n_hop)` — where `c(i)` is
  the clause 5.2.1 Gold sequence, initialized at the start of each radio frame with
  `c_init = 25·floor(n_ID/30) + (n_ID mod 30)`.

In all three cases `n_ID` is given by the higher-layer parameter `hoppingId` if configured,
otherwise `n_ID = N_ID^cell`.

The frequency hopping index `n_hop = 0` if intra-slot frequency hopping is disabled by
`intraSlotFrequencyHopping`; otherwise `n_hop = 0` for the first hop and `n_hop = 1` for the
second hop.

> **PSFCH does not use this subclause at all.** File 09 §8.3.4.2.1's PSFCH exceptions assign `u`
> and `v` **directly** (`u = n_ID mod 30` with `n_ID = sl-PSFCH-HopID` if configured else `u=0`;
> `v=0` always), bypassing the `pucch-GroupHopping`/`f_gh`/`f_ss` machinery above entirely.
> Included here only so the full picture of what clause 6.3.2.2 normally does is visible.

###### 6.3.2.2.2 Cyclic shift hopping

> The cyclic shift `α` varies as a function of the symbol and slot number according to
>
> ```
> α_l = (2π / N_sc^RB) · ((m0 + m_cs + m_int + n_cs(n_s,f^μ, l+l′)) mod N_sc^RB)
> ```
>
> where:
>
> - `n_s,f^μ` is the slot number in the radio frame
> - `l` is the OFDM symbol number in the PUCCH transmission, `l=0` = first symbol of the PUCCH
>   transmission
> - `l′` is the index of the OFDM symbol in the slot that corresponds to the first OFDM symbol of
>   the PUCCH transmission in the slot, given by [5, TS 38.213]
> - `m0` is given by [5, TS 38.213] for PUCCH formats 0 and 1, and by clause 6.4.1.3.3.1 for
>   formats 3 and 4
> - `m_cs = 0` except for PUCCH format 0, where it depends on the information to be transmitted
>   per clause 9.2 of [5, TS 38.213]
> - `m_int = 5·n_IRB^μ` for PUCCH formats 0 and 1 **if** interlaced mapping is enabled by the
>   higher-layer parameters `useInterlacePUCCH-PUSCH` in `BWP-UplinkCommon`/`BWP-UplinkDedicated`
>   (`n_IRB^μ` is the interlace resource-block number); **otherwise `m_int = 0`**.
> - the function `n_cs(n_s,f^μ, l)` is given by
>   `n_cs(n_s,f^μ, l) = Σ_{m=0}^{7} 2^m·c(8·N_symb^slot·n_s,f^μ + 8l + m)`, where `c(i)` is the
>   clause 5.2.1 (file 11) Gold sequence, initialized with `c_init = n_ID` at the beginning of
>   each radio frame, `n_ID` given by `hoppingId` if configured, otherwise `n_ID = N_ID^cell`.

**This is the formula this project needs for PSFCH's `α` in `slPSFCH.m`.** Clause 8.3.4.2.1 (file
09) gives these overrides for PSFCH, applied on top of the generic formula above:

| Symbol in the α formula | PSFCH value (per file 09 §8.3.4.2.1) |
|---|---|
| `N_sc^RB` | 12 (one resource block, clause 4.4.4.1, file 10) |
| `m_cs` | given by clause 16.3 of TS 38.213 |
| `m0` | given by clause 16.3 of TS 38.213 |
| `l` | **0** (fixed) |
| `l′` | index of the OFDM symbol in the slot corresponding to the **second** OFDM symbol of the
  PSFCH transmission (per TS 38.213), so `l+l′` in the formula reduces to just `l′` |
| `u`, `v` for `r_u,v^(α,δ)` | `u = n_ID mod 30`, `v = 0`, with `n_ID = sl-PSFCH-HopID` if
  configured, otherwise `u = 0` (bypasses §6.3.2.2.1 entirely — see note above) |
| `c_init` (for the `n_cs` pseudo-random generator) | `n_ID` with `n_ID = sl-PSFCH-HopID` if
  configured, otherwise `c_init = 0` — this overrides the generic `c_init = n_ID` (`hoppingId`/
  `N_ID^cell`) rule inside the `n_cs(·)` definition above, since `hoppingId`/`N_ID^cell` are Uu
  cell-configuration concepts sidelink does not have |
| `m_int` | **not listed as an override** — but its own generic definition only triggers under
  `useInterlacePUCCH-PUSCH`, a `BWP-UplinkCommon`/`BWP-UplinkDedicated` IE with no sidelink
  `SL-BWP-*` equivalent (file 04's SL IE catalogue has no interlacing parameter); by the formula's
  own "otherwise `m_int=0`" branch, `m_int = 0` for PSFCH. *(This is this project's inference from
  the absence of the triggering IE, not an explicit spec statement for PSFCH — flagged here rather
  than asserted as directly spec-stated; see "Gaps in this extraction".)*

So, fully assembled for PSFCH:

```
α = (2π/12) · ((m0 + m_cs + n_cs(n_s,f^μ, l′)) mod 12)

n_cs(n_s,f^μ, l′) = Σ_{m=0}^{7} 2^m · c(8·N_symb^slot·n_s,f^μ + 8·l′ + m)

c(i): clause 5.2.1 Gold sequence, c_init = sl-PSFCH-HopID (or 0 if not configured),
      re-initialized at the start of each radio frame
```

with `m0`, `m_cs` both taken from TS 38.213 §16.3 (not in this repo's extracted notes — see
`00-INDEX.md` gap list for TS 38.213, which **is** fully extracted in file 05 for clause 16, so
double-check whether §16.3's `m0`/`m_cs` values are already covered there before treating this as
a residual gap).

##### 6.3.2.3 PUCCH format 0

> The sequence `x(n)` shall be generated according to
>
> ```
> x(l·N_sc^RB + n) = r_u,v^(α,δ)(n),     n = 0,1,…,N_sc^RB−1
>                                        l = 0 for single-symbol PUCCH transmission
>                                        l = 0,1 for double-symbol PUCCH transmission
> ```
>
> where `r_u,v^(α,δ)(n)` is given by clause 6.3.2.2 with `m_cs` depending on the information to be
> transmitted according to clause 9.2 of [5, TS 38.213].
>
> Mapping to physical resources: `x(n)` multiplied by amplitude scaling factor `β_PUCCH,0`, mapped
> in sequence starting with `x(0)` to resource elements `(k,l)_p,μ` assigned per clause 9.2.1 of
> [5, TS 38.213], increasing `k` then `l`, antenna port `p=2000`. For interlaced transmission the
> mapping repeats per resource block in the interlace.

**This is the direct structural analog of PSFCH format 0** (file 09 §8.3.4.2.1/§8.3.4.2.2): same
`x(n) = r_u,v^(α,δ)(n)`, `n=0,…,N_sc^RB−1` sequence-generation shape, same "multiply by amplitude
scaling factor, map in increasing `k` order on a dedicated antenna port" mapping shape. Confirms
PSFCH format 0 is modelled directly on PUCCH format 0 with sidelink-specific parameter overrides,
not an independently-invented format.

##### 6.3.2.4–6.3.2.6 PUCCH formats 1, 2, 3, 4 (stub)

Format 1 (§6.3.2.4): BPSK/QPSK-modulated single symbol, block-wise spread with an orthogonal
sequence `w_i(m)` (Table 6.3.2.4.1-2, DFT-like spreading codes up to length 7), for ≤2-bit
payloads over 4–14 symbols. Format 2 (§6.3.2.5): scrambled + QPSK-modulated + spread, for >2-bit
payloads over 1–2 symbols. Formats 3/4 (§6.3.2.6): scrambled + modulated + block/DFT-spread, >2-bit
payloads over 4–14 symbols, format 4 adds pre-DFT block-wise spreading for multiplexing.

**Not extracted in full.** None of these three formats has a sidelink physical-channel analog —
PSFCH is a single fixed format (format-0-derived) with no equivalent of PUCCH's longer/
higher-payload formats. See PDF pages 40–44 if ever needed (e.g. for a future non-sidelink
feature).

#### 6.3.3 Physical random-access channel (stub)

Defines PRACH preamble sequence generation (§6.3.3.1 — Zadoff-Chu root sequence tables spanning
PDF pages 44–51, four preamble length families `L_RA ∈ {839, 139, 571, 1151}`, dozens of
root-sequence and cyclic-shift restriction-set tables) and PRACH resource mapping (§6.3.3.2 — PDF
pages 51–71, preamble format tables for every combination of format, subcarrier spacing, and
number of PRACH slots).

**Not extracted.** This is by far the largest subclause in clause 6 (~27 PDF pages, the majority
of clause 6's page count) and has **zero relevance to NR sidelink** — PRACH is the Uu random-
access channel (UE-to-gNB initial access), with no PC5/sidelink equivalent of any kind; nothing
in TS 38.211 clause 8, TS 38.213 clause 16, or the SL RRC IEs (file 04) references PRACH. Fully
out of scope for this project; not transcribed even in stub-table form to avoid disproportionate
effort on content this project will never consume. See PDF pages 44–71 directly if ever needed
for an unrelated feature.

### 6.4 Physical signals

#### 6.4.1 Reference signals

##### 6.4.1.1 Demodulation reference signal for PUSCH

###### 6.4.1.1.1 Sequence generation (stub)

Two branches: transform-precoding-disabled (a QPSK-like Gold-sequence construction,
`r(n) = (1/√2)(1−2c(2n)) + j(1/√2)(1−2c(2n+1))`, structurally identical to every DM-RS sequence
in file 09 but with a PUSCH-specific `c_init` built from `n_SCID`, `N_ID^0`/`N_ID^1`, and CDM-
group-dependent `λ̄`/`n̄_SCID` logic) and transform-precoding-enabled (routes through clause 5.2.2
or 5.2.3 depending on configuration, `δ=1`). **Not extracted in full** — sidelink's own PSSCH
DM-RS sequence generation (file 09 §8.4.1.1.1) is self-contained and does not cite this subclause
at all (only the RE-*mapping* template in §6.4.1.1.3 below is shared). See PDF pages 71–73 if ever
needed.

###### 6.4.1.1.2 (void)

###### 6.4.1.1.3 Precoding and mapping to physical resources — full

> The sequence `r(m)` shall be mapped to the intermediate quantity `ã_{k,l}^(p̃_j,μ)` according
> to:
>
> **If transform precoding is not enabled** *(the case sidelink PSSCH DM-RS uses)*:
>
> ```
> ã_{k,l}^(p̃_j,μ) = w_f(k′) · w_t(l′) · r(2n + k′)
>
> k = { 4n + 2k′     Configuration type 1
>     { 6n + k′      Configuration type 2
>
> k′ = 0,1
> l  = l̄ + l′
> n  = 0,1,…
> j  = 0,1,…,ν−1
> ```
>
> If transform precoding *is* enabled, the formula is the same with `k = 4n+2k′` only
> (configuration type 1 is the only option in that case).
>
> `w_f(k′)`, `w_t(l′)`, and `Δ` are given by **Tables 6.4.1.1.3-1 and 6.4.1.1.3-2** below, and the
> configuration type is given by the higher-layer parameter `DMRS-UplinkConfig`; both `k′` and `Δ`
> correspond to `p̃0,…,p̃ν−1`. The intermediate quantity `ã_{k,l}^(p̃_j,μ) = 0` if `Δ` corresponds
> to any other antenna port than `p̃_j`.
>
> The intermediate quantity shall be precoded, multiplied by the amplitude scaling factor
> `β_DMRS^PUSCH`, and mapped to physical resources according to
>
> ```
> [a_{k,l}^(p0,μ)   ]                [ã_{k,l}^(p̃0,μ)  ]
> [    ⋮            ]  = β_DMRS^PUSCH·W· [    ⋮           ]
> [a_{k,l}^(pρ-1,μ) ]                [ã_{k,l}^(p̃ν-1,μ)]
> ```
>
> where the precoding matrix `W` and the antenna port set `{p0,…,pρ−1}` are given by clause
> 6.3.1.5 (above), and the antenna port set `{p̃0,…,p̃ν−1}` is given by [6, TS 38.214].

**This is the exact clause sidelink §8.4.1.1.2 (file 09, PSSCH DM-RS) points to**: *"The sequence
`r(m)` shall be mapped to the intermediate quantity `ã_{k,l}^(p̃_j,μ)` according to clause
6.4.1.1.3 using **configuration type 1 without transform precoding**, and where `w_f(k′)`,
`w_t(l′)`, and `Δ` are given by Table 8.4.1.1.2-2."* So for PSSCH DM-RS mapping, the applicable
branch is exactly the "transform precoding not enabled, configuration type 1" case above:

```
ã_{k,l}^(p̃_j,μ) = w_f(k′) · w_t(l′) · r(2n + k′)
k = 4n + 2k′
k′ ∈ {0,1}
l = l̄ + l′  (l̄ = DM-RS symbol position from Table 8.4.1.1.2-1, file 09)
n = 0,1,…
```

and `w_f(k′)`, `w_t(l′)` come from sidelink's own **Table 8.4.1.1.2-2** (file 09) — which is
exactly a 2-row subset of the generic Table 6.4.1.1.3-1 below, confirmed by cross-checking: rows
`p̃=0` (`w_f(0)=+1, w_f(1)=+1, w_t(0)=+1`) and `p̃=1` (`w_f(0)=+1, w_f(1)=−1, w_t(0)=+1`) of Table
6.4.1.1.3-1 match sidelink's `p=1000`/`p=1001` rows exactly (CDM group 0, Δ=0 in both).

**Table 6.4.1.1.3-1: Parameters for PUSCH DM-RS configuration type 1**

| p̃ | CDM group λ | Δ | w_f(0) | w_f(1) | w_t(0) | w_t(1) |
|---|---|---|---|---|---|---|
| 0 | 0 | 0 | +1 | +1 | +1 | +1 |
| 1 | 0 | 0 | +1 | −1 | +1 | +1 |
| 2 | 1 | 1 | +1 | +1 | +1 | +1 |
| 3 | 1 | 1 | +1 | −1 | +1 | +1 |
| 4 | 0 | 0 | +1 | +1 | +1 | −1 |
| 5 | 0 | 0 | +1 | −1 | +1 | −1 |
| 6 | 1 | 1 | +1 | +1 | +1 | −1 |
| 7 | 1 | 1 | +1 | −1 | +1 | −1 |

**Table 6.4.1.1.3-2: Parameters for PUSCH DM-RS configuration type 2** *(not used by sidelink —
file 09 confirms PSSCH DM-RS always uses configuration type 1 — included for completeness)*

| p̃ | CDM group λ | Δ | w_f(0) | w_f(1) | w_t(0) | w_t(1) |
|---|---|---|---|---|---|---|
| 0 | 0 | 0 | +1 | +1 | +1 | +1 |
| 1 | 0 | 0 | +1 | −1 | +1 | +1 |
| 2 | 1 | 2 | +1 | +1 | +1 | +1 |
| 3 | 1 | 2 | +1 | −1 | +1 | +1 |
| 4 | 2 | 4 | +1 | +1 | +1 | +1 |
| 5 | 2 | 4 | +1 | −1 | +1 | +1 |
| 6 | 0 | 0 | +1 | +1 | +1 | −1 |
| 7 | 0 | 0 | +1 | −1 | +1 | −1 |
| 8 | 1 | 2 | +1 | +1 | +1 | −1 |
| 9 | 1 | 2 | +1 | −1 | +1 | −1 |
| 10 | 2 | 4 | +1 | +1 | +1 | −1 |
| 11 | 2 | 4 | +1 | −1 | +1 | −1 |

**Not extracted:** Tables 6.4.1.1.3-3 to -6 (PUSCH DM-RS *time-domain position* tables for mapping
types A/B, single-/double-symbol DM-RS, with/without intra-slot frequency hopping — PDF pages
76–77) and Table 6.4.1.1.3-5 (`l′` / supported antenna ports by DM-RS duration). Sidelink does not
use any of these — file 09's own **Table 8.4.1.1.2-1** (PSSCH DM-RS time-domain location) is a
complete, independently-specified replacement keyed on `l_d` (scheduled PSSCH+PSCCH duration) and
DM-RS count from SCI, not on PUSCH's `dmrs-TypeA-Position`/`dmrs-AdditionalPosition`/mapping-type
scheme. Only the *frequency-domain* CDM-group/`w_f`/`w_t` tables (6.4.1.1.3-1/-2 above) are shared
between PUSCH and PSSCH DM-RS; the *time-domain* position logic is not.

#### 6.4.1.2 Phase-tracking reference signals for PUSCH (stub)

PT-RS sequence generation and RE mapping, keyed on `M_sc^PUSCH`, PT-RS group count, DM-RS port
association, and (if transform precoding enabled) a DFT-domain sample-selection scheme. **Not
extracted in full** — sidelink PSSCH PT-RS is fully specified independently in file 09
§8.4.1.2.1/§8.4.1.2.2, which cites clause 8.3.1.4 (precoding, this file) but does not cite this
PUSCH-specific subclause. See PDF pages 77–80 if ever needed.

#### 6.4.1.3 Demodulation reference signal for PUCCH (stub)

DM-RS sequence generation and mapping for PUCCH formats 1, 2, 3, and 4 specifically (format 0 has
no DM-RS of its own — it *is* the reference signal, per §6.3.2.3 above). **Not extracted** —
PSFCH format 0 (file 09) likewise has no separate DM-RS; irrelevant by the same reasoning as
§6.3.2.4–6.3.2.6. See PDF pages 81–84 if ever needed.

#### 6.4.1.4 Sounding reference signal (stub)

SRS resource/sequence/mapping/slot-configuration definitions (PDF pages 84–90) — a UL channel-
sounding signal with no sidelink equivalent (sidelink channel quality is instead handled via SL
CSI-RS/CSI reporting, already covered in file 02 and file 09 §8.4.1.5). **Not extracted.**

---

## Gaps in this extraction

### Scope decision: full clause 6 was not transcribed, and here is exactly what was cut

Clause 6 is ~59 PDF pages; only the subclauses actually cited by TS 38.211 §8 (sidelink, file 09)
were extracted in full, per the task's instruction to keep each file "a coherent, navigable
scope" rather than a giant dump, and to prioritize effort toward the two items actively blocking
`slPSSCH.m`/`slPSFCH.m`. What was cut, verbatim list:

| Cut content | PDF pages | Why cut |
|---|---|---|
| §6.3.1.1 Scrambling (UCI placeholder-bit logic) | 32 | PUSCH-UCI-multiplexing-specific, no SL citation |
| §6.3.1.2 Modulation | 33 | Standard clause-5.1 mapping, already in file 11 |
| §6.3.1.4 Transform precoding (DFT formula) | 33–34 | PSSCH has no transform-precoding option |
| Tables 6.3.1.5-1 to -7 (codebook precoding matrices) | 34–37 | Sidelink always takes the `W=I` branch |
| §6.3.1.6/§6.3.1.7 VRB/PRB mapping | 37 | Sidelink has its own, simpler version (file 09 §8.3.1.5/.6) |
| §6.3.2.4–6.3.2.6 PUCCH formats 1/2/3/4 | 40–44 | No PSFCH analog beyond format 0 |
| §6.3.3 PRACH (sequence gen + resource mapping) | 44–71 | No sidelink random-access channel exists |
| §6.4.1.1.1 DM-RS sequence generation | 71–73 | Sidelink DM-RS sequence gen is self-contained (file 09) |
| Tables 6.4.1.1.3-3 to -6 (DM-RS time-domain position) | 75–77 | Superseded by sidelink's own Table 8.4.1.1.2-1 |
| §6.4.1.2 PT-RS for PUSCH | 77–80 | Sidelink PT-RS is self-contained (file 09 §8.4.1.2) |
| §6.4.1.3 DM-RS for PUCCH | 81–84 | No PSFCH-DM-RS equivalent |
| §6.4.1.4 SRS | 84–90 | No sidelink equivalent (SL CSI handled differently) |

None of this is a "didn't get to it" gap — each cut was checked against file 09's citation graph
(every "as defined in clause X" and every formula parameter) before being excluded. If a future
task needs any of the cut content, the PDF page ranges above are a direct starting point; no
re-derivation of page boundaries is needed.

### `m_int = 0` for PSFCH is an inference, not an explicit spec statement — flagged

Clause 8.3.4.2.1's PSFCH exceptions list does **not** explicitly say "`m_int = 0`". This file's
§6.3.2.2.2 write-up derives `m_int = 0` from the fact that `m_int`'s own generic definition only
takes a nonzero value when `useInterlacePUCCH-PUSCH` is configured in `BWP-UplinkCommon`/
`BWP-UplinkDedicated`, and no such interlacing parameter exists in the sidelink BWP configuration
IEs (per file 04's SL IE catalogue, which was not re-verified line-by-line during this pass — the
absence claim rests on file 04's completeness, not a fresh re-read of every SL IE for this
specific extraction). **Recommendation:** before hard-coding `m_int = 0` in `slPSFCH.m`, do a
targeted grep of file 04 for any `interlac`/`Interlace` sidelink IE to confirm there truly is no
sidelink interlacing parameter; if none exists, the inference above stands.

### `m0` and `m_cs` for PSFCH — confirmed already present and reconstructed in files 05/07

Clause 8.3.4.2.1 gives `m0` and `m_cs` for PSFCH as "given by clause 16.3 of TS 38.213." Checked
during this pass: TS 38.213 §16.3 is fully present in file 05
(`05-TS38213-UE-Sidelink-Control-Procedures.md`, §16.3), and its three cyclic-shift tables are
**already reconstructed** with correct grid structure in
[file 07](07-Reconstructed-Tables.md#table-1631-set-of-cyclic-shift-pairs-m_0) (file 05's own
copy of these three tables is flattened/unusable, same class of PDF-extraction damage file 07
exists to fix — file 07 is the one to read, not file 05, for these specific tables):

- **`m0`** comes from **Table 16.3-1** ("Set of cyclic shift pairs"), indexed by `N_CS^PSFCH`
  (1, 2, 3, or 6 — the number of cyclic shift pairs configured for the resource pool) and a
  cyclic-shift-pair index derived from the PSFCH resource index (§16.3, file 05): e.g. for
  `N_CS^PSFCH=6`, the six pair values are simply `0,1,2,3,4,5`.
- **`m_cs`** comes from **Table 16.3-2** (`0→NACK` maps to cyclic shift `0`, `1→ACK` maps to
  cyclic shift `6` — used when the UE detects SCI format 2-A with Cast type indicator `"01"` or
  `"10"`) or **Table 16.3-3** (NACK-only: `0→NACK` maps to `0`, `1→ACK` is `N/A` — used for SCI
  format 2-B or SCI format 2-A with Cast type indicator `"11"`).

This fully closes the PSFCH `α` formula chain end-to-end: `N_sc^RB`, `m0`, `m_cs`, `m_int`, and
`n_cs(·)` (via its `c_init` override) are all now resolved to concrete, already-extracted spec
content across files 07, 09 (this file's clause-4/5/6 support), and this file — nothing left
pointing outside this repo's notes.

### `2^n`-collapse bug: none found in the extracted subclauses

The formulas transcribed in full above (§6.3.1.5, §6.3.2.2/.2.1/.2.2, §6.3.2.3, §6.4.1.1.3) were
checked against file 09's documented `pdftotext -layout` exponent-collapse bug (`2^15`→`215`,
etc.). No instance was found — the only exponents appearing in these subclauses are small (`2π`,
`2^m` inside a sum with `m=0..7`, `2n+k′`) and none rendered as a collapsed baseline digit run in
the raw extraction. All formulas above were nonetheless cross-checked against the raw
`pdftotext -layout` dump line-by-line during transcription, not just visually skimmed.

### Table reconstruction notes

- **Table 6.3.2.1-1** (PUCCH formats) and **Tables 6.4.1.1.3-1/-2** (DM-RS config type 1/2
  parameters) all had clean, correctly-aligned flattened text in the raw `-layout` extraction —
  reconstructed directly, no image cross-check needed (small tables, unambiguous column mapping,
  and Table 6.4.1.1.3-1 was independently cross-checked against sidelink's own Table 8.4.1.1.2-2
  in file 09, which is a strict subset and matched exactly — a strong consistency check).
