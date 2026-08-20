# TS 38.211 §4 — Frame Structure and Physical Resources

> **Source:** 3GPP TS 38.211 V16.10.0 (2022-06), Release 16 — *NR; Physical channels and modulation*
> **Scope:** the entirety of clause 4 — time units, numerologies, frame/subframe/slot structure,
> antenna port definition, resource grid, resource elements, resource blocks (common/physical/
> virtual/interlaced), bandwidth part, carrier aggregation. This is the clause that TS 38.211 §8
> (sidelink) repeatedly says "as defined in clause 4" and stops — see file 09's Gaps section for
> the list of sidelink subclauses this file resolves.
> **Status:** verbatim spec extract, reformatted. Page headers/footers removed, PDF hard-wraps
> rejoined, clause numbers promoted to headings. Extracted from PDF pages 11–16 (printed page
> numbers equal PDF page numbers throughout this document, confirmed in file 09).
> **Priority context:** this clause is needed eventually for `slResourceGrid` (not yet built) but
> is not blocking any in-progress module. Extracted in full because it is short (~5 pages) and
> the definitions are foundational, not because it is urgent — see `00-INDEX.md` gap tracking.

## Contents

- [4 Frame structure and physical resources](#4-frame-structure-and-physical-resources)
  - [4.1 General](#41-general)
  - [4.2 Numerologies](#42-numerologies)
  - [4.3 Frame structure](#43-frame-structure)
    - [4.3.1 Frames and subframes](#431-frames-and-subframes)
    - [4.3.2 Slots](#432-slots)
  - [4.4 Physical resources](#44-physical-resources)
    - [4.4.1 Antenna ports](#441-antenna-ports)
    - [4.4.2 Resource grid](#442-resource-grid)
    - [4.4.3 Resource elements](#443-resource-elements)
    - [4.4.4 Resource blocks](#444-resource-blocks)
      - [4.4.4.1 General](#4441-general)
      - [4.4.4.2 Point A](#4442-point-a)
      - [4.4.4.3 Common resource blocks](#4443-common-resource-blocks)
      - [4.4.4.4 Physical resource blocks](#4444-physical-resource-blocks)
      - [4.4.4.5 Virtual resource blocks](#4445-virtual-resource-blocks)
      - [4.4.4.6 Interlaced resource blocks](#4446-interlaced-resource-blocks)
    - [4.4.5 Bandwidth part](#445-bandwidth-part)
  - [4.5 Carrier aggregation](#45-carrier-aggregation)
- [Gaps in this extraction](#gaps-in-this-extraction)

---

## 4 Frame structure and physical resources

### 4.1 General

Throughout this specification, unless otherwise noted, the size of various fields in the time
domain is expressed in time units `T_c = 1/(Δf_max · N_f)` where `Δf_max = 480·10^3` Hz and
`N_f = 4096`. The constant `κ = T_s/T_c = 64` where `T_s = 1/(Δf_ref · N_f,ref)`,
`Δf_ref = 15·10^3` Hz and `N_f,ref = 2048`.

Throughout this specification, unless otherwise noted, statements using the term "UE" in clauses
4, 5, 6, or 7 are equally applicable to the IAB-MT part of an IAB-node.

### 4.2 Numerologies

Multiple OFDM numerologies are supported as given by Table 4.2-1 where µ and the cyclic prefix
for a downlink or uplink bandwidth part are obtained from the higher-layer parameters
`subcarrierSpacing` and `cyclicPrefix`, respectively.

**Table 4.2-1: Supported transmission numerologies**

| µ | Δf = 2^µ · 15 [kHz] | Cyclic prefix |
|---|---|---|
| 0 | 15 | Normal |
| 1 | 30 | Normal |
| 2 | 60 | Normal, Extended |
| 3 | 120 | Normal |
| 4 | 240 | Normal |

> Compare Table 8.2.2-1 in file 09: the sidelink numerology table is the same shape but stops at
> µ=3 (120 kHz) — µ=4 (240 kHz) is a downlink-only numerology (used for SS/PBCH block
> transmission bandwidth signalling), never valid for sidelink.

### 4.3 Frame structure

#### 4.3.1 Frames and subframes

Downlink, uplink, and sidelink transmissions are organized into frames with
`T_f = Δf_max·N_f/100 · T_c = 10 ms` duration, each consisting of ten subframes of
`T_sf = Δf_max·N_f/1000 · T_c = 1 ms` duration. The number of consecutive OFDM symbols per
subframe is `N_symb^subframe,µ = N_symb^slot · N_slot^subframe,µ`. Each frame is divided into two
equally-sized half-frames of five subframes each, with half-frame 0 consisting of subframes 0–4
and half-frame 1 consisting of subframes 5–9.

There is one set of frames in the uplink and one set of frames in the downlink on a carrier.

Uplink frame number `i` for transmission from the UE shall start
`T_TA = (N_TA + N_TA,offset)·T_c` before the start of the corresponding downlink frame at the UE,
where `N_TA,offset` is given by [5, TS 38.213], except for msgA transmission on PUSCH where
`N_TA = 0` shall be used.

**Figure 4.3.1-1: Uplink-downlink timing relation** — a downlink frame `i` box and an uplink
frame `i` box are drawn side by side, with the uplink frame box starting `T_TA` seconds earlier
than the downlink frame box.

> **This is the `N_TA,offset` that sidelink §8.5 (file 09) points back to.** File 09's Gaps
> section noted that clause 8.5 says "`N_TA,offset` is given by clause 4.3.1 of [TS 38.211]"
> (i.e. this subclause) when a UE has a serving cell fulfilling the S criterion — but the value
> itself is not stated *here* either; §4.3.1 only defines the timing relation that `N_TA,offset`
> feeds into, and the offset's numeric definition is in TS 38.213 (per the paragraph above). This
> is not a new gap, just confirmation that clause 4.3.1 is a dead end for the numeric value, same
> as file 09 already flagged for TS 38.133.

#### 4.3.2 Slots

For subcarrier spacing configuration µ, slots are numbered `n_s^µ ∈ {0,…,N_slot^subframe,µ − 1}`
in increasing order within a subframe and `n_s,f^µ ∈ {0,…,N_slot^frame,µ − 1}` in increasing
order within a frame. There are `N_symb^slot` consecutive OFDM symbols in a slot, where
`N_symb^slot` depends on the cyclic prefix as given by Tables 4.3.2-1 and 4.3.2-2. The start of
slot `n_s^µ` in a subframe is aligned in time with the start of OFDM symbol `n_s^µ · N_symb^slot`
in the same subframe.

OFDM symbols in a slot in a downlink or uplink frame can be classified as 'downlink', 'flexible',
or 'uplink'. Signalling of slot formats is described in clause 11.1 of [5, TS 38.213].

- In a slot in a downlink frame, the UE shall assume that downlink transmissions only occur in
  'downlink' or 'flexible' symbols.
- In a slot in an uplink frame, the UE shall only transmit in 'uplink' or 'flexible' symbols.

A UE not capable of full-duplex communication and not supporting simultaneous transmission and
reception (as defined by `simultaneousRxTxInterBandENDC`, `simultaneousRxTxInterBandCA`, or
`simultaneousRxTxSUL` [10, TS 38.306]) among all cells within a group of cells is not expected to:

- transmit in the uplink in one cell within the group earlier than `N_Rx-Tx · T_c` after the end
  of the last received downlink symbol in the same or a different cell within the group, where
  `N_Rx-Tx` is given by Table 4.3.2-3;
- receive in the downlink in one cell within the group earlier than `N_Tx-Rx · T_c` after the end
  of the last transmitted uplink symbol in the same or a different cell within the group, where
  `N_Tx-Rx` is given by Table 4.3.2-3.

The same two constraints apply, with the same table, to a single cell (not just cross-cell within
a group) and to DAPS handover operation between two cells. *(Four near-identical paragraphs in
the source collapse to this one summary; the only variable between them is which cell pairing the
constraint applies to — same cell, same group, or DAPS source/target — and neither `N_Rx-Tx` nor
`N_Tx-Rx` changes.)*

**Table 4.3.2-1: Number of OFDM symbols per slot, slots per frame, and slots per subframe for
normal cyclic prefix**

| µ | N_symb^slot | N_slot^frame,µ | N_slot^subframe,µ |
|---|---|---|---|
| 0 | 14 | 10 | 1 |
| 1 | 14 | 20 | 2 |
| 2 | 14 | 40 | 4 |
| 3 | 14 | 80 | 8 |
| 4 | 14 | 160 | 16 |

**Table 4.3.2-2: Number of OFDM symbols per slot, slots per frame, and slots per subframe for
extended cyclic prefix**

| µ | N_symb^slot | N_slot^frame,µ | N_slot^subframe,µ |
|---|---|---|---|
| 2 | 12 | 40 | 4 |

**Table 4.3.2-3: Transition time N_Rx-Tx and N_Tx-Rx**

| Transition time | FR1 | FR2 |
|---|---|---|
| N_Tx-Rx | 25600 | 13792 |
| N_Rx-Tx | 25600 | 13792 |

> Sidelink's own Table 8.2.2-1 (file 09) restates µ ∈ {0,1,2,3} with the same Δf mapping and adds
> that µ=2 sidelink may use Extended CP — consistent with Table 4.3.2-2 here, which only defines
> `N_symb^slot=12` for µ=2 (there is no extended-CP row for any other µ). Sidelink never uses
> µ=4, so Table 4.3.2-1's µ=4 row is downlink/uplink-only.

### 4.4 Physical resources

#### 4.4.1 Antenna ports

An antenna port is defined such that the channel over which a symbol on the antenna port is
conveyed can be inferred from the channel over which another symbol on the same antenna port is
conveyed.

Two antenna ports are said to be **quasi co-located** if the large-scale properties of the
channel over which a symbol on one antenna port is conveyed can be inferred from the channel over
which a symbol on the other antenna port is conveyed. The large-scale properties include one or
more of: delay spread, Doppler spread, Doppler shift, average gain, average delay, and spatial Rx
parameters.

> This is the entire generic definition. Sidelink's §8.2.4 (file 09) layers the SL-specific
> antenna-port-number ranges (1000/2000/3000/4000/5000 for PSSCH/PSCCH/CSI-RS/S-SS-PSBCH/PSFCH)
> and the SL-specific "can be inferred" conditions on top of this one-paragraph definition — there
> is no more generic content to find here.

#### 4.4.2 Resource grid

For each numerology and carrier, a resource grid of `N_grid,x^size,µ · N_sc^RB` subcarriers and
`N_symb^subframe,µ` OFDM symbols is defined, starting at common resource block `N_grid^start,µ`
indicated by higher-layer signalling. There is one set of resource grids per transmission
direction (uplink, downlink, or sidelink) with the subscript `x` set to DL, UL, and SL for
downlink, uplink, and sidelink, respectively. There is one resource grid for a given antenna port
`p`, subcarrier spacing configuration `µ`, and transmission direction.

For uplink and downlink, the carrier bandwidth `N_grid^size,µ` is given by the higher-layer
parameter `carrierBandwidth` in the `SCS-SpecificCarrier` IE, and the starting position
`N_grid^start,µ` by `offsetToCarrier` in the same IE. *(The sidelink equivalents —
`sl-SCS-SpecificCarrierList` — are already given in file 09 §8.2.5, which this subclause is
deferred from.)*

The frequency location of a subcarrier refers to the center frequency of that subcarrier.

For the downlink, the higher-layer parameter `txDirectCurrentLocation` in the
`SCS-SpecificCarrier` IE indicates the location of the transmitter DC subcarrier in the downlink
for each configured numerology. Values 0–3299 represent the DC subcarrier number; 3300 means the
DC subcarrier is outside the resource grid.

For the uplink, the higher-layer parameter `txDirectCurrentLocation` in the
`UplinkTxDirectCurrentBWP` IE indicates the uplink DC subcarrier location, including whether it
is offset by 7.5 kHz relative to the indicated subcarrier's center. Values 0–3299 represent the
DC subcarrier number; 3300 means outside the grid; 3301 means undetermined.

#### 4.4.3 Resource elements

Each element in the resource grid for antenna port `p` and subcarrier spacing configuration `µ`
is called a **resource element** and is uniquely identified by `(k,l)_p,µ` where `k` is the
frequency-domain index and `l` refers to the symbol position in the time domain relative to some
reference point. Resource element `(k,l)_p,µ` corresponds to a physical resource and the
complex value `a_k,l^(p,µ)`. When there is no risk of confusion, or no particular antenna port or
subcarrier spacing is specified, the indices `p` and `µ` may be dropped, giving `a_k,l^(p)` or
`a_k,l`.

#### 4.4.4 Resource blocks

##### 4.4.4.1 General

A **resource block** is defined as `N_sc^RB = 12` consecutive subcarriers in the frequency
domain.

##### 4.4.4.2 Point A

**Point A** serves as a common reference point for resource block grids and is obtained from:

- `offsetToPointA` for a PCell downlink, where `offsetToPointA` represents the frequency offset
  between point A and the lowest subcarrier of the lowest resource block that overlaps with the
  SS/PBCH block used by the UE for initial cell selection, expressed in units of resource blocks
  assuming 15 kHz subcarrier spacing for FR1 and 60 kHz for FR2:
  - without shared spectrum channel access, the lowest resource block has the subcarrier spacing
    given by `subCarrierSpacingCommon`;
  - with shared spectrum channel access, the lowest resource block has the same subcarrier
    spacing as the SS/PBCH block used for initial cell selection;
- `absoluteFrequencyPointA` for all other cases, expressed as an ARFCN.

> Sidelink's Point A (file 09 §8.2.7) is instead given directly by `sl-AbsoluteFrequencyPointA` —
> a single higher-layer parameter, not the PCell-downlink-vs-other-cases split above (sidelink
> has no "PCell downlink" concept of its own).

##### 4.4.4.3 Common resource blocks

Common resource blocks are numbered from 0 upward in the frequency domain for subcarrier spacing
configuration `µ`. The center of subcarrier 0 of common resource block 0 for subcarrier spacing
configuration `µ` coincides with 'point A'. The relation between the common resource block number
`n_CRB^µ` and resource elements `(k,l)` for subcarrier spacing configuration `µ` is given by

```
n_CRB^µ = floor( k / N_sc^RB )
```

where `k` is defined relative to point A such that `k=0` corresponds to the subcarrier centered
around point A.

##### 4.4.4.4 Physical resource blocks

Physical resource blocks for subcarrier spacing configuration `µ` are defined within a bandwidth
part and numbered from 0 to `N_BWP,i^size,µ − 1` where `i` is the bandwidth part number. The
relation between physical resource block `n_PRB^µ` in bandwidth part `i` and common resource
block `n_CRB^µ` is given by

```
n_CRB^µ = n_PRB^µ + N_BWP,i^start,µ
```

where `N_BWP,i^start,µ` is the common resource block where bandwidth part `i` starts relative to
common resource block 0.

##### 4.4.4.5 Virtual resource blocks

Virtual resource blocks are defined within a bandwidth part and numbered from 0 to
`N_BWP,i^size − 1` where `i` is the bandwidth part number.

##### 4.4.4.6 Interlaced resource blocks

Multiple interlaces of resource blocks are defined, where interlace `m ∈ {0,1,…,M−1}` consists of
common resource blocks `{m, M+m, 2M+m, 3M+m, …}`, with `M` the number of interlaces given by
Table 4.4.4.6-1. The relation between interlaced resource block `n_IRB,m^µ ∈ {0,1,…}` in
bandwidth part `i` and interlace `m`, and common resource block `n_CRB^µ`, is given by

```
n_CRB^µ = M · n_IRB,m^µ + N_BWP,i^start,µ + ((m − N_BWP,i^start,µ) mod M)
```

The UE expects that the number of common resource blocks in an interlace contained within
bandwidth part `i` is no less than 10.

**Table 4.4.4.6-1: The number of resource block interlaces**

| µ | M |
|---|---|
| 0 | 10 |
| 1 | 5 |

> **Not used by sidelink.** Interlaced resource blocks are an NR-U (unlicensed shared-spectrum)
> concept; nothing in TS 38.211 clause 8 (file 09) or the SL RRC IEs (file 04) references
> interlaced mapping. Included here only for clause-4 completeness.

### 4.4.5 Bandwidth part

A **bandwidth part** is a subset of contiguous common resource blocks defined in clause 4.4.4.3
for a given numerology `i` on a given carrier. The starting position `N_BWP,i^start,µ` and the
number of resource blocks `N_BWP,i^size,µ` in a bandwidth part shall fulfil

```
N_grid,x^start,µ ≤ N_BWP,i^start,µ < N_grid,x^start,µ + N_grid,x^size,µ
N_grid,x^start,µ < N_BWP,i^start,µ + N_BWP,i^size,µ ≤ N_grid,x^start,µ + N_grid,x^size,µ
```

Configuration of a bandwidth part is described in clause 12 of [5, TS 38.213].

A UE can be configured with up to four bandwidth parts in the downlink, with a single downlink
BWP active at a given time; the UE is not expected to receive PDSCH, PDCCH, or CSI-RS (except for
RRM) outside an active BWP. Symmetrically for the uplink (up to four BWPs, one active), plus up to
four more in a supplementary uplink if configured; the UE shall not transmit PUSCH or PUCCH
outside an active BWP, and shall not transmit SRS outside an active BWP for an active cell.

Unless otherwise noted, the description in this specification applies to each of the bandwidth
parts; when there is no risk of confusion, the index `µ` may be dropped from `N_BWP,i^start,µ`,
`N_BWP,i^size,µ`, `N_grid,x^start,µ`, and `N_grid,x^size,µ`.

> Sidelink has exactly one active bandwidth part (file 09 §8.2.8 defers configuration entirely to
> TS 38.213 clause 16, not to a multi-BWP scheme like this one) — the "up to four, one active"
> multi-BWP machinery above is a Uu-only concept.

### 4.5 Carrier aggregation

Transmissions in multiple cells can be aggregated. Unless otherwise noted, the description in
this specification applies to each of the serving cells.

For carrier aggregation of cells with unaligned frame boundaries, the slot offset
`N_slot,offset^CA` between a PCell/PSCell and an SCell is determined by the higher-layer parameter
`ca-SlotOffset` for the SCell. The quantity `µ_offset` is the maximum of the lowest subcarrier
spacing configuration among the subcarrier spacings given by `scs-SpecificCarrierList` for
PCell/PSCell and for the SCell, respectively. The slot offset `N_slot,offset^CA` fulfils:

- when the lowest subcarrier spacing configuration among the two cells is µ=2 for both or µ=3 for
  both, the start of slot 0 for the cell whose point A has the lower frequency coincides with the
  start of slot `q·N_slot,offset^CA mod N_slot^frame,µ_offset` for the other cell, where `q=−1` if
  point A of the PCell/PSCell has a lower frequency than point A of the SCell, otherwise `q=1`;
- otherwise, the start of slot 0 for the cell with the lower of the two cells' lowest subcarrier
  spacing configurations (or the PCell/PSCell if tied) coincides with the start of slot
  `q·N_slot,offset^CA mod N_slot^frame,µ_offset` for the other cell, where `q=−1` if the
  PCell/PSCell's lowest subcarrier spacing configuration is ≤ the SCell's, otherwise `q=1`.

> **Not applicable to this project.** Sidelink Mode-2 operates on a single configured resource
> pool per carrier; there is no carrier-aggregation concept in TS 38.211 clause 8, TS 38.213
> clause 16, or the SL RRC IEs (file 04). Included for clause-4 completeness only.

---

## Gaps in this extraction

### Everything in clause 4 is covered

All of clause 4 (§4.1–§4.5) is transcribed above, extracted from PDF/printed pages 11–16
(confirmed offset-0, i.e. printed page number = PDF page number, per file 09's cross-check
against page footers). Clause 4 begins partway down page 11 (after the tail of clause 3.3
Abbreviations) and clause 5 begins partway down page 16 — both boundaries were verified directly
against the extracted text, not assumed from the table of contents alone.

### No `2^n`-collapse bug found in this clause

File 09 documented a `pdftotext -layout` bug where superscripted exponents (`2^15`, `2^31`, etc.)
collapse onto the baseline as `215`, `231`. Clause 4 has few such exponents (`T_c`, `N_f`, and the
frame/subframe duration formulas use small integer constants like `10^3`, `100`, `1000`, `64`,
`2048`, `4096` — all of which appeared correctly as ordinary multiplied constants, not
superscripts, in the source PDF and in this extraction). No instance of the bug was found in this
clause. The repeated table quantities (`N_symb^slot`, `N_grid^size,µ`, etc.) are superscripts in
the *variable name*, not exponents in a numeric literal, and are unaffected by that bug family.

### Table/figure reconstruction notes

- **Tables 4.2-1, 4.3.2-1, 4.3.2-2, 4.3.2-3, 4.4.4.6-1** are all small (≤5 rows, ≤4 columns) and
  the flattened `-layout` text preserved column alignment correctly; reconstructed directly from
  the text, cross-checked against the numbers already known from file 09's Table 8.2.2-1 (which
  restates the µ∈{0,1,2,3} subset of Table 4.2-1) — no discrepancy.
- **Figure 4.3.1-1** (uplink-downlink timing relation) is a simple two-box timing diagram with one
  labelled offset, described in prose rather than reconstructed as an ASCII diagram — the
  underlying formula `T_TA = (N_TA + N_TA,offset)·T_c` it illustrates is already given verbatim in
  the surrounding text, same pattern as file 09's handling of Figure 8.5-1.

### One repeated paragraph collapsed to a single summary

§4.3.2 contains four almost-identical paragraphs (same-cell, same-group, DAPS-source, DAPS-target
half-duplex transition-time constraints) that differ only in which pair of cells the constraint
applies to; both `N_Rx-Tx` and `N_Tx-Rx` come from the same Table 4.3.2-3 in all four cases. These
were collapsed into one summary paragraph with a note, rather than repeated four times, to keep
the file navigable — this is a readability edit, not a content omission; nothing in the four
original paragraphs is normatively different from what full spelling-out would add for this
project.
