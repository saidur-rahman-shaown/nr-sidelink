# TS 38.211 §8 — Physical Channels and Signals for Sidelink

> **Source:** 3GPP TS 38.211 V16.10.0 (2022-06), Release 16 — *NR; Physical channels and modulation*
> **Scope:** the entirety of clause 8 ("Sidelink") — PSSCH/PSCCH/PSBCH/PSFCH channel processing
> (scrambling, modulation, mapping to resources), all sidelink reference/sync signals (DM-RS for
> PSSCH/PSCCH/PSBCH, PT-RS for PSSCH, CSI-RS, S-PSS, S-SSS), the S-SS/PSBCH block time-frequency
> structure, sidelink physical-resource definitions (numerology, antenna ports, resource grid),
> and sidelink timing.
> **Status:** verbatim spec extract, reformatted. Page headers/footers removed, PDF hard-wraps
> rejoined, clause numbers promoted to headings. Every table below was cross-checked against a
> rendered image of its source PDF page (not just the flattened `-layout` text) — see
> "Gaps in this extraction" at the end for the one place a figure, not a table, was simplified.
> **Known extraction bug fixed here:** `pdftotext -layout` collapses superscripted exponents onto
> the baseline digit run, so `2^15` came out of the raw extraction as the literal string `215`,
> `2^16` as `216`, `2^17` as `217`, `2^31` as `231`, `2^10` as `210`. Every `c_init` formula in
> this clause was re-verified against a rendered page image; all instances below are corrected to
> `2^15`, `2^16`, `2^17`, `2^31`, `2^10` as appropriate. This bug would otherwise silently corrupt
> every DM-RS/PSSCH/PSCCH/CSI-RS scrambling-sequence initialisation value in this file.

## Contents

- [8 Sidelink](#8-sidelink)
  - [8.1 Overview](#81-overview)
    - [8.1.1 Overview of physical channels](#811-overview-of-physical-channels)
    - [8.1.2 Overview of physical signals](#812-overview-of-physical-signals)
  - [8.2 Physical resources](#82-physical-resources)
    - [8.2.1 General](#821-general)
    - [8.2.2 Numerologies](#822-numerologies)
    - [8.2.3 Frame structure](#823-frame-structure)
      - [8.2.3.1 Frames and subframes](#8231-frames-and-subframes)
      - [8.2.3.2 Slots](#8232-slots)
    - [8.2.4 Antenna ports](#824-antenna-ports)
    - [8.2.5 Resource grid](#825-resource-grid)
    - [8.2.6 Resource elements](#826-resource-elements)
    - [8.2.7 Resource blocks](#827-resource-blocks)
    - [8.2.8 Bandwidth part](#828-bandwidth-part)
  - [8.3 Physical channels](#83-physical-channels)
    - [8.3.1 Physical sidelink shared channel](#831-physical-sidelink-shared-channel)
      - [8.3.1.1 Scrambling](#8311-scrambling)
      - [8.3.1.2 Modulation](#8312-modulation)
      - [8.3.1.3 Layer mapping](#8313-layer-mapping)
      - [8.3.1.4 Precoding](#8314-precoding)
      - [8.3.1.5 Mapping to virtual resource blocks](#8315-mapping-to-virtual-resource-blocks)
      - [8.3.1.6 Mapping from virtual to physical resource blocks](#8316-mapping-from-virtual-to-physical-resource-blocks)
    - [8.3.2 Physical sidelink control channel](#832-physical-sidelink-control-channel)
      - [8.3.2.1 Scrambling](#8321-scrambling)
      - [8.3.2.2 Modulation](#8322-modulation)
      - [8.3.2.3 Mapping to physical resources](#8323-mapping-to-physical-resources)
    - [8.3.3 Physical sidelink broadcast channel](#833-physical-sidelink-broadcast-channel)
      - [8.3.3.1 Scrambling](#8331-scrambling)
      - [8.3.3.2 Modulation](#8332-modulation)
      - [8.3.3.3 Mapping to physical resources](#8333-mapping-to-physical-resources)
    - [8.3.4 Physical sidelink feedback channel](#834-physical-sidelink-feedback-channel)
      - [8.3.4.1 General](#8341-general)
      - [8.3.4.2 PSFCH format 0](#8342-psfch-format-0)
        - [8.3.4.2.1 Sequence generation](#83421-sequence-generation)
        - [8.3.4.2.2 Mapping to physical resources](#83422-mapping-to-physical-resources)
  - [8.4 Physical signals](#84-physical-signals)
    - [8.4.1 Reference signals](#841-reference-signals)
      - [8.4.1.1 Demodulation reference signals for PSSCH](#8411-demodulation-reference-signals-for-pssch)
        - [8.4.1.1.1 Sequence generation](#84111-sequence-generation)
        - [8.4.1.1.2 Mapping to physical resources](#84112-mapping-to-physical-resources)
      - [8.4.1.2 Phase-tracking reference signals for PSSCH](#8412-phase-tracking-reference-signals-for-pssch)
        - [8.4.1.2.1 Sequence generation](#84121-sequence-generation)
        - [8.4.1.2.2 Mapping to physical resources](#84122-mapping-to-physical-resources)
      - [8.4.1.3 Demodulation reference signals for PSCCH](#8413-demodulation-reference-signals-for-pscch)
        - [8.4.1.3.1 Sequence generation](#84131-sequence-generation)
        - [8.4.1.3.2 Mapping to physical resources](#84132-mapping-to-physical-resources)
      - [8.4.1.4 Demodulation reference signals for PSBCH](#8414-demodulation-reference-signals-for-psbch)
        - [8.4.1.4.1 Sequence generation](#84141-sequence-generation)
        - [8.4.1.4.2 Mapping to physical resources](#84142-mapping-to-physical-resources)
      - [8.4.1.5 CSI reference signals](#8415-csi-reference-signals)
        - [8.4.1.5.1 General](#84151-general)
        - [8.4.1.5.2 Sequence generation](#84152-sequence-generation)
        - [8.4.1.5.3 Mapping to physical resources](#84153-mapping-to-physical-resources)
    - [8.4.2 Synchronization signals](#842-synchronization-signals)
      - [8.4.2.1 Physical-layer sidelink synchronization identities](#8421-physical-layer-sidelink-synchronization-identities)
      - [8.4.2.2 Sidelink primary synchronization signal](#8422-sidelink-primary-synchronization-signal)
        - [8.4.2.2.1 Sequence generation](#84221-sequence-generation)
        - [8.4.2.2.2 Mapping to physical resources](#84222-mapping-to-physical-resources)
      - [8.4.2.3 Sidelink secondary synchronization signal](#8423-sidelink-secondary-synchronization-signal)
        - [8.4.2.3.1 Sequence generation](#84231-sequence-generation)
        - [8.4.2.3.2 Mapping to physical resources](#84232-mapping-to-physical-resources)
    - [8.4.3 S-SS/PSBCH block](#843-s-sspsbch-block)
      - [8.4.3.1 Time-frequency structure of an S-SS/PSBCH block](#8431-time-frequency-structure-of-an-s-sspsbch-block)
        - [8.4.3.1.1 Mapping of S-PSS within an S-SS/PSBCH block](#84311-mapping-of-s-pss-within-an-s-sspsbch-block)
        - [8.4.3.1.2 Mapping of S-SSS within an S-SS/PSBCH block](#84312-mapping-of-s-sss-within-an-s-sspsbch-block)
        - [8.4.3.1.3 Mapping of PSBCH and DM-RS within an S-SS/PSBCH block](#84313-mapping-of-psbch-and-dm-rs-within-an-s-sspsbch-block)
      - [8.4.3.2 Time location of an S-SS/PSBCH block](#8432-time-location-of-an-s-sspsbch-block)
  - [8.5 Timing](#85-timing)
- [Gaps in this extraction](#gaps-in-this-extraction)

---

## 8 Sidelink

### 8.1 Overview

#### 8.1.1 Overview of physical channels

A sidelink physical channel corresponds to a set of resource elements carrying information
originating from higher layers. The following sidelink physical channels are defined:

- Physical Sidelink Shared Channel, PSSCH
- Physical Sidelink Broadcast Channel, PSBCH
- Physical Sidelink Control Channel, PSCCH
- Physical Sidelink Feedback Channel, PSFCH

#### 8.1.2 Overview of physical signals

A sidelink physical signal corresponds to a set of resource elements used by the physical layer
but does not carry information originating from higher layers.

The following sidelink physical signals are defined:

- Demodulation reference signals, DM-RS
- Channel-state information reference signal, CSI-RS
- Phase-tracking reference signals, PT-RS
- Sidelink primary synchronization signal, S-PSS
- Sidelink secondary synchronization signal, S-SSS

### 8.2 Physical resources

#### 8.2.1 General

The OFDM symbol immediately following the last symbol used for PSSCH, PSFCH, or S-SSB serves as
a guard symbol.

The first OFDM symbol of a PSSCH and its associated PSCCH is duplicated as described in clauses
8.3.1.5 and 8.3.2.3. The first OFDM symbol of a PSFCH is duplicated as described in clause
8.3.4.2.2.

> This is the entire normative content of the "guard symbol" and "duplicated first symbol"
> concept in clause 8 — see "Gaps in this extraction" for how this maps (and does not map) onto
> this project's `slAgcSymbol`/`slGuardSymbol` framing.

#### 8.2.2 Numerologies

Multiple OFDM numerologies are supported as given by Table 8.2.2-1 where µ and the cyclic prefix
for a sidelink bandwidth part are obtained from the higher-layer parameter `sl-BWP`.

**Table 8.2.2-1: Supported transmission numerologies**

| µ | Δf = 2^µ · 15 [kHz] | Cyclic prefix |
|---|---|---|
| 0 | 15 | Normal |
| 1 | 30 | Normal |
| 2 | 60 | Normal, Extended |
| 3 | 120 | Normal |

#### 8.2.3 Frame structure

##### 8.2.3.1 Frames and subframes

The frame and subframe structure for sidelink transmission is defined in clause 4.3.1.

##### 8.2.3.2 Slots

The slot structure for sidelink transmission is defined in clause 4.3.2.

#### 8.2.4 Antenna ports

An antenna port is defined in clause 4.4.1.

The following antenna ports are defined for the sidelink:

- Antenna ports starting with 1000 for PSSCH
- Antenna ports starting with 2000 for PSCCH
- Antenna ports starting with 3000 for CSI-RS
- Antenna ports starting with 4000 for S-SS/PSBCH
- Antenna ports starting with 5000 for PSFCH

For DM-RS associated with a PSBCH, the channel over which a PSBCH symbol on one antenna port is
conveyed can be inferred from the channel over which a DM-RS symbol on the same antenna port is
conveyed only if the two symbols are within a S-SS/PSBCH block transmitted within the same slot,
and with the same block index according to clause 8.4.3.1.

For DM-RS associated with a PSSCH, the channel over which a PSSCH symbol on one antenna port is
conveyed can be inferred from the channel over which a DM-RS symbol on the same antenna port is
conveyed only if the two symbols are within the same frequency resource as the scheduled PSSCH
and in the same slot.

For DM-RS associated with a PSCCH, the channel over which a PSCCH symbol on one antenna port is
conveyed can be inferred from the channel over which a DM-RS symbol on the same antenna port is
conveyed only if the two symbols are within the same frequency resource as the transmitted PSCCH
and in the same slot.

#### 8.2.5 Resource grid

The resource grid for sidelink transmission is defined in clause 4.4.2.

For sidelink, the carrier bandwidth 𝑁grid^size,µ and the starting position 𝑁grid^start,µ for
subcarrier spacing configuration µ are obtained from the higher-layer parameter
`sl-SCS-SpecificCarrierList`.

For the sidelink, the higher-layer parameter `sl-TxDirectCurrentLocation` indicates the location
of the transmitter DC subcarrier in the sidelink for each of the configured bandwidth parts.
Values in the range 0–3299 represent the number of the DC subcarrier, the value 3300 indicates
that the DC subcarrier is located outside the resource grid, and the value 3301 indicates that
the position of the DC subcarrier in the sidelink is undetermined. The DC subcarrier location
offset relative to the center of the indicated subcarrier is given by 7.5 + 5𝑁 kHz if
`frequencyShift7p5khzSL` is provided and by 5𝑁 kHz otherwise, where 𝑁 ∈ {−1,0,1} is given by the
higher-layer parameter `valueN`.

#### 8.2.6 Resource elements

Resource elements are defined in clause 4.4.3.

#### 8.2.7 Resource blocks

Resource blocks are defined in clause 4.4.4.

Point A for sidelink transmission/reception is obtained from the higher-layer parameter
`sl-AbsoluteFrequencyPointA`.

#### 8.2.8 Bandwidth part

Configuration of the single bandwidth part for sidelink transmission is described in clause 16 of
[5, TS 38.213].

### 8.3 Physical channels

#### 8.3.1 Physical sidelink shared channel

##### 8.3.1.1 Scrambling

For the single codeword 𝑞 = 0, the block of bits 𝑏^(𝑞)(0), … , 𝑏^(𝑞)(𝑀bit^(𝑞) − 1), where
𝑀bit^(𝑞) = 𝑀bit,SCI2^(𝑞) + 𝑀bit,data^(𝑞) is the number of bits in codeword 𝑞 transmitted on the
physical channel as defined in [4, TS 38.212], shall be scrambled prior to modulation.

Scrambling shall be done according to the following pseudo code:

```
set i = 0
set j = 0

while i < M_bit^(q)

    if b^(q)(i) = x                          // SCI placeholder bits

        b~^(q)(i) = b~^(q)(i − 2)
        j = j + 1

    else

        b~^(q)(i) = ( b^(q)(i) + c^(q)( i − M~_i,j^(q) ) ) mod 2

    end if

    i = i + 1

end while
```

where the scrambling sequence 𝑐^(𝑞)(𝑖) is given by clause 5.2.1 and

- for 0 ≤ 𝑖 < 𝑀bit,SCI2^(𝑞)
  - 𝑀~_i,j^(𝑞) = 𝑗
  - The scrambling sequence generator shall be initialized with

    𝑐init = 2^15 · 𝑁ID + 1010

    where 𝑁ID = 𝑁ID^X mod 2^16 and the quantity 𝑁ID^X equals the decimal representation of the
    CRC on the PSCCH associated with the PSSCH according to 𝑁ID^X = ∑_{𝑖=0}^{𝐿−1} 𝑝_𝑖 · 2^(𝐿−1−𝑖)
    with 𝑝 and 𝐿 given by clause 8.3.2 in [4, TS 38.212].

- for 𝑀bit,SCI2^(𝑞) ≤ 𝑖 < 𝑀bit^(𝑞)
  - 𝑀~_i,j^(𝑞) = 𝑀bit,SCI2^(𝑞)
  - The scrambling sequence generator shall be initialized with

    𝑐init = 2^15 · 𝑁ID + 1010

    where 𝑁ID = 𝑁ID^X mod 2^16 and the quantity 𝑁ID^X equals the decimal representation of the
    CRC on the PSCCH associated with the PSSCH according to 𝑁ID^X = ∑_{𝑖=0}^{𝐿−1} 𝑝_𝑖 · 2^(𝐿−1−𝑖)
    with 𝑝 and 𝐿 given by clause 8.3.2 in [4, TS 38.212].

##### 8.3.1.2 Modulation

For the single codeword 𝑞 = 0, the block of scrambled bits shall be modulated, resulting in a
block of complex-valued modulation symbols 𝑑^(𝑞)(0), … , 𝑑^(𝑞)(𝑀symb^(𝑞) − 1) where
𝑀symb^(𝑞) = 𝑀symb,1^(𝑞) + 𝑀symb,2^(𝑞).

Modulation for 0 ≤ 𝑖 < 𝑀bit,SCI2^(𝑞) shall be done as described in clause 5.1 using QPSK, where
𝑀symb,1^(𝑞) = 𝑀bit,SCI2^(𝑞) ⁄ 2.

Modulation for 𝑀bit,SCI2^(𝑞) ≤ 𝑖 < 𝑀bit^(𝑞) shall be done as described in clause 5.1 using one of
the modulation schemes in Table 8.3.1.2-1 where 𝑀symb,2^(𝑞) = 𝑀bit,data^(𝑞) ⁄ 𝑄m.

**Table 8.3.1.2-1: Supported modulation schemes**

| Modulation scheme | Modulation order 𝑄m |
|---|---|
| QPSK | 2 |
| 16QAM | 4 |
| 64QAM | 6 |
| 256QAM | 8 |

##### 8.3.1.3 Layer mapping

Layer mapping shall be done according to clause 7.3.1.3 with the number of layers 𝜐 ∈ {1,2},
resulting in 𝑥(𝑖) = [𝑥^(0)(𝑖) … 𝑥^(𝜐−1)(𝑖)]^T, 𝑖 = 0,1, … , 𝑀symb^layer − 1.

##### 8.3.1.4 Precoding

The block of vectors [𝑥^(0)(𝑖) … 𝑥^(𝜐−1)(𝑖)]^T shall be precoded according to clause 6.3.1.5
where the precoding matrix 𝑊 equals the identity matrix and 𝑀symb^ap = 𝑀symb^layer.

##### 8.3.1.5 Mapping to virtual resource blocks

For each of the antenna ports used for transmission of the PSSCH, the block of complex-valued
symbols 𝑧^(𝑝)(0), … , 𝑧^(𝑝)(𝑀symb^ap − 1) shall be multiplied with the amplitude scaling factor
𝛽DMRS^PSSCH in order to conform to the transmit power specified in [5, TS 38.213] and mapped to
resource elements (𝑘′, 𝑙)_{𝑝,𝜇} in the virtual resource blocks assigned for transmission, where
𝑘′ = 0 is the first subcarrier in the lowest-numbered virtual resource block assigned for
transmission.

The mapping operation shall be done in two steps:

- first, the complex-valued symbols corresponding to the bit for the 2nd-stage SCI in increasing
  order of first the index 𝑘′ over the assigned virtual resource blocks and then the index 𝑙,
  starting from the first PSSCH symbol carrying an associated DM-RS and meeting all of the
  following criteria:
  - the corresponding resource elements in the corresponding physical resource blocks are not
    used for transmission of the associated DM-RS, PT-RS, or PSCCH;
- secondly, the complex-valued modulation symbols not corresponding to the 2nd-stage SCI shall be
  in increasing order of first the index 𝑘′ over the assigned virtual resource blocks, and then
  the index 𝑙 with the starting position given by [6, TS 38.214] and meeting all of the following
  criteria:
  - the resource elements are not used for 2nd-stage SCI in the first step;
  - the corresponding resource elements in the corresponding physical resource blocks are not
    used for transmission of the associated DM-RS, PT-RS, CSI-RS, or PSCCH.

The resource elements used for the PSSCH in the first OFDM symbol in the mapping operation above,
including any DM-RS, PT-RS, or CSI-RS occurring in the first OFDM symbol, **shall be duplicated
in the OFDM symbol immediately preceding the first OFDM symbol in the mapping.**

> This is the normative source of "the AGC symbol duplicates the following symbol" for
> PSSCH/PSCCH: the duplicate is written into the symbol *before* the first real content symbol,
> copying the content *from* that first real symbol. See "Gaps in this extraction" for the
> cross-check against this project's `+phy` assumptions.

##### 8.3.1.6 Mapping from virtual to physical resource blocks

Virtual resource blocks shall be mapped to physical resource blocks according to non-interleaved
mapping.

For non-interleaved VRB-to-PRB mapping, virtual resource block 𝑛 is mapped to physical resource
block 𝑛.

#### 8.3.2 Physical sidelink control channel

##### 8.3.2.1 Scrambling

The block of bits 𝑏(0), … , 𝑏(𝑀bit − 1), where 𝑀bit is the number of bits transmitted on the
physical channel, shall be scrambled prior to modulation, resulting in a block of scrambled bits
𝑏̃(0), … , 𝑏̃(𝑀bit − 1) according to

    𝑏̃(𝑖) = (𝑏(𝑖) + 𝑐(𝑖)) mod 2

where the scrambling sequence 𝑐(𝑖) is given by clause 5.2.1. The scrambling sequence generator
shall be initialized with

    𝑐init = 1010

##### 8.3.2.2 Modulation

The block of scrambled bits 𝑏̃(0), … , 𝑏̃(𝑀bit − 1) shall be modulated as described in clause 5.1
using QPSK, resulting in a block of complex-valued modulation symbols 𝑑(0), … , 𝑑(𝑀symb − 1)
where 𝑀symb = 𝑀bit ⁄ 2.

##### 8.3.2.3 Mapping to physical resources

The set of complex-valued modulation symbols 𝑑(0), … , 𝑑(𝑀symb − 1) shall be multiplied with the
amplitude scaling factor 𝛽DMRS^PSCCH in order to conform to the transmit power specified in
[5, TS 38.213] and mapped in sequence starting with 𝑑(0) to resource elements (𝑘, 𝑙)_{𝑝,𝜇}
assigned for transmission according to clause 16.4 of [5, TS 38.213], and not used for the
demodulation reference signals associated with PSCCH, in increasing order of first the index 𝑘
over the assigned physical resources, and then the index 𝑙 on antenna port 𝑝 = 2000.

The resource elements used for the PSCCH in the first OFDM symbol in the mapping operation above,
including any DM-RS, PT-RS, or CSI-RS occurring in the first OFDM symbol, **shall be duplicated
in the immediately preceding OFDM symbol.**

#### 8.3.3 Physical sidelink broadcast channel

##### 8.3.3.1 Scrambling

The block of bits 𝑏(0), … , 𝑏(𝑀bit − 1), where 𝑀bit is the number of bits transmitted on the
physical sidelink broadcast channel, shall be scrambled prior to modulation, resulting in a block
of scrambled bits 𝑏̃(0), … , 𝑏̃(𝑀bit − 1) according to

    𝑏̃(𝑖) = (𝑏(𝑖) + 𝑐(𝑖)) mod 2

where the scrambling sequence 𝑐(𝑖) is given by clause 5.2.1. The scrambling sequence generator
shall be initialized with 𝑐init = 𝑁ID^SL at the start of each S-SS/PSBCH block.

##### 8.3.3.2 Modulation

The block of bits 𝑏̃(0), … , 𝑏̃(𝑀bit − 1) shall be QPSK modulated as described in clause 5.1.3,
resulting in a block of complex-valued modulation symbols 𝑑PSBCH(0), … , 𝑑PSBCH(𝑀symb − 1) where
𝑀symb = 𝑀bit ⁄ 2.

##### 8.3.3.3 Mapping to physical resources

Mapping to physical resources is described in clause 8.4.3.

#### 8.3.4 Physical sidelink feedback channel

##### 8.3.4.1 General

*(This subclause has a heading only in the source — no body text.)*

##### 8.3.4.2 PSFCH format 0

###### 8.3.4.2.1 Sequence generation

The sequence 𝑥(𝑛) shall be generated according to

    𝑥(𝑛) = 𝑟_{𝑢,𝑣}^{𝛼,𝛿}(𝑛)
    𝑛 = 0,1, … , 𝑁scRB − 1

where 𝑟_{𝑢,𝑣}^{(𝛼,𝛿)}(𝑛) is given by clause 6.3.2.2 with the following exceptions:

- 𝑚cs is given by clause 16.3 of [5, TS 38.213];
- 𝑚0 is given by clause 16.3 of [5, TS 38.213];
- 𝑙 = 0;
- 𝑙′ is the index of the OFDM symbol in the slot that corresponds to the second OFDM symbol of
  the PSFCH transmission in the slot given by [5, TS 38.213];
- 𝑢 = 𝑛ID mod 30 and 𝑣 = 0 with 𝑛ID given by the higher-layer parameter `sl-PSFCH-HopID` if
  configured; otherwise, 𝑢 = 0.
- 𝑐init = 𝑛ID with 𝑛ID given by the higher-layer parameter `sl-PSFCH-HopID` if configured;
  otherwise, 𝑐init = 0.

###### 8.3.4.2.2 Mapping to physical resources

The sequence 𝑥(𝑛) shall be multiplied with the amplitude scaling factor 𝛽PSFCH in order to
conform to the transmit power specified in [5, TS 38.213] and mapped in sequence starting with
𝑥(0) to resource elements (𝑘, 𝑙)_{𝑝,𝜇} assigned for transmission of the second PSFCH symbol
according to clause 16.3 of [5, TS 38.213] in increasing order of the index 𝑘 over the assigned
physical resources on antenna port 𝑝 = 5000.

The resource elements used for the PSFCH in the OFDM symbol in the mapping operation above
**shall be duplicated in the immediately preceding OFDM symbol.**

> Note the direction: the PSFCH's *first* symbol duplicates its *second* (content-carrying)
> symbol — an AGC-role duplicate specific to PSFCH, not a "guard" symbol. See "Gaps in this
> extraction" for how this interacts with the guard-symbol definition in §8.2.1.

### 8.4 Physical signals

#### 8.4.1 Reference signals

##### 8.4.1.1 Demodulation reference signals for PSSCH

###### 8.4.1.1.1 Sequence generation

The sequence 𝑟_𝑙(𝑚) shall be generated according to

    𝑟_𝑙(𝑚) = (1/√2)(1 − 2𝑐(2𝑚)) + 𝑗(1/√2)(1 − 2𝑐(2𝑚 + 1))

where the pseudo-random sequence 𝑐(𝑚) is defined in clause 5.2.1. The pseudo-random sequence
generator shall be initialized with

    𝑐init = ( 2^17 · (𝑁symb^slot · 𝑛_{s,f}^𝜇 + 𝑙 + 1) · (2𝑁ID + 1) + 2𝑁ID ) mod 2^31

where 𝑙 is the OFDM symbol number within the slot, 𝑛_{s,f}^𝜇 is the slot number within a frame,
and 𝑁ID = 𝑁ID^X mod 2^16 where the quantity 𝑁ID^X equals the decimal representation of CRC on
the PSCCH associated with the PSSCH according to 𝑁ID^X = ∑_{𝑖=0}^{𝐿−1} 𝑝_𝑖 · 2^(𝐿−1−𝑖) with 𝑝
and 𝐿 given by clause 7.3.2 in [4, TS 38.212].

###### 8.4.1.1.2 Mapping to physical resources

The sequence 𝑟(𝑚) shall be mapped to the intermediate quantity 𝑎̃_{𝑘,𝑙}^(𝑝̃_𝑗,𝜇) according to
clause 6.4.1.1.3 using configuration type 1 without transform precoding, and where 𝑤f(𝑘′),
𝑤t(𝑙′), and Δ are given by Table 8.4.1.1.2-2, and 𝑟(𝑚) is specified in clause 8.4.1.1.1.

The patterns used for the PSSCH DM-RS is indicated in the SCI as described in clause 8.3.1.1 of
[4, TS 38.212].

The intermediate quantity 𝑎̃_{𝑘,𝑙}^(𝑝̃_𝑗,𝜇) shall be precoded, multiplied with the amplitude
scaling factor 𝛽DMRS^PSSCH specified in clause 8.3.1.5, and mapped to physical resources
according to

```
⌈ a_{k,l}^(p_0,μ)   ⌉               ⌈ a~_{k,l}^(p~_0,μ)   ⌉
|      ⋮            | = β_DMRS^PSSCH·W· |       ⋮              |
⌊ a_{k,l}^(p_{ρ−1},μ)⌋               ⌊ a~_{k,l}^(p~_{υ−1},μ)⌋
```

where

- the precoding matrix 𝑊 is given by clause 8.3.1.4,
- the set of antenna ports {𝑝0, … , 𝑝𝜌−1} is given by clause 8.3.1.4, and
- the set of antenna ports {𝑝̃0, … , 𝑝̃𝜐−1} is given by [6, TS 38.214];

and the following conditions are fulfilled:

- the resource elements 𝑎̃_{𝑘,𝑙}^(𝑝̃_𝑗,𝜇) are within the common resource blocks allocated for
  PSSCH transmission.

The quantity 𝑘 is defined relative to subcarrier 0 in common resource block 0 and the quantity 𝑙
is defined relative to the start of the scheduled resources for transmission of PSSCH and the
associated PSCCH, including the OFDM symbol duplicated as described in clauses 8.3.1.5 and
8.3.2.3.

The position(s) of the DM-RS symbols is given by 𝑙̅ according to Table 8.4.1.1.2-1 where the
number of PSSCH DM-RS is indicated in the SCI, and 𝑙d is the duration of the scheduled resources
for transmission of PSSCH and the associated PSCCH, including the OFDM symbol duplicated as
described in clauses 8.3.1.5 and 8.3.2.3.

**Table 8.4.1.1.2-1: PSSCH DM-RS time-domain location**

*(Verified against the rendered PDF page — see `page124-124.png` cross-check. `𝑙̅` values are
symbol indices within the scheduled PSSCH+PSCCH duration `𝑙d`, relative to the start of that
duration, i.e. symbol 0 is the duplicated first symbol.)*

| 𝑙d (symbols) | PSCCH dur. 2 sym, DM-RS=2 | PSCCH dur. 2 sym, DM-RS=3 | PSCCH dur. 2 sym, DM-RS=4 | PSCCH dur. 3 sym, DM-RS=2 | PSCCH dur. 3 sym, DM-RS=3 | PSCCH dur. 3 sym, DM-RS=4 |
|---|---|---|---|---|---|---|
| 6  | 1, 5   |          |              | 1, 5   |          |              |
| 7  | 1, 5   |          |              | 1, 5   |          |              |
| 8  | 1, 5   |          |              | 1, 5   |          |              |
| 9  | 3, 8   | 1, 4, 7  |              | 4, 8   | 1, 4, 7  |              |
| 10 | 3, 8   | 1, 4, 7  |              | 4, 8   | 1, 4, 7  |              |
| 11 | 3, 10  | 1, 5, 9  | 1, 4, 7, 10  | 4, 10  | 1, 5, 9  | 1, 4, 7, 10  |
| 12 | 3, 10  | 1, 5, 9  | 1, 4, 7, 10  | 4, 10  | 1, 5, 9  | 1, 4, 7, 10  |
| 13 | 3, 10  | 1, 6, 11 | 1, 4, 7, 10  | 4, 10  | 1, 6, 11 | 1, 4, 7, 10  |

**Table 8.4.1.1.2-2: Parameters for PSSCH DM-RS**

| 𝑝 | CDM group 𝜆 | Δ | 𝑤f(𝑘′), 𝑘′=0 | 𝑤f(𝑘′), 𝑘′=1 | 𝑤t(𝑙′), 𝑙′=0 |
|---|---|---|---|---|---|
| 1000 | 0 | 0 | +1 | +1 | +1 |
| 1001 | 0 | 0 | +1 | −1 | +1 |

##### 8.4.1.2 Phase-tracking reference signals for PSSCH

###### 8.4.1.2.1 Sequence generation

The precoded sidelink phase-tracking reference signal for subcarrier 𝑘 on layer 𝑗 is given by

```
r^(p~_j)(m) = { r(m)   if j = j′ or j = j″
              { 0      otherwise
```

where

- antenna ports 𝑝̃_{𝑗′} or {𝑝̃_{𝑗′}, 𝑝̃_{𝑗″}} associated with PT-RS transmission are given by
  clause 8.2.3 of [6, TS 38.214];
- 𝑟(𝑚) is given by clause 8.4.1.1.1 at the position of the first PSSCH symbol carrying an
  associated DM-RS.

###### 8.4.1.2.2 Mapping to physical resources

The UE shall transmit phase-tracking reference signals only in the resource blocks used for the
PSSCH, and only if the procedure in [6, TS 38.214] indicates that phase-tracking reference
signals are being used.

The PSSCH PT-RS shall be mapped to resource elements according to

```
⌈ a_{k,l0}^(p_0,μ)   ⌉                    ⌈ r^(p~_0)(2n + k′)     ⌉
|      ⋮             | = β_DMRS^PSSCH·W· |          ⋮              |
⌊ a_{k,lρ−1}^(p_{ρ−1},μ)⌋                 ⌊ r^(p~_{υ−1})(2n + k′) ⌋

k = 4n + 2k′ + Δ
```

when all the following conditions are fulfilled

- 𝑙 is within the OFDM symbols allocated for the PSSCH transmission;
- resource element (𝑘, 𝑙) is not used for PSCCH, nor DM-RS associated with PSSCH;
- 𝑘′ and Δ correspond to 𝑝̃0, … , 𝑝̃𝜐−1

The precoding matrix 𝑊 is given by clause 8.3.1.4.

The set of time indices 𝑙 defined relative to the start of the PSSCH allocation is defined by

1. set 𝑖 = 0 and 𝑙ref = 0
2. if any symbol in the interval max(𝑙ref + (𝑖 − 1)𝐿PT-RS + 1, 𝑙ref), … , 𝑙ref + 𝑖𝐿PT-RS overlaps
   with a symbol used for DM-RS according to clause 8.4.1.1.2
   - set 𝑖 = 1
   - set 𝑙ref to the symbol index of the DM-RS symbol
   - repeat from step 2 as long as 𝑙ref + 𝑖𝐿PT-RS is inside the PSSCH allocation
3. add 𝑙ref + 𝑖𝐿PT-RS to the set of time indices for PT-RS
4. increment 𝑖 by one
5. repeat from step 2 above as long as 𝑙ref + 𝑖𝐿PT-RS is inside the PSSCH allocation

where 𝐿PT-RS ∈ {1,2,4} is given by clause 8.4.3 of [6, TS 38.214].

For the purpose of PT-RS mapping, the resource blocks allocated for PSSCH transmission are
numbered from 0 to 𝑁RB − 1 from the lowest scheduled resource block to the highest. The
corresponding subcarriers in this set of resource blocks are numbered in increasing order
starting from the lowest frequency from 0 to 𝑁scRB·𝑁RB − 1. The subcarriers to which the PT-RS
shall be mapped are given by

    𝑘 = 𝑘ref^RE + (𝑖·𝐾PT-RS + 𝑘ref^RB) · 𝑁scRB

    𝑘ref^RB = { 𝑁ID mod 𝐾PT-RS                  if 𝑁RB mod 𝐾PT-RS = 0
              { 𝑁ID mod (𝑁RB mod 𝐾PT-RS)         otherwise

where

- 𝑖 = 0,1,2, …
- 𝑘ref^RE is given by Table 8.4.1.2.2-1 for the DM-RS port associated with the PT-RS port
  according to clause 8.2.3 in [6, TS 38.214].
- 𝑁RB is the number of resource blocks scheduled;
- 𝐾PT-RS ∈ {2,4} is given by [6, TS 38.214];
- 𝑁ID = 𝑁ID^X mod 2^16 where the quantity 𝑁ID^X equals the decimal representation of CRC on the
  PSCCH associated with the PSSCH according to 𝑁ID^X = ∑_{𝑖=0}^{𝐿−1} 𝑝_𝑖 · 2^(𝐿−1−𝑖) with 𝑝 and
  𝐿 given by clause 7.3.2 in [4, TS 38.212].

PSSCH PT-RS shall not be mapped to resource elements containing PSCCH or PSCCH DMRS by puncturing
PSSCH PT-RS.

A UE is not expected to receive sidelink CSI-RS and PSSCH PT-RS on the same resource elements.

**Table 8.4.1.2.2-1: The parameter 𝑘ref^RE**

| DM-RS antenna port 𝑝̃ | offset00 | offset01 | offset10 | offset11 |
|---|---|---|---|---|
| 0 | 0 | 2 | 6 | 8 |
| 1 | 2 | 4 | 8 | 10 |

*(Column headers are the four values of the higher-layer parameter `resourceElementOffset`.)*

##### 8.4.1.3 Demodulation reference signals for PSCCH

###### 8.4.1.3.1 Sequence generation

The sequence 𝑟_𝑙(𝑚) shall be generated according to

    𝑟_𝑙(𝑚) = (1/√2)(1 − 2𝑐(2𝑚)) + 𝑗(1/√2)(1 − 2𝑐(2𝑚 + 1))

where the pseudo-random sequence 𝑐(𝑚) is defined in clause 5.2.1. The pseudo-random sequence
generator shall be initialized with

    𝑐init = ( 2^17 · (𝑁symb^slot · 𝑛_{s,f}^𝜇 + 𝑙 + 1) · (2𝑁ID + 1) + 2𝑁ID ) mod 2^31

where

- 𝑙 is the OFDM symbol number within the slot,
- 𝑛_{s,f}^𝜇 is the slot number within a frame, and
- 𝑁ID ∈ {0,1, … ,65535} is given by the higher-layer parameter `sl-DMRS-ScrambleID`.

###### 8.4.1.3.2 Mapping to physical resources

The sequence 𝑟_𝑙(𝑚) shall be multiplied with the amplitude scaling factor 𝛽DMRS^PSCCH in order
to conform to the transmit power specified in [5, 38.213] and mapped in sequence starting with
𝑟_𝑙(0) to resource elements (𝑘, 𝑙)_{𝑝,𝜇} in a slot on antenna port 𝑝 = 2000 according to

    𝑎_{𝑘,𝑙}^(𝑝,𝜇) = 𝛽DMRS^PSCCH · 𝑤_{f,𝑖}(𝑘′) · 𝑟_𝑙(3𝑛 + 𝑘′)
    𝑘 = 𝑛𝑁scRB + 4𝑘′ + 1
    𝑘′ = 0,1,2
    𝑛 = 0,1, …

where the following conditions are fulfilled

- they are within the resource elements constituting the PSCCH

The quantity 𝑤_{f,𝑖}(𝑘′) is given by Table 8.4.1.3.2-1 and 𝑖 ∈ {0,1,2} shall be randomly selected
by the UE.

The reference point for 𝑘 is subcarrier 0 in common resource block 0.

The quantity 𝑙 is the OFDM symbol number within the slot.

**Table 8.4.1.3.2-1: The quantity 𝑤_{f,𝑖}(𝑘′)**

| 𝑘′ | 𝑖=0 | 𝑖=1 | 𝑖=2 |
|---|---|---|---|
| 0 | 1 | 1 | 1 |
| 1 | 1 | e^(j2π/3) | e^(−j2π/3) |
| 2 | 1 | e^(−j2π/3) | e^(j2π/3) |

##### 8.4.1.4 Demodulation reference signals for PSBCH

###### 8.4.1.4.1 Sequence generation

The reference-signal sequence 𝑟(𝑚) for an S-SS/PSBCH block is defined by

    𝑟(𝑚) = (1/√2)(1 − 2𝑐(2𝑚)) + 𝑗(1/√2)(1 − 2𝑐(2𝑚 + 1))

where 𝑐(𝑛) is given by clause 5.2. The scrambling sequence generator shall be initialized at the
start of each S-SS/PSBCH block occasion with

    𝑐init = 𝑁ID^SL

###### 8.4.1.4.2 Mapping to physical resources

Mapping to physical resources is described in clause 8.4.3.

##### 8.4.1.5 CSI reference signals

###### 8.4.1.5.1 General

*(This subclause has a heading only in the source — no body text.)*

###### 8.4.1.5.2 Sequence generation

The sequence 𝑟(𝑚) shall be generated according to

    𝑟(𝑚) = (1/√2)(1 − 2𝑐(2𝑚)) + 𝑗(1/√2)(1 − 2𝑐(2𝑚 + 1))

where the pseudo-random sequence 𝑐(𝑖) is defined in clause 5.2.1. The pseudo-random sequence
generator shall be initialised with

    𝑐init = ( 2^10 · (𝑁symb^slot · 𝑛_{s,f}^𝜇 + 𝑙 + 1) · (2𝑛ID + 1) + 𝑛ID ) mod 2^31

at the start of each OFDM symbol where 𝑛_{s,f}^𝜇 is the slot number within a radio frame, 𝑙 is
the OFDM symbol number within a slot, and 𝑛ID = 𝑁ID^X mod 2^10 where the quantity 𝑁ID^X equals
the decimal representation of CRC for the sidelink control information mapped to the PSCCH
associated with the CSI-RS according to 𝑁ID^X = ∑_{𝑖=0}^{𝐿−1} 𝑝_𝑖 · 2^(𝐿−1−𝑖) with 𝑝 and 𝐿 given
by clause 7.3.2 in [4, TS 38.212].

###### 8.4.1.5.3 Mapping to physical resources

Mapping to resource elements shall be done according to clause 7.4.1.5.3 with the following
exceptions:

- only 1 and 2 antenna ports are supported, 𝑋 ∈ {1,2};
- only density 𝜌 = 1 is supported;
- zero-power CSI-RS is not supported;
- the quantity 𝛽CSIRS is an amplitude scaling factor to conform with the transmit power specified
  in clause 8.2.1 of [6, TS 38.214].

#### 8.4.2 Synchronization signals

##### 8.4.2.1 Physical-layer sidelink synchronization identities

There are 672 unique physical-layer sidelink synchronization identities given by

    𝑁ID^SL = 𝑁ID,1^SL + 336·𝑁ID,2^SL

where 𝑁ID,1^SL ∈ {0,1, … ,335} and 𝑁ID,2^SL ∈ {0,1}. The sidelink synchronization identities are
divided into two sets, **id_net** consisting of 𝑁ID^SL = 0,1, … ,335 and **id_oon** consisting of
𝑁ID^SL = 336,337, … ,671.

##### 8.4.2.2 Sidelink primary synchronization signal

###### 8.4.2.2.1 Sequence generation

The sequence 𝑑S-PSS(𝑛) for the sidelink primary synchronization signal is defined by

    𝑑S-PSS(𝑛) = 1 − 2𝑥(𝑚)
    𝑚 = (𝑛 + 22 + 43·𝑁ID,2^SL) mod 127
    0 ≤ 𝑛 < 127

where

    𝑥(𝑖 + 7) = (𝑥(𝑖 + 4) + 𝑥(𝑖)) mod 2

and

    [𝑥(6)  𝑥(5)  𝑥(4)  𝑥(3)  𝑥(2)  𝑥(1)  𝑥(0)] = [1  1  1  0  1  1  0]

> **This is a single m-sequence `x(i)`** (one generator polynomial, one 7-bit initial state
> `1110110`), read out at a cyclic shift of `22 + 43·N_ID,2^SL`. Since `N_ID,2^SL ∈ {0,1}`, the
> two possible shifts are exactly **22** (when `N_ID,2^SL = 0`) and **65** (when `N_ID,2^SL = 1`,
> since `22 + 43 = 65`). There is no second base sequence, no second polynomial, and no second
> initial state anywhere in this subclause — see "Gaps in this extraction" for the direct
> cross-check against this project's `slSPSS` assumption.

###### 8.4.2.2.2 Mapping to physical resources

Mapping to physical resources is described in clause 8.4.3.

##### 8.4.2.3 Sidelink secondary synchronization signal

###### 8.4.2.3.1 Sequence generation

The sequence 𝑑S-SSS(𝑛) for the sidelink secondary synchronization signal is defined by

    𝑑S-SSS(𝑛) = [1 − 2𝑥0((𝑛 + 𝑚0) mod 127)] · [1 − 2𝑥1((𝑛 + 𝑚1) mod 127)]
    𝑚0 = 15·⌊𝑁ID,1^SL / 112⌋ + 5·𝑁ID,2^SL
    𝑚1 = 𝑁ID,1^SL mod 112
    0 ≤ 𝑛 < 127

where

    𝑥0(𝑖 + 7) = (𝑥0(𝑖 + 4) + 𝑥0(𝑖)) mod 2
    𝑥1(𝑖 + 7) = (𝑥1(𝑖 + 1) + 𝑥1(𝑖)) mod 2

and

    [𝑥0(6) 𝑥0(5) 𝑥0(4) 𝑥0(3) 𝑥0(2) 𝑥0(1) 𝑥0(0)] = [0 0 0 0 0 0 1]
    [𝑥1(6) 𝑥1(5) 𝑥1(4) 𝑥1(3) 𝑥1(2) 𝑥1(1) 𝑥1(0)] = [0 0 0 0 0 0 1]

> **This is a product of two *different* m-sequences** — `x0` (taps at positions 4 and 0) and
> `x1` (taps at positions 1 and 0) are two distinct generator polynomials, each cyclically
> shifted independently (`m0` derived from both `N_ID,1^SL` and `N_ID,2^SL`; `m1` from
> `N_ID,1^SL` alone). This is structurally the same construction as the Uu SSS in clause
> 7.4.2.3.1 of this spec (product of two shifted length-127 m-sequences), not the Gold-sequence
> generator of clause 5.2.1 used for scrambling everywhere else in clause 8. "Gold-derived" as a
> one-line description is not wrong in spirit but is imprecise — see "Gaps in this extraction".

###### 8.4.2.3.2 Mapping to physical resources

Mapping to physical resources is described in clause 8.4.3.

#### 8.4.3 S-SS/PSBCH block

##### 8.4.3.1 Time-frequency structure of an S-SS/PSBCH block

In the time domain, an S-SS/PSBCH block consists of 𝑁symb^S-SSB OFDM symbols, numbered in
increasing order from 0 to 𝑁symb^S-SSB − 1 within the S-SS/PSBCH block, where S-PSS, S-SSS, and
PSBCH with associated DM-RS are mapped to symbols as given by Table 8.4.3.1-1. The number of
OFDM symbols in an S-SS/PSBCH block 𝑁symb^S-SSB = 13 for normal cyclic prefix and
𝑁symb^S-SSB = 11 for extended cyclic prefix. The first OFDM symbol in an S-SS/PSBCH block is the
first OFDM symbol in the slot.

In the frequency domain, an S-SS/PSBCH block consists of 132 contiguous subcarriers with the
subcarriers numbered in increasing order from 0 to 131 within the sidelink S-SS/PSBCH block. The
quantities 𝑘 and 𝑙 represent the frequency and time indices, respectively, within one sidelink
S-SS/PSBCH block.

For an S-SS/PSBCH block, the UE shall use

- antenna port 4000 for transmission of S-PSS, S-SSS, PSBCH and DM-RS for PSBCH;
- the same cyclic prefix length and subcarrier spacing for the S-PSS, S-SSS, PSBCH and DM-RS for
  PSBCH,

**Table 8.4.3.1-1: Resources within an S-SS/PSBCH block for S-PSS, S-SSS, PSBCH, and DM-RS**

*(Verified against the rendered PDF page — see `page129-129.png` cross-check.)*

| Channel or signal | OFDM symbol number 𝑙 (rel. to start of block) | Subcarrier number 𝑘 (rel. to start of block) |
|---|---|---|
| S-PSS | 1, 2 | 2, 3, …, 127, 128 |
| S-SSS | 3, 4 | 2, 3, …, 127, 128 |
| Set to zero | 1, 2, 3, 4 | 0, 1, 129, 130, 131 |
| PSBCH | 0, 5, 6, …, 𝑁symb^S-SSB − 1 | 0, 1, …, 131 |
| DM-RS for PSBCH | 0, 5, 6, …, 𝑁symb^S-SSB − 1 | 0, 4, 8, …, 128 |

###### 8.4.3.1.1 Mapping of S-PSS within an S-SS/PSBCH block

The sequence of symbols 𝑑S-PSS(0), … , 𝑑S-PSS(126) constituting the sidelink primary
synchronization signal in one OFDM symbol shall be scaled by a factor 𝛽S-PSS to conform to the
S-PSS power allocation specified in [5, TS 38.213] and mapped to resource elements (𝑘, 𝑙)_{𝑝,𝜇}
in increasing order of 𝑘 in each of the symbols 𝑙, where 𝑘 and 𝑙 are given by Table 8.4.3.1-1 and
represent the frequency and time indices, respectively, within one S-SS/PSBCH block.

###### 8.4.3.1.2 Mapping of S-SSS within an S-SS/PSBCH block

The sequence of symbols 𝑑S-SSS(0), … , 𝑑S-SSS(126) constituting the sidelink secondary
synchronization signal in one OFDM symbol shall be scaled by a factor 𝛽S-SSS to conform to the
S-SSS power allocation specified in [5, TS 38.213] and mapped to resource elements (𝑘, 𝑙)_{𝑝,𝜇}
in increasing order of 𝑘 in each of the symbols 𝑙, where 𝑘 and 𝑙 are given by Table 8.4.3.1-1 and
represent the frequency and time indices, respectively, within one S-SS/PSBCH block.

###### 8.4.3.1.3 Mapping of PSBCH and DM-RS within an S-SS/PSBCH block

The sequence of complex-valued symbols 𝑑PSBCH(0), … , 𝑑PSBCH(𝑀symb − 1) constituting the physical
sidelink broadcast channel shall be scaled by a factor 𝛽DMRS^PSBCH to conform to the PSBCH power
allocation specified in [5, TS 38.213] and mapped in sequence starting with 𝑑PSBCH(0) to resource
elements (𝑘, 𝑙)_{𝑝,𝜇} which meet all the following criteria:

- they are not used for PSBCH demodulation reference signals

The mapping to resource elements (𝑘, 𝑙)_{𝑝,𝜇} not reserved for PSBCH DM-RS shall be in increasing
order of first the index 𝑘 and then the index 𝑙, where 𝑘 and 𝑙 represent the frequency and time
indices, respectively, within one S-SS/PSBCH block and are given by Table 8.4.3.1-1.

The sequence of complex-valued symbols 𝑟(0), … , 𝑟(33·(𝑁symb^S-SSB − 4) − 1) constituting the
demodulation reference signals for the S-SS/PSBCH block shall be scaled by a factor of
𝛽DMRS^PSBCH to conform to the PSBCH power allocation specified in [5, TS 38.213] and mapped to
resource elements (𝑘, 𝑙)_{𝑝,𝜇} in increasing order of first 𝑘 and then 𝑙 where 𝑘 and 𝑙 are given
by Table 8.4.3.1-1 and represent the frequency and time indices, respectively, within one
S-SS/PSBCH block.

##### 8.4.3.2 Time location of an S-SS/PSBCH block

The locations in the time domain where a UE shall monitor for a possible S-SS/PSBCH block are
described in clause 16.1 of [5, TS 38.213].

### 8.5 Timing

Transmission of a sidelink radio frame number 𝑖 from the UE shall start
(𝑁TA,SL + 𝑁TA,offset) · 𝑇c seconds before the start of the corresponding timing reference frame
at the UE. The UE is not required to receive sidelink or downlink transmissions earlier than the
value of 𝑁TA,offset, which is given in [12, TS 38.133], after the end of a sidelink transmission.

For sidelink transmissions:

If the UE has a serving cell fulfilling the S criterion according to clause 8.2 of
[13, TS 38.304]

- The timing of reference radio frame 𝑖 equals that of downlink radio frame 𝑖 in the cell with
  the same uplink carrier frequency as the sidelink and
- 𝑁TA,offset is given by clause 4.3.1 of [TS 38.211],

Otherwise

- The timing of reference radio frame 𝑖 is given by clauses 12.2.2, 12.2.3, 12.2.4 or 12.2.5 of
  [12, TS 38.113] and
- 𝑁TA,offset = 0.

**Figure 8.5-1: Sidelink timing relation**

A timing-reference-frame `i` is drawn as a dashed box starting some time before the sidelink
radio frame `i` box begins; the sidelink radio frame `i` box starts later than the timing
reference frame `i` box by an amount `(N_TA,SL + N_TA,offset) · T_c` seconds, marked with a
double-headed arrow between the two start points.

The quantity 𝑁TA,SL equals to 0.

---

## Gaps in this extraction

### Everything in clause 8 is covered

All of clause 8 (§8.1 through §8.5) is transcribed above — there is no clause 9 in this document;
clause 8 is the last normative clause before Annex A (Change history), confirmed by extracting
PDF pages 118–131 (the clause boundary was located first via the document's own table of
contents on PDF pages 6–7, then verified against the page footers, which read
`Release 16 <page> 3GPP TS 38.211 V16.10.0 (2022-06)` throughout — offset 0 between printed page
number and PDF page number).

### One likely spec-original typo, preserved verbatim

§8.5 cites `[12, TS 38.133]` for `N_TA,offset` in one paragraph, then cites `[12, TS 38.113]`
(same reference number `[12]`, different spec number) two paragraphs later for the reference
radio frame timing clauses. 3GPP TS 38.113 does not exist as a real specification number (38.133
"Requirements for support of radio resource management" is the real target and is almost
certainly what `[12]` is defined as in clause 2 of this document, which is outside the extracted
page range). This looks like a typo in the source PDF itself, not an artifact of this extraction
— both spellings were confirmed by direct visual inspection of PDF page 130. Preserved as-is
above; treat `[12, TS 38.113]` as `[12, TS 38.133]` when tracing the reference.

### Clause 8 leans on clauses 4–7 of the same document — not extracted here (out of scope)

Clause 8 is written as a thin sidelink-specific layer over generic definitions that live earlier
in the same `38211-ga0.pdf`, in clauses 4 (frame structure and physical resources), 5 (generic
functions — modulation mapper, pseudo-random sequence generator), 6 (uplink — precoding, low-PAPR
sequence generator, DM-RS-to-RE mapping template), and 7 (downlink — layer mapping, CSI-RS RE
mapping template). Specifically, clause 8 subclauses that just say "as defined in clause X" and
stop there, where X is outside clause 8:

| Clause 8 subclause | Defers to | Content deferred |
|---|---|---|
| §8.2.3.1 | 4.3.1 | Frames and subframes |
| §8.2.3.2 | 4.3.2 | Slot structure |
| §8.2.4 | 4.4.1 | Antenna port definition |
| §8.2.5 | 4.4.2 | Resource grid definition |
| §8.2.6 | 4.4.3 | Resource element definition |
| §8.2.7 | 4.4.4 | Resource block definition |
| §8.3.1.1, §8.3.2.1, §8.3.3.1, DM-RS/CSI-RS §§ | 5.2.1 / 5.2 | Pseudo-random (Gold) sequence generator `c(i)` |
| §8.3.1.2, §8.3.2.2 | 5.1 (/ 5.1.3 for PSBCH) | Modulation mapper (QPSK/16QAM/64QAM/256QAM) |
| §8.3.1.3 | 7.3.1.3 | Layer mapping procedure |
| §8.3.1.4, PT-RS §8.4.1.2.2 | 6.3.1.5 | Precoding procedure |
| §8.3.4.2.1 (PSFCH) | 6.3.2.2 | Low-PAPR sequence `r_{u,v}^{α,δ}(n)` generator (same family as PUCCH/PUSCH DMRS base sequences) |
| §8.4.1.1.2 (PSSCH DM-RS) | 6.4.1.1.3 | Generic DM-RS-to-intermediate-quantity RE mapping template |
| §8.4.1.5.3 (CSI-RS) | 7.4.1.5.3 | Generic CSI-RS RE mapping template |

None of clauses 4–7 are extracted in this repo (only clause 8 was in scope for this file). This
mirrors the existing gap pattern for `38214-gh0.pdf` clause 5 (00-INDEX gap #3) — same PDF,
different clause, not yet pulled in. **Impact:** low for reading clause 8's channel/signal
definitions (the formulas and tables above are self-contained enough to implement against), but
a from-scratch reimplementation of the Gold-sequence generator, the low-PAPR sequence generator,
or the generic DM-RS/CSI-RS RE-mapping template would need those clauses too.

### Two external specs referenced by clause 8 that are not in this repo at all

- **TS 38.304** (`[13, TS 38.304]`, cited once in §8.5 for the "S criterion" that selects which
  timing reference a UE uses) — no PDF present anywhere in `../`. Narrow impact: only affects the
  timing-reference-frame selection branch when a UE has an in-coverage serving cell.
- **TS 38.133** (`[12, TS 38.133]`, cited in §8.5 for `N_TA,offset` and reference-frame timing
  clauses 12.2.2–12.2.5) — no PDF present. Same narrow scope: sidelink Tx timing advance/offset
  only.

Neither of these was in the pre-existing 00-INDEX gap list; both are low-impact (timing-advance
detail, not resource selection or channel coding) but are noted here per the "don't silently
drop" instruction.

### Cross-checks against this project's existing (pre-extraction) assumptions

**(a) S-PSS — confirmed one m-sequence at two cyclic shifts, not two base sequences.**
§8.4.2.2.1 defines exactly one generator polynomial (`x(i+7)=(x(i+4)+x(i)) mod 2`) and one 7-bit
initial state (`1110110`), read out starting at offset `22 + 43·N_ID,2^SL`. With
`N_ID,2^SL ∈ {0,1}`, the two shifts are **22** and **65**. `+phy/+ts38211/CLAUDE.md`'s
"two candidate m-sequences for S-PSS" framing and its "Known traps" entry both describe this as
if there are two sequences to implement; the spec text says there is one sequence and one
parametrised cyclic shift. This is worth correcting in that file — the trap is real (an
implementer who hard-codes only the `N_ID,2^SL=0` shift and assumes the other "follows a
pattern" will get it wrong), but the *reason* is a single shifted readout, not two distinct
sequence generators.

**(b) S-SSS — "Gold-derived" is directionally fine but imprecise.** §8.4.2.3.1 constructs S-SSS
as a product of two *different* m-sequences (`x0` and `x1`, different tap positions, different
independent cyclic shifts `m0`/`m1` — `m0` depends on both `N_ID,1^SL` and `N_ID,2^SL`, `m1` only
on `N_ID,1^SL`). This is the same construction pattern as the Uu SSS (this spec's own clause
7.4.2.3.1), not literally the Gold-sequence generator of clause 5.2.1 that every scrambling
sequence in this clause otherwise uses. Not a contradiction requiring a code change, just a more
precise description than "Gold-derived" for documentation purposes.

**(c) AGC symbol duplicates the following symbol — confirmed.** §8.2.1, §8.3.1.5, §8.3.2.3, and
§8.3.4.2.2 are consistent: the *first* OFDM symbol of a PSSCH+PSCCH transmission (or of a PSFCH
transmission) has its content **copied from** the first *real* content symbol that follows it
("...shall be duplicated in the OFDM symbol immediately preceding..."). This matches
`+phy/CLAUDE.md`'s "The AGC symbol duplicates the symbol after it, so it is populated after that
symbol exists" exactly, for all three of PSSCH/PSCCH and PSFCH.

**(d) Guard symbol — confirmed for "last in the region", not confirmed as bracketing PSFCH on
both sides.** §8.2.1 defines exactly *one* guard symbol per region: "The OFDM symbol immediately
following the last symbol used for PSSCH, PSFCH, or S-SSB serves as a guard symbol." This is a
single trailing symbol after each such region — it does confirm a guard symbol follows a PSFCH
region (supporting "guard symbol ... also around PSFCH" if that phrase means "at the tail end of
the PSFCH region too"). **It does not establish a guard symbol *before* PSFCH.** The symbol
immediately before PSFCH's content-carrying symbol is PSFCH's own AGC-role duplicate per
§8.3.4.2.2 (which copies PSFCH's second symbol backward into its first), not a "guard" in this
clause's terminology; the reason PSSCH cannot be transmitted in the symbol immediately before
PSFCH is TS 38.214 §8.1.2.1's scheduling restriction, not an §8.2.1 guard-symbol rule. If
`+phy/CLAUDE.md`'s "and around PSFCH" was meant to imply guard symbols on *both* sides of PSFCH,
that reading is not supported by clause 8 alone — worth tightening to "guard symbol follows a
PSFCH region; the symbol before PSFCH's content is PSFCH's own duplicated first symbol, not a
guard."

### Table/figure reconstruction notes

- **Table 8.4.1.1.2-1** (PSSCH DM-RS time-domain location) and **Table 8.4.3.1-1** (S-SS/PSBCH
  block resource map) both had multi-level merged column headers in the source PDF. Both were
  reconstructed by rendering the source page as an image (`pdftoppm -r 220`) and reading the grid
  directly, not by guessing from the flattened `-layout` text — the flattened text for both
  happened to already preserve correct column alignment, and the image cross-check confirmed no
  cells were transposed.
- **Table 8.4.1.2.2-1** (`k_ref^RE`) and **Table 8.4.1.3.2-1** (`w_{f,i}(k')`) were likewise
  confirmed against rendered page images.
- **Figure 8.5-1** (sidelink timing relation) is a simple two-box timing diagram with one
  labelled arrow; it is described in prose above rather than reconstructed as an ASCII diagram,
  since the flattened text extraction of a figure has no grid/table structure to reconstruct —
  the underlying formula it illustrates, `(N_TA,SL + N_TA,offset) · T_c`, is already given
  verbatim in the surrounding §8.5 text.
