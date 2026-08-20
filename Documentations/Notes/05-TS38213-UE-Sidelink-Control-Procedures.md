# TS 38.213 §16 — UE Procedures for Sidelink Control

> **Source:** 3GPP TS 38.213 V16.17.0 (2024-03), Release 16 — *NR; Physical layer procedures for control*
> **Scope:** S-SSB synchronisation procedures and priority, open-loop power control for PSSCH/PSCCH/PSFCH/S-SSB, SL vs UL prioritisation, PSFCH HARQ-ACK reporting on sidelink and forwarding on uplink (PUCCH/PUSCH codebooks), PSCCH transmission.
> **Status:** verbatim spec extract, reformatted. Page headers/footers removed,
> PDF hard-wraps rejoined, clause numbers promoted to headings.
> Normative text is unchanged; see `00-INDEX.md` for gaps and reconstructions.

## Contents

- [16 UE procedures for sidelink](#16-ue-procedures-for-sidelink)
  - [16.1 Synchronization procedures](#161-synchronization-procedures)
  - [16.2 Power control](#162-power-control)
    - [16.2.0 S-SS/PSBCH blocks](#1620-s-sspsbch-blocks)
    - [16.2.1 PSSCH](#1621-pssch)
    - [16.2.2 PSCCH](#1622-pscch)
    - [16.2.3 PSFCH](#1623-psfch)
    - [16.2.4 Prioritization of transmissions/receptions](#1624-prioritization-of-transmissionsreceptions)
      - [16.2.4.1 Simultaneous NR and E-UTRA transmission/reception](#16241-simultaneous-nr-and-e-utra-transmissionreception)
      - [16.2.4.2 Simultaneous PSFCH transmission/reception](#16242-simultaneous-psfch-transmissionreception)
      - [16.2.4.3 Simultaneous SL and UL transmissions/receptions](#16243-simultaneous-sl-and-ul-transmissionsreceptions)
        - [16.2.4.3.1 Prioritizations for sidelink and uplink transmissions/receptions](#162431-prioritizations-for-sidelink-and-uplink-transmissionsreceptions)
  - [16.3 UE procedure for reporting HARQ-ACK on sidelink](#163-ue-procedure-for-reporting-harq-ack-on-sidelink)
    - [16.3.1 UE procedure for receiving HARQ-ACK on sidelink](#1631-ue-procedure-for-receiving-harq-ack-on-sidelink)
  - [16.4 UE procedure for transmitting PSCCH](#164-ue-procedure-for-transmitting-pscch)
  - [16.5 UE procedure for reporting HARQ-ACK on uplink](#165-ue-procedure-for-reporting-harq-ack-on-uplink)
    - [16.5.1 Type-1 HARQ-ACK codebook determination](#1651-type-1-harq-ack-codebook-determination)
      - [16.5.1.1 Type-1 HARQ-ACK codebook in physical uplink control channel](#16511-type-1-harq-ack-codebook-in-physical-uplink-control-channel)
      - [16.5.1.2 Type-1 HARQ-ACK codebook in physical uplink shared channel](#16512-type-1-harq-ack-codebook-in-physical-uplink-shared-channel)
    - [16.5.2 Type-2 HARQ-ACK codebook determination](#1652-type-2-harq-ack-codebook-determination)
      - [16.5.2.1 Type-2 HARQ-ACK codebook in physical uplink control channel](#16521-type-2-harq-ack-codebook-in-physical-uplink-control-channel)
      - [16.5.2.2 Type-2 HARQ-ACK codebook in physical uplink shared channel](#16522-type-2-harq-ack-codebook-in-physical-uplink-shared-channel)

---

## 16 UE procedures for sidelink

A UE is provided by _SL-BWP-Config_ or _SL-BWP-ConfigCommon_ a BWP for SL transmissions (SL BWP) with numerology and resource grid determined as described in [4, TS 38.211]. For a resource pool within the SL BWP, the UE is provided by _sl-NumSubchannel_ a number of sub-channels where each sub-channel includes a number of contiguous RBs provided by _sl-SubchannelSize_. The first RB of the first sub-channel in the SL BWP is indicated by _sl-StartRB-Subchannel_. Available slots for a resource pool are provided by _sl-TimeResource_ and occur with a periodicity of 10240 ms. For an available slot without S-SS/PSBCH blocks, SL transmissions can start from a first symbol indicated by _sl-StartSymbol_ and be within a number of consecutive symbols indicated by _sl-LengthSymbols_. For an available slot with S-SS/PSBCH blocks, the first symbol and the number of consecutive symbols is predetermined.

The UE expects to use a same numerology in the SL BWP and in an active UL BWP in a same carrier of a same cell. If the active UL BWP numerology is different than the SL BWP numerology, the SL BWP is deactivated.

A priority of a PSSCH according to NR radio access or according to E-UTRA radio access is indicated by a priority field in a respective scheduling SCI format. A priority of a PSSS/SSSS/PSBCH according to E-UTRA radio access is provided by _sl-SSB-PriorityEUTRA_ [13, TS 36.213]. A priority of an S-SS/PSBCH block is provided by _sl-SSB-PriorityNR_. A priority of a PSFCH is same as the priority of a corresponding PSSCH.

A UE does not expect to be provided search space sets associated with CORESETs on more than one cell to monitor PDCCH for detection of DCI format 3_0 or DCI format 3_1.

### 16.1 Synchronization procedures

A UE receives the following SL synchronization signals in order to perform synchronization procedures based on S- SS/PSBCH blocks: SL primary synchronization signals (S-PSS) and SL secondary synchronization signals (S-SSS) [4, TS 38.211].

A UE assumes that reception occasions of a physical sidelink broadcast channel (PSBCH), S-PSS, and S-SSS are in consecutive symbols [4, TS 38.211] and form a S-SS/PSBCH block.

For reception of a S-SS/PSBCH block, a UE assumes a frequency location corresponding to the subcarrier with index 66 in the S-SS/PSBCH block [4, TS 38.211], is provided by _sl-AbsoluteFrequencySSB_. The UE assumes that a S-PSS symbol, a S-SSS symbol, and a PSBCH symbol have a same transmission power. The UE assumes a same numerology of the S-SS/PSBCH as for a SL BWP of the S-SS/PSBCH block reception, and that a bandwidth of the S-SS/PSBCH is within a bandwidth of the SL BWP. The UE assumes the subcarrier with index 0 in the S-SS/PSBCH block is aligned with a subcarrier with index 0 in an RB of the SL BWP.

A UE is provided, by _sl-NumSSB-WithinPeriod_, a number 𝑁period S−SSB of S-SS/PSBCH blocks in a period of 16 frames.

The UE assumes that a transmission of the S-SS/PSBCH blocks in the period is with a periodicity of 16 frames. The UE determines indexes of slots that include S-SS/PSBCH block as 𝑁offset S−SSB+(𝑁interval S−SSB + 1) ⋅ 𝑖S−SSB, where

- index 0 corresponds to a first slot in a frame with SFN of the serving cell satisfying (SFN mod 16) = 0 or DFN satisfying (DFN mod 16) = 0
- 𝑖S−SSB is a S-SS/PSBCH block index within the number of S-SS/PSBCH blocks in the period, with 0 ≤ S−SSB 𝑖S−SSB ≤ 𝑁period − 1
- 𝑁offset S−SSB is a slot offset from a start of the period to the first slot including S-SS/PSBCH block, provided by _sl-TimeOffsetSSB_
- 𝑁interval S−SSB is a slot interval between S-SS/PSBCH blocks, provided by _sl-TimeInterval_ For paired spectrum, an S-SS/PSBCH block can be transmitted/received only in a slot of an UL carrier. For unpaired spectrum, an S-SS/PSBCH block can be transmitted/received only in a slot of which all OFDM symbols are configured as UL by _tdd-UL-DL-ConfigurationCommon_ of the serving cell if provided or _sl-TDD-Configuration_ if provided or _sl-TDD-Config_ of the received PSBCH if provided. Or if _tdd-UL-DL-ConfigurationCommon_ and _sl-TDD-Configuration_ are not provided for a spectrum indicated with only PC5 interface in Table 5.2E.1-1 in [TS 38.101-1], an S-SS/PSBCH block can be transmitted/received in any slot of the spectrum.

For transmission of an S-SS/PSBCH block, a UE includes a bit sequence 𝑎0, 𝑎1, 𝑎2, 𝑎3, …, 𝑎11 in the PSBCH payload to indicate _sl-TDD-Config_ and provide a slot format over a number of slots.

For paired spectrum, or if _tdd-UL-DL-ConfigurationCommon_ and _sl-TDD-Configuration_ are not provided for a spectrum indicated with only PC5 interface in Table 5.2E.1-1 in [TS 38.101-1],

- 𝑎0, 𝑎1, 𝑎2, 𝑎3, 𝑎4, 𝑎5, 𝑎6, 𝑎7, 𝑎8, 𝑎9, 𝑎10, 𝑎11 are set to '1';

else

- 𝑎0 = 0 if _pattern1_ is provided by _sl-TDD-Configuration_ or _tdd-UL-DL-ConfigurationCommon_; 𝑎0 = 1 if both _pattern1_ and _pattern2_ are provided by _sl-TDD-Configuration_ or _tdd-UL-DL-ConfigurationCommon_ as described in clause 11.1
- 𝑎1, 𝑎2, 𝑎3, 𝑎4 are determined based on
- 𝑃 in _pattern1_ as described in Table 16.1-1 for 𝑎0 = 0
- 𝑃 in _pattern1_ and 𝑃 2 _in pattern2_ as described in Table 16.1-2 for 𝑎0 = 1 where 𝑃 and 𝑃 2 are as described in clause 11.1
- 𝑎5, 𝑎6, 𝑎7, 𝑎8, 𝑎9, 𝑎10, 𝑎11 are the 7th to 1st LSBs of 𝑢slots SL, respectively
- for 𝑎0 = 0, 𝑢slots SL = 𝑢slots ∗ 2𝜇−𝜇ref + ⌊𝑢sym∗2𝜇−𝜇ref 𝐿 ⌋ + 𝐼1
- for 𝑎0 = 1, 𝑢slots SL = ⌊𝑢slots,2∗2𝜇−𝜇ref+⌊𝑢sym,2∗2𝜇−𝜇ref 𝐿 ⌋+𝐼2 𝑤 ⌋ ∗ ⌈𝑃∗2𝜇+1 𝑤 ⌉ + ⌊𝑢slots∗2𝜇−𝜇ref+⌊𝑢sym∗2𝜇−𝜇ref 𝐿 ⌋+𝐼1 𝑤 ⌋ where
- 𝐿 is the number of symbols in a slot: 𝐿 = 12 if _cyclicPrefix_ = "ECP"; else, 𝐿 = 14
- 𝐼1 is 1 if 𝑢sym ∗ 2𝜇−𝜇ref 𝑚𝑜𝑑 𝐿 ≥ 𝐿 − 𝑌, else 𝐼1 is 0
- 𝐼2 is 1 if 𝑢sym,2 ∗ 2𝜇−𝜇ref 𝑚𝑜𝑑 𝐿 ≥ 𝐿 − 𝑌, else 𝐼2 is 0
- 𝑌 is the sidelink starting symbol index provided by _sl-StartSymbol_
- 𝑤 is the granularity of slots indication as described in Table 16.1-2
- 𝜇ref, 𝑢slots, 𝑢sym, 𝑢slots,2, 𝑢sym,2 are the parameters of _tdd-UL-DL-ConfigurationCommon_ as described in clause 11.1, or the parameters of _sl-TDD-Configuration_ as defined in [12, TS 38.331]
- 𝜇 = 0, 1, 2, 3 corresponds to SL SCS as defined in [4, TS 38.211]

**Table 16.1-1: Slot configuration period when one pattern is indicated** **Slot configuration period of** **_pattern1_** 𝒂𝟏, 𝒂𝟐, 𝒂𝟑, 𝒂𝟒 𝑷 **(msec)** 0, 0, 0, 0 0.5 0, 0, 1, 0 1 0, 1, 0, 0 2 0, 0, 0, 1 0, 0, 1, 1 2.5 10 0, 1, 0, 1 0, 1, 1, 0 4 0, 1, 1, 1 5 0.625 1.25 1, 0, 0, 0 Reserved Reserved

**Table 16.1-2: Slot configuration period and granularity when two patterns are indicated** 𝒂𝟏, 𝒂𝟐, 𝒂𝟑, 𝒂𝟒 0, 0, 0, 0 0, 0, 0, 1 0, 0, 1, 0 1 1 0, 0, 1, 1 0.5 2 0, 1, 0, 0 0, 1, 0, 1 2 0.5 0, 1, 1, 0 1 3 0, 1, 1, 1 1, 0, 0, 0 1, 0, 0, 1 1, 0, 1, 0 1, 0, 1, 1 1, 1, 0, 0 1, 1, 0, 1 1, 1, 1, 0 1, 1, 1, 1 **Slot configuration** **period of** **_pattern1_** 𝑷 **(msec)** 0.5 0.625 1.25 2.5 10 𝑷𝟐 **(msec)** 0.5 0.625 1.25 2.5 10 **Slot configuration period** **of** **_pattern2_** **Granularity** 𝒘 **in slots with different SCS** 15kHz 30 kHz 60 kHz 120 kHz 1 2 2 3 1 1 4 1 2 2 3 3 2 4 1 5 5 1 2 4 1 2 4 8 If a UE would transmit or receive an S-SS/PSBCH block, and the transmission or reception would overlap in time with transmissions or receptions on the sidelink using E-UTRA radio access, the UE transmits or receives the signal/channel with the higher priority.

If a UE would transmit or receive sidelink synchronization signals for E-UTRA radio access, and the transmission or reception would overlap in time with sidelink transmissions or receptions using NR radio access, the UE transmits or receives the signal/channel with the higher priority.

### 16.2 Power control

#### 16.2.0 S-SS/PSBCH blocks

A UE determines a power 𝑃 S-SSB(𝑖) for an S-SS/PSBCH block transmission occasion in slot 𝑖 on active SL BWP 𝑏 of carrier 𝑓 as 𝑃 S-SSB(𝑖) = 𝑚𝑖𝑛(𝑃 CMAX, 𝑃 O,S−SSB + 10 𝑙𝑜𝑔10(2𝜇∙ 𝑀RB S−SSB) + 𝛼S−SSB⋅ 𝑃𝐿) [dBm] where

- 𝑃 CMAX is defined in [8-1, TS 38.101-1]
- 𝑃 O,S−SSB is a value of _dl-P0-PSBCH_ if provided; else, 𝑃 S-SSB(𝑖) = 𝑃 CMAX
- 𝛼S−SSB is a value of _dl-Alpha-PSBCH_, if provided; else, 𝛼S−SSB = 1
- 𝑃𝐿 = 𝑃𝐿𝑏,𝑓,𝑐(𝑞𝑑) when the active SL BWP is on a serving cell 𝑐, as described in clause 7.1.1 except that
- the RS resource is the one the UE uses for determining a power of a PUSCH transmission scheduled by a DCI format 0_0 in serving cell 𝑐 when the UE is configured to monitor PDCCH for detection of DCI format 0_0 in serving cell 𝑐
- the RS resource is the one corresponding to the SS/PBCH block the UE uses to obtain MIB when the UE is not configured to monitor PDCCH for detection of DCI format 0_0 in serving cell 𝑐
- 𝑀RB S−SSB = 11 is a number of resource blocks for a S-SS/PSBCH block transmission with SCS configuration 𝜇

#### 16.2.1 PSSCH

A UE determines a power 𝑃 PSSCH(𝑖) for a PSSCH transmission on a resource pool in symbols where a corresponding PSCCH is not transmitted in PSCCH-PSSCH transmission occasion 𝑖 on active SL BWP 𝑏 of carrier 𝑓 as:

𝑃 PSSCH(𝑖) = 𝑚𝑖𝑛 (𝑃 CMAX, 𝑃 MAX,CBR, 𝑚𝑖𝑛(𝑃 PSSCH,𝐷(𝑖), 𝑃 PSSCH,𝑆𝐿(𝑖))) [dBm] where

- 𝑃 CMAX is defined in [8-1, TS 38.101-1]
- 𝑃 MAX,CBR is determined by a value of _sl-MaxTxPower_ based on a priority level of the PSSCH transmission and a CBR range that includes a CBR measured in slot 𝑖 − 𝑁 [6, TS 38.214]; if _sl-MaxTxPower_ is not provided, then 𝑃 MAX,CBR = 𝑃 CMAX;
- if _dl-P0-PSSCH-PSCCH_ is provided
- 𝑃 PSSCH,𝐷(𝑖) = 𝑃 O,𝐷 + 10 𝑙𝑜𝑔10 (2𝜇 ⋅ 𝑀RB PSSCH(𝑖)) + 𝛼𝐷⋅ 𝑃𝐿𝐷 [dBm]
- else
- 𝑃 PSSCH,𝐷(𝑖) = 𝑚𝑖𝑛(𝑃 CMAX, 𝑃 MAX,CBR) [dBm] where
- 𝑃 O,𝐷 is a value of _dl-P0-PSSCH-PSCCH_ if provided
- 𝛼𝐷 is a value of _dl-Alpha-PSSCH-PSCCH_, if provided; else, 𝛼𝐷 = 1
- 𝑃𝐿𝐷 = 𝑃𝐿𝑏,𝑓,𝑐(𝑞𝑑) when the active SL BWP is on a serving cell 𝑐, as described in clause 7.1.1 except that
- the RS resource is the one the UE uses for determining a power of a PUSCH transmission scheduled by a DCI format 0_0 in serving cell 𝑐 when the UE is configured to monitor PDCCH for detection of DCI format 0_0 in serving cell 𝑐
- the RS resource is the one corresponding to the SS/PBCH block the UE uses to obtain MIB when the UE is not configured to monitor PDCCH for detection of DCI format 0_0 in serving cell 𝑐
- 𝑀RB PSSCH(𝑖) is a number of resource blocks for the PSSCH transmission occasion 𝑖 and 𝜇 is a SCS configuration
- if _sl-P0-PSSCH-PSCCH_ is provided, if a SCI format scheduling the PSSCH transmission includes a cast type indicator field indicating unicast, and if a ℎ𝑖𝑔ℎ𝑒𝑟 𝑙𝑎𝑦𝑒𝑟 𝑓𝑖𝑙𝑡𝑒𝑟𝑒𝑑 𝑅𝑆𝑅𝑃 is reported to the UE transmitting the PSSCH from the UE intended to receive the PSCCH-PSSCH transmission
- 𝑃 PSSCH,𝑆𝐿(𝑖) = 𝑃 O,𝑆𝐿 + 10 𝑙𝑜𝑔10 (2𝜇 ⋅ 𝑀RB PSSCH(𝑖)) + 𝛼𝑆𝐿⋅ 𝑃𝐿𝑆𝐿 [dBm]
- else
- 𝑃 PSSCH,SL(𝑖) = 𝑚𝑖𝑛(𝑃 CMAX, 𝑃 PSSCH,𝐷(𝑖)) [dBm] where
- 𝑃 O,𝑆𝐿 is a value of _sl-P0-PSSCH-PSCCH_, if provided
- 𝛼𝑆𝐿 is a value of _sl-Alpha-PSSCH-PSCCH_, if provided; else, 𝛼𝑆𝐿 = 1
- 𝑃𝐿𝑆𝐿 = 𝑟𝑒𝑓𝑒𝑟𝑒𝑛𝑐𝑒𝑆𝑖𝑔𝑛𝑎𝑙𝑃𝑜𝑤𝑒𝑟 – ℎ𝑖𝑔ℎ𝑒𝑟 𝑙𝑎𝑦𝑒𝑟 𝑓𝑖𝑙𝑡𝑒𝑟𝑒𝑑 𝑅𝑆𝑅𝑃, where
- 𝑟𝑒𝑓𝑒𝑟𝑒𝑛𝑐𝑒𝑆𝑖𝑔𝑛𝑎𝑙𝑃𝑜𝑤𝑒𝑟 is obtained from a PSSCH transmit power per RE summed over the antenna ports of the UE, higher layer filtered across PSSCH transmission occasions using a filter configuration provided by _sl-FilterCoefficient_, and
- ℎ𝑖𝑔ℎ𝑒𝑟 𝑙𝑎𝑦𝑒𝑟 𝑓𝑖𝑙𝑡𝑒𝑟𝑒𝑑 𝑅𝑆𝑅𝑃 is a RSRP, as defined in [7, TS 38.215], that is reported to the UE from a UE receiving the PSCCH-PSSCH transmission and is obtained from a PSSCH DM-RS using a filter configuration provided by _sl-FilterCoefficient_
- 𝑀RB PSSCH(𝑖) is a number of resource blocks for PSCCH-PSSCH transmission occasion 𝑖 and 𝜇 is a SCS configuration The UE splits the power 𝑃 PSSCH(𝑖) equally across the antenna ports on which the UE transmits the PSSCH with non- zero power.

A UE determines a power 𝑃 PSSCH2(𝑖) for a PSSCH transmission on a resource pool in the symbols where a corresponding PSCCH is transmitted in PSCCH-PSSCH transmission occasion 𝑖 on active SL BWP 𝑏 of carrier 𝑓 as 𝑃 PSSCH2(𝑖) = 10 𝑙𝑜𝑔10 (𝑀RB PSSCH(𝑖)−𝑀RB 𝑀RB PSSCH(𝑖) PSCCH(𝑖)) + 𝑃 PSSCH(𝑖) [dBm] where 𝑀RB PSCCH(𝑖) is a number of resource blocks for the corresponding PSCCH transmission in PSCCH-PSSCH transmission occasion 𝑖.

The UE splits the power 𝑃 PSSCH2(𝑖) equally across the antenna ports on which the UE transmits the PSSCH with non- zero power.

#### 16.2.2 PSCCH

A UE determines a power 𝑃 PSCCH(𝑖) for a PSCCH transmission on a resource pool in PSCCH-PSSCH transmission occasion 𝑖 as 𝑃 PSCCH(𝑖) = 10 𝑙𝑜𝑔10 (𝑀RB PSCCH(𝑖) 𝑀RB PSSCH(𝑖)) + 𝑃 PSSCH(𝑖) [dBm] where

- 𝑃 PSSCH(𝑖) is specified in clause 16.2.1
- 𝑀RB PSCCH(𝑖) is a number of resource blocks for the PSCCH transmission in PSCCH-PSSCH transmission occasion 𝑖
- 𝑀RB PSSCH(𝑖) is a number of resource blocks for PSCCH-PSSCH transmission occasion _i_

#### 16.2.3 PSFCH

A UE with 𝑁sch,Tx,PSFCH scheduled PSFCH transmissions, and capable of transmitting a maximum of 𝑁max,PSFCH PSFCHs, determines a number 𝑁Tx,PSFCH of simultaneous PSFCH transmissions and a power 𝑃 PSFCH,k(𝑖) for a PSFCH transmission 𝑘, 1 ≤ 𝑘 ≤ 𝑁Tx,PSFCH, on all the resource pools in PSFCH transmission occasion 𝑖 on active SL BWP 𝑏 of carrier 𝑓 as

- if _dl-P0-PSFCH_ is provided, 𝑃 PSFCH,one = 𝑃 O,𝑃𝑆𝐹𝐶𝐻 + 10 𝑙𝑜𝑔10(2𝜇) + 𝛼𝑃𝑆𝐹𝐶𝐻⋅ 𝑃𝐿 [dBm] where
- 𝑃 O,𝑃𝑆𝐹𝐶𝐻 is a value of _dl-P0-PSFCH_
- 𝛼𝑃𝑆𝐶𝐻 is a value of _dl-Alpha-PSFCH_, if provided; else, 𝛼𝑃𝐹𝑆𝐶𝐻 = 1
- 𝑃𝐿 = 𝑃𝐿𝑏,𝑓,𝑐(𝑞𝑑) when the active SL BWP is on a serving cell 𝑐, as described in clause 7.1.1 except that
- the RS resource is the one the UE uses for determining a power of a PUSCH transmission scheduled by a DCI format 0_0 in serving cell 𝑐 when the UE is configured to monitor PDCCH for detection of DCI format 0_0 in serving cell 𝑐
- the RS resource is the one corresponding to the SS/PBCH block the UE uses to obtain MIB when the UE is not configured to monitor PDCCH for detection of DCI format 0_0 in serving cell 𝑐
- if 𝑁sch,Tx,PSFCH ≤ 𝑁max,PSFCH
- if 𝑃 PSFCH,one + 10𝑙𝑜𝑔10(𝑁sch,Tx,PSFCH) ≤ 𝑃 CMAX, where 𝑃 CMAX is determined for 𝑁sch,Tx,PSFCH PSFCH transmissions according to [8-1, TS 38.101-1]
- 𝑁Tx,PSFCH = 𝑁sch,Tx,PSFCH and 𝑃 PSFCH,k(𝑖) = 𝑃 PSFCH,one [dBm]
- else
- UE autonomously determines 𝑁Tx,PSFCH PSFCH transmissions with ascending order of corresponding priority field values as described in clause 16.2.4.2 such that 𝑁Tx,PSFCH ≥ 𝐾 max(1, ∑ 𝑀𝑖 𝑖=1) where 𝑀𝑖 is a number of PSFCHs with priority value 𝑖 and 𝐾 is defined as 𝐾
- the largest value satisfying 𝑃 PSFCH,one + 10𝑙𝑜𝑔10(max(1, ∑ 𝑀𝑖 𝑖=1)) ≤ 𝑃 CMAX where 𝑃 CMAX is determined according to [8-1, TS 38.101-1] for transmission of all PSFCHs assigned with priority values 1, 2, …, 𝐾, if any
- zero, otherwise and 𝑃 PSFCH,k(𝑖) = 𝑚𝑖𝑛(𝑃 CMAX− 10𝑙𝑜𝑔10(𝑁Tx,PSFCH), 𝑃 PSFCH,one) [dBm] where 𝑃 CMAX is defined in [8-1, TS 38.101-1] and is determined for the 𝑁Tx,PSFCH PSFCH transmissions
- else
- the UE autonomously selects 𝑁max,PSFCH PSFCH transmissions with ascending order of corresponding priority field values as described in clause 16.2.4.2
- if 𝑃 PSFCH,one + 10𝑙𝑜𝑔10(𝑁max,PSFCH) ≤ 𝑃 CMAX, where 𝑃 CMAX is determined for the 𝑁max,PSFCH PSFCH transmissions according to [8-1, TS 38.101-1]
- 𝑁Tx,PSFCH = 𝑁max,PSFCH and 𝑃 PSFCH,k(𝑖) = 𝑃 PSFCH,one [dBm]
- else
- the UE autonomously selects 𝑁Tx,PSFCH PSFCH transmissions in ascending order of corresponding priority field values as described in clause 16.2.4.2 such that 𝑁Tx,PSFCH ≥ 𝐾 max(1, ∑ 𝑀𝑖 𝑖=1) where 𝑀𝑖 is a number of PSFCHs with priority value 𝑖 and 𝐾 is defined as 𝐾
- the largest value satisfying 𝑃 PSFCH,one + 10𝑙𝑜𝑔10(max(1, ∑ 𝑀𝑖 𝑖=1)) ≤ 𝑃 CMAX where 𝑃 CMAX is determined according to [8-1, TS 38.101-1] for transmission of all PSFCHs assigned with priority values 1, 2, …, 𝐾, if any
- zero, otherwise and 𝑃 PSFCH,k(𝑖) = 𝑚𝑖𝑛(𝑃 CMAX− 10𝑙𝑜𝑔10(𝑁Tx,PSFCH), 𝑃 PSFCH,one) [dBm] where 𝑃 CMAX is determined for the 𝑁Tx,PSFCH simultaneous PSFCH transmissions according to [8-1, TS 38.101-1]
- else 𝑃 PSFCH,k(𝑖) = 𝑃 CMAX− 10𝑙𝑜𝑔10(𝑁Tx,PSFCH) [dBm] where the UE autonomously determines 𝑁Tx,PSFCH PSFCH transmissions with ascending order of corresponding priority field values as described in clause 16.2.4.2 such that 𝑁Tx,PSFCH ≥ 1 and where 𝑃 CMAX is determined for the 𝑁Tx,PSFCH PSFCH transmissions according to [8-1, TS 38.101-1].

For resource pools configured with PSFCH resources overlapping in time, the UE either expects not to be provided with _dl-P0-PSFCH_ or _dl-Alpha-PSFCH_ in any of the resource pools, or expects to be provided with the same values of _dl-P0-PSFCH_ and the same values of _dl-Alpha-PSFCH_ for all the resource pools.

#### 16.2.4 Prioritization of transmissions/receptions

##### 16.2.4.1 Simultaneous NR and E-UTRA transmission/reception

If a UE

- would transmit a first channel/signal using E-UTRA radio access and second channels/signals using NR radio access, and
- a transmission of the first channel/signal would overlap in time with a transmission of the second channels/signals, and
- the priorities of the channels/signals are known to both E-UTRA radio access and NR radio access at the UE 𝑇 msec prior to the start of the earliest of the two transmissions, where 𝑇 ≤ 4 and is based on UE implementation, the UE transmits only the channels/signals of the radio access technology with the highest priority as determined by the SCI formats scheduling the transmissions or, in case of a S-SS/PSBCH block or a sidelink synchronization signal using E-UTRA radio access, as indicated by higher layers or, in case of PSFCH, equal to the priority of the corresponding PSSCH.

If a UE

- would respectively transmit or receive a first channel/signal using E-UTRA radio access and receive a second channel/signal or transmit second channels/signals using NR radio access, and
- a transmission or reception of the first channel/signal would respectively overlap in time with a reception of the second channel/signal or transmission of the second channels/signals, and
- the priorities of the channels/signals are known to both E-UTRA radio access and NR radio access at the UE 𝑇 msec prior to the start of the earliest transmission or reception, where 𝑇 ≤ 4 and is based on UE implementation, the UE transmits or receives the channels/signals of the radio access technology with the highest priority as determined by the SCI formats scheduling the transmissions or, in case of a S-SS/PSBCH block or a sidelink synchronization signal using E-UTRA radio access, as indicated by higher layers or, in case of PSFCH, equal to the priority of the corresponding PSSCH.

##### 16.2.4.2 Simultaneous PSFCH transmission/reception

If a UE

- would transmit 𝑁sch,Tx,PSFCH PSFCHs and receive 𝑁sch,Rx,PSFCHPSFCHs, and
- transmissions of the 𝑁sch,Tx,PSFCH PSFCHs would overlap in time with receptions of the 𝑁sch,Rx,PSFCH PSFCHs the UE transmits or receives only a set of PSFCHs corresponding to the smallest priority field value, as determined by a first set of SCI format 1-A and a second set of SCI format 1-A [5, TS 38.212] that are respectively associated with the 𝑁sch,Tx,PSFCH PSFCHs and the 𝑁sch,Rx,PSFCH PSFCHs.

If a UE would transmit 𝑁sch,Tx,PSFCH PSFCHs in a PSFCH transmission occasion, the UE transmits 𝑁Tx,PSFCH PSFCHs corresponding to the smallest 𝑁Tx,PSFCH priority field values indicated in all SCI formats 1-A associated with the PSFCH transmission occasion.

##### 16.2.4.3 Simultaneous SL and UL transmissions/receptions

If a UE

- would simultaneously transmit on the UL and on the SL in a carrier or in two respective carriers, and
- the UE is not capable of simultaneous transmissions on the UL and on the SL in the carrier or in the two respective carriers the UE transmits only on the link, UL or SL, with the higher priority.

If a UE

- would simultaneously transmit on the UL and receive on the SL in a carrier, or
- would simultaneously transmit on the UL and receive on the SL in two respective carriers and the UE is not capable of simultaneous transmission on the UL and reception on the SL in the two respective carriers the UE transmits on UL or receives on SL, with the higher priority.

If a UE

- is capable of simultaneous transmissions on the UL and on the SL in two respective carriers,
- would transmit on the UL and on the SL in the two respective carriers,
- the transmission on the UL would overlap with the transmission on the SL over a time period, and
- the total UE transmission power over the time period would exceed 𝑃 CMAX the UE
- reduces the power for the UL transmission prior to the start of the UL transmission, if the SL transmission has higher priority than the UL transmission as determined in clause 16.2.4.3.1, so that the total UE transmission power would not exceed 𝑃 CMAX
- reduces the power for the SL transmission prior to the start of the SL transmission, if the UL transmission has higher priority than the SL transmission as determined in clause 16.2.4.3.1, so that the total UE transmission power would not exceed 𝑃 CMAX

###### 16.2.4.3.1 Prioritizations for sidelink and uplink transmissions/receptions

A UE performs prioritization between SL transmissions/receptions and UL transmissions after performing the procedures described in clause 9, clause 9.2.5, and clause 9.2.6, and in clause 6.1 of [6, TS 38.214].

PSFCH transmissions in a slot have a same priority value as the smallest priority value among PSSCH receptions with corresponding HARQ-ACK information provided by the PSFCH transmissions in the slot.

PSFCH receptions in a slot have a same priority value as the smallest priority value among PSSCH transmissions with corresponding HARQ-ACK information provided by the PSFCH receptions in the slot.

A priority of S-SS/PSBCH block transmission or reception is provided by _sl-SSB-PriorityNR._ For prioritization between SL transmission or PSFCH/S-SS/PSBCH block reception and UL transmission other than a PRACH, or a PUSCH scheduled by an UL grant in a RAR and its retransmission, or a PUSCH corresponding to Type-2 random access procedure and its retransmission, or a PUCCH with sidelink HARQ-ACK information report

- if the UL transmission is for a PUSCH or for a PUCCH with priority index 1,
- if _sl-PriorityThreshold-UL-URLLC_ is provided
- the SL transmission or reception has higher priority than the UL transmission if the priority value of the SL transmission or reception is smaller than _sl-PriorityThreshold-UL-URLLC_; otherwise, the UL transmission has higher priority than the SL transmission or reception
- else
- the UL transmission has higher priority than the SL transmission or reception
- else
- the SL transmission or reception has higher priority than the UL transmission if the priority value of the SL transmission(s) or reception is smaller than _sl-PriorityThreshold_; otherwise, the UL transmission has higher priority than the SL transmission or reception A PRACH transmission, or a PUSCH scheduled by an UL grant in a RAR and its retransmission, or a PUSCH for Type-2 random access procedure and its retransmission, or a PUCCH with HARQ-ACK information in response to successRAR, or a PUCCH indicated by a DCI format 1_0 with CRC scrambled by a corresponding TC-RNTI has higher priority than a SL transmission or reception.

A PUCCH transmission with a sidelink HARQ-ACK information report has higher priority than a SL transmission if a priority value of the PUCCH is smaller than a priority value of the SL transmission. The priority value of the PUCCH transmission is as described in clause 16.5. If the priority value of the PUCCH transmission is larger than the priority value of the SL transmission, the SL transmission has higher priority.

A PUCCH transmission with a sidelink HARQ-ACK information report has higher priority than a PSFCH/S- SS/PSBCH block reception if a priority value of the PUCCH is smaller than a priority value of the SL reception. If the priority value of the PUCCH transmission is larger than the priority value of the PSFCH/S-SS/PSBCH block reception, the SL reception has higher priority.

When one or more SL transmissions from a UE overlap in time with multiple non-overlapping UL transmissions from the UE, the UE performs the SL transmissions if at least one SL transmission is prioritized over all UL transmissions subject to the UE processing timeline with respect to the first SL transmission and the first UL transmission.

When one or more UL transmissions from a UE overlap in time with multiple non-overlapping SL transmissions, the UE performs the UL transmissions if at least one UL transmission is prioritized over all SL transmissions subject to the UE processing timeline with respect to the first SL transmission and the first UL transmission.

When one SL transmission overlaps in time with one or more overlapping UL transmissions, the UE performs the SL transmission if the SL transmission is prioritized over all UL transmissions subject to both the UE multiplexing and processing timelines with respect to the first SL transmission and the first UL transmission, where the UE processing timeline with respect to the first SL transmission and the first UL transmission is same as when one or more SL transmissions overlap in time with multiple non-overlapping UL transmissions.

When one SL transmission overlaps in time with one or more overlapping UL transmissions, the UE performs the UL transmission if at least one UL transmission is prioritized over the SL transmission subject to both the UE multiplexing and processing timelines with respect to the first SL transmission and the first UL transmission, where the UE processing timeline with respect to the first SL transmission and the first UL transmission is same as when one or more SL transmissions overlap in time with multiple non-overlapping UL transmissions.

### 16.3 UE procedure for reporting HARQ-ACK on sidelink

A UE can be indicated by an SCI format scheduling a PSSCH reception to transmit a PSFCH with HARQ-ACK information in response to the PSSCH reception. The UE provides HARQ-ACK information that includes ACK or NACK, or only NACK.

A UE can be provided, by _sl-PSFCH-Period_, a number of slots in a resource pool for a period of PSFCH transmission occasion resources. If the number is zero, PSFCH transmissions from the UE in the resource pool are disabled.

A UE expects that a slot 𝑡′ 𝑆𝐿 (0 ≤ 𝑘 < 𝑇′ 𝑘 𝑚𝑎𝑥) has a PSFCH transmission occasion resource if 𝑘 mod 𝑁PSSCH PSFCH = 0, where 𝑡′ 𝑆𝐿 is defined in [6, TS 38.214], and 𝑇′ 𝑘 𝑚𝑎𝑥 is a number of slots that belong to the resource pool within 10240 msec according to [6, TS 38.214], and 𝑁PSSCH PSFCH is provided by _sl-PSFCH-Period_.

A UE may be indicated by higher layers to not transmit a PSFCH in response to a PSSCH reception [11, TS 38.321].

If a UE receives a PSSCH in a resource pool and the HARQ feedback enabled/disabled indicator field in an associated SCI format 2-A or a SCI format 2-B has value 1 [5, TS 38.212], the UE provides the HARQ-ACK information in a PSFCH transmission in the resource pool. The UE transmits the PSFCH in a first slot that includes PSFCH resources and is at least a number of slots, provided by _sl-MinTimeGapPSFCH_, of the resource pool after a last slot of the PSSCH reception.

A UE is provided by _sl-PSFCH-RB-Set_ a set of 𝑀PRB, set PSFCH PRBs in a resource pool for PSFCH transmission in a PRB of the resource pool. For a number of 𝑁subch sub-channels for the resource pool, provided by _sl-NumSubchannel_, and a number of PSSCH slots associated with a PSFCH slot that is less than or equal to 𝑁PSSCH PSFCH, the UE allocates the [(𝑖 + 𝑗 ⋅ 𝑁PSSCH PSFCH PSFCH) ⋅ 𝑀subch, slot, (𝑖 + 1 + 𝑗 ⋅ 𝑁PSSCH PSFCH PSFCH) ⋅ 𝑀subch, slot − 1] PRBs from the 𝑀PRB, set PSFCH PRBs to slot 𝑖 among the PSSCH slots associated with the PSFCH slot and sub-channel 𝑗, where 𝑀subch, slot PSFCH = 𝑀PRB, set PSFCH (𝑁subch⋅ 𝑁PSSCH ⁄, 0 ≤ PSFCH) PSFCH 𝑖 < 𝑁PSSCH, 0 ≤ 𝑗 < 𝑁subch, and the allocation starts in an ascending order of 𝑖 and continues in an ascending order of 𝑗. The UE expects that 𝑀PRB, set PSFCH is a multiple of 𝑁subch∙ 𝑁PSSCH PSFCH _._ The second OFDM symbol 𝑙′ of PSFCH transmission in a slot is defined as 𝑙′ 𝑠𝑙-𝐿𝑒𝑛𝑔𝑡ℎ𝑆𝑦𝑚𝑏𝑜𝑙𝑠 − 2.

= 𝑠𝑙-𝑆𝑡𝑎𝑟𝑡𝑆𝑦𝑚𝑏𝑜𝑙 + A UE determines a number of PSFCH resources available for multiplexing HARQ-ACK information in a PSFCH transmission as 𝑅PRB, CS PSFCH = 𝑁type PSFCH PSFCH ⋅ 𝑀subch, slot ⋅ 𝑁CS PSFCH where 𝑁CS PSFCH is a number of cyclic shift pairs for the resource pool provided by _sl-NumMuxCS-Pair_ and, based on an indication by _sl-PSFCH-CandidateResourceType_,

- if _sl-PSFCH-CandidateResourceType_ is configured as _startSubCH_, 𝑁type PSFCH = 1 and the 𝑀subch, slot PSFCH PRBs are associated with the starting sub-channel of the corresponding PSSCH;
- if _sl-PSFCH-CandidateResourceType_ is configured as _allocSubCH_, 𝑁type PSFCH = 𝑁subch PSSCH and the PSSCH 𝑁subch ⋅ 𝑀subch, slot PSFCH PRBs are associated with the 𝑁subch PSSCH sub-channels of the corresponding PSSCH.

The PSFCH resources are first indexed according to an ascending order of the PRB index, from the 𝑁type PSFCH PRBs, and then according to an ascending order of the cyclic shift pair index from the 𝑁CS PSFCH cyclic shift pairs.

PSFCH ⋅ 𝑀subch, slot A UE determines an index of a PSFCH resource for a PSFCH transmission in response to a PSSCH reception as (𝑃 ID + 𝑀ID)𝑚𝑜𝑑𝑅PRB, CS PSFCH where 𝑃 ID is a physical layer source ID provided by SCI format 2-A or 2-B [5, TS 38.212] scheduling the PSSCH reception, and 𝑀ID is the identity of the UE receiving the PSSCH as indicated by higher layers if the UE detects a SCI format 2-A with Cast type indicator field value of "01"; otherwise, 𝑀ID is zero.

A UE determines a 𝑚0 value, for computing a value of cyclic shift 𝛼 [4, TS 38.211], from a cyclic shift pair index corresponding to a PSFCH resource index and from 𝑁CS PSFCH using Table 16.3-1.

**Table 16.3-1: Set of cyclic shift pairs** 𝒎 𝑵**CS** **PSFCH** **Cyclic Shift** **Cyclic Shift** **Cyclic Shift** **Cyclic Shift** **Cyclic Shift** **Cyclic Shift** **Pair Index 0** **Pair Index 1** **Pair Index 2** **Pair Index 3** **Pair Index 4** **Pair Index 5** 1 0 - - - - - 2 0 3 - - - - 3 0 2 4 - - - 6 0 1 2 3 4 5 A UE determines a 𝑚cs value, for computing a value of cyclic shift 𝛼 [4, TS 38.211], as in Table 16.3-2 if the UE detects a SCI format 2-A with Cast type indicator field value of "01" or "10", or as in Table 16.3-3 if the UE detects a SCI format 2-B or a SCI format 2-A with Cast type indicator field value of "11". The UE applies one cyclic shift from a cyclic shift pair to a sequence used for the PSFCH transmission [4, TS 38.211].

**Table 16.3-2: Mapping of HARQ-ACK information bit values to a cyclic shift, from a cyclic shift pair,** **of a sequence for a PSFCH transmission when HARQ-ACK information includes ACK or NACK** **HARQ-ACK Value** **0 (NACK) 1 (ACK)** **Sequence cyclic shift** 0 6

**Table 16.3-3: Mapping of HARQ-ACK information bit values to a cyclic shift, from a cyclic shift pair,** **of a sequence for a PSFCH transmission when HARQ-ACK information includes only NACK** **HARQ-ACK Value** **0 (NACK) 1 (ACK)** **Sequence cyclic shift** 0 N/A

#### 16.3.1 UE procedure for receiving HARQ-ACK on sidelink

A UE that transmitted a PSSCH scheduled by a SCI format 2-A or a SCI format 2-B that indicates HARQ feedback enabled, attempts to receive associated PSFCHs according to PSFCH resources determined as described in clause 16.3.

The UE determines an ACK or a NACK value for HARQ-ACK information provided in each PSFCH resource as described in [8-4, TS 38.101-4]. The UE does not determine both an ACK value and a NACK value at a same time for a PSFCH resource.

For each PSFCH reception occasion, from a number of PSFCH reception occasions, the UE generates HARQ-ACK information to report to higher layers. For generating the HARQ-ACK information, the UE can be indicated by a SCI format to perform one of the following

- if the UE receives a PSFCH associated with a SCI format 2-A with Cast type indicator field value of "10"
- report to higher layers HARQ-ACK information with same value as a value of HARQ-ACK information that the UE determines from the PSFCH reception
- if the UE receives a PSFCH associated with a SCI format 2-A with Cast type indicator field value of "01"
- report an ACK value to higher layers if the UE determines an ACK value from at least one PSFCH reception occasion from the number of PSFCH reception occasions in PSFCH resources corresponding to every identity 𝑀ID of UEs that the UE expects to receive corresponding PSSCHs as described in clause 16.3;

otherwise, report a NACK value to higher layers

- if the PSFCH reception occasion is associated with a SCI format 2-B or a SCI format 2-A with Cast type indicator field value of "11"
- report to higher layers an ACK value if the UE determines absence of PSFCH reception for the PSFCH reception occasion; otherwise, report a NACK value to higher layers

### 16.4 UE procedure for transmitting PSCCH

A UE can be provided a number of symbols in a resource pool, by _sl-TimeResourcePSCCH_, starting from a second symbol that is available for SL transmissions in a slot, and a number of PRBs in the resource pool, by _sl-FreqResourcePSCCH_, starting from the lowest PRB of the lowest sub-channel of the associated PSSCH, for a PSCCH transmission with a SCI format 1-A.

A UE that transmits a PSCCH with SCI format 1-A using sidelink resource allocation mode 2 [6, TS 38.214] sets - "Resource reservation period" as an index in _sl-ResourceReservePeriodList_ corresponding to a reservation period provided by higher layers [11, TS 38.321], if the UE is provided _sl-MultiReserveResource_

- the values of the frequency resource assignment field and the time resource assignment field as described in [6, TS 38.214] to indicate 𝑁 resources from a set {𝑅y} of resources selected by higher layers as described in [11, TS 38.321] with 𝑁 smallest slot indices 𝑦𝑖 for 0 ≤ 𝑖 ≤ 𝑁 − 1 such that 𝑦0 < 𝑦1 < ⋯ < 𝑦𝑁−1 ≤ 𝑦0 + 31, where:
- 𝑁 = min(𝑁selected, 𝑁max _ reserve), where 𝑁selected is a number of resources in the set {𝑅y} with slot indices 𝑦𝑗, 0 ≤ 𝑗 ≤ 𝑁selected− 1, such that 𝑦0 < 𝑦1 < ⋯ < 𝑦𝑁selected−1 ≤ 𝑦0 + 31, and 𝑁max reserve is provided _ by _sl-MaxNumPerReserve_
- each resource, from the set of {𝑅y} resources, corresponds to 𝐿subCH contiguous sub-channels and a slot in a set of slots {𝑡′ 𝑆𝐿}, where 𝐿subCH is the number of sub-channels available for PSSCH/PSCCH transmission in 𝑦 a slot
- (𝑡′ 𝑆𝐿 0, 𝑡′ 𝑆𝐿 1, 𝑡′ 𝑆𝐿 2,...) is a set of slots in a sidelink resource pool [6, TS 38.214]
- 𝑦0 is an index of a slot where the PSCCH with SCI format 1-A is transmitted.

A UE that transmits a PSCCH with SCI format 1-A using sidelink resource allocation mode 1 [6, TS 38.214] sets

- the values of the frequency resource assignment field and the time resource assignment field for the SCI format 1-A transmitted in the 𝑚-th resource for PSCCH/PSSCH transmission provided by a dynamic grant or by a SL configured grant, where 𝑚 = {1, …, 𝑀} and M is the total number of resources for PSCCH/PSSCH transmission provided by a dynamic grant or the number of resources for PSCCH/PSSCH transmission in a period provided by a SL configured grant type 1 or SL configured grant type 2, as follows:
- the frequency resource assignment field and time resource assignment field indicate the 𝑚-th to 𝑀-th resources as described in [6, TS 38.214].

For decoding of a SCI format 1-A, a UE may assume that a number of bits provided by _sl_-_NumReservedBits_ can have any value.

### 16.5 UE procedure for reporting HARQ-ACK on uplink

A UE can be provided PUCCH resources or PUSCH resources [12, TS 38.331] to report HARQ-ACK information that the UE generates based on HARQ-ACK information that the UE obtains from PSFCH receptions, or from absence of PSFCH receptions. The UE reports HARQ-ACK information on the primary cell of the PUCCH group, as described in clause 9, of the cell where the UE monitors PDCCH for detection of DCI format 3_0.

For SL configured grant Type 1 or Type 2 PSSCH transmissions by a UE within a time period provided by _sl-PeriodCG_, the UE generates one HARQ-ACK information bit in response to the PSFCH receptions to multiplex in a PUCCH transmission occasion that is after a last time resource, in a set of time resources.

For PSSCH transmissions scheduled by a DCI format 3_0, a UE generates HARQ-ACK information in response to PSFCH receptions to multiplex in a PUCCH transmission occasion that is after a last time resource in a set of time resources provided by the DCI format 3_0.

From a number of PSFCH reception occasions, the UE generates HARQ-ACK information to report in a PUCCH or PUSCH transmission. The UE can be indicated by a SCI format to perform one of the following and the UE constructs a HARQ-ACK codeword with HARQ-ACK information, when applicable

- for one or more PSFCH reception occasions associated with SCI format 2-A with Cast type indicator field value of "10"
- generate HARQ-ACK information with same value as a value of HARQ-ACK information the UE determines from the last PSFCH reception from the number of PSFCH reception occasions corresponding to PSSCH transmissions or, if the UE determines that a PSFCH is not received at the last PSFCH reception occasion and ACK is not received in any of previous PSFCH reception occasions, generate NACK
- for one or more PSFCH reception occasions associated with SCI format 2-A with Cast type indicator field value of "01"
- generate ACK if the UE determines ACK from at least one PSFCH reception occasion, from the number of PSFCH reception occasions corresponding to PSSCH transmissions, in PSFCH resources corresponding to every identity 𝑀ID of the UEs that the UE expects to receive the PSSCH, as described in clause 16.3;

otherwise, generate NACK

- for one or more PSFCH reception occasions associated with SCI format 2-B or SCI format 2-A with Cast type indicator field value of "11"
- generate ACK when the UE determines absence of PSFCH reception for the last PSFCH reception occasion from the number of PSFCH reception occasions corresponding to PSSCH transmissions; otherwise, generate NACK After a UE transmits PSSCHs and receives PSFCHs in corresponding PSFCH resource occasions, the priority value of HARQ-ACK information is same as the priority value of the PSSCH transmissions that is associated with the PSFCH reception occasions providing the HARQ-ACK information.

The UE generates a NACK when, due to prioritization, as described in clause 16.2.4, the UE does not receive PSFCH in any PSFCH reception occasion associated with a PSSCH transmission in a resource provided by a DCI format 3_0 and the UE transmitted PSSCH in the resource or, for a configured grant, in a resource provided in a single period and for which the UE is provided a PUCCH resource to report HARQ-ACK information and the UE transmitted PSSCH in the resource. The priority value of the NACK is same as the priority value of the PSSCH transmission.

The UE generates a NACK when, due to prioritization as described in clause 16.2.4, the UE does not transmit a PSSCH in any of the resources provided by a DCI format 3_0 or, for a configured grant, in any of the resources provided in a single period and for which the UE is provided a PUCCH resource to report HARQ-ACK information. The priority value of the NACK is same as the priority value of the PSSCH that was not transmitted due to prioritization.

The UE generates an ACK if the UE does not transmit a PSCCH with a SCI format 1-A scheduling a PSSCH in any of the resources provided by a configured grant in a single period and for which the UE is provided a PUCCH resource to report HARQ-ACK information. The priority value of the ACK is same as the largest priority value among the possible priority values for the configured grant.

The UE generates an ACK if the UE does not transmit a PSCCH with a SCI format 1-A scheduling a PSSCH in any of the resources provided by a DCI format 3_0 and for which the UE is provided a PUCCH resource to report HARQ- ACK information. The priority value of the ACK is same as the largest priority value among the possible priority values for the dynamic grant.

For reporting HARQ-ACK information on uplink corresponding to one or multiple PSSCH transmissions with a corresponding SCI format with the field 'HARQ feedback enabled/disabled indicator' set to disabled, the UE generates HARQ-ACK information with the contents instructed by higher layer. The priority value of the HARQ-ACK information is same as the priority value of the PSSCH transmission.

A UE does not expect to be provided PUCCH resources or PUSCH resources to report HARQ-ACK information that start earlier than 𝑇 𝑝𝑟𝑒𝑝 = (𝑁 + 1) ∙ (2048 + 144) ∙ 𝜅 ∙ 2−𝜇∙ 𝑇 𝑐 after the end of a last symbol of a last PSFCH reception occasion, from a number of PSFCH reception occasions that the UE generates HARQ-ACK information to report in a PUCCH or PUSCH transmission, where

- 𝜅 and 𝑇 𝑐 are defined in [4, TS 38.211]
- 𝜇 = min (𝜇𝑆𝐿, 𝜇𝑈𝐿), where 𝜇𝑆𝐿 is the SCS configuration of the SL BWP and 𝜇𝑈𝐿 is the SCS configuration of the active UL BWP on the primary cell
- 𝑁 is determined from 𝜇 according to Table 16.5-1

**Table 16.5-1: Values of** 𝑵 𝝁 𝑵 0 14 1 18 2 28 3 32 For DCI format 3_0, if present, the PSFCH-to-HARQ feedback timing indicator field values map to values for a set of number of slots provided by _sl-PSFCH-ToPUCCH_ as defined in Table 16.5-2.

**Table 16.5-2: Mapping of PSFCH-to-HARQ feedback timing indicator field values to numbers of slots** **PSFCH-to-HARQ feedback timing indicator** **Number of slots** _k_ 1 bit 2 bits 3 bits '0' '00' '000' 1st value provided by _sl-PSFCH-ToPUCCH_ '1' '01' '001' 2nd value provided by _sl-PSFCH-ToPUCCH_ '10' '010' 3rd value provided by _sl-PSFCH-ToPUCCH_ '11' '011' 4th value provided by _sl-PSFCH-ToPUCCH_ '100' 5th value provided by _sl-PSFCH-ToPUCCH_ '101' 6th value provided by _sl-PSFCH-ToPUCCH_ '110' 7th value provided by _sl-PSFCH-ToPUCCH_ '111' 8th value provided by _sl-PSFCH-ToPUCCH_ With reference to slots for PUCCH transmissions and for a number of PSFCH reception occasions ending in slot 𝑛, the UE provides the generated HARQ-ACK information in a PUCCH transmission within slot 𝑛 + 𝑘, subject to the overlapping conditions in clause 9.2.5, where 𝑘 is a number of slots indicated by a PSFCH-to-HARQ feedback timing indicator field, if present, in a DCI format indicating a slot for PUCCH transmission to report the HARQ-ACK information, or 𝑘 is provided by _sl-PSFCH-ToPUCCH_ for a transmission scheduled by a DCI format or for a SL configured grant type 2, or by _sl-PSFCH-ToPUCCH-CG-Type1_ for a SL configured grant type 1. 𝑘 = 0 corresponds to a last slot for a PUCCH transmission that would overlap with the last PSFCH reception occasion assuming that the start of the sidelink frame is same as the start of the downlink frame [4, TS 38.211].

For a PSSCH transmission by a UE that is scheduled by a DCI format, or for a SL configured grant Type 2 PSSCH transmission activated by a DCI format, the DCI format indicates to the UE that a PUCCH resource is not provided when a value of the PUCCH resource indicator field is zero and a value of PSFCH-to-HARQ feedback timing indicator field, if present, is zero. For a SL configured grant Type 2 PSSCH transmission without a corresponding PDCCH, the DCI format activating the SL configured grant Type 2 indicates to the UE that a PUCCH resource is not provided when a value of the PUCCH resource indicator field is zero and a value of PSFCH-to-HARQ feedback timing indicator field, if present, is zero. For a SL configured grant Type 1 PSSCH transmission, a PUCCH resource can be provided by _sl-N1PUCCH-AN_ and _sl-PSFCH-ToPUCCH-CG-Type1_. For transmission of HARQ-ACK information corresponding only to a SL configured grant Type 2 PSSCH transmission, including the PSSCH transmission(s) associated with the corresponding activation DCI format 3_ 0, a UE can be provided a PUCCH resource by _sl-N1PUCCH-AN-Type2_. If a PUCCH resource is not provided, the UE does not transmit a PUCCH with generated HARQ-ACK information from PSFCH reception occasions.

For a PUCCH transmission with HARQ-ACK information, a UE determines a PUCCH resource after determining a set of PUCCH resources from up to four PUCCH resource sets provided by _sl-PUCCH-Config_, for 𝑂𝑈𝐶𝐼 HARQ-ACK information bits, as described in clause 9.2.1. The PUCCH resource determination is based on a PUCCH resource indicator field [5, TS 38.212] in a last DCI format 3_0, excluding DCI format 3_0 for the SL configured grant Type 2 activation, among the DCI formats 3_0 that have a value of a PSFCH-to-HARQ feedback timing indicator field indicating a same slot for the PUCCH transmission, that the UE detects and for which the UE transmits corresponding HARQ-ACK information in the PUCCH where, for PUCCH resource determination, detected DCI formats are indexed in an ascending order across PDCCH monitoring occasion indexes.

The PUCCH resource indicator field values map to values of a set of PUCCH resource indexes, as described in clause 9.2.3.

A UE transmits a PUCCH with HARQ-ACK information using PUCCH format 0 or PUCCH format 1 or PUCCH format 2 or PUCCH format 3 or PUCCH format 4 as described in clause 9.2.3.

A UE does not expect to multiplex HARQ-ACK information for more than one SL configured grants in a same PUCCH.

A priority value of a PUCCH transmission with one or more sidelink HARQ-ACK information bits is the smallest priority value for the one or more HARQ-ACK information bits.

In the following, the CRC for DCI format 3_0 is scrambled with a SL-RNTI or a SL-CS-RNTI.

#### 16.5.1 Type-1 HARQ-ACK codebook determination

This clause applies if the UE is configured with _pdsch-HARQ-ACK-Codebook = semi-static_.

If a UE is configured a SL configured grant Type 1, and the UE is configured a SL configured grant Type 2 or to monitor PDCCH for detection of DCI format 3_0 with CRC scrambled by SL-RNTI or SL-CS-RNTI, and the UE is provided a set of slot timing values 𝐾1 associated with a SL BWP by _sl-PSFCH-ToPUCCH_ and _sl-PSFCH-ToPUCCH-CG-Type1_, the _sl-PSFCH-ToPUCCH-CG-Type1_ is one of _sl-PSFCH-ToPUCCH_.

A UE reports HARQ-ACK information for PSSCH transmissions with corresponding PSFCH reception occasions in slot 𝑛 only in a HARQ-ACK codebook that the UE includes in a PUCCH or PUSCH transmission in slot 𝑛 + 𝑘, where 𝑘 is a number of slots indicated by the PSFCH-to-HARQ feedback timing indicator field in a DCI format 3_0 scheduling the PSSCH transmissions, or by a value of PSFCH-to-HARQ feedback timing indicator field in a DCI format 3_0 activating a SL configured grant Type-2 transmission, or by a value of _sl-PSFCH-ToPUCCH-CG-Type1_ for a SL configured grant Type-1. If the UE reports HARQ-ACK information for the PSSCH transmissions with corresponding PSFCH reception occasions in a slot other than slot 𝑛 + 𝑘, the UE sets a value for each corresponding HARQ-ACK information bit to NACK.

If a UE reports HARQ-ACK information in a PUCCH only for

- PSFCH reception occasions associated with PSSCH transmissions scheduled by a DCI format 3_0 with counter SAI field value of 1, or
- PSFCH reception occasions associated with PSSCH transmissions corresponding to a SL configured grant within a set 𝑀𝐴 of occasions for candidate PSSCH transmissions with corresponding PSFCH reception occasions as determined in clause 16.5.1.1, the UE determines a HARQ-ACK codebook only for the PSFCH reception occasion associated with PSSCH transmissions scheduled by DCI format 3_0 or only for the PSFCH reception occasion associated with PSSCH transmissions corresponding to a SL configured grant according to corresponding set 𝑀𝐴 of occasions, where a value of a counter SAI in DCI format 3_0 is according to Table 16.5.2.1-1. Otherwise, the procedures in clause 16.5.1.1 and in clause 16.5.1.2 for a HARQ-ACK codebook determination apply.

##### 16.5.1.1 Type-1 HARQ-ACK codebook in physical uplink control channel

For a SL BWP on a carrier, and an active UL BWP on the primary cell, as described in clause 12, a UE determines a set 𝑀𝐴 of occasions for candidate PSSCH transmissions with corresponding PSFCH reception occasions for which the UE can multiplex corresponding HARQ-ACK information in a PUCCH transmission in slot 𝑛𝑈. The determination is based on:

  a) a set of slot timing values 𝐾1 associated with the SL BWP where 𝐾1 is provided by _sl-PSFCH-ToPUCCH_ for DCI format 3_0 or by _sl-PSFCH-ToPUCCH-CG-Type1_
  b) the ratio 2𝜇SL−𝜇UL between the sidelink SCS configuration 𝜇SL and the uplink SCS configuration 𝜇UL provided by _subcarrierSpacing_ in _SL-BWP-Config_ _or SL-BWP-ConfigCommon_ and _BWP-Uplink_ for the SL BWP and the active UL BWP, respectively
  c) a configured sidelink resource pool bitmap
  d) a value of a period of PSFCH transmission occasion resources for a sidelink resource pool provided by a respective _sl-PSFCH-Period_ For the set of slot timing values 𝐾1, the UE determines a set 𝑀𝐴 corresponding PSFCH reception occasions according to the following pseudo-code.

of occasions for candidate PSSCH transmissions with Set 𝑗 = 0 - index of occasion for candidate PSSCH transmissions with corresponding PSFCH reception occasions Set 𝑀𝐴 = ∅ Set C(𝐾1) to the cardinality of set 𝐾1 Set 𝑘 = 0 – index of slot timing values 𝐾1,𝑘, in descending order of the slot timing values, in set 𝐾1 Set 𝑁𝑃𝑆𝐹𝐶𝐻 to the value of the period of PSFCH transmission occasion resources for the sidelink resource pool while 𝑘 < C(𝐾1) if 𝑚𝑜𝑑 (𝑛𝑈− 𝐾1,𝑘 + 1, 𝑚𝑎𝑥(2𝜇UL−𝜇SL, 1)) = 0 Set 𝑛𝑆 = 0 – index of a SL slot within an UL slot while 𝑛𝑆 < 𝑚𝑎𝑥(2𝜇SL−𝜇UL, 1) if slot 𝑛𝑈 starts at a same time as or after a slot for an active UL BWP change on the PCell and slot ⌊(𝑛𝑈− 𝐾1,𝑘) ⋅ 2𝜇SL−𝜇UL ⌋ + 𝑛𝑆 is before the slot for the active UL BWP change on the PCell 𝑛𝑆 = 𝑛𝑆 + 1;

else if slot ⌊(𝑛𝑈− 𝐾1,𝑘) ⋅ 2𝜇SL−𝜇UL ⌋ + 𝑛𝑆 belongs to the sidelink resource pool and includes PSFCH resources as indicated by a sidelink resource pool bitmap and _sl-PSFCH-Period_, where 𝐾1,𝑘 is the _k_-th slot timing value in set 𝐾1 Set 𝑛𝐹 = 0 – index of a SL slot within an PSFCH period while 𝑛𝐹 < 𝑁𝑃𝑆𝐹𝐶𝐻 𝑀𝐴 = 𝑀𝐴 ∪ 𝑗;

𝑗 = 𝑗 + 1;

𝑛𝐹 = 𝑛𝐹 + 1;

end while end if 𝑛𝑆 = 𝑛𝑆 + 1;

end if end while end if 𝑘 = 𝑘 + 1;

end while The cardinality of the set 𝑀𝐴 defines a total number 𝑀 of occasions for candidate PSSCH transmissions with corresponding PSFCH reception occasions corresponding to the HARQ-ACK information bits. A UE determines ̃ 𝐴𝐶𝐾 ̃ 𝐴𝐶𝐾 ̃ 𝑜 0, 𝑜 1, …, 𝑜 𝐴𝐶𝐾 HARQ-ACK information bits, for a total number of 𝑂ACK 𝑂ACK−1 HARQ-ACK information bits as ̃ 𝑜 𝑗 𝐴𝐶𝐾 = HARQ-ACK information bit for candidate PSSCH transmission with index 𝑗 with corresponding PSFCH reception, for 0 ≤ 𝑗 < 𝑀, as described in clause 16.5. If the UE does not transmit a PSSCH in an occasion for candidate PSSCH transmission with corresponding PSFCH reception occasion, due to the UE not detecting a corresponding DCI format 3_0, the UE generates a NACK value for the occasion for candidate PSSCH transmission with corresponding PSFCH reception occasion.

If 𝑂ACK ≤ 11, the UE determines a number of HARQ-ACK information bits 𝑛HARQ−ACK for obtaining a transmission power for a PUCCH, as described in clause 7.2.1, as 𝑛HARQ-ACK = ∑ M−1 m=0 where 𝑁𝑚 𝑁m received received is a number of HARQ-ACK information bits determined for corresponding PSSCH transmissions with corresponding PSFCH reception occasions in PSFCH reception occasion 𝑚.

##### 16.5.1.2 Type-1 HARQ-ACK codebook in physical uplink shared channel

If a UE would multiplex HARQ-ACK information in a PUSCH transmission that is not scheduled by a DCI format or is scheduled by a DCI format without an SAI field, then

- if the UE
- has not received any PDCCH with a DCI format 3_0 scheduling PSSCH transmissions with corresponding PSFCH reception occasions that the UE transmits corresponding HARQ-ACK information in the PUSCH, based on a value of a respective PSFCH-to-HARQ feedback timing indicator field in a DCI format scheduling the PSSCH transmissions or on the value of PSFCH-to-HARQ feedback timing indicator field in a DCI format 3_0 activating a SL configured grant Type 2 transmission, or
- has not been provided PSSCH resources with corresponding PSFCH reception occasions that the UE transmits corresponding HARQ-ACK information based on the value of _sl-PSFCH-ToPUCCH-CG-Type1_ for a SL configured grant Type 1, then in any of the set 𝑀𝐴 of occasions for candidate PSSCH transmissions with corresponding PSFCH reception occasions, as described in clause 16.5.1.1, the UE does not multiplex HARQ-ACK information in the PUSCH transmission;
- else the UE generates the HARQ-ACK codebook as described in clause 16.5.1.1, unless the UE generates HARQ-ACK information only for
- PSFCH reception occasions associated with PSSCH transmissions corresponding to a SL configured grant, or
- PSFCH reception occasions associated with PSSCH transmissions that are scheduled by DCI format 3_0 with a counter SAI field value of 1, in the set 𝑀𝐴 of occasions for candidate PSSCH transmissions with corresponding PSFCH reception occasions, in which case the UE generates HARQ-ACK information only for the PSFCH reception occasions as described in clause 16.5.1.

A UE sets to NACK value in the HARQ-ACK codebook any HARQ-ACK information corresponding to PSFCH reception occasions associated with PSSCH transmissions scheduled by a DCI format 3_0 that the UE detects in a PDCCH monitoring occasion that starts after a PDCCH monitoring occasion where the UE detects a DCI format scheduling the PUSCH transmission.

If a UE multiplexes HARQ-ACK information in a PUSCH transmission that is scheduled by a DCI format that includes a SAI field, the UE generates the HARQ-ACK codebook as described in clause 16.5.1.1 when a value of the SAI field UL in the DCI format is 𝑉𝑇−SAI = 1. The UE does not generate a HARQ-ACK codebook for multiplexing in the PUSCH UL transmission when 𝑉𝑇−SAI = 0 unless the UE generates HARQ-ACK information only for

- PSFCH reception occasions associated with PSSCH transmissions corresponding to a SL configured grant, or
- PSFCH reception occasions associated with PSSCH transmissions that are scheduled by a DCI format 3_0 with a counter SAI field value of 1, in the set 𝑀𝐴 of occasions for candidate PSSCH transmissions with corresponding PSFCH reception occasions as described in clause 16.5.1.

𝑉𝑇−SAI UL = 0 if the SAI field in the DCI format is set to '0'; otherwise, 𝑉𝑇−SAI UL = 1.

#### 16.5.2 Type-2 HARQ-ACK codebook determination

This clause applies if the UE is configured with _pdsch-HARQ-ACK-Codebook = dynamic_.

##### 16.5.2.1 Type-2 HARQ-ACK codebook in physical uplink control channel

A UE determines monitoring occasions for PDCCH with DCI format 3_0 for scheduling PSSCH transmissions with associated PSFCH reception occasions on an active DL BWP of a serving cell 𝑐, as described in clause 10.1, and for which the UE transmits HARQ-ACK information in a same PUCCH in slot 𝑛 based on

- PSFCH-to-HARQ feedback timing indicator field values, or a value provided by _sl-PSFCH-ToPUCCH-CG-Type1_, for PUCCH transmission with HARQ-ACK information in slot 𝑛 in response to PSFCH receptions;
- time gap field in DCI format 3_0 for scheduling PSSCH transmissions with associated PSFCH receptions;
- time resource assignment in DCI format 3_0 for scheduling PSSCH transmissions with associated PSFCH receptions;
- a configured sidelink resource pool bitmap;
- a value of a period of PSFCH resources provided in _sl-PSFCH-Period_;
- a value of a minimum time gap provided in _sl-MinTimeGapPSFCH_.

The set of PDCCH monitoring occasions for DCI format 3_0 for scheduling PSSCH transmissions with associated PSFCH reception occasions is defined as the PDCCH monitoring occasions in the active DL BWP of the configured serving cell, indexed in ascending order of start time of the associated search space sets. The cardinality of the set of PDCCH monitoring occasions defines a total number 𝑀 of PDCCH monitoring occasions. A UE is not expected to receive a DCI format 3 _0 with CRC scrambled by SL-RNTI and a DCI format 3 _ 0 with CRC scrambled by SL-CS- RNTI for scheduling retransmission corresponding to a SL configured grant Type 1 or a sidelink configured grant Type 2 simultaneously in a same monitoring occasion.

A value of a counter sidelink assignment indicator (SAI) field in DCI format 3_0, excluding DCI format 3_0 for the SL configured grant Type 2 activation, denotes an accumulative number of PDCCH monitoring occasions where PSSCH transmissions with associated PSFCH receptions are scheduled, up to a current PDCCH monitoring occasion, in ascending order of PDCCH monitoring occasion index 𝑚, where 0 ≤ 𝑚 < 𝑀.

Denote by 𝑉 𝐶−SAI,𝑚 SL the value of the counter SAI in DCI format 3_0 in PDCCH monitoring occasion 𝑚 according to Table 16.5.2.1-1.

If the UE transmits HARQ-ACK information in a PUCCH in slot 𝑛, the UE determines the 𝑜 ̃ 𝐴𝐶𝐾 ̃ 𝐴𝐶𝐾 ̃ 𝐴𝐶𝐾 0, 𝑜 1, …, 𝑜 𝑂ACK−1, for a total number of 𝑂ACK HARQ-ACK information bits, according to the following pseudo-code:

Set 𝑚 = 0 – PDCCH with DCI format 3_0 monitoring occasion index: lower index corresponds to earlier PDCCH with DCI format 3_0 monitoring occasion Set 𝑗 = 0 Set 𝑉 𝑡𝑒𝑚𝑝 = 0 Set 𝑉 𝑠 = ∅ Set 𝑀 to the number of PDCCH monitoring occasions while 𝑚 < 𝑀 if PDCCH monitoring occasion 𝑚 is before an active UL BWP change on the PCell 𝑚 = 𝑀;

else if there is a PSFCH reception occasion associated with a PSSCH transmission scheduled by a DCI format in PDCCH monitoring occasion 𝑚 if 𝑉 𝐶−SAI,𝑚 SL ≤ 𝑉 𝑡𝑒𝑚𝑝 𝑗 = 𝑗 + 1;

end if SL 𝑉 𝑡𝑒𝑚𝑝 = 𝑉 𝐶−SAI,𝑚 ̃ 𝐴𝐶𝐾 𝑜 𝑆𝐿 = HARQ-ACK information bit 4𝑗+𝑉 𝐶−𝑆𝐴𝐼,𝑚 −1 𝑉 𝑠 SL = 𝑉 𝑠 ∪ {4𝑗 + 𝑉 𝐶−SAI,𝑚 − 1} end if end if 𝑚 = 𝑚 + 1;

end while 𝑂𝐴𝐶𝐾 = 4 ⋅ 𝑗 + 𝑉𝑡𝑒𝑚𝑝 ̃ 𝑜 𝑖 𝐴𝐶𝐾 = 𝑁𝐴𝐶𝐾 for any 𝑖 ∈ {0,1, …, 𝑂𝐴𝐶𝐾− 1}\𝑉 𝑠 if a SL configured grant Type 1 is configured for a UE, or a SL configured grant Type 2 is configured and activated for a UE, and the SL configured grant provides a grant for PSSCH transmissions, including the PSSCH transmission(s) associated with the corresponding activation DCI format 3_0, with PSFCH reception occasions in a slot 𝑛 − 𝐾1, where 𝐾1 is the 𝑘 value for the SL configured grant as described in clause 16.5 𝑂𝐴𝐶𝐾 = 𝑂𝐴𝐶𝐾 + 1;

𝑜̃ 𝐴𝐶𝐾 𝑂𝐴𝐶𝐾−1 = HARQ-ACK information bit associated with the PSFCH reception occasions associated with the PSSCH transmissions scheduled by the SL configured grant end if If 𝑂ACK ≤ 11, the UE determines a number of HARQ-ACK information bits 𝑛HARQ−ACK for obtaining a transmission power for a PUCCH, as described in clause 7.2.1, as SL nHARQ-ACK = (𝑉 SAI,mlast M−1 − 𝑈SAI) mod 4 + ∑ 𝑁m received m=0 + 𝑁CG where SL - 𝑉 SAI,𝑚last is a value of a counter SAI field in a last DCI format 3_0, excluding the DCI format 3_0 activating a SL configured grant, scheduling PSSCH transmissions associated with PSFCH reception occasions that the UE detects within the 𝑀 PDCCH monitoring occasions SL - 𝑉 SAI,𝑚last = 0 if the UE does not detect any DCI format 3_0, excluding the DCI format 3_0 activating a SL configured grant, scheduling PSSCH transmissions associated with PSFCH reception occasions in any of the 𝑀 PDCCH monitoring occasions

- 𝑈SAI is a total number of DCI format 3_0, excluding the DCI format 3_0 activating a SL configured grant, scheduling PSSCH transmissions associated with PSFCH reception occasions, that the UE detects within the 𝑀 PDCCH monitoring occasions. 𝑈SAI = 0 if the UE does not detect any DCI format 3_0, excluding the DCI format 3_0 activating a SL configured grant, scheduling PSSCH transmissions with associated PSFCH reception occasions in any of the 𝑀 PDCCH monitoring occasions
- 𝑁𝑚 received is a number of DCI format 3_0, excluding the DCI format 3_0 activating a SL configured grant, scheduling PSSCH transmissions with associated PSFCH reception occasions that the UE detects in PDCCH monitoring occasion 𝑚
- 𝑁CG is a number of SL configured grants for which the UE transmits corresponding HARQ-ACK information in a same PUCCH as for HARQ-ACK information corresponding to PSFCH reception occasions associated with PSSCH transmissions scheduled by a dynamic grant within the 𝑀 PDCCH monitoring occasions

**Table 16.5.2.1-1: Value of counter SAI in DCI format 3_0** **Number of PDCCH monitoring occasions in which DCI format 3_0** **scheduling PSSCH transmissions with corresponding PSFCH reception** **occasions is present, denoted as** 𝒀 **and** 𝒀 ≥ 𝟏 **SAI** **MSB, LSB** SL 𝑽𝑪−𝑺AI 0,0 1 (𝑌 − 1)𝑚𝑜𝑑4 + 1 = 1 0,1 2 (𝑌 − 1)𝑚𝑜𝑑4 + 1 = 2 1,0 3 (𝑌 − 1)𝑚𝑜𝑑4 + 1 = 3 1,1 4 (𝑌 − 1)𝑚𝑜𝑑4 + 1 = 4

##### 16.5.2.2 Type-2 HARQ-ACK codebook in physical uplink shared channel

If a UE would multiplex HARQ-ACK information in a PUSCH transmission that is not scheduled by a DCI format or is scheduled by a DCI format without an SAI field, then

- if the UE
- has not received any PDCCH within the monitoring occasions for DCI format 3_0 for scheduling PSSCH with corresponding PSFCH reception occasions on any serving cell, and
- does not have HARQ-ACK information in response to a PSSCH transmission with corresponding PSFCH reception occasions associated with a SL configured grant to multiplex in the PUSCH, as described in clause 16.5.2.1, the UE does not multiplex HARQ-ACK information in the PUSCH transmission;
- else, the UE generates and multiplexes in the PUSCH transmission the HARQ-ACK codebook as described in clause 16.5.2.1.

If a UE multiplexes HARQ-ACK information in a PUSCH transmission that is scheduled by a DCI format that includes a SAI field, the UE generates the HARQ-ACK codebook as described in clause 16.5.2.1, with the following modifications:

- For the pseudo-code for the HARQ-ACK codebook generation in clause 16.5.2.1, after the completion of the 𝑚 loop, the UE sets 𝑉 𝑡𝑒𝑚𝑝 = 𝑉 T-SAI UL UL where 𝑉 T-SAI is the value of the SAI field in the DCI format according to Table 16.5.2.2-1.

If a UE

- is scheduled for a PUSCH transmission by a DCI format that includes a SAI field with value 𝑉 T-SAI UL = 4, and
- has not received any PDCCH within the monitoring occasions for PDCCH with DCI format 3_0 for scheduling PSSCH with corresponding PSFCH reception occasions on a serving cell, and
- does not have HARQ-ACK information in response to PSFCH reception occasions associated with a SL configured grant to multiplex in the PUSCH, as described in clause 16.5.2.1, the UE does not multiplex HARQ-ACK information in the PUSCH transmission.

**Table 16.5.2.2-1: Value of SAI**

| | | |
|---|---|---|
|SAI<br><br>MSB, LSB|UL<br><br>𝑽T-SAI|Number of PDCCH monitoring occasions in which DCI format 3_0<br><br>scheduling PSSCH transmissions with corresponding PSFCH reception<br><br>occasions is present, denoted as 𝑿 and 𝑿 ≥ 𝟏|
|0,0|1|(𝑋 − 1)𝑚𝑜𝑑4 + 1 = 1|
|0,1|2|(𝑋 − 1)𝑚𝑜𝑑4 + 1 = 2|
|1,0|3|(𝑋 − 1)𝑚𝑜𝑑4 + 1 = 3|
|1,1||4 (𝑋 − 1)𝑚𝑜𝑑4 + 1 = 4|
