# NR Sidelink — 3GPP Rel-16 Notes Index

Working notes for the Deer Sidelink Mode-2 simulator. All spec text is a verbatim
extract, reformatted for reading; source PDFs are in [`../`](../).

---

## Files

| # | File | Spec | Covers |
|---|---|---|---|
| 01 | [MAC Sidelink Procedures](01-TS38321-MAC-Sidelink-Procedures.md) | TS 38.321 §5.22–5.23 | SL grant reception, **TX resource (re-)selection check**, re-evaluation/pre-emption, SL HARQ entity + processes, PSFCH reception, HARQ-based SL RLF, LCP, SL-BSR, SR, CSI reporting |
| 02 | [PHY Sidelink Data Procedures](02-TS38214-PHY-Sidelink-Data-Procedures.md) | TS 38.214 §8 | PSSCH tx/rx, time/frequency resource allocation, MCS + TBS, **§8.1.4 Mode-2 candidate resource determination**, congestion control, DM-RS/CSI-RS/PT-RS, SL CSI |
| 03 | [RRC Sidelink Procedures](03-TS38331-RRC-Sidelink-Procedures.md) | TS 38.331 §5.8 | PC5-RRC connection, SidelinkUEInformationNR, SLSS + sync reference, SL rx/tx conditions, RRCReconfigurationSidelink, SL capability transfer, SL RLF, MIB-SL, SL measurement, zone ID, DFN derivation |
| 04 | [RRC ASN.1 IEs and Messages](04-TS38331-RRC-ASN1-IEs-and-Messages.md) | TS 38.331 §6, §9 | SBCCH/SCCH messages, **§6.3.5 sidelink IEs** (48 definitions incl. `SL-ResourcePool`, `SL-UE-SelectedConfig`, `SL-Thres-RSRP-List`), default configs, §9.3 pre-configuration |
| 05 | [UE Sidelink Control Procedures](05-TS38213-UE-Sidelink-Control-Procedures.md) | TS 38.213 §16 | S-SSB sync, power control (S-SSB/PSSCH/PSCCH/PSFCH), SL vs UL prioritisation, PSFCH HARQ-ACK on sidelink and forwarding on uplink, PSCCH tx |
| 06 | [**Mode-2 Sensing Working Reference**](06-Mode2-Sensing-WORKING-REFERENCE.md) | derived | The sensing/selection algorithm end to end with the math restored, plus a 20-item implementation checklist. **Start here for Mode-2 work.** |
| 07 | [Reconstructed Tables](07-Reconstructed-Tables.md) | derived | Every table whose grid the PDF extraction destroyed, re-read from the source PDFs |
| 08 | [Mode-2 Conformance Audit](08-Mode2-Conformance-Audit.md) | derived | `Version 3` scheduler scored against the file 06 checklist, with KPI impact and a staged work order |
| 09 | [TS38211 Sidelink Physical Channels and Signals](09-TS38211-Sidelink-Physical-Channels-and-Signals.md) | TS 38.211 §8 | PSSCH/PSCCH/PSBCH/PSFCH scrambling+modulation+RE mapping, DM-RS for each channel, PT-RS, CSI-RS, S-PSS/S-SSS (§8.4.2), S-SS/PSBCH block structure, sidelink numerology/antenna ports/resource grid (§8.2), sidelink timing (§8.5) |
| 10 | [TS38211 Frame Structure and Physical Resources](10-TS38211-Frame-Structure-and-Physical-Resources.md) | TS 38.211 §4 | Time units, numerologies, frame/subframe/slot structure (§4.3), antenna port definition (§4.4.1), resource grid/element/block definitions (§4.4.2–§4.4.4), bandwidth part (§4.4.5), carrier aggregation (§4.5) — full clause, all "as defined in clause 4" targets from file 09 |
| 11 | [TS38211 Generic Functions](11-TS38211-Generic-Functions.md) | TS 38.211 §5 | Modulation mapper (§5.1, all 6 schemes), pseudo-random/Gold sequence generator (§5.2.1), low-PAPR sequence generator type 1 incl. the 12-point base-sequence table PSFCH needs (§5.2.2), OFDM baseband signal generation (§5.3.1). Type-2 low-PAPR/PRACH/RIM-RS baseband stubbed (unused by sidelink) |
| 12 | [**TS38211 Uplink Support Procedures**](12-TS38211-Uplink-Support-Procedures.md) | TS 38.211 §6 (selected) | **§6.3.1.5 Precoding** (`W`=identity for PSSCH — top priority), **§6.3.2.2/.2.1/.2.2 sequence + cyclic shift hopping** (PSFCH `α` formula — 2nd priority), §6.3.2.1/§6.3.2.3 PUCCH format-0 context, **§6.4.1.1.3 DM-RS precoding+RE-mapping template** (PSSCH DM-RS — 2nd priority) incl. Tables 6.4.1.1.3-1/-2. PUSCH scrambling/PRACH/PUCCH formats 1–4/SRS stubbed (no sidelink citation) |
| 13 | [**TS38211 Downlink Support Procedures**](13-TS38211-Downlink-Support-Procedures.md) | TS 38.211 §7 (selected) | **§7.3.1.3 Layer mapping** Table 7.3.1.3-1 for ν∈{1,2} (top priority — resolves file 09's PSSCH layer-mapping gap), **§7.4.1.5 CSI-RS RE-mapping template** (§7.4.1.5.3, Table 7.4.1.5.3-1 rows 2–3 relevant to sidelink's X∈{1,2} restriction). PDCCH/PBCH/PDSCH DM-RS/PT-RS/RIM-RS/PRS/PSS-SSS/SS-PBCH-block stubbed (no sidelink citation, or already covered independently in file 09) |
| — | [`_raw/`](_raw/) | — | The original unedited pastes, kept for diffing |

---

## What was fixed

The five original files were raw PDF pastes. Applied to all of them:

- **Page furniture removed** — `**Release 16**`, `**3GPP TS 38.xxx V…**` and page
  numbers appeared ~280 times, often welded mid-sentence
  (`…link establishment (TS**Release 16** **211** **3GPP TS 38.331…**`).
- **Double-spacing collapsed** — every source line was followed by a blank line,
  so nothing rendered as a paragraph. ~6,100 blank lines removed.
- **Hard-wraps rejoined** — sentences split across 3–5 lines are now single
  paragraphs, including parameter names split mid-token
  (`_sl-_` + newline + `_MaxTxTransNumPSSCH_` → `_sl-MaxTxTransNumPSSCH_`).
- **Clause numbers promoted to headings** with a table of contents per file, so
  `5.22.1.2` is now navigable instead of being plain text.
- **3GPP conditional structure preserved** — the `1>` / `2>` / `3>` nesting that
  carries the normative logic is now indented lists rather than flat lines.
- **ASN.1 fenced** — 48 `-- ASN1START/STOP` blocks are code blocks; each message
  and IE definition is a heading and appears in the TOC.
- **Files renamed** by spec number and clause range, numbered in reading order.

Net: 12,400 lines → 5,100, with structure that was not there before.

> **One title was wrong, not just unclear:** `PDSCH Procedures - Rel 16 TS 38.214.md`
> contains TS 38.214 **clause 8**, which is *sidelink* (PSSCH/PSCCH). It has nothing
> to do with PDSCH. Renamed to file 02.

---

## Gaps — spec content referenced by these notes but not present

Ordered by how much it blocks the Mode-2 sensing work.

### 1. TS 38.215 — missing entirely (no PDF, no notes) 🔴

Referenced 10× across the notes. It defines the SL measurement quantities:

| Quantity | Clause | Needed for |
|---|---|---|
| **CBR** (Channel Busy Ratio) | §5.1.27 | `sl-CR-Limit` congestion control; CBR-dependent selection of MCS, sub-channel count and retransmission count (38.321 §5.22.1.1); `P_MAX,CBR` in power control (38.213 §16.2.1) |
| **CR** (Channel occupancy Ratio) | §5.1.28 | the `Σ_{i≥k} CR(i) ≤ CR_Limit(k)` check |
| **SL S-RSSI** | §5.1.26 | the input CBR is computed from |
| **SL PSSCH-RSRP / PSCCH-RSRP** | §5.1.24 / §5.1.25 | the exclusion threshold comparison in §8.1.4 step 6b — the core of sensing |

**Impact:** the RSRP *comparison* is fully specified in file 06, but the RSRP
*measurement definition* is not. Congestion control cannot be implemented to spec
without this. **Download `38215-g*.pdf` and extract §5.1.24–5.1.28.**

### 2. TS 38.212 §8.3–8.4 — SCI formats (PDF present, no notes) 🔴

`38212-gf0.pdf` is in `../` but was never extracted. Referenced 12×. Needed:

- **§8.3.1.1 SCI format 1-A** — the fields sensing actually decodes: `Priority`,
  `Frequency resource assignment`, `Time resource assignment`,
  `Resource reservation period`, `DMRS pattern`, `Additional MCS table indicator`,
  `PSFCH overhead indication`. File 02 §8.1.4 refers to these by name only.
- **§8.4 SCI format 2-A / 2-B** — cast type indicator, HARQ feedback enabled/disabled,
  source/destination ID. Drives PSFCH behaviour and the Table 16.3-2 vs 16.3-3 choice.
- **§8.4.4** — 2nd-stage SCI coded symbol count `N_RE^SCI,2`, which feeds TBS.

**Impact:** blocks a faithful SCI encoder/decoder, and therefore the sensing input.

### 3. TS 38.214 clause 5 — MCS and TBS tables (same PDF, not extracted) 🟠

The notes contain clause 8 only, but §8.1.3 defers to:

- **Tables 5.1.3.1-1/-2/-3** — the actual MCS→(`Q_m`, `R`) tables (64QAM, 256QAM, low-SE);
- **§5.1.3.2 steps 2)–4)** — the TBS quantisation procedure.

**Impact:** throughput and BLER KPIs depend on these. Extract clause 5.1.3 from
`38214-gh0.pdf` — everything else needed is already in file 02 / file 07.

### 4. ~~TS 38.211 §8.3–8.4 — physical channel definitions~~ — FIXED, see file 09 ✅

`38211-ga0.pdf` clause 8 (the entire "Sidelink" clause, §8.1–§8.5 — there is no
clause 9 in this document, clause 8 runs straight into Annex A) is now extracted
in full in [file 09](09-TS38211-Sidelink-Physical-Channels-and-Signals.md),
including PSSCH/PSCCH DM-RS sequence generation and mapping (§8.4.1.1, §8.4.1.3),
PSBCH DM-RS (§8.4.1.4), PT-RS (§8.4.1.2), CSI-RS (§8.4.1.5), S-PSS/S-SSS
(§8.4.2 — **not** §8.7/§8.8 as earlier guessed elsewhere in this project), the
S-SS/PSBCH block structure (§8.4.3), PSFCH sequence/cyclic-shift application
(§8.3.4), and the AGC-duplicate/guard-symbol rule (§8.2.1). File 09 also
cross-checks and corrects two assumptions previously used only as low-confidence
guesses in `+phy/+ts38211/CLAUDE.md`: S-PSS is one m-sequence at two cyclic
shifts {22, 65}, not two base sequences; and the guard-symbol rule (§8.2.1) only
places a guard *after* a PSFCH region, not before it — the symbol before PSFCH's
content is PSFCH's own AGC-role duplicate, not a guard.

**Clauses 4–7 of the same `38211-ga0.pdf` — FIXED, see files 10–13 ✅**

Frame structure/physical-resource definitions (§4, file 10), the generic
pseudo-random/Gold sequence generator and modulation mapper (§5, file 11), and
the sidelink-relevant slices of clauses 6 and 7 (file 12, file 13) are now
extracted. Specifically resolved, from file 09's original defer-table:

| Clause 8 subclause | Defers to | Now in | Status |
|---|---|---|---|
| §8.2.3.1, §8.2.3.2 | 4.3.1, 4.3.2 | file 10 | ✅ full |
| §8.2.4 | 4.4.1 | file 10 | ✅ full |
| §8.2.5 | 4.4.2 | file 10 | ✅ full |
| §8.2.6 | 4.4.3 | file 10 | ✅ full |
| §8.2.7 | 4.4.4 | file 10 | ✅ full |
| scrambling clauses | 5.2.1 | file 11 | ✅ full |
| modulation clauses | 5.1 | file 11 | ✅ full |
| §8.3.1.3 | 7.3.1.3 | file 13 | ✅ full — resolves the layer-mapping question blocking `slPSSCH.m` |
| §8.3.1.4, PT-RS §8.4.1.2.2 | 6.3.1.5 | file 12 | ✅ full — `W`=identity confirmed as pure pass-through |
| §8.3.4.2.1 (PSFCH) | 6.3.2.2 | file 12 | ✅ full — `α` formula fully closed, incl. `m0`/`m_cs` cross-check into files 05/07 |
| §8.4.1.1.2 (PSSCH DM-RS) | 6.4.1.1.3 | file 12 | ✅ full (frequency-domain template only; sidelink's own Table 8.4.1.1.2-1 supersedes the time-domain position tables) |
| §8.4.1.5.3 (CSI-RS) | 7.4.1.5.3 | file 13 | ✅ full (only the `X∈{1,2}`, `ρ=1` rows sidelink actually reaches) |

**Not fully re-extracted, by deliberate scope decision** (see each file's own "Gaps in this
extraction" section for the itemized cut list and PDF page pointers): PRACH (clause 6.3.3, no
sidelink equivalent exists at all), PUCCH formats 1–4 (clauses 6.3.2.4–6.3.2.6, no PSFCH analog
beyond format 0), SRS (§6.4.1.4, no sidelink equivalent), PDCCH/PBCH (§7.3.2/§7.3.3, no sidelink
citation), PDSCH/PDCCH/PBCH DM-RS and PT-RS (§7.4.1.1–§7.4.1.4, sidelink's own DM-RS/PT-RS are
independently specified in file 09), RIM-RS (§7.4.1.6, gNB-only), PRS (§7.4.1.7, not referenced),
Uu PSS/SSS and SS/PBCH block (§7.4.2, §7.4.3, sidelink's S-PSS/S-SSS/S-SS-PSBCH-block are
independently specified in file 09). None of these were ever in file 09's defer-table — they were
never a gap for this project — so nothing above is a regression from file 09's original scope.

- **TS 38.304 and TS 38.133** — cited once each in §8.5 for sidelink Tx timing
  (the "S criterion" and `N_TA,offset`/reference-frame-timing clauses). No PDF
  for either in `../`. Narrow impact: timing-advance detail only. **Still open** — files 10–13
  did not touch this (clause 4.3.1, file 10, defines the timing *relation* `N_TA,offset` feeds
  into but not the offset's own value, which lives in TS 38.133 as file 09 already found).

### 5. TS 38.321 clause 6 — MAC PDU / CE formats (PDF present, no notes) 🟡

`38321-gm0.pdf` is in `../`. §5.22 references the **SL-BSR / Truncated SL-BSR MAC CE**
formats and the SL-SCH subheader layout, none of which are extracted.

**Impact:** only matters once you model MAC PDU overhead exactly; the LCP and BSR
*procedures* are already in file 01.

### 6. Smaller items 🟡

- **TS 38.213 §9.2.5** (PUCCH overlap rules) — referenced by §16.5, not extracted.
  Mode-1 only; irrelevant to Mode-2.
- **TS 38.331 §6.3.5 ordering** — in file 04 the paste has §6.6 *before* §6.3.5,
  unlike the spec. Content is complete; the TOC gives correct navigation. Left as-is.
- **Tables 16.1-1 / 16.1-2** — the flattened paste in file 05 has cells out of
  order and is unusable. Corrected versions are in
  [file 07](07-Reconstructed-Tables.md#table-161-1-slot-configuration-period-when-one-pattern-is-indicated).

### What is *not* missing

Checked and complete — no action needed:

- TS 38.331 §5.8.1 through §5.8.12, including zone ID and DFN derivation.
- All 48 sidelink IEs in §6.3.5, including every Mode-2 sensing parameter
  (`sl-SensingWindow`, `sl-SelectionWindowList`, `sl-Thres-RSRP-List`,
  `sl-TxPercentageList`, `sl-RS-ForSensing`, `sl-PreemptionEnable`,
  `sl-ResourceReservePeriodList`, `sl-MultiReserveResource`, `sl-CR-Limit`,
  `sl-ProbResourceKeep`, `sl-ReselectAfter`).
- TS 38.321 §5.22.1.1 through §5.22.2.3 including §5.22.1.2a and §5.22.1.3.1a.
- TS 38.214 §8.1.1–8.1.7, §8.2–8.6.
- TS 38.213 §16.1–16.5.
- TS 38.211 §8.1–§8.5 in full (see file 09) — clause 8 is the entire document's
  sidelink content; there is no separate clause 9 to check for.
- TS 38.211 §4 in full (see file 10); §5.1, §5.2.1, §5.2.2 (see file 11); the sidelink-cited
  slices of §6 and §7 (see file 12, file 13) — every clause-8 "as defined in clause X" target
  for X ∈ {4,5,6,7} is now resolved. See files 12/13's own "Gaps in this extraction" for the
  deliberately-out-of-scope remainder of clauses 6–7 (PRACH, SRS, PUCCH formats 1–4, PDCCH,
  PBCH, RIM-RS, PRS, Uu PSS/SSS/SS-PBCH-block) — none of it was ever referenced by clause 8.
