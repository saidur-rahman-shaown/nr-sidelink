# NR Sidelink Mode 2 in an open field: report

**Start with [`REPORT.md`](REPORT.md).** It is a three-part tutorial: how the MAC picks resources,
what one link delivers on a real PHY, and what many UEs get in a 1 km × 1 km field.

The operating point is a 20 MHz channel at 5.9 GHz, 30 kHz SCS (μ = 1), 5 sub-channels × 10 PRB
(50 PRB) and 23 dBm. Propagation is TR 38.901 RMa line of sight, with antennas at 3 m (machinery cab roof), 3 dBi
each, and a 9 dB noise figure (TR 37.885 V15.3.0 Table 6.1.1-1); MCS 5 reaches 1500 m. Fading is TDL-D at 0/10/20/30 mph. The selection window
runs from T1 = 5 slots to T2 = PDB − 3 slots. Every latency includes 1 slot on the air and 2 slots
to receive, so the minimum is 4 ms. The traffic uses only the broadcast PQIs 55–59 of TS 23.287
Table 5.4.4-1, each judged against its own PER.

## Where to look for what

| Question | Section | Figures |
|---|---|---|
| What does the spec promise: earliest and latest transmission, latency per PQI? | A.1 | `figures/study/A_mac/A1_*`, `A2_*` |
| What does a UE sense, and what do the decoded SCIs reserve? | A.2 | `A3_sensed_scis.png` |
| How the candidate set is built, and RSRP threshold escalation | A.3 | `A4_exclusion.png`, `A5_threshold.png` |
| SPS for periodic traffic | A.4 | `A6_*`, `A7_*` |
| One-shot selection for event traffic | A.5 | `A8_event_selection.png` |
| 1000 packets per PQI on an empty channel: none over its PDB | A.6 | `A9_per_packet_latency.png` |
| SNR and received power against distance (RMa link budget) | B.1 | `figures/study/B_link/B1_*` |
| Effect of speed (0–30 mph) on the PHY | B.2, B.6 | `B2_*`, `B7_*` |
| Range per MCS (MCS 1–3 ≈ 2 km, MCS 5 ≈ 1.5 km) | B.3 | `B3_range.png` |
| Throughput against distance, MCS 5/6/11/27 | B.4 | `B4_throughput.png` |
| Latency and reliability against distance, per PQI | B.5 | `B5_*`, `B6_*` |
| Traffic flows; how UEs are distributed (PPP) and one sample drop | C.1 | `C1_deployment.png` |
| Reliability, latency, broadcast throughput, collisions and failures against UE density (5–100 /km²), each PQI judged against its own PER | C.2–C.7 | `figures/study/C_system/` |

## Regenerating

From the repository root:

```matlab
experiments.runStudy()
```

This runs about 2–3 hours on 6 workers and writes to `plots/study/`. The figures here are copies of
that folder.

The previous, more detailed study is in [`archive/REPORT_v1_detailed.md`](archive/REPORT_v1_detailed.md).
It covers RMa path loss, the waveform deployment, RLC segmentation and the event-strategy comparison;
its figures are in `figures/` and its data in `data/`.
