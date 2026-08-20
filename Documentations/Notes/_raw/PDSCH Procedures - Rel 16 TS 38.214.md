
8 Physical sidelink shared channel related procedures

A UE can be configured by higher layers with one or more sidelink resource pools. A sidelink resource pool can be for

transmission of PSSCH, as described in Clause 8.1, or for reception of PSSCH, as described in Clause 8.3 and can be

associated with either sidelink resource allocation mode 1 or sidelink resource allocation mode 2.

In the frequency domain, a sidelink resource pool consists of _sl-NumSubchannel_ contiguous sub-channels. A sub-

channel consists of _sl-SubchannelSize_ contiguous PRBs, where _sl-NumSubchannel_ and _sl-SubchannelSize_ are higher

layer parameters.

The set of slots that may belong to a sidelink resource pool is denoted by (𝑡0

𝑆𝐿

,𝑡1

𝑆𝐿

,

⋯

,𝑡𝑇𝑚𝑎𝑥−1

𝑆𝐿 ) where

- 0≤𝑡𝑖

𝑆𝐿 <10240×2𝜇

,0≤𝑖<𝑇𝑚𝑎𝑥,

- the slot index is relative to slot#0 of the radio frame corresponding to SFN 0 of the serving cell or DFN 0,

- the set includes all the slots except the following slots,

- 𝑁𝑆−𝑆𝑆𝐵 slots in which S-SS/PSBCH block (S-SSB) is configured,

- 𝑁𝑛𝑜𝑛𝑆𝐿 slots in each of which at least one of _Y-th_, _(Y+1)-th_, …, _(Y+X-1)-th_ OFDM symbols are not semi-

statically configured as UL as per the higher layer parameter _tdd-UL-DL-ConfigurationCommon_ of the

serving cell if provided or _sl-TDD-Configuration_ if provided or _sl-TDD-Config_ of the received PSBCH if

provided, where _Y_ and _X_ are set by the higher layer parameters _sl-StartSymbol_ and _sl-LengthSymbols_,

respectively.

- The reserved slots which are determined by the following steps.

1) the remaining slots excluding 𝑁𝑆−𝑆𝑆𝐵 slots and 𝑁𝑛𝑜𝑛𝑆𝐿 slots from the set of all the slots are denoted by

(𝑙0,𝑙1,

⋯

,𝑙(10240×2𝜇−𝑁𝑆−𝑆𝑆𝐵 −𝑁𝑛𝑜𝑛𝑆𝐿−1)) arranged in increasing order of slot index.

2) a slot 𝑙𝑟 (0≤𝑟<10240×2𝜇−𝑁𝑆−𝑆𝑆𝐵−𝑁𝑛𝑜𝑛𝑆𝐿) belongs to the reserved slots if 𝑟=

⌊𝑚∙(10240×2𝜇−𝑁𝑆−𝑆𝑆𝐵−𝑁𝑛𝑜𝑛𝑆𝐿)

𝑁𝑟𝑒𝑠𝑒𝑟𝑣𝑒𝑑 ⌋, here 𝑚=0,1,

⋯

,𝑁𝑟𝑒𝑠𝑒𝑟𝑣𝑒𝑑−1 and 𝑁𝑟𝑒𝑠𝑒𝑟𝑣𝑒𝑑 =(10240×2𝜇−

𝑁𝑆−𝑆𝑆𝐵−𝑁𝑛𝑜𝑛𝑆𝐿) 𝑚𝑜𝑑 𝐿𝑏𝑖𝑡𝑚𝑎𝑝 where 𝐿𝑏𝑖𝑡𝑚𝑎𝑝 denotes the length of bitmap configured by higher

layers.

- The slots in the set are arranged in increasing order of slot index.

The UE determines the set of slots assigned to a sidelink resource pool as follows:

- a bitmap (𝑏0,𝑏1,…,𝑏𝐿𝑏𝑖𝑡𝑚𝑎𝑝−1) associated with the resource pool is used where 𝐿𝑏𝑖𝑡𝑚𝑎𝑝 the length of the

bitmap is configured by higher layers.

- a slot 𝑡𝑘

𝑆𝐿 (0≤𝑘<10240×2𝜇−𝑁𝑆−𝑆𝑆𝐵−𝑁𝑛𝑜𝑛𝑆𝐿−𝑁𝑟𝑒𝑠𝑒𝑟𝑣𝑒𝑑) belongs to the set if 𝑏𝑘′ =1 where 𝑘′ =

𝑘 𝑚𝑜𝑑 𝐿𝑏𝑖𝑡𝑚𝑎𝑝.

**_3GPP_****Release 16**

**156**

**3GPP TS 38.214 V16.17.0 (2024-06)**

- The slots in the set are re-indexed such that the subscripts _i_ of the remaining slots 𝑡′

𝑆𝐿 are successive {0, 1, …,

𝑖

𝑇′

𝑚𝑎𝑥−1} where 𝑇′

𝑚𝑎𝑥 is the number of the slots remaining in the set.

The UE determines the set of resource blocks assigned to a sidelink resource pool as follows:

- The resource block pool consists of 𝑁𝑃𝑅𝐵 PRBs.

- The sub-channel _m_ for 𝑚=0,1,

⋯

,𝑛𝑢𝑚𝑆𝑢𝑏𝑐ℎ𝑎𝑛𝑛𝑒𝑙−1 consists of a set of 𝑛𝑠𝑢𝑏𝐶𝐻𝑠𝑖𝑧𝑒 contiguous resource

blocks with the physical resource block number 𝑛𝑃𝑅𝐵 =𝑛𝑠𝑢𝑏𝐶𝐻𝑅𝐵𝑠𝑡𝑎𝑟𝑡 +𝑚∙𝑛𝑠𝑢𝑏𝐶𝐻𝑠𝑖𝑧𝑒 +𝑗 for 𝑗=

0,1,

⋯

,𝑛𝑠𝑢𝑏𝐶𝐻𝑠𝑖𝑧𝑒−1, where 𝑛𝑠𝑢𝑏𝐶𝐻𝑅𝐵𝑠𝑡𝑎𝑟𝑡 and 𝑛𝑠𝑢𝑏𝐶𝐻𝑠𝑖𝑧𝑒 are given by higher layer parameters _sl-StartRB-_

_Subchannel_ and _sl-SubchannelSize_, respectively

A UE is not expected to use the last 𝑁𝑃𝑅𝐵 mod 𝑛𝑠𝑢𝑏𝐶𝐻𝑠𝑖𝑧𝑒 PRBs in the resource pool.

8.1 UE procedure for transmitting the physical sidelink shared

channel

Each PSSCH transmission is associated with an PSCCH transmission.

That PSCCH transmission carries the 1st stage of the SCI associated with the PSSCH transmission; the 2nd stage of the

associated SCI is carried within the resource of the PSSCH.

If the UE transmits SCI format 1-A on PSCCH according to a PSCCH resource configuration in slot _n_ and PSCCH

resource _m_, then for the associated PSSCH transmission in the same slot

- one transport block is transmitted with up to two layers;

- The number of layers (ʋ) is determined according to the '_Number of DMRS port'_ field in the SCI;

- The set of consecutive symbols within the slot for transmission of the PSSCH is determined according to clause

8.1.2.1;

- The set of contiguous resource blocks for transmission of the PSSCH is determined according to clause 8.1.2.2;

Transform precoding is not supported for PSSCH transmission.

Only wideband precoding is supported for PSSCH transmission.

The DM-RS antenna ports in Clause 8.4.1.1.2 of [4, TS38.211] are determined according to the ordering

of DM-RS port(s) given by Tables 8.3.1.1-3 in Clause 8.3.1.1 of [5, TS 38.212].

The UE shall set the contents of the SCI format 2-A as follows:

- the UE shall set value of the _'HARQ process number'_ field as indicated by higher layers.

- the UE shall set value of the '_NDI_' field as indicated by higher layers.

- the UE shall set value of the '_Redundancy version_' field as indicated by higher layers.

- the UE shall set value of the '_Source ID_' field as indicated by higher layers.

- the UE shall set value of the '_Destination ID_' field as indicated by higher layers.

- the UE shall set value of the '_HARQ feedback enabled/disabled indicator_' field as indicated by higher layers.

- the UE shall set value of the '_Cast type indicator_' field as indicated by higher layers.

- the UE shall set value of the '_CSI request_' field as indicated by higher layers.

The UE shall set the contents of the SCI formats 2-B as follows:

- the UE shall set value of the '_HARQ process number_' field as indicated by higher layers.

- the UE shall set value of the '_NDI_' field as indicated by higher layers.

- the UE shall set value of the '_Redundancy version_' field as indicated by higher layers.

**_3GPP_****Release 16**

**157**

**3GPP TS 38.214 V16.17.0 (2024-06)**

- the UE shall set value of the '_Source ID_' field as indicated by higher layers.

- the UE shall set value of the '_Destination ID_' field as indicated by higher layers.

- the UE shall set value of the '_HARQ feedback enabled/disabled indicator_' field as indicated by higher layers.

- the UE shall set value of the '_Zone ID_' field as indicated by higher layers.

- the UE shall set the '_Communication range requirement_' field as indicated by higher layers.

8.1.1 Transmission schemes

Only one transmission scheme is defined for the PSSCH and is used for all PSSCH transmissions.

PSSCH transmission is performed with up to two antenna ports, with antenna ports 1000-1001 as defined in clause 8.2.4

of [4, TS 38.211].

8.1.2 Resource allocation

In sidelink resource allocation mode 1:

- for PSSCH and PSCCH transmission, dynamic grant, configured grant type 1 and configured grant type 2 are

supported. The configured grant Type 2 sidelink transmission is semi-persistently scheduled by a SL grant in a

valid activation DCI according to Clause 10.2A of [6, TS 38.213].

8.1.2.1 Resource allocation in time domain

The UE shall transmit the PSSCH in the same slot as the associated PSCCH.

The minimum resource allocation unit in the time domain is a slot.

The UE shall transmit the PSSCH in consecutive symbols within the slot, subject to the following restrictions:

- The UE shall not transmit PSSCH in symbols which are not configured for sidelink. A symbol is configured for

sidelink, according to higher layer parameters _sl-StartSymbol_ and _sl-LengthSymbols_, where _sl-StartSymbol_ is the

symbol index of the first symbol of _sl-LengthSymbols_ consecutive symbols configured for sidelink.

- Within the slot, PSSCH resource allocation starts at symbol _sl-StartSymbol+1._

- The UE shall not transmit PSSCH in symbols which are configured for use by PSFCH, if PSFCH is configured

in this slot.

- The UE shall not transmit PSSCH in the last symbol configured for sidelink.

- The UE shall not transmit PSSCH in the symbol immediately preceding the symbols which are configured for

use by PSFCH, if PSFCH is configured in this slot.

In sidelink resource allocation mode 1:

- For sidelink dynamic grant, the PSSCH transmission is scheduled by a DCI format 3_0.

- For sidelink configured grant type 2, the configured grant is activated by a DCI format 3_0.

- For sidelink dynamic grant and sidelink configured grant type 2:

- The "Time gap" field value _m_ of the DCI format 3_0 provides an index _m_ + 1 into a slot offset table. That

table is given by higher layer parameter _sl-DCI-ToSL-Trans_ and the table value at index _m_ + 1 will be

referred to as slot offset 𝐾𝑆𝐿.

- The slot of the first sidelink transmission scheduled by the DCI is the first SL slot of the corresponding

𝑇TA

resource pool that starts not earlier than 𝑇DL−

+𝐾𝑆𝐿 ×𝑇slot, where 𝑇DL is the starting time of the

2

downlink slot carrying the corresponding DCI, 𝑇TA is the timing advance value corresponding to the TAG

of the serving cell on which the DCI is received and 𝐾𝑆𝐿 is the slot offset between the slot of the DCI and

the first sidelink transmission scheduled by DCI and 𝑇slot is the SL slot duration.

**_3GPP_****Release 16**

**158**

**3GPP TS 38.214 V16.17.0 (2024-06)**

- The "Configuration index" field of the DCI format 3_0, if provided and not reserved, indicates the index of

the sidelink configured type 2.

- For sidelink configured grant type 1:

- The slot of the first sidelink transmissions follows the higher layer configuration according to [10, TS

38.321].

8.1.2.2 Resource allocation in frequency domain

The resource allocation unit in the frequency domain is the sub-channel.

The sub-channel assignment for sidelink transmission is determined using the "Frequency resource assignment" field in

the associated SCI.

The lowest sub-channel for sidelink transmission is the sub-channel on which the lowest PRB of the associated PSCCH

is transmitted.

If a PSSCH scheduled by a PSCCH would overlap with resources containing the PSCCH, the resources corresponding

to a union of the PSCCH that scheduled the PSSCH and associated PSCCH DM-RS are not available for the PSSCH.

8.1.3 Modulation order, target code rate, redundancy version and

transport block size determination

The redundancy version is given by the "Redundancy version" field in SCI format 2-A or 2-B.

8.1.3.1 Modulation order and target code rate determination

_I__MCS_ is given by the '_Modulation and coding scheme_' field in SCI format 1-A.

The MCS table is determined as follows: Table 5.1.3.1-1 is used if no additional MCS table is configured by higher

layer parameter _sl-Additional-MCS-Table_; otherwise an MCS table is determined according to Table 8.1.3.1-1 or Table

8.1.3.1-2 and '_Additional_ _MCS table indicator_' field in SCI format 1-A.

**Table 8.1.3.1-1: Mapping of one bit of MCS table indicator to MCS table**

Table 5.1.3.1-1

1st table provided by higher layer parameter _sl-Additional-MCS-Table_

**MCS table indicator** **MCS table**

'0' '1' **Table 8.1.3.1-2: Mapping of two bits of MCS table indicator to MCS table**

**MCS table indicator** **MCS table**

'00' Table 5.1.3.1-1

'01' 1st table provided by higher layer parameter _sl-Additional-MCS-Table_

'10' 2nd table provided by higher layer parameter _sl-Additional-MCS-Table_

'11' reserved

The UE shall use _I__MCS_ and the MCS table determined according to the previous step to determine the modulation order

(_Q__m_) and Target code rate (_R_) used in the physical sidelink shared channel.

8.1.3.2 Transport block size determination

For the PSSCH assigned by SCI, if Table 5.1.3.1-2 is used and 0 

 _MCS_

_I_ _,_ or a table other than Table 5.1.3.1-2 is

27

used and 28

0 

 _MCS_

_I_ _,_ the UE shall first determine the TBS as specified below:

The UE shall first determine the number of REs (_N__RE_) within the slot.

- A UE first determines the number of REs allocated for PSSCH within a PRB (𝑁𝑅𝐸

′ ) by 𝑁𝑅𝐸

′ =

𝑁𝑠𝑐

𝑠ℎ

𝑅𝐵(𝑁𝑠𝑦𝑚𝑏

−𝑁𝑠𝑦𝑚𝑏

𝑃𝑆𝐹𝐶𝐻)−𝑁𝑜ℎ

𝑃𝑅𝐵

−𝑁𝑅𝐸

𝐷𝑀𝑅𝑆, where

- 𝑁𝑠𝑐

𝑅𝐵 =12 is the number of subcarriers in a physical resource block,

**_3GPP_****Release 16**

**159**

**3GPP TS 38.214 V16.17.0 (2024-06)**

- 𝑁𝑠𝑦𝑚𝑏

𝑠ℎ = _sl-LengthSymbols_ -2, where _sl-LengthSymbols_ is the number of sidelink symbols within the slot

provided by higher layers,

- 𝑁𝑠𝑦𝑚𝑏

𝑃𝑆𝐹𝐶𝐻 = 3 if '_PSFCH overhead indication'_ field of SCI format 1-A indicates "1", and 𝑁𝑠𝑦𝑚𝑏

𝑃𝑆𝐹𝐶𝐻 = 0

otherwise, if higher layer parameter _sl-PSFCH-Period_ is 2 or 4. If higher layer parameter _sl-PSFCH-_

_Period_ is 0, 𝑁𝑠𝑦𝑚𝑏

𝑃𝑆𝐹𝐶𝐻 =0. If higher layer parameter _sl-PSFCH-Period_ is 1, 𝑁𝑠𝑦𝑚𝑏

𝑃𝑆𝐹𝐶𝐻 =3.

- 𝑁𝑜ℎ

𝑃𝑅𝐵 is the overhead given by higher layer parameter _sl-X-Overhead_,

- 𝑁𝑅𝐸

𝐷𝑀𝑅𝑆 is given by Table 8.1.3.2-1 according to higher layer parameter _sl-PSSCH-DMRS-_

_TimePatternList._

**Table 8.1.3.2-1:** 𝑵𝑹𝑬

𝑫𝑴𝑹𝑺 **according to higher layer parameter** **_sl-PSSCH-DMRS-TimePatternList_**

_sl-PSSCH-DMRS-TimePatternList_ 𝑁𝑅𝐸

𝐷𝑀𝑅𝑆

{2} 12

{3} 18

{4} 24

{2,3} 15

{2,4} 18

{3,4} 21

{2,3,4} 18

- A UE determines the total number of REs allocated for PSSCH ( 𝑁𝑅𝐸

𝑆𝐶𝐼,2, where

_N_ ) by 𝑁𝑅𝐸 =𝑁𝑅𝐸

_RE_

′

∙𝑛𝑃𝑅𝐵−𝑁𝑅𝐸

𝑆𝐶𝐼,1

−

- _n__PRB_ is the total number of allocated PRBs for the PSSCH,

- 𝑁𝑅𝐸

𝑆𝐶𝐼,1 is the total number of REs occupied by the PSCCH and PSCCH DM-RS.

- 𝑁𝑅𝐸

𝑆𝐶𝐼,2 is the number of coded modulation symbols generated for 2nd

-stage SCI transmission (prior to

duplication for the 2nd layer, if present) according to Clause 8.4.4 of [5, TS 38.212], with the assumption

of γ=0.

The UE determines TBS according to Steps 2), 3), and 4) in clause 5.1.3.2.

A UE is not expected to receive an SCI indicating 28≤𝐼𝑀𝐶𝑆 ≤31 if Table 5.1.3.1-2 is used, or 29≤𝐼𝑀𝐶𝑆 ≤31

otherwise.

8.1.4 UE procedure for determining the subset of resources to be reported

to higher layers in PSSCH resource selection in sidelink resource

allocation mode 2

In resource allocation mode 2, the higher layer can request the UE to determine a subset of resources from which the

higher layer will select resources for PSSCH/PSCCH transmission. To trigger this procedure, in slot _n,_ the higher layer

provides the following parameters for this PSSCH/PSCCH transmission:

- the resource pool from which the resources are to be reported;

- L1 priority, 𝑝𝑟𝑖𝑜𝑇𝑋;

- the remaining packet delay budget;

- the number of sub-channels to be used for the PSSCH/PSCCH transmission in a slot, 𝐿subCH;

- optionally, the resource reservation interval, 𝑃rsvp_TX, in units of msec.

**_3GPP_****Release 16**

**160**

**3GPP TS 38.214 V16.17.0 (2024-06)**

- if the higher layer requests the UE to determine a subset of resources from which the higher layer will select

resources for PSSCH/PSCCH transmission as part of re-evaluation or pre-emption procedure, the higher layer

provides a set of resources (𝑟0,𝑟1,𝑟2,…) which may be subject to re-evaluation and a set of resources

(𝑟0

′

′

′

,𝑟1

,𝑟2

,…) which may be subject to pre-emption.

- it is up to UE implementation to determine the subset of resources as requested by higher layers before or

after the slot 𝑟𝑖

′′

- 𝑇3, where 𝑟𝑖

′′ is the slot with the smallest slot index among (𝑟0,𝑟1,𝑟2,…) and

(𝑟0

′

′

′

𝑆𝐿

,𝑟1

,𝑟2

,…) , and 𝑇3 is equal to 𝑇𝑝𝑟𝑜𝑐,1

, where 𝑇𝑝𝑟𝑜𝑐,1

𝑆𝐿 is defined in slots in Table 8.1.4-2 where 𝜇𝑆𝐿 is

the SCS configuration of the SL BWP.

The following higher layer parameters affect this procedure:

_- sl-SelectionWindowList_: internal parameter 𝑇2𝑚𝑖𝑛 is set to the corresponding value from higher layer parameter

_sl-SelectionWindowList_ for the given value of 𝑝𝑟𝑖𝑜𝑇𝑋.

_- sl-Thres-RSRP-List_: this higher layer parameter provides an RSRP threshold for each combination (𝑝𝑖, 𝑝𝑗),

where 𝑝𝑖 is the value of the priority field in a received SCI format 1-A and 𝑝j is the priority of the transmission

of the UE selecting resources; for a given invocation of this procedure, 𝑝j = 𝑝𝑟𝑖𝑜𝑇𝑋.

_- sl-RS-ForSensing_ selects if the UE uses the PSSCH-RSRP or PSCCH-RSRP measurement, as defined in clause

8.4.2.1.

_- sl-ResourceReservePeriodList_

_- sl-SensingWindow_: internal parameter 𝑇0 is defined as the number of slots corresponding to _sl-SensingWindow_

msec

_- sl-TxPercentageList_: internal parameter 𝑋 for a given 𝑝𝑟𝑖𝑜𝑇𝑋 is defined as _sl-TxPercentageList (_𝑝𝑟𝑖𝑜𝑇𝑋_)_

converted from percentage to ratio

- _sl-PreemptionEnable_: if _sl-PreemptionEnable_ is provided, and if it is not equal to 'enabled'

, internal parameter

𝑝𝑟𝑖𝑜𝑝𝑟𝑒 is set to the higher layer provided parameter _sl-PreemptionEnable_

The resource reservation interval, 𝑃rsvp_TX, if provided, is converted from units of msec to units of logical slots,

resulting in 𝑃rsvp_

′ according to clause 8.1.7.

TX

Notation:

(𝑡′

𝑆𝐿

0

,𝑡′

𝑆𝐿

1

,𝑡′

𝑆𝐿

2

,…) denotes the set of slots which belongs to the sidelink resource pool and is defined in Clause 8.

The following steps are used:

1) A candidate single-slot resource for transmission 𝑅x,y is defined as a set of 𝐿subCH contiguous sub-channels

with sub-channel _x+j_ in slot 𝑡′

𝑆𝐿 where 𝑗=0,...,𝐿subCH−1. The UE shall assume that any set of 𝐿subCH

𝑦

contiguous sub-channels included in the corresponding resource pool within the time interval [𝑛+𝑇1,𝑛+𝑇2]

correspond to one candidate single-slot resource, where

- selection of 𝑇1 is up to UE implementation under 0 ≤ 𝑇1 ≤ 𝑇𝑝𝑟𝑜𝑐,1

𝑆𝐿 , where 𝑇𝑝𝑟𝑜𝑐,1

𝑆𝐿 is defined in slots

in Table 8.1.4-2 where 𝜇𝑆𝐿 is the SCS configuration of the SL BWP;

- if 𝑇2𝑚𝑖𝑛 is shorter than the remaining packet delay budget (in slots) then 𝑇2 is up to UE implementation

subject to 𝑇2𝑚𝑖𝑛 ≤ 𝑇2 ≤ remaining packet delay budget (in slots); otherwise 𝑇2 is set to the remaining

packet delay budget (in slots).

The total number of candidate single-slot resources is denoted by 𝑀total.

2) The sensing window is defined by the range of slots [𝑛 –𝑇0,𝑛–𝑇𝑝𝑟𝑜𝑐,0

𝑆𝐿

𝑆𝐿 ) where 𝑇0 is defined above and 𝑇𝑝𝑟𝑜𝑐,0

is defined in slots in Table 8.1.4-1 where 𝜇𝑆𝐿 is the SCS configuration of the SL BWP. The UE shall monitor

slots which belongs to a sidelink resource pool within the sensing window except for those in which its own

transmissions occur. The UE shall perform the behaviour in the following steps based on PSCCH decoded and

RSRP measured in these slots.

**_3GPP_****Release 16**

**161**

**3GPP TS 38.214 V16.17.0 (2024-06)**

3) The internal parameter 𝑇ℎ(𝑝𝑖,𝑝𝑗) is set to the corresponding value of RSRP threshold indicated by the _i_-th

field in _sl-Thres-RSRP-List_, where 𝑖=𝑝𝑖 +(𝑝𝑗−1)∗8.

4) The set 𝑆𝐴 is initialized to the set of all the candidate single-slot resources.

5) The UE shall exclude any candidate single-slot resource 𝑅x,y from the set 𝑆𝐴 if it meets all the following

conditions:

- the UE has not monitored slot 𝑡′

𝑚

𝑆𝐿 in Step 2.

- for any periodicity value allowed by the higher layer parameter _sl-ResourceReservePeriodList_ and a

hypothetical SCI format 1-A received in slot 𝑡′

𝑚

𝑆𝐿 with '_Resource reservation period_' field set to that

periodicity value and indicating all subchannels of the resource pool in this slot, condition c in step 6 would

be met.

5a) If the number of candidate single-slot resources 𝑅x,y remaining in the set 𝑆𝐴 is smaller than 𝑋⋅𝑀_total_, the set

𝑆𝐴 is initialized to the set of all the candidate single-slot resources as in step 4.

6) The UE shall exclude any candidate single-slot resource 𝑅x,y from the set 𝑆𝐴 if it meets all the following

conditions:

a) the UE receives an SCI format 1-A in slot 𝑡′

𝑚

𝑆𝐿, and '_Resource reservation period'_ field, if present, and

'_Priority_' field in the received SCI format 1-A indicate the values 𝑃rsvp_RX and 𝑝𝑟𝑖𝑜𝑅𝑋, respectively

according to Clause 16.4 in [6, TS 38.213];

b) the RSRP measurement performed, according to clause 8.4.2.1 for the received SCI format 1-A, is higher

than 𝑇ℎ(𝑝𝑟𝑖𝑜𝑅𝑋,𝑝𝑟𝑖𝑜𝑇𝑋);

c) the SCI format received in slot 𝑡′

𝑚

𝑆𝐿 or the same SCI format which, if and only if the '_Resource reservation_

_period_' field is present in the received SCI format 1-A, is assumed to be received in slot(s) 𝑡′

𝑆𝐿

′

𝑚+𝑞×𝑃𝑟𝑠𝑣𝑝_

𝑅𝑋

′

determines according to clause 8.1.5 the set of resource blocks and slots which overlaps with 𝑅𝑥,𝑦+𝑗×𝑃𝑟𝑠𝑣𝑝_

𝑇𝑋

for _q_=1, 2, …, _Q_ and _j=_0, 1, …, 𝐶𝑟𝑒𝑠𝑒𝑙−1. Here, 𝑃𝑟𝑠𝑣𝑝_

′ is 𝑃rsvp_RX converted to units of logical slots

𝑅𝑋

according to clause 8.1.7, 𝑄=⌈ 𝑇𝑠𝑐𝑎𝑙

𝑃𝑟𝑠𝑣𝑝_

𝑅𝑋⌉ if 𝑃𝑟𝑠𝑣𝑝_

𝑅𝑋 < 𝑇𝑠𝑐𝑎𝑙 and 𝑛′

′

−𝑚≤𝑃𝑟𝑠𝑣𝑝_

𝑅𝑋

, where 𝑡′

𝑆𝐿

𝑛′

=

𝑛 if slot _n_ belongs to the set (𝑡′

𝑆𝐿

0

,𝑡′

𝑆𝐿

1

,...,𝑡′

𝑆𝐿 ), otherwise slot 𝑡′

𝑆𝐿 is the first slot after slot _n_

𝑇′𝑚𝑎𝑥−1

𝑛′

belonging to the set (𝑡′

𝑆𝐿

0

,𝑡′

𝑆𝐿

1

,...,𝑡′

𝑆𝐿 𝑇′𝑚𝑎𝑥−1

); otherwise 𝑄=1. 𝑇𝑠𝑐𝑎𝑙 is set to selection window size _T__2_

converted to units of msec.

7) If the number of candidate single-slot resources remaining in the set 𝑆𝐴 is smaller than 𝑋⋅𝑀total, then

𝑇ℎ(𝑝𝑖,𝑝𝑗) is increased by 3 dB for each priority value 𝑇ℎ(𝑝𝑖,𝑝𝑗) and the procedure continues with step 4.

The UE shall report set 𝑆𝐴 to higher layers.

If a resource 𝑟𝑖 from the set (𝑟0,𝑟1,𝑟2,…) is not a member of 𝑆𝐴, then the UE shall report re-evaluation of the

resource 𝑟𝑖 to higher layers.

If a resource 𝑟𝑖

′ from the set (𝑟0

′

′

′

,𝑟1

,𝑟2

,…) meets the conditions below then the UE shall report pre-emption of the

resource 𝑟𝑖

′ to higher layers

- 𝑟𝑖

′ is not a member of 𝑆𝐴, and

- 𝑟𝑖

′ meets the conditions for exclusion in step 6, with 𝑇ℎ(𝑝𝑟𝑖𝑜𝑅𝑋,𝑝𝑟𝑖𝑜𝑇𝑋) set to the final threshold after

executing steps 1)-7), i.e. including all necessary increments for reaching 𝑋⋅𝑀total, and

- the associated priority 𝑝𝑟𝑖𝑜𝑅𝑋, satisfies one of the following conditions:

- _sl-PreemptionEnable_ is provided and is equal to 'enabled' and 𝑝𝑟𝑖𝑜𝑇𝑋 >𝑝𝑟𝑖𝑜𝑅𝑋

- _sl-PreemptionEnable_ is provided and is not equal to 'enabled', and 𝑝𝑟𝑖𝑜𝑅𝑋 <𝑝𝑟𝑖𝑜𝑝𝑟𝑒 and 𝑝𝑟𝑖𝑜𝑇𝑋 >𝑝𝑟𝑖𝑜𝑅𝑋

**_3GPP_****Release 16**

**162**

**3GPP TS 38.214 V16.17.0 (2024-06)**

**Table 8.1.4-1:** 𝑻𝒑𝒓𝒐𝒄,𝟎

𝑺𝑳 **depending on sub-carrier spacing**

𝝁𝑺𝑳 𝑻𝒑𝒓𝒐𝒄,𝟎

𝑺𝑳 **[slots]**

0 1

1 1

2 2

3 4

**Table 8.1.4-2:** 𝑻𝒑𝒓𝒐𝒄,𝟏

𝑺𝑳 **depending on sub-carrier spacing**

𝝁𝑺𝑳 𝑻𝒑𝒓𝒐𝒄,𝟏

𝑺𝑳 **[slots]**

0 3

1 5

2 9

3 17

8.1.5 UE procedure for determining slots and resource blocks for PSSCH

transmission associated with an SCI format 1-A

The set of slots and resource blocks for PSSCH transmission is determined by the resource used for the PSCCH

transmission containing the associated SCI format 1-A, and fields '_Frequency resource assignment_'

'_Time resource_

,

_assignment_' of the associated SCI format 1-A as described below.

'_Time resource assignment_' carries logical slot offset indication of N = 1 or 2 actual resources when _sl-_

_MaxNumPerReserve_ is 2, and N = 1 or 2 or 3 actual resources when _sl-MaxNumPerReserve_ is 3, in a form of time RIV

(TRIV) field which is determined as follows:

if 𝑁=1

𝑇𝑅𝐼𝑉=0

elseif 𝑁=2

𝑇𝑅𝐼𝑉=𝑡1

else

if (𝑡2−𝑡1−1)≤15

𝑇𝑅𝐼𝑉=30(𝑡2−𝑡1−1)+𝑡1 +31

else

𝑇𝑅𝐼𝑉=30(31−𝑡2 +𝑡1)+62−𝑡1

end if

end if

where the first resource is in the slot where SCI format 1-A was received, and 𝑡𝑖 denotes i-th resource time offset in

logical slots of a resource pool with respect to the first resource where for N = 2, 1≤𝑡1 ≤31; and for N = 3, 1≤𝑡1 ≤

30, t1 <𝑡2 ≤31.

**_3GPP_****Release 16**

**163**

**3GPP TS 38.214 V16.17.0 (2024-06)**

The starting sub-channel 𝑛𝑠𝑢𝑏𝐶𝐻,0

𝑠𝑡𝑎𝑟𝑡 of the first resource is determined according to clause 8.1.2.2. The number of

contiguously allocated sub-channels for each of the N resources 𝐿subCH≥1 and the starting sub-channel indexes of

resources indicated by the received SCI format 1-A, except the resource in the slot where SCI format 1-A was received,

are determined from "Frequency resource assignment" which is equal to a frequency RIV (FRIV) where.

If _sl-MaxNumPerReserve_ is 2 then

𝐹𝑅𝐼𝑉=𝑛𝑠𝑢𝑏𝐶𝐻,1

𝑠𝑡𝑎𝑟𝑡 +∑ (𝑁 subchannel

𝑆𝐿 +1−𝑖)𝐿subCH−1

𝑖=1

If _sl-MaxNumPerReserve_ is 3 then

𝐹𝑅𝐼𝑉=𝑛𝑠𝑢𝑏𝐶𝐻,1

𝑠𝑡𝑎𝑟𝑡

𝑠𝑡𝑎𝑟𝑡 +𝑛𝑠𝑢𝑏𝐶𝐻,2

⋅(𝑁 subchannel

𝐿subCH−1

𝑆𝐿 +1−𝐿subCH)+∑ (𝑁 subchannel

𝑖=1

𝑆𝐿 +1−𝑖)2

where

- 𝑛𝑠𝑢𝑏𝐶𝐻,1

𝑠𝑡𝑎𝑟𝑡 denotes the starting sub-channel index for the second resource

- 𝑛𝑠𝑢𝑏𝐶𝐻,2

𝑠𝑡𝑎𝑟𝑡 denotes the starting sub-channel index for the third resource

- 𝑁 _subchannel_

𝑆𝐿 is the number of sub-channels in a resource pool provided according to the higher layer parameter _sl-_

_NumSubchannel_

If TRIV indicates _N_ < _sl-MaxNumPerReserve_, the starting sub-channel indexes corresponding to _sl-MaxNumPerReserve_

minus N last resources are not used.

The number of slots in one set of the time and frequency resources for transmission opportunities of PSSCH is given by

𝐶𝑟𝑒𝑠𝑒𝑙 where 𝐶𝑟𝑒𝑠𝑒𝑙= 10*SL_RESOURCE_RESELECTION_COUNTER [10, TS 38.321] if configured else 𝐶𝑟𝑒𝑠𝑒𝑙 is

set to 1.

If a set of sub-channels in slot 𝑡′

𝑚

𝑆𝐿 is determined as the time and frequency resource for PSSCH transmission

corresponding to the selected sidelink grant (described in [10, TS 38.321]), the same set of sub-channels in slots

𝑡′

𝑆𝐿 are also determined for PSSCH transmissions corresponding to the same sidelink grant where _j=_1, 2,_…,_

_′_

𝑚+𝑗×𝑃𝑟𝑠𝑣𝑝_

𝑇𝑋

𝐶𝑟𝑒𝑠𝑒𝑙−1, 𝑃rsvp_TX, if provided, is converted from units of msec to units of logical slots, resulting in 𝑃rsvp_

′ according

TX

to clause 8.1.7, and (𝑡′

𝑆𝐿

0

,𝑡′

𝑆𝐿

1

,𝑡′

𝑆𝐿

2

,…) is determined by Clause 8. Here, 𝑃rsvp_TX is the resource reservation interval

indicated by higher layers.

8.1.6 Sidelink congestion control in sidelink resource allocation mode 2

If a UE is configured with higher layer parameter _sl-CR-Limit_ and transmits PSSCH in slot _n_, the UE shall ensure the

following limits for any priority value k;

∑ 𝐶𝑅(𝑖)

𝑖≥𝑘 ≤𝐶𝑅𝐿𝑖𝑚𝑖𝑡(𝑘)

where 𝐶𝑅(𝑖) is the CR evaluated in slot _n_-_N_ for the PSSCH transmissions with '_Priority_' field in the SCI set to _i_, and

𝐶𝑅𝐿𝑖𝑚𝑖𝑡(𝑘) corresponds to the high layer parameter _sl-CR-Limit_ that is associated with the priority value _k_ and the CBR

range which includes the CBR measured in slot _n_-_N_, where _N_ is the congestion control processing time.

The congestion control processing time _N_ is based on µ of Table 8.1.6-1 and Table 8.1.6-2 for UE processing capability

1 and 2 respectively, where µ corresponds to the subcarrier spacing of the sidelink channel with which the PSSCH is to

be transmitted. A UE shall only apply a single processing time capability in sidelink congestion control.

**Table 8.1.6-1: Congestion control processing time for processing timing capability 1**

**µ** Congestion control processing time N [slots]

0 2

1 2

2 4

3 8

**_3GPP_****Release 16**

**164**

**3GPP TS 38.214 V16.17.0 (2024-06)**

**Table 8.1.6-2: Congestion control processing time for processing timing capability 2**

**µ** Congestion control processing time N [slots]

0 2

1 4

2 8

3 16
It is up to UE implementation how to meet the above limits, including dropping the transmissions in slot _n_.

8.1.7 UE procedure for determining the number of logical slots for a

reservation period

A given resource reservation period 𝑃rsvp in milliseconds is converted to a period 𝑃rsvp

′ in logical slots as:

𝑃rsvp

′ =⌈ 𝑇′

𝑚𝑎𝑥

10240 𝑚𝑠

×𝑃rsvp⌉

where 𝑇′

𝑚𝑎𝑥 is the number of slots that belong to a resource pool as defined in Clause 8.

8.2 UE procedure for transmitting sidelink reference signals

8.2.1 CSI-RS transmission procedure

A UE transmits sidelink CSI-RS within a unicast PSSCH transmission if the following conditions hold:

- CSI reporting is enabled by higher layer parameter _sl-CSI-Acquisition_; and

- the '_CSI request_' field in the corresponding SCI format 2-A is set to 1.

The following parameters for CSI-RS transmission are configured for each CSI-RS configuration:

- _sl-CSI-RS-FirstSymbol_ indicates the first OFDM symbol in a PRB used for SL CSI-RS

- _sl-CSI-RS-FreqAllocation_ indicates the number of antenna ports and the frequency domain allocation for SL

CSI-RS.

𝑃𝑆𝑆𝐶𝐻

When the UE is configured with _Q__p_={1,2} CSI-RS port(s) in sidelink and the number of scheduled layers is 𝑛𝑙𝑎𝑦𝑒𝑟

,

- The CSI-RS scaling factor 𝛽CSIRS specified in clause 8.4.1.5.3 of [4, TS 38.211] is given by 𝛽CSIRS =𝛽DMRS

PSSCH ∙

√𝑛𝑙𝑎𝑦𝑒𝑟

𝑃𝑆𝑆𝐶𝐻

𝑄𝑝

38.211].

where 𝛽DMRS

PSSCH is the scaling factor for the corresponding PSSCH specified in clause 8.3.1.5 of [4, TS

8.2.2 PSSCH DM-RS transmission procedure

The UE selects the DM-RS time domain pattern out of the patterns configured using the higher layer parameter _sl-_

_PSSCH-DMRS-TimePatternList_ for the resource pool on which the PSSCH is to be transmitted. If more than one DM-

RS time domain pattern is configured, the selected pattern is indicated by the '_DMRS pattern_' field in the SCI format 1-

A associated with the PSSCH transmission.

If PSSCH DM-RS and PSCCH are mapped to the same OFDM symbol, then this mapping within a single sub-channel

is only supported if higher layer parameter _sl-SubchannelSize_ >= 20, i.e. the sub-channel size is at least 20 PRBs.

When a sub-channel size is less than 20 PRBs and the size of PSCCH is less than the sub-channel size, a UE is not

expected to choose a PSSCH DM-RS pattern to be transmitted in the same OFDM symbol with PSCCH.

8.2.3 PT-RS transmission procedure

Transmission of PT-RS is only supported in frequency range 2.

**_3GPP_****Release 16**

**165**

**3GPP TS 38.214 V16.17.0 (2024-06)**

The UE PT-RS transmission procedure specified in clause 6.2.3.1 applies for derivation of the PT-RS parameters _L__PT-RS_

and

_,_

_K__PT-RS_ and for determination of PT-RS presence, with the following changes:

- _timeDensity_ and _frequencyDensity_ in _PTRS-UplinkConfig_ are replaced by _sl-PTRS-TimeDensity_ and _sl-PTRS-_

_FreqDensity_ in _SL-PTRS-Config_ respectively, and _SL-PTRS-Config_ is (pre)configured per resource pool;

- the number of antenna ports is the same as the number of PSSCH DM-RS antenna ports and the association

between a PT-RS antenna port and a PSSCH DM-RS antenna port is fixed.

8.3 UE procedure for receiving the physical sidelink shared

channel

For sidelink resource allocation mode 1, a UE upon detection of SCI format 1-A on PSCCH can decode PSSCH

according to the detected SCI formats 2-A and 2-B, and associated PSSCH resource configuration configured by higher

layers. The UE is not required to decode more than one PSCCH at each PSCCH resource candidate.

For sidelink resource allocation mode 2, a UE upon detection of SCI format 1-A on PSCCH can decode PSSCH

according to the detected SCI formats 2-A and 2-B, and associated PSSCH resource configuration configured by higher

layers. The UE is not required to decode more than one PSCCH at each PSCCH resource candidate.

A UE is required to decode neither the corresponding SCI formats 2-A and 2-B nor the PSSCH associated with an SCI

format 1-A if the SCI format 1-A indicates an MCS table that the UE does not support.

8.4 UE procedure for receiving reference signals

8.4.1 CSI-RS reception procedure

The CSI-RS defined in Clause 8.4.1.5 of [4, TS 38.211] may be used for CSI computation.

8.4.2 DM-RS reception procedure for RSRP computation

8.4.2.1 RSRP for resource selection in sidelink resource allocation mode 2

In sidelink resource allocation mode 2, the UE measures RSRP for resource selection as follows:

- PSSCH-RSRP over the DM-RS resource elements for the PSSCH according to the received SCI format 1-A if

higher layer parameter _sl-RS-ForSensing_ is set to 'pssch', and

- PSCCH-RSRP over the DM-RS resource elements for the PSCCH carrying the received SCI format 1-A if

higher layer parameter _sl-RS-ForSensing_ is set to 'pscch_'_

.

8.4.3 PT-RS reception procedure

Reception of PT-RS is only supported in frequency range 2.

The UE PT-RS reception procedure specified in clause 5.1.6.3 applies for derivation of the PT-RS parameters _L__PT-RS_ and

_K__PT-RS_ and for determination of PT-RS presence, with the following changes:

- _timeDensity_ and f_requencyDensity_ in _PTRS-DownlinkConfig_ are replaced by _sl-PTRS-TimeDensity_ and _sl-PTRS-_

_FreqDensity_ in _SL-PTRS-Config_ respectively, and _SL-PTRS-Config_ is (pre)configured per resource pool;

- the number of antenna ports is the same as the number of PSSCH DM-RS antenna ports and the association

between a PT-RS antenna port and a PSSCH DM-RS antenna port is fixed.

8.5 UE procedure for reporting channel state information (CSI)

8.5.1 Channel state information framework

CSI consists of Channel Quality Indicator (CQI) and Rank Indicator (RI). The CQI and RI are always reported together.

**_3GPP_****Release 16**

**166**

**3GPP TS 38.214 V16.17.0 (2024-06)**

8.5.1.1 Reporting configurations

The UE shall calculate CSI parameters (if reported) assuming the following dependencies between CSI parameters (if

reported)

- CQI shall be calculated conditioned on the reported RI

The CSI reporting can be aperiodic (using [10, TS 38.321]). Table 8.5.1.1-1 shows the supported combinations of CSI

reporting configurations and CSI-RS configurations and how the CSI reporting is triggered for CSI-RS configuration.

Aperiodic CSI-RS is configured and triggered/activated as described in Clause 8.5.1.2.

**Table 8.5.1.1-1 Triggering/Activation of CSI reporting for the possible CSI-RS Configurations.**

**CSI-RS Configuration Aperiodic CSI Reporting**

For CSI reporting, wideband CQI reporting is

Aperiodic CSI-RS Triggered by SCI.

supported. A wideband CQI is reported for a

single codeword for the entire CSI reporting band.

8.5.1.2 Triggering of sidelink CSI reports

The CSI-triggering UE is not allowed to trigger another aperiodic CSI report for the same UE before the last slot of the

expected reception or completion of the ongoing aperiodic CSI report associated with the SCI format 2-A with the '_CSI_

_request_' field set to 1, where the last slot of the expected reception of the ongoing aperiodic CSI report is given by [10,

TS38.321].

An aperiodic CSI report is triggered by an SCI format 2-A with the '_CSI request_' field set to 1.

A UE is not expected to transmit a sidelink CSI-RS and a sidelink PT-RS which overlap.

8.5.2 Channel state information

8.5.2.1 CSI reporting quantities

8.5.2.1.1 Channel quality indicator (CQI)

The UE shall derive CQI as specified in clause 5.2.2.1, with the following changes

- PDSCH replaced by PSSCH

- uplink slot replaced by sidelink slot

- downlink physical resource blocks replaced by sidelink physical resource blocks

- Transport Block Size determination according to Clause 8.1.3.2

- CSI reference resource according to the Clause 8.5.2.3

- interference measurements are not supported

- sub-band differential CQI is not supported

- cqi-Table is determined as follows

- cqi-Table = 'table1' if Table 5.1.3.1-1 is determined as the MCS table according to Clause 8.1.3.1 of [6,

38.214],

- cqi-Table = 'table2' if Table 5.1.3.1-2 is determined as the MCS table according to Clause 8.1.3.1 of [6,

38.214],

- cqi-Table = 'table3' if Table 5.1.3.1-3 is determined as the MCS table according to Clause 8.1.3.1 of [6,

38.214]

**_3GPP_****Release 16**

**167**

**3GPP TS 38.214 V16.17.0 (2024-06)**

8.5.2.2 Reference signal (CSI-RS)

The UE can be configured with one CSI-RS pattern as indicated by the higher layer parameters _sl-CSI-RS-_

_FreqAllocation, sl-CSI-RS-FirstSymbol_ in _SL-CSI-RS-Config_.

Parameters for which the UE shall assume non-zero transmission power for CSI-RS are configured according to clause

8.2.1.

A UE is not expected to be configured such that a CSI-RS and the corresponding PSCCH can be mapped to the same

resource element. A UE is not expected to receive sidelink CSI-RS and PSSCH DM-RS, nor CSI-RS and 2nd-stage

SCI, on the same symbol.

Sidelink CSI-RS shall be transmitted according to [4, TS 38.211] in the resource blocks used for the PSSCH associated

with the SCI format 2-A triggering a report.

8.5.2.3 CSI reference resource definition

The CSI reference resource in sidelink is defined as follows:

- In the frequency domain, the CSI reference resource is defined by the group of sidelink physical resource blocks

containing the sidelink CSI-RS to which the derived CSI relates.

- In the time domain, the CSI reference resource for a CSI reporting in sidelink slot _n_ is defined by a single

sidelink slot _n__CSI_ref_ where _n__CSI_ref_ is the same sidelink slot as the corresponding CSI request.

If configured to report CQI index and RI index, in the CSI reference resource, the UE shall assume the following for the

purpose of deriving the CQI index and RI index:

- The reference resource uses the CP length and subcarrier spacing configured for the SL BWP.

- Redundancy Version 0.

- PSCCH occupies 2 OFDM symbols.

- The number of PSSCH and DM-RS symbols is equal to _sl-LengthSymbols_‒2.

- Assume no REs allocated for sidelink CSI-RS.

- Assume no REs allocated SCI format 2-A or SCI format 2-B.

- Assume the same number of DM-RS symbols as the smallest one configured by the higher layer parameter _sl-_

_PSSCH-DMRS-TimePatternList._

- Assume no REs allocated for sidelink PT-RS.

- Assume sidelink CSI-RS RE power is the same as PSSCH RE power.

- The PSSCH transmission scheme where the UE may assume that PSSCH transmission would be performed with

up to 2 transmission layers as defined in Clause 8.3.1.4 of [4, TS 38.211]. For CQI calculation, the UE should

assume that PSSCH signals on antenna ports in the set [1000,…, 1000+ν-1] for ν layers would result in signals

equivalent to corresponding symbols transmitted on antenna ports [3000,…, 3000+_P_-1], as given by

[ 𝑦(3000)(𝑖)

𝑦(3000+𝑃−1)(𝑖)]=𝑊(𝑖)[ 𝑥(0)(𝑖)

⋯

𝑥(𝜈−1)(𝑖)]

⋯

0

(

)

(

where  _T_

_x_ )

( ) 1

_i_

)



_x_

(

_i_

)...

_x_

_i_

 is a vector of PSSCH symbols from the layer mapping defined in Clause

(

8.3.1.4 of [4, TS 38.211], 𝑃∈[1,2] is the number of CSI-RS ports. If only one CSI-RS port is configured,

_W(i)_ is 1. Otherwise, _W(i)_ is the identity matrix_._

8.5.3 CSI reporting

The UE can be configured with one CSI reporting latency bound as indicated by the higher layer parameter _sl-_

_LatencyBoundCSI-Report_. CSI reporting is aperiodic and is described in [10, TS 38.321].

**_3GPP_****Release 16**

**168**

**3GPP TS 38.214 V16.17.0 (2024-06)**

8.6 UE PSSCH preparation procedure time

For sidelink dynamic grant and for SL configured grant type 2 activation, if the first sidelink symbol in the sidelink

allocation for a PSSCH for a transport block and the associated PSCCH, including the DM-RS and the duplicated

symbol, as defined by the slot offset 𝐾𝑆𝐿 of the scheduling DCI for dynamic grant or the activating DCI for SL

configured grant type 2, is no earlier than at symbol _L_, where _L_ is defined as the next sidelink symbol with its CP

starting 𝑇𝑝𝑟𝑜𝑐

=(𝑁2 +𝑑2,1)(2048+144)⋅𝜅2−𝜇⋅𝑇𝐶 after the end of the reception of the last symbol of the PDCCH

carrying the DCI scheduling the sidelink transmissions for dynamic grant or activating the SL configured grant type 2,

then the UE shall transmit the PSSCH and the associated PSCCH.

_- N__2_ is based on _µ_ of Table 8.6-1, where _µ_ corresponds to the one of (_µ__DL_, _µ__SL_) resulting with the largest _T__proc_,

where the _µ__DL_ corresponds to the subcarrier spacing of the downlink with which the PDCCH carrying the DCI

scheduling the PSSCH for dynamic grant or activating the SL configured grant type 2 was transmitted and _µ__SL_

corresponds to the subcarrier spacing of the sidelink channel with which the PSSCH and the associated PSCCH

are to be transmitted, and _κ_ is defined in Clause 4.1 of [4, TS 38.211].

- _d__2,1_ = 1.

Otherwise the UE may ignore the scheduling DCI for dynamic grant or the activating DCI for SL configured grant type

2.

The value of 𝑇𝑝𝑟𝑜𝑐 is used both in the case of normal and extended cyclic prefix.

**Table 8.6-1: PSSCH preparation time**

 **PSSCH preparation time** **_N_****_2_** **[symbols]**

0 10

1 12

2 23

3 36

For sidelink resource allocation mode 1, the UE does not expect that the first sidelink symbol in the sidelink allocation

for a PSSCH for retransmission of a transport block and the associated PSCCH, including the DM-RS and the

duplicated symbol as defined by the "Time resource assignment" field of the corresponding DCI for dynamic grant or

for SL configured grant type 2, or by _sl-TimeResourceCG-Type1_ for configured grant type 1 starts earlier than at

symbol 𝐿 where 𝐿 is defined as the next sidelink symbol with its CP starting 𝑇𝑝𝑟𝑒𝑝 +𝛿 after the end of the last

symbol of the PSFCH occasion corresponding to the most recent transmission of PSSCH for the same transport block,

where 𝑇𝑝𝑟𝑒𝑝 is defined in Clause 16.5 of [6, TS 38.213] and 𝛿=5∙10−4 𝑠. Otherwise the UE may skip the

retransmission of the PSSCH and the transmission of the corresponding PSCCH.

**_3GPP_**