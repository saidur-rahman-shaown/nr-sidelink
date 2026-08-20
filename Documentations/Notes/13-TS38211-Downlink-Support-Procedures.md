# TS 38.211 §7 — Downlink (Support Procedures Referenced by Sidelink)

> **Source:** 3GPP TS 38.211 V16.10.0 (2022-06), Release 16 — *NR; Physical channels and modulation*
> **Scope:** clause 7 ("Downlink") is ~28 pages (PDF pages 90–117) covering PDSCH, PDCCH, PBCH,
> and all downlink reference/sync signals (DM-RS, PT-RS, CSI-RS, RIM-RS, PRS, PSS/SSS, SS/PBCH
> block) in full generality. This file extracts **only the subclauses TS 38.211 §8 (sidelink,
> file 09) actually cites**, plus enough surrounding structure to stay navigable. Everything else
> is a heading-plus-summary **stub** with a PDF page pointer — see "Gaps in this extraction".
> **Status:** the extracted subclauses are verbatim spec text, reformatted; stubs are this
> project's own summary, clearly marked as such.
> **Priority context:** this file resolves the **highest-priority** item blocking this project —
> §7.3.1.3 (layer mapping for ν∈{1,2}, needed to finish `+phy/+ts38211/slPSSCH.m`) — and the
> **lower-priority** item §7.4.1.5.3 (generic CSI-RS RE-mapping template).

## Contents

- [7 Downlink](#7-downlink)
  - [7.1 Overview](#71-overview)
  - [7.2 Physical resources](#72-physical-resources)
  - [7.3 Physical channels](#73-physical-channels)
    - [7.3.1 Physical downlink shared channel](#731-physical-downlink-shared-channel)
      - [7.3.1.1 Scrambling (stub)](#7311-scrambling-stub)
      - [7.3.1.2 Modulation (stub)](#7312-modulation-stub)
      - [7.3.1.3 Layer mapping — full](#7313-layer-mapping--full)
      - [7.3.1.4 Antenna port mapping](#7314-antenna-port-mapping)
      - [7.3.1.5 and 7.3.1.6 — VRB/PRB mapping (stub)](#7315-and-7316--vrbprb-mapping-stub)
    - [7.3.2 Physical downlink control channel (stub)](#732-physical-downlink-control-channel-stub)
    - [7.3.3 Physical broadcast channel (stub)](#733-physical-broadcast-channel-stub)
  - [7.4 Physical signals](#74-physical-signals)
    - [7.4.1 Reference signals](#741-reference-signals)
      - [7.4.1.1–7.4.1.4 DM-RS/PT-RS for PDSCH, PDCCH, PBCH (stub)](#7411–7414-dm-rspt-rs-for-pdsch-pdcch-pbch-stub)
      - [7.4.1.5 CSI reference signals — full](#7415-csi-reference-signals--full)
      - [7.4.1.6 RIM reference signals (stub)](#7416-rim-reference-signals-stub)
      - [7.4.1.7 Positioning reference signals (stub)](#7417-positioning-reference-signals-stub)
    - [7.4.2 Synchronization signals (stub)](#742-synchronization-signals-stub)
    - [7.4.3 SS/PBCH block (stub)](#743-sspbch-block-stub)
- [Gaps in this extraction](#gaps-in-this-extraction)

---

## 7 Downlink

### 7.1 Overview

A downlink physical channel corresponds to a set of resource elements carrying information
originating from higher layers. The following downlink physical channels are defined: **Physical
Downlink Shared Channel (PDSCH)**, **Physical Broadcast Channel (PBCH)**, **Physical Downlink
Control Channel (PDCCH)**.

A downlink physical signal is used by the physical layer but does not carry information
originating from higher layers. The following downlink physical signals are defined:
**Demodulation reference signals (DM-RS)**, **Phase-tracking reference signals (PT-RS)**,
**Positioning reference signal (PRS)**, **Channel-state information reference signal (CSI-RS)**,
**Primary synchronization signal (PSS)**, **Secondary synchronization signal (SSS)**.

### 7.2 Physical resources

The frame structure and physical resources the UE shall assume when receiving downlink
transmissions are defined in clause 4 (file 10).

The following antenna ports are defined for the downlink:

- Antenna ports starting with 1000 for PDSCH
- Antenna ports starting with 2000 for PDCCH
- Antenna ports starting with 3000 for CSI-RS
- Antenna ports starting with 4000 for SS/PBCH block transmission
- Antenna ports starting with 5000 for positioning reference signals

*(Compare sidelink's port ranges in file 09 §8.2.4 — the same first-four prefixes 1000/2000/3000/
4000 are reused by sidelink for PSSCH/PSCCH/CSI-RS/S-SS-PSBCH, with 5000 repurposed for PSFCH
instead of PRS. The prefix *pattern* is shared; the channel each prefix names is not.)*

The UE shall not assume that two antenna ports are quasi co-located with respect to any QCL type
unless specified otherwise. The remaining paragraphs define the DM-RS-to-PDSCH/PDCCH/PBCH
channel-inference conditions (same resource/slot/PRG, or same CORESET precoding assumption, or
same SS/PBCH block index) — Uu-specific detail with no sidelink counterpart, not reproduced here.

### 7.3 Physical channels

#### 7.3.1 Physical downlink shared channel

##### 7.3.1.1 Scrambling (stub)

Up to two codewords `q∈{0,1}`; scrambling follows the standard `b̃(i)=(b(i)+c(i)) mod 2` pattern
(clause 5.2.1 Gold sequence, file 11) with a `c_init` built from `n_RNTI`, codeword index `q`, and
`n_ID` (with special-casing for dual-CORESET-pool `dataScramblingIdentityPDSCH`/`PDSCH2`). **Not
extracted in full** — no sidelink citation. See PDF pages 91–92 if ever needed.

##### 7.3.1.2 Modulation (stub)

Standard clause-5.1 mapping using Table 7.3.1.2-1 (QPSK/16QAM/64QAM/256QAM — the downlink-only
subset, no π/2-BPSK row since PDSCH has no transform-precoding option). **Not extracted in full.**

##### 7.3.1.3 Layer mapping — full

> The UE shall assume that complex-valued modulation symbols for each of the codewords to be
> transmitted are mapped onto one or several layers according to **Table 7.3.1.3-1**.
> Complex-valued modulation symbols `d^(q)(0),…,d^(q)(M_symb^(q)−1)` for codeword `q` shall be
> mapped onto the layers `x(i) = [x^(0)(i) … x^(ν−1)(i)]^T`, `i = 0,1,…,M_symb^layer−1`, where `ν`
> is the number of layers and `M_symb^layer` is the number of modulation symbols per layer.

**This is the clause sidelink §8.3.1.3 (file 09) points to directly:** *"Layer mapping shall be
done according to clause 7.3.1.3 with the number of layers `ν ∈ {1,2}`, resulting in
`x(i) = [x^(0)(i) … x^(ν−1)(i)]^T`, `i = 0,1,…,M_symb^layer−1`."* PUSCH's own §6.3.1.3 (file 12)
also just points at this same table rather than defining anything separately — Table 7.3.1.3-1
below is the single generic layer-mapping definition shared by PUSCH, PDSCH, and (for `ν∈{1,2}`)
PSSCH.

**Table 7.3.1.3-1: Codeword-to-layer mapping for spatial multiplexing**

*(Reproducing only the `ν=1` and `ν=2` rows, single codeword — the only rows PSSCH ever reaches,
since sidelink caps `ν` at 2 and always uses one codeword (`q=0` only, per file 09 §8.3.1.1). The
full table covers `ν` up to 8 across one or two codewords for PDSCH; those additional rows are
included afterward for clause completeness but are never exercised by PSSCH.)*

| Number of layers ν | Number of codewords | Mapping (`i = 0,1,…,M_symb^layer−1`) |
|---|---|---|
| **1** | 1 | `x^(0)(i) = d^(0)(i)` — `M_symb^layer = M_symb^(0)` |
| **2** | 1 | `x^(0)(i) = d^(0)(2i)`, `x^(1)(i) = d^(0)(2i+1)` — `M_symb^layer = M_symb^(0)/2` |
| 3 | 1 | `x^(0)(i)=d^(0)(3i)`, `x^(1)(i)=d^(0)(3i+1)`, `x^(2)(i)=d^(0)(3i+2)` — `M_symb^layer = M_symb^(0)/3` |
| 4 | 1 | `x^(0)(i)=d^(0)(4i)`, `x^(1)(i)=d^(0)(4i+1)`, `x^(2)(i)=d^(0)(4i+2)`, `x^(3)(i)=d^(0)(4i+3)` — `M_symb^layer = M_symb^(0)/4` |
| 5 | 2 | `x^(0)(i)=d^(0)(2i)`, `x^(1)(i)=d^(0)(2i+1)`, `x^(2)(i)=d^(1)(3i)`, `x^(3)(i)=d^(1)(3i+1)`, `x^(4)(i)=d^(1)(3i+2)` — `M_symb^layer = M_symb^(0)/2 = M_symb^(1)/3` |
| 6 | 2 | `x^(0..2)(i)=d^(0)(3i..3i+2)`, `x^(3..5)(i)=d^(1)(3i..3i+2)` — `M_symb^layer = M_symb^(0)/3 = M_symb^(1)/3` |
| 7 | 2 | `x^(0..2)(i)=d^(0)(3i..3i+2)`, `x^(3..6)(i)=d^(1)(4i..4i+3)` — `M_symb^layer = M_symb^(0)/3 = M_symb^(1)/4` |
| 8 | 2 | `x^(0..3)(i)=d^(0)(4i..4i+3)`, `x^(4..7)(i)=d^(1)(4i..4i+3)` — `M_symb^layer = M_symb^(0)/4 = M_symb^(1)/4` |

**What this means for `slPSSCH.m`'s layer mapping, stated plainly:**

- **`ν=1`:** the codeword's modulation-symbol stream is copied straight onto the single layer,
  one-to-one, index for index. `x^(0)(i) = d^(0)(i)`. **A pure pass-through — this project's
  existing assumption was correct.**
- **`ν=2`:** the codeword's modulation-symbol stream is **demultiplexed by even/odd sample
  index** onto the two layers: layer 0 gets every even-indexed symbol (`d^(0)(0), d^(0)(2),
  d^(0)(4),…`), layer 1 gets every odd-indexed symbol (`d^(0)(1), d^(0)(3), d^(0)(5),…`), each
  re-indexed from 0. **Not a first-half/second-half split — this project's existing "alternates
  even/odd samples between two layers" assumption was correct**, and the number of symbols per
  layer is exactly half the codeword length (`M_symb^layer = M_symb^(0)/2`, which requires
  `M_symb^(0)` to be even — true by construction since PSSCH's codeword length is always a
  multiple of the modulation order times an even RE count).

##### 7.3.1.4 Antenna port mapping

> The block of vectors `[x^(0)(i) … x^(ν−1)(i)]^T`, `i = 0,1,…,M_symb^layer−1`, shall be mapped
> to antenna ports according to
>
> ```
> [y^(p0)(i)   ]     [x^(0)(i)  ]
> [    ⋮       ]  =  [   ⋮      ]
> [y^(pν-1)(i) ]     [x^(ν-1)(i)]
> ```
>
> where `i = 0,1,…,M_symb^ap−1`, `M_symb^ap = M_symb^layer`. The set of antenna ports
> `{p0,…,pν−1}` shall be determined according to the procedure in [4, TS 38.212].

**Note the naming discontinuity across clauses 6/7/8 that is easy to trip over:** PDSCH's antenna
port mapping (`x → y`, this subclause) is a pure identity/relabelling with **no precoding matrix
at all** — PDSCH layers map 1:1 to antenna ports, full stop. PUSCH (file 12 §6.3.1.5) instead has
a genuine precoding step `y → z` with matrix `W`. Sidelink's own chain (file 09 §8.3.1.3→§8.3.1.4)
follows the **PUSCH-shaped** two-step pattern — layer mapping produces `x`, then clause 8.3.1.4
(citing clause 6.3.1.5, file 12) applies precoding `x → z` with `W` forced to identity — not the
PDSCH-shaped one-step `x → y` relabelling above. **This subclause (7.3.1.4) is therefore not the
right analog for sidelink's second step**; file 12 §6.3.1.5 is. It is included here only because
it is short and completes the picture of how clause 7's own PDSCH chain differs from clause 6's
and clause 8's — sidelink never calls this subclause.

##### 7.3.1.5 and 7.3.1.6 — VRB/PRB mapping (stub)

§7.3.1.5 maps precoded (for PDSCH: antenna-port-mapped) symbols to virtual resource blocks,
skipping DM-RS/CSI-RS/PT-RS/not-available REs. §7.3.1.6 maps virtual to physical resource blocks,
with both non-interleaved and a substantially more involved **interleaved** option (resource-block
bundling, CORESET-0-relative numbering, a bit-reversal-style interleaver formula) used for
DCI-format-1_0 common-search-space scheduling. **Not extracted in full** — sidelink has its own
non-interleaved-only VRB/PRB mapping in file 09 §8.3.1.5/§8.3.1.6, and the interleaved option here
is a PDCCH/CORESET-0-specific Uu mechanism with no sidelink relevance at all. See PDF pages 94–96
if ever needed.

#### 7.3.2 Physical downlink control channel (stub)

Defines Control-Channel Elements (CCE), Control-Resource Sets (CORESET), PDCCH scrambling,
modulation, and RE mapping (antenna port 2000). **Not extracted** — sidelink has no PDCCH
equivalent; PSCCH (file 09 §8.3.2) is independently and completely specified without reference to
this subclause. See PDF pages 96–98 if ever needed.

#### 7.3.3 Physical broadcast channel (stub)

Defines PBCH scrambling, modulation, and mapping (deferred to clause 7.4.3, the SS/PBCH block
subclause). **Not extracted** — sidelink's PSBCH (file 09 §8.3.3) is independently specified,
mapped via its own S-SS/PSBCH block subclause (file 09 §8.4.3), not this one. See PDF page 98 if
ever needed.

### 7.4 Physical signals

#### 7.4.1 Reference signals

##### 7.4.1.1–7.4.1.4 DM-RS/PT-RS for PDSCH, PDCCH, PBCH (stub)

- **§7.4.1.1 DM-RS for PDSCH** (PDF pages 98–103): sequence generation (standard Gold-sequence
  construction, `c_init` from `n_SCID`/scrambling IDs) and a substantial RE-mapping subclause
  (§7.4.1.1.2) with its own configuration-type-1/2 CDM tables — structurally parallel to, but a
  separate table set from, PUSCH's §6.4.1.1.3 (file 12). Not the clause sidelink PSSCH DM-RS
  cites (that is §6.4.1.1.3, per file 09 §8.4.1.1.2) — **not extracted**.
- **§7.4.1.2 PT-RS for PDSCH** (PDF pages 103–105): not cited by sidelink PT-RS (file 09
  §8.4.1.2, which cites clause 8.3.1.4/6.3.1.5 instead) — **not extracted**.
- **§7.4.1.3 DM-RS for PDCCH** (PDF page 105): irrelevant, no sidelink PDCCH — **not extracted**.
- **§7.4.1.4 DM-RS for PBCH** (PDF pages 105–106): irrelevant, sidelink PSBCH DM-RS is
  independently specified in file 09 §8.4.1.4 — **not extracted**.

##### 7.4.1.5 CSI reference signals — full

###### 7.4.1.5.1 General

> Zero-power (ZP) and non-zero-power (NZP) CSI-RS are defined:
>
> - for a non-zero-power CSI-RS configured by the `NZP-CSI-RS-Resource` IE or by the
>   `CSI-RS-Resource-Mobility` field in `CSI-RS-ResourceConfigMobility`, the sequence shall be
>   generated according to clause 7.4.1.5.2 and mapped to resource elements according to clause
>   7.4.1.5.3;
> - for a zero-power CSI-RS configured by the `ZP-CSI-RS-Resource` IE, the UE shall assume the
>   resource elements defined in clause 7.4.1.5.3 are not used for PDSCH transmission (subject to
>   clause 5.1.4.2 of [6, TS 38.214]). The UE performs the same measurement/reception on
>   channels/signals except PDSCH regardless of whether they collide with ZP CSI-RS or not.

> **Sidelink CSI-RS has no zero-power option** — file 09 §8.4.1.5.3's exceptions list explicitly
> states "zero-power CSI-RS is not supported" for sidelink. Only the NZP branch above applies.

###### 7.4.1.5.2 Sequence generation

> The reference-signal sequence `r(m)` is defined by
>
> ```
> r(m) = (1/√2)(1−2c(2m)) + j(1/√2)(1−2c(2m+1))
> ```
>
> where the pseudo-random sequence `c(i)` is defined in clause 5.2.1 (file 11). The pseudo-random
> sequence generator shall be initialised with
>
> ```
> c_init = (2^10·(N_symb^slot·n_s,f^μ + l + 1)·(2·n_ID + 1) + n_ID) mod 2^31
> ```
>
> at the start of each OFDM symbol, where `n_s,f^μ` is the slot number within a radio frame, `l`
> is the OFDM symbol number within a slot, and `n_ID` equals the higher-layer parameter
> `scramblingID` or `sequenceGenerationConfig`.

**Structurally identical to sidelink's own CSI-RS sequence generation** (file 09 §8.4.1.5.2),
which uses the same `r(m)` formula and the same `2^10·(...)·(2n_ID+1) + n_ID) mod 2^31` shape for
`c_init`, differing only in how `n_ID` is derived (sidelink: `n_ID = N_ID^X mod 2^10` from the
associated PSCCH's SCI CRC, per file 09; here: a direct RRC-configured `scramblingID`). File 09
already extracted and verified this formula (including checking for the `2^10`/`2^31`
exponent-collapse bug); reproduced here only to show sidelink's version is a direct descendant of
this generic one, not an independent invention.

###### 7.4.1.5.3 Mapping to physical resources — full

> For each CSI-RS configured, the UE shall assume the sequence `r(m)` is mapped to resource
> elements `(k,l)_p,μ` according to
>
> ```
> a_{k,l}^(p,μ) = β_CSIRS · w_f(k′) · w_t(l′) · r(l_{n,s,f}, m)
>
> m = n·(comb-related index) + k′         [see note below on the k↔n relationship]
> k = n·N_sc^RB + k′ + k̄
> l = l̄ + l′
> l′ = { 0        for X=1 (see note on X below)
>      { 0,1      for X>1
> n  = 0,1,…
> ```
>
> when the resource element `(k,l)_p,μ` is within the resource blocks occupied by the CSI-RS
> resource for which the UE is configured. The reference point for `k=0` is subcarrier 0 in common
> resource block 0.
>
> The value of `ρ` (density) is given by the higher-layer parameter `density` in
> `CSI-RS-ResourceMapping`/`CSI-RS-CellMobility`; the number of ports `X` is given by `nrofPorts`.
>
> The UE is not expected to receive CSI-RS and DM-RS on the same resource elements. `β_CSIRS ≠ 0`
> for a non-zero-power CSI-RS, selected such that the power offset in `powerControlOffsetSS` (if
> provided) is fulfilled.
>
> The quantities `k′`, `l′`, `w_f(k′)`, and `w_t(l′)` are given by **Tables 7.4.1.5.3-1 to
> 7.4.1.5.3-5** below, where each `(k̄,l̄)` in a row of Table 7.4.1.5.3-1 corresponds to a CDM
> group of size 1 (no CDM) or 2, 4, or 8. CDM type is given by `cdm-Type` in
> `CSI-RS-ResourceMapping`. `k′`/`l′` index resource elements *within* a CDM group.
>
> Time-domain locations `l0 ∈ {0,…,13}` and `l1 ∈ {2,…,12}` come from
> `firstOFDMSymbolInTimeDomain`/`firstOFDMSymbolInTimeDomain2`. The frequency-domain location is a
> bitmap (`frequencyDomainAllocation`) whose bit-to-`k_i` mapping depends on which row of Table
> 7.4.1.5.3-1 applies (4 different bitmap widths/scale-factor combinations across the 18 rows).
>
> CSI-RS antenna ports are numbered `p = 3000 + s + jL`, `j = 0,…,N/L−1`, `s = 0,…,L−1`, where `s`
> is the sequence index from Tables 7.4.1.5.3-2 to -5, `L ∈ {1,2,4,8}` is the CDM group size, and
> `N` is the number of CSI-RS ports. CDM groups are numbered in order of increasing frequency
> location first, then increasing time location.
>
> For periodic/semi-persistent CSI-RS (or CSI-RS-CellMobility), the UE assumes transmission in
> slots satisfying `(N_slot^frame,μ·n_f + n_s,f^μ − T_offset) mod T_CSI-RS = 0`, with periodicity
> `T_CSI-RS` and offset `T_offset` from `CSI-ResourcePeriodicityAndOffset`/`slotConfig`.
>
> The UE may assume antenna ports within a CSI-RS resource are quasi co-located with QCL Type A,
> Type D (when applicable), and average gain.

**Sidelink §8.4.1.5.3 (file 09) applies this template with three restrictions**, which narrow the
18-row Table 7.4.1.5.3-1 down to just **two rows** in practice:

- "only 1 and 2 antenna ports are supported, `X ∈ {1,2}`"
- "only density `ρ = 1` is supported" (not `0.5`)
- "zero-power CSI-RS is not supported" (already noted under §7.4.1.5.1 above)

Cross-referencing against Table 7.4.1.5.3-1 below: **only Row 2 (`X=1`) and Row 3 (`X=2`)**
support both `X ≤ 2` *and* density `1` (as opposed to `1, 0.5` where sidelink is restricted to the
`1` option) — every other row requires `X ≥ 4`. So sidelink CSI-RS RE mapping reduces to:

- **`X=1` (Row 2, `noCDM`):** single RE per port per PRB, `(k̄,l̄) = (k0,l0)`, `w_f(0)=1`,
  `w_t(0)=1` (Table 7.4.1.5.3-2) — no CDM at all, one port maps directly to one RE.
- **`X=2` (Row 3, `fd-CDM2`):** one RE pair per PRB at `(k0,l0)`, with the two ports
  frequency-code-division-multiplexed using `w_f = [1,1]` (port index 0) or `w_f = [1,−1]` (port
  index 1) from Table 7.4.1.5.3-3, `w_t(0)=1` for both — i.e. the exact same `+1/+1` vs `+1/−1`
  CDM pattern already seen in sidelink's own PSSCH DM-RS Table 8.4.1.1.2-2 (file 09) and the
  generic PUSCH DM-RS Table 6.4.1.1.3-1 (file 12) — this `[+1,+1]`/`[+1,−1]` two-port CDM pattern
  recurs across DM-RS and CSI-RS alike throughout this spec.

**Table 7.4.1.5.3-1: CSI-RS locations within a slot** *(full 18-row table for clause completeness;
rows 2 and 3, bolded, are the only rows reachable under sidelink's `X∈{1,2}`/`ρ=1` restriction)*

| Row | Ports X | Density ρ | cdm-Type | (k̄,l̄) locations | CDM group index j | k′ range | l′ range |
|---|---|---|---|---|---|---|---|
| 1 | 1 | 3 | noCDM | (k0,l0), (k0+4,l0), (k0+8,l0) | 0,0,0 | 0 | 0 |
| **2** | **1** | **1, 0.5** | **noCDM** | **(k0,l0)** | **0** | **0** | **0** |
| **3** | **2** | **1, 0.5** | **fd-CDM2** | **(k0,l0)** | **0** | **0, 1** | **0** |
| 4 | 4 | 1 | fd-CDM2 | (k0,l0), (k0+2,l0) | 0,1 | 0, 1 | 0 |
| 5 | 4 | 1 | fd-CDM2 | (k0,l0), (k0,l0+1) | 0,1 | 0, 1 | 0 |
| 6 | 8 | 1 | fd-CDM2 | (k0,l0),(k1,l0),(k2,l0),(k3,l0) | 0,1,2,3 | 0, 1 | 0 |
| 7 | 8 | 1 | fd-CDM2 | (k0,l0),(k1,l0),(k0,l0+1),(k1,l0+1) | 0,1,2,3 | 0, 1 | 0 |
| 8 | 8 | 1 | cdm4-FD2-TD2 | (k0,l0), (k1,l0) | 0,1 | 0, 1 | 0, 1 |
| 9 | 12 | 1 | fd-CDM2 | (k0..k5, l0) | 0,1,2,3,4,5 | 0, 1 | 0 |
| 10 | 12 | 1 | cdm4-FD2-TD2 | (k0,l0),(k1,l0),(k2,l0) | 0,1,2 | 0, 1 | 0, 1 |
| 11 | 16 | 1, 0.5 | fd-CDM2 | (k0..k3,l0), (k0..k3,l0+1) | 0..7 | 0, 1 | 0 |
| 12 | 16 | 1, 0.5 | cdm4-FD2-TD2 | (k0..k3, l0) | 0,1,2,3 | 0, 1 | 0, 1 |
| 13 | 24 | 1, 0.5 | fd-CDM2 | (k0..k2,l0),(k0..k2,l0+1),(k0..k2,l1),(k0..k2,l1+1) | 0..11 | 0, 1 | 0 |
| 14 | 24 | 1, 0.5 | cdm4-FD2-TD2 | (k0..k2,l0), (k0..k2,l1) | 0..5 | 0, 1 | 0, 1 |
| 15 | 24 | 1, 0.5 | cdm8-FD2-TD4 | (k0..k2, l0) | 0,1,2 | 0, 1 | 0, 1, 2, 3 |
| 16 | 32 | 1, 0.5 | fd-CDM2 | (k0..k3,l0),(k0..k3,l0+1),(k0..k3,l1),(k0..k3,l1+1) | 0..15 | 0, 1 | 0 |
| 17 | 32 | 1, 0.5 | cdm4-FD2-TD2 | (k0..k3,l0), (k0..k3,l1) | 0..7 | 0, 1 | 0, 1 |
| 18 | 32 | 1, 0.5 | cdm8-FD2-TD4 | (k0..k3, l0) | 0,1,2,3 | 0,1 | 0,1,2,3 |

**Table 7.4.1.5.3-2: `w_f(k′)`, `w_t(l′)` for `cdm-Type = 'noCDM'`** *(sidelink Row 2)*

| Index | w_f(0) | w_t(0) |
|---|---|---|
| 0 | 1 | 1 |

**Table 7.4.1.5.3-3: `w_f(k′)`, `w_t(l′)` for `cdm-Type = 'fd-CDM2'`** *(sidelink Row 3)*

| Index | [w_f(0) w_f(1)] | w_t(0) |
|---|---|---|
| 0 | [1  1] | 1 |
| 1 | [1 −1] | 1 |

**Tables 7.4.1.5.3-4/-5** (`cdm4-FD2-TD2`, 4-row `[w_f(0..1)]`×`[w_t(0..1)]` sign-pattern table;
`cdm8-FD2-TD4`, 8-row `[w_f(0..1)]`×`[w_t(0..3)]` sign-pattern table) are **not reproduced** —
they only apply to Rows 8/10/12/14/17/18 (`X≥8`), unreachable under sidelink's `X∈{1,2}`
restriction. See PDF page 109 if ever needed for a non-sidelink use.

##### 7.4.1.6 RIM reference signals (stub)

Gcatalogb-to-gNB Remote Interference Management reference signal — sequence generation, mapping,
and an extensive multi-part configuration scheme (time/frequency/sequence parameter indexing,
uplink-downlink switching-period-relative timing) spanning PDF pages 109–112, among the most
formula-dense subclauses in the entire document. **Not extracted** — zero UE-side or sidelink
relevance (RIM-RS is purely an inter-gNB coordination signal). See PDF pages 109–112 if ever
needed (extremely unlikely for this project).

##### 7.4.1.7 Positioning reference signals (stub)

PRS sequence generation and mapping for downlink positioning (PDF pages 113–114). **Not
extracted** — sidelink positioning (if ever relevant to this project) is a distinct, not-yet-
extracted feature area with no citation path through this subclause. See PDF pages 113–114 if
ever needed.

#### 7.4.2 Synchronization signals (stub)

Physical-layer cell identities (`N_ID^cell = N_ID^(1)·3 + N_ID^(2)`, 1008 identities), PSS
sequence generation (single length-127 m-sequence, cyclic-shifted by `43·N_ID^(2)`), and SSS
sequence generation (product of two length-127 m-sequences) — the Uu counterpart of sidelink's
S-PSS/S-SSS (file 09 §8.4.2, already fully extracted and cross-checked there, including the
correction that S-PSS is one m-sequence at two cyclic shifts, not two base sequences). **Not
extracted here** — file 09 §8.4.2's own commentary already notes the structural parallel to this
subclause (calling out clause 7.4.2.3.1 by name when describing S-SSS's two-m-sequence-product
construction), so re-extracting this subclause would be pure duplication. See PDF pages 115–116
if the exact Uu PSS/SSS formulas (as opposed to the sidelink ones) are ever independently needed.

#### 7.4.3 SS/PBCH block (stub)

Time-frequency structure of the Uu SS/PBCH block (240 subcarriers, `N_symb^SSB=4` symbols,
PSS/SSS/PBCH+DM-RS resource mapping table) and its time-domain candidate-block-index scheme. **Not
extracted** — sidelink's S-SS/PSBCH block (file 09 §8.4.3) is structurally similar (same kind of
resource-map table, same PSS/SSS/PBCH+DM-RS layout idea) but numerically different (132
subcarriers not 240, 13 symbols not 4, different symbol/subcarrier assignments) and is already
fully extracted independently in file 09 — re-extracting the Uu version would not resolve any
open gap for this project. See PDF pages 116–117 if ever needed.

---

## Gaps in this extraction

### Scope decision: full clause 7 was not transcribed, and here is exactly what was cut

Clause 7 is ~28 PDF pages; only §7.3.1.3 (layer mapping) and §7.4.1.5 (CSI-RS, especially
§7.4.1.5.3) were extracted in full, since those are the only subclauses TS 38.211 §8 (sidelink,
file 09) cites. Cut content, verbatim list:

| Cut content | PDF pages | Why cut |
|---|---|---|
| §7.3.1.1 Scrambling | 91–92 | No sidelink citation, standard Gold-sequence pattern already in file 11 |
| §7.3.1.2 Modulation | 92 | Standard clause-5.1 mapping, already in file 11 |
| §7.3.1.5/§7.3.1.6 VRB/PRB mapping | 94–96 | Sidelink has its own (file 09 §8.3.1.5/.6); interleaved-mapping option is CORESET-0-specific |
| §7.3.2 PDCCH | 96–98 | No sidelink PDCCH equivalent |
| §7.3.3 PBCH | 98 | No sidelink PSBCH citation to this subclause |
| §7.4.1.1 DM-RS for PDSCH | 98–103 | Sidelink PSSCH DM-RS cites §6.4.1.1.3 (file 12), not this |
| §7.4.1.2 PT-RS for PDSCH | 103–105 | Sidelink PT-RS cites §8.3.1.4/6.3.1.5, not this |
| §7.4.1.3 DM-RS for PDCCH | 105 | No sidelink PDCCH |
| §7.4.1.4 DM-RS for PBCH | 105–106 | Sidelink PSBCH DM-RS independently specified (file 09 §8.4.1.4) |
| §7.4.1.6 RIM-RS | 109–112 | Zero UE/sidelink relevance, gNB-to-gNB only |
| §7.4.1.7 PRS | 113–114 | Not referenced by any sidelink or SL-adjacent clause |
| §7.4.2 Sync signals (PSS/SSS) | 115–116 | Sidelink S-PSS/S-SSS independently specified (file 09 §8.4.2) |
| §7.4.3 SS/PBCH block | 116–117 | Sidelink S-SS/PSBCH block independently specified (file 09 §8.4.3) |

Each cut was checked against file 09's citation graph before being excluded, same standard as
file 12. Tables 7.4.1.5.3-4/-5 (CDM types requiring `X≥8`) were cut for the specific, verifiable
reason that sidelink's `X∈{1,2}` restriction makes them unreachable — not a general
"CSI-RS-adjacent, skip it" decision.

### `2^n`-collapse bug: none found in the extracted subclauses

§7.3.1.3's Table 7.3.1.3-1 and §7.4.1.5's formulas were checked against file 09's documented
`pdftotext -layout` exponent-collapse bug. The one exponent-bearing formula extracted in full
here — §7.4.1.5.2's `c_init = (2^10·(...)·(2n_ID+1) + n_ID) mod 2^31` — was cross-checked
directly against file 09's already-verified sidelink CSI-RS `c_init` formula (file 09 §8.4.1.5.2,
which uses the identical `2^10`/`2^31` shape and was already confirmed correct there): both
extractions show `2^10` and `2^31` as proper exponents, not collapsed digit runs (`210`, `231`),
confirming no fresh instance of the bug in this file's extraction.

### Table 7.4.1.5.3-1 reconstruction note

This 18-row table has the most complex merged-cell structure of any table extracted across files
10–13 (multi-value cells like "`(k0,l0), (k1,l0), (k2,l0), (k3,l0)`" for the `(k̄,l̄)` column, and
a shared `k′`/`l′` range column that applies per-CDM-group rather than per-row in the strict
sense). It was reconstructed from the flattened `-layout` text, which preserved row-by-row
structure correctly, and cross-checked for internal consistency against the three sidelink
restrictions stated in file 09 §8.4.1.5.3 (`X∈{1,2}`, `ρ=1` only, no ZP) rather than against a
rendered page image — the two rows that matter for this project (Rows 2 and 3) are short enough
(1–2 REs, no multi-value cells) that misreading risk is low, but if the full 18-row table is ever
needed normatively for a non-sidelink purpose, cross-check Rows 4–18 against a rendered PDF page
image first, following file 09's standard practice for complex tables.
