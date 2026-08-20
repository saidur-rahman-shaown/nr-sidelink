# TS 38.321 §5.22–5.23 — MAC Sidelink Procedures (SL-SCH / SL-BCH)

> **Source:** 3GPP TS 38.321 V16.22.0 (2025-12), Release 16 — *NR; Medium Access Control (MAC) protocol specification*
> **Scope:** Mode-1 and Mode-2 sidelink grant handling, TX resource (re-)selection check, sidelink HARQ entity and processes, PSFCH reception, LCP, SL-BSR, SR, CSI reporting.
> **Status:** verbatim spec extract, reformatted. Page headers/footers removed,
> PDF hard-wraps rejoined, clause numbers promoted to headings.
> Normative text is unchanged; see `00-INDEX.md` for gaps and reconstructions.

## Contents

  - [5.22 SL-SCH Data transfer](#522-sl-sch-data-transfer)
    - [5.22.1 SL-SCH Data transmission](#5221-sl-sch-data-transmission)
      - [5.22.1.1 SL Grant reception and SCI transmission](#52211-sl-grant-reception-and-sci-transmission)
      - [5.22.1.2 TX resource (re-)selection check](#52212-tx-resource-re-selection-check)
      - [5.22.1.2a Re-evaluation and Pre-emption](#52212a-re-evaluation-and-pre-emption)
      - [5.22.1.3 Sidelink HARQ operation](#52213-sidelink-harq-operation)
        - [5.22.1.3.1 Sidelink HARQ Entity](#522131-sidelink-harq-entity)
        - [5.22.1.3.1a Sidelink process](#522131a-sidelink-process)
        - [5.22.1.3.2 PSFCH reception](#522132-psfch-reception)
        - [5.22.1.3.3 HARQ-based Sidelink RLF detection](#522133-harq-based-sidelink-rlf-detection)
      - [5.22.1.4 Multiplexing and assembly](#52214-multiplexing-and-assembly)
        - [5.22.1.4.0 General](#522140-general)
        - [5.22.1.4.1 Logical channel prioritization](#522141-logical-channel-prioritization)
          - [5.22.1.4.1.1 General](#5221411-general)
          - [5.22.1.4.1.2 Selection of logical channels](#5221412-selection-of-logical-channels)
          - [5.22.1.4.1.3 Allocation of sidelink resources](#5221413-allocation-of-sidelink-resources)
        - [5.22.1.4.2 Multiplexing of MAC Control Elements and MAC SDUs](#522142-multiplexing-of-mac-control-elements-and-mac-sdus)
      - [5.22.1.5 Scheduling Request](#52215-scheduling-request)
      - [5.22.1.6 Buffer Status Reporting](#52216-buffer-status-reporting)
      - [5.22.1.7 CSI Reporting](#52217-csi-reporting)
    - [5.22.2 SL-SCH Data reception](#5222-sl-sch-data-reception)
      - [5.22.2.1 SCI reception](#52221-sci-reception)
      - [5.22.2.2 Sidelink HARQ operation](#52222-sidelink-harq-operation)
        - [5.22.2.2.1 Sidelink HARQ Entity](#522221-sidelink-harq-entity)
        - [5.22.2.2.2 Sidelink process](#522222-sidelink-process)
      - [5.22.2.3 Disassembly and demultiplexing](#52223-disassembly-and-demultiplexing)
  - [5.23 SL-BCH data transfer](#523-sl-bch-data-transfer)
    - [5.23.1 SL-BCH data transmission](#5231-sl-bch-data-transmission)
    - [5.23.2 SL-BCH data reception](#5232-sl-bch-data-reception)

---

### 5.22 SL-SCH Data transfer

#### 5.22.1 SL-SCH Data transmission

##### 5.22.1.1 SL Grant reception and SCI transmission

Sidelink grant is received dynamically on the PDCCH, configured semi-persistently by RRC or autonomously selected by the MAC entity. The MAC entity shall have a sidelink grant on an active SL BWP to determine a set of PSCCH duration(s) in which transmission of SCI occurs and a set of PSSCH duration(s) in which transmission of SL-SCH associated with the SCI occurs. A sidelink grant addressed to SL-CS-RNTI with NDI = 1 is considered as a dynamic sidelink grant.

If the MAC entity has been configured with Sidelink resource allocation mode 1 as indicated in TS 38.331 [5], the MAC entity shall for each PDCCH occasion and for each grant received for this PDCCH occasion:

- `1>` if a sidelink grant has been received on the PDCCH for the MAC entity's SL-RNTI:
  - `2>` if the NDI received on the PDCCH has not been toggled compared to the value in the previously received HARQ information for the HARQ Process ID:
    - `3>` use the received sidelink grant to determine PSCCH duration(s) and PSSCH duration(s) for one or more retransmissions of a single MAC PDU for the corresponding Sidelink process according to clause 8.1.2 of TS 38.214 [7].
  - `2>` else:
    - `3>` use the received sidelink grant to determine PSCCH duration(s) and PSSCH duration(s) for initial transmission and, if available, retransmission(s) of a single MAC PDU according to clause 8.1.2 of TS 38.214 [7].
- `1>` else if a sidelink grant has been received on the PDCCH for the MAC entity's SL-CS-RNTI:
  - `2>` if PDCCH contents indicate retransmission(s) for the identifed HARQ process ID that has been set for an activated configured sidelink grant identified by _sl-ConfigIndexCG_:
    - `3>` use the received sidelink grant to determine PSCCH duration(s) and PSSCH duration(s) for one or more retransmissions of a single MAC PDU according to clause 8.1.2 of TS 38.214 [7].
  - `2>` else if PDCCH contents indicate configured grant Type 2 deactivation for a configured sidelink grant:
    - `3>` trigger configured sidelink grant confirmation for the configured sidelink grant.
  - `2>` else if PDCCH contents indicate configured grant Type 2 activation for a configured sidelink grant:
    - `3>` trigger configured sidelink grant confirmation for the configured sidelink grant;
    - `3>` store the configured sidelink grant;
    - `3>` initialise or re-initialise the configured sidelink grant to determine the set of PSCCH durations and the set of PSSCH durations for transmissions of multiple MAC PDUs according to clause 8.1.2 of TS 38.214 [7].
- `1>` if a dynamic sidelink grant is available for retransmission(s) of a MAC PDU which has been positively acknowledged as specified in clause 5.22.1.3.1a:
  - `2>` clear the PSCCH duration(s) and PSSCH duration(s) corresponding to retransmission(s) of the MAC PDU from the sidelink grant.

If the MAC entity has been configured with Sidelink resource allocation mode 2 to transmit using pool(s) of resources in a carrier as indicated in TS 38.331 [5] or TS 36.331 [21] based on sensing or random selection, the MAC entity shall for each Sidelink process:

> NOTE 1: If the MAC entity is configured with Sidelink resource allocation mode 2 to transmit using a pool of resources in a carrier as indicated in TS 38.331 [5] or TS 36.331 [21], the MAC entity can create a selected sidelink grant on the pool of resources based on random selection or sensing only after releasing configured sidelink grant(s), if any.

> NOTE 2: The MAC entity expects that PSFCH is always configured by RRC for at least one pool of resources in _sl-TxPoolSelectedNormal_ and for the resource pool in _sl-TxPoolExceptional_ in case that at least a logical channel configured with _sl-HARQ-FeedbackEnabled_ is set to _enabled_.

- `1>` if the MAC entity has selected to create a selected sidelink grant corresponding to transmissions of multiple MAC PDUs, and SL data is available in a logical channel:
  - `2>` if the MAC entity has not selected a pool of resources allowed for the logical channel:
    - `3>` if _sl-HARQ-FeedbackEnabled_ is set to _enabled_ for the logical channel:
      - `4>` select any pool of resources configured with PSFCH resources among the pools of resources;
    - `3>` else:
      - `4>` select any pool of resources among the pools of resources;
  - `2>` perform the TX resource (re-)selection check on the selected pool of resources as specified in clause 5.22.1.2;

> NOTE 3: The MAC entity continuously performs the TX resource (re-)selection check until the corresponding pool of resources is released by RRC or the MAC entity decides to cancel creating a selected sidelink grant corresponding to transmissions of multiple MAC PDUs.

  - `2>` if the TX resource (re-)selection is triggered as the result of the TX resource (re-)selection check:
    - `3>` select one of the allowed values configured by RRC in _sl-ResourceReservePeriodList_ and set the resource reservation interval, 𝑃 rsvp_TX, with the selected value;

> NOTE 3A: The MAC entity selects a value for the resource reservation interval which is larger than the remaining PDB of SL data available in the logical channel.

    - `3>` randomly select, with equal probability, an integer value in the interval [5, 15] for the resource reservation interval higher than or equal to 100ms or in the interval [5 × ⌈ 100 max(20, 𝑃rsvp_ TX)⌉, 15 × ⌈ 100 max(20, 𝑃rsvp_ TX)⌉] for the resource reservation interval lower than 100ms and set _SL_RESOURCE_RESELECTION_COUNTER_ to the selected value;
    - `3>` select the number of HARQ retransmissions from the allowed numbers, if configured by RRC, in _sl-MaxTxTransNumPSSCH_ included in _sl-PSSCH-TxConfigList_ and, if configured by RRC, overlapped in _sl-MaxTxTransNumPSSCH_ indicated in _sl-CBR-PriorityTxConfigList_ for the highest priority of the logical channel(s) allowed on the carrier and the CBR measured by lower layers according to clause 5.1.27 of TS 38.215 [24] if CBR measurement results are available or the corresponding _sl-defaultTxConfigIndex_ configured by RRC if CBR measurement results are not available;
    - `3>` select an amount of frequency resources within the range, if configured by RRC, between _sl-MinSubChannelNumPSSCH_ and _sl-MaxSubchannelNumPSSCH_ included in _sl-PSSCH-TxConfigList_ and, if configured by RRC, overlapped between _sl-MinSubChannelNumPSSCH_ and _sl-MaxSubchannelNumPSSCH_ indicated in _sl-CBR-PriorityTxConfigList_ for the highest priority of the logical channel(s) allowed on the carrier and the CBR measured by lower layers according to clause 5.1.27 of TS 38.215 [24] if CBR measurement results are available or the corresponding _sl-defaultTxConfigIndex_ configured by RRC if CBR measurement results are not available;
    - `3>` if transmission based on random selection is configured by upper layers:
      - `4>` randomly select the time and frequency resources for one transmission opportunity from the resource pool, according to the amount of selected frequency resources and the remaining PDB of SL data available in the logical channel(s) allowed on the carrier.
    - `3>` else:
      - `4>` randomly select the time and frequency resources for one transmission opportunity from the resources indicated by the physical layer as specified in clause 8.1.4 of TS 38.214 [7], according to the amount of selected frequency resources and the remaining PDB of SL data available in the logical channel(s) allowed on the carrier.
    - `3>` use the randomly selected resource to select a set of periodic resources spaced by the resource reservation interval for transmissions of PSCCH and PSSCH corresponding to the number of transmission opportunities of MAC PDUs determined in TS 38.214 [7];
    - `3>` if one or more HARQ retransmissions are selected:
      - `4>` if transmission based on sensing is configured by upper layers and there are available resources left in the resources indicated by the physical layer according to clause 8.1.4 of TS 38.214 [7] for more transmission opportunities; or
      - `4>` if transmission based on random selection is configured by upper layers and there are available resources left in the resource pool for more transmission opportunities:
        - `5>` randomly select the time and frequency resources for one or more transmission opportunities from the available resources, according to the amount of selected frequency resources, the selected number of HARQ retransmissions and the remaining PDB of SL data available in the logical channel(s) allowed on the carrier by ensuring the minimum time gap between any two selected resources in case that PSFCH is configured for this pool of resources and that a retransmission resource can be indicated by the time resource assignment of a prior SCI according to clause 8.3.1.1 of TS 38.212 [9];
        - `5>` use the randomly selected resource to select a set of periodic resources spaced by the resource reservation interval for transmissions of PSCCH and PSSCH corresponding to the number of retransmission opportunities of the MAC PDUs determined in TS 38.214 [7];
        - `5>` consider the first set of transmission opportunities as the initial transmission opportunities and the other set(s) of transmission opportunities as the retransmission opportunities;
        - `5>` consider the sets of initial transmission opportunities and retransmission opportunities as the selected sidelink grant.
    - `3>` else:
      - `4>` consider the set as the selected sidelink grant.
    - `3>` use the selected sidelink grant to determine the set of PSCCH durations and the set of PSSCH durations according to TS 38.214 [7].
  - `2>` else if _SL_RESOURCE_RESELECTION_COUNTER_ = 0 and when _SL_RESOURCE_RESELECTION_COUNTER_ was equal to 1 the MAC entity randomly selected, with equal probability, a value in the interval [0, 1] which is less than or equal to the probability configured by RRC in _sl-ProbResourceKeep_:
    - `3>` clear the selected sidelink grant, if available;
    - `3>` randomly select, with equal probability, an integer value in the interval [5, 15] for the resource reservation interval higher than or equal to 100ms or in the interval [5 × ⌈ 100 max(20, 𝑃rsvp_ TX)⌉, 15 × ⌈ 100 max(20, 𝑃rsvp_ TX)⌉] for the resource reservation interval lower than 100ms and set _SL_RESOURCE_RESELECTION_COUNTER_ to the selected value;
    - `3>` reuse the previously selected sidelink grant for the number of transmissions of the MAC PDUs determined in TS 38.214 [7] with the resource reservation interval to determine the set of PSCCH durations and the set of PSSCH durations according to TS 38.214 [7].
- `1>` if the MAC entity has selected to create a selected sidelink grant corresponding to transmission(s) of a single MAC PDU, and if SL data is available in a logical channel, or an SL-CSI reporting is triggered:
  - `2>` if SL data is available in the logical channel:
    - `3>` if _sl-HARQ-FeedbackEnabled_ is set to _enabled_ for the logical channel:
      - `4>` select any pool of resources configured with PSFCH resources among the pools of resources;
    - `3>` else:
      - `4>` select any pool of resources among the pools of resources;
  - `2>` else if an SL-CSI reporting is triggered:
    - `3>` select any pool of resources among the pools of resources.
  - `2>` perform the TX resource (re-)selection check on the selected pool of resources as specified in clause 5.22.1.2;
  - `2>` if the TX resource (re-)selection is triggered as the result of the TX resource (re-)selection check:
    - `3>` select the number of HARQ retransmissions from the allowed numbers, if configured by RRC, in _sl-MaxTxTransNumPSSCH_ included in _sl-PSSCH-TxConfigList_ and, if configured by RRC, overlapped in _sl-MaxTxTransNumPSSCH_ indicated in _sl-CBR-PriorityTxConfigList_ for the highest priority of the logical channel(s) allowed on the carrier and the CBR measured by lower layers according to clause 5.1.27 of TS 38.215 [24] if CBR measurement results are available or the corresponding _sl-defaultTxConfigIndex_ configured by RRC if CBR measurement results are not available;
    - `3>` select an amount of frequency resources within the range, if configured by RRC, between _sl-MinSubChannelNumPSSCH_ and _sl-MaxSubChannelNumPSSCH_ included in _sl-PSSCH-TxConfigList_ and, if configured by RRC, overlapped between _sl-MinSubChannelNumPSSCH_ and _sl-MaxSubChannelNumPSSCH_ indicated in _sl-CBR-PriorityTxConfigList_ for the highest priority of the logical channel(s) allowed on the carrier and the CBR measured by lower layers according to clause 5.1.27 of TS 38.215 [24] if CBR measurement results are available or the corresponding _sl-defaultTxConfigIndex_ configured by RRC if CBR measurement results are not available;
    - `3>` if transmission based on random selection is configured by upper layers:
      - `4>` randomly select the time and frequency resources for one transmission opportunity from the resource pool, according to the amount of selected frequency resources and the remaining PDB of SL data available in the logical channel(s) allowed on the carrier, and the latency requirement of the triggered SL CSI reporting;
    - `3>` else:
      - `4>` randomly select the time and frequency resources for one transmission opportunity from the resources indicated by the physical layer as specified in clause 8.1.4 of TS 38.214 [7], according to the amount of selected frequency resources and the remaining PDB of SL data available in the logical channel(s) allowed on the carrier, and/or the latency requirement of the triggered SL-CSI reporting;
    - `3>` if one or more HARQ retransmissions are selected:
      - `4>` if transmission based on sensing is configured by upper layers and there are available resources left in the resources indicated by the physical layer according to clause 8.1.4 of TS 38.214 [7] for more transmission opportunities; or
      - `4>` if transmission based on random selection is configured by upper layers and there are available resources left in the resource pool for more transmission opportunities:
        - `5>` randomly select the time and frequency resources for one or more transmission opportunities from the available resources, according to the amount of selected frequency resources, the selected number of HARQ retransmissions and the remaining PDB of SL data available in the logical channel(s) allowed on the carrier, and/or the latency requirement of the triggered SL-CSI by ensuring the minimum time gap between any two selected resources in case that PSFCH is configured for this pool of resources, and that a retransmission resource can be indicated by the time resource assignment of a prior SCI according to clause 8.3.1.1 of TS 38.212 [9];
        - `5>` consider a transmission opportunity which comes first in time as the initial transmission opportunity and other transmission opportunities as the retransmission opportunities;
        - `5>` consider all the transmission opportunities as the selected sidelink grant;
    - `3>` else:
      - `4>` consider the set as the selected sidelink grant;
    - `3>` use the selected sidelink grant to determine PSCCH duration(s) and PSSCH duration(s) according to TS 38.214 [7].

> NOTE 3B: If retransmission resource(s) cannot be selected by ensuring that the resource(s) can be indicated by the time resource assignment of a prior SCI, how to select the time and frequency resources for one or more transmission opportunities from the available resources is left for UE implementation by ensuring the minimum time gap between any two selected resources in case that PSFCH is configured for this pool of resources.

- `1>` if a selected sidelink grant is available for retransmission(s) of a MAC PDU which has been positively acknowledged as specified in clause 5.22.1.3.1a:
  - `2>` clear the PSCCH duration(s) and PSSCH duration(s) corresponding to retransmission(s) of the MAC PDU from the selected sidelink grant.

> NOTE 3C: How the MAC entity determines the remaining PDB of SL data is left to UE implementation.

For a selected sidelink grant, the minimum time gap between any two selected resources comprises:

- a time gap between the end of the last symbol of a PSSCH transmission of the first resource and the start of the first symbol of the corresponding PSFCH reception determined by _sl-MinTimeGapPSFCH_ and _sl-PSFCH-Period_ for the pool of resources; and
- a time required for PSFCH reception and processing plus sidelink retransmission preparation including multiplexing of necessary physical channels and any TX-RX/RX-TX switching time.

> NOTE: How to determine the time required for PSFCH reception and processing plus sidelink retransmission preparation is left to UE implementation.

The MAC entity shall for each PSSCH duration:

- `1>` for each sidelink grant occurring in this PSSCH duration:
  - `2>` select a MCS table allowed in the pool of resource which is associated with the sidelink grant;

> NOTE 4a: MCS table selection is up to UE implementation if more than one MCS table is configured.

  - `2>` if the MAC entity has been configured with Sidelink resource allocation mode 1:
    - `3>` select a MCS which is, if configured, within the range that is configured by RRC between _sl-MinMCS-PSSCH_ and _sl-MaxMCS-PSSCH_ associated with the selected MCS table included in _sl-ConfigDedicatedNR_;
    - `3>` set the resource reservation interval to 0ms.
  - `2>` else:
    - `3>` select a MCS which is, if configured, within the range, if configured by RRC, between _sl-MinMCS-PSSCH_ and _sl-MaxMCS-PSSCH_ associated with the selected MCS table included in _sl-PSSCH-TxConfigList_ and, if configured by RRC, overlapped between _sl-MinMCS-PSSCH_ and _sl-MaxMCS-PSSCH_ associated with the selected MCS table indicated in _sl-CBR-PriorityTxConfigList_ for the highest priority of the sidelink logical channel(s) in the MAC PDU and the CBR measured by lower layers according to clause 5.1.27 of TS 38.215 [24] if CBR measurement results are available or the corresponding _sl-defaultTxConfigIndex_ configured by RRC if CBR measurement results are not available;
    - `3>` if the MAC entity decides not to use the selected sidelink grant for the next PSSCH duration corresponding to an initial transmission opportunity:
      - `4>` set the resource reservation interval to 0ms.
    - `3>` else:
      - `4>` set the resource reservation interval to the selected value.

> NOTE 5: MCS selection is up to UE implementation if the MCS or the corresponding range is not configured by RRC.

  - `2>` if the configured sidelink grant has been activated and this PSSCH duration corresponds to the first PSSCH transmission opportunity within this _sl-PeriodCG_ of the configured sidelink grant:
    - `3>` set the HARQ Process ID to the HARQ Process ID associated with this PSSCH duration and, if available, all subsequent PSSCH duration(s) occuring in this _sl-PeriodCG_ for the configured sidelink grant;
    - `3>` determine that this PSSCH duration is used for initial transmission;
    - `3>` flush the HARQ buffer of Sidelink process associated with the HARQ Process ID.
  - `2>` deliver the sidelink grant, the selected MCS, and the associated HARQ information to the Sidelink HARQ Entity for this PSSCH duration.

For configured sidelink grants, the HARQ Process ID associated with the first slot of an SL transmission is derived from the following equation:

HARQ Process ID = [floor(CURRENT_slot / _PeriodicitySL_)] modulo _sl-NrOfHARQ-Processes_ + _sl-HARQ-ProcID-offset_ where CURRENT_slot refers to current logical slot in the associated resource pool, and _PeriodicitySL_ is defined in clause 5.8.3.

##### 5.22.1.2 TX resource (re-)selection check

If the TX resource (re-)selection check procedure is triggered on the selected pool of resources for a Sidelink process according to clause 5.22.1.1, the MAC entity shall for the Sidelink process:

- `1>` if _SL_RESOURCE_RESELECTION_COUNTER_ = 0 and when _SL_RESOURCE_RESELECTION_COUNTER_ was equal to 1 the MAC entity randomly selected, with equal probability, a value in the interval [0, 1] which is above the probability configured by RRC in _sl-ProbResourceKeep_; or
- `1>` if the pool of resources is configured or reconfigured by RRC; or
- `1>` if there is no selected sidelink grant on the selected pool of resources; or
- `1>` if neither transmission nor retransmission has been performed by the MAC entity on any resource indicated in the selected sidelink grant during the last second; or
- `1>` if _sl-ReselectAfter_ is configured and the number of consecutive unused transmission opportunities on resources indicated in the selected sidelink grant, which is incremented by 1 when none of the resources of the selected sidelink grant within a resource reservation interval is used, is equal to _sl-ReselectAfter_; or
- `1>` if the selected sidelink grant cannot accommodate a RLC SDU by using the maximum allowed MCS configured by RRC in _sl-MaxMCS-PSSCH_ associated with the selected MCS table and the UE selects not to segment the RLC SDU; or

> NOTE 1: If the selected sidelink grant cannot accommodate the RLC SDU, it is left for UE implementation whether to perform segmentation or sidelink resource reselection.

- `1>` if transmission(s) with the selected sidelink grant cannot fulfil the remaining PDB of the data in a logical channel, and the MAC entity selects not to perform transmission(s) corresponding to a single MAC PDU:

> NOTE 2: If the remaining PDB is not met, it is left for UE implementation whether to perform transmission(s) corresponding to single MAC PDU or sidelink resource reselection.

> NOTE 3: It is left for UE implementation whether to trigger the TX resource (re-)selection due to the latency requirement of the MAC CE triggered according to clause 5.22.1.7.

  - `2>` clear the selected sidelink grant associated to the Sidelink process, if available;
  - `2>` trigger the TX resource (re-)selection.

> NOTE 4: Void.

> NOTE 5: Void.

##### 5.22.1.2a Re-evaluation and Pre-emption

A resource(s) of the selected sidelink grant for a MAC PDU to transmit from multiplexing and assembly entity is re- evaluated by physical layer at _T__3_ before the slot where the SCI indicating the resource(s) is signalled at first time as specified in clause 8.1.4 of TS 38.214 [7].

A resource(s) of the selected sidelink grant which has been indicated by a prior SCI for a MAC PDU to transmit from multiplexing and assembly entity could be checked for pre-emption by physical layer at _T__3_ before the slot where the resource(s) is located as specified in clause 8.1.4 of TS 38.214 [7].

> NOTE 1: It is up to UE implementation to re-evaluate or pre-empt before 'm – _T__3_ ' or after 'm – _T__3_ ' but before 'm'.

For re-evaluation, m is the slot where the SCI indicating the resource(s) is signalled at first time as specified in clause 8.1.4 of TS 38.214. For pre-emption, m is the slot where the resource(s) is located as specified in clause 8.1.4 of TS 38.214.

If the MAC entity has been configured with Sidelink resource allocation mode 2 to transmit using pool(s) of resources in a carrier as indicated in TS 38.331 [5] or TS 36.331 [21] based on sensing or random selection the MAC entity shall for each Sidelink process:

- `1>` if a resource(s) of the selected sidelink grant which has not been identified by a prior SCI is indicated for re- evaluation by the physical layer as specified in clause 8.1.4 of TS 38.214 [7]; or
- `1>` if any resource(s) of the selected sidelink grant which has been indicated by a prior SCI is indicated for pre- emption by the physical layer as specified in clause 8.1.4 of TS 38.214 [7]:
  - `2>` remove the resource(s) from the selected sidelink grant associated to the Sidelink process;
  - `2>` randomly select the time and frequency resource from the resources indicated by the physical layer as specified in clause 8.1.4 of TS 38.214 [7] for either the removed resource or the dropped resource, according to the amount of selected frequency resources, the selected number of HARQ retransmissions and the remaining PDB of either SL data available in the logical channel(s) by ensuring the minimum time gap between any two selected resources of the selected sidelink grant in case that PSFCH is configured for this pool of resources, and that a resource can be indicated by the time resource assignment of an SCI for a retransmission according to clause 8.3.1.1 of TS 38.212 [9];

> NOTE 2: If retransmission resource(s) cannot be selected by ensuring that the resource(s) can be indicated by the time resource assignment of a prior SCI, how to select the time and frequency resources for one or more transmission opportunities from the available resources is left for UE implementation by ensuring the minimum time gap between any two selected resources in case that PSFCH is configured for this pool of resources.

  - `2>` replace the removed or dropped resource(s) by the selected resource(s) for the selected sidelink grant.

> NOTE 3: It is left for UE implementation to reselect any pre-selected but not reserved resource(s) other than the resource(s) indicated for pre-emption or re-evaluation by the physical layer during reselection triggered by re-evaluation or pre-emption indicated by the physical layer.

> NOTE 4: It is up to UE implementation whether to set the resource reservation interval in the re-selected resource to replace pre-empted resource.

> NOTE 5: It is up to UE implementation whether to trigger resource reselection due to deprioritization as specified in clause 16.2.4 of TS 38.213 [6], clause 5.14.1.2.2 of TS 36.321 [22] and clause 5.22.1.3.1a.

> NOTE 6: For the selected sidelink grant corresponds to transmissions of multiple MAC PDU, it is up to UE implementation whether to apply re-evaluation check to the resources in non-initial reservation period that have been signalled neither in the immediate last nor in the current period.

##### 5.22.1.3 Sidelink HARQ operation

###### 5.22.1.3.1 Sidelink HARQ Entity

The MAC entity includes at most one Sidelink HARQ entity for transmission on SL-SCH, which maintains a number of parallel Sidelink processes.

The maximum number of transmitting Sidelink processes associated with the Sidelink HARQ Entity is 16. A sidelink process may be configured for transmissions of multiple MAC PDUs. For transmissions of multiple MAC PDUs with Sidelink resource allocation mode 2, the maximum number of transmitting Sidelink processes associated with the Sidelink HARQ Entity is 4.

A delivered sidelink grant and its associated Sidelink transmission information are associated with a Sidelink process.

Each Sidelink process supports one TB.

For each sidelink grant, the Sidelink HARQ Entity shall:

- `1>` if the MAC entity determines that the sidelink grant is used for initial transmission as specified in clause 5.22.1.1; or
- `1>` if the sidelink grant is a configured sidelink grant and no MAC PDU has been obtained in an _sl-PeriodCG_ of the configured sidelink grant:

> NOTE 1: Void.

  - `2>` (re-)associate a Sidelink process to this grant, and for the associated Sidelink process:

> NOTE 1A: The Sidelink HARQ Entity will associate the selected sidelink grant to the Sidelink process determined by the MAC entity.

    - `3>` obtain the MAC PDU to transmit from the Multiplexing and assembly entity, if any;
    - `3>` if a MAC PDU to transmit has been obtained:
      - `4>` if a HARQ Process ID has been set for the sidelink grant:
        - `5>` (re-)associate the HARQ Process ID corresponding to the sidelink grant to the Sidelink process;

> NOTE 1a: There is one-to-one mapping between a HARQ Process ID and a Sidelink process in the MAC entity configured with Sidelink resource allocation mode 1.

      - `4>` determines Sidelink transmission information of the TB for the source and destination pair of the MAC PDU as follows:
        - `5>` set the Source Layer-1 ID to the 8 LSB of the Source Layer-2 ID of the MAC PDU;
        - `5>` set the Destination Layer-1 ID to the 16 LSB of the Destination Layer-2 ID of the MAC PDU;
        - `5>` (re-)associate the Sidelink process to a Sidelink process ID;

> NOTE 1b: How UE determine Sidelink process ID in SCI is left to UE implementation for NR sidelink.

        - `5>` consider the NDI to have been toggled compared to the value of the previous transmission corresponding to the Sidelink identification information and the Sidelink process ID of the MAC PDU and set the NDI to the toggled value;

> NOTE 2: The initial value of the NDI set to the very first transmission for the associated Sidelink process is left to UE implementation.

> NOTE 3: Void.

        - `5>` if the MAC PDU includes only Sidelink MAC CE:
          - `6>` set the cast type indicator to unicast.
        - `5>` else:
          - `6>` set the cast type indicator to one of broadcast, groupcast and unicast as indicated by upper layers.
        - `5>` if HARQ feedback has been enabled for the MAC PDU according to clause 5.22.1.4.2;
          - `6>` set the HARQ feedback enabled/disabled indicator to _enabled_.
        - `5>` else:
          - `6>` set the HARQ feedback enabled/disabled indicator to _disabled_.
        - `5>` set the priority to the value of the highest priority of the logical channel(s), if any, and a MAC CE, if included, in the MAC PDU;
        - `5>` if HARQ feedback is enabled for groupcast:
          - `6>` if both a group size and a member ID are provided by upper layers and the group size is not greater than the number of candidate PSFCH resources associated with this sidelink grant:
            - `7>` select either positive-negative acknowledgement or negative-only acknowledgement.

> NOTE 4: Selection of positive-negative acknowledgement or negative-only acknowledgement is up to UE implementation.

          - `6>` else:
            - `7>` select negative-only acknowledgement.
          - `6>` if negative-only acknowledgement is selected, UE's location information is available, and _sl-TransRange_ has been configured for a logical channel in the MAC PDU, and _sl-ZoneConfig_ is configured as specified in TS 38.331 [5]:
            - `7>` set the communication range requirement to the value of the longest communication range of the logical channel(s) in the MAC PDU;
            - `7>` determine the value of _sl-ZoneLength_ corresponding to the communication range requirement and set Zone_id to the value of Zone_id calculated using the determined value of _sl-ZoneLength_ as specified in TS 38.331 [5].
        - `5>` set the Redundancy version to the selected value.
      - `4>` deliver the MAC PDU, the sidelink grant and the Sidelink transmission information of the TB to the associated Sidelink process;
      - `4>` instruct the associated Sidelink process to trigger a new transmission.
    - `3>` else:
      - `4>` flush the HARQ buffer of the associated Sidelink process.
- `1>` else (i.e. retransmission):
  - `2>` if the HARQ Process ID corresponding to the sidelink grant received on PDCCH, the configured sidelink grant or the selected sidelink grant is associated to a Sidelink process of which HARQ buffer is empty; or
  - `2>` if the HARQ Process ID corresponding to the sidelink grant received on PDCCH is not associated to any Sidelink process:
    - `3>` ignore the sidelink grant.
  - `2>` else:
    - `3>` identify the Sidelink process associated with this grant, and for the associated Sidelink process:
      - `4>` deliver the sidelink grant of the MAC PDU to the associated Sidelink process;
      - `4>` instruct the associated Sidelink process to trigger a retransmission.

###### 5.22.1.3.1a Sidelink process

The Sidelink process is associated with a HARQ buffer.

New transmissions and retransmissions are performed on the resource indicated in the sidelink grant as specified in clause 5.22.1.1 and with the MCS selected as specified in clause 8.1.3.1 of TS 38.214 [7] and clause 5.22.1.1.

If the Sidelink process is configured to perform transmissions of multiple MAC PDUs with Sidelink resource allocation mode 2, the process maintains a counter _SL_RESOURCE_RESELECTION_COUNTER_. For other configurations of the Sidelink process, this counter is not available.

Priority of a MAC PDU is determined by the highest priority of the logical channel(s) or a MAC CE in the MAC PDU.

If the Sidelink HARQ Entity requests a new transmission, the Sidelink process shall:

- `1>` store the MAC PDU in the associated HARQ buffer;
- `1>` store the sidelink grant received from the Sidelink HARQ Entity;
- `1>` generate a transmission as described below.

If the Sidelink HARQ Entity requests a retransmission, the Sidelink process shall:

- `1>` store the sidelink grant received from the Sidelink HARQ Entity;
- `1>` generate a transmission as described below.

To generate a transmission, the Sidelink process shall:

- `1>` if there is no uplink transmission; or
- `1>` if the MAC entity is able to simultaneously perform uplink transmission(s) and sidelink transmission at the time of the transmission; or
- `1>` if the other MAC entity and the MAC entity are able to simultaneously perform uplink transmission(s) and sidelink transmission at the time of the transmission respectively; or
- `1>` if there is a MAC PDU to be transmitted for this duration in uplink, except a MAC PDU obtained from the Msg3 buffer, the MSGA buffer, or prioritized as specified in clause 5.4.2.2, and the sidelink transmission is prioritized over uplink transmission:
  - `2>` instruct the physical layer to transmit SCI according to the stored sidelink grant with the associated Sidelink transmission information;
  - `2>` instruct the physical layer to generate a transmission according to the stored sidelink grant;
  - `2>` if HARQ feedback has been enabled for the MAC PDU according to clause 5.22.1.4.2:
    - `3>` instruct the physical layer to monitor PSFCH for the transmission and perform PSFCH reception as specified in clause 5.22.1.3.2.
  - `2>` if _sl-PUCCH-Config_ is configured by RRC for the stored sidelink grant:
    - `3>` determine transmission of an acknowledgement on the PUCCH as specified in clause 5.22.1.3.2.
- `1>` if this transmission corresponds to the last transmission of the MAC PDU:
  - `2>` decrement _SL_RESOURCE_RESELECTION_COUNTER_ by 1, if available.

> NOTE 1: If the number of HARQ retransmissions selected by the MAC entity has been reached, or if a positive acknowledgement to a transmission of the MAC PDU has been received, or if a negative-only acknowledgement was enabled in the SCI and no negative acknowledgement was received for the transmission of the MAC PDU, the MAC entity determines this transmission corresponds to the last transmission of the MAC PDU for Sidelink resource allocation mode 2. How to determine the last transmission in other cases is up to UE implementation.

- `1>` if _sl-MaxTransNum_ corresponding to the highest priority of the logical channel(s) in the MAC PDU has been configured in _sl-CG-MaxTransNumList_ for the sidelink grant by RRC and the number of transmissions of the MAC PDU has been reached to _sl-MaxTransNum_; or
- `1>` if a positive acknowledgement to this transmission of the MAC PDU was received according to clause 5.22.1.3.2; or
- `1>` if negative-only acknowledgement was enabled in the SCI and no negative acknowledgement was received for this transmission of the MAC PDU according to clause 5.22.1.3.2:
  - `2>` flush the HARQ buffer of the associated Sidelink process.

The transmission of the MAC PDU is prioritized over uplink transmission(s) of the MAC entity or the other MAC entity if the following conditions are met:

- `1>` if the MAC entity is not able to perform this sidelink transmission simultaneously with all uplink transmission(s) at the time of the transmission, and
- `1>` if none of the uplink transmission(s) is prioritized by upper layer according to TS 23.287 [19], and
- `1>` if none of the NR uplink MAC PDU(s) includes any MAC CE prioritized as described in clause 5.4.3.1.3, and
- `1>` if _ul-PrioritizationThres_ is configured and if the value of the highest priority of logical channel(s) of all the NR uplink transmission(s) is not lower than _ul-PrioritizationThres_, and
- `1>` if _sl-PrioritizationThres_ is configured and if the value of the highest priority of logical channel(s) or a MAC CE in the MAC PDU is lower than _sl-PrioritizationThres_.

> NOTE 2: If the MAC entity is not able to perform this sidelink transmission simultaneously with all uplink transmissions as specified in clause 5.4.2.2 of TS 36.321 [22] at the time of the transmission, and prioritization-related information is not available prior to the time of this sidelink transmission due to processing time restriction, it is up to UE implementation whether this sidelink transmission is performed.

###### 5.22.1.3.2 PSFCH reception

The MAC entity shall for each PSSCH transmission:

- `1>` if an acknowledgement corresponding to the PSSCH transmission in clause 5.22.1.3.1a is obtained from the physical layer:
  - `2>` deliver the acknowledgement to the corresponding Sidelink HARQ entity for the Sidelink process;
- `1>` else:
  - `2>` deliver a negative acknowledgement to the corresponding Sidelink HARQ entity for the Sidelink process;
- `1>` if the PSSCH transmission occurs for a pair of Source Layer-2 ID and Destination Layer-2 ID corresponding to a PC5-RRC connection which has been established by upper layers:
  - `2>` perform the HARQ-Based Sidelink RLF Detection procedure as specified in clause 5.22.1.3.3.

If _sl-PUCCH-Config_ is configured by RRC, the MAC entity shall for a PUCCH transmission occasion:

- `1>` if the _timeAlignmentTimer_, associated with the TAG containing the Serving Cell on which the HARQ feedback is to be transmitted, is stopped or expired:
  - `2>` not instruct the physical layer to generate acknowledgement(s) of the data in this TB.
- `1>` else if a MAC PDU has been obtained for a sidelink grant associated to the PUCCH transmission occasion in clause 5.22.1.3.1, the MAC entity shall:
  - `2>` if the most recent transmission of the MAC PDU was not prioritized as specified in clause 5.22.1.3.1a:
    - `3>` instruct the physical layer to signal a negative acknowledgement on the PUCCH according to clause 16.5 of TS 38.213 [6].
  - `2>` else if HARQ feedback has been disabled for the MAC PDU and next retransmission(s) of the MAC PDU is not required:
    - `3>` instruct the physical layer to signal a positive acknowledgement corresponding to the transmission on the PUCCH according to clause 16.5 of TS 38.213 [6].
  - `2>` else if HARQ feedback has been disabled for the MAC PDU, and no sidelink grant is available for next retransmission(s) of the MAC PDU (including immediately after all PSSCH duration(s) in an _sl-PeriodCG_ for the sidelink grant, the number of transmissions of the MAC PDU has not reached _sl-MaxTransNum_ corresponding to the highest priority of the logical channel(s) in the MAC PDU, if configured in _sl-CG-MaxTransNumList_ for the sidelink grant by RRC), if any:
    - `3>` instruct the physical layer to signal a negative acknowledgement corresponding to the transmission on the PUCCH according to clause 16.5 of TS 38.213 [6].
  - `2>` else:
    - `3>` instruct the physical layer to signal an acknowledgement corresponding to the transmission on the PUCCH according to clause 16.5 of TS 38.213 [6]
- `1>` else:
  - `2>` instruct the physical layer to signal a positive acknowledgement on the PUCCH according to clause 16.5 of TS 38.213 [6].

###### 5.22.1.3.3 HARQ-based Sidelink RLF detection

The HARQ-based Sidelink RLF detection procedure is used to detect Sidelink RLF based on a number of consecutive DTX on PSFCH reception occasions for a PC5-RRC connection.

RRC configures the following parameter to control HARQ-based Sidelink RLF detection:

- _sl-maxNumConsecutiveDTX_.

The following UE variable is used for HARQ-based Sidelink RLF detection.

- _numConsecutiveDTX_, which is maintained for each PC5-RRC connection.

The Sidelink HARQ Entity shall (re-)initialize _numConsecutiveDTX_ to zero for each PC5-RRC connection which has been established by upper layers, if any, upon establishment of the PC5-RRC connection or (re)configuration of _sl-maxNumConsecutiveDTX_.

The Sidelink HARQ Entity shall for each PSFCH reception occasion associated to the PSSCH transmission:

- `1>` if PSFCH reception is absent on the PSFCH reception occasion:
  - `2>` increment _numConsecutiveDTX_ by 1;
  - `2>` if _numConsecutiveDTX_ reaches _sl-maxNumConsecutiveDTX_:
    - `3>` indicate HARQ-based Sidelink RLF detection to RRC.
- `1>` else:
  - `2>` re-initialize _numConsecutiveDTX_ to zero.

##### 5.22.1.4 Multiplexing and assembly

###### 5.22.1.4.0 General

For PDU(s) associated with one SCI, MAC shall consider only logical channels with the same Source Layer-2 ID- Destination Layer-2 ID pair for one of unicast, groupcast and broadcast which is associated with the pair. Multiple transmissions for different Sidelink processes are allowed to be independently performed in different PSSCH durations.

###### 5.22.1.4.1 Logical channel prioritization

###### 5.22.1.4.1.1 General

The sidelink Logical Channel Prioritization procedure is applied whenever a new transmission is performed.

RRC controls the scheduling of sidelink data by signalling for each logical channel:

- _sl-Priority_ where an increasing priority value indicates a lower priority level;
- _sl-PrioritisedBitRate_ which sets the sidelink Prioritized Bit Rate (sPBR);
- _sl-BucketSizeDuration_ which sets the sidelink Bucket Size Duration (sBSD).

RRC additionally controls the LCP procedure by configuring mapping restrictions for each logical channel:

- _sl-configuredGrantType1Allowed_ which sets whether a configured grant Type 1 can be used for sidelink transmission;
- _sl-AllowedCG-List_ which sets the allowed configured grant(s) for sidelink transmission;
- _sl-HARQ-FeedbackEnabled_ which sets whether the logical channel is allowed to be multiplexed with logical channel(s) with _sl-HARQ-FeedbackEnabled_ set to _enabled_ or _disabled_.

The following UE variable is used for the Logical channel prioritization procedure:

- _SBj_ which is maintained for each logical channel _j_.

The MAC entity shall initialize _SBj_ of the logical channel to zero when the logical channel is established.

For each logical channel _j_, the MAC entity shall:

- `1>` increment _SBj_ by the product sPBR × T before every instance of the LCP procedure, where T is the time elapsed since _SBj_ was last incremented;
- `1>` if the value of _SBj_ is greater than the sidelink bucket size (i.e. sPBR × sBSD):
  - `2>` set _SBj_ to the sidelink bucket size.

> NOTE: The exact moment(s) when the UE updates _SBj_ between LCP procedures is up to UE implementation, as long as _SBj_ is up to date at the time when a grant is processed by LCP.

###### 5.22.1.4.1.2 Selection of logical channels

The MAC entity shall for each SCI corresponding to a new transmission:

- `1>` select a Destination associated to one of unicast, groupcast and broadcast, having at least one of the MAC CE and the logical channel with the highest priority, among the logical channels that satisfy all the following conditions and MAC CE(s), if any, for the SL grant associated to the SCI:
  - `2>` SL data is available for transmission; and
  - `2>` _SBj_ > 0, in case there is any logical channel having _SBj_ > 0; and
  - `2>` _sl-configuredGrantType1Allowed_, if configured, is set to _true_ in case the SL grant is a Configured Grant Type 1; and
  - `2>` _sl-AllowedCG-List_, if configured, includes the configured grant index associated to the SL grant; and
  - `2>` _sl-HARQ-FeedbackEnabled_ is set to _disabled_, if PSFCH is not configured for the SL grant associated to the SCI.

> NOTE 1: If multiple Destinations have the logical channels satisfying all conditions above with the same highest priority or if multiple Destinations have either the MAC CE and/or the logical channels satisfying all conditions above with the same priority as the MAC CE, which Destination is selected among them is up to UE implementation.

- `1>` select the logical channels satisfying all the following conditions among the logical channels belonging to the selected Destination:
  - `2>` SL data is available for transmission; and
  - `2>` _sl-configuredGrantType1Allowed_, if configured, is set to _true_ in case the SL grant is a Configured Grant Type 1; and.
  - `2>` _sl-AllowedCG-List_, if configured, includes the configured grant index associated to the SL grant; and
  - `2>` _sl-HARQ-FeedbackEnabled_ is set to the value that satisfies the following conditions:
    - `3>` if PSFCH is configured for the sidelink grant associated to the SCI:
      - `4>` _sl-HARQ-FeedbackEnabled_ is set to _enabled_, if _sl-HARQ-FeedbackEnabled_ is set to _enabled_ for the highest priority logical channel satisfying the above conditions; or
      - `4>` _sl-HARQ-FeedbackEnabled_ is set to _disabled_, if _sl-HARQ-FeedbackEnabled_ is set to _disabled_ for the highest priority logical channel satisfying the above conditions.
    - `3>` else:
      - `4>` _sl-HARQ-FeedbackEnabled_ is set to disabled.

> NOTE 2: HARQ feedback enabled/disabled indicator is set to disabled for the transmission of a MAC PDU only carrying CSI reporting MAC CE.

###### 5.22.1.4.1.3 Allocation of sidelink resources

The MAC entity shall for each SCI corresponding to a new transmission:

- `1>` allocate resources to the logical channels as follows:
  - `2>` logical channels selected in clause 5.22.1.4.1.2 for the SL grant with _SBj_ > 0 are allocated resources in a decreasing priority order. If the sPBR of a logical channel is set to _infinity_, the MAC entity shall allocate resources for all the data that is available for transmission on the logical channel before meeting the sPBR of the lower priority logical channel(s);
  - `2>` decrement _SBj_ by the total size of MAC SDUs served to logical channel _j_ above;
  - `2>` if any resources remain, all the logical channels selected in clause 5.22.1.4.1.2 are served in a strict decreasing priority order (regardless of the value of _SBj_) until either the data for that logical channel or the SL grant is exhausted, whichever comes first. Logical channels configured with equal priority should be served equally.

> NOTE: The value of _SBj_ can be negative.

The UE shall also follow the rules below during the SL scheduling procedures above:

- the UE should not segment an RLC SDU (or partially transmitted SDU or retransmitted RLC PDU) if the whole SDU (or partially transmitted SDU or retransmitted RLC PDU) fits into the remaining resources of the associated MAC entity;
- if the UE segments an RLC SDU from the logical channel, it shall maximize the size of the segment to fill the grant of the associated MAC entity as much as possible;
- the UE should maximise the transmission of data;
- if the MAC entity is given a sidelink grant size that is equal to or larger than 12 bytes while having data available and allowed (according to clause 5.22.1.4.1) for transmission, the MAC entity shall not transmit only padding;
- A logical channel configured with _sl-HARQ-FeedbackEnabled_ set to _enabled_ and a logical channel configured with _sl-HARQ-FeedbackEnabled_ set to _disabled_ cannot be multiplexed into the same MAC PDU.

The MAC entity shall not generate a MAC PDU for the HARQ entity if the following conditions are satisfied:

- there is no Sidelink CSI Reporting MAC CE generated for this PSSCH transmission as specified in clause 5.22.1.7; and
- the MAC PDU includes zero MAC SDUs.

Logical channels shall be prioritised in accordance with the following order (highest priority listed first):

- data from SCCH;
- Sidelink CSI Reporting MAC CE;
- data from any STCH.

###### 5.22.1.4.2 Multiplexing of MAC Control Elements and MAC SDUs

The MAC entity shall multiplex a MAC CE and MAC SDUs in a MAC PDU according to clauses 5.22.1.4.1 and 6.1.6.

##### 5.22.1.5 Scheduling Request

In addition to clause 5.4.4, the Scheduling Request (SR) is also used for requesting SL-SCH resources for new transmission when triggered by the Sidelink BSR (clause 5.22.1.6) or the SL-CSI reporting (clause 5.22.1.7). If configured, the MAC entity performs the SR procedure as specified in this clause unless otherwise specified in clause 5.4.4. For a sidelink logical channel or for SL-CSI reporting, at most one PUCCH resource for SR is configured per UL BWP.

The SR configuration of the logical channel that triggered the Sidelink BSR (clause 5.22.1.6) (if such a configuration exists) is also considered as corresponding SR configuration for the triggered SR (clause 5.4.4). The value of the priority of the triggered SR corresponds to the value of priority of the logical channel that triggered the SR.

Each sidelink logical channel may be mapped to zero or one SR configuration, which is configured by RRC. If the SL- CSI reporting procedure is enabled by RRC, the SL-CSI reporting is mapped to one SR configuration for all PC5-RRC connections. The SR configuration of the SL-CSI reporting triggered according to 5.22.1.7 is considered as corresponding SR configuration for the triggered SR (clause 5.4.4). The value of the priority of the triggered SR corresponds to the value of the priority of the Sidelink CSI Reporting MAC CE.

All pending SR(s) triggered according to the Sidelink BSR procedure (clause 5.22.1.6) prior to the MAC PDU assembly shall be cancelled and each respective _sr-ProhibitTimer_ shall be stopped when the MAC PDU is transmitted and this PDU includes an SL-BSR MAC CE which contains buffer status up to (and including) the last event that triggered a Sidelink BSR (see clause 5.22.1.4) prior to the MAC PDU assembly.

All pending SR(s) triggered according to the Sidelink BSR procedure (clause 5.22.1.6) shall be cancelled and each respective _sr-ProhibitTimer_ shall be stopped when the SL grant(s) can accommodate all pending data available for transmission in sidelink.

The pending SR triggered according to the SL-CSI reporting for a destination shall be cancelled and each respective _sr-ProhibitTimer_ shall be stopped when the SL grant(s) can accommodate the Sidelink CSI Reporting MAC CE when the SL-CSI reporting that has been triggered but not cancelled or when the triggered SL-CSI reporting is cancelled due to latency non-fulfilment as specified in 5.22.1.7. All pending SR(s) triggered by either Sidelink BSR or Sidelink CSI report shall be cancelled, when RRC configures Sidelink resource allocation mode 2.

##### 5.22.1.6 Buffer Status Reporting

The Sidelink Buffer Status reporting (SL-BSR) procedure is used to provide the serving gNB with information about SL data volume in the MAC entity.

RRC configures the following parameters to control the SL-BSR:

- _sl-periodicBSR-Timer_, configured by _periodicBSR-Timer_ in _sl-BSR-Config_;
- _sl-retxBSR-Timer_, configured by _retxBSR-Timer_ in _sl-BSR-Config_;
- _sl-logicalChannelSR-DelayTimerApplied_;
- _sl-logicalChannelSR-DelayTimer_, configured by _logicalChannelSR-DelayTimer_ in _sl-BSR-Config_;
- _sl-logicalChannelGroup_.

Each logical channel which belongs to a Destination is allocated to an LCG as specified in TS 38.331 [5]. The maximum number of LCGs is eight.

The MAC entity determines the amount of SL data available for a logical channel according to the data volume calculation procedure in TSs 38.322 [3] and 38.323 [4].

An SL-BSR shall be triggered if any of the following events occur:

- `1>` if the MAC entity has been configured with Sidelink resource allocation mode 1:
  - `2>` SL data, for a logical channel which belongs to an LCG of a Destination, becomes available to the MAC entity; and either
    - `3>` this SL data belongs to a logical channel with higher priority than the priorities of the logical channels containing available SL data which belong to any LCG belonging to the same Destination; or
    - `3>` none of the logical channels which belong to an LCG belonging to the same Destination contains any available SL data.

in which case the SL-BSR is referred below to as 'Regular SL-BSR';

  - `2>` UL resources are allocated and number of padding bits remaining after a Padding BSR has been triggered is equal to or larger than the size of the SL-BSR MAC CE plus its subheader, in which case the SL-BSR is referred below to as 'Padding SL-BSR';
  - `2>` _sl-retxBSR-Timer_ expires, and at least one of the logical channels which belong to an LCG contains SL data, in which case the SL-BSR is referred below to as 'Regular SL-BSR';
  - `2>` _sl-periodicBSR-Timer_ expires, in which case the SL-BSR is referred below to as 'Periodic SL-BSR'.
- `1>` else:
  - `2>` Sidelink resource allocation mode 1 is configured by RRC and SL data is available for transmission in the RLC entity or in the PDCP entity, in which case the Sidelink BSR is referred below to as 'Regular SL-BSR'.

For Regular SL-BSR, the MAC entity shall:

- `1>` if the SL-BSR is triggered for a logical channel for which _sl-logicalChannelSR-DelayTimerApplied_ with value _true_ is configured by RRC:
  - `2>` start or restart the _sl-logicalChannelSR-DelayTimer_.
- `1>` else:
  - `2>` if running, stop the _sl-logicalChannelSR-DelayTimer_.

For Regular and Periodic SL-BSR, the MAC entity shall:

- `1>` if _sl-PrioritizationThres_ is configured and the value of the highest priority of the logical channels that belong to any LCG and contain SL data for any Destination is lower than _sl-PrioritizationThres_; and
- `1>` if _ul-PrioritizationThres_ is configured and the value of the highest priority of the logical channels that belong to any LCG and contain UL data is equal to or higher than _ul-PrioritizationThres_ according to clause 5.4.5:
  - `2>` prioritize the LCG(s) for the Destination(s).
- `1>` if the Buffer Status reporting procedure determines that at least one BSR has been triggered and not cancelled according to clause 5.4.5 and the UL grant cannot accommodate an SL-BSR MAC CE containing buffer status only for all prioritized LCGs having data available for transmission plus the subheader of the SL-BSR according to clause 5.4.3.1.3, in case the SL-BSR is considered as not prioritized:
  - `2>` prioritize the SL-BSR for logical channel prioritization specified in clause 5.4.3.1;
  - `2>` report Truncated SL-BSR containing buffer status for as many prioritized LCGs having data available for transmission as possible, taking the number of bits in the UL grant into consideration.
- `1>` else if the number of bits in the UL grant is expected to be equal to or larger than the size of an SL-BSR containing buffer status for all LCGs having data available for transmission plus the subheader of the SL-BSR according to clause 5.4.3.1.3:
  - `2>` report SL-BSR containing buffer status for all LCGs having data available for transmission.
- `1>` else:
  - `2>` report Truncated SL-BSR containing buffer status for as many LCGs having data available for transmission as possible, taking the number of bits in the UL grant into consideration.

For Padding SL-BSR:

- `1>` if the number of padding bits remaining after a Padding BSR has been triggered is equal to or larger than the size of an SL-BSR containing buffer status for all LCGs having data available for transmission plus its subheader:
  - `2>` report SL-BSR containing buffer status for all LCGs having data available for transmission;
- `1>` else:
  - `2>` report Truncated SL-BSR containing buffer status for as many LCGs having data available for transmission as possible, taking the number of bits in the UL grant into consideration.

For SL-BSR triggered by _sl-retxBSR-Timer_ expiry, the MAC entity considers that the logical channel that triggered the SL-BSR is the highest priority logical channel that has data available for transmission at the time the SL-BSR is triggered.

The MAC entity shall:

- `1>` if the sidelink Buffer Status reporting procedure determines that at least one SL-BSR has been triggered and not cancelled:
  - `2>` if UL-SCH resources are available for a new transmission and the UL-SCH resources can accommodate the SL-BSR MAC CE plus its subheader as a result of logical channel prioritization according to clause 5.4.3.1:
    - `3>` instruct the Multiplexing and Assembly procedure in clause 5.4.3 to generate the SL-BSR MAC CE(s);
    - `3>` start or restart _sl-periodicBSR-Timer_ except when all the generated SL-BSRs are Truncated SL-BSRs;
    - `3>` start or restart _sl-retxBSR-Timer_.
  - `2>` if a Regular SL-BSR has been triggered and _sl-logicalChannelSR-DelayTimer_ is not running:
    - `3>` if there is no UL-SCH resource available for a new transmission; or
    - `3>` if UL-SCH resources are available for a new transmission and the UL-SCH resources cannot accommodate the SL-BSR MAC CE plus its subheader as a result of logical channel prioritization according to clause 5.4.3.1; or
    - `3>` if the set of Subcarrier Spacing index values in _sl-AllowedSCS-List_, if configured for the logical channel that triggered the SL-BSR, does not include the Subcarrier Spacing index associated to the UL-SCH resources available for a new transmission; or
    - `3>` if _sl-MaxPUSCH-Duration_, if configured for the logical channel that triggered the SL-BSR, is smaller than the PUSCH transmission duration associated to the UL-SCH resources available for a new transmission:
      - `4>` trigger a Scheduling Request.

> NOTE 1: UL-SCH resources are considered available if the MAC entity has an active configured grant, or receives, or determines an uplink grant. If the MAC entity has determined at a given point in time that UL-SCH resources are available, this need not imply that UL-SCH resources are available for use at that point in time.

A MAC PDU shall contain at most one SL-BSR MAC CE, even when multiple events have triggered an SL-BSR. The Regular SL-BSR and the Periodic SL-BSR shall have precedence over the padding SL-BSR.

The MAC entity shall restart _sl-retxBSR-Timer_ upon reception of an SL grant for transmission of new data on any SL- SCH.

All triggered SL-BSRs may be cancelled when the SL grant(s) can accommodate all pending data available for transmission. All BSRs triggered prior to MAC PDU assembly shall be cancelled when a MAC PDU is transmitted and this PDU includes an SL-BSR MAC CE which contains buffer status up to (and including) the last event that triggered an SL-BSR prior to the MAC PDU assembly. All triggered SL-BSRs shall be cancelled, and _sl-retx-BSR-Timer_ and _sl-periodic-BSR-Timer_ shall be stopped, when RRC configures Sidelink resource allocation mode 2.

> NOTE 2: MAC PDU assembly can happen at any point in time between uplink grant reception and actual transmission of the corresponding MAC PDU. SL-BSR and SR can be triggered after the assembly of a MAC PDU which contains an SL-BSR MAC CE, but before the transmission of this MAC PDU. In addition, SL-BSR and SR can be triggered during MAC PDU assembly.

##### 5.22.1.7 CSI Reporting

The Sidelink Channel State Information (SL-CSI) reporting procedure is used to provide a peer UE with sidelink channel state information as specified in clause 8.5 of TS 38.214 [7].

RRC configures the following parameters to control the SL-CSI reporting procedure:

- _sl-LatencyBoundCSI-Report_, which is maintained for each PC5-RRC connection.

The MAC entity maintains an _sl-CSI-ReportTimer_ for each pair of the Source Layer-2 ID and the Destination Layer-2 ID corresponding to a PC5-RRC connection. _sl-CSI-ReportTimer_ is used for an SL-CSI reporting UE to follow the latency requirement signalled from a CSI triggering UE. The value of _sl-CSI-ReportTimer_ is the same as the latency requirement of the SL-CSI reporting in _sl-LatencyBoundCSI-Report_ configured by RRC.

The MAC entity shall for each pair of the Source Layer-2 ID and the Destination Layer-2 ID corresponding to a PC5- RRC connection which has been established by upper layers:

- `1>` if the SL-CSI reporting has been triggered by an SCI and not cancelled:
  - `2>` if the _sl-CSI-ReportTimer_ for the triggered SL-CSI reporting is not running:
    - `3>` start the _sl-CSI-ReportTimer_.
  - `2>` if the _sl-CSI-ReportTimer_ for the triggered SL-CSI reporting expires:
    - `3>` cancel the triggered SL-CSI reporting.
  - `2>` else if the MAC entity has SL resources allocated for new transmission and the SL-SCH resources can accommodate the SL-CSI reporting MAC CE and its subheader as a result of logical channel prioritization:
    - `3>` instruct the Multiplexing and Assembly procedure to generate a Sidelink CSI Reporting MAC CE as defined in clause 6.1.3.35;
    - `3>` stop the _sl-CSI-ReportTimer_ for the triggered SL-CSI reporting;
    - `3>` cancel the triggered SL-CSI reporting.
  - `2>` else if the MAC entity has been configured with Sidelink resource allocation mode 1:
    - `3>` trigger a Scheduling Request.

> NOTE: The MAC entity configured with Sidelink resource allocation mode 1 may trigger a Scheduling Request if transmission of a pending SL-CSI reporting with the sidelink grant(s) cannot fulfil the latency requirement associated to the SL-CSI reporting.

#### 5.22.2 SL-SCH Data reception

##### 5.22.2.1 SCI reception

SCI indicates if there is a transmission on SL-SCH and provide the relevant HARQ information. An SCI consists of two parts: the 1st stage SCI on PSCCH and the 2nd stage SCI on PSSCH as specified in clause 8.1 of TS 38.214 [7].

The MAC entity shall:

- `1>` for each PSCCH duration during which the MAC entity monitors PSCCH:
  - `2>` if a 1st stage SCI has been received on the PSCCH:
    - `3>` determine the set of PSSCH durations in which reception of a 2nd stage SCI and the transport block occur using the received part of the SCI;
    - `3>` if the 2nd stage SCI for this PSSCH duration has been received on the PSSCH:
      - `4>` store the SCI as a valid SCI for the PSSCH durations corresponding to transmission(s) of the transport block and the associated HARQ information and QoS information;
- `1>` for each PSSCH duration for which the MAC entity has a valid SCI:
  - `2>` deliver the SCI and the associated Sidelink transmission information to the Sidelink HARQ Entity.

##### 5.22.2.2 Sidelink HARQ operation

###### 5.22.2.2.1 Sidelink HARQ Entity

There is at most one Sidelink HARQ Entity at the MAC entity for reception of the SL-SCH, which maintains a number of parallel Sidelink processes.

Each Sidelink process is associated with SCI in which the MAC entity is interested. This interest is determined by the Sidelink identification information of the SCI. The Sidelink HARQ Entity directs Sidelink transmission information and associated TBs received on the SL-SCH to the corresponding Sidelink processes.

The number of Receiving Sidelink processes associated with the Sidelink HARQ Entity is defined in TS 38.306 [5].

For each PSSCH duration, the Sidelink HARQ Entity shall:

- `1>` for each SCI valid for this PSSCH duration:
  - `2>` if the NDI has been toggled compared to the value of the previous received transmission corresponding to the Sidelink identification information and the Sidelink process ID of the SCI or this is the very first received transmission for the pair of the Sidelink identification information and the Sidelink process ID of the SCI:
    - `3>` if there is a Sidelink process associated with the Sidelink identification information and the Sidelink process ID of the SCI:
      - `4>` consider the Sidelink process as unoccupied;
      - `4>` flush the soft buffer for the Sidelink process.
    - `3>` allocate the TB received from the physical layer and the associated Sidelink identification information and Sidelink process ID to an unoccupied Sidelink process;
    - `3>` associate the Sidelink process with the Sidelink identification information and the Sidelink process ID of this SCI and consider this transmission to be a new transmission.

> NOTE 1: When a new TB arrives, the Sidelink HARQ Entity allocates the TB to any unoccupied Sidelink process.

If there is no unoccupied Sidelink process in the Sidelink HARQ entity, how to manage receiving Sidelink processes is up to UE implementation.

> NOTE 1a: If the NDI has not been toggled compared to the value of the previous received transmission corresponding to the Sidelink identification information and the Sidelink process ID of the SCI, and if there is no Sidelink process associated with the Sidelink identification information and the Sidelink process ID of the SCI, it is up to UE implementation to handle the corresponding TB.

- `1>` for each Sidelink process:
  - `2>` if the NDI has not been toggled compared to the value of the previous received transmission corresponding to the Sidelink identification information and the Sidelink process ID of the SCI for the Sidelink process according to its associated SCI:
    - `3>` allocate the TB received from the physical layer to the Sidelink process and consider this transmission to be a retransmission.

> NOTE 2: A single sidelink process can only be (re-)associated to a single combination of Sidelink identification information and Sidelink process ID at a time and a single combination of Sidelink identification information and Sidelink process ID can only be (re-)associated to a single sidelink process at a time.

###### 5.22.2.2.2 Sidelink process

For each PSSCH duration where a transmission takes place for the Sidelink process, one TB and the associated HARQ information is received from the Sidelink HARQ Entity.

For each received TB and associated Sidelink transmission information, the Sidelink process shall:

- `1>` if this is a new transmission:
  - `2>` attempt to decode the received data.
- `1>` else if this is a retransmission:
  - `2>` if the data for this TB has not yet been successfully decoded:
    - `3>` instruct the physical layer to combine the received data with the data currently in the soft buffer for this TB and attempt to decode the combined data.
- `1>` if the data which the MAC entity attempted to decode was successfully decoded for this TB; or
- `1>` if the data for this TB was successfully decoded before:
  - `2>` if this is the first successful decoding of the data for this TB:
    - `3>` if this TB is associated to unicast and the DST field of the decoded MAC PDU subheader is equal to the 8 MSB of any of the Source Layer-2 ID(s) of the UE for which the 16 LSB are equal to the Destination ID in the corresponding SCI:
      - `4>` if the SRC field of the decoded MAC PDU subheader is equal to the 16 MSB of any of the Destination Layer-2 ID(s) of the UE for which the 8 LSB are equal to the Source ID in the corresponding SCI; or
      - `4>` if this TB is corresponding to the logical channel with LCID equal to 0 or 1 and determined to be the first TB:
        - `5>` deliver the decoded MAC PDU to the disassembly and demultiplexing entity.
    - `3>` if this TB is associated to groupcast or broadcast and the DST field of the decoded MAC PDU subheader is equal to the 8 MSB of any of the Destination Layer-2 ID(s) of the UE for which the 16 LSB are equal to the Destination ID in the corresponding SCI:
      - `4>` deliver the decoded MAC PDU to the disassembly and demultiplexing entity;

> NOTE: Whether the TB is the first TB can be determined based on the Source Layer-2 ID and Destination Layer- 2 ID pair.

  - `2>` consider the Sidelink process as unoccupied.
- `1>` else:
  - `2>` instruct the physical layer to replace the data in the soft buffer for this TB with the data which the MAC entity attempted to decode.
- `1>` if HARQ feedback is enabled by the SCI:
  - `2>` if negative-only acknowledgement is indicated by the SCI according to clause 8.4.1 of TS 38.212 [9]:
    - `3>` if UE's location information is available and distance beteween UE's location and the central location of the nearest zone that is calculated based on the _Zone_id_ in the SCI and the value of _sl-ZoneLength_ corresponding to the communication range requirement in the SCI as specified in TS 38.331 [5] is smaller or equal to the communication range requirement in the SCI; or
    - `3>` if none of _Zone_id_ and communication range requirement is indicated by the SCI; or
    - `3>` if UE's location information is not available:
      - `4>` if the data which the MAC entity attempted to decode was not successfully decoded for this TB and the data for this TB was not successfully decoded before:
        - `5>` instruct the physical layer to generate a negative acknowledgement of the data in this TB.
  - `2>` if negative-positive acknowledgement or unicast is indicated by the SCI according to clause 8.4.1 of TS 38.212 [9]:
    - `3>` if the data which the MAC entity attempted to decode was successfully decoded for this TB or the data for this TB was successfully decoded before:
      - `4>` instruct the physical layer to generate a positive acknowledgement of the data in this TB.
    - `3>` else:
      - `4>` instruct the physical layer to generate a negative acknowledgement of the data in this TB.

##### 5.22.2.3 Disassembly and demultiplexing

The MAC entity shall disassemble and demultiplex a MAC PDU as defined in clause 6.1.6.

### 5.23 SL-BCH data transfer

#### 5.23.1 SL-BCH data transmission

When instructed to send SL-BCH, the MAC entity shall:

- `1>` obtain the MAC PDU to transmit from SBCCH;
- `1>` deliver the MAC PDU to the physical layer and instruct it to generate a transmission.

#### 5.23.2 SL-BCH data reception

When the MAC entity needs to receive SL-BCH, the MAC entity shall:

- `1>` receive and attempt to decode the SL-BCH;
- `1>` if a TB on the SL-BCH has been successfully decoded:
  - `2>` deliver the decoded MAC PDU to upper layers.
