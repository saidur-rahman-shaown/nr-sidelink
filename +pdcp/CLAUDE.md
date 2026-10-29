# PDCP (B9) — TS 38.323 V16.8.0, sidelink

## Status: built, level-1 and level-2 tests passing, wired into `+stack/`.
`Documentations/38323-g80.pdf` is local. The independent-verifier computed the PDU octets and a
full groupcast receive trace (in-order and out-of-order) from the spec text. Clause 7.1/7.2
exponents were read from rendered pages, because pdftotext drops them. The code matched every
value on the first run (`test_pdcp`).

| Module | Clause | Notes |
|---|---|---|
| `pdcpConfig` | 38.331 SL-PDCP-Config-r16; 6.3.2, 7.2, 7.3, 6.3.12 | labels → numbers; 12-bit SN enforced for gc/bc; t-Reordering is the receiving UE's input |
| `pdcpPduPack` / `pdcpPduParse` | 6.2.2.4, 6.2.2.6, 6.2.2.7, 6.3.x, 5.10 | gc/bc 2-byte header (SDU Type, R, SN); unicast D/C, SDU Type, SN, KNRP-sess ID = 0, no MAC-I |
| `securityProtect` | 5.8, 5.9 | pass-through stub with the COUNT-carrying interface; **raises** if security is active (TS 33.536 not built) |
| `pdcpTxInit` / `pdcpTxSdu` / `pdcpTxTimer` | 5.2.1, 5.2.3, 5.3, 7.3 | COUNT, SN = COUNT mod 2^N, one discardTimer per SDU as a deadline |
| `pdcpRxInit` / `pdcpRxPdu` / `pdcpRxTimer` | 5.2.2.1, 5.2.2.2, 5.2.4, 7.1 | HFN/COUNT derivation, duplicate discard, reordering, out-of-order delivery, t-Reordering |

## The PDB is enforced here
Each SLRB's `sl-DiscardTimer` in the stored config equals the PDB of the PQIs mapped to it
(`test_slrbConfig` asserts it). `stack.txSlot` hands every expiry to RLC (`rlc.*TxDiscard`). If
RLC still holds the SDU unsent, it is dropped and counted in `ue.stats.lostToDiscard`.
`pdcpTimerExpired` counts every expiry, including SDUs already on the air, and is **not** a loss
count.

An SDU that RLC has already started segmenting is not discarded (TS 38.322 5.4). It completes,
so it can arrive late. The first end-to-end run showed it: a 700-byte PQI-70 packet expired at
20 ms with its first segment already sent, and its tail went out at 22.5 ms. That is the spec
working as written. The timer bounds queueing, not delivery.

## Known traps (each has a test)
- **The groupcast/broadcast receiver holds its FIRST SDU for t-Reordering.** Clause 7.1 starts
  RX_DELIV at x − 0.5·2^(N−1), half a window below the first SN heard. The first SDU is therefore
  not at RX_DELIV and waits for t-Reordering, even on a loss-free link. Measured in `+stack`: a
  packet transmitted at slot 45 was delivered at slot 65 (t-Reordering 10 ms). With
  `sl-OutOfOrderDelivery` it goes up at once.
- **Window_Size is 2^(N−1)** and the gc/bc initial offset is 0.5·2^(N−1). pdftotext prints both
  as `2[...] – 1`. Read the rendered page.
- **With out-of-order delivery, a delivered SDU stays in the buffer until RX_DELIV passes it.**
  Duplicate detection needs it ("received before"). Removing it on delivery would let a
  duplicate through as a fresh SDU.
- **t-Reordering on an AM bearer must outlast RLC ARQ.** NR RLC AM delivers out of order, so
  PDCP is the layer that waits for a retransmitted SDU. With 10 ms on an AM bearer, the first
  end-to-end loss test recovered the lost SDU in RLC and then saw PDCP discard it as COUNT <
  RX_DELIV. `stack.defaults` therefore separates `tReorderingMs` (UM) and `tReorderingAmMs`.
- COUNT does not wrap (6.3.5). `pdcpTxSdu` raises at 2^32 rather than wrapping silently.

## Not built
ROHC (5.7, IP SDUs only; V2X SDUs are Non-IP, and `pdcpTxSdu` raises for IP). EHC (5.12).
Security (5.8/5.9, TS 33.536; stubbed). Status reports and data recovery (5.4/5.5, AM DRBs with
statusReportRequired, not configured on sidelink here). Duplication (5.11). Re-establishment and
suspend (5.1.2, 5.1.4).

## pending-human
- **The gc/bc first-SDU hold** (above): verifier and code agree. It is surprising and costs real
  latency on every new receiver, so it should be checked by eye against clause 7.1.
- **Out-of-order delivery and the in-order machinery.** The text of 5.2.2.1/5.2.2.2 does not
  explicitly exempt already-delivered SDUs from the in-order "deliver all stored". Read here as
  "each SDU delivered once". The verifier read it the same way.
- **The HFN of the gc/bc initial state** is the UE's choice (7.1 NOTE). It is taken as 1, the
  smallest value that keeps RX_DELIV positive.
