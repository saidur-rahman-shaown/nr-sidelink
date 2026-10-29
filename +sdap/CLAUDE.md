# SDAP (B9) — TS 37.324 V19.0.0 (`Documentations/37324-j00 2.pdf`)

## Status: built, tested, wired into `+stack/`, and now checked against the PDF.
The local document is Rel-19. Its sidelink content (clauses 5.2.3/5.2.4, 6.2.1, 6.2.2.4, 6.3.3,
6.3.8) has not changed since Rel-16, so it is used for this Rel-16 stack. `+cfg/specVersions.json`
records the version and the reason.
- **The QoS-flow → SLRB mapping rules** come from the TS 38.331 IEs: `sl-MappedQoS-FlowsList-r16`,
  `sl-DefaultRB-r16` (at most one per destination), `sl-CastType-r16` and `sl-SDAP-Header-r16`
  ("present if sl-DefaultRB is true").
- **The header** is clause 6.2.2.4: one octet D/C | R | PQFI(6), **unicast only**. Clause 6.2.1:
  "SDAP header is not present for groupcast and broadcast". D/C = 1 is a data PDU (6.3.3). A
  D/C = 0 PDU is an End-Marker control PDU (6.2.3): `sdapPduParse` recognises it and does not
  deliver it. Sending one (a QoS-flow remap) is not built.

### The earlier version had the gc/bc rule backwards
Before the PDF arrived, the recalled rule was "a gc/bc receiver cannot know the header setting,
so require the header on every gc/bc SLRB". Clause 6.2.1 says the opposite. It is now
`stack.ueInit` (`stack:ueInit:gcBcHeader`) and `cfgValidate` check 16c that **reject** a header
on a gc/bc SLRB, and gc/bc receivers never strip one. One consequence: the default-SLRB rule
needs a header, so only a unicast SLRB can be the default.

| Module | Notes |
|---|---|
| `sdapRules` | the configured SLRBs → flat rule arrays (PQI, SLRB, cast) plus default SLRB per cast type |
| `sdapTxMap` | PQI + cast type → SLRB: a matching rule, else the default, else **0 (no bearer)** |
| `sdapPduPack` / `sdapPduParse` | header present/absent per SLRB |
| `castCode` | `sl-CastType` label → this package's 1/2/3 code (not the SCI-2A cast type) |

## The priority path, PQI to SCI-1A (the trace this package was asked to document)
1. The application tags the packet with its **PQI** (`stack.appSend`).
2. `sdapTxMap` maps PQI + cast type to an **SLRB** using the stored config's
   `sl-MappedQoS-FlowsList`.
3. The SLRB's RLC bearer carries **`sl-MAC-LogicalChannelConfig.sl-Priority`**
   (`mac.slLchConfig`).
4. That priority orders **LCP** (`mac.slLcp`). It is `prio_TX` in Mode-2 selection
   (`phy.ts38214.candidateSet`'s p_j, which picks the RSRP threshold and the
   `sl-TxPercentage`). It is also SCI-1A's **Priority** field: the highest priority among the
   logical channels in the MAC PDU (TS 38.321 5.22.1.3.1).

The PQI's own priority level reaches SCI-1A only because the stored config sets each logical
channel's `sl-Priority` to the PQI priority of the flows it carries. `test_slrbConfig` asserts
that. `test_stack` asserts that, for every mapped PQI, the priority a receiver decodes from the
waveform equals `cfg.pqiTable`'s.

## Known traps
- **Rules match on cast type as well as PQI.** PQI 89 maps to different SLRBs for broadcast and
  unicast, with different RLC modes.
- **No rule and no default means no bearer.** The packet is refused and counted
  (`ue.stats.noBearer`), never put on an invented bearer. `cfgValidate` check 17 rejects a
  configured PQI that maps nowhere.
- **A gc/bc receiver needs no header knowledge.** Clause 6.2.1 removes the header from gc/bc
  entirely, so the receiver's only question is unicast or not, and it learns that from SCI-2.
- `SL-PQFI-r16` is INTEGER (1..64) but the QFI field is 6 bits (0..63). `sdapPduPack` encodes the
  value and rejects 64. Clause 6.3.8 gives the field and no offset, so the range mismatch is
  between 38.331 and 37.324 themselves (still pending-human).
