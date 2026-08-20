# TS 38.331 §6 & §9 — Sidelink RRC Messages, ASN.1 IEs and Pre-configuration

> **Source:** 3GPP TS 38.331 V16.22.0 (2026-06), Release 16 — *NR; Radio Resource Control (RRC) protocol specification*
> **Scope:** SBCCH/SCCH message structure and definitions, §6.3.5 sidelink information elements (resource pool, BWP, sync, QoS, TX/RX profiles), default SL radio configurations, §9.3 sidelink pre-configured parameters.
> **Status:** verbatim spec extract, reformatted. Page headers/footers removed,
> PDF hard-wraps rejoined, clause numbers promoted to headings.
> Normative text is unchanged; see `00-INDEX.md` for gaps and reconstructions.

## Contents

    - [6.6.1 General message structure](#661-general-message-structure)
      - [`PC5-RRC-Definitions`](#pc5-rrc-definitions)
      - [`SBCCH-SL-BCH-Message`](#sbcch-sl-bch-message)
      - [`SCCH-Message`](#scch-message)
    - [6.6.2 Message definitions](#662-message-definitions)
      - [`MasterInformationBlockSidelink`](#masterinformationblocksidelink)
      - [`MeasurementReportSidelink`](#measurementreportsidelink)
      - [`RRCReconfigurationSidelink`](#rrcreconfigurationsidelink)
      - [`RRCReconfigurationCompleteSidelink`](#rrcreconfigurationcompletesidelink)
      - [`RRCReconfigurationFailureSidelink`](#rrcreconfigurationfailuresidelink)
      - [`UECapabilityEnquirySidelink`](#uecapabilityenquirysidelink)
      - [`UECapabilityInformationSidelink`](#uecapabilityinformationsidelink)
    - [6.3.5 Sidelink information elements](#635-sidelink-information-elements)
      - [`SL-BWP-Config`](#sl-bwp-config)
      - [`SL-BWP-ConfigCommon`](#sl-bwp-configcommon)
      - [`SL-BWP-PoolConfig`](#sl-bwp-poolconfig)
      - [`SL-BWP-PoolConfigCommon`](#sl-bwp-poolconfigcommon)
      - [`SL-CBR-PriorityTxConfigList`](#sl-cbr-prioritytxconfiglist)
      - [`SL-CBR-CommonTxConfigList`](#sl-cbr-commontxconfiglist)
      - [`SL-ConfigDedicatedNR`](#sl-configdedicatednr)
      - [`SL-ConfiguredGrantConfig`](#sl-configuredgrantconfig)
      - [`SL-DestinationIdentity`](#sl-destinationidentity)
      - [`SL-FreqConfig`](#sl-freqconfig)
      - [`SL-FreqConfigCommon`](#sl-freqconfigcommon)
      - [`SL-LogicalChannelConfig`](#sl-logicalchannelconfig)
      - [`SL-MeasConfigCommon`](#sl-measconfigcommon)
      - [`SL-MeasConfigInfo`](#sl-measconfiginfo)
      - [`SL-MeasIdList`](#sl-measidlist)
      - [`SL-MeasObjectList`](#sl-measobjectlist)
      - [`SL-PDCP-Config`](#sl-pdcp-config)
      - [`SL-PSBCH-Config`](#sl-psbch-config)
      - [`SL-PSSCH-TxConfigList`](#sl-pssch-txconfiglist)
      - [`SL-QoS-FlowIdentity`](#sl-qos-flowidentity)
      - [`SL-QoS-Profile`](#sl-qos-profile)
      - [`SL-QuantityConfig`](#sl-quantityconfig)
      - [`SL-RadioBearerConfig`](#sl-radiobearerconfig)
      - [`SL-ReportConfigList`](#sl-reportconfiglist)
      - [`SL-ResourcePool`](#sl-resourcepool)
      - [`SL-RLC-BearerConfig`](#sl-rlc-bearerconfig)
      - [`SL-RLC-BearerConfigIndex`](#sl-rlc-bearerconfigindex)
      - [`SL-RLC-Config`](#sl-rlc-config)
      - [`SL-ScheduledConfig`](#sl-scheduledconfig)
      - [`SL-SDAP-Config`](#sl-sdap-config)
      - [`SL-SyncConfig`](#sl-syncconfig)
      - [`SL-Thres-RSRP-List`](#sl-thres-rsrp-list)
      - [`SL-TxPower`](#sl-txpower)
      - [`SL-TypeTxSync`](#sl-typetxsync)
      - [`SL-UE-SelectedConfig`](#sl-ue-selectedconfig)
      - [`SL-ZoneConfig`](#sl-zoneconfig)
      - [9.1.1.4 SCCH configuration](#9114-scch-configuration)
      - [9.1.1.5 STCH configuration](#9115-stch-configuration)
    - [9.1.2 Void](#912-void)
  - [9.2 Default radio configurations](#92-default-radio-configurations)
    - [9.2.1 Default SRB configurations](#921-default-srb-configurations)
    - [9.2.2 Default MAC Cell Group configuration](#922-default-mac-cell-group-configuration)
    - [9.2.3 Default values timers and constants](#923-default-values-timers-and-constants)
  - [9.3 Sidelink pre-configured parameters](#93-sidelink-pre-configured-parameters)
      - [`NR-Sidelink-Preconf`](#nr-sidelink-preconf)
      - [`SL-PreconfigurationNR`](#sl-preconfigurationnr)

---

PC5 RRC messages

#### 6.6.1 General message structure

##### PC5-RRC-Definitions

This ASN.1 segment is the start of the PC5 RRC PDU definitions.

```asn1
-- TAG-PC5-RRC-DEFINITIONS-START
PC5-RRC-Definitions DEFINITIONS AUTOMATIC TAGS ::=
BEGIN
IMPORTS
SetupRelease,
RRC-TransactionIdentifier,
SN-FieldLengthAM,
SN-FieldLengthUM,
LogicalChannelIdentity,
maxNrofSLRB-r16,
maxNrofSL-QFIs-r16,
maxNrofSL-QFIsPerDest-r16,
RSRP-Range,
SL-MeasConfig-r16,
SL-MeasId-r16,
FreqBandList,
FreqBandIndicatorNR,
maxSimultaneousBands,
maxBandComb,
maxBands,
BandParametersSidelink-r16,
RLC-ParametersSidelink-r16
FROM NR-RRC-Definitions;
-- TAG-PC5-RRC-DEFINITIONS-STOP
```

##### SBCCH-SL-BCH-Message

The _SBCCH-SL-BCH-Message_ class is the set of RRC messages that may be sent from the UE to the UE via SL-BCH on the SBCCH logical channel.

```asn1
-- TAG-SBCCH-SL-BCH-MESSAGE-START
SBCCH-SL-BCH-Message ::= SEQUENCE {
message SBCCH-SL-BCH-MessageType
}
SBCCH-SL-BCH-MessageType::= CHOICE {
c1 CHOICE {
masterInformationBlockSidelink MasterInformationBlockSidelink,
spare1 NULL
},
messageClassExtension SEQUENCE {}
}
-- TAG-SBCCH-SL-BCH-MESSAGE-STOP
```

##### SCCH-Message

The _SCCH-Message_ class is the set of RRC messages that may be sent from the UE to the UE for unicast of NR sidelink communication on SCCH logical channel.

```asn1
-- TAG-SCCH-MESSAGE-START
SCCH-Message ::= SEQUENCE {
message SCCH-MessageType
}
SCCH-MessageType ::= CHOICE {
c1 CHOICE {
measurementReportSidelink MeasurementReportSidelink,
rrcReconfigurationSidelink RRCReconfigurationSidelink,
rrcReconfigurationCompleteSidelink RRCReconfigurationCompleteSidelink,
rrcReconfigurationFailureSidelink RRCReconfigurationFailureSidelink,
ueCapabilityEnquirySidelink UECapabilityEnquirySidelink,
ueCapabilityInformationSidelink UECapabilityInformationSidelink,
spare2 NULL, spare1 NULL
},
messageClassExtension SEQUENCE {}
}
-- TAG-SCCH-MESSAGE-STOP
```

#### 6.6.2 Message definitions

##### MasterInformationBlockSidelink

The _MasterInformationBlockSidelink_ includes the system information transmitted by a UE via SL-BCH.

Signalling radio bearer: N/A RLC-SAP: TM Logical channel: SBCCH Direction: UE to UE **_MasterInformationBlockSidelink_**

```asn1
-- TAG-MASTERINFORMATIONBLOCKSIDELINK-START
MasterInformationBlockSidelink ::= SEQUENCE {
sl-TDD-Config-r16 BIT STRING (SIZE (12)),
inCoverage-r16 BOOLEAN,
directFrameNumber-r16 BIT STRING (SIZE (10)),
slotIndex-r16 BIT STRING (SIZE (7)),
reservedBits-r16 BIT STRING (SIZE (2))
}
-- TAG-MASTERINFORMATIONBLOCKSIDELINK-STOP
```

**_MasterInformationBlockSidelink_** **field descriptions** **_directFrameNumber_** Indicates the frame number in which S-SSB transmitted.

**_inCoverage_** Value true indicates that the UE transmitting the _MasterInformationBlockSidelink_ is in network coverage, or UE selects GNSS timing as the synchronization reference source.

**_slotIndex_** Indicates the slot index in which S-SSB transmitted.

##### MeasurementReportSidelink

The _MeasurementReportSidelink_ message is used for the indication of measurement results of NR sidelink.

Signalling radio bearer: SL-SRB3 RLC-SAP: AM Logical channel: SCCH Direction: UE to UE **_MeasurementReportSidelink_** **message**

```asn1
-- TAG-MEASUREMENTREPORTSIDELINK-START
MeasurementReportSidelink ::= SEQUENCE {
criticalExtensions CHOICE {
measurementReportSidelink-r16 MeasurementReportSidelink-r16-IEs,
criticalExtensionsFuture SEQUENCE {}
}
}
MeasurementReportSidelink-r16-IEs ::= SEQUENCE {
sl-MeasResults-r16 SL-MeasResults-r16,
lateNonCriticalExtension OCTET STRING OPTIONAL,
nonCriticalExtension SEQUENCE{} OPTIONAL
}
SL-MeasResults-r16 ::= SEQUENCE {
sl-MeasId-r16 SL-MeasId-r16,
sl-MeasResult-r16 SL-MeasResult-r16,
...
}
SL-MeasResult-r16 ::= SEQUENCE {
sl-ResultDMRS-r16 SL-MeasQuantityResult-r16 OPTIONAL,
...
}
SL-MeasQuantityResult-r16 ::= SEQUENCE {
sl-RSRP-r16 RSRP-Range OPTIONAL,
...
}
-- TAG-MEASUREMENTREPORTSIDELINK-STOP
```

**_MeasurementReportSidelink_** **field descriptions** **_sl-MeasId_** Identifies the sidelink measurement identity for which the reporting is being performed.

**_sl-MeasResult_** Measured RSRP results of a unicast destination.

##### RRCReconfigurationSidelink

The _RRCReconfigurationSidelink_ message is the command to AS configuration of the PC5 RRC connection. It is only applied to unicast of NR sidelink communication.

Signalling radio bearer: SL-SRB3 RLC-SAP: AM Logical channel: SCCH Direction: UE to UE **_RRCReconfigurationSidelink_** **message**

```asn1
-- TAG-RRCRECONFIGURATIONSIDELINK-START
RRCReconfigurationSidelink ::= SEQUENCE {
rrc-TransactionIdentifier-r16 RRC-TransactionIdentifier,
criticalExtensions CHOICE {
rrcReconfigurationSidelink-r16 RRCReconfigurationSidelink-r16-IEs,
criticalExtensionsFuture SEQUENCE {}
}
}
RRCReconfigurationSidelink-r16-IEs ::= SEQUENCE {
slrb-ConfigToAddModList-r16 SEQUENCE (SIZE (1..maxNrofSLRB-r16)) OF SLRB-Config-r16 OPTIONAL,
-- Need N
slrb-ConfigToReleaseList-r16 SEQUENCE (SIZE (1..maxNrofSLRB-r16)) OF SLRB-PC5-ConfigIndex-r16 OPTIONAL,
-- Need N
sl-MeasConfig-r16 SetupRelease {SL-MeasConfig-r16} OPTIONAL,
-- Need M
sl-CSI-RS-Config-r16 SetupRelease {SL-CSI-RS-Config-r16} OPTIONAL,
-- Need M
sl-ResetConfig-r16 ENUMERATED {true} OPTIONAL,
-- Need N
sl-LatencyBoundCSI-Report-r16 INTEGER (3..160) OPTIONAL,
-- Need M
lateNonCriticalExtension OCTET STRING OPTIONAL,
nonCriticalExtension SEQUENCE {} OPTIONAL
}
SLRB-Config-r16::= SEQUENCE {
slrb-PC5-ConfigIndex-r16 SLRB-PC5-ConfigIndex-r16,
sl-SDAP-ConfigPC5-r16 SL-SDAP-ConfigPC5-r16 OPTIONAL,
-- Need M
sl-PDCP-ConfigPC5-r16 SL-PDCP-ConfigPC5-r16 OPTIONAL,
-- Need M
sl-RLC-ConfigPC5-r16 SL-RLC-ConfigPC5-r16 OPTIONAL,
-- Need M
sl-MAC-LogicalChannelConfigPC5-r16 SL-LogicalChannelConfigPC5-r16 OPTIONAL,
-- Need M
...
}
SLRB-PC5-ConfigIndex-r16 ::= INTEGER (1..maxNrofSLRB-r16)
SL-SDAP-ConfigPC5-r16 ::= SEQUENCE {
sl-MappedQoS-FlowsToAddList-r16 SEQUENCE (SIZE (1.. maxNrofSL-QFIsPerDest-r16)) OF SL-PQFI-r16 OPTIONAL,
-- Need N
sl-MappedQoS-FlowsToReleaseList-r16 SEQUENCE (SIZE (1.. maxNrofSL-QFIsPerDest-r16)) OF SL-PQFI-r16 OPTIONAL,
-- Need N
sl-SDAP-Header-r16 ENUMERATED {present, absent},
...
}
SL-PDCP-ConfigPC5-r16 ::= SEQUENCE {
sl-PDCP-SN-Size-r16 ENUMERATED {len12bits, len18bits} OPTIONAL,
-- Need M
sl-OutOfOrderDelivery-r16 ENUMERATED { true } OPTIONAL,
-- Need R
...
}
SL-RLC-ConfigPC5-r16 ::= CHOICE {
sl-AM-RLC-r16 SEQUENCE {
sl-SN-FieldLengthAM-r16 SN-FieldLengthAM OPTIONAL,
-- Need M
...
},
sl-UM-Bi-Directional-RLC-r16 SEQUENCE {
sl-SN-FieldLengthUM-r16 SN-FieldLengthUM OPTIONAL,
-- Need M
...
},
sl-UM-Uni-Directional-RLC-r16 SEQUENCE {
sl-SN-FieldLengthUM-r16 SN-FieldLengthUM OPTIONAL,
-- Need M
...
}
}
SL-LogicalChannelConfigPC5-r16 ::= SEQUENCE {
sl-LogicalChannelIdentity-r16 LogicalChannelIdentity,
...
}
SL-PQFI-r16 ::= INTEGER (1..64)
SL-CSI-RS-Config-r16 ::= SEQUENCE {
sl-CSI-RS-FreqAllocation-r16 CHOICE {
sl-OneAntennaPort-r16 BIT STRING (SIZE (12)),
sl-TwoAntennaPort-r16 BIT STRING (SIZE (6))
} OPTIONAL,
-- Need M
sl-CSI-RS-FirstSymbol-r16 INTEGER (3..12) OPTIONAL,
-- Need M
...
}
-- TAG-RRCRECONFIGURATIONSIDELINK-STOP
```

**_RRCReconfigurationSidelink_** **field descriptions** **_sl-CSI-RS-FreqAllocation_** Indicates the frequency domain position for sidelink CSI-RS.

**_sl-CSI-RS-FirstSymbol_** Indicates the position of first symbol of sidelink CSI-RS.

**_sl-Resetconfig_** Indicates that the full configuration should be applicable for the _RRCReconfigurationSidelink_ message.

**_sl-LatencyBoundCSI-Report_** Indicate the latency bound of SL CSI report from the associated SL CSI triggering in terms of number of slots.

**_sl-LogicalChannelIdentity_** Indicates the identity of the sidelink logical channel.

**_sl-MappedQoS-FlowsToAddList_** Indicate the QoS flows to be mapped to the configured sidelink DRB. Each entry is indicated by the _SL-PQFI_, which is used between UEs, as defined in TS 23.287 [55].

**_sl-MappedQoS-FlowsToReleaseList_** Indicate the QoS flows to be released from the configured sidelink DRB. Each entry is indicated by the _SL-PQFI_, which is used between UEs, as defined in TS 23.287 [55].

**_sl-MeasConfig_** Indicates the sidelink measurement configuration for the unicast destination.

**_sl-OutOfOrderDelivery_** is established.

Indicates whether or not outOfOrderDelivery specified in TS 38.323 [5] is configured. This field should be either always present or always absent, after the sidelink radio bearer **_sl-PDCP-SN-Size_** Indicates the PDCP SN size of the configured sidelink DRB.

**_sl-SDAP-Header_** Indicates whether or not a SDAP header is present on this sidelink DRB.

##### RRCReconfigurationCompleteSidelink

The _RRCReconfigurationCompleteSidelink_ message is used to confirm the successful completion of a PC5 RRC AS reconfiguration. It is only applied to unicast of NR sidelink communication.

Signalling radio bearer: SL-SRB3 RLC-SAP: AM Logical channel: SCCH Direction: UE to UE **_RRCReconfigurationCompleteSidelink_** **message**

```asn1
-- TAG-RRCRECONFIGURATIONCOMPLETESIDELINK-START
RRCReconfigurationCompleteSidelink ::= SEQUENCE {
rrc-TransactionIdentifier-r16 RRC-TransactionIdentifier,
criticalExtensions CHOICE {
rrcReconfigurationCompleteSidelink-r16 RRCReconfigurationCompleteSidelink-r16-IEs,
criticalExtensionsFuture SEQUENCE {}
}
}
RRCReconfigurationCompleteSidelink-r16-IEs ::= SEQUENCE {
lateNonCriticalExtension OCTET STRING OPTIONAL,
nonCriticalExtension SEQUENCE {} OPTIONAL
}
-- TAG-RRCRECONFIGURATIONCOMPLETESIDELINK-STOP
```

##### RRCReconfigurationFailureSidelink

The _RRCReconfigurationFailureSidelink_ message is used to indicate the failure of a PC5 RRC AS reconfiguration. It is only applied to unicast of NR sidelink communication.

Signalling radio bearer: SL-SRB3 RLC-SAP: AM Logical channel: SCCH Direction: UE to UE **_RRCReconfigurationFailureSidelink_** **message**

```asn1
-- TAG-RRCRECONFIGURATIONFAILURESIDELINK-START
RRCReconfigurationFailureSidelink ::= SEQUENCE {
rrc-TransactionIdentifier-r16 RRC-TransactionIdentifier,
criticalExtensions CHOICE {
rrcReconfigurationFailureSidelink-r16 RRCReconfigurationFailureSidelink-r16-IEs,
criticalExtensionsFuture SEQUENCE {}
}
}
RRCReconfigurationFailureSidelink-r16-IEs ::= SEQUENCE {
lateNonCriticalExtension OCTET STRING OPTIONAL,
nonCriticalExtension SEQUENCE {} OPTIONAL
}
-- TAG-RRCRECONFIGURATIONFAILURESIDELINK-STOP
```

##### UECapabilityEnquirySidelink

The _UECapabilityEnquirySidelink_ message is used to request UE sidelink capabilities. It is only applied to unicast of NR sidelink communication.

Signalling radio bearer: SL-SRB3 RLC-SAP: AM Logical channel: SCCH Direction: UE to UE **_UECapabilityEnquirySidelink_** **message**

```asn1
-- TAG-UECAPABILITYENQUIRYSIDELINK-START
UECapabilityEnquirySidelink ::= SEQUENCE {
rrc-TransactionIdentifier-r16 RRC-TransactionIdentifier,
criticalExtensions CHOICE {
ueCapabilityEnquirySidelink-r16 UECapabilityEnquirySidelink-r16-IEs,
criticalExtensionsFuture SEQUENCE {}
}
}
UECapabilityEnquirySidelink-r16-IEs ::= SEQUENCE {
frequencyBandListFilterSidelink-r16 FreqBandList OPTIONAL,
-- Need N
ue-CapabilityInformationSidelink-r16 OCTET STRING OPTIONAL,
-- Need N
lateNonCriticalExtension OCTET STRING OPTIONAL,
nonCriticalExtension SEQUENCE{} OPTIONAL
}
-- TAG-UECAPABILITYENQUIRYSIDELINK-STOP
```

**_UECapabilityEnquirySidelink-IEs_** **field descriptions** **_frequencyBandListFilterSidelink_** This field is used to indicate frequency bands for which the peer UE is requested to provide supported bands and band combinations for NR sidelink communications. The UE always provides this field.

**_ue-CapabilityInformationSidelink_** This field indicates the _UECapabilityInformationSidelink_ message to provide the UE sidelink capability, which can be optionally sent together with _UECapabilityEnquirySidelink_.

##### UECapabilityInformationSidelink

The _UECapabilityInformationSidelink_ message is used to transfer UE radio access capabilities. It is only applied to unicast of NR sidelink communication.

Signalling radio bearer: SL-SRB3 RLC-SAP: AM Logical channel: SCCH Direction: UE to UE **_UECapabilityInformationSidelink_** **message**

```asn1
-- TAG-UECAPABILITYINFORMATIONSIDELINK-START
UECapabilityInformationSidelink ::= SEQUENCE {
rrc-TransactionIdentifier-r16 RRC-TransactionIdentifier,
criticalExtensions CHOICE {
ueCapabilityInformationSidelink-r16 UECapabilityInformationSidelink-r16-IEs,
criticalExtensionsFuture SEQUENCE {}
}
}
UECapabilityInformationSidelink-r16-IEs ::= SEQUENCE {
accessStratumReleaseSidelink-r16 AccessStratumReleaseSidelink-r16,
pdcp-ParametersSidelink-r16 PDCP-ParametersSidelink-r16 OPTIONAL,
rlc-ParametersSidelink-r16 RLC-ParametersSidelink-r16 OPTIONAL,
supportedBandCombinationListSidelinkNR-r16 BandCombinationListSidelinkNR-r16 OPTIONAL,
supportedBandListSidelink-r16 SEQUENCE (SIZE (1..maxBands)) OF BandSidelinkPC5-r16 OPTIONAL,
appliedFreqBandListFilter-r16 FreqBandList OPTIONAL,
lateNonCriticalExtension OCTET STRING OPTIONAL,
nonCriticalExtension SEQUENCE{} OPTIONAL
}
AccessStratumReleaseSidelink-r16 ::= ENUMERATED { rel16, spare7, spare6, spare5, spare4, spare3, spare2, spare1, ... }
PDCP-ParametersSidelink-r16 ::= SEQUENCE {
outOfOrderDeliverySidelink-r16 ENUMERATED {supported} OPTIONAL,
...
}
BandCombinationListSidelinkNR-r16 ::= SEQUENCE (SIZE (1..maxBandComb)) OF BandCombinationParametersSidelinkNR-r16
BandCombinationParametersSidelinkNR-r16 ::= SEQUENCE (SIZE (1..maxSimultaneousBands)) OF BandParametersSidelink-r16
BandSidelinkPC5-r16 ::= SEQUENCE {
freqBandSidelink-r16 FreqBandIndicatorNR,
--15-1
sl-Reception-r16 SEQUENCE {
harq-RxProcessSidelink-r16 ENUMERATED {n16, n24, n32, n64},
pscch-RxSidelink-r16 ENUMERATED {value1, value2},
scs-CP-PatternRxSidelink-r16 CHOICE {
fr1-r16 SEQUENCE {
scs-15kHz-r16 BIT STRING (SIZE (16)) OPTIONAL,
scs-30kHz-r16 BIT STRING (SIZE (16)) OPTIONAL,
scs-60kHz-r16 BIT STRING (SIZE (16)) OPTIONAL
},
fr2-r16 SEQUENCE {
scs-60kHz-r16 BIT STRING (SIZE (16)) OPTIONAL,
scs-120kHz-r16 BIT STRING (SIZE (16)) OPTIONAL
}
} OPTIONAL,
extendedCP-RxSidelink-r16 ENUMERATED {supported} OPTIONAL
} OPTIONAL,
--15-10
sl-Tx-256QAM-r16 ENUMERATED {supported} OPTIONAL,
--15-12
lowSE-64QAM-MCS-TableSidelink-r16 ENUMERATED {supported} OPTIONAL,
...,
[[
--15-14
csi-ReportSidelink-r16 SEQUENCE {
csi-RS-PortsSidelink-r16 ENUMERATED {p1, p2}
} OPTIONAL,
--15-19
rankTwoReception-r16 ENUMERATED {supported} OPTIONAL,
--15-23
sl-openLoopPC-RSRP-ReportSidelink-r16 ENUMERATED {supported} OPTIONAL,
--13-1
sl-Rx-256QAM-r16 ENUMERATED {supported} OPTIONAL
]]
}
-- TAG-UECAPABILITYINFORMATIONSIDELINK-STOP
```

– _End of PC5-RRC-Definitio_

#### 6.3.5 Sidelink information elements

##### SL-BWP-Config

The IE _SL-BWP-Config_ is used to configure the UE specific NR sidelink communication on one particular sidelink bandwidth part.

**_SL-BWP-Config_** **information element**

```asn1
-- TAG-SL-BWP-CONFIG-START
SL-BWP-Config-r16 ::= SEQUENCE {
sl-BWP-Id BWP-Id,
sl-BWP-Generic-r16 SL-BWP-Generic-r16 OPTIONAL,
-- Need M
sl-BWP-PoolConfig-r16 SL-BWP-PoolConfig-r16 OPTIONAL,
-- Need M
...
}
SL-BWP-Generic-r16 ::= SEQUENCE {
sl-BWP-r16 BWP OPTIONAL,
-- Need M
sl-LengthSymbols-r16 ENUMERATED {sym7, sym8, sym9, sym10, sym11, sym12, sym13, sym14} OPTIONAL,
-- Need M
sl-StartSymbol-r16 ENUMERATED {sym0, sym1, sym2, sym3, sym4, sym5, sym6, sym7} OPTIONAL,
-- Need M
sl-PSBCH-Config-r16 SetupRelease {SL-PSBCH-Config-r16} OPTIONAL,
-- Need M
sl-TxDirectCurrentLocation-r16 INTEGER (0..3301) OPTIONAL,
-- Need M
...
}
-- TAG-SL-BWP-CONFIG-STOP
```

**_SL-BWP-Config_** **field descriptions** **_sl-BWP-Generic_** This field indicates the generic parameters on the configured sidelink BWP.

**_sl-BWP-PoolConfig_** This field indicates the resource pool configurations on the configured sidelink BWP.

**_sl-BWP-Id_** An identifier for this sidelink bandwidth part.

**_SL-BWP-Generic_** **field descriptions** **_sl-LengthSymbols_** This field indicates the number of symbols used for sidelink in a slot without S-SSB. A single value can be (pre)configured per sidelink bandwidth part.

**_sl-StartSymbol_** This field indicates the starting symbol used for sidelink in a slot without S-SSB. A single value can be (pre)configured per sidelink bandwidth part.

**_sl-TxDirectCurrentLocation_** The sidelink Tx/Rx Direct Current location for the carrier. Only values in the value range of this field between 0 and 3299, which indicate the subcarrier index within the carrier corresponding to the numerology of the corresponding sidelink BWP and value 3300, which indicates "Outside the carrier" and value 3301, which indicates "Undetermined position within the carrier" are used in this version of the specification.

##### SL-BWP-ConfigCommon

The IE _SL-BWP-ConfigCommon_ is used to configure the cell-specific configuration information on one particular sidelink bandwidth part.

**_SL-BWP-ConfigCommon_** **information element**

```asn1
-- TAG-SL-BWP-CONFIGCOMMON-START
SL-BWP-ConfigCommon-r16 ::= SEQUENCE {
sl-BWP-Generic-r16 SL-BWP-Generic-r16 OPTIONAL,
-- Need R
sl-BWP-PoolConfigCommon-r16 SL-BWP-PoolConfigCommon-r16 OPTIONAL,
-- Need R
...
}
-- TAG-SL-BWP-CONFIGCOMMON-STOP
```

**_SL-BWP-ConfigCommon_** **field descriptions** **_sl-BWP-Generic_** This field indicates the generic parameters on the configured sidelink BWP.

**_sl-BWP-PoolConfigCommon_** This field indicates the resource pool configurations on the configured sidelink BWP.

##### SL-BWP-PoolConfig

The IE _SL-BWP-PoolConfig_ is used to configure NR sidelink communication resource pool.

**_SL-BWP-PoolConfig_** **information element**

```asn1
-- TAG-SL-BWP-POOLCONFIG-START
SL-BWP-PoolConfig-r16 ::= SEQUENCE {
sl-RxPool-r16 SEQUENCE (SIZE (1..maxNrofRXPool-r16)) OF SL-ResourcePool-r16 OPTIONAL,
-- Cond HO
sl-TxPoolSelectedNormal-r16 SL-TxPoolDedicated-r16 OPTIONAL,
-- Need M
sl-TxPoolScheduling-r16 SL-TxPoolDedicated-r16 OPTIONAL,
-- Need N
sl-TxPoolExceptional-r16 SL-ResourcePoolConfig-r16 OPTIONAL -- Need M
}
SL-TxPoolDedicated-r16 ::= SEQUENCE {
sl-PoolToReleaseList-r16 SEQUENCE (SIZE (1..maxNrofTXPool-r16)) OF SL-ResourcePoolID-r16 OPTIONAL,
-- Need N
sl-PoolToAddModList-r16 SEQUENCE (SIZE (1..maxNrofTXPool-r16)) OF SL-ResourcePoolConfig-r16 OPTIONAL -- Need N
}
SL-ResourcePoolConfig-r16 ::= SEQUENCE {
sl-ResourcePoolID-r16 SL-ResourcePoolID-r16,
sl-ResourcePool-r16 SL-ResourcePool-r16 OPTIONAL -- Need M
}
SL-ResourcePoolID-r16 ::= INTEGER (1..maxNrofPoolID-r16)
-- TAG-SL-BWP-POOLCONFIG-STOP
```

**_SL-BWP-PoolConfig_** **field descriptions** **_sl-RxPool_** Indicates the receiving resource pool on the configured BWP. For the PSFCH related configuration, if configured, will be used for PSFCH transmission/reception. If the field is included, it replaces any previous list, i.e. all the entries of the list are replaced and each of the _SL-ResourcePool_ entries is considered to be newly created.

**_sl-TxPoolExceptional_** Indicates the resources by which the UE is allowed to transmit NR sidelink communication in exceptional conditions on the configured BWP. For the PSFCH related configuration, if configured, will be used for PSFCH transmission/reception.

**_sl-TxPoolScheduling_** Indicates the resources by which the UE is allowed to transmit NR sidelink communication based on network scheduling on the configured BWP. For the PSFCH related configuration, if configured, will be used for PSFCH transmission/reception.

**_sl-TxPoolSelectedNormal_** Indicates the resources by which the UE is allowed to transmit NR sidelink communication by UE autonomous resource selection on the configured BWP. For the PSFCH related configuration, if configured, will be used for PSFCH transmission/reception.

**Conditional Presence Explanation** _HO_ This field is optionally present, need M, in an _RRCReconfiguration_ message including _reconfigurationWithSync_; otherwise it is absent, Need M.

##### SL-BWP-PoolConfigCommon

The IE _SL-BWP-PoolConfigCommon_ is used to configure the cell-specific NR sidelink communication resource pool.

**_SL-BWP-PoolConfigCommon_** **information element**

```asn1
-- TAG-SL-BWP-POOLCONFIGCOMMON-START
SL-BWP-PoolConfigCommon-r16 ::= SEQUENCE {
sl-RxPool-r16 SEQUENCE (SIZE (1..maxNrofRXPool-r16)) OF SL-ResourcePool-r16 OPTIONAL,
-- Need R
sl-TxPoolSelectedNormal-r16 SEQUENCE (SIZE (1..maxNrofTXPool-r16)) OF SL-ResourcePoolConfig-r16 OPTIONAL,
-- Need R
sl-TxPoolExceptional-r16 SL-ResourcePoolConfig-r16 OPTIONAL -- Need R
}
-- TAG-SL-BWP-POOLCONFIGCOMMON-STOP
```

**_SL-BWP-PoolConfigCommon_** **field descriptions** **_sl-TxPoolExceptional_** Indicates the resources by which the UE is allowed to transmit NR sidelink communication in exceptional conditions on the configured BWP. For the PSFCH related configuration, if configured, will be used for PSFCH transmission/reception. This field is not present when _SL-BWP-PoolConfigCommon_ is included in _SidelinkPreconfigNR_.

##### SL-CBR-PriorityTxConfigList

The IE _SL-CBR-PriorityTxConfigList_ indicates the mapping between PSSCH transmission parameter (such as MCS, PRB number, retransmission number, CR limit) sets by using the indexes of the configurations provided in _sl-CBR-PSSCH-TxConfigList_, CBR ranges by an index to the entry of the CBR range configuration in _sl-CBR-RangeConfigList_, and priority ranges. It also indicates the default PSSCH transmission parameters to be used when CBR measurement results are not available, and MCS range for the MCS tables used in the resource pool.

**_SL-CBR-PriorityTxConfigList_** **information element**

```asn1
-- TAG-SL-CBR-PRIORITYTXCONFIGLIST-START
SL-CBR-PriorityTxConfigList-r16 ::= SEQUENCE (SIZE (1..8)) OF SL-PriorityTxConfigIndex-r16
SL-CBR-PriorityTxConfigList-v1650 ::= SEQUENCE (SIZE (1..8)) OF SL-PriorityTxConfigIndex-v1650
SL-PriorityTxConfigIndex-r16 ::= SEQUENCE {
sl-PriorityThreshold-r16 INTEGER (1..8) OPTIONAL,
-- Need M
sl-DefaultTxConfigIndex-r16 INTEGER (0..maxCBR-Level-1-r16) OPTIONAL,
-- Need M
sl-CBR-ConfigIndex-r16 INTEGER (0..maxCBR-Config-1-r16) OPTIONAL,
-- Need M
sl-Tx-ConfigIndexList-r16 SEQUENCE (SIZE (1.. maxCBR-Level-r16)) OF SL-TxConfigIndex-r16 OPTIONAL -- Need M
}
SL-PriorityTxConfigIndex-v1650 ::= SEQUENCE {
sl-MCS-RangeList-r16 SEQUENCE (SIZE (1..maxCBR-Level-r16)) OF SL-MinMaxMCS-List-r16 OPTIONAL -- Need M
}
SL-TxConfigIndex-r16 ::= INTEGER (0..maxTxConfig-1-r16)
-- TAG-SL-CBR-PRIORITYTXCONFIGLIST-STOP
```

**_SL-CBR-PriorityTxConfigList_** **field descriptions** **_sl-CBR-ConfigIndex_** Indicates the CBR ranges to be used by an index to the entry of the CBR range configuration in _sl-CBR-RangeConfigList_.

**_sl-DefaultTxConfigIndex_** Indicates the PSSCH transmission parameters to be used by the UEs which do not have available CBR measurement results, by means of an index to the corresponding entry in _sl-Tx-ConfigIndexList_. Value 0 indicates the first entry in _sl-Tx-ConfigIndexList_. The field is ignored if the UE has available CBR measurement results.

**_sl-MCS-RangeList_** Indicates the minimum MCS value and maximum MCS value for the associated MCS table(s). UE shall ignore the minimum MCS value and maximum MCS value used for table of 64QAM indicated in _SL-CBR-PriorityTxConfigList-r16_ if _SL-CBR-PriorityTxConfigList-v1650_ is present.

**_sl-PriorityThreshold_** Indicates the upper bound of priority range which is associated with the configurations in _sl-CBR-ConfigIndex_ and in _sl-Tx-ConfigIndexList_. The upper bounds of the priority ranges are configured in ascending order for consecutive entries of _SL-PriorityTxConfigIndex_ in _SL-CBR-PriorityTxConfigList_. For the first entry of S_L-PriorityTxConfigIndex_, the lower bound of the priority range is 1.

**_SL-CBR-PriorityTxConfigList-v1650_** If included, it includes the same number of entries, and listed in the same order, as in _SL-CBR-PriorityTxConfigList-r16_.

##### SL-CBR-CommonTxConfigList

The IE _SL-CBR-CommonTxConfigList_ indicates the list of PSSCH transmission parameters (such as MCS, sub-channel number, retransmission number, CR limit) in _sl-CBR-PSSCH-TxConfigList_, and the list of CBR ranges in _sl-CBR-RangeConfigList_, to configure congestion control to the UE for sidelink communication.

**_SL-CBR-CommonTxConfigList_** **information element**

```asn1
-- TAG-SL-CBR-COMMONTXCONFIGLIST-START
SL-CBR-CommonTxConfigList-r16 ::= SEQUENCE {
sl-CBR-RangeConfigList-r16 SEQUENCE (SIZE (1..maxCBR-Config-r16)) OF SL-CBR-LevelsConfig-r16 OPTIONAL,
-- Need M
sl-CBR-PSSCH-TxConfigList-r16 SEQUENCE (SIZE (1.. maxTxConfig-r16)) OF SL-CBR-PSSCH-TxConfig-r16 OPTIONAL -- Need M
}
SL-CBR-LevelsConfig-r16 ::= SEQUENCE (SIZE (1..maxCBR-Level-r16)) OF SL-CBR-r16
SL-CBR-PSSCH-TxConfig-r16 ::= SEQUENCE {
sl-CR-Limit-r16 INTEGER(0..10000) OPTIONAL,
-- Need M
sl-TxParameters-r16 SL-PSSCH-TxParameters-r16 OPTIONAL -- Need M
}
SL-CBR-r16 ::= INTEGER (0..100)
-- TAG-SL-CBR-COMMONTXCONFIGLIST-STOP
```

**_SL-CBR-CommonTxConfigList_** **field descriptions** **_sl-CBR-RangeConfigList_** Indicates the list of CBR ranges. Each entry of the list indicates in _SL-CBR-LevelsConfig_ the upper bound of the CBR range for the respective entry. The upper bounds of the CBR ranges are configured in ascending order for consecutive entries of _sl-CBR-RangeConfigList._ For the first entry of _sl-CBR-RangeConfigList_ the lower bound of the CBR range is 0. Value 0 corresponds to 0, value 1 to 0.01, value 2 to 0.02, and so on.

**_sl-CR-Limit_** corresponds to 1.

Indicates the maximum limit on the occupancy ratio. Value 0 corresponds to 0, value 1 to 0.0001, value 2 to 0.0002, and so on (i.e. in steps of 0.0001) until value 10000, which **_sl-CBR-PSSCH-TxConfigList_** Indicates the list of available PSSCH transmission parameters (such as MCS, sub-channel number, retransmission number and CR limit) configurations.

**_sl-TxParameters_** Indicates PSSCH transmission parameters.

##### SL-ConfigDedicatedNR

The IE _SL-ConfigDedicatedNR_ specifies the dedicated configuration information for NR sidelink communication.

**_SL-ConfigDedicatedNR_** **information element**

```asn1
-- TAG-SL-CONFIGDEDICATEDNR-START
SL-ConfigDedicatedNR-r16 ::= SEQUENCE {
sl-PHY-MAC-RLC-Config-r16 SL-PHY-MAC-RLC-Config-r16 OPTIONAL,
-- Need M
sl-RadioBearerToReleaseList-r16 SEQUENCE (SIZE (1..maxNrofSLRB-r16)) OF SLRB-Uu-ConfigIndex-r16 OPTIONAL,
-- Need N
sl-RadioBearerToAddModList-r16 SEQUENCE (SIZE (1..maxNrofSLRB-r16)) OF SL-RadioBearerConfig-r16 OPTIONAL,
-- Need N
sl-MeasConfigInfoToReleaseList-r16 SEQUENCE (SIZE (1..maxNrofSL-Dest-r16)) OF SL-DestinationIndex-r16 OPTIONAL,
-- Need N
sl-MeasConfigInfoToAddModList-r16 SEQUENCE (SIZE (1..maxNrofSL-Dest-r16)) OF SL-MeasConfigInfo-r16 OPTIONAL,
-- Need N
t400-r16 ENUMERATED {ms100, ms200, ms300, ms400, ms600, ms1000, ms1500, ms2000} OPTIONAL,
-- Need M
...
}
SL-ConfigDedicatedNR-v16k0 ::= SEQUENCE {
sl-PHY-MAC-RLC-Config-v16k0 SL-PHY-MAC-RLC-Config-v16k0 OPTIONAL -- Need M
}
SL-DestinationIndex-r16 ::= INTEGER (0..maxNrofSL-Dest-1-r16)
SL-PHY-MAC-RLC-Config-r16::= SEQUENCE {
sl-ScheduledConfig-r16 SetupRelease { SL-ScheduledConfig-r16 } OPTIONAL,
-- Need M
sl-UE-SelectedConfig-r16 SetupRelease { SL-UE-SelectedConfig-r16 } OPTIONAL,
-- Need M
sl-FreqInfoToReleaseList-r16 SEQUENCE (SIZE (1..maxNrofFreqSL-r16)) OF SL-Freq-Id-r16 OPTIONAL,
-- Need N
sl-FreqInfoToAddModList-r16 SEQUENCE (SIZE (1..maxNrofFreqSL-r16)) OF SL-FreqConfig-r16 OPTIONAL,
-- Need N
sl-RLC-BearerToReleaseList-r16 SEQUENCE (SIZE (1..maxSL-LCID-r16)) OF SL-RLC-BearerConfigIndex-r16 OPTIONAL,
-- Need N
sl-RLC-BearerToAddModList-r16 SEQUENCE (SIZE (1..maxSL-LCID-r16)) OF SL-RLC-BearerConfig-r16 OPTIONAL,
-- Need N
sl-MaxNumConsecutiveDTX-r16 ENUMERATED {n1, n2, n3, n4, n6, n8, n16, n32} OPTIONAL,
-- Need M
sl-CSI-Acquisition-r16 ENUMERATED {enabled} OPTIONAL,
-- Need R
sl-CSI-SchedulingRequestId-r16 SetupRelease {SchedulingRequestId} OPTIONAL,
-- Need M
sl-SSB-PriorityNR-r16 INTEGER (1..8) OPTIONAL,
-- Need R
networkControlledSyncTx-r16 ENUMERATED {on, off} OPTIONAL -- Need M
}
SL-PHY-MAC-RLC-Config-v16k0::= SEQUENCE {
sl-FreqInfoToAddModListExt-v16k0 SEQUENCE (SIZE (1..maxNrofFreqSL-r16)) OF SL-FreqConfigExt-v16k0 OPTIONAL -- Need N
}
-- TAG-SL-CONFIGDEDICATEDNR-STOP
```

**_SL-ConfigDedicatedNR_** **field descriptions** **_sl-MeasConfigInfoToAddModList_** This field indicates the RSRP measurement configurations for unicast destinations to add and/or modify.

**_sl-MeasConfigInfoToReleaseList_** This field indicates the RSRP measurement configurations for unicast destinations to remove.

**_sl-PHY-MAC-RLC-Config_** This field indicates the lower layer sidelink radio bearer configurations.

**_sl-RadioBearerToAddModList_** This field indicates one or multiple sidelink radio bearer configurations to add and/or modify.

**_sl-RadioBearerToReleaseList_** This field indicates one or multiple sidelink radio bearer configurations to remove.

| | |
|---|---|
||SL-PHY-MAC-RLC-Config field descriptions|
|networkControlledSyncTx||
||This field indicates whether the UE shall transmit synchronisation information (i.e. become synchronisation source). Value on indicates the UE to transmit synchronisation|
|information while value off indicates the UE to not transmit such information.||
|sl-MaxNumConsecutiveDTX||
||This field indicates the maximum number of consecutive HARQ DTX before triggering sidelink RLF. Value n1 corresponds to 1, value n2 corresponds to 2, and so on.|
|sl-FreqInfoToAddModList, sl-FreqInfoToAddModListExt||
||This field indicates the NR sidelink communication configuration on some carrier frequency (ies) to add and/or modify. In this release, only one entry can be configured in the|
||list. If network includes sl-FreqInfoToAddModListExt, it includes the same number of entries, and listed in the same order, as in sl-FreqInfoToAddModList.|
|sl-FreqInfoToReleaseList||
||This field indicates the NR sidelink communication configuration on some carrier frequency (ies) to remove. In this release, only one entry can be configured in the list.|
|sl-RLC-BearerToAddModList||
|This field indicates one or multiple sidelink RLC bearer configurations to add and/or modify.||
|sl-RLC-BearerToReleaseList||
|This field indicates one or multiple sidelink RLC bearer configurations to remove.||
|sl-ScheduledConfig||
||Indicates the configuration for UE to transmit NR sidelink communication based on network scheduling. This field is not configured simultaneously with sl-UE-SelectedConfig.|
|sl-UE-SelectedConfig||
||Indicates the configuration used for UE autonomous resource selection. This field is not configured simultaneously with sl-ScheduledConfig.|
|sl-CSI-Acquisition||
||Indicates whether CSI reporting is enabled in sidelink unicast. If the field is absent, sidelink CSI reporting is disabled.|
|sl-CSI-SchedulingRequestId||
||If present, it indicates the scheduling request configuration applicable for sidelink CSI report MAC CE, as specified in TS 38.321 [3].|
|sl-SSB-PriorityNR||
|||

This field indicates the priority of NR sidelink SSB transmission and reception.

##### SL-ConfiguredGrantConfig

The IE _SL-ConfiguredGrantConfig_ specifies the configured grant configuration information for NR sidelink communication.

**_SL-ConfiguredGrantConfig_** **information element**

```asn1
-- TAG-SL-CONFIGUREDGRANTCONFIG-START
SL-ConfiguredGrantConfig-r16 ::= SEQUENCE {
sl-ConfigIndexCG-r16 SL-ConfigIndexCG-r16,
sl-PeriodCG-r16 SL-PeriodCG-r16 OPTIONAL,
-- Need M
sl-NrOfHARQ-Processes-r16 INTEGER (1..16) OPTIONAL,
-- Need M
sl-HARQ-ProcID-offset-r16 INTEGER (0..15) OPTIONAL,
-- Need M
sl-CG-MaxTransNumList-r16 SL-CG-MaxTransNumList-r16 OPTIONAL,
-- Need M
rrc-ConfiguredSidelinkGrant-r16 SEQUENCE {
sl-TimeResourceCG-Type1-r16 INTEGER (0..496) OPTIONAL,
-- Need M
sl-StartSubchannelCG-Type1-r16 INTEGER (0..26) OPTIONAL,
-- Need M
sl-FreqResourceCG-Type1-r16 INTEGER (0..6929) OPTIONAL,
-- Need M
sl-TimeOffsetCG-Type1-r16 INTEGER (0..7999) OPTIONAL,
-- Need R
sl-N1PUCCH-AN-r16 PUCCH-ResourceId OPTIONAL,
-- Need M
sl-PSFCH-ToPUCCH-CG-Type1-r16 INTEGER (0..15) OPTIONAL,
-- Need M
sl-ResourcePoolID-r16 SL-ResourcePoolID-r16 OPTIONAL,
-- Need M
sl-TimeReferenceSFN-Type1-r16 ENUMERATED {sfn512} OPTIONAL -- Need S
} OPTIONAL,
-- Need M
...,
[[
sl-N1PUCCH-AN-Type2-r16 PUCCH-ResourceId OPTIONAL -- Need M
]]
}
SL-ConfigIndexCG-r16 ::= INTEGER (0..maxNrofCG-SL-1-r16)
SL-CG-MaxTransNumList-r16 ::= SEQUENCE (SIZE (1..8)) OF SL-CG-MaxTransNum-r16
SL-CG-MaxTransNum-r16 ::= SEQUENCE {
sl-Priority-r16 INTEGER (1..8),
sl-MaxTransNum-r16 INTEGER (1..32)
}
SL-PeriodCG-r16 ::= CHOICE{
sl-PeriodCG1-r16 ENUMERATED {ms100, ms200, ms300, ms400, ms500, ms600, ms700, ms800, ms900, ms1000, spare6,
spare5, spare4, spare3, spare2, spare1},
sl-PeriodCG2-r16 INTEGER (1..99)
}
-- TAG-SL-CONFIGUREDGRANTCONFIG-STOP
```

**_SL-ConfiguredGrantConfig_** **field descriptions** **_rrc-ConfiguredSidelinkGrant_** Configuration for "sidelink configured grant" transmission with fully RRC-configured SL grant (Type1). If this field is not configured, the UE uses SL grant configured by DCI addressed to SL-CS-RNTI (Type2).

**_sl-ConfigIndexCG_** This field indicates the ID to identify configured grant for sidelink.

**_sl-CG-MaxTransNumList_** channel priority.

This field indicates the maximum number of times that a TB can be transmitted using the resources provided by the configured grant. _sl-Priority_ corresponds to the logical **_sl-FreqResourceCG-Type1_** Indicates the frequency resource location of sidelink configured grant type 1. An index giving valid combinations of one or two starting sub-channel and length (jointly encoded) as resource indicator value (RIV), as defined in TS 38.214 [19].

**_sl-HARQ-ProcID-Offset_** Indicates the offset used in deriving the HARQ process ID for SL configured grant type 1 or SL configured type 2, see TS 38.321 [3], clause 5.8.3.

**_sl-N1PUCCH-AN_** to by its ID.

This field indicates the PUCCH resource for HARQ feedback for sidelink configured grant type 1. The actual PUCCH-Resource is configured in _sl-PUCCH-Config_ and referred **_sl-N1PUCCH-AN-Type2_** This field indicates the PUCCH resource for HARQ feedback for PSCCH/PSSCH transmissions without a corresponding PDCCH on sidelink configured grant type 2. The actual PUCCH-Resource is configured in _sl-PUCCH-Config_ and referred to by its ID.

**_sl-NrOfHARQ-Processes_** This field indicates the number of HARQ processes configured for a specific configured grant. It applies for both Type 1 and Type 2.

**_sl-PeriodCG_** This field indicates the period of sidelink configured grant in the unit of ms.

**_sl-PSFCH-ToPUCCH-CG-Type1_** reporting sidelink HARQ.

This field, for configured grant type 1, indicates slot offset between the PSFCH associated with the last PSSCH resource of each period and the PUCCH occasion used for **_sl-ResourcePoolID_** Indicates the resource pool in which the configured sidelink grant Type 1 is applied.

**_sl-StartSubchannelCG-Type1_** This field indicates the starting sub-channel of sidelink configured grant Type 1. An index giving valid sub-channel index.

**_sl-TimeOffsetCG-Type1_** This field indicates the slot offset with respect to logical slot defined by _sl-TimeReferenceSFN-Type1_, as specified in TS 38.321 [3].

**_sl-TimeReferenceSFN-Type1_** Indicates SFN used for determination of the offset of a resource in time domain. If it is present, the UE uses the 1st logical slot of associated resource pool after the starting time of the closest SFN with the indicated number preceding the reception of the sidelink configured grant configuration Type 1 as reference logical slot, see TS 38.321 [3], clause 5.8.3. If it is not present, the reference SFN is 0.

**_sl-TimeResourceCG-Type1_** This field indicates the time resource location of sidelink configured grant Type 1. An index giving valid combinations of up to two slot positions (jointly encoded) as time resource indicator value (TRIV), as defined in TS 38.212 [17].

##### SL-DestinationIdentity

The IE _SL-DestinationIdentity_ is used to identify a destination of a NR sidelink communication.

**_SL-DestinationIdentity_** **information element**

```asn1
-- TAG-SL-DESTINATIONIDENTITY-START
SL-DestinationIdentity-r16 ::= BIT STRING (SIZE (24))
-- TAG-SL-DESTINATIONIDENTITY-STOP
```

##### SL-FreqConfig

The IE _SL-FreqConfig_ specifies the dedicated configuration information on one particular carrier frequency for NR sidelink communication.

**_SL-FreqConfig_** **information element**

```asn1
-- TAG-SL-FREQCONFIG-START
SL-FreqConfig-r16 ::= SEQUENCE {
sl-Freq-Id-r16 SL-Freq-Id-r16,
sl-SCS-SpecificCarrierList-r16 SEQUENCE (SIZE (1..maxSCSs)) OF SCS-SpecificCarrier,
sl-AbsoluteFrequencyPointA-r16 ARFCN-ValueNR OPTIONAL,
-- Need M
sl-AbsoluteFrequencySSB-r16 ARFCN-ValueNR OPTIONAL,
-- Need R
frequencyShift7p5khzSL-r16 ENUMERATED {true} OPTIONAL,
-- Cond V2X-SL-Shared
valueN-r16 INTEGER (-1..1),
sl-BWP-ToReleaseList-r16 SEQUENCE (SIZE (1..maxNrofSL-BWPs-r16)) OF BWP-Id OPTIONAL,
-- Need N
sl-BWP-ToAddModList-r16 SEQUENCE (SIZE (1..maxNrofSL-BWPs-r16)) OF SL-BWP-Config-r16 OPTIONAL,
-- Need N
sl-SyncConfigList-r16 SL-SyncConfigList-r16 OPTIONAL,
-- Need M
sl-SyncPriority-r16 ENUMERATED {gnss, gnbEnb} OPTIONAL -- Need M
}
SL-FreqConfigExt-v16k0 ::= SEQUENCE {
additionalSpectrumEmission-r16 AdditionalSpectrumEmission OPTIONAL -- Need M
}
SL-Freq-Id-r16 ::= INTEGER (1.. maxNrofFreqSL-r16)
-- TAG-SL-FREQCONFIG-STOP
```

**_SL-FreqConfig_** **field descriptions** **_additionalSpectrumEmission_** Provides the _additionalSpectrumEmission_ values as defined in TS 38.101-1 [15], clause 6.2E.3.1.

**_frequencyShift7p5khzSL_** Enable the NR SL transmission with a 7.5 kHz shift to the LTE raster. If the field is absent, the frequency shift is disabled.

**_sl-AbsoluteFrequencyPointA_** Absolute frequency of the reference resource block (Common RB 0). Its lowest subcarrier is also known as Point A.

**_sl-AbsoluteFrequencySSB_** Indicates the frequency location of sidelink SSB. The transmission bandwidth for sidelink SSB is within the bandwidth of this sidelink BWP.

**_sl-BWP-ToAddModList_** This field indicates the list of sidelink BWP(s) on which the NR sidelink communication configuration is to be added or reconfigured. In this release, only one BWP is allowed to be configured for NR sidelink communication.

**_sl-BWP-ToReleaseList_** This field indicates the list of sidelink BWP(s) on which the NR sidelink communication configuration is to be released.

**_sl-Freq-Id_** This field indicates the identity of the dedicated configuration information on the carrier frequency for NR sidelink communication.

**_sl-SCS-SpecificCarrierList_** A set of UE specific channel bandwidth and location configurations for different subcarrier spacings (numerologies). Defined in relation to Point A. The UE uses the configuration provided in this field only for the purpose of channel bandwidth and location determination. In this release, only one _SCS-SpecificCarrier_ is allowed to be configured for NR sidelink communication.

**_sl-SyncPriority_** This field indicates synchronization priority order, as specified in clause 5.8.6.

**_valueN_** Indicate the NR SL transmission with a valueN *5kHz shift to the LTE raster. (see TS 38.101-1 [15], clause 5.4E.2).

**Conditional Presence** **Explanation** _V2X-SL-Shared_ This field is mandatory present if the carrier frequency configured for NR sidelink communication is shared by V2X sidelink communication. It is absent, Need R, otherwise.

##### SL-FreqConfigCommon

The IE _FreqConfigCommon_ specifies the cell-specific configuration information on one particular carrier frequency for NR sidelink communication.

**_SL-FreqConfigCommon_** **information element**

```asn1
-- TAG-SL-FREQCONFIGCOMMON-START
SL-FreqConfigCommon-r16 ::= SEQUENCE {
sl-SCS-SpecificCarrierList-r16 SEQUENCE (SIZE (1..maxSCSs)) OF SCS-SpecificCarrier,
sl-AbsoluteFrequencyPointA-r16 ARFCN-ValueNR,
sl-AbsoluteFrequencySSB-r16 ARFCN-ValueNR OPTIONAL,
-- Need R
frequencyShift7p5khzSL-r16 ENUMERATED {true} OPTIONAL,
-- Cond V2X-SL-Shared
valueN-r16 INTEGER (-1..1),
sl-BWP-List-r16 SEQUENCE (SIZE (1..maxNrofSL-BWPs-r16)) OF SL-BWP-ConfigCommon-r16 OPTIONAL,
-- Need R
sl-SyncPriority-r16 ENUMERATED {gnss, gnbEnb} OPTIONAL,
-- Need R
sl-NbAsSync-r16 BOOLEAN OPTIONAL,
-- Need R
sl-SyncConfigList-r16 SL-SyncConfigList-r16 OPTIONAL,
-- Need R
...
}
SL-FreqConfigCommonExt-v16k0 ::= SEQUENCE {
additionalSpectrumEmission-r16 AdditionalSpectrumEmission OPTIONAL -- Need R
}
-- TAG-SL-FREQCONFIGCOMMON-STOP
```

**_SL-FreqConfigCommon_** **field descriptions** **_additionalSpectrumEmission_** Provides the _additionalSpectrumEmission_ values as defined in TS 38.101-1 [15], clause 6.2E.3.1.

**_frequencyShift7p5khzSL_** Enable the NR SL transmission with a 7.5 kHz shift to the LTE raster. If the field is absent, the frequency shift is disabled.

**_sl-AbsoluteFrequencyPointA_** Absolute frequency of the reference resource block (Common RB 0). Its lowest subcarrier is also known as Point A.

**_sl-AbsoluteFrequencySSB_** Indicates the frequency location of sidelink SSB. The transmission bandwidth for sidelink SSB is within the bandwidth of this sidelink BWP.

**_sl-BWP-List_** communication.

This field indicates the list of sidelink BWP(s) on which the NR sidelink communication configuration. In this release, only one BWP is allowed to be configured for NR sidelink **_sl-NbAsSync_** This field indicates whether the network can be selected as synchronization reference directly/indirectly only, if _sl-SyncPriority_ is set to gnss. If this field is set to TRUE, the network is enabled to be selected as synchronization reference directly/indirectly. The field is only present in _SidelinkPreconfigNR_. Otherwise it is absent.

**_sl-SyncPriority_** This field indicates synchronization priority order, as specified in clause 5.8.6..

**_sl-SyncConfigList_** This field indicates the configuration by which the UE is allowed to receive and transmit synchronisation information for NR sidelink communication. Network configures _sl-SyncConfig_ including _txParameters_ when configuring UEs to transmit synchronisation information. If this field is configured in _SL-PreconfigurationNR-r16_, only one entry is configured in _sl-SyncConfigList_.

**_valueN_** Indicate the NR SL transmission with a valueN *5kHz shift to the LTE raster (see TS 38.101-1 [15], clause 5.4E.2).

**Conditional Presence** **Explanation** _V2X-SL-Shared_ This field is mandatory present if the carrier frequency configured for NR sidelink communication is shared by V2X sidelink communication. It is absent, Need R, otherwise.

##### SL-LogicalChannelConfig

The IE _SL_-_LogicalChannelConfig_ is used to configure the sidelink logical channel parameters.

**_SL-LogicalChannelConfig_** **information element**

```asn1
-- TAG-SL-LOGICALCHANNELCONFIG-START
SL-LogicalChannelConfig-r16 ::= SEQUENCE {
sl-Priority-r16 INTEGER (1..8),
sl-PrioritisedBitRate-r16 ENUMERATED {kBps0, kBps8, kBps16, kBps32, kBps64, kBps128, kBps256, kBps512,
kBps1024, kBps2048, kBps4096, kBps8192, kBps16384, kBps32768, kBps65536, infinity},
sl-BucketSizeDuration-r16 ENUMERATED {ms5, ms10, ms20, ms50, ms100, ms150, ms300, ms500, ms1000,
spare7, spare6, spare5, spare4, spare3,spare2, spare1},
sl-ConfiguredGrantType1Allowed-r16 ENUMERATED {true} OPTIONAL,
-- Need R
sl-HARQ-FeedbackEnabled-r16 ENUMERATED {enabled, disabled } OPTIONAL,
-- Need R
sl-AllowedCG-List-r16 SEQUENCE (SIZE (0.. maxNrofCG-SL-1-r16)) OF SL-ConfigIndexCG-r16
OPTIONAL,
-- Need R
sl-AllowedSCS-List-r16 SEQUENCE (SIZE (1..maxSCSs)) OF SubcarrierSpacing OPTIONAL,
-- Need R
sl-MaxPUSCH-Duration-r16 ENUMERATED {ms0p02, ms0p04, ms0p0625, ms0p125, ms0p25, ms0p5, spare2, spare1}
OPTIONAL,
-- Need R
sl-LogicalChannelGroup-r16 INTEGER (0..maxLCG-ID) OPTIONAL,
-- Need R
sl-SchedulingRequestId-r16 SchedulingRequestId OPTIONAL,
-- Need R
sl-LogicalChannelSR-DelayTimerApplied-r16 BOOLEAN OPTIONAL,
-- Need R
...
}
-- TAG-SL-LOGICALCHANNELCONFIG-STOP
```

**_SL-LogicalChannelConfig field_** **descriptions** **_sl-AllowedCG-List_** This restriction applies only when the SL grant is a configured grant. If present, SL MAC SDUs from this logical channel can only be mapped to the indicated configured grant configuration. If the size of the sequence is zero, then SL MAC SDUs from this logical channel cannot be mapped to any configured grant configurations. If the field is not present, SL MAC SDUs from this logical channel can be mapped to any configured grant configurations. If the field _sl-ConfiguredGrantType1Allowed_ is present, only those sidelink configured grant type 1 configurations indicated in this sequence are allowed for use by this sidelink logical channel; otherwise, this sequence shall not include any sidelink configured grant type 1 configuration. Corresponds to "sl-AllowedCG-List" as specified in TS 38.321 [3].

**_sl-AllowedSCS-List_** If present, it indicates the numerology of UL-SCH resources that this sidelink logical channel is mapped to, when checking the SR trigger condition. Corresponds to ' sl- AllowedSCS-List' in TS 38.321 [3].

**_sl-BucketSizeDuration_** Value in ms. _ms5_ corresponds to 5 ms, value _ms10_ corresponds to 10 ms, and so on.

**_sl-ConfiguredGrantType1Allowed_** If present and set to true, or if the capability _lcp-RestrictionSidelink_ as specified in TS 38.306 [26] is not indicated, SL MAC SDUs from this sidelink logical channel can be transmitted on a sidelink configured grant type 1. Otherwise, SL MAC SDUs from this logical channel cannot be transmitted on a sidelink configured grant type 1. Corresponds to 'sl-configuredGrantType1Allowed' in TS 38.321 [3].

**_sl-HARQ-FeedbackEnabled_** Network always includes this field. It indicates the HARQ feedback enabled/disabled restriction in LCP for this sidelink logical channel. If set to _enabled_, the sidelink logical channel will be multiplexed only with a logical channel which enabling the HARQ feedback. If set to _disabled_, the sidelink logical channel cannot be multiplexed with a logical channel which enabling the HARQ feedback. Corresponds to 'sl-HARQ-FeedbackEnabled' in TS 38.321 [3]. If this field of at least one sidelink logical channel for the UE is set to enabled, _sl-PSFCH-Config_ should be mandatory present in configuration _SL-ResourcePool_ of at least one of the sidelink resource pools.

**_sl-LogicalChannelGroup_** ID of the sidelink logical channel group, as specified in TS 38.321 [3], which the sidelink logical channel belongs to.

**_sl-LogicalChannelSR-DelayTimerApplied_** Indicates whether to apply the delay timer for SR transmission for this sidelink logical channel. Set to false if _logicalChannelSR-DelayTimer_ is not included in _sl-BSR-Config_.

**_sl-MaxPUSCH-Duration_** If present, it indicates the maximum PUSCH duration of UL-SCH resources that this sidelink logical channel is mapped to, when checking the SR trigger condition.

Corresponds to "sl-MaxPUSCH-Duration" in TS 38.321 [3].

**_sl-PrioritisedBitRate_** Value in kiloBytes/s. Value _kBps0_ corresponds to 0 kiloBytes/s, value _kBps8_ corresponds to 8 kiloBytes/s, value _kBps16_ corresponds to 16 kiloBytes/s, and so on.

**_sl-Priority_** Sidelink logical channel priority, as specified in TS 38.321 [3].

**_sl-SchedulingRequestId_** If present, it indicates the scheduling request configuration applicable for this sidelink logical channel, as specified in TS 38.321 [3].

##### SL-MeasConfigCommon

The IE _SL-MeasConfigCommon_ is used to set the cell specific SL RSRP measurement configurations for unicast destinations.

**_SL-MeasConfigCommon_** **information element**

```asn1
-- TAG-SL-MEASCONFIGCOMMON-START
SL-MeasConfigCommon-r16 ::= SEQUENCE {
sl-MeasObjectListCommon-r16 SL-MeasObjectList-r16 OPTIONAL,
-- Need R
sl-ReportConfigListCommon-r16 SL-ReportConfigList-r16 OPTIONAL,
-- Need R
sl-MeasIdListCommon-r16 SL-MeasIdList-r16 OPTIONAL,
-- Need R
sl-QuantityConfigCommon-r16 SL-QuantityConfig-r16 OPTIONAL,
-- Need R
...
}
-- TAG-SL-MEASCONFIGCOMMON-STOP
```

**_SL-MeasConfigCommon_** **field descriptions** **_sl-MeasIdListCommon_** List of sidelink measurement identities **_sl-MeasObjectListCommon_** List of sidelink measurement objects.

**_sl-QuantityConfigCommon_** Indicates the layer 3 filtering coefficient for sidelink measurement.

**_sl-ReportConfigListCommon_** List of sidelink measurement reporting configurations.

##### SL-MeasConfigInfo

The IE _SL_-_MeasConfigInfo_ is used to set RSRP measurement configurations for unicast destinations.

**_SL-MeasConfigInfo_** **information element**

```asn1
-- TAG-SL-MEASCONFIGINFO-START
SL-MeasConfigInfo-r16 ::= SEQUENCE {
sl-DestinationIndex-r16 SL-DestinationIndex-r16,
sl-MeasConfig-r16 SL-MeasConfig-r16,
...
}
SL-MeasConfig-r16 ::= SEQUENCE {
sl-MeasObjectToRemoveList-r16 SL-MeasObjectToRemoveList-r16 OPTIONAL,
-- Need N
sl-MeasObjectToAddModList-r16 SL-MeasObjectList-r16 OPTIONAL,
-- Need N
sl-ReportConfigToRemoveList-r16 SL-ReportConfigToRemoveList-r16 OPTIONAL,
-- Need N
sl-ReportConfigToAddModList-r16 SL-ReportConfigList-r16 OPTIONAL,
-- Need N
sl-MeasIdToRemoveList-r16 SL-MeasIdToRemoveList-r16 OPTIONAL,
-- Need N
sl-MeasIdToAddModList-r16 SL-MeasIdList-r16 OPTIONAL,
-- Need N
sl-QuantityConfig-r16 SL-QuantityConfig-r16 OPTIONAL,
-- Need M
...
}
SL-MeasObjectToRemoveList-r16 ::= SEQUENCE (SIZE (1..maxNrofSL-ObjectId-r16)) OF SL-MeasObjectId-r16
SL-ReportConfigToRemoveList-r16 ::= SEQUENCE (SIZE (1..maxNrofSL-ReportConfigId-r16)) OF SL-ReportConfigId-r16
SL-MeasIdToRemoveList-r16 ::= SEQUENCE (SIZE (1..maxNrofSL-MeasId-r16)) OF SL-MeasId-r16
-- TAG-SL-MEASCONFIGINFO-STOP
```

**_SL-MeasConfigInfo_** **field descriptions** **_sl-MeasIdToAddModList_** List of sidelink measurement identities to add and/or modify.

**_sl-MeasIdToRemoveList_** List of sidelink measurement identities to remove.

**_sl-MeasObjectToAddModList_** List of sidelink measurement objects to add and/or modify.

**_sl-MeasObjectToRemoveList_** List of sidelink measurement objects to remove.

**_sl-QuantityConfig_** Indicates the layer 3 filtering coefficient for sidelink measurement.

**_sl-ReportConfigToAddModList_** List of sidelink measurement reporting configurations to add and/or modify.

**_sl-ReportConfigToRemoveList_** List of sidelink measurement reporting configurations to remove.

##### SL-MeasIdList

The IE _SL_-_MeasIdList_ concerns a list of SL measurement identities to add or modify for a destination, with for each entry the _sl-MeasId_, the associated _sl-MeasObjectId_ and the associated _sl-ReportConfigId_.

**_SL-MeasIdList_** **information element**

```asn1
-- TAG-SL-MEASIDLIST-START
SL-MeasIdList-r16 ::= SEQUENCE (SIZE (1..maxNrofSL-MeasId-r16)) OF SL-MeasIdInfo-r16
SL-MeasIdInfo-r16 ::= SEQUENCE {
sl-MeasId-r16 SL-MeasId-r16,
sl-MeasObjectId-r16 SL-MeasObjectId-r16,
sl-ReportConfigId-r16 SL-ReportConfigId-r16,
...
}
SL-MeasId-r16 ::= INTEGER (1..maxNrofSL-MeasId-r16)
-- TAG-SL-MEASIDLIST-STOP
```

##### SL-MeasObjectList

The IE _SL_-_MeasObjectList_ concerns a list of SL measurement objects to add or modify for a destination.

**_SL-MeasObjectList_** **information element**

```asn1
-- TAG-SL-MEASOBJECTLIST-START
SL-MeasObjectList-r16 ::= SEQUENCE (SIZE (1..maxNrofSL-ObjectId-r16)) OF SL-MeasObjectInfo-r16
SL-MeasObjectInfo-r16 ::= SEQUENCE {
sl-MeasObjectId-r16 SL-MeasObjectId-r16,
sl-MeasObject-r16 SL-MeasObject-r16,
...
}
SL-MeasObjectId-r16 ::= INTEGER (1..maxNrofSL-ObjectId-r16)
SL-MeasObject-r16 ::= SEQUENCE {
frequencyInfoSL-r16 ARFCN-ValueNR,
...
}
-- TAG-SL-MEASOBJECTLIST-STOP
```

**_SL-MeasObjectList_** **field descriptions** **_frequencyInfoSL_** It indicates the lowest usable subcarrier on the carrier where SL RSRP is measured, determined according to _sl-AbsoluteFrequencyPointA_ in IE _SL-FreqConfig/SL-FreqConfigCommon_ and _offsetToCarrier_ in IE _SCS-SpecificCarrier_ configured for _sl-SCS-SpecificCarrierList_ in IE _SL-FreqConfig_/_SL-FreqConfigCommon_. See TS 38.211 [16], clause 8.2.5.

**_sl-MeasObjectId_** It is used to identify a sidelink measurement object configuration.

**_sl-MeasObject_** It specifies information applicable for sidelink DMRS measurement.

##### SL-PDCP-Config

The IE _SL_-_PDCP-Config_ is used to set the configurable PDCP parameters for a sidelink radio bearer.

**_SL-PDCP-Config_** **information element**

```asn1
-- TAG-SL-PDCP-CONFIG-START
SL-PDCP-Config-r16 ::= SEQUENCE {
sl-DiscardTimer-r16 ENUMERATED {ms3, ms10, ms20, ms25, ms30, ms40, ms50, ms60, ms75, ms100, ms150, ms200,
ms250, ms300, ms500, ms750, ms1500, infinity} OPTIONAL,
-- Cond Setup
sl-PDCP-SN-Size-r16 ENUMERATED {len12bits, len18bits} OPTIONAL,
-- Cond Setup2
sl-OutOfOrderDelivery ENUMERATED { true } OPTIONAL,
-- Need R
...
}
-- TAG-SL-PDCP-CONFIG-STOP
```

**_SL-PDCP-Config_** **field descriptions** **_sl-DiscardTimer_** Value in ms of _discardTimer_ specified in TS 38.323 [5]. Value _ms50_ corresponds to 50 ms, value _ms100_ corresponds to 100 ms and so on.

**_sl-OutOfOrderDelivery_** established.

Indicates whether or not outOfOrderDelivery specified in TS 38.323 [5] is configured. This field should be either always present or always absent, after the radio bearer is **_sl-PDCP-SN-Size_** PDCP sequence number size for unicast NR sidelink communication, 12 or 18 bits, as specified in TS 38.323 [5]. For groupcast and broadcast NR sidelink communication, only 12 bits is applicable, as specified in 9.1.1.5.

**Conditional Presence** **Explanation** _Setup_ The field is mandatory present in case of sidelink DRB setup via dedicated signaling and in case of sidelink DRB configuration via system information and pre-configuration; otherwise the field is optionally present, need M.

_Setup2_ The field is mandatory present in case of sidelink DRB setup via dedicated signaling and in case of sidelink DRB configuration via system information and pre-configuration for RLC-AM and RLC-UM for unicast NR sidelink communication; otherwise the field is not present, Need M.

##### SL-PSBCH-Config

The IE _SL-PSBCH-Config_ indicates PSBCH transmission parameters on each sidelink bandwidth part.

**_SL-PSBCH-Config_** **information element**

```asn1
-- TAG-SL-PSBCH-CONFIG-START
SL-PSBCH-Config-r16 ::= SEQUENCE {
dl-P0-PSBCH-r16 INTEGER (-16..15) OPTIONAL,
-- Need M
dl-Alpha-PSBCH-r16 ENUMERATED {alpha0, alpha04, alpha05, alpha06, alpha07, alpha08, alpha09, alpha1} OPTIONAL,
-- Need M
...
}
-- TAG-SL-PSBCH-CONFIG-STOP
```

**_SL-PSBCH-Config_** **field descriptions** **_dl-Alpha-PSBCH_** Indicates alpha value for DL pathloss based power control for PSBCH. When the field is not configured the UE applies the value 1 **_dl-P0-PSBCH_** Indicates P0 value for DL pathloss based power control for PSBCH. If not configured, DL pathloss based power control is disabled for PSBCH.

##### SL-PSSCH-TxConfigList

The IE _SL-PSSCH-TxConfigList_ indicates PSSCH transmission parameters. When lower layers select parameters from the range indicated in IE _SL-PSSCH-TxConfigList_, the UE considers both configurations in IE _SL-PSSCH-TxConfigList_ and the CBR-dependent configurations represented in IE _SL-CBR-PriorityTxConfigList_. Only one IE _SL-PSSCH-TxConfig_ is provided per _SL-TypeTxSync_.

**_SL-PSSCH-TxConfigList_** **information element**

```asn1
-- TAG-SL-PSSCH-TXCONFIGLIST-START
SL-PSSCH-TxConfigList-r16 ::= SEQUENCE (SIZE (1..maxPSSCH-TxConfig-r16)) OF SL-PSSCH-TxConfig-r16
SL-PSSCH-TxConfig-r16 ::= SEQUENCE {
sl-TypeTxSync-r16 SL-TypeTxSync-r16 OPTIONAL,
-- Need R
sl-ThresUE-Speed-r16 ENUMERATED {kmph60, kmph80, kmph100, kmph120,
kmph140, kmph160, kmph180, kmph200},
sl-ParametersAboveThres-r16 SL-PSSCH-TxParameters-r16,
sl-ParametersBelowThres-r16 SL-PSSCH-TxParameters-r16,
...,
[[
sl-ParametersAboveThres-v1650 SL-MinMaxMCS-List-r16 OPTIONAL,
-- Need R
sl-ParametersBelowThres-v1650 SL-MinMaxMCS-List-r16 OPTIONAL -- Need R
]]
}
SL-PSSCH-TxParameters-r16 ::= SEQUENCE {
sl-MinMCS-PSSCH-r16 INTEGER (0..27),
sl-MaxMCS-PSSCH-r16 INTEGER (0..31),
sl-MinSubChannelNumPSSCH-r16 INTEGER (1..27),
sl-MaxSubchannelNumPSSCH-r16 INTEGER (1..27),
sl-MaxTxTransNumPSSCH-r16 INTEGER (1..32),
sl-MaxTxPower-r16 SL-TxPower-r16 OPTIONAL -- Cond CBR
}
-- TAG-SL-PSSCH-TXCONFIGLIST-STOP
```

**_SL-PSSCH-TxConfigList_** **field descriptions** **_sl-MaxTxTransNumPSSCH_** Indicates the maximum transmission number (including new transmission and retransmission) for PSSCH.

**_sl-MaxTxPower_** This field indicates the maximum transmission power for transmission on PSSCH and PSCCH.

**_sl-MinMCS-PSSCH, sl-MaxMCS-PSSCH_** This field indicates the minimum and maximum MCS values used for transmissions on PSSCH. The UE shall ignore the minimum and maximum MCS values used for the associated MCS table(s) in _sl-ParametersAboveThres-r16_ and _sl-ParametersBelowThres-r16_ if _sl-ParametersAboveThres-v1650_ and _sl-ParametersBelowThres-v1650_ are present, respectively.

**_sl-MinSubChannelNumPSSCH, sl-MaxSubChannelNumPSSCH_** This field indicates the minimum and maximum number of sub-channels which may be used for transmissions on PSSCH.

**_sl-TypeTxSync_** This field indicates the synchronization reference type. For configurations by the eNB/gNB, only _gnbEnb_ can be configured; and for pre-configuration or when this field is absent, the configuration is applicable for all synchronization reference types.

**_sl-ThresUE-Speed_** This field indicates a UE absolute speed threshold.

**Conditional Presence** **Explanation** _CBR_ The field is optionally present, Need R, when the IE _SL-PSSCH-TxParameters_ is present in _SL-CBR-CommonTxConfigList,_ _SL-UE-SelectedConfig,_ _SIB12_ or _SidelinkPreconfigNR_; otherwise the field is not present, need R.

##### SL-QoS-FlowIdentity

The IE _SL-QoS-FlowIdentity_ is used to identify a sidelink QoS flow.

**_SL-QoS-FlowIdentity_** **information element**

```asn1
-- TAG-SL-QOS-FLOWIDENTITY-START
SL-QoS-FlowIdentity-r16 ::= INTEGER (1..maxNrofSL-QFIs-r16)
-- TAG-SL-QOS-FLOWIDENTITY-STOP
```

##### SL-QoS-Profile

The IE _SL-QoS-Profile_ is used to give the QoS parameters for a sidelink QoS flow. Need codes or conditions specified for _SL-QoS-Profile_ do not apply, in case _SL-QoS-Profile_ is included in _SidelinkUEInformationNR_.

**_SL-QoS-Profile_** **information element**

```asn1
-- TAG-SL-QOS-PROFILE-START
SL-QoS-Profile-r16 ::= SEQUENCE {
sl-PQI-r16 SL-PQI-r16 OPTIONAL,
-- Need R
sl-GFBR-r16 INTEGER (0..4000000000) OPTIONAL,
-- Need R
sl-MFBR-r16 INTEGER (0..4000000000) OPTIONAL,
-- Need R
sl-Range-r16 INTEGER (1..1000) OPTIONAL,
-- Need R
...
}
SL-PQI-r16 ::= CHOICE {
sl-StandardizedPQI-r16 INTEGER (0..255),
sl-Non-StandardizedPQI-r16 SEQUENCE {
sl-ResourceType-r16 ENUMERATED {gbr, non-GBR, delayCriticalGBR, spare1} OPTIONAL,
-- Need R
sl-PriorityLevel-r16 INTEGER (1..8) OPTIONAL,
-- Need R
sl-PacketDelayBudget-r16 INTEGER (0..1023) OPTIONAL,
-- Need R
sl-PacketErrorRate-r16 INTEGER (0..9) OPTIONAL,
-- Need R
sl-AveragingWindow-r16 INTEGER (0..4095) OPTIONAL,
-- Need R
sl-MaxDataBurstVolume-r16 INTEGER (0..4095) OPTIONAL,
-- Need R
...
}
}
-- TAG-SL-QOS-PROFILE-STOP
```

**_SL-QoS-Profile_** **field descriptions** **_sl-GFBR_** Indicate the guaranteed bit rate for a GBR QoS flow. The unit is: Kbit/s **_sl-MFBR_** Indicate the maximum bit rate for a GBR QoS flow. The unit is: Kbit/s **_sl-PQI_** This field indicates either the PQI for standardized PQI or non-standardized QoS parameters.

**_sl-Range_** This field indicates the range parameter of the Qos flow, as defined in clause 5.4.1.1.1, TS 23.287 [55]. It is present only for groupcast. The unit is meter.

**_SL-PQI_** **field descriptions** **_sl-AveragingWindow_** Indicates the Averaging Window for a QoS flow, and applies to GBR QoS flows only. Unit: ms. The default value of the IE is 2000ms.

**_sl-MaxDataBurstVolume_** Indicates the Maximum Data Burst Volume for a QoS flow, and applies to delay critical GBR QoS flows only. Unit: byte.

**_sl-PacketDelayBudget_** Indicates the Packet Delay Budget for a QoS flow. Upper bound value for the delay that a packet may experience expressed in unit of 0.5ms.

**_sl-PacketErrorRate_** Indicates the Packet Error Rate for a QoS flow. The packet error rate is expressed as Scalar x 10-k where k is the Exponent.

**_sl-PriorityLevel_** Indicates the Priority Level for a QoS flow. Values ordered in decreasing order of priority, i.e. with 1 as the highest priority and 8 as the lowest priority.

**_sl-StandardizedPQI_** Indicate the PQI for standardized PQI.

##### SL-QuantityConfig

The IE _SL_-_QuantityConfig_ specifies the layer 3 filtering coefficients for NR SL RSRP measurement for a destination.

**_SL-QuantityConfig_** **information element**

```asn1
-- TAG-SL-QUANTITYCONFIG-START
SL-QuantityConfig-r16 ::= SEQUENCE {
sl-FilterCoefficientDMRS-r16 FilterCoefficient DEFAULT fc4,
...
}
-- TAG-SL-QuantityConfig-STOP
```

**_SL-QuantityConfig_** **field descriptions** **_sl-FilterCoefficientDMRS_** DMRS based L3 filter configuration:

Specifies L3 filter configuration for sidelink RSRP measurement result from the L1 fiter(s), as defined in TS 38.215 [9].

##### SL-RadioBearerConfig

The IE _SL-RadioBearerConfig_ specifies the sidelink DRB configuration information for NR sidelink communication.

**_SL-RadioBearerConfig_** **information element**

```asn1
-- TAG-SL-RADIOBEARERCONFIG-START
SL-RadioBearerConfig-r16 ::= SEQUENCE {
slrb-Uu-ConfigIndex-r16 SLRB-Uu-ConfigIndex-r16,
sl-SDAP-Config-r16 SL-SDAP-Config-r16 OPTIONAL,
-- Cond SLRBSetup
sl-PDCP-Config-r16 SL-PDCP-Config-r16 OPTIONAL,
-- Cond SLRBSetup
sl-TransRange-r16 ENUMERATED {m20, m50, m80, m100, m120, m150, m180, m200, m220, m250, m270, m300, m350, m370,
m400, m420, m450, m480, m500, m550, m600, m700, m1000, spare9, spare8, spare7, spare6,
spare5, spare4, spare3, spare2, spare1} OPTIONAL,
-- Need R
...
}
-- TAG-SL-RADIOBEARERCONFIG-STOP
```

**_SL-RadioBearerConfig_** **field descriptions** **_sl-PDCP-Config_** This field indicates the PDCP parameters for the sidelink DRB.

**_sl-SDAP-Config_** This field indicates how to map sidelink QoS flows to sidelink DRB.

**_slrb-Uu-ConfigIndex_** This field indicates the index of sidelink DRB configuration.

**_sl-TransRange_** This field indicates the transmission range of the sidelink DRB. The unit is meter.

**Conditional Presence** **Explanation** _SLRBSetup_ The field is mandatory present in case of sidelink DRB setup via the dedicated signalling and in case of sidelink DRB configuration via system information and pre-configuration; otherwise the field is optionally present, need M.

##### SL-ReportConfigList

The IE _SL_-_ReportConfigList_ concerns a list of SL measurement reporting configurations to add or modify for a destination.

**_SL-ReportConfigList_** **information element**

```asn1
-- TAG-SL-REPORTCONFIGLIST-START
SL-ReportConfigList-r16 ::= SEQUENCE (SIZE (1..maxNrofSL-ReportConfigId-r16)) OF SL-ReportConfigInfo-r16
SL-ReportConfigInfo-r16 ::= SEQUENCE {
sl-ReportConfigId-r16 SL-ReportConfigId-r16,
sl-ReportConfig-r16 SL-ReportConfig-r16,
...
}
SL-ReportConfigId-r16 ::= INTEGER (1..maxNrofSL-ReportConfigId-r16)
SL-ReportConfig-r16 ::= SEQUENCE {
sl-ReportType-r16 CHOICE {
sl-Periodical-r16 SL-PeriodicalReportConfig-r16,
sl-EventTriggered-r16 SL-EventTriggerConfig-r16,
...
},
...
}
SL-PeriodicalReportConfig-r16 ::= SEQUENCE {
sl-ReportInterval-r16 ReportInterval,
sl-ReportAmount-r16 ENUMERATED {r1, r2, r4, r8, r16, r32, r64, infinity},
sl-ReportQuantity-r16 SL-MeasReportQuantity-r16,
sl-RS-Type-r16 SL-RS-Type-r16,
...
}
SL-EventTriggerConfig-r16 ::= SEQUENCE {
sl-EventId-r16 CHOICE {
eventS1-r16 SEQUENCE {
s1-Threshold-r16 SL-MeasTriggerQuantity-r16,
sl-ReportOnLeave-r16 BOOLEAN,
sl-Hysteresis-r16 Hysteresis,
sl-TimeToTrigger-r16 TimeToTrigger,
...
},
eventS2-r16 SEQUENCE {
s2-Threshold-r16 SL-MeasTriggerQuantity-r16,
sl-ReportOnLeave-r16 BOOLEAN,
sl-Hysteresis-r16 Hysteresis,
sl-TimeToTrigger-r16 TimeToTrigger,
...
},
...
},
sl-ReportInterval-r16 ReportInterval,
sl-ReportAmount-r16 ENUMERATED {r1, r2, r4, r8, r16, r32, r64, infinity},
sl-ReportQuantity-r16 SL-MeasReportQuantity-r16,
sl-RS-Type-r16 SL-RS-Type-r16,
...
}
SL-MeasReportQuantity-r16 ::= CHOICE {
sl-RSRP-r16 BOOLEAN,
...
}
SL-MeasTriggerQuantity-r16 ::= CHOICE {
sl-RSRP-r16 RSRP-Range,
...
}
SL-RS-Type-r16 ::= ENUMERATED {dmrs, spare3, spare2, spare1}
-- TAG-SL-REPORTCONFIGLIST-STOP
```

**_SL-ReportConfig_** **field descriptions** **_sl-ReportType_** Type of the configured sidelink measurement report.

**_SL-EventTriggerConfig_** **field descriptions** **_sl-EventId_** Choice of sidelink measurement event triggered reporting criteria.

**_sl-ReportAmount_** Number of sidelink measurement reports applicable for _sl-EventTriggered_ report type.

**_sl-ReportInterval_** Indicates the interval between periodical reports (i.e., when _sl-ReportAmount_ exceeds 1) for _sl-EventTriggered_ report type.

**_sl-ReportOnLeave_** specified in 5.8.10.4.1.

indicates whether or not the UE shall initiate the sidelink measurement reporting procedure when the leaving condition is met for a frequency in _sl-FrequencyTriggeredList_, as **_sl-ReportQuantity_** The sidelink measurement quantities to be included in the sidelink measurement report.

**_sl-TimeToTrigger_** Time during which specific criteria for the event needs to be met in order to trigger a sidelink measurement report.

**_sN-Threshold_** Threshold used for events S1 and S2 specified in clauses 5.8.10.4.2 and 5.8.10.4.3, respectively.

**_SL-PeriodicalReportConfig_** **field descriptions** **_sl-ReportAmount_** Number of sidelink measurement reports applicable for _sl-Periodical_ report type.

**_sl-ReportInterval_** Indicates the interval between periodical reports (i.e., when _sl-ReportAmount_ exceeds 1) for _sl-Periodical_ report type.

**_sl-ReportQuantity_** The sidelink measurement quantities to be included in the sidelink measurement report.

##### SL-ResourcePool

The IE _SL-ResourcePool_ specifies the configuration information for NR sidelink communication resource pool.

**_SL-ResourcePool_** **information element**

```asn1
-- TAG-SL-RESOURCEPOOL-START
SL-ResourcePool-r16 ::= SEQUENCE {
sl-PSCCH-Config-r16 SetupRelease { SL-PSCCH-Config-r16 } OPTIONAL,
-- Need M
sl-PSSCH-Config-r16 SetupRelease { SL-PSSCH-Config-r16 } OPTIONAL,
-- Need M
sl-PSFCH-Config-r16 SetupRelease { SL-PSFCH-Config-r16 } OPTIONAL,
-- Need M
sl-SyncAllowed-r16 SL-SyncAllowed-r16 OPTIONAL,
-- Need M
sl-SubchannelSize-r16 ENUMERATED {n10, n12, n15, n20, n25, n50, n75, n100} OPTIONAL,
-- Need M
dummy INTEGER (10..160) OPTIONAL,
-- Need M
sl-StartRB-Subchannel-r16 INTEGER (0..265) OPTIONAL,
-- Need M
sl-NumSubchannel-r16 INTEGER (1..27) OPTIONAL,
-- Need M
sl-Additional-MCS-Table-r16 ENUMERATED {qam256, qam64LowSE, qam256-qam64LowSE } OPTIONAL,
-- Need M
sl-ThreshS-RSSI-CBR-r16 INTEGER (0..45) OPTIONAL,
-- Need M
sl-TimeWindowSizeCBR-r16 ENUMERATED {ms100, slot100} OPTIONAL,
-- Need M
sl-TimeWindowSizeCR-r16 ENUMERATED {ms1000, slot1000} OPTIONAL,
-- Need M
sl-PTRS-Config-r16 SL-PTRS-Config-r16 OPTIONAL,
-- Need M
sl-UE-SelectedConfigRP-r16 SL-UE-SelectedConfigRP-r16 OPTIONAL,
-- Need M
sl-RxParametersNcell-r16 SEQUENCE {
sl-TDD-Configuration-r16 TDD-UL-DL-ConfigCommon OPTIONAL,
-- Need M
sl-SyncConfigIndex-r16 INTEGER (0..15)
} OPTIONAL,
-- Need M
sl-ZoneConfigMCR-List-r16 SEQUENCE (SIZE (16)) OF SL-ZoneConfigMCR-r16 OPTIONAL,
-- Need M
sl-FilterCoefficient-r16 FilterCoefficient OPTIONAL,
-- Need M
sl-RB-Number-r16 INTEGER (10..275) OPTIONAL,
-- Need M
sl-PreemptionEnable-r16 ENUMERATED {enabled, pl1, pl2, pl3, pl4, pl5, pl6, pl7, pl8} OPTIONAL,
-- Need R
sl-PriorityThreshold-UL-URLLC-r16 INTEGER (1..9) OPTIONAL,
-- Need M
sl-PriorityThreshold-r16 INTEGER (1..9) OPTIONAL,
-- Need M
sl-X-Overhead-r16 ENUMERATED {n0,n3, n6, n9} OPTIONAL,
-- Need S
sl-PowerControl-r16 SL-PowerControl-r16 OPTIONAL,
-- Need M
sl-TxPercentageList-r16 SL-TxPercentageList-r16 OPTIONAL,
-- Need M
sl-MinMaxMCS-List-r16 SL-MinMaxMCS-List-r16 OPTIONAL,
-- Need M
...,
[[
sl-TimeResource-r16 BIT STRING (SIZE (10..160)) OPTIONAL -- Need M
]]
}
SL-ZoneConfigMCR-r16 ::= SEQUENCE {
sl-ZoneConfigMCR-Index-r16 INTEGER (0..15),
sl-TransRange-r16 ENUMERATED {m20, m50, m80, m100, m120, m150, m180, m200, m220, m250, m270, m300, m350,
m370, m400, m420, m450, m480, m500, m550, m600, m700, m1000, spare9, spare8,
spare7, spare6, spare5, spare4, spare3, spare2, spare1}
OPTIONAL,
-- Need M
sl-ZoneConfig-r16 SL-ZoneConfig-r16 OPTIONAL,
-- Need M
...
}
SL-SyncAllowed-r16 ::= SEQUENCE {
gnss-Sync-r16 ENUMERATED {true} OPTIONAL,
-- Need R
gnbEnb-Sync-r16 ENUMERATED {true} OPTIONAL,
-- Need R
ue-Sync-r16 ENUMERATED {true} OPTIONAL -- Need R
}
SL-PSCCH-Config-r16 ::= SEQUENCE {
sl-TimeResourcePSCCH-r16 ENUMERATED {n2, n3} OPTIONAL,
-- Need M
sl-FreqResourcePSCCH-r16 ENUMERATED {n10,n12, n15, n20, n25} OPTIONAL,
-- Need M
sl-DMRS-ScrambleID-r16 INTEGER (0..65535) OPTIONAL,
-- Need M
sl-NumReservedBits-r16 INTEGER (2..4) OPTIONAL,
-- Need M
...
}
SL-PSSCH-Config-r16 ::= SEQUENCE {
sl-PSSCH-DMRS-TimePatternList-r16 SEQUENCE (SIZE (1..3)) OF INTEGER (2..4) OPTIONAL,
-- Need M
sl-BetaOffsets2ndSCI-r16 SEQUENCE (SIZE (4)) OF SL-BetaOffsets-r16 OPTIONAL,
-- Need M
sl-Scaling-r16 ENUMERATED {f0p5, f0p65, f0p8, f1} OPTIONAL,
-- Need M
...
}
SL-PSFCH-Config-r16 ::= SEQUENCE {
sl-PSFCH-Period-r16 ENUMERATED {sl0, sl1, sl2, sl4} OPTIONAL,
-- Need M
sl-PSFCH-RB-Set-r16 BIT STRING (SIZE (10..275)) OPTIONAL,
-- Need M
sl-NumMuxCS-Pair-r16 ENUMERATED {n1, n2, n3, n6} OPTIONAL,
-- Need M
sl-MinTimeGapPSFCH-r16 ENUMERATED {sl2, sl3} OPTIONAL,
-- Need M
sl-PSFCH-HopID-r16 INTEGER (0..1023) OPTIONAL,
-- Need M
sl-PSFCH-CandidateResourceType-r16 ENUMERATED {startSubCH, allocSubCH} OPTIONAL,
-- Need M
...
}
SL-PTRS-Config-r16 ::= SEQUENCE {
sl-PTRS-FreqDensity-r16 SEQUENCE (SIZE (2)) OF INTEGER (1..276) OPTIONAL,
-- Need M
sl-PTRS-TimeDensity-r16 SEQUENCE (SIZE (3)) OF INTEGER (0..29) OPTIONAL,
-- Need M
sl-PTRS-RE-Offset-r16 ENUMERATED {offset01, offset10, offset11} OPTIONAL,
-- Need M
...
}
SL-UE-SelectedConfigRP-r16 ::= SEQUENCE {
sl-CBR-PriorityTxConfigList-r16 SL-CBR-PriorityTxConfigList-r16 OPTIONAL,
-- Need M
sl-Thres-RSRP-List-r16 SL-Thres-RSRP-List-r16 OPTIONAL,
-- Need M
sl-MultiReserveResource-r16 ENUMERATED {enabled} OPTIONAL,
-- Need M
sl-MaxNumPerReserve-r16 ENUMERATED {n2, n3} OPTIONAL,
-- Need M
sl-SensingWindow-r16 ENUMERATED {ms100, ms1100} OPTIONAL,
-- Need M
sl-SelectionWindowList-r16 SL-SelectionWindowList-r16 OPTIONAL,
-- Need M
sl-ResourceReservePeriodList-r16 SEQUENCE (SIZE (1..16)) OF SL-ResourceReservePeriod-r16 OPTIONAL,
-- Need M
sl-RS-ForSensing-r16 ENUMERATED {pscch, pssch},
...,
[[
sl-CBR-PriorityTxConfigList-v1650 SL-CBR-PriorityTxConfigList-v1650 OPTIONAL -- Need M
]]
}
SL-ResourceReservePeriod-r16 ::= CHOICE {
sl-ResourceReservePeriod1-r16 ENUMERATED {ms0, ms100, ms200, ms300, ms400, ms500, ms600, ms700, ms800, ms900, ms1000},
sl-ResourceReservePeriod2-r16 INTEGER (1..99)
}
SL-SelectionWindowList-r16 ::= SEQUENCE (SIZE (8)) OF SL-SelectionWindowConfig-r16
SL-SelectionWindowConfig-r16 ::= SEQUENCE {
sl-Priority-r16 INTEGER (1..8),
sl-SelectionWindow-r16 ENUMERATED {n1, n5, n10, n20}
}
SL-TxPercentageList-r16 ::= SEQUENCE (SIZE (8)) OF SL-TxPercentageConfig-r16
SL-TxPercentageConfig-r16 ::= SEQUENCE {
sl-Priority-r16 INTEGER (1..8),
sl-TxPercentage-r16 ENUMERATED {p20, p35, p50}
}
SL-MinMaxMCS-List-r16 ::= SEQUENCE (SIZE (1..3)) OF SL-MinMaxMCS-Config-r16
SL-MinMaxMCS-Config-r16 ::= SEQUENCE {
sl-MCS-Table-r16 ENUMERATED {qam64, qam256, qam64LowSE},
sl-MinMCS-PSSCH-r16 INTEGER (0..27),
sl-MaxMCS-PSSCH-r16 INTEGER (0..31)
}
SL-BetaOffsets-r16 ::= INTEGER (0..31)
SL-PowerControl-r16 ::= SEQUENCE {
sl-MaxTransPower-r16 INTEGER (-30..33),
sl-Alpha-PSSCH-PSCCH-r16 ENUMERATED {alpha0, alpha04, alpha05, alpha06, alpha07, alpha08, alpha09, alpha1} OPTIONAL,
-- Need M
dl-Alpha-PSSCH-PSCCH-r16 ENUMERATED {alpha0, alpha04, alpha05, alpha06, alpha07, alpha08, alpha09, alpha1} OPTIONAL,
-- Need S
sl-P0-PSSCH-PSCCH-r16 INTEGER (-16..15) OPTIONAL,
-- Need S
dl-P0-PSSCH-PSCCH-r16 INTEGER (-16..15) OPTIONAL,
-- Need M
dl-Alpha-PSFCH-r16 ENUMERATED {alpha0, alpha04, alpha05, alpha06, alpha07, alpha08, alpha09, alpha1} OPTIONAL,
-- Need S
dl-P0-PSFCH-r16 INTEGER (-16..15) OPTIONAL,
-- Need M
...
}
-- TAG-SL-RESOURCEPOOL-STOP
```

**_SL-ZoneConfigMCR_** **field descriptions** **_sl-TransRange_** Indicates the communication range requirement for the corresponding _sl-ZoneConfigMCR-Index_.

**_sl-ZoneConfig_** Indicates the zone configuration for the corresponding _sl-ZoneConfigMCR-Index_.

**_sl-ZoneConfigMCR-Index_** Indicates the codepoint of the communication range requirement field in SCI.

**_SL-ResourcePool_** **field descriptions** **_dummy_** This field is not used in the specification. If received it shall be ignored by the UE.

**_sl-FilterCoefficient_** This field indicates the filtering coefficient for long-term measurement and reference signal power derivation used for sidelink open-loop power control.

**_sl-Additional-MCS-Table_** Indicates the MCS table(s) additionally used in the resource pool. 64QAM table is (pre-)configured as default. Zero, one or two can be additionally (pre-)configured using the 256QAM and/or low-SE MCS tables. If two MCS tables are indicated, 256QAM MCS table is the 1st table and qam64lowSE MCS table is the 2nd table as specified in TS 38.214 [19], clause 8.1.3.1.

**_sl-NumSubchannel_** Indicates the number of subchannels in the corresponding resource pool, which consists of contiguous PRBs only.

**_sl-PreemptionEnable_** Indicates whether pre-emption is disabled or enabled in a resource pool. If the field is present and the value is _pl1_, _pl2_, and so on (but not _enabled_), it means that pre-emption is enabled and a priority level p_preemption is configured. If the field is present and the value is _enabled_, the pre-emption is enabled (but p_preemption is not configured) and pre-emption is applicable to all levels.

**_sl-PriorityThreshold-UL-URLLC_** Indicates the threshold used to determine whether NR sidelink transmission is prioritized over uplink transmission of priority index 1 as specified in TS 38.213[13], clause 16.2.4.3, or whether PUCCH transmission carrying SL HARQ is prioritized over PUCCH transmission carrying UCI of priority index 1 if they overlap in time as specified in TS 38.213 [13], clause 9.2.5.0.

**_sl-PriorityThreshold_** Indicates the threshold used to determine whether NR sidelink transmission is prioritized over uplink transmission of priority index 0 as specified in TS 38.213[13], clause 16.2.4.3, or whether PUCCH transmission carrying SL HARQ is prioritized over PUCCH transmission carrying UCI of priority index 0 if they overlap in time as specified in TS 38.213 [13], clause 9.2.5.0.

**_sl-RB-Number_** Indicates the number of PRBs in the corresponding resource pool, which consists of contiguous PRBs only. The remaining RB cannot be used (See TS 38.214[19], clause 8).

**_sl-StartRB-Subchannel_** Indicates the lowest RB index of the subchannel with the lowest index in the resource pool with respect to the lowest RB index of a SL BWP.

**_sl-SubchannelSize_** Indicates the minimum granularity in frequency domain for the sensing for PSSCH resource selection in the unit of PRB.

**_sl-SyncAllowed_** Indicates the allowed synchronization reference(s) which is (are) allowed to use the configured resource pool.

**_sl-SyncConfigIndex_** sidelink communication.

Indicates the synchronisation configuration that is associated with a reception pool, by means of an index to the corresponding entry _SL-SyncConfigList_ of in _SIB12_ for NR **_sl-TDD-Configuration_** Indicates the TDD configuration associated with the reception pool of the cell indicated by _sl-SyncConfigIndex_.

**_sl-ThreshS-RSSI-CBR_** (-112 + n*2) dBm, and so on.

Indicates the S-RSSI threshold for determining the contribution of a sub-channel to the CBR measurement. Value 0 corresponds to -112 dBm, value 1 to -110 dBm, value n to **_sl-TimeResource_** Indicates the bitmap of the resource pool, which is defined by repeating the bitmap with a periodicity during a SFN or DFN cycle.

**_sl-TimeWindowSizeCBR_** Indicates the time window size for CBR measurement.

**_sl-TimeWindowSizeCR_** Indicates the time window size for CR evaluation.

**_sl-TxPercentageList_** Indicates the portion of candidate single-slot PSSCH resources over the total resources. Value p20 corresponds to 20%, and so on.

**_sl-X-Overhead_** Accounts for overhead from CSI-RS, PT-RS. If the field is absent, the UE applies value _n0_ (see TS 38.214 [19], clause 8.1.3.2).

**_SL-SyncAllowed_** **field descriptions** **_gnbEnb-Sync_** synchronized to eNB or gNB).

If configured, the (pre-) configured resources can be used if the UE is directly or indirectly synchronized to eNB or gNB (i.e., synchronized to a reference UE which is directly **_gnss-Sync_** synchronized to GNSS).

If configured, the (pre-) configured resources can be used if the UE is directly or indirectly synchronized to GNSS (i.e., synchronized to a reference UE which is directly **_ue-Sync_** If configured, the (pre-) configured resources can be used if the UE is synchronized to a reference UE which is not synchronized to eNB, gNB and GNSS directly or indirectly.

**_SL-PSCCH-Config_** **field descriptions** **_sl-FreqResourcePSCCH_** Indicates the number of PRBs for PSCCH in a resource pool where it is not greater than the number PRBs of the subchannel.

**_sl-DMRS-ScrambleID_** Indicates the initialization value for PSCCH DMRS scrambling.

**_sl-NumReservedBits_** Indicates the number of reserved bits in first stage SCI.

**_sl-TimeResourcePSCCH_** Indicates the number of symbols of PSCCH in a resource pool.

**_SL-PSSCH-Config_** **field descriptions** **_sl-BetaOffsets2ndSCI_** 38.213 [13].

Indicates candidates of beta-offset values to determine the number of coded modulation symbols for second stage SCI. The value indicates the index of Table 9.3-2 of TS **_sl-PSSCH-DMRS-TimePatternList_** Indicates the set of PSSCH DMRS time domain patterns in terms of PSSCH DMRS symbols in a slot that can be used in the resource pool.

**_sl-Scaling_** 0.65, and so on.

Indicates a scaling factor to limit the number of resource elements assigned to the second stage SCI on PSSCH. Value _f0p5_ corresponds to 0.5, value _f0p65_ corresponds to **_SL-PSFCH-Config_** **field descriptions** **_sl-MinTimeGapPSFCH_** The minimum time gap between PSFCH and the associated PSSCH in the unit of slots.

**_sl-NumMuxCS-Pair_** Indicates the number of cyclic shift pairs used for a PSFCH transmission that can be multiplexed in a PRB.

**_sl-PSFCH-CandidateResourceType_** Indicates the number of PSFCH resources available for multiplexing HARQ-ACK information in a PSFCH transmission (see TS 38.213 [13], clause 16.3).

**_sl-PSFCH-HopID_** Scrambling ID for sequence hopping of the PSFCH used in the resource pool.

**_sl-PSFCH-Period_** resource pool is disabled.

Indicates the period of PSFCH resource in the unit of slots within this resource pool. If set to _sl0_, no resource for PSFCH, and HARQ feedback for all transmissions in the **_sl-PSFCH-RB-Set_** Indicates the set of PRBs that are actually used for PSFCH transmission and reception. The leftmost bit of the bitmap refers to the lowest RB index in the resource pool, and so on. Value 0 in the bitmap indicates that the corresponding PRB is not used for PSFCH transmission and reception while value 1 indicates that the corresponding PRB is used for PSFCH transmission and reception (see TS 38.213 [13]).

**_SL-PTRS-Config_** **field descriptions** **_sl-PTRS-FreqDensity_** Presence and frequency density of SL PT-RS as a function of scheduled BW. If the field is not configured, the UE uses K_PT-RS = 2 **_sl-PTRS-TimeDensity_** Presence and time density of SL PT-RS as a function of MCS. If the field is not configured, the UE uses L_PT-RS = 1 **_sl-PTRS-RE-Offset_** Indicates the subcarrier offset for SL PT-RS. If the field is not configured, the UE applies the value _offset00_ (see TS 38.211 [16], clause 8.4.1.2.2).

**_SL-UE-SelectedConfigRP_** **field descriptions** **_sl-CBR-PriorityTxConfigList_** Indicates the mapping between PSSCH transmission parameter (such as MCS, PRB number, retransmission number, CR limit) sets by using the indexes of the configurations in _sl-CBR-PSSCH-TxConfigList_, CBR ranges by using the indexes to the entry of the CBR range configurations in _sl-CBR-RangeConfigList_, and priority ranges. It also indicates the default PSSCH transmission parameters to be used when CBR measurement results are not available, and MCS range for the MCS tables used in the resource pool. The field _sl-CBR-PriorityTxConfigList-v1650_ is present only when _sl-CBR-PriorityTxConfigList-r16_ is configured.

**_sl-MaxNumPerReserve_** Indicates the maximum number of reserved PSCCH/PSSCH resources that can be indicated by an SCI.

**_sl-MultiReserveResource_** procedure.

Indicates if it is allowed to reserve a sidelink resource for an initial transmission of a TB by an SCI associated with a different TB, based on sensing and resource selection **_sl-ResourceReservePeriodList_** configured.

Set of possible resource reservation period allowed in the resource pool in the unit of ms. Up to 16 values can be configured per resource pool. The value _ms0_ is always **_sl-RS-ForSensing_** Indicates whether DMRS of PSCCH or PSSCH is used for L1 RSRP measurement in the sensing operation.

**_sl-SensingWindow_** Parameter that indicates the start of the sensing window.

**_sl-SelectionWindowList_** Parameter that determines the end of the selection window in the resource selection for a TB with respect to priority indicated in SCI. Value n1 corresponds to 1*2µ, value n5 corresponds to 5*2µ, and so on, where µ = 0,1,2,3 refers to SCS 15,30,60,120 kHz respectively.

**_sl-Thres-RSRP-List_** Indicates a list of 64 thresholds, and the threshold should be selected based on the priority in the decoded SCI and the priority in the SCI to be transmitted. A resource is excluded if it is indicated or reserved by a decoded SCI and PSSCH/PSCCH RSRP in the associated data resource is above a threshold.

**_SL-PowerControl_** **field descriptions** **_sl-MaxTransPower_** Indicates the maximum value of the UE's sidelink transmission power on this resource pool when the sidelink transmission is performed only on this resource pool. The unit is dBm. If the sidelink transmission is PSFCH, and multiple resource pools are used, the maximum transmission power for PSFCH is configured as sum of fields _sl-maxTransPower_ over multiple resource pools, as specified in TS 38.101-1 [15].

**_sl-Alpha-PSSCH-PSCCH_** value 1.

Indicates alpha value for sidelink pathloss based power control for PSCCH/PSSCH when _sl-P0-PSSCH-PSCCH_ is configured. When the field is absent the UE applies the **_sl-P0-PSSCH-PSCCH_** Indicates P0 value for sidelink pathloss based power control for PSCCH/PSSCH. If not configured, sidelink pathloss based power control is disabled for PSCCH/PSSCH.

**_dl-Alpha-PSSCH-PSCCH_** value 1.

Indicates alpha value for downlink pathloss based power control for PSCCH/PSSCH when _dl-P0-PSSCH-PSCCH_ is configured. When the field is absent the UE applies the **_dl-P0-PSSCH-PSCCH_** Indicates P0 value for downlink pathloss based power control for PSCCH/PSSCH. If not configured, downlink pathloss based power control is disabled for PSCCH/PSSCH.

**_dl-Alpha-PSFCH_** Indicates alpha value for downlink pathloss based power control for PSFCH when _dl-P0-PSFCH_ is configured. When the field is absent the UE applies the value 1. For resource pools configured with PSFCH resources overlapping in time, this field is either not configured in any of the resource pools or configured with the same value for all the resource pools.

**_dl-P0-PSFCH_** Indicates P0 value for downlink pathloss based power control for PSFCH. If not configured, downlink pathloss based power control is disabled for PSFCH. For resource pools configured with PSFCH resources overlapping in time, this field is either not configured in any of the resource pools or configured with the same value for all the resource pools.

**_SL-MinMaxMCS-Config_** **field descriptions** **_sl-MaxMCS-PSSCH_** Indicates the maximum MCS value when using the associated MCS table. If no MCS is configured, UE autonomously selects MCS from the full range of values.

**_sl-MinMCS-PSSCH_** Indicates the minimum MCS value when using the associated MCS table. If no MCS is configured, UE autonomously selects MCS from the full range of values.

##### SL-RLC-BearerConfig

The IE _SL-RLC-BearerConfig_ specifies the SL RLC bearer configuration information for NR sidelink communication.

**_SL-RLC-BearerConfig_** **information element**

```asn1
-- TAG-SL-RLC-BEARERCONFIG-START
SL-RLC-BearerConfig-r16 ::= SEQUENCE {
sl-RLC-BearerConfigIndex-r16 SL-RLC-BearerConfigIndex-r16,
sl-ServedRadioBearer-r16 SLRB-Uu-ConfigIndex-r16 OPTIONAL,
-- Cond LCH-SetupOnly
sl-RLC-Config-r16 SL-RLC-Config-r16 OPTIONAL,
-- Cond LCH-Setup
sl-MAC-LogicalChannelConfig-r16 SL-LogicalChannelConfig-r16 OPTIONAL,
-- Cond LCH-Setup
...
}
-- TAG-SL-RLC-BEARERCONFIG-STOP
```

**_SL-RLC-BearerConfig_** **field descriptions** **_sl-MAC-LogicalChannelConfig_** The field is used to configure MAC SL logical channel paramenters.

**_sl-RLC-BearerConfigIndex_** The index of the RLC bearer configuration.

**_sl-RLC-Config_** Determines the RLC mode (UM, AM) and provides corresponding parameters.

**_sl-ServedRadioBearer_** Associates the sidelink RLC Bearer with a sidelink DRB. It indicates the index of SL radio bearer configuration, which is corresponding to the RLC bearer configuration.

**Conditional Presence** **Explanation** _LCH-Setup_ The field is mandatory present upon creation of a new sidelink logical channel via the dedicated signalling and in case of sidelink DRB configuration via system information and pre-configuration; otherwise the field is optionally present, Need M.

_LCH-SetupOnly_ This field is mandatory present upon creation of a new sidelink logical channel via the dedicated signalling and in case of sidelink DRB configuration via system information and pre-configuration. Otherwise, it is absent, Need M.

##### SL-RLC-BearerConfigIndex

The IE _SL-RLC-BearerConfigIndex_ is used to identify a SL RLC bearer configuration.

**_SL-RLC-BearerConfigIndex_** **information element**

```asn1
-- TAG-SL-RLC-BEARERCONFIGINDEX-START
SL-RLC-BearerConfigIndex-r16 ::= INTEGER (1..maxSL-LCID-r16)
-- TAG-RLC-BEARERCONFIGINDEX-STOP
```

##### SL-RLC-Config

The IE _SL-RLC-Config_ is used to specify the RLC configuration of sidelink DRB. RLC AM configuration is only applicable to the unicast NR sidelink communication.

**_SL-RLC-Config_** **information element**

```asn1
-- TAG-SL-RLC-CONFIG-START
SL-RLC-Config-r16 ::= CHOICE {
sl-AM-RLC-r16 SEQUENCE {
sl-SN-FieldLengthAM-r16 SN-FieldLengthAM OPTIONAL,
-- Cond SLRBSetup
sl-T-PollRetransmit-r16 T-PollRetransmit,
sl-PollPDU-r16 PollPDU,
sl-PollByte-r16 PollByte,
sl-MaxRetxThreshold-r16 ENUMERATED { t1, t2, t3, t4, t6, t8, t16, t32 },
...
},
sl-UM-RLC-r16 SEQUENCE {
sl-SN-FieldLengthUM-r16 SN-FieldLengthUM OPTIONAL,
-- Cond SLRBSetup
...
},
...
}
-- TAG-SL-RLC-CONFIG-STOP
```

**_SL-RLC-Config_** **field descriptions** **_sl-MaxRetxThreshold_** retransmissions and so on.

Parameter value of _maxRetxThreshold_ for RLC AM for NR sidelink communications, see TS 38.322 [4]. Value _t1_ corresponds to 1 retransmission, value _t2_ corresponds to 2 **_sl-PollByte_** Parameter value of _pollByte_ for RLC AM for NR sidelink communications, see TS 38.322 [4]. Value _kB25_ corresponds to 25 kBytes, value _kB50_ corresponds to 50 kBytes and so on. _infinity_ corresponds to an infinite amount of kBytes.

**_sl-PollPDU_** Parameter value of _pollPDU_ for RLC AM for NR sidelink communications, seeTS 38.322 [4]. Value _p4_ corresponds to 4 PDUs, value _p8_ corresponds to 8 PDUs and so on.

_infinity_ corresponds to an infinite number of PDUs.

**_sl-SN-FieldLength_** _SN-FieldLengthUM_.

This field indicates the RLC SN field size for NR sidelink communication, see TS 38.322 [4]. For groupcast and broadcast, only value _size6_ (6 bits) is configured for the field _sl-_ **_sl-T-PollRetransmit_** Timer value of _t-PollRetransmit_ for RLC AM for NR sidelink communications, see TS 38.322 [4], in milliseconds. Value _ms5_ means 5 ms, value _ms10_ means 10 ms and so on.

**Conditional Presence** **Explanation** _SLRBSetup_ The field is mandatory present in case of sidelink DRB setup via the dedicated signalling and in case of sidelink DRB configuration via system information and pre-configuration; otherwise the field is optionally present, need M.

##### SL-ScheduledConfig

The IE _SL-ScheduledConfig_ specifies sidelink communication configurations used for network scheduled NR sidelink communication.

**_SL-ScheduledConfig_** **information element**

```asn1
-- TAG-SL-SCHEDULEDCONFIG-START
SL-ScheduledConfig-r16 ::= SEQUENCE {
sl-RNTI-r16 RNTI-Value,
mac-MainConfigSL-r16 MAC-MainConfigSL-r16 OPTIONAL,
-- Need M
sl-CS-RNTI-r16 RNTI-Value OPTIONAL,
-- Need M
sl-PSFCH-ToPUCCH-r16 SEQUENCE (SIZE (1..8)) OF INTEGER (0..15) OPTIONAL,
-- Need M
sl-ConfiguredGrantConfigList-r16 SL-ConfiguredGrantConfigList-r16 OPTIONAL,
-- Need M
...,
[[
sl-DCI-ToSL-Trans-r16 SEQUENCE (SIZE (1..8)) OF INTEGER (1..32) OPTIONAL -- Need M
]]
}
MAC-MainConfigSL-r16 ::= SEQUENCE {
sl-BSR-Config-r16 BSR-Config OPTIONAL,
-- Need M
ul-PrioritizationThres-r16 INTEGER (1..16) OPTIONAL,
-- Need M
sl-PrioritizationThres-r16 INTEGER (1..8) OPTIONAL,
-- Need M
...
}
SL-ConfiguredGrantConfigList-r16 ::= SEQUENCE {
sl-ConfiguredGrantConfigToReleaseList-r16 SEQUENCE (SIZE (1..maxNrofCG-SL-r16)) OF SL-ConfigIndexCG-r16 OPTIONAL,
-- Need N
sl-ConfiguredGrantConfigToAddModList-r16 SEQUENCE (SIZE (1..maxNrofCG-SL-r16)) OF SL-ConfiguredGrantConfig-r16 OPTIONAL -- Need N
}
-- TAG-SL-SCHEDULEDCONFIG-STOP
```

**_SL-ScheduledConfig_** **field descriptions** **_sl-CS-RNTI_** Indicate the RNTI used to scramble CRC of DCI format 3_0, see TS 38.321 [3].

**_sl-DCI-ToSL-Trans_** Indicate the time gap between DCI reception and the first sidelink transmission scheduled by the DCI (see TS 38.214 [19], clause 8.1.2.1). Value 1 included in this field corresponds to 1 slot, value 2 corresponds to 2 slots and so on, based on the numerology of sidelink BWP.

**_sl-PSFCH-ToPUCCH_** For dynamic grant and configured grant type 2, this field configures the values (in number of slot lengths) of the PSFCH to PUCCH gap. The field PSFCH-to-HARQ_feedback timing indicator in DCI format 3_0 selects one of the configured values of the PSFCH to PUCCH gap.

**_sl-RNTI_** Indicate the SL-RNTI used for monitoring the network scheduling to transmit NR sidelink communication (i.e. the mode 1).

**_MAC-MainConfigSL_** **field descriptions** **_sl-BSR-Config_** This field is to configure the sidelink buffer status report.

**_sl-PrioritizationThres_** Indicates the SL priority threshold, which is used to determine whether SL TX is prioritized over UL TX, as specified in TS 38.321 [3]. Network does not configure the _sl-PrioritizationThres_ and the _ul-PrioritizationThres_ to the UE separately.

**_ul-PrioritizationThres_** Indicates the UL priority threshold, which is used to determine whether SL TX is prioritized over UL TX, as specified in TS 38.321 [3]. Network does not configure the _sl-PrioritizationThres_ and the _ul-PrioritizationThres_ to the UE separately.

##### SL-SDAP-Config

The IE _SL-SDAP-Config_ is used to set the configurable SDAP parameters for a Sidelink DRB.

**_SL-SDAP-Config_** **information element**

```asn1
-- TAG-SL-SDAP-CONFIG-START
SL-SDAP-Config-r16 ::= SEQUENCE {
sl-SDAP-Header-r16 ENUMERATED {present, absent},
sl-DefaultRB-r16 BOOLEAN,
sl-MappedQoS-Flows-r16 CHOICE {
sl-MappedQoS-FlowsList-r16 SEQUENCE (SIZE (1..maxNrofSL-QFIs-r16)) OF SL-QoS-Profile-r16,
sl-MappedQoS-FlowsListDedicated-r16 SL-MappedQoS-FlowsListDedicated-r16
} OPTIONAL,
-- Need M
sl-CastType-r16 ENUMERATED {broadcast, groupcast, unicast, spare1} OPTIONAL,
-- Need M
...
}
SL-MappedQoS-FlowsListDedicated-r16 ::= SEQUENCE {
sl-MappedQoS-FlowsToAddList-r16 SEQUENCE (SIZE (1..maxNrofSL-QFIs-r16)) OF SL-QoS-FlowIdentity-r16 OPTIONAL,
-- Need N
sl-MappedQoS-FlowsToReleaseList-r16 SEQUENCE (SIZE (1..maxNrofSL-QFIs-r16)) OF SL-QoS-FlowIdentity-r16 OPTIONAL -- Need N
}
-- TAG-SL-SDAP-CONFIG-STOP
```

**_SL-SDAP-Config_** **field descriptions** **_sl-DefaultRB_** Indicates whether or not this is the default sidelink DRB for this NR sidelink communication transmission destination. Among all configured instances of _SL-SDAP-Config_ for this destination, this field shall be set to _true_ in at most one instance of _SL-SDAP-Config_ and to _false_ in all other instances.

**_sl-MappedQoS-Flows_** _MappedQoS-FlowsList_.

Indicates QoS flows to be mapped to the sidelink DRB. If the field is included in dedicated signalling, it is set to _sl-MappedQoS-FlowsListDedicated_; otherwise, it is set to _sl-_ **_sl-MappedQoS-FlowsList_** Indicates the list of QoS profiles of the NR sidelink communication transmission destination mapped to this sidelink DRB.

**_sl-MappedQoS-FlowsToAddList_** Indicates the list of SL QoS flows ID of the NR sidelink communication transmission destination to be additionally mapped to this sidelink DRB.

**_sl-MappedQoS-FlowsToReleaseList_** Indicates the list of SL QoS flows ID of the NR sidelink communication transmission destination to be released from existing QoS flow to SLRB mapping of this sidelink DRB.

**_sl-SDAP-Header_** _sl-DefaultRB_ is set to _true_.

Indicates whether or not a SDAP header is present on this sidelink DRB. The field cannot be changed after a sidelink DRB is established. This field is set to present if the field

##### SL-SyncConfig

The IE _SL-SyncConfig_ specifies the configuration information concerning reception of synchronisation signals from neighbouring cells as well as concerning the transmission of synchronisation signals for sidelink communication.

**_SL-SyncConfig_** **information element**

```asn1
-- TAG-SL-SYNCCONFIG-START
SL-SyncConfigList-r16 ::= SEQUENCE (SIZE (1..maxSL-SyncConfig-r16)) OF SL-SyncConfig-r16
SL-SyncConfig-r16 ::= SEQUENCE {
sl-SyncRefMinHyst-r16 ENUMERATED {dB0, dB3, dB6, dB9, dB12} OPTIONAL,
-- Need R
sl-SyncRefDiffHyst-r16 ENUMERATED {dB0, dB3, dB6, dB9, dB12, dBinf} OPTIONAL,
-- Need R
sl-FilterCoefficient-r16 FilterCoefficient OPTIONAL,
-- Need R
sl-SSB-TimeAllocation1-r16 SL-SSB-TimeAllocation-r16 OPTIONAL,
-- Need R
sl-SSB-TimeAllocation2-r16 SL-SSB-TimeAllocation-r16 OPTIONAL,
-- Need R
sl-SSB-TimeAllocation3-r16 SL-SSB-TimeAllocation-r16 OPTIONAL,
-- Need R
sl-SSID-r16 INTEGER (0..671) OPTIONAL,
-- Need R
txParameters-r16 SEQUENCE {
syncTxThreshIC-r16 SL-RSRP-Range-r16 OPTIONAL,
-- Need R
syncTxThreshOoC-r16 SL-RSRP-Range-r16 OPTIONAL,
-- Need R
syncInfoReserved-r16 BIT STRING (SIZE (2)) OPTIONAL -- Need R
},
gnss-Sync-r16 ENUMERATED {true} OPTIONAL,
-- Need R
...
}
SL-RSRP-Range-r16 ::= INTEGER (0..13)
SL-SSB-TimeAllocation-r16 ::= SEQUENCE {
sl-NumSSB-WithinPeriod-r16 ENUMERATED {n1, n2, n4, n8, n16, n32, n64} OPTIONAL,
-- Need R
sl-TimeOffsetSSB-r16 INTEGER (0..1279) OPTIONAL,
-- Need R
sl-TimeInterval-r16 INTEGER (0..639) OPTIONAL -- Need R
}
-- TAG-SL-SYNCCONFIG-STOP
```

**_SL-SyncConfig_** **field descriptions** **_gnss-Sync_** If configured, the synchronization configuration is used for SLSS transmission/reception when the UE is synchronized to GNSS. If not configured, the synchronization configuration is used for SLSS transmission/reception when the UE is synchronized to eNB/gNB.

**_sl-SyncRefMinHyst_** Hysteresis when evaluating a SyncRef UE using absolute comparison.

**_sl-SyncRefDiffHyst_** Hysteresis when evaluating a SyncRef UE using relative comparison.

**_sl-NumSSB-WithinPeriod_** FR1, SCS = 15 kHz: 1 FR1, SCS = 30 kHz: 1, 2 FR1, SCS = 60 kHz: 1, 2, 4 FR2, SCS = 60 kHz: 1, 2, 4, 8, 16, 32 FR2, SCS = 120 kHz: 1, 2, 4, 8, 16, 32, 64 Indicates the number of sidelink SSB transmissions within one sidelink SSB period. The applicable values are related to the subcarrier spacing and frequency as follows:

**_sl-TimeOffsetSSB_** Indicates the slot offset from the start of sidelink SSB period to the first sidelink SSB.

**_sl-TimeInterval_** Indicates the slot interval between neighboring sidelink SSBs. This value is applicable when there are more than one sidelink SSBs within one sidelink SSB period.

**_sl-SSID_** Indicates the ID of sidelink synchronization signal associated with different synchronization priorities.

**_syncInfoReserved_** Reserved for future use.

**_syncTxThreshIC, syncTxThreshOoC_** Indicates the thresholds used while in coverage and out of coverage, respectively. Value 0 corresponds to -infinity, value 1 to -115 dBm, value 2 to -110 dBm, and so on (i.e. in steps of 5 dBm) until value 12, which corresponds to -60 dBm, while value 13 corresponds to +infinity.

##### SL-Thres-RSRP-List

IE _SL-Thres-RSRP-List_ indicates a threshold used for sensing based UE autonomous resource selection (see TS 38.215 [9]). A resource is excluded if it is indicated or reserved by a decoded SCI and PSSCH/PSCCH RSRP in the associated data resource is above the threshold defined by IE _SL-Thres-RSRP-List_. Value 0 corresponds to minus infinity dBm, value 1 corresponds to -128dBm, value 2 corresponds to -126dBm, value n corresponds to (-128 + (n-1)*2) dBm and so on, value 66 corresponds to infinity dBm.

**_SL-Thres-RSRP-List_** **information element**

```asn1
-- TAG-SL-THRES-RSRP-LIST-START
SL-Thres-RSRP-List-r16 ::= SEQUENCE (SIZE (64)) OF SL-Thres-RSRP-r16
SL-Thres-RSRP-r16 ::= INTEGER (0..66)
-- TAG-SL-THRES-RSRP-LIST-STOP
```

##### SL-TxPower

The IE _SL-TxPower_ is used to limit the UE's sidelink transmission power on a carrier frequency. The unit is dBm. Value minusinfinity corresponds to –infinity.

**_SL-TxPower_** **information element**

```asn1
-- TAG-SL-TXPOWER-START
SL-TxPower-r16 ::= CHOICE{
minusinfinity-r16 NULL,
txPower-r16 INTEGER (-30..33)
}
-- TAG-SL-TXPOWER-STOP
```

##### SL-TypeTxSync

The IE _SL-TypeTxSync_ indicates the synchronization reference type.

**_SL-TypeTxSync_** **information element**

```asn1
-- TAG-SL-TYPETXSYNC-START
SL-TypeTxSync-r16 ::= ENUMERATED {gnss, gnbEnb, ue}
-- TAG-SL-TYPETXSYNC-STOP
```

##### SL-UE-SelectedConfig

IE _SL-UE-SelectedConfig_ specifies sidelink communication configurations used for UE autonomous resource selection.

**_SL-UE-SelectedConfig_** **information element**

```asn1
-- TAG-SL-UE-SELECTEDCONFIG-START
SL-UE-SelectedConfig-r16 ::= SEQUENCE {
sl-PSSCH-TxConfigList-r16 SL-PSSCH-TxConfigList-r16 OPTIONAL,
-- Need R
sl-ProbResourceKeep-r16 ENUMERATED {v0, v0dot2, v0dot4, v0dot6, v0dot8} OPTIONAL,
-- Need R
sl-ReselectAfter-r16 ENUMERATED {n1, n2, n3, n4, n5, n6, n7, n8, n9} OPTIONAL,
-- Need R
sl-CBR-CommonTxConfigList-r16 SL-CBR-CommonTxConfigList-r16 OPTIONAL,
-- Need R
ul-PrioritizationThres-r16 INTEGER (1..16) OPTIONAL,
-- Need R
sl-PrioritizationThres-r16 INTEGER (1..8) OPTIONAL,
-- Need R
...
}
-- TAG-SL-UE-SELECTEDCONFIG-STOP
```

**_SL-UE-SelectedConfig_** **field descriptions** **_sl-PrioritizationThres_** Indicates the SL priority threshold, which is used to determine whether SL TX is prioritized over UL TX, as specified in TS 38.321 [3]. Network does not configure the _sl-PrioritizationThres_ and the _ul-PrioritizationThres_ to the UE separately.

**_sl-ProbResourceKeep_** selection (see TS 38.321 [3]).

Indicates the probability with which the UE keeps the current resource when the resource reselection counter reaches zero for sensing based UE autonomous resource **_sl-PSSCH-TxConfigList_** Indicates PSSCH TX parameters such as MCS, sub-channel number, retransmission number, associated to different UE absolute speeds and different synchronization reference types for UE autonomous resource selection.

**_sl-ReselectAfter_** Indicates the number of consecutive skipped transmissions before triggering resource reselection for sidelink communication (see TS 38.321 [3]).

**_ul-PrioritizationThres_** Indicates the UL priority threshold, which is used to determine whether SL TX is prioritized over UL TX, as specified in TS 38.321 [3]. Network does not configure the _sl-PrioritizationThres_ and the _ul-PrioritizationThres_ to the UE separately.

##### SL-ZoneConfig

The IE _SL-ZoneConfig_ is used to configure the zone ID related parameters.

**_SL-ZoneConfig_** **information element**

```asn1
-- TAG-SL-ZONECONFIG-START
SL-ZoneConfig-r16 ::= SEQUENCE {
sl-ZoneLength-r16 ENUMERATED { m5, m10, m20, m30, m40, m50, spare2, spare1},
...
}
-- TAG-SL-ZONECONFIG-STOP
```

##### 9.1.1.4 SCCH configuration

Parameters that are specified for unicast of NR sidelink communication, which is used for the sidelink signalling radio bearer of PC5-RRC message. The SL-SRB using this SCCH configuration is named as SL-SRB3.

| | | | |
|---|---|---|---|
|Name|Value|Semantics description|Ver|
|PDCP configuration||||
|>t-Reordering|Undefined|Selected by the receiving UE, up to<br><br>UE implementation||
|>pdcp-SN-Size|12|||
|RLC configuration||AM RLC||
|>sn-FieldLength|12|||
|>t-Reassembly|Undefined|Selected by the receiving UE, up to<br><br>UE implementation||
|>t-PollRetransmit|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||
|>pollPDU|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||
|>pollByte|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||
|>maxRetxThreshold|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||
|>t-StatusProhibit|Undefined|Selected by the receiving UE, up to<br><br>UE implementation||
|>logicalChannelIdentity|3|||
|MAC configuration||||
|>priority|1|||
|>prioritisedBitRate|infinity|||
|>logicalChannelGroup|0|||
|>schedulingRequestId|0|The scheduling request configuration<br><br>with this value is applicable for this<br><br>SCCH if configured by the network.||
|>sl-HARQ-FeedbackEnabled|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||

Parameters that are specified of NR sidelink communication, which is used for the sidelink signalling radio bearer of unprotected PC5-S message (e.g. Direct Link Establishment Request, TS 24.587 [57]). The SL-SRB using this SCCH configuration is named as SL-SRB0.

| | | | |
|---|---|---|---|
|Name|Value|Semantics description|Ver|
|PDCP configuration||||
|>t-Reordering|Undefined|Selected by the receiving UE, up to<br><br>UE implementation||
|>pdcp-SN-Size|12|||
|RLC configuration||UM RLC||
|>sn-FieldLength|6|||
|>t-Reassembly|Undefined|Selected by the receiving UE, up to<br><br>UE implementation||
|>logicalChannelIdentity|0|||
|MAC configuration||||
|>priority|1|||
|>prioritisedBitRate|infinity|||
|>logicalChannelGroup|0|||
|>schedulingRequestId|0|The scheduling request configuration<br><br>with this value is applicable for this<br><br>SCCH if configured by the network.||
|>sl-HARQ-FeedbackEnabled|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||

Parameters that are specified for unicast of NR sidelink communication, which is used for the sidelink signalling radio bearer of PC5-S message establishing PC5-S security (e.g. Direct Link Security Mode Command and Direct Link Security Mode Complete, TS 24.587 [57]). The SL-SRB using this SCCH configuration is named as SL-SRB1.

| | | | |
|---|---|---|---|
|Name|Value|Semantics description|Ver|
|PDCP configuration| | | |
|>t-Reordering|Undefined|Selected by the receiving UE, up to<br><br>UE implementation||
|>pdcp-SN-Size|12|||
|RLC configuration||AM RLC||
|>sn-FieldLength|12|||
|>t-Reassembly|Undefined|Selected by the receiving UE, up to<br><br>UE implementation||
|>t-PollRetransmit|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||
|>pollPDU|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||
|>pollByte|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||
|>maxRetxThreshold|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||
|>t-StatusProhibit|Undefined|Selected by the receiving UE, up to<br><br>UE implementation||
|>logicalChannelIdentity|1|||
|MAC configuration||||
|>priority|1|||
|>prioritisedBitRate|infinity|||
|>logicalChannelGroup|0|||
|>schedulingRequestId|0|The scheduling request configuration<br><br>with this value is applicable for this<br><br>SCCH if configured by the network.||
|>sl-HARQ-FeedbackEnabled|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||

Parameters that are specified for unicast of NR sidelink communication, which is used for the sidelink signalling radio bearer of protected PC5-S message except Direct Link Security Mode Complete. The SL-SRB using this SCCH configuration is named as SL-SRB2.

| | | | |
|---|---|---|---|
|Name|Value|Semantics description|Ver|
|PDCP configuration| | | |
|>t-Reordering|Undefined|Selected by the receiving UE, up to<br><br>UE implementation||
|>pdcp-SN-Size|12|||
|RLC configuration||AM RLC||
|>sn-FieldLength 12| | | |
|>t-Reassembly|Undefined|Selected by the receiving UE, up to<br><br>UE implementation||
|>t-PollRetransmit|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||
|>pollPDU|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||
|>pollByte|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||
|>maxRetxThreshold|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||
|>t-StatusProhibit|Undefined|Selected by the receiving UE, up to<br><br>UE implementation||
|>logicalChannelIdentity|2|||
|MAC configuration||||
|>priority|1|||
|>prioritisedBitRate|infinity|||
|>logicalChannelGroup|0|||
|>schedulingRequestId|0|The scheduling request configuration<br><br>with this value is applicable for this<br><br>SCCH if configured by the network.||
|>sl-HARQ-FeedbackEnabled|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||

##### 9.1.1.5 STCH configuration

Parameters that are specified for NR sidelink communication, which is used for the sidelink data radio bearer.

| | | | |
|---|---|---|---|
|Name|Value|Semantics description|Ver|
|PDCP configuration||||
|>t-Reordering|Undefined|Selected by the receiving UE, up to<br><br>UE implementation||
|>pdcp-SN-Size|12|For broadcast and groupcast of NR<br><br>sidelink communication||
|>maxCID|15|For broadcast and groupcast of NR<br><br>sidelink communication||
|>profiles||||
|RLC configuration||For broadcast and groupcast of NR<br><br>sidelink communication, uni-<br><br>directional UM RLC<br><br>UM window size is set to 32||
|>t-Reassembly|Undefined|Selected by the receiving UE, up to<br><br>Up to UE implementation||
|>sn-FieldLength|6|For broadcast and groupcast of NR<br><br>sidelink communication||
|>logicalChannelIdentity|Undefined|Selected by the transmitting UE, up to<br><br>UE implementation||
|MAC configuration||||
|>priority||||

#### 9.1.2 Void

### 9.2 Default radio configurations

The following clauses only list default values for REL-15 parameters included in protocol version v15.3.0. For all fields introduced in a later protocol version, the default value is "released" or "false" unless explicitly specified otherwise. If the UE is to apply default configuration while it is configured with some critically extended fields, the UE shall apply the original version of those fields with only default values.

> NOTE 1: In general, the signalling should preferably support a "release" option for fields introduced after v15.3.0.

The "value not applicable" should be used restrictively, mainly limited to for fields which value is relevant only if another field is set to a value other than its default.

> NOTE 2: For parameters in _ServingCellConfig_, the default values are specified in the corresponding specification.

#### 9.2.1 Default SRB configurations

Parameters

| | | | | | |
|---|---|---|---|---|---|
|Name|Value| | |Semantics<br><br>description|Ver|
||SRB1 SRB2 SRB3| | |||
|PDCP-Config<br><br>>t-Reordering|infinity|||||
|RLC-Config CHOICE|Am| | |||
|ul-AM-RLC<br><br>>sn-FieldLength<br><br>>t-PollRetransmit<br><br>>pollPDU<br><br>>pollByte<br><br>>maxRetxThreshold|size12<br><br>ms45<br><br>infinity<br><br>infinity<br><br>t8| | |||
|dl-AM-RLC<br><br>>sn-FieldLength<br><br>>t-Reassembly<br><br>>t-StatusProhibit|size12<br><br>ms35<br><br>ms0| | |||
|logicalChannelIdentity|1 2 3| | |||
|LogicalChannelConfig|| | |||
|>priority|1 3 1| | |||
|>prioritisedBitRate|infinity| | |||
|>logicalChannelGroup 0|| | |||

#### 9.2.2 Default MAC Cell Group configuration

Parameters

| | | | |
|---|---|---|---|
|Name|Value|Semantics description|Ver|
|MAC Cell Group configuration| | | |
|bsr-Config||||
|>periodicBSR-Timer|sf10|||
|>retxBSR-Timer|sf80|||
|phr-Config||||
|>phr-PeriodicTimer sf10| | | |
|>phr-ProhibitTimer|sf10|||
|||||

_>phr-Tx-PowerFactorChange_ dB1

#### 9.2.3 Default values timers and constants

Parameters

| | | | |
|---|---|---|---|
|Name|Value|Semantics description|Ver|
|t310|ms1000|||
|n310|n1|||
|t311|ms30000|||
|||||

n311 n1

### 9.3 Sidelink pre-configured parameters

This ASN.1 segment is the start of the NR definitions of pre-configured sidelink parameters.

##### NR-Sidelink-Preconf

```asn1
-- TAG-NR-SIDELINK-PRECONF-DEFINITIONS-START
NR-Sidelink-Preconf DEFINITIONS AUTOMATIC TAGS ::=
BEGIN
IMPORTS
SL-FreqConfigCommon-r16,
SL-RadioBearerConfig-r16,
SL-RLC-BearerConfig-r16,
SL-EUTRA-AnchorCarrierFreqList-r16,
SL-NR-AnchorCarrierFreqList-r16,
SL-MeasConfigCommon-r16,
SL-UE-SelectedConfig-r16,
TDD-UL-DL-ConfigCommon,
maxNrofFreqSL-r16,
maxNrofSLRB-r16,
maxSL-LCID-r16,
SL-FreqConfigCommonExt-v16k0
FROM NR-RRC-Definitions;
-- TAG-NR-SIDELINK-PRECONF-DEFINITIONS-STOP
```

##### SL-PreconfigurationNR

The IE _SL-PreconfigurationNR_ includes the sidelink pre-configured parameters used for NR sidelink communication. Need codes or conditions specified for subfields in _SL-PreconfigurationNR_ do not apply.

**_SL-PreconfigurationNR_** **information elements**

```asn1
-- TAG-SL-PRECONFIGURATIONNR-START
SL-PreconfigurationNR-r16 ::= SEQUENCE {
sidelinkPreconfigNR-r16 SidelinkPreconfigNR-r16,
...,
[[
sidelinkPreconfigNR-v16k0 SidelinkPreconfigNR-v16k0
]]
}
SidelinkPreconfigNR-r16 ::= SEQUENCE {
sl-PreconfigFreqInfoList-r16 SEQUENCE (SIZE (1..maxNrofFreqSL-r16)) OF SL-FreqConfigCommon-r16 OPTIONAL,
sl-PreconfigNR-AnchorCarrierFreqList-r16 SL-NR-AnchorCarrierFreqList-r16 OPTIONAL,
sl-PreconfigEUTRA-AnchorCarrierFreqList-r16 SL-EUTRA-AnchorCarrierFreqList-r16 OPTIONAL,
sl-RadioBearerPreConfigList-r16 SEQUENCE (SIZE (1..maxNrofSLRB-r16)) OF SL-RadioBearerConfig-r16 OPTIONAL,
sl-RLC-BearerPreConfigList-r16 SEQUENCE (SIZE (1..maxSL-LCID-r16)) OF SL-RLC-BearerConfig-r16 OPTIONAL,
sl-MeasPreConfig-r16 SL-MeasConfigCommon-r16 OPTIONAL,
sl-OffsetDFN-r16 INTEGER (1..1000) OPTIONAL,
t400-r16 ENUMERATED{ms100, ms200, ms300, ms400, ms600, ms1000, ms1500, ms2000} OPTIONAL,
sl-MaxNumConsecutiveDTX-r16 ENUMERATED {n1, n2, n3, n4, n6, n8, n16, n32} OPTIONAL,
sl-SSB-PriorityNR-r16 INTEGER (1..8) OPTIONAL,
sl-PreconfigGeneral-r16 SL-PreconfigGeneral-r16 OPTIONAL,
sl-UE-SelectedPreConfig-r16 SL-UE-SelectedConfig-r16 OPTIONAL,
sl-CSI-Acquisition-r16 ENUMERATED {enabled} OPTIONAL,
sl-RoHC-Profiles-r16 SL-RoHC-Profiles-r16 OPTIONAL,
sl-MaxCID-r16 INTEGER (1..16383) DEFAULT 15,
...
}
SidelinkPreconfigNR-v16k0 ::= SEQUENCE {
sl-PreconfigFreqInfoListExt-v16k0 SEQUENCE (SIZE (1..maxNrofFreqSL-r16)) OF SL-FreqConfigCommonExt-v16k0 OPTIONAL
}
SL-PreconfigGeneral-r16 ::= SEQUENCE {
sl-TDD-Configuration-r16 TDD-UL-DL-ConfigCommon OPTIONAL,
reservedBits-r16 BIT STRING (SIZE (2)) OPTIONAL,
...
}
SL-RoHC-Profiles-r16 ::= SEQUENCE {
profile0x0001-r16 BOOLEAN,
profile0x0002-r16 BOOLEAN,
profile0x0003-r16 BOOLEAN,
profile0x0004-r16 BOOLEAN,
profile0x0006-r16 BOOLEAN,
profile0x0101-r16 BOOLEAN,
profile0x0102-r16 BOOLEAN,
profile0x0103-r16 BOOLEAN,
profile0x0104-r16 BOOLEAN
}
-- TAG-SL-PRECONFIGURATIONNR-STOP
```

**_SL-PreconfigurationNR_** **field descriptions** **_sl-OffsetDFN_** Indicates the timing offset for the UE to determine DFN timing when GNSS is used for timing reference. Value 1 corresponds to 0.001 milliseconds, value 2 corresponds to 0.002 milliseconds, and so on. If the field is absent, no offset is applied.

**_sl-PreconfigEUTRA-AnchorCarrierFreqList_** This field indicates the EUTRA anchor carrier frequency list, which can provide the NR sidelink communication configuration.

**_sl-PreconfigFreqInfoList, sl-PreconfigFreqInfoListExt_** This field indicates the NR sidelink communication configuration some carrier frequency(ies). In this release, only one _SL-FreqConfig_ can be configured in the list. If _sl-PreconfigFreqInfoListExt_ is included, it contains the same number of entries, and listed in the same order, as in _sl-PreconfigFreqInfoList_.

**_sl-PreconfigNR-AnchorCarrierFreqList_** This field indicates the NR anchor carrier frequency list, which can provide the NR sidelink communication configuration.

**_sl-RadioBearerPreConfigList_** This field indicates one or multiple sidelink radio bearer configurations.

**_sl-RLC-BearerPreConfigList_** This field indicates one or multiple sidelink RLC bearer configurations.

**_sl-RoHC-Profiles_** This field indicates the supported RoHC profiles for NR sidelink communications.

**_sl-SSB-PriorityNR_** This field indicates the priority of NR sidelink SSB transmission and reception.

– _End of NR-Sidelink-Preconf_
