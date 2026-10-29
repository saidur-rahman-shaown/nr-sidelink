# Experiments — the report suite

Ours, not normative. Every experiment drives the existing engines and changes nothing inside them:
`+harness/+lls/` for anything MCS- or channel-specific, `+harness/+sls/` (through
`private/runLogged`, which only observes the unchanged slot loop) for anything multi-UE, and
`+harness/+field/` (the full stack, waveform level) where a layer the SLS lacks — RLC — is the
subject.

    matlab -batch "experiments.runAll()"                       % everything, ~1.5 h on 10 cores
    matlab -batch "s=experiments.settings(); s.scale='quick'; experiments.runAll(s)"   % smoke test
    matlab -batch "experiments.field()"                        % one experiment
    matlab -batch "experiments.waveDeploy()"                   % waveform deployment, ~40 min, not in runAll

**The study (current report, `report/REPORT.md`) is three parts**, run by `experiments.runStudy()`:
`macTutorial` (Part A: spec bounds, sensing, exclusion, SPS, event selection, built on the verified
TS 38.214 functions), `linkLevel` (Part B: real PHY, RMa LOS link with 3 m antennas, 3 + 3 dBi and
NF 9 dB (`settings().link`), so MCS 5 reaches 1500 m, range/throughput/latency vs distance at 0/10/20/30 mph; BLER from `measureSpeeds`,
which also registers per-speed tables for the SLS in `+harness/+phyabs/tables/`), and `systemLevel`
(Part C: 1 km x 1 km PPP drops, densities 5-100 /km^2, the five broadcast PQIs each against its own
PER, broadcast throughput at the receivers; C1 comes from `experiments.deployment`). Figures go to
`plots/study/`. The experiments listed below are the earlier, more detailed suite
(`report/archive/REPORT_v1_detailed.md`).

Figures: `plots/experiments/<experiment>/`. Data: `plots/experiments/data/<experiment>.mat`, and
`summary.json` from `exportSummary`. Shared knobs: `settings.m` (scale, seeds, the radio channel)
and `fieldConfig.m` (field size, PPP density, duration, traffic, policy).

| Experiment | Engine | Question |
|---|---|---|
| `slotStructure` | normative chains | what the S-SSB slot and the data slot (with/without PSFCH) carry, RE by RE; the pool timeline with S-SSB slots excluded |
| `sensingSelection` | SLS + `candidateSet` | what one UE senses, what survives exclusion, what it picks; S_A vs load |
| `linkCurves` | LLS | measured BLER vs SNR for MCS 0..27 (cached; three channel conditions) |
| `throughputMcs` | LLS curves | MCS 5/6/11/27 throughput vs SNR and distance, three HARQ modes, three conditions |
| `distance` | LLS curves + SLS | throughput/range for every MCS; PDB reliability and latency vs distance, HARQ none/blind/PSFCH |
| `rlcSegmentation` | full stack | SDU size past the max TBS: segments, reliability, latency |
| `latency` | SLS | latency vs PDB: baseline, load, P_rsvp, retx, MCS |
| `field` | SLS | PPP field, CAM + Poisson events: collisions, CBR, target-UE latency, PDB verdict |
| `eventStrategy` | SLS | which UE policy serves event-driven data best, at two densities |
| `cbrCapacity` | SLS | CBR vs the capacity a UE may still use (sl-CR-Limit staircase) and the operating envelope |
| `rxSensitivity` | LLS curves | received power vs LDPC+CRC sensitivity per MCS, and the range it gives |
| `waveDeploy` | `+harness/+deploy` | the field as summed waveforms in continuous time through Communications Toolbox TX/RX hardware; real vs ideal hardware vs no PDCP reordering hold; `abstractionCheck` calibrates the SLS SINR formula against the waveform decoder |

## The operating point
Every experiment runs at one point, `settings().op`: a **20 MHz** channel at **30 kHz / μ = 1**,
**5 sub-channels × 10 PRB = 50 PRB**, **23 dBm**, **TR 38.901 RMa**. `fieldScenario` and `lineRun`
apply it, `private/assertOperatingPoint` refuses any SLS run off it (called by `runLogged`), and
the link-level experiments check `linkCurves`' `.meta`. The first version of this suite ran its
system-level experiments on the SLS's own default pool (10 × 10 PRB, a 40 MHz channel) and nothing
noticed; the assertion exists because of that.

## PDB violations
`pdbViolations` collects, from every saved result, each configuration where a flow's on-time share
is below 1 − PER, with its shortfall and the measured context (collisions, CBR, distance, SDU size).
It writes `data/pdbViolations.csv`; `exportSummary` embeds it. The factor figures ring every
violating point in red.

## Definitions the figures rely on
- **PDB verdict** (`private/pdbVerdict`): PDB and PER are a pair (TS 23.287 5.4.4), so a flow passes
  when the fraction delivered *within* the PDB is at least 1 − PER. `PASS*` = consistent with the
  target but on fewer than 3/PER samples, so not demonstrated.
- **Per-link** (`private/linkPackets`): every (packet, receiver within range) pair; half-duplex and
  collision losses count. **Per-packet**: first decode at *any* receiver (`kpiReport`'s
  definition). Broadcast safety traffic is judged per link; per packet always looks better.
- **Collision**: two PSSCH in one slot sharing at least one sub-channel. *Same start* = their PSCCHs
  coincide too.
- **Throughput (link level)**: full-buffer rate of one link transmitting every slot — an upper
  bound Mode 2 does not reach. The field and CBR experiments give what a UE gets in a shared pool.

## Known traps
- **The shipped BLER table holds MCS {4 7 11 16 20} and `blerInterp` snaps to the nearest row.**
  An SLS run "at MCS 5" silently reads MCS 4. Every SLS experiment calls
  `private/assertTableMcs`; MCS outside the table belong to `linkCurves`.
- **Link curves are measured with 2 DM-RS symbols unless tagged.** At 120 km/h MCS ≥ 21 does not
  decode on a first transmission at any SNR (Doppler-limited channel estimation). The `_dmrs4`
  and `_v30` sets exist to show that this is the channel and pattern, not the code. The 3- and
  4-symbol patterns put a DM-RS in a PSCCH symbol; that interaction is not modelled
  (`harness.lls.linkConfig`), so those curves are a data-channel what-if.
- **Latency = (TX slot − arrival) + 3 slots, and T2 = PDB − 3 slots.** The TB is built during T1
  (T_proc,1); then 1 transmission slot and 2 slots to receive it (`settings().op.txSlots`,
  `.rxProcSlots`), and `private/linkPackets` adds those 3 slots. Mean = (T1 + T2)/2 + 3 slots, so the shortest latency is T1 + 3 slots = 4 ms and the longest is the PDB itself. The SLS
  reaches T2 = PDB − 3 slots through `decodeMarginSlots = 2` (`phy.rx.policy.pdbLogicalSlots`: the
  last start is n + PDB − margin − 1). `fieldScenario` and `lineRun` also set
  `policy.prepSlots = T_proc,1`. Without it, an SDU arriving while the UE held an SPS grant could
  ride an opportunity in its own arrival slot, and latencies of 1.5 ms appeared below the 4 ms
  floor. Before the pdbLogicalSlots fix, T2 could land on the discard slot itself, and a 10 ms
  event flow lost 8.5 % of its packets as "not sent" on an almost empty field.
- **Only PQIs 55–59 are broadcast** (TS 23.287 Table 5.4.4-1 NOTE 1: GBR and DC-GBR are unicast
  only). The study uses nothing else; the earlier suite's "PQI 55 = 100 ms CAM" came from a wrong
  `cfg.pqiTable` and now reads 58.
- **The SLS decodes a TB in the slot it is sent.** The 3-slot pipeline is added afterwards by
  `private/linkPackets`. `harness.kpiReport`'s latency does not include it, so the two differ by
  1.5 ms.
- **`fieldConfig()` inside this package is the repo's top-level `fieldConfig.m`** (the full-stack
  field), not `experiments.fieldConfig` — MATLAB does not import a package into itself.
  `rlcSegmentation` uses the former on purpose.
