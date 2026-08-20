
Procedures : 

5.8 Sidelink

5.8.1 General

NR sidelink communication consists of unicast, groupcast and broadcast. For unicast, the PC5-RRC connection is a

logical connection between a pair of a Source Layer-2 ID and a Destination Layer-2 ID in the AS. The PC5-RRC

signalling, as specified in clause 5.8.9, can be initiated after its corresponding PC5 unicast link establishment (TS**Release 16** **211** **3GPP TS 38.331 V16.22.0 (2026-06)**

23.287 [55]). The PC5-RRC connection and the corresponding sidelink SRBs and sidelink DRB(s) are released when

the PC5 unicast link is released as indicated by upper layers.

For each PC5-RRC connection of unicast, one sidelink SRB (i.e. SL-SRB0) is used to transmit the PC5-S message(s)

before the PC5-S security has been established. One sidelink SRB (i.e. SL-SRB1) is used to transmit the PC5-S

messages to establish the PC5-S security. One sidelink SRB (i.e. SL-SRB2) is used to transmit the PC5-S messages

after the PC5-S security has been established, which is protected. One sidelink SRB (i.e. SL-SRB3) is used to transmit

the PC5-RRC signalling, which is protected and only sent after the PC5-S security has been established.

For unicast of NR sidelink communication, AS security comprises of integrity protection of PC5 signalling (SL-SRB1,

SL-SRB2 and SL-SRB3) and user data (SL-DRBs), and it further comprises of ciphering of PC5 signaling (SL-SRB1

only for the Direct Link Security Mode Complete message as specified in TS 24.587[57], SL-SRB2 and SL-SRB3) and

user data (SL-DRBs). The ciphering and integrity protection algorithms and parameters for a PC5 unicast link are

exchanged by PC5-S messages in the upper layers as specified in TS 33.536 [60], and apply to the corresponding PC5-

RRC connection in the AS. Once AS security is activated for a PC5 unicast link in the upper layers as specified in TS

33.536 [60], all messages on SL-SRB2 and SL-SRB3 and/or user data on SL-DRBs of the corresponding PC5-RRC

connection are integrity protected and/or ciphered by the PDCP.

For unicast of NR sidelink communication, if the change of the key is indicated by the upper layers as specified in TS

24.587 [57], UE re-establishes the PDCP entity of the SL-SRB1, SL-SRB2, SL-SRB3 and SL-DRBs on the

corresponding PC5-RRC connection.

NOTE 1: In case the configurations for NR sidelink communication are acquired via the E-UTRA, the

configurations for NR sidelink communication in _SIB12_ and _sl-ConfigDedicatedNR_ within

_RRCReconfiguration_ used in clause 5.8 are provided by the configurations in

_SystemInformationBlockType28_ and _sl-ConfigDedicatedForNR_ within _RRCConnectionReconfiguration_ as

specified in TS 36.331 [10], respectively.

NOTE 2: In this release, there is one-to-one correspondence between the PC5-RRC connection and the PC5 unicast

link as specified in TS 38.300[2].

NOTE 3: All SL-DRBs related to the same PC5-RRC connection have the same activation/deactivation setting for

ciphering and the same activation/deactivation setting for integrity protection as in TS 33.536 [60].

NOTE 4: When integrity check failure concerning SL-SRB1 for a specific destination is detected, the UE sends an

indication to the upper layers [57].

NOTE 5: The selection of NULL algorithms means that the PC5 messages are considered protected for the

purposes of being allowed to be sent or received.

5.8.2 Conditions for NR sidelink communication operation

The UE shall perform NR sidelink communication operation only if the conditions defined in this clause are met:

1> if the UE's serving cell is suitable (RRC_IDLE or RRC_INACTIVE or RRC_CONNECTED); and if either the

selected cell on the frequency used for NR sidelink communication operation belongs to the registered or

equivalent PLMN as specified in TS 24.587 [57] or the UE is out of coverage on the frequency used for NR

sidelink communication operation as defined in TS 38.304 [20] and TS 36.304 [27]; or

1> if the UE's serving cell (RRC_IDLE or RRC_CONNECTED) fulfils the conditions to support NR sidelink

communication in limited service state as specified in TS 23.287 [55]; and if either the serving cell is on the

frequency used for NR sidelink communication operation or the UE is out of coverage on the frequency used for

NR sidelink communication operation as defined in TS 38.304 [20] and TS 36.304 [27]; or

1> if the UE has no serving cell (RRC_IDLE);**Release 16** **212** **3GPP TS 38.331 V16.22.0 (2026-06)**

5.8.3 Sidelink UE information for NR sidelink communication

5.8.3.1 General

**UE Network**

SIB12 acquisition

_SidelinkUEInformationNR_

**Figure 5.8.3.1-1: Sidelink UE information for NR sidelink communication**

The purpose of this procedure is to inform the network that the UE:

- is interested or no longer interested to receive or transmit NR sidelink communication,

- is requesting assignment or release of transmission resource for NR sidelink communication,

- is reporting QoS parameters and QoS profile(s) related to NR sidelink communication,

- is reporting that a sidelink radio link failure or sidelink RRC reconfiguration failure has been detected,

- is reporting the sidelink UE capability information of the associated peer UE for unicast communication,

- is reporting the RLC mode information of the sidelink data radio bearer(s) received from the associated peer UE

for unicast communication.

5.8.3.2 Initiation

A UE capable of NR sidelink communication that is in RRC_CONNECTED may initiate the procedure to indicate it is

(interested in) receiving or transmitting NR sidelink communication in several cases including upon successful

connection establishment or resuming, upon change of interest, upon changing QoS profiles, upon receiving

_UECapabilityInformationSidelink_ from the associated peer UE, upon RLC mode information updated from the

associated peer UE or upon change to a PCell providing _SIB12_ including _sl-ConfigCommonNR_. A UE capable of NR

sidelink communication may initiate the procedure to request assignment of dedicated sidelink DRB configuration and

transmission resources for NR sidelink communication transmission. A UE capable of NR sidelink communication may

initiate the procedure to report to the network that a sidelink radio link failure or sidelink RRC reconfiguration failure

has been declared.

Upon initiating this procedure, the UE shall:

1> if _SIB12_ including _sl-ConfigCommonNR_ is provided by the PCell:

2> ensure having a valid version of _SIB12_ for the PCell;

2> if configured by upper layers to receive NR sidelink communication on the frequency included in _sl-_

_FreqInfoList_ in _SIB12_ of the PCell:

3> if the UE did not transmit a _SidelinkUEInformationNR_ message since last entering RRC_CONNECTED

state; or

3> if since the last time the UE transmitted a _SidelinkUEInformationNR_ message the UE connected to a

PCell not providing _SIB12_ including _sl-ConfigCommonNR_; or

3> if the last transmission of the _SidelinkUEInformationNR_ message did not include _sl-RxInterestedFreqList_;

or if the frequency configured by upper layers to receive NR sidelink communication on has changed

since the last transmission of the _SidelinkUEInformationNR_ message:

4> initiate transmission of the _SidelinkUEInformationNR_ message to indicate the NR sidelink

communication reception frequency of interest in accordance with 5.8.3.3;**Release 16** **213** **3GPP TS 38.331 V16.22.0 (2026-06)**

2> else:

3> if the last transmission of the _SidelinkUEInformationNR_ message included _sl-RxInterestedFreqList_:

4> initiate transmission of the _SidelinkUEInformationNR_ message to indicate it is no longer interested in

NR sidelink communication reception in accordance with 5.8.3.3;

2> if configured by upper layers to transmit NR sidelink communication on the frequency included in _sl-_

_FreqInfoList_ in _SIB12_ of the PCell:

3> if the UE did not transmit a _SidelinkUEInformationNR_ message since last entering RRC_CONNECTED

state; or

3> if since the last time the UE transmitted a _SidelinkUEInformationNR_ message the UE connected to a

PCell not providing _SIB12_ including _sl-ConfigCommonNR_; or

3> if the last transmission of the _SidelinkUEInformationNR_ message did not include _sl-TxResourceReqList_;

or if the information carried by the _sl-TxResourceReqList_ has changed since the last transmission of the

_SidelinkUEInformationNR_ message:

4> initiate transmission of the _SidelinkUEInformationNR_ message to indicate the NR sidelink

communication transmission resources required by the UE in accordance with 5.8.3.3;

2> else:

3> if the last transmission of the _SidelinkUEInformationNR_ message included _sl-TxResourceReqList_:

4> initiate transmission of the _SidelinkUEInformationNR_ message to indicate it no longer requires NR

sidelink communication transmission resources in accordance with 5.8.3.3.

5.8.3.3 Actions related to transmission of _SidelinkUEInformationNR_ message

The UE shall set the contents of the _SidelinkUEInformationNR_ message as follows:

1> if the UE initiates the procedure to indicate it is (no more) interested to receive NR sidelink communication or to

request (configuration/ release) of NR sidelink communication transmission resources or to report to the network

that a sidelink radio link failure or sidelink RRC reconfiguration failure has been declared (i.e. UE includes all

concerned information, irrespective of what triggered the procedure):

2> if _SIB12_ including _sl-ConfigCommonNR_ is provided by the PCell:

3> if configured by upper layers to receive NR sidelink communication:

4> include _sl-RxInterestedFreqList_ and set it to the frequency for NR sidelink communication reception;

3> if configured by upper layers to transmit NR sidelink communication:

4> include _sl-TxResourceReqList_ and set its fields (if needed) as follows for each destination for which it

requests network to assign NR sidelink communication resource:

5> set _sl-DestinationIdentity_ to the destination identity configured by upper layer for NR sidelink

communication transmission;

5> set _sl-CastType_ to the cast type of the associated destination identity configured by the upper layer

for the NR sidelink communication transmission;

5> set _sl-RLC-ModeIndicationList_ to include the RLC mode(s) and optionally QoS profile(s) of the

sidelink QoS flow(s) of the associated RLC mode(s), if the associated bi-directional sidelink

DRB(s) have been established due to the configuration by _RRCReconfigurationSidelink_;

5> set _sl-QoS-InfoList_ to include QoS profile(s) of the sidelink QoS flow(s) of the associated

destination configured by the upper layer for the NR sidelink communication transmission;

5> set _sl-TxInterestedFreqList_ to indicate the frequency of the associated destination for NR sidelink

communication transmission;**Release 16** **214** **3GPP TS 38.331 V16.22.0 (2026-06)**

5> set _sl-TypeTxSyncList_ to the current synchronization reference type used on the associated _sl-_

_TxInterestedFreqList_ for NR sidelink communication transmission.

5> set _sl-CapabilityInformationSidelink_ to include _UECapabilityInformationSidelink_ message, if any,

received from peer UE.

4> if a sidelink radio link failure or a sidelink RRC reconfiguration failure has been declared, according

to clauses 5.8.9.3 and 5.8.9.1.8, respectively;

5> include _sl-FailureList_ and set its fields as follows for each destination for which it reports the NR

sidelink communication failure:

6> set _sl-DestinationIdentity_ to the destination identity configured by upper layer for NR sidelink

communication transmission;

6> if the sidelink RLF is detected as specified in clause 5.8.9.3:

7> set _sl-Failure_ as _rlf_ for the associated destination for the NR sidelink communication

transmission;

6> else if _RRCReconfigurationFailureSidelink_ is received:

7> set _sl-Failure_ as _configFailure_ for the associated destination for the NR sidelink

communication transmission;

1> if the UE initiates the procedure while connected to an E-UTRA PCell:

2> submit the _SidelinkUEInformationNR_ to lower layers via SRB1, embedded in E-UTRA RRC message

_ULInformationTransferIRAT_ as specified in TS 36.331 [10], clause 5.6.28;

1> else:

2> submit the _SidelinkUEInformationNR_ message to lower layers for transmission.

5.8.4 Void

5.8.5 Sidelink synchronisation information transmission for NR sidelink

communication

5.8.5.1 General

**UE Network**

_SIB12 acquisition_

_RRCReconfiguration_

_SLSS& MasterInformationBlockSidelink_

**Figure 5.8.5.1-1: Synchronisation information transmission for NR sidelink communication, in**

**(partial) coverage****Release 16** **215** **3GPP TS 38.331 V16.22.0 (2026-06)**

**UE UE**

_SLSS& MasterInformationBlockSidelink_

_SLSS& MasterInformationBlockSidelink_

**Figure 5.8.5.1-2: Synchronisation information transmission for NR sidelink communication, out of**

**coverage**

The purpose of this procedure is to provide synchronisation information to a UE.

5.8.5.2 Initiation

A UE capable of NR sidelink communication and SLSS/PSBCH transmission shall, when transmitting NR sidelink

communication, and if the conditions for NR sidelink communication operation are met and when the following

conditions are met:

1> if in coverage on the frequency used for NR sidelink communication, as defined in TS 38.304 [20]; and has

selected GNSS or the cell as synchronization reference as defined in 5.8.6.3; or

1> if out of coverage on the frequency used for NR sidelink communication, and the frequency used to transmit NR

sidelink communication is included in _sl-FreqInfoToAddModList_ in _sl-ConfigDedicatedNR_ within

_RRCReconfiguration_ message or included in _sl-FreqInfoList_ within _SIB12_; and has selected GNSS or the cell as

synchronization reference as defined in 5.8.6.3:

2> if in RRC_CONNECTED; and if _networkControlledSyncTx_ is configured and set to _on_; or

2> if _networkControlledSyncTx_ is not configured; and for the concerned frequency _syncTxThreshIC_ is

configured; and the RSRP measurement of the reference cell, selected as defined in 5.8.6.3, for NR sidelink

communication transmission is below the value of _syncTxThreshIC_:

3> transmit sidelink SSB on the frequency used for NR sidelink communication in accordance with 5.8.5.3

and TS 38.211 [16], including the transmission of SLSS as specified in 5.8.5.3 and transmission of

_MasterInformationBlockSidelink_ as specified in 5.8.9.4.3;

1> else:

2> for the frequency used for NR sidelink communication, if _syncTxThreshOoC_ is included in

_SidelinkPreconfigNR_; and the UE is not directly synchronized to GNSS, and the UE has no selected SyncRef

UE or the PSBCH-RSRP measurement result of the selected SyncRef UE is below the value of

_syncTxThreshOoC_; or

2> for the frequency used for NR sidelink communication, if the UE selects GNSS as the synchronization

reference source:

3> transmit sidelink SSB on the frequency used for NR sidelink communication in accordance with 5.8.5.3

and TS 38.211 [16] , including the transmission of SLSS as specified in 5.8.5.3 and transmission of

_MasterInformationBlockSidelink_ as specified in 5.8.9.4.3;

5.8.5.3 Transmission of SLSS

The UE shall select the SLSSID and the slot in which to transmit SLSS as follows:

1> if triggered by NR sidelink communication and in coverage on the frequency used for NR sidelink

communication, as defined in TS 38.304 [20]; or

1> if triggered by NR sidelink communication, and out of coverage on the frequency used for NR sidelink

communication, and the concerned frequency is included in _sl-FreqInfoToAddModList_ in _sl-ConfigDedicatedNR_

within _RRCReconfiguration_ message or included in _sl-FreqInfoList_ within _SIB12_:

2> if the UE has selected GNSS as synchronization reference in accordance with 5.8.6.2:**Release 16** **216** **3GPP TS 38.331 V16.22.0 (2026-06)**

3> select SLSSID 0;

3> use _sl-SSB-TimeAllocation1_ included in the entry of configured _sl-SyncConfigList_ corresponding to the

concerned frequency, that includes _txParameters_ and _gnss-Sync_;

3> select the slot(s) indicated by _sl-SSB-TimeAllocation1_;

2> if the UE has selected a cell as synchronization reference in accordance with 5.8.6.2:

3> select the SLSSID included in the entry of configured _sl-SyncConfigList_ corresponding to the concerned

frequency, that includes _txParameters_ and does not include _gnss-Sync_;

3> select the slot(s) indicated by _sl-SSB-TimeAllocation1_;

1> else if triggered by NR sidelink communication and the UE has GNSS as the synchronization reference:

2> select SLSSID 0;

2> if _sl-SSB-TimeAllocation3_ is configured for the frequency used in _SidelinkPreconfigNR:_

3> select the slot(s) indicated by _sl-SSB-TimeAllocation3_;

2> else:

3> select the slot(s) indicated by _sl-SSB-TimeAllocation1_;

1> else:

2> select the synchronisation reference UE (i.e. SyncRef UE) as defined in 5.8.6;

2> if the UE has a selected SyncRef UE and _inCoverage_ in the _MasterInformationBlockSidelink_ message

received from this UE is set to _true_; or

2> if the UE has a selected SyncRef UE and _inCoverage_ in the _MasterInformationBlockSidelink_ message

received from this UE is set to _false_ while the SLSS from this UE is part of the set defined for out of

coverage, see TS 38.211 [16]:

3> select the same SLSSID as the SLSSID of the selected SyncRef UE;

3> select the slot in which to transmit the SLSS according to the _sl-SSB-TimeAllocation1_ or _sl-SSB-_

_TimeAllocation2_ included in the preconfigured sidelink parameters corresponding to the concerned

frequency, such that the timing is different from the SLSS of the selected SyncRef UE;

2> else if the UE has a selected SyncRef UE and the SLSS from this UE was transmitted on the slot(s) indicated

_sl-SSB-TimeAllocation3_, which is configured for the frequency used in _SidelinkPreconfigNR_:

3> select SLSSID 337;

3> select the slot(s) indicated by _sl-SSB-TimeAllocation2_;

2> else if the UE has a selected SyncRef UE:

3> select the SLSSID from the set defined for out of coverage having an index that is 336 more than the

index of the SLSSID of the selected SyncRef UE, see TS 38.211 [16];

3> select the slot in which to transmit the SLSS according to _sl-SSB-TimeAllocation1_ or _sl-SSB-_

_TimeAllocation2_ included in the preconfigured sidelink parameters corresponding to the concerned

frequency, such that the timing is different from the SLSS of the selected SyncRef UE;

2> else (i.e. no SyncRef UE selected):

3> if the UE has not randomly selected an SLSSID:

4> randomly select, using a uniform distribution, an SLSSID from the set of sequences defined for out of

coverage except SLSSID 336 and 337, see TS 38.211 [16];**Release 16** **217** **3GPP TS 38.331 V16.22.0 (2026-06)**

4> select the slot in which to transmit the SLSS according to the _sl-SSB-TimeAllocation1_ or _sl-SSB-_

_TimeAllocation2_ (arbitrary selection between these) included in the preconfigured sidelink parameters

in _SidelinkPreconfigNR_ corresponding to the concerned frequency;

5.8.5a Sidelink synchronisation information transmission for V2X sidelink

communication

5.8.5a.1 General

**UE Network**

_SIB13/SIB14 acquisition_

_RRCReconfiguration_

_SLSS and MasterInformationBlockSidelink_

**Figure 5.8.5a.1-1: Synchronisation information transmission for V2X sidelink communication, in**

**(partial) coverage**

**UE UE**

_SLSS and MasterInformationBlockSidelink_

_SLSS and MasterInformationBlockSidelink_

**Figure 5.8.5a.1-2: Synchronisation information transmission for V2X sidelink communication, out of**

**coverage**

The purpose of this procedure is to provide synchronisation information to a UE.

5.8.5a.2 Initiation

A UE capable of V2X sidelink communication initiates the transmission of SLSS and _MasterInformationBlock-SL-V2X_

according to the conditions and the procedures specified for V2X sidelink communication in clause 5.10.7 of TS 36.331

[10].

NOTE 1: When applying the procedure in this clause, _SIB13_ and _SIB14_ correspond to

_SystemInformationBlockType21_ and _SystemInformationBlockType26_ specified in TS 36.331 [10]

respectively

5.8.6 Sidelink synchronisation reference

5.8.6.1 General

The purpose of this procedure is to select a synchronisation reference and used when transmitting NR sidelink

communication.

5.8.6.2 Selection and reselection of synchronisation reference

The UE shall:**Release 16** **218** **3GPP TS 38.331 V16.22.0 (2026-06)**

1> if the frequency used for NR sidelink communication is included in _sl-FreqInfoToAddModList_ in _sl-_

_ConfigDedicatedNR_ within _RRCReconfiguration_ message or included in _sl-ConfigCommonNR_ within _SIB12_, and

_sl-SyncPriority_ is configured for the concerned frequency and set to _gnbEnb_:

2> select a cell as the synchronization reference source as defined in 5.8.6.3:

1> else if the frequency used for NR sidelink communication is included in _sl-FreqInfoToAddModList_ in _sl-_

_ConfigDedicatedNR_ within _RRCReconfiguration_ message or included in _sl-ConfigCommonNR_ within _SIB12_, and

_sl-SyncPriority_ for the concerned frequency is not configured or is set to _gnss_, and GNSS is reliable in

accordance with TS 38.101-1 [15] and TS 38.133 [14]:

2> select GNSS as the synchronization reference source;

1> else if the frequency used for NR sidelink communication is included in _SL-PreconfigurationNR_, and _sl-_

_SyncPriority_ in _SidelinkPreconfigNR_ is set to _gnss_ and GNSS is reliable in accordance with TS 38.101-1 [15]

and TS 38.133 [14]:

2> select GNSS as the synchronization reference source;

1> else:

2> perform a full search (i.e. covering all subframes and all possible SLSSIDs) to detect candidate SLSS, in

accordance with TS 38.133 [14]

2> when evaluating the one or more detected SLSSIDs, apply layer 3 filtering as specified in 5.5.3.2 using the

preconfigured _sl-FilterCoefficient_ in _SL-SyncConfig_, before using the PSBCH-RSRP measurement results;

2> if the UE has selected a SyncRef UE:

3> if the PSBCH-RSRP of the strongest candidate SyncRef UE exceeds the minimum requirement TS

38.133 [14] by _sl-SyncRefMinHyst_ and the strongest candidate SyncRef UE belongs to the same priority

group as the current SyncRef UE and the PSBCH-RSRP of the strongest candidate SyncRef UE exceeds

the PSBCH-RSRP of the current SyncRef UE by _syncRefDiffHyst_; or

3> if the PSBCH-RSRP of the candidate SyncRef UE exceeds the minimum requirement TS 38.133 [14] by

_sl-SyncRefMinHyst_ and the candidate SyncRef UE belongs to a higher priority group than the current

SyncRef UE; or

3> if GNSS becomes reliable in accordance with TS 38.101-1 [15] and TS 38.133 [14], and GNSS belongs

to a higher priority group than the current SyncRef UE; or

3> if a cell is detected and gNB/eNB (if _sl-NbAsSync_ is set to _true_) belongs to a higher priority group than

the current SyncRef UE; or

3> if the PSBCH-RSRP of the current SyncRef UE is less than the minimum requirement defined in TS

38.133 [14]:

4> consider no SyncRef UE to be selected;

2> if the UE has selected GNSS as the synchronization reference for NR sidelink communication:

3> if the PSBCH-RSRP of the candidate SyncRef UE exceeds the minimum requirement defined in TS

38.133 [14] by _sl-SyncRefMinHyst_ and the candidate SyncRef UE belongs to a higher priority group than

GNSS; or

3> if GNSS becomes not reliable in accordance with TS 38.101-1 [15] and TS 38.133 [14]:

4> consider GNSS not to be selected;

2> if the UE has selected cell as the synchronization reference for NR sidelink communication:

3> if the PSBCH-RSRP of the candidate SyncRef UE exceeds the minimum requirement defined in TS

38.133 [14] by _sl-SyncRefMinHyst_ and the candidate SyncRef UE belongs to a higher priority group than

gNB/eNB; or

3> if the selected cell is not detected:**Release 16** **219** **3GPP TS 38.331 V16.22.0 (2026-06)**

4> consider the cell not to be selected;

2> if the UE has not selected any synchronization reference:

3> if the UE detects one or more SLSSIDs for which the PSBCH-RSRP exceeds the minimum requirement

defined in TS 38.133 [14] by _sl-SyncRefMinHyst_ and for which the UE received the corresponding

_MasterInformationBlockSidelink_ message (candidate SyncRef UEs), or if the UE detects GNSS that is

reliable in accordance with TS 38.101-1 [15] and TS 38.133 [14], or if the UE detects a cell, select a

synchronization reference according to the following priority group order:

4> if _sl-SyncPriority_ corresponding to the concerned frequency is set to _gnbEnb_:

5> UEs of which SLSSID is part of the set defined for in coverage, and _inCoverage_, included in the

_MasterInformationBlockSidelink_ message received from this UE, is set to _true_, starting with the

UE with the highest PSBCH-RSRP result (priority group 1);

5> UE of which SLSSID is part of the set defined for in coverage, and _inCoverage_, included in the

_MasterInformationBlockSidelink_ message received from this UE, is set to _false_, starting with the

UE with the highest PSBCH-RSRP result (priority group 2);

5> GNSS that is reliable in accordance with TS 38.101-1 [15] and TS 38.133 [14] (priority group 3);

5> UEs of which SLSSID is 0, and _inCoverage_, included in the _MasterInformationBlockSidelink_

message received from this UE, is set to _true,_ or of which SLSSID is 0 and SLSS is transmitted on

slot(s) indicated by _sl-SSB-TimeAllocation3_, starting with the UE with the highest PSBCH-RSRP

result (priority group 4);

5> UEs of which SLSSID is 0 and SLSS is not transmitted on slot(s) indicated by _sl-SSB-_

_TimeAllocation3_, and _inCoverage_, included in the _MasterInformationBlockSidelink_ message

received from this UE, is set to _false_, starting with the UE with the highest PSBCH-RSRP result

(priority group 5);

5> UEs of which SLSSID is 337 and _inCoverage_, included in the _MasterInformationBlockSidelink_

message received from this UE, is set to _false_, starting with the UE with the highest PSBCH-RSRP

result (priority group 5);

5> Other UEs, starting with the UE with the highest PSBCH-RSRP result (priority group 6);

4> if _sl-SyncPriority_ corresponding to the concerned frequency is set to _gnss_, and _sl-NbAsSync_ is set to

_true:_

5> UEs of which SLSSID is 0, and _inCoverage_, included in the _MasterInformationBlockSidelink_

message received from this UE, is set to _true_, or of which SLSSID is 0 and SLSS is transmitted on

slot(s) indicated by _sl-SSB-TimeAllocation3_, starting with the UE with the highest PSBCH-RSRP

result (priority group 1);

5> UEs of which SLSSID is 0 and SLSS is not transmitted on slot(s) indicated by _sl-SSB-_

_TimeAllocation3_, and _inCoverage_, included in the _MasterInformationBlockSidelink_ message

received from this UE, is set to _false_, starting with the UE with the highest PSBCHS-RSRP result

(priority group 2);

5> UEs of which SLSSID is 337 and _inCoverage_, included in the _MasterInformationBlockSidelink_

message received from this UE, is set to _false_, starting with the UE with the highest PSBCH-RSRP

result (priority group 2);

5> the cell detected by the UE as defined in 5.8.6.3 (priority group 3);

5> UEs of which SLSSID is part of the set defined for in coverage, and _inCoverage_, included in the

_MasterInformationBlockSidelink_ message received from this UE, is set to _true_, starting with the

UE with the highest PSBCH-RSRP result (priority group 4);

5> UE of which SLSSID is part of the set defined for in coverage, and _inCoverage_, included in the

_MasterInformationBlockSidelink_ message received from this UE, is set to _false_, starting with the

UE with the highest PSBCH-RSRP result (priority group 5);

5> Other UEs, starting with the UE with the highest S-RSRP result (priority group 6);**Release 16** **220** **3GPP TS 38.331 V16.22.0 (2026-06)**

4> if _sl-SyncPriority_ corresponding to the concerned frequency is set to _gnss_, and _sl-NbAsSync_ is set to

_false:_

5> UEs of which SLSSID is 0, and _inCoverage_, included in the _MasterInformationBlockSidelink_

message received from this UE, is set to _true_, or of which SLSSID is 0 and SLSS is transmitted on

slot(s) indicated by _sl-SSB-TimeAllocation3_, starting with the UE with the highest PSBCH-RSRP

result (priority group 1);

5> UEs of which SLSSID is 0 and SLSS is not transmitted on slot(s) indicated by _sl-SSB-_

_TimeAllocation3_, and _inCoverage_, included in the _MasterInformationBlockSidelink_ message

received from this UE, is set to _false_, starting with the UE with the highest PSBCHS-RSRP result

(priority group 2);

5> UEs of which SLSSID is 337 and _inCoverage_, included in the _MasterInformationBlockSidelink_

message received from this UE, is set to _false_, starting with the UE with the highest PSBCH-RSRP

result (priority group 2);

5> Other UEs, starting with the UE with the highest PSBCH-RSRP result (priority group 3);

NOTE: How the UE achieves subframe boundary alignment between V2X sidelink communication and NR

sidelink communication (if both are performed by the UE) is as specified in TS 38.213, clause 16.7.

5.8.6.3 Sidelink communication transmission reference cell selection

A UE capable of NR sidelink communication that is configured by upper layers to transmit NR sidelink communication

shall:

1> for the frequency used to transmit NR sidelink communication, select a cell to be used as reference for

synchronization in accordance with the following:

2> if the frequency concerns the primary frequency:

3> use the PCell or the serving cell as reference;

2> else if the frequency concerns a secondary frequency:

3> use the concerned SCell as reference;

2> else if the UE is in coverage of the concerned frequency:

3> use the DL frequency paired with the one used to transmit NR sidelink communication as reference;

2> else (i.e., out of coverage on the concerned frequency):

3> use the PCell or the serving cell as reference, if needed;

5.8.7 Sidelink communication reception

A UE capable of NR sidelink communication that is configured by upper layers to receive NR sidelink communication

shall:

1> if the conditions for NR sidelink communication operation as defined in 5.8.2 are met:

2> if the frequency used for NR sidelink communication is included in _sl-FreqInfoToAddModList_ in

_RRCReconfiguration_ message or _sl-FreqInfoList_ included in _SIB12_:

3> if the UE is configured with _sl-RxPool_ included in _RRCReconfiguration_ message with

_reconfigurationWithSync_ (i.e. handover):

4> configure lower layers to monitor sidelink control information and the corresponding data using the

pool(s) of resources indicated by _sl-RxPool_;

3> else if the cell chosen for NR sidelink communication provides _SIB12_:

4> configure lower layers to monitor sidelink control information and the corresponding data using the

pool(s) of resources indicated by _sl-RxPool in SIB12_;**Release 16** **221** **3GPP TS 38.331 V16.22.0 (2026-06)**

2> else:

3> configure lower layers to monitor sidelink control information and the corresponding data using the

pool(s) of resources that were preconfigured by _sl-RxPool_ in _SL-PreconfigurationNR_, as defined in clause

9.3;

5.8.8 Sidelink communication transmission

A UE capable of NR sidelink communication that is configured by upper layers to transmit NR sidelink communication

and has related data to be transmitted shall:

1> if the conditions for NR sidelink communication operation as defined in 5.8.2 are met:

2> if the frequency used for NR sidelink communication is included in _sl-FreqInfoToAddModList_ in _sl-_

_ConfigDedicatedNR_ within _RRCReconfiguration_ message or included in _sl-ConfigCommonNR_ within _SIB12_:

3> if the UE is in RRC_CONNECTED and uses the frequency included in _sl-ConfigDedicatedNR_ within

_RRCReconfiguration_ message:

4> if the UE is configured with _sl-ScheduledConfig_:

5> if T310 for MCG or T311 is running; and if _sl-TxPoolExceptional_ is included in _sl-FreqInfoList_

for the concerned frequency in _SIB12_ or included in _sl-ConfigDedicatedNR_ in

_RRCReconfiguration_; or

5> if T301 is running and the cell on which the UE initiated RRC connection re-establishment

provides _SIB12_ including _sl-TxPoolExceptional_ for the concerned frequency; or

5> if T304 for MCG is running and the UE is configured with _sl-TxPoolExceptional_ included in _sl-_

_ConfigDedicatedNR_ for the concerned frequency in _RRCReconfiguration_:

6> configure lower layers to perform the sidelink resource allocation mode 2 based on random

selection using the pool of resources indicated by _sl-TxPoolExceptional_ as defined in TS

38.321 [3];

5> else:

6> configure lower layers to perform the sidelink resource allocation mode 1 for NR sidelink

communication;

5> if T311 is running, configure the lower layers to release the resources indicated by _rrc-_

_ConfiguredSidelinkGrant_ (if any);

4> if the UE is configured with _sl-UE-SelectedConfig_:

5> if a result of sensing on the resources configured in _sl-TxPoolSelectedNormal_ for the concerned

frequency included in _sl-ConfigDedicatedNR_ within _RRCReconfiguration_ is not available in

accordance with TS 38.214 [19];

6> if _sl-TxPoolExceptional_ for the concerned frequency is included in _RRCReconfiguration_; or

6> if the PCell provides _SIB12_ including _sl-TxPoolExceptional_ in _sl-FreqInfoList_ for the

concerned frequency:

7> configure lower layers to perform the sidelink resource allocation mode 2 based on random

selection using the pool of resources indicated by _sl-TxPoolExceptional_ as defined in TS

38.321 [3];

5> else, if the _sl-TxPoolSelectedNormal_ for the concerned frequency is included in the _sl-_

_ConfigDedicatedNR_ within _RRCReconfiguration_:

6> configure lower layers to perform the sidelink resource allocation mode 2 based on sensing (as

defined in TS 38.321 [3] and TS 38.214 [19]) using the pools of resources indicated by _sl-_

_TxPoolSelectedNormal_ for the concerned frequency;

3> else:**Release 16** **222** **3GPP TS 38.331 V16.22.0 (2026-06)**

4> if the cell chosen for NR sidelink communication transmission provides _SIB12_:

5> if _SIB12_ includes _sl-TxPoolSelectedNormal_ for the concerned frequency, and a result of sensing on

the resources configured in the _sl-TxPoolSelectedNormal_ is available in accordance with TS

38.214 [19]

6> configure lower layers to perform the sidelink resource allocation mode 2 based on sensing

using the pools of resources indicated by _sl-TxPoolSelectedNormal_ for the concerned

frequency as defined in TS 38.321 [3];

5> else if _SIB12_ includes _sl-TxPoolExceptional_ for the concerned frequency:

6> from the moment the UE initiates RRC connection establishment or RRC connection resume,

until receiving an _RRCReconfiguration_ including _sl-ConfigDedicatedNR_, or receiving an

_RRCRelease_ or an _RRCReject_; or

6> if a result of sensing on the resources configured in _sl-TxPoolSelectedNormal_ for the concerned

frequency in _SIB12_ is not available in accordance with TS 38.214 [19]:

7> configure lower layers to perform the sidelink resource allocation mode 2 based on random

selection (as defined in TS 38.321 [3]) using the pool of resources indicated by _sl-_

_TxPoolExceptional_ for the concerned frequency;

2> else:

3> configure lower layers to perform the sidelink resource allocation mode 2 based on sensing (as defined in

TS 38.321 [3] and TS 38.213 [13]) using the pools of resources indicated by _sl-TxPoolSelectedNormal_ in

_SidelinkPreconfigNR_ for the concerned frequency.

NOTE 1: The UE continues to use resources configured in _rrc-ConfiguredSidelinkGrant_ (while T310 is running)

until it is released (i.e. until T310 has expired). The UE does not use sidelink configured grant type 2

resources while T310 is running.

NOTE 2: In case of RRC reconfiguration with sync, the UE uses resources configured in _rrc-_

_ConfiguredSidelinkGrant_ (while T304 on the MCG is running) if provided by the target cell.

If configured to perform sidelink resource allocation mode 2, the UE capable of NR sidelink communication that is

configured by upper layers to transmit NR sidelink communication shall perform sensing on all pools of resources

which may be used for transmission of the sidelink control information and the corresponding data. The pools of

resources are indicated by _SidelinkPreconfigNR_, _sl-TxPoolSelectedNormal_ in _sl-ConfigDedicatedNR_, or _sl-_

_TxPoolSelectedNormal_ in _SIB12_ for the concerned frequency, as configured above.

5.8.9 Sidelink RRC procedure

5.8.9.1 Sidelink RRC reconfiguration

5.8.9.1.1 General

**UE UE**

_RRCReconfigurationSidelink_

_RRCReconfigurationCompleteSidelink_

**Figure 5.8.9.1.1-1: Sidelink RRC reconfiguration, successful****Release 16** **223** **3GPP TS 38.331 V16.22.0 (2026-06)**

**UE UE**

_RRCReconfigurationSidelink_

_RRCReconfigurationFailureSidelink_

**Figure 5.8.9.1.1-2: Sidelink RRC reconfiguration, failure**

The purpose of this procedure is to modify a PC5-RRC connection, e.g. to establish/modify/release sidelink DRBs, to

(re-)configure NR sidelink measurement and reporting, to (re-)configure sidelink CSI reference signal resources and

CSI reporting latency bound.

The UE may initiate the sidelink RRC reconfiguration procedure and perform the operation in clause 5.8.9.1.2 on the

corresponding PC5-RRC connection in following cases:

- the release of sidelink DRBs associated with the peer UE, as specified in clause 5.8.9.1a.1;

- the establishment of sidelink DRBs associated with the peer UE, as specified in clause 5.8.9.1a.2;

- the modification for the parameters included in _SLRB-Config_ of sidelink DRBs associated with the peer UE, as

specified in clause 5.8.9.1a.2;

- the (re-)configuration of the peer UE to perform NR sidelink measurement and report.

- the (re-)configuration of the sidelink CSI reference signal resources and CSI reporting latency bound.

In RRC_CONNECTED, the UE applies the NR sidelink communications parameters provided in _RRCReconfiguration_

(if any). In RRC_IDLE or RRC_INACTIVE, the UE applies the NR sidelink communications parameters provided in

system information (if any). For other cases, UEs apply the NR sidelink communications parameters provided in

_SidelinkPreconfigNR_ (if any). When UE performs state transition between above three cases, the UE applies the NR

sidelink communications parameters provided in the new state, after acquisition of the new configurations. Before

acquisition of the new configurations, UE continues applying the NR sidelink communications parameters provided in

the old state.

5.8.9.1.2 Actions related to transmission of _RRCReconfigurationSidelink_ message

The UE shall set the contents of _RRCReconfigurationSidelink_ message as follows:

1> for each sidelink DRB that is to be released, according to clause 5.8.9.1a.1.1, due to configuration by _sl-_

_ConfigDedicatedNR,_ _SIB12_, _SidelinkPreconfigNR_ or by upper layers:

2> set the entry included in the _slrb-ConfigToReleaseList_ corresponding to the sidelink DRB;

1> for each sidelink DRB that is to be established or modified, according to clause 5.8.9.1a.2.1, due to receiving _sl-_

_ConfigDedicatedNR,_ _SIB12_ or _SidelinkPreconfigNR_:

2> if a sidelink DRB is to be established:

3> assign a new logical channel identity for the logical channel to be associated with the sidelink DRB and

set _sl-MAC-LogicalChannelConfigPC5_ in the _SLRB-Config_ to include the new logical channel identity;

2> set the _SLRB-Config_ included in the _slrb-ConfigToAddModList_, according to the received _sl-_

_RadioBearerConfig_ and _sl-RLC-BearerConfig_ corresponding to the sidelink DRB;

1> set the _sl-MeasConfig_ as follows:

2> If the frequency used for NR sidelink communication is included in _sl-FreqInfoToAddModList_ in _sl-_

_ConfigDedicatedNR_ within _RRCReconfiguration_ message or included in _sl-ConfigCommonNR_ within SIB12:

3> if UE is in RRC_CONNECTED:**Release 16** **224** **3GPP TS 38.331 V16.22.0 (2026-06)**

4> set the _sl-MeasConfig_ according to stored NR sidelink measurement configuration information for this

destination;

3> if UE is in RRC_IDLE or RRC_INACTIVE:

4> set the _sl-MeasConfig_ according to stored NR sidelink measurement configuration received from

_SIB12_;

2> else:

3> set the _sl-MeasConfig_ according to the _sl-MeasPreConfig_ in _SidelinkPreconfigNR_;

1> start timer T400 for the destination;

1> set the _sl-CSI-RS-Config_;

1> set the _sl-LatencyBoundCSI-Report_;

1> set the _sl-ResetConfig_;

NOTE 1: Whether/how to set the parameters included in _sl-CSI-RS-Config_, _sl-LatencyBoundCSI-Report_ and _sl-_

_ResetConfig_ is up to UE implementation.

The UE shall submit the _RRCReconfigurationSidelink_ message to lower layers for transmission.

5.8.9.1.3 Reception of an _RRCReconfigurationSidelink_ by the UE

The UE shall perform the following actions upon reception of the _RRCReconfigurationSidelink_:

1> if the _RRCReconfigurationSidelink_ includes the _sl-ResetConfig_:

2> perform the sidelink reset configuration procedure as specified in 5.8.9.1.10;

1> if the _RRCReconfigurationSidelink_ includes the _slrb-ConfigToReleaseList_:

2> for each entry included in the _slrb-ConfigToReleaseList_ that is part of the current UE sidelink configuration;

3> perform the sidelink DRB release procedure, according to clause 5.8.9.1a.1;

1> if the _RRCReconfigurationSidelink_ includes the _slrb-ConfigToAddModList_:

2> for each _slrb-PC5-ConfigIndex_ value included in the _slrb-ConfigToAddModList_ that is not part of the current

UE sidelink configuration:

3> if _sl-MappedQoS-FlowsToAddList_ is included:

4> apply the _SL-PQFI_ included in _sl-MappedQoS-FlowsToAddList_;

3> perform the sidelink DRB addition procedure, according to clause 5.8.9.1a.2;

2> for each _slrb-PC5-ConfigIndex_ value included in the _slrb-ConfigToAddModList_ that is part of the current UE

sidelink configuration:

3> if _sl-MappedQoS-FlowsToAddList_ is included:

4> add the _SL-PQFI_ included in _sl-MappedQoS-FlowsToAddList_ to the corresponding sidelink DRB;

3> if _sl-MappedQoS-FlowsToReleaseList_ is included:

4> remove the _SL-PQFI_ included in _sl-MappedQoS-FlowsToReleaseList_ from the corresponding sidelink

DRB;

3> if the sidelink DRB release conditions as described in clause 5.8.9.1a.1.1 are met:

4> perform the sidelink DRB release procedure according to clause 5.8.9.1a.1.2;

3> else if the sidelink DRB modification conditions as described in clause 5.8.9.1a.2.1 are met:**Release 16** **225** **3GPP TS 38.331 V16.22.0 (2026-06)**

4> perform the sidelink DRB modification procedure according to clause 5.8.9.1a.2.2;

1> if the _RRCReconfigurationSidelink_ message includes the _sl-MeasConfig_:

2> perform the sidelink measurement configuration procedure as specified in 5.8.10;

1> if the _RRCReconfigurationSidelink_ message includes the _sl-CSI-RS-Config_:

2> apply the sidelink CSI-RS configuration;

1> if the _RRCReconfigurationSidelink_ message includes the _sl-LatencyBoundCSI-Report_:

2> apply the configured sidelink CSI report latency bound;

1> if the UE is unable to comply with (part of) the configuration included in the _RRCReconfigurationSidelink_ (i.e.

sidelink RRC reconfiguration failure):

2> continue using the configuration used prior to the reception of the _RRCReconfigurationSidelink_ message;

2> set the content of the _RRCReconfigurationFailureSidelink_ message;

3> submit the _RRCReconfigurationFailureSidelink_ message to lower layers for transmission;

1> else:

2> set the content of the _RRCReconfigurationCompleteSidelink_ message;

3> submit the _RRCReconfigurationCompleteSidelink_ message to lower layers for transmission;

NOTE 1: When the same logical channel is configured with different RLC mode by another UE, the UE handles

the case as sidelink RRC reconfiguration failure.

5.8.9.1.4 Void

5.8.9.1.5 Void

5.8.9.1.6 Void

5.8.9.1.7 Void

5.8.9.1.8 Reception of an _RRCReconfigurationFailureSidelink_ by the UE

The UE shall perform the following actions upon reception of the _RRCReconfigurationFailureSidelink_:

1> stop timer T400 for the destination, if running;

1> continue using the configuration used prior to corresponding _RRCReconfigurationSidelink_ message;

1> if UE is in RRC_CONNECTED:

2> perform the sidelink UE information for NR sidelink communication procedure, as specified in 5.8.3.3 or

clause 5.10.15 in TS 36.331 [10];

5.8.9.1.9 Reception of an _RRCReconfigurationCompleteSidelink_ by the UE

The UE shall perform the following actions upon reception of the _RRCReconfigurationCompleteSidelink_:

1> stop timer T400 for the destination, if running;

1> consider the configurations in the corresponding _RRCReconfigurationSidelink_ message to be applied.

5.8.9.1.10 Sidelink reset configuration

The UE shall:

1> release/clear current sidelink radio configuration of this destination received in the _RRCReconfigurationSidelink_;

1> release the sidelink DRBs of this destination, in according to clause 5.8.9.1a.1;**Release 16** **226** **3GPP TS 38.331 V16.22.0 (2026-06)**

1> reset the sidelink specific MAC of this destination.

NOTE 1: Sidelink radio configuration is not just the resource configuration but may include other configurations

included in the _RRCReconfigurationSidelink_ message except the sidelink DRBs of this destination.

NOTE 2: After the sidelink DRB release procedure, UE may perform the sidelink DRB addition according to the

current sidelink configuration of this destination, received in _sl-ConfigDedicatedNR,_ _SIB12_ and

_SidelinkPreconfigNR_, according to clause 5.8.9.1a.2.

5.8.9.1a Sidelink radio bearer management

5.8.9.1a.1 Sidelink DRB release

5.8.9.1a.1.1 Sidelink DRB release conditions

For NR sidelink communication, a sidelink DRB release is initiated in the following cases:

1> for groupcast, broadcast and unicast, if _slrb-Uu-ConfigIndex_ (if any) of the sidelink DRB is included in _sl-_

_RadioBearerToReleaseList_ in _sl-ConfigDedicatedNR_; or

1> for groupcast and broadcast, if no sidelink QoS flow with data indicated by upper layers is mapped to the

sidelink DRB for transmission, which is (re)configured by receiving _SIB1_2 or _SidelinkPreconfigNR_; or

1> for groupcast, broadcast and unicast, if _SL-RLC-BearerConfigIndex_ (if any) of the sidelink DRB is included in

_sl-RLC-BearerToReleaseList_ in _sl-ConfigDedicatedNR_; or

1> for unicast, if no sidelink QoS flow with data indicated by upper layers is mapped to the sidelink DRB for

transmission, which is (re)configured by receiving _SIB12_ or _SidelinkPreconfigNR_, and if no sidelink QoS flow

mapped to the sidelink DRB, which is (re)configured by receiving _RRCReconfigurationSidelink_, has data; or

1> for unicast, if _SLRB-PC5-ConfigIndex_ (if any) of the sidelink DRB is included in _slrb-ConfigToReleaseList_ in

_RRCReconfigurationSidelink_ or if _sl-ResetConfig_ is included in _RRCReconfigurationSidelink_; or

1> for unicast, when the corresponding PC5-RRC connection is released due to sidelink RLF being detected,

according to clause 5.8.9.3; or

1> for unicast, when the corresponding PC5-RRC connection is released due to upper layer request according to

clause 5.8.9.5.

5.8.9.1a.1.2 Sidelink DRB release operations

For each sidelink DRB, whose sidelink DRB release conditions are met as in clause 5.8.9.1a.1.1, the UE capable of NR

sidelink communication that is configured by upper layers to perform NR sidelink communication shall:

1> for groupcast and broadcast; or

1> for unicast, if the sidelink DRB release was triggered after the reception of the _RRCReconfigurationSidelink_

message; or

1> for unicast, after receiving the _RRCReconfigurationCompleteSidelink_ message, if the sidelink DRB release was

triggered due to the configuration received within the _sl-ConfigDedicatedNR,_ _SIB12_, _SidelinkPreconfigNR_ or

indicated by upper layers:

2> release the PDCP entity for NR sidelink communication associated with the sidelink DRB;

2> if SDAP entity for NR sidelink communication associated with this sidelink DRB is configured:

3> indicate the release of the sidelink DRB to the SDAP entity associated with this sidelink DRB (TS 37.324

[24], clause 5.3.3);

2> release SDAP entities for NR sidelink communication, if any, that have no associated sidelink DRB as

specified in TS 37.324 [24] clause 5.1.2;

1> for groupcast and broadcast; or

1> for unicast, after receiving the _RRCReconfigurationCompleteSidelink_ message, if the sidelink DRB release was

triggered due to the configuration received within the _sl-ConfigDedicatedNR_:**Release 16** **227** **3GPP TS 38.331 V16.22.0 (2026-06)**

2> for each _sl-RLC-BearerConfigIndex_ included in the received _sl-RLC-BearerToReleaseList_ that is part of the

current UE sidelink configuration:

3> release the RLC entity and the corresponding logical channel for NR sidelink communication, associated

with the _sl-RLC-BearerConfigIndex_.

1> for unicast, if the sidelink DRB release was triggered due to the reception of the _RRCReconfigurationSidelink_

message; or

1> for unicast, after receiving the _RRCReconfigurationCompleteSidelink_ message, if the sidelink DRB release was

triggered due to the configuration received within the _SIB12_, _SidelinkPreconfigNR_ or indicated by upper layers:

2> release the RLC entity and the corresponding logical channel for NR sidelink communication associated with

the sidelink DRB;

2> perform the sidelink UE information procedure in clause 5.8.3 for unicast if needed.

1> if the sidelink radio link failure is detected for a specific destination:

2> release the PDCP entity, RLC entity and the logical channel of the sidelink DRB for the specific destination.

5.8.9.1a.2 Sidelink DRB addition/modification

5.8.9.1a.2.1 Sidelink DRB addition/modification conditions

For NR sidelink communication, a sidelink DRB addition is initiated only in the following cases:

1> if any sidelink QoS flow is (re)configured by _sl-ConfigDedicatedNR_, _SIB12_, _SidelinkPreconfigNR_ and is to be

mapped to one sidelink DRB_,_ which is not established; or

1> if any sidelink QoS flow is (re)configured by _RRCReconfigurationSidelink_ and is to be mapped to a sidelink

DRB, which is not established;

For NR sidelink communication, a sidelink DRB modification is initiated only in the following cases:

1> if any of the sidelink DRB related parameters is changed by _sl-ConfigDedicatedNR_, _SIB12_, _SidelinkPreconfigNR_

or _RRCReconfigurationSidelink_ for one sidelink DRB_,_ which is established;

5.8.9.1a.2.2 Sidelink DRB addition/modification operations

For the sidelink DRB, whose sidelink DRB addition conditions are met as in clause 5.8.9.1a.2.1, the UE capable of NR

sidelink communication that is configured by upper layers to perform NR sidelink communication shall:

1> for groupcast and broadcast; or

1> for unicast, if the sidelink DRB addition was triggered due to the reception of the _RRCReconfigurationSidelink_

message; or

1> for unicast, after receiving the _RRCReconfigurationCompleteSidelink_ message, if the sidelink DRB addition was

triggered due to the configuration received within the _sl-ConfigDedicatedNR,_ _SIB12_, _SidelinkPreconfigNR_ or

indicated by upper layers:

2> if an SDAP entity for NR sidelink communication associated with the destination and the cast type of the

sidelink DRB does not exist:

3> establish an SDAP entity for NR sidelink communication as specified in TS 37.324 [24] clause 5.1.1;

2> (re)configure the SDAP entity in accordance with the _sl-SDAP-ConfigPC5_ received in the

_RRCReconfigurationSidelink_ or _sl-SDAP-Config_ received in _sl-ConfigDedicatedNR_, _SIB12_,

_SidelinkPreconfigNR_, associated with the sidelink DRB;

2> establish a PDCP entity for NR sidelink communication and configure it in accordance with the _sl-PDCP-_

_ConfigPC5_ received in the _RRCReconfigurationSidelink_ or _sl-PDCP-Config_ received in _sl-_

_ConfigDedicatedNR,_ _SIB12_, _SidelinkPreconfigNR_, associated with the sidelink DRB;**Release 16** **228** **3GPP TS 38.331 V16.22.0 (2026-06)**

2> establish a RLC entity for NR sidelink communication and configure it in accordance with the _sl-RLC-_

_ConfigPC5_ received in the _RRCReconfigurationSidelink_ or _sl-RLC-Config_ received in _sl-_

_ConfigDedicatedNR,_ _SIB12_, _SidelinkPreconfigNR_, associated with sidelink DRB;

2> if this procedure was due to the reception of a _RRCReconfigurationSidelink_ message:

3> configure the MAC entity with a logical channel in accordance with the _sl-MAC-_

_LogicalChannelConfigPC5_ received in the _RRCReconfigurationSidelink_ associated with the sidelink

DRB, and perform the sidelink UE information procedure in clause 5.8.3 for unicast if need;

2> else if this procedure was due to the reception of a _RRCReconfigurationCompleteSidelink_ message:

3> configure the MAC entity with a logical channel associated with the sidelink DRB, in accordance with the

_sl-MAC-LogicalChannelConfig_ received in the _sl-ConfigDedicatedNR_, _SIB12_, _SidelinkPreconfigNR;_

2> else (i.e. for groupcast/broadcast):

3> configure the MAC entity with a logical channel associated with the sidelink DRB, in accordance with the

_sl-MAC-LogicalChannelConfig_ received in the _sl-ConfigDedicatedNR_, _SIB12_, _SidelinkPreconfigNR_ and

assign a new LCID to this logical channel.

NOTE 1: When a sidelink DRB addition is due to the configuration by _RRCReconfigurationSidelink_, it is up to UE

implementation to select the sidelink DRB configuration as necessary transmitting parameters for the

sidelink DRB, from the received _sl-ConfigDedicatedNR_ (if in RRC_CONNECTED), _SIB12_ (if in

RRC_IDLE/INACTIVE), _SidelinkPreconfigNR_ (if out of coverage) with the same RLC mode as the one

configured in _RRCReconfigurationSidelink_.

For the sidelink DRB, whose sidelink DRB modification conditions are met as in clause 5.8.9.1a.2.1, the UE capable of

NR sidelink communication that is configured by upper layers to perform NR sidelink communication shall:

1> for groupcast and broadcast; or

1> for unicast, if the sidelink DRB modification was triggered due to the reception of the

_RRCReconfigurationSidelink_ message; or

1> for unicast, after receiving the _RRCReconfigurationCompleteSidelink_ message, if the sidelink DRB modification

was triggered due to the configuration received within the _sl-ConfigDedicatedNR,_ _SIB12_ or

_SidelinkPreconfigNR_:

2> reconfigure the SDAP entity of the sidelink DRB, in accordance with the _sl-SDAP-ConfigPC5_ received in the

_RRCReconfigurationSidelink_ or _sl-SDAP-Config_ received in _sl-ConfigDedicatedNR,_ _SIB12_,

_SidelinkPreconfigNR_, if included;

2> reconfigure the PDCP entity of the sidelink DRB, in accordance with the _sl-PDCP-ConfigPC5_ received in

the _RRCReconfigurationSidelink_ or _sl-PDCP-Config_ received in _sl-ConfigDedicatedNR,_ _SIB12_,

_SidelinkPreconfigNR_, if included;

2> reconfigure the RLC entity of the sidelink DRB, in accordance with the _sl-RLC-ConfigPC5_ received in the

_RRCReconfigurationSidelink_ or _sl-RLC-Config_ received in _sl-ConfigDedicatedNR,_ _SIB12_,

_SidelinkPreconfigNR_, if included;

2> reconfigure the logical channel of the sidelink DRB, in accordance with the _sl-MAC-_

_LogicalChannelConfigPC5_ received in the _RRCReconfigurationSidelink_ or _sl-MAC-LogicalChannelConfig_

received in _sl-ConfigDedicatedNR,_ _SIB12_, _SidelinkPreconfigNR_, if included.

5.8.9.1a.3 Sidelink SRB release

The UE shall:

1> if a PC5-RRC connection release for a specific destination is requested by upper layers; or

1> if the sidelink radio link failure is detected for a specific destination:

2> release the PDCP entity, RLC entity and the logical channel of the sidelink SRB for PC5-RRC message of

the specific destination;**Release 16** **229** **3GPP TS 38.331 V16.22.0 (2026-06)**

2> consider the PC5-RRC connection is released for the destination.

1> if PC5-S transmission for a specific destination is terminated in upper layers:

2> release the PDCP entity, RLC entity and the logical channel of the sidelink SRB(s) for PC5-S message of the

specific destination;

5.8.9.1a.4 Sidelink SRB addition

The UE shall:

1> if transmission of PC5-S message for a specific destination is requested by upper layers for sidelink SRB:

2> establish PDCP entity, RLC entity and the logical channel of a sidelink SRB for PC5-S message, as specified

in clause 9.1.1.4;

1> if a PC5-RRC connection establishment for a specific destination is indicated by upper layers:

2> establish PDCP entity, RLC entity and the logical channel of a sidelink SRB for PC5-RRC message of the

specific destination, as specified in clause 9.1.1.4;

2> consider the PC5-RRC connection is established for the destination.

5.8.9.2 Sidelink UE capability transfer

5.8.9.2.1 General

This clause describes how the UE compiles and transfers its sidelink UE capability information for unicast to the

initiating UE.

**UE UE**

_UECapabilityEnquirySidelink_

_UECapabilityInformationSidelink_

**Figure 5.8.9.2.1-1: Sidelink UE capability transfer**

5.8.9.2.2 Initiation

The UE may initiate the sidelink UE capability transfer procedure upon indication from upper layer when it needs

(additional) UE radio access capability information.

5.8.9.2.3 Actions related to transmission of the _UECapabilityEnquirySidelink_ by the UE

The initiating UE shall set the contents of _UECapabilityEnquirySidelink_ message as follows:

1> include in UE radio access capabilities for sidelink within _ue-CapabilityInformationSidelink_, if needed;

NOTE 1: It is up to initiating UE to decide whether _ue-CapabilityInformationSidelink_ should be included.

1> set _frequencyBandListFilterSidelink_ to include frequency bands for which the peer UE is requested to provide

supported bands and band combinations;

NOTE 2: The initiating UE is not allowed to send the _UECapabilityEnquirySidelink_ message without including the

field _frequencyBandListFilterSidelink._

1> submit the _UECapabilityEnquirySidelink_ message to lower layers for transmission.

5.8.9.2.4 Actions related to reception of the _UECapabilityEnquirySidelink_ by the UE

The peer UE shall set the contents of _UECapabilityInformationSidelink_ message as follows:**Release 16** **230** **3GPP TS 38.331 V16.22.0 (2026-06)**

1> include UE radio access capabilities for sidelink within _ue-CapabilityInformationSidelink_;

1> compile a list of "candidate band combinations" only consisting of bands included in

_frequencyBandListFilterSidelink_, and prioritized in the order of _frequencyBandListFilterSidelink_ (i.e. first

include band combinations containing the first-listed band, then include remaining band combinations containing

the second-listed band, and so on).

1> include into _supportedBandCombinationListSidelinkNR_ as many band combinations as possible from the list of

"candidate band combinations", starting from the first entry;

1> include the received _frequencyBandListFilterSidelink_ in the field _appliedFreqBandListFilter_ of the requested UE

capability;

1> submit the _UECapabilityInformationSidelink_ message to lower layers for transmission.

NOTE: If the UE cannot include all band combinations due to message size or list size constraints, it is up to UE

implementation which band combinations it prioritizes.

5.8.9.3 Sidelink radio link failure related actions

The UE shall:

1> upon indication from sidelink RLC entity that the maximum number of retransmissions for a specific destination

has been reached; or

1> upon T400 expiry for a specific destination; or

1> upon indication from MAC entity that the maximum number of consecutive HARQ DTX for a specific

destination has been reached; or

1> upon integrity check failure indication from sidelink PDCP entity concerning SL-SRB2 or SL-SRB3 for a

specific destination:

2> consider sidelink radio link failure to be detected for this destination;

2> release the DRBs of this destination, in according to clause 5.8.9.1a.1;

2> release the SRBs of this destination, in according to clause 5.8.9.1a.3;

2> discard the NR sidelink communication related configuration of this destination;

2> reset the sidelink specific MAC of this destination;

2> consider the PC5-RRC connection is released for the destination;

2> indicate the release of the PC5-RRC connection to the upper layers for this destination (i.e. PC5 is

unavailable);

2> if UE is in RRC_CONNECTED:

3> perform the sidelink UE information for NR sidelink communication procedure, as specified in clause

5.8.3.3;

NOTE: It is up to UE implementation on whether and how to indicate to upper layers to maintain the keep-alive

procedure [55].

5.8.9.4 Sidelink common control information

5.8.9.4.1 General

The sidelink common control information is carried by _MasterInformationBlockSidelink_. The sidelink common control

information may change at any transmission, i.e. neither a modification period nor a change notification mechanism is

used.

A UE configured to receive or transmit NR sidelink communication shall:

1> if the UE has a selected SyncRef UE, as specified in clause 5.8.6:**Release 16** **231** **3GPP TS 38.331 V16.22.0 (2026-06)**

2> ensure having a valid version of the _MasterInformationBlockSidelink_ message of that SyncRef UE;

5.8.9.4.2 Actions related to reception of _MasterInformationBlockSidelink_ message

Upon receiving _MasterInformationBlockSidelink_, the UE shall:

1> apply the values included in the received _MasterInformationBlockSidelink_ message.

5.8.9.4.3 Transmission of _MasterInformationBlockSidelink_ message

The UE shall set the contents of the _MasterInformationBlockSidelink_ message as follows:

1> if in coverage on the frequency used for the NR sidelink communication as defined in TS 38.304 [20].

2> set _inCoverage_ to _true_;

2> if _tdd-UL-DL-ConfigurationCommon_ is included in the received _SIB1_:

3> set _sl-TDD-Config_ to the value representing the same meaning as that is included in _tdd-UL-DL-_

_ConfigurationCommon,_ as described in TS 38.213, clause 16.1 [13];

2> else:

3> set _sl-TDD-Config_ to the value as specified in TS 38.213 [13], clause 16.1;

2> if _syncInfoReserved_ is included in an entry of configured _sl-SyncConfigList_ corresponding to the concerned

frequency from the received _SIB12:_

3> set _reservedBits_ to the value of _syncInfoReserved_ in the received _SIB12_;

2> else_:_

3> set all bits in _reservedBits_ to 0;

1> else if out of coverage on the frequency used for NR sidelink communication as defined in TS 38.304 [20]; and

the concerned frequency is included in _sl-FreqInfoToAddModList_ in _RRCReconfiguration_ or in _sl-FreqInfoList_

within _SIB12_:

2> set _inCoverage_ to _true_;

2> set _reservedBits_ to the value of the corresponding field included in the preconfigured sidelink parameters (i.e.

_sl-PreconfigGeneral_ in _SidelinkPreconfigNR_ defined in 9.3);

2> set _sl-TDD-Config_ to the value representing the same meaning as that is included in the corresponding field

included in the preconfigured sidelink parameters (i.e. _sl-PreconfigGeneral_ in _SL-PreconfigurationNR_

defined in 9.3) as described in TS 38.213, clause 16.1 [13];

1> else if out of coverage on the frequency used for NR sidelink communication as defined in TS 38.304 [20]; and

the UE selects GNSS as the synchronization reference and _sl-SSB-TimeAllocation3_ is not configured for the

frequency used in _SidelinkPreconfigNR_:

2> set _inCoverage_ to _true_;

2> set _reservedBits_ to the value of the corresponding field included in the preconfigured sidelink parameters (i.e.

_sl-PreconfigGeneral_ in _SidelinkPreconfigNR_ defined in 9.3);

2> set _sl-TDD-Config_ to the value representing the same meaning as that is included in the corresponding field

included in the preconfigured sidelink parameters (i.e. _sl-PreconfigGeneral_ in _SL-PreconfigurationNR_

defined in 9.3) as described in TS 38.213, clause 16.1 [13];

1> else if the UE has a selected SyncRef UE (as defined in 5.8.6):

2> set _inCoverage_ to _false_;

2> set _sl-TDD-Config_ and _reservedBits_ to the value of the corresponding field included in the received

_MasterInformationBlockSidelink_;**Release 16** **232** **3GPP TS 38.331 V16.22.0 (2026-06)**

1> else:

2> set _inCoverage_ to _false_;

2> set _reservedBits_ to the value of the corresponding field included in the preconfigured sidelink parameters (i.e.

_sl-PreconfigGeneral_ in _SidelinkPreconfigNR_ defined in 9.3);

2> set _sl-TDD-Config_ to the value representing the same meaning as that is included in the corresponding field

included in the preconfigured sidelink parameters (i.e. _sl-PreconfigGeneral_ in _SL-PreconfigurationNR_

defined in 9.3) as described in TS 38.213, clause 16.1 [13];

1> set _directFrameNumber_ and _slotIndex_ according to the slot used to transmit the SLSS, as specified in 5.8.5.3;

1> submit the _MasterInformationBlockSidelink_ to lower layers for transmission upon which the procedure ends;

5.8.9.5 Actions related to PC5-RRC connection release requested by upper layers

The UE initiates the procedure when upper layers request the release of the PC5-RRC connection as specified in TS

24.587 [57]. The UE shall not initiate the procedure for power saving purposes.

The UE shall:

1> if the PC5-RRC connection release for the specific destination is requested by upper layers:

2> discard the NR sidelink communication related configuration of this destination;

2> release the DRBs of this destination, in according to clause 5.8.9.1a.1;

2> release the SRBs of this destination, in according to clause 5.8.9.1a.3;

2> reset the sidelink specific MAC of this destination.

2> consider the PC5-RRC connection is released for the destination;

5.8.10 Sidelink measurement

5.8.10.1 Introduction

The UE may configure the associated peer UE to perform NR sidelink measurement and report on the corresponding

PC5-RRC connection in accordance with the NR sidelink measurement configuration for unicast by

_RRCReconfigurationSidelink_ message.

The NR sidelink measurement configuration includes the following parameters for a PC5-RRC connection:

**1. NR sidelink measurement objects:** Object(s) on which the associated peer UE shall perform the NR sidelink

measurements.

- For NR sidelink measurement, a NR sidelink measurement object indicates the NR sidelink frequency of

reference signals to be measured.

**2. NR sidelink reporting configurations:** NR sidelink measurement reporting configuration(s) where there can be

one or multiple NR sidelink reporting configurations per NR sidelink measurement object. Each NR sidelink

reporting configuration consists of the following:

- Reporting criterion: The criterion that triggers the UE to send a NR sidelink measurement report. This can

either be periodical or a single event description.

- RS type: The RS that the UE uses for NR sidelink measurement results. In this release, only DMRS is

supported for NR sidelink measurement.

- Reporting format: The quantities that the UE includes in the measurement report. In this release, only RSRP

measurement is supported.

**3. NR sidelink measurement identities:** A list of NR sidelink measurement identities where each NR sidelink

measurement identity links one NR sidelink measurement object with one NR sidelink reporting configuration.

By configuring multiple NR sidelink measurement identities, it is possible to link more than one NR sidelink**Release 16** **233** **3GPP TS 38.331 V16.22.0 (2026-06)**

measurement object to the same NR sidelink reporting configuration, as well as to link more than one NR

sidelink reporting configuration to the same NR sidelink measurement object. The NR sidelink measurement

identity is also included in the NR sidelink measurement report that triggered the reporting, serving as a

reference to the network.

**4. NR sidelink quantity configurations:** The NR sidelink quantity configuration defines the NR sidelink

measurement filtering configuration used for all event evaluation and related reporting, and for periodical

reporting of that NR sidelink measurement. In each configuration, different filter coefficients can be configured

for different NR sidelink measurement quantities.

Both UEs of the PC5-RRC connection maintains a NR sidelink measurement object list, a NR sidelink reporting

configuration list, and a NR sidelink measurement identities list according to signalling and procedures in this

specification.

5.8.10.2 Sidelink measurement configuration

5.8.10.2.1 General

The UE shall:

1> if the received _sl-MeasConfig_ includes the _sl-MeasObjectToRemoveList_ in the _RRCReconfigurationSidelink_:

2> perform the sidelink measurement object removal procedure as specified in 5.8.10.2.4;

1> if the received _sl-MeasConfig_ includes the _sl-MeasObjectToAddModList_ in the _RRCReconfigurationSidelink_:

2> perform the sidelink measurement object addition/modification procedure as specified in 5.8.10.2.5;

1> if the received _sl-MeasConfig_ includes the _sl-ReportConfigToRemoveList_ in the _RRCReconfigurationSidelink_:

2> perform the sidelink reporting configuration removal procedure as specified in 5.8.10.2.6;

1> if the received _sl-MeasConfig_ includes the _sl-ReportConfigToAddModList_ in the _RRCReconfigurationSidelink_:

2> perform the sidelink reporting configuration addition/modification procedure as specified in 5.8.10.2.7;

1> if the received _sl-MeasConfig_ includes the _sl-QuantityConfig_ in the _RRCReconfigurationSidelink_:

2> perform the sidelink quantity configuration procedure as specified in 5.8.10.2.8;

1> if the received _sl-MeasConfig_ includes the _sl-MeasIdToRemoveList_ in the _RRCReconfigurationSidelink_:

2> perform the sidelink measurement identity removal procedure as specified in 5.8.10.2.2;

1> if the received _sl-MeasConfig_ includes the _sl-MeasIdToAddModList_ in the _RRCReconfigurationSidelink_:

2> perform the sidelink measurement identity addition/modification procedure as specified in 5.8.10.2.3;

5.8.10.2.2 Sidelink measurement identity removal

The UE shall:

1> for each _sl-MeasId_ included in the received _sl-MeasIdToRemoveList_ that is part of the current UE configuration

in _VarMeasConfigSL_:

2> remove the entry with the matching _sl-MeasId_ from the _sl-MeasIdList_ within the _VarMeasConfigSL_;

2> remove the NR sidelink measurement reporting entry for this _sl-MeasId_ from the _VarMeasReportListSL_, if

included;

2> stop the periodical reporting timer and reset the associated information (e.g. _sl-TimeToTrigger_) for this _sl-_

_MeasId_.

NOTE: The UE does not consider the message as erroneous if the _sl-MeasIdToRemoveList_ includes any _sl-_

_MeasId_ value that is not part of the current UE configuration.**Release 16** **234** **3GPP TS 38.331 V16.22.0 (2026-06)**

5.8.10.2.3 Sidelink measurement identity addition/modification

The UE shall:

1> for each _sl-MeasId_ included in the received _sl-MeasIdToAddModList_:

2> if an entry with the matching _sl-MeasId_ exists in the _sl-MeasIdList_ within the _VarMeasConfigSL_:

3> replace the entry with the value received for this _sl-MeasId_;

2> else:

3> add a new entry for this _sl-MeasId_ within the _VarMeasConfigSL_;

2> remove the measurement reporting entry for this _sl-MeasId_ from the _VarMeasReportListSL_, if included;

2> stop the periodical reporting timer and reset the associated information (e.g. _sl-TimeToTrigger_) for this _sl-_

_MeasId_;

5.8.10.2.4 Sidelink measurement object removal

The UE shall:

1> for each sl-MeasObjectId included in the received sl-MeasObjectToRemoveList that is part of sl-MeasObjectList

in VarMeasConfigSL:

2> remove the entry with the matching _sl-MeasObjectId_ from the _sl-MeasObjectList_ within the

_VarMeasConfigSL_;

2> remove all _sl-MeasId_ associated with this _sl-MeasObjectId_ from the _sl-MeasIdList_ within the

_VarMeasConfigSL_, if any;

2> if a _sl-MeasId_ is removed from the _sl-MeasIdList_:

3> remove the measurement reporting entry for this _sl-MeasId_ from the _VarMeasReportListSL_, if included;

3> stop the periodical reporting timer and reset the associated information (e.g. _sl-TimeToTrigger_) for this _sl-_

_MeasId_.

NOTE: The UE does not consider the message as erroneous if the _sl-MeasObjectToRemoveList_ includes any _sl-_

_MeasObjectId_ value that is not part of the current UE configuration.

5.8.10.2.5 Sidelink measurement object addition/modification

The UE shall:

1> for each _sl-MeasObjectId_ included in the received _sl-MeasObjectToAddModList_:

2> if an entry with the matching _sl-MeasObjectId_ exists in the _sl-MeasObjectList_ within the _VarMeasConfigSL_,

for this entry:

3> for each _sl-MeasId_ associated with this _sl-MeasObjectId_ included in the _sl-MeasIdList_ within the

_VarMeasConfigSL_, if any:

4> remove the measurement reporting entry for this _sl-MeasId_ from the _VarMeasReportListSL_, if

included;

4> stop the periodical reporting timer and reset the associated information (e.g. _sl-TimeToTrigger_) for

this _sl-MeasId_;

3> reconfigure the entry with the value received for this _sl-MeasObject_;

2> else:

3> add a new entry for the received _sl-MeasObject_ to the _sl-MeasObjectList_ within _VarMeasConfigSL_.**Release 16** **235** **3GPP TS 38.331 V16.22.0 (2026-06)**

5.8.10.2.6 Sidelink reporting configuration removal

The UE shall:

1> for each _sl-ReportConfigId_ included in the received _sl-ReportConfigToRemoveList_ that is part of the current UE

configuration in _VarMeasConfigSL_:

2> remove the entry with the matching _sl-ReportConfigId_ from the _sl-ReportConfigList_ within the

_VarMeasConfigSL_;

2> remove all _sl-MeasId_ associated with the _sl-ReportConfigId_ from the _sl-MeasIdList_ within the

_VarMeasConfigSL_, if any;

2> if a _sl-MeasId_ is removed from the _sl-MeasIdList_:

3> remove the measurement reporting entry for this _sl-MeasId_ from the _VarMeasReportListSL_, if included;

3> stop the periodical reporting timer and reset the associated information (e.g. _sl-TimeToTrigger_) for this _sl-_

_MeasId_.

NOTE: The UE does not consider the message as erroneous if the _sl-ReportConfigToRemoveList_ includes any _sl-_

_ReportConfigId_ value that is not part of the current UE configuration.

5.8.10.2.7 Sidelink reporting configuration addition/modification

The UE shall:

1> for each sl-ReportConfigId included in the received sl-ReportConfigToAddModList:

2> if an entry with the matching _sl-ReportConfigId_ exists in the _sl-ReportConfigList_ within the

_VarMeasConfigSL_, for this entry:

3> reconfigure the entry with the value received for this _sl-ReportConfig_;

3> for each _sl-MeasId_ associated with this _sl-ReportConfigId_ included in the _sl-MeasIdList_ within the

_VarMeasConfigSL_, if any:

4> remove the measurement reporting entry for this _sl-MeasId_ from the _VarMeasReportListSL_, if

included;

4> stop the periodical reporting timer and reset the associated information (e.g. _sl-TimeToTrigger_) for

this _sl-MeasId_;

2> else:

3> add a new entry for the received _sl-ReportConfig_ to the _sl-ReportConfigList_ within the _VarMeasConfigSL_.

5.8.10.2.8 Sidelink quantity configuration

The UE shall:

1> for each received _sl-QuantityConfig_:

2> set the corresponding parameter(s) in _sl-QuantityConfig_ within _VarMeasConfigSL_ to the value of the

received _sl-QuantityConfig_ parameter(s);

1> for each _sl-MeasId_ included in the _sl-MeasIdList_ within _VarMeasConfigSL_:

2> remove the measurement reporting entry for this _sl-MeasId_ from the _VarMeasReportListSL_, if included;

2> stop the periodical reporting timer and reset the associated information (e.g. _sl-TimeToTrigger_) for this _sl-_

_MeasId_.**Release 16** **236** **3GPP TS 38.331 V16.22.0 (2026-06)**

5.8.10.3 Performing NR sidelink measurements

5.8.10.3.1 General

A UE shall derive NR sidelink measurement results by measuring one or multiple DMRS associated per PC5-RRC

connection as configured by the peer UE associated, as described in 5.8.10.3.2. For all NR sidelink measurement results

the UE applies the layer 3 filtering as specified in clause 5.5.3.2, before using the measured results for evaluation of

reporting criteria and measurement reporting. In this release, only NR sidelink RSRP can be configured as trigger

quantity and reporting quantity.

The UE shall:

1> for each _sl-MeasId_ included in the _sl-MeasIdList_ within _VarMeasConfigSL_:

2> if the _sl-MeasObject_ is associated to NR sidelink and the _sl-RS-Type_ is set to _dmrs_:

3> derive the layer 3 filtered NR sidelink measurement result based on PSSCH DMRS for the trigger

quantity and each measurement quantity indicated in _sl-ReportQuantity_ using parameters from the

associated _sl-MeasObject_, as described in clause 5.8.10.3.2.

2> perform the evaluation of reporting criteria as specified in clause 5.8.10.4.

5.8.10.3.2 Derivation of NR sidelink measurement results

The UE may be configured by the peer UE associated to derive NR sidelink RSRP measurement results per PC5-RRC

connection associated to the NR sidelink measurement objects based on parameters configured in the _sl-MeasObject_

and in the _sl-ReportConfig_.

The UE shall:

1> for each NR sidelink measurement quantity to be derived based on NR sidelink DMRS:

2> derive the corresponding measurement of NR sidelink frequency indicated quantity based on PSSCH DMRS

as described in TS 38.215 [9] in the concerned _sl-MeasObject_;

2> apply layer 3 filtering as described in clause 5.5.3.2;

5.8.10.4 Sidelink measurement report triggering

5.8.10.4.1 General

The UE shall:

1> for each _sl-MeasId_ included in the _sl-MeasIdList_ within _VarMeasConfigSL_:

2> if the _sl-ReportType_ is set to _sl-EventTriggered_ and if the entry condition applicable for this event, i.e. the

event corresponding with the _sl-EventId_ of the corresponding _sl-ReportConfig_ within _VarMeasConfigSL_, is

fulfilled for NR sidelink frequency for all NR sidelink measurements after layer 3 filtering taken during _sl-_

_TimeToTrigger_ defined for this event within the _VarMeasConfigSL_, while the _VarMeasReportListSL_ does not

include a NR sidelink measurement reporting entry for this _sl-MeasId_ (a first NR sidelink frequency triggers

the event):

3> include a NR sidelink measurement reporting entry within the _VarMeasReportListSL_ for this _sl-MeasId_;

3> set the _sl-NumberOfReportsSent_ defined within the _VarMeasReportListSL_ for this _sl-MeasId_ to 0;

3> include the concerned NR sidelink frequency in the _sl-FrequencyTriggeredList_ defined within the

_VarMeasReportListSL_ for this _sl-MeasId_;

3> initiate the NR sidelink measurement reporting procedure, as specified in clause 5.8.10.5;

2> else if the _sl-ReportType_ is set to _sl-EventTriggered_ and if the entry condition applicable for this event, i.e.

the event corresponding with the _sl-EventId_ of the corresponding _sl-ReportConfig_ within _VarMeasConfigSL_,

is fulfilled for NR sidelink frequency not included in the _sl-FrequencyTriggeredList_ for all NR sidelink

measurements after layer 3 filtering taken during _sl-TimeToTrigger_ defined for this event within the

_VarMeasConfigSL_ (a subsequent NR sidelink frequency triggers the event):**Release 16** **237** **3GPP TS 38.331 V16.22.0 (2026-06)**

3> set the _sl-NumberOfReportsSent_ defined within the _VarMeasReportListSL_ for this _sl-MeasId_ to 0;

3> include the concerned NR sidelink frequency in the _sl-FrequencyTriggeredList_ defined within the

_VarMeasReportListSL_ for this _sl-MeasId_;

3> initiate the NR sidelink measurement reporting procedure, as specified in 5.8.10.5;

2> else if the _sl-ReportType_ is set to _sl-EventTriggered_ and if the leaving condition applicable for this event is

fulfilled for NR sidelink frequency included in the _sl-FrequencyTriggeredList_ defined within the

_VarMeasReportListSL_ for this _sl-MeasId_ for all NR sidelink measurements after layer 3 filtering taken during

_sl-TimeToTrigger_ defined within the _VarMeasConfigSL_ for this event:

3> remove the concerned NR sidelink frequency in the _sl-FrequencyTriggeredList_ defined within the

_VarMeasReportListSL_ for this _sl-MeasId_;

3> if _sl-ReportOnLeave_ is set to _true_ for the corresponding reporting configuration:

4> initiate the NR sidelink measurement reporting procedure, as specified in 5.8.10.5;

3> if the _sl-FrequencyTriggeredList_ defined within the _VarMeasReportListSL_ for this _sl-MeasId_ is empty:

4> remove the NR sidelink measurement reporting entry within the _VarMeasReportListSL_ for this _sl-_

_MeasId_;

4> stop the periodical reporting timer for this _sl-MeasId_, if running;

2> if _sl-ReportType_ is set to _sl-Periodical_ and if a (first) NR sidelink measurement result is available:

3> include a NR sidelink measurement reporting entry within the _VarMeasReportListSL_ for this _sl-MeasId_;

3> set the _sl-NumberOfReportsSent_ defined within the _VarMeasReportListSL_ for this _sl-MeasId_ to 0;

3> initiate the NR sidelink measurement reporting procedure, as specified in 5.8.10.5, immediately after the

quantity to be reported becomes available for the NR sidelink frequency:

2> upon expiry of the periodical reporting timer for this _sl-MeasId_:

3> initiate the NR sidelink measurement reporting procedure, as specified in 5.8.10.5.

5.8.10.4.2 Event S1 (Serving becomes better than threshold)

The UE shall:

1> consider the entering condition for this event to be satisfied when condition S1-1, as specified below, is fulfilled;

1> consider the leaving condition for this event to be satisfied when condition S1-2, as specified below, is fulfilled;

1> for this NR sidelink measurement, consider the NR sidelink frequency corresponding to the associated _sl-_

_MeasObject_ associated with this event.

Inequality S1-1 (Entering condition)

_Ms – Hys > Thresh_

Inequality S1-2 (Leaving condition)

_Ms + Hys < Thresh_

The variables in the formula are defined as follows:

**_Ms_** is the NR sidelink measurement result of the NR sidelink frequency, not taking into account any offsets.

**_Hys_** is the hysteresis parameter for this event (i.e. _sl-Hysteresis_ as defined within _sl-ReportConfig_ for this event).

**_Thresh_** is the threshold parameter for this event (i.e. _s1-Threshold_ as defined within _sl-ReportConfig_ for this event).

**_Ms_** is expressed in dBm in case of RSRP.**Release 16** **238** **3GPP TS 38.331 V16.22.0 (2026-06)**

**_Hys_** is expressed in dB.

**_Thresh_** is expressed in the same unit as **_Ms_**.

5.8.10.4.3 Event S2 (Serving becomes worse than threshold)

The UE shall:

1> consider the entering condition for this event to be satisfied when condition S2-1, as specified below, is fulfilled;

1> consider the leaving condition for this event to be satisfied when condition S2-2, as specified below, is fulfilled;

1> for this NR sidelink measurement, consider the NR sidelink frequency indicated by the _sl-MeasObject_ associated

to this event.

Inequality S2-1 (Entering condition)

_Ms + Hys < Thresh_

Inequality S2-2 (Leaving condition)

_Ms – Hys > Thresh_

The variables in the formula are defined as follows:

**_Ms_** is the NR sidelink measurement result of the NR sidelink frequency, not taking into account any offsets.

**_Hys_** is the hysteresis parameter for this event (i.e. _sl-Hysteresis_ as defined within _sl-ReportConfig_ for this event).

**_Thresh_** is the threshold parameter for this event (i.e. _s2-Threshold_ as defined within _sl-ReportConfig_ for this event).

**_Ms_** is expressed in dBm in case of RSRP.

**_Hys_** is expressed in dB.

**_Thresh_** is expressed in the same unit as **_Ms_**.

5.8.10.5 Sidelink measurement reporting

5.8.10.5.1 General

**UE UE**

_MeasurementReportSidelink_

**Figure 5.8.10.5.1-1: NR sidelink measurement reporting**

The purpose of this procedure is to transfer measurement results from the UE to the peer UE associated.

For the _sl-MeasId_ for which the NR sidelink measurement reporting procedure was triggered, the UE shall set the _sl-_

_MeasResults_ within the _MeasurementReportSidelink_ message as follows:

1> set the _sl-MeasId_ to the measurement identity that triggered the NR sidelink measurement reporting;

1> if the _sl-ReportConfig_ associated with the _sl-MeasId_ that triggered the NR sidelink measurement reporting is set

to _sl-EventTriggered_ or _sl-Periodical_:

2> set _sl-ResultDMRS_ within _sl-MeasResult_ to include the NR sidelink DMRS based quantity indicated in the _sl-_

_ReportQuantity_ within the concerned _sl-ReportConfig_;

1> increment the _sl-NumberOfReportsSent_ as defined within the _VarMeasReportListSL_ for this _sl-MeasId_ by 1;

1> stop the periodical reporting timer, if running;**Release 16** **239** **3GPP TS 38.331 V16.22.0 (2026-06)**

1> if the _sl-NumberOfReportsSent_ as defined within the _VarMeasReportListSL_ for this _sl-MeasId_ is less than the _sl-_

_ReportAmount_ as defined within the corresponding _sl-ReportConfig_ for this _sl-MeasId_:

2> start the periodical reporting timer with the value of _sl-ReportInterval_ as defined within the corresponding _sl-_

_ReportConfig_ for this _sl-MeasId_;

1> else:

2> if the _sl-ReportType_ is set to _sl-Periodical_:

3> remove the entry within the _VarMeasReportListSL_ for this _sl-MeasId_;

3> remove this _sl-MeasId_ from the _sl-MeasIdList_ within _VarMeasConfigSL_;

1> submit the _MeasurementReportSidelink_ message to lower layers for transmission, upon which the procedure

ends.

5.8.11 Zone identity calculation

The UE shall determine an identity of the zone (i.e. Zone_id) in which it is located using the following formulae, if _sl-_

_ZoneConfig_ is configured:

_x_1= Floor (_x_ / _L_) Mod 64;

_y_1= Floor (_y_ / _L_) Mod 64;

Zone_id = _y_1 * 64 + _x_1.

The parameters in the formulae are defined as follows:

**L** is the value of _sl-ZoneLength_ included in _sl-ZoneConfig_;

**x** is the geodesic distance in longitude between UE's current location and geographical coordinates (0, 0) according

to WGS84 model [58] and it is expressed in meters;

**y** is the geodesic distance in latitude between UE's current location and geographical coordinates (0, 0) according to

WGS84 model [58] and it is expressed in meters.

NOTE: How the calculated zone_id is used is specified in TS 38.321 [3].

5.8.12 DFN derivation from GNSS

When the UE selects GNSS as the synchronization reference source, the DFN, the subframe number within a frame and

slot number within a frame used for NR sidelink communication are derived from the current UTC time, by the

following formulae:

_DFN_= Floor (0.1*(_Tcurrent_ –_Tref–OffsetDFN_)) mod 1024

_SubframeNumber_= Floor (_Tcurrent_ –_Tref–OffsetDFN_) mod 10

_SlotNumber_= Floor ((_Tcurrent_ –Tref–_OffsetDFN_)*2μ) mod (10*2μ)

Where:

**_Tcurrent_** is the current UTC time obtained from GNSS. This value is expressed in milliseconds;

**_Tref_** is the reference UTC time 00:00:00 on Gregorian calendar date 1 January, 1900 (midnight between Thursday,

December 31, 1899 and Friday, January 1, 1900). This value is expressed in milliseconds;

**_OffsetDFN_** is the value _sl-OffsetDFN_ if configured, otherwise it is zero. This value is expressed in milliseconds.

μ=0/1/2/3 corresponding to the 15/30/60/120 kHz of SCS for SL, respectively.

NOTE 1: In case of leap second change event, how UE obtains the scheduled time of leap second change to adjust

_Tcurrent_ correspondingly is left to UE implementation. How UE handles to avoid the sudden

discontinuity of DFN is left to UE implementation.**Release 16** **240** **3GPP TS 38.331 V16.22.0 (2026-06)**

NOTE 2: Void.


