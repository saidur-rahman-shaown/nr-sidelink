# Experiment design for an NR sidelink validation and performance study

Date: 2026-10-26. Status: proposed study protocol, before collecting publication results.

This plan targets the current MATLAB NR sidelink Mode 2 platform. The selected publication
focus combines general platform validation with an agricultural/industrial open-field case
study. Road V2X is an optional reference comparison. Numerical
budgets and acceptance margins below are proposed research choices, not IEEE requirements or
3GPP certification limits. Freeze them after a separate pilot and before the main campaigns.

## 1. Paper objective and claims

Suggested working title:

**A Reproducible Validation and Performance Characterization of an NR Sidelink Mode 2 Platform**

Application-focused alternative: **Validation and Performance Characterization of NR Sidelink
Mode 2 for Agricultural Field Communications**.

Organize the paper around explicit, falsifiable claims:

1. Selected implemented protocol procedures agree with independent reference cases under the
   specified release, configuration, and parameter coverage.
2. The practical waveform receiver has characterized control, data, synchronization, and
   feedback performance, with quantified statistical uncertainty.
3. The system-level abstraction predicts waveform outcomes within a declared operating domain
   and error margin.
4. Scheduling, congestion, receiver limitations, and upper-layer behavior explain the measured
   deadline-reliability operating envelope.

Broad coverage supports a platform paper, but the scientific contribution must also explain
something: for example, where abstraction breaks, which mechanism dominates deadline failures,
or how an implementation choice changes the reliability/capacity tradeoff. Compare the claimed
contribution with relevant prior work before fixing the final novelty statement.

Describe software-generated results as a simulation-based experimental study. Physical
receiver validation requires independent device measurements. A waveform simulated through an
RF impairment model remains a simulation.

## 2. Scope and reference freeze

Maintain a feature-to-evidence matrix with four statuses: implemented and validated,
implemented with limited evidence, planned, or outside the paper's scope. Each entry needs:

```text
feature_id, specification_version, clause, implementation_entry_point,
supported_parameters, reference_source, experiment_id, acceptance_rule,
result_artifact, known_deviation
```

Use the project's [specVersions.json](../+cfg/specVersions.json) as the starting manifest, then
audit it. The PHY/MAC baseline is Release 16, while the current SDAP and QoS documents include
Release 19 versions. Document which later text is used and why its relevant provisions apply.
The current manifest's TR 37.885 and PC5-S entries are explicitly unverified placeholders.

TR 37.885 V15.3.0 supplies V2X evaluation assumptions and metrics. Use its exact scenario and
metric definitions when reporting a result as a reproduction of that methodology; label
custom scenarios separately. [TR 37.885](https://atisorg.s3.amazonaws.com/archive/3gpp-documents/Rel15/ATIS.3GPP.37.885.V1530.pdf)

Select applicable receiver-performance cases from the chosen Release 16 versions of
[TS 38.101-4](https://www.etsi.org/deliver/etsi_ts/138100_138199/13810104/16.14.00_60/ts_13810104v161400p.pdf)
and [TS 38.521-4](https://www.etsi.org/deliver/etsi_ts/138500_138599/13852104/16.10.00_60/ts_13852104v161000p.pdf).
Record complete case identifiers, antenna configuration, reference channels, SNR/power
conventions, transport format, and statistical decision procedure. A custom SISO test cannot
establish compliance with a case requiring a different antenna configuration.

Current scope restrictions to carry into the matrix include:

- The full stack supports an all-slot pool, PRB-zero BWP/pool placement, and PSFCH periods 0 or 1.
  Other pool timing and PSFCH periods need implementation work before equivalent full-stack tests.
- Broadcast and unicast are the main validated data paths. Groupcast NACK-only behavior needs
  its own SCI, zone/range, resource, and feedback campaign.
- Mode 1, PC5-S signaling, PC5-RRC exchange, security, and other absent features require separate
  implementation and evidence before entering the claimed coverage.
- The SLS path does not include the complete SDAP/PDCP/RLC behavior used by `+stack/`.

Use equivalence classes, parameter boundaries, and targeted interactions to cover large
configuration spaces. Report the covered combinations instead of implying that testing a few
examples exhausts every valid Cartesian combination.

## 3. Entry conditions for publication campaigns

The six findings of the 2026-10-26 review (formerly BUGS_TO_ADDRESS.md) were all confirmed and
fixed on 2026-10-28, each with a regression test in
[test_reviewFixes.m](../+test/+unit/+harness/test_reviewFixes.m); the 80-UE receive-process
check in `test_sls` now passes with zero drops. Summarised in `+harness/CLAUDE.md`, Known traps.

Additional issues to address in the study design:

1. The current report documents a PSSCH mapping deviation: data mapping starts at the first
   DM-RS symbol. Check the mapping against the frozen time/frequency mapping clauses and correct
   it before claiming conformance of the affected waveform and capacity results.
2. `harness.kpiReport` and the experiment helpers use different latency conventions. The SLS
   decodes in the transmission slot; experiment postprocessing adds a three-slot pipeline.
   Establish common measurement boundaries before comparing engines.
3. Current study defaults use only three seeds. Treat those runs as exploratory until the
   uncertainty and independent-replication plan below is satisfied.
4. The current RMa deployment uses antenna heights outside the model's stated base-station
   range. Validate propagation for the intended geometry or identify this as an extrapolation.
5. Freeze the actual simulation configuration and BLER-table metadata together. The current
   measured tables do not automatically validate every MCS, allocation width, numerology,
   channel profile, speed, DM-RS pattern, or receiver revision.

Keep these entry conditions separate from research comparisons. A disabled mandatory
procedure is a diagnostic ablation, not another standards-compliant baseline.

## 4. Validation ladder and independent evidence

| Level | Question | Reference and acceptance approach |
|---|---|---|
| V0: bookkeeping and physics | Are units, time, power, and packet counts correct? | Analytical identities and injected events with known timestamps/powers |
| V1: protocol procedures | Do bits, mappings, state transitions, and timers implement the selected clauses? | Independent worked examples and externally sourced vectors where available |
| V2: waveform receiver | How does this receiver perform? | Applicable reference-channel tests and independent receiver/reference results |
| V3: abstraction | Does the SLS reproduce the waveform under matched conditions? | Held-out waveform cases and predefined equivalence margins |
| V4: deployment | Do system conclusions persist across layouts, loads, and mobility? | Independent drops, sensitivity analysis, and an independent simulator/calibration case |
| V5: physical validation | Does the model describe actual devices and propagation? | Conducted and over-the-air measurements with uncertainty budgets |

Round trips establish encoder/decoder consistency. They need independent examples to establish
that both sides have interpreted the specification correctly. Agreement with a wrapper that
calls the same underlying toolbox algorithm is useful integration evidence, but its shared
dependency must be disclosed.

Split calibration and validation: fit propagation, impairment, or abstraction parameters on
one dataset, freeze them, and evaluate on independent holdout cases. For example, choosing
antenna/channel parameters to obtain a 1.5 km range and then matching that same range is not an
independent range validation.

## 5. Campaign matrix

| ID | Aspect and controlled experiment | Factors | Measurements | Main platform entry points |
|---|---|---|---|---|
| E00 | Deterministic integrity | Numerology, grid size, payload and header boundaries, slot wrap | Packet conservation, power conservation, timestamp ordering, TBS/RE accounting | `test.runAllTests`, `+sap/`, `+cfg/`, `+phy/` |
| E01 | Synchronization and broadcast acquisition | SNR, delay, CFO, Doppler, sidelink identity | Detection probability, false alarms, timing/CFO error, PSBCH BLER | `harness.lls.syncSlot`, `+phy/+rx/+sync/` |
| E02 | Control and data PHY | Valid MCS, TBS/width, DM-RS pattern, AWGN and fading | PSCCH BLER, SCI-2 BLER, TB BLER, channel-estimation error, throughput | `harness.lls.linkSlot`, `blerSweep`, `experiments.linkCurves` |
| E03 | Noise and receiver sensitivity | NF, input power, bandwidth, FFT size | Measured per-RE variance/SNR, BLER versus received power, sensitivity at a declared BLER | `rf.noiseFloorDbm`, `noiseScale`, `experiments.rxSensitivity` |
| E04 | HARQ and PSFCH | No repeat, blind repeats, feedback, RV sequence, ACK/NACK/DTX, missed attempts | Failure probability after each attempt, false ACK/NACK, DTX, combining gain, latency, resource cost | `harness.lls.linkHarq`, `+stack/`, `+mac/`, PSFCH chains |
| E05 | Mode 2 sensing and selection | Known reservations, unmonitored slots, hidden terminals, priorities, thresholds | Candidate-set membership, exclusion cause, threshold escalation, chosen resource, legal timing | `candidateSet`, `resourcePickChained`, `experiments.sensingSelection` |
| E06 | Reservation lifecycle | Reservation period, keep probability, reselection counter, traffic phase | Reservation duration, counter evolution, idle occupancy, collision persistence, reselection latency | `+mac/grant*`, `+harness/+sls/`, `experiments.macTutorial` |
| E07 | Re-evaluation and pre-emption | Introduced reservation conflicts and higher-priority flows | Trigger timing, replacement legality, displaced-resource effects, priority outcomes | `+mac/reevaluation`, `+mac/preemption`, SLS traces |
| E08 | Congestion and fairness | Density, packet rate/size, priority mix, CR limits | CBR/CR accuracy, deadline reliability, goodput, per-UE fairness, drops by cause | `experiments.cbrCapacity`, `field`, `systemLevel` |
| E09 | Upper layers and mixed destinations | RLC UM/AM, segmentation, loss bursts, reordering, sequence wrap, timers | Byte-exact delivery, duplicates, reassembly, timer effects, latency decomposition | `test.runRlcTests`, `test.runStackTests`, `experiments.rlcSegmentation`, `runField` |
| E10 | RF and interference | Timing/CFO, PA backoff, IQ imbalance, ADC resolution, near-far ratio, partial overlap | EVM, clipping, measured interference, BLER, capture, adjacent-resource effects supported by the model | `+rf/`, `runDeploy`, `experiments.waveDeploy` |
| E11 | Abstraction validation | Matched waveform/SLS allocations and interference traces | BLER discrepancy, SNR-threshold discrepancy, reliability/latency discrepancy | `test_agreement`, `harness.deploy.abstractionCheck`, new matched-case driver |
| E12 | Application operating envelope | Geometry, mobility, density, offered load, event bursts, policy | Deadline reliability versus distance/load, reception gaps, capacity boundary | `experiments.systemLevel`, `field`, waveform spot checks |
| E13 | Physical holdout validation | Conducted attenuation and controlled outdoor geometry | Power/NF calibration, measured BLER/sensitivity, prediction residuals | External devices; import timestamped traces into analysis |

For each campaign, write a short protocol containing: research question; hypothesis; independent
variable; controlled variables; observational unit; reference; run count; primary endpoint;
acceptance criterion; expected artifact; and anticipated failure signatures.

### Examples of deterministic checks

- Candidate resources exactly match a hand-constructed small sensing scenario, including boundary
  slots, hypothetical reservations for unmonitored slots, chained reservations, and priority pairs.
- Known injected receive power produces the expected RSRP/RSSI with documented RE normalization.
- The total packet count partitions into terminal outcomes and explicitly censored packets.
- An ACK, NACK, silence, duplicate TB, or missed control decode causes the expected HARQ transition.
- A successful CRC never bypasses destination filtering, and duplicate transport blocks do not
  produce duplicate application deliveries.
- Slot/pool conversions remain valid across the DFN wrap and across excluded physical slots.

## 6. Research questions, baselines, and interventions

| Research question | Hypothesis to test | Comparison |
|---|---|---|
| What limits short-deadline reliability? | Selection/queueing dominates at low load; collision and receiver limits become important as load rises | Measured non-overlapping latency stages and per-packet event traces |
| When does feedback help? | Feedback reduces unnecessary transmissions, but its overhead and failures change the capacity benefit | Matched intended links, no-repeat/blind/feedback cases, with resource and energy accounting |
| When is the PHY abstraction adequate? | Average-SINR lookup loses accuracy under selective interference and unequal HARQ observations | Held-out waveform cases with partial overlap, fades, and missed receptions |
| Which policy improves the operating envelope? | A declared window/resource policy changes the latency-contention tradeoff | Frozen implementation baseline and one or two separately specified policies |
| What causes upper-layer tails? | Reassembly and reordering timers can dominate some delivery tails | Full-stack timer and segmentation interventions at fixed radio traces |

Use controlled two-/three-device topologies before large deployments: clean link, equal-power
collision, near-far capture, partial overlap, hidden terminal, and half-duplex conflict. These
provide identifiable mechanisms that a density sweep alone cannot isolate.

Keep intended receivers, payload demand, power limits, and resource pool comparable between
methods. PSFCH changes usable data resources, and unicast/broadcast have different delivery
semantics; record both effects rather than attributing every difference to ACK suppression.

When multiple mechanisms overlap, record their observed events separately. A collision flag
does not prove that the collision caused the packet loss. Use paired interventions or controlled
topologies for causal attribution; label heuristic loss categories as heuristic.

## 7. Scenario and factor selection

Use three scenario families:

1. **Diagnostic:** static two-/three-device layouts and analytically controlled AWGN/interference.
2. **Reference V2X:** reproduce a selected TR 37.885 highway and/or urban case with the specified
   geometry, mobility, traffic, channel, and antenna assumptions. Implement missing model features
   before presenting this as a matched reference case.
3. **Application extension:** an open field or agricultural/industrial layout with independently
   justified antenna heights, gains, mobility, obstructions, and propagation. A uniform spatial
   point process is a custom deployment assumption, not a substitute for a specified road layout.

### Selected application: agricultural/industrial field

Use the platform validation as the first contribution and the field operating envelope as the
second. Include these scenarios with the same packet definitions and radio reference planes:

| Scenario | Deployment / movement | Main question |
|---|---|---|
| A0: controlled field link | Two machines, controlled separation and antenna placement | Does an independently calibrated propagation/receiver model predict held-out link results? |
| A1: coordinated machines | Leader/follower or harvester/cart trajectories, including changing relative positions | What deadline reliability and reception-gap distribution does the coordination flow obtain? |
| A2: shared field | Multiple machines on parallel passes, headland turns, and uneven clusters | How do contention, topology, and spatial reuse change the operating envelope? |
| A3: blockage and near-far | Large machine bodies, equipment, crop/structure obstruction where supported by data, and a nearby interferer | Which failure mechanisms dominate when average distance alone is insufficient? |
| A4: machine-to-coordinator | Unicast telemetry to another UE or UE-type field gateway | How do HARQ, RLC AM, segmentation, and reordering alter reliability and delay? |

A field gateway in this study uses PC5 as a UE-type endpoint; a cellular Uu/base-station path
would be a separate system model. Use actual mission trajectories if available. A uniform PPP
drop is a diagnostic density experiment; its realism for coordinated machinery needs justification.

Proposed application factors are static operation and 5/15/30 km/h motion; periodic awareness,
isolated event notifications, synchronized event bursts, and unicast telemetry; and field sizes
such as 500 m by 500 m and 1 km by 1 km. These are design candidates to replace with deployment
requirements or measured traces. Sweep relevant service ranges independently of the field size,
and report communication reliability at each range instead of choosing a desired range in advance.

Document machine antenna mounting height, cable/filter losses, antenna gain/pattern, orientation,
and blockage. Measure or independently justify path loss and shadowing for the actual field.
Terrain, crop state, and obstruction belong in the validation domain only when supported by
measurements or a validated model. Fit on separate locations/runs from the physical holdout.

Select each application's deadline and payload from its requirements, then map to supported PQIs
and bearers. A convenient PQI table entry alone does not establish a machinery application's
communication requirement. Present results as a communication service envelope under those
assumptions.

Proposed initial factor levels, subject to the pilot and supported configuration checks:

| Factor | Baseline / proposed levels | Design note |
|---|---|---|
| Carrier | 5.9 GHz | State the simulated operating band and applicability |
| Channel bandwidth / pool | 20 MHz; 50 PRBs; 5 subchannels of 10 PRBs | Occupied pool bandwidth is 18 MHz at 30 kHz spacing; distinguish it from channel bandwidth |
| Numerology | `mu = 1` initially | Extend only after bandwidth and abstraction validation for other numerologies |
| Transmit power | 23 dBm total at a declared reference plane | Record antenna gain, feeder losses, and power allocation |
| Noise figure | 9 dB baseline; 6/9/12 dB sensitivity cases | Sensitivity levels are hypothetical receiver cases |
| MCS | Exact registered table indices, initially 4/7/11/16/20 where matching tables exist | Add valid MCS/receiver cases through new waveform measurements; avoid nearest-row substitution |
| Payload | 100/300/1000 B, plus TBS and segmentation boundaries | Reject unsupported SLS payloads; use the full stack for segmentation |
| Traffic | Periodic 20/100/200 ms; isolated events; Poisson; synchronized bursts | Bursts test correlated hazards that independent Poisson arrivals miss |
| Density | Pilot 10/30/60/100/200 UEs per square kilometre in the custom field | Lane-based densities are separate parameters in road scenarios |
| Reservation period | Supported 20/50/100 ms cases | Compare with both traffic period and deadline |
| Retransmission | 0/1/2 blind repeats; supported feedback cases | Enforce resource reach, processing gaps, and per-packet attempt accounting |
| Mobility | Static, low-speed application case, reference-road case | Publish per-end velocities and exact Doppler construction |
| Receiver | Practical estimator/equalizer baseline; ideal knowledge only as an upper bound | Label ideal-reference results distinctly |

Do not execute the full Cartesian product. First screen factors in controlled cases, then test
interactions suggested by the mechanisms: density × traffic load × policy; Doppler × DM-RS
pattern × MCS; near-far ratio × partial overlap; and HARQ × receiver observations × deadline.

## 8. Metrics and measurement boundaries

### 8.1 Packet and link eligibility

For each source packet `p`, define the intended receiver set `R(p)` before looking at decoding
outcomes. For unicast it contains the addressed receiver. For broadcast, define a distance or
application relevance rule at a stated reference time, such as generation time. Record distance
at both generation and transmission when mobility matters.

Use every eligible packet/receiver pair in the denominator, including half-duplex misses,
unsent expiries, and intended receivers that never decode control. A separate conditional PHY
metric can describe performance among listening receivers, with its denominator explicitly named.

For a declared deadline `D(p)`, the primary application metric is:

\[
R_D = \frac{\sum_p\sum_{r\in R(p)}\mathbf{1}\{t_{deliver}(p,r)-t_{gen}(p)\le D(p)\}}
{\sum_p |R(p)|}.
\]

Report by flow, distance bin, receiver/source, and scenario replicate. Also report eventual
delivery separately. State whether an aggregate weights packets, packet/receiver pairs, or UEs
equally; these answer different questions.

### 8.2 QoS interpretation

Use PDB, PER, and priority values from the frozen PQI table, respecting resource type and cast
restrictions. However, distinguish a study-defined on-time delivery target from formal PQI
conformance. TS 23.287 delegates PER semantics to TS 23.501; the latter defines PER in terms of
non-congestion losses and treats deadline expiry differently by resource type. Therefore,
`R_D >= 1 - PER` may be an explicitly chosen application criterion, but cannot by itself prove
every standardized QoS obligation. [TS 23.287](https://www.etsi.org/deliver/etsi_ts/123200_123299/123287/19.00.00_60/ts_123287v190000p.pdf),
[TS 23.501, clauses 5.7.3.4–5.7.3.5](https://www.etsi.org/deliver/etsi_ts/123500_123599/123501/18.08.00_60/ts_123501v180800p.pdf).

The cited TS 23.501 edition establishes this distinction; select and freeze the applicable
edition for the final study's release profile.

### 8.3 Latency, goodput, and temporal reliability

Record application generation, AS ingress, RLC enqueue, MAC readiness, grant selection, first
transmission start/end, PHY decode, RLC/PDCP delivery, and application delivery. Include receiver
ID and unique packet/TB/attempt IDs so multiplexing and retransmission remain traceable.

Application latency is `t_app_deliver - t_app_gen`; PC5/AS latency uses its stated interface
boundaries. A fixed processing allowance is a model parameter, not measured software runtime or
measured device latency. Decompose latency using non-overlapping timestamp intervals and a
consistent treatment of retransmissions and overlapping processing.

Report delivered-packet p50/p95/p99 alongside `R_D`, loss counts, and reception-gap/outage
distributions. An unconditional deadline CDF uses all eligible pairs in the denominator and
leaves undelivered outcomes unresolved at finite times. A percentile requiring more delivered
mass than exists is unavailable/infinite under that definition.

Distinguish source payload goodput from aggregate receiver-copy goodput in broadcast. The latter
increases with the number of recipients even if the source bit rate is unchanged. Record resource
occupancy and transmissions per delivered packet to make this effect visible.

### 8.4 Cohort and end-of-run handling

Define a fixed observation cohort by generation time. Allow every cohort packet its full
deadline observation window after traffic observation ends; continue background traffic as
needed to preserve the intended load. Alternatively, predefine and report right censoring.
Report generated, eligible, delivered on time, delivered late, lost, and censored counts.

## 9. Replication and statistical analysis

### Independent units

Use independent topology/mobility/channel realizations as the main deployment replication
units, with traffic replicates nested where useful. Packet/receiver pairs from one packet,
neighbors in the same topology, and adjacent fading samples are correlated. Do not treat them
as independent Bernoulli trials simply because the log contains many rows.

For policy comparisons, replay common exogenous traffic and propagation traces across methods.
Use separate random streams for geometry, mobility, traffic, fading, and scheduling decisions.
The same integer seed alone does not preserve pairing when methods consume different numbers
of random draws.

### Budgets and intervals

Use a separate pilot to estimate variance, dependence, warm-up, and computation cost. A possible
starting budget is 30 independent deployment drops per selected main condition, 2 seconds of
warm-up and 20 seconds of observation per run. These durations are provisional: compare longer
warm-up/observation windows and examine CBR, queue occupancy, grant state, and receive-process
occupancy for stationarity. Report cold-start behavior in a separate transient experiment.

For system metrics, use intervals over independent drops and cluster/block methods preserving
within-run dependence. For paired comparisons, estimate paired differences and their intervals.
Report effect sizes and uncertainty, with correction for multiple primary comparisons where
appropriate. Quantile intervals need sufficient independent tail observations.

For isolated, independent PHY trials, use an appropriate binomial interval; exact intervals are
particularly useful with few errors. [NIST exact binomial intervals](https://itl.nist.gov/div898/software/dataplot/refman2/auxillar/exacbici.htm).
Choose fixed main-campaign sample counts from the pilot. If using a sequential stopping rule,
use an inference procedure valid for that rule or the applicable standardized test procedure.

### Rare-event claims

With zero failures in `n` independent trials, the one-sided 95% upper failure-probability bound is:

\[
p_U=1-0.05^{1/n}\approx\frac{3}{n}.
\]

Thus, zero observed failures require at least approximately these independent sample counts
to support the indicated upper failure bound:

| Failure target | Minimum `n` using the exact expression |
|---|---:|
| `1e-2` | 299 |
| `1e-3` | 2,995 |
| `1e-4` | 29,956 |
| `1e-5` | 299,572 |

Zero failures in 1,000 independent trials gives an upper bound near 0.003; it does not establish
a failure rate below `1e-4`. Correlated broadcast copies do not supply the independent sample
count in this calculation. Apply a justified dependence model or report a weaker claim.

For each reliability target, predefine three outcomes: demonstrated, violated, or inconclusive,
based on confidence bounds. Passing a point-estimate threshold alone is insufficient.

## 10. PHY and abstraction acceptance rules

Separate noise-only, interference, and receiver-processing validation.

1. Verify thermal/noise-figure power and per-RE variance numerically over grid sizes and supported
   numerologies. Publish the antenna-port, time-sample, FFT-grid, and equalized-symbol conventions.
2. Measure PSCCH, SCI-2, PSSCH, and PSFCH separately; do not infer one from another's curve.
3. In a pilot, bracket each BLER transition with a coarse SNR grid. Refine near transitions and
   measure the main curves with independently selected, fixed precision budgets.
4. Tag every table with MCS table/index, TBS, width, numerology, channel profile/delay spread,
   Doppler construction, antenna configuration, DM-RS pattern, HARQ history, receiver version,
   trial count, and confidence interval.
5. Hold out SNR points, channel realizations, and selected allocation/interference cases from
   table construction. Agreement at stored table entries is only a table-reading check.
6. Compare like-for-like MAC and upper-layer behavior when assessing the abstraction. The SLS
   and full stack currently use different grant/upper-layer behavior, so a raw deployment KPI
   difference cannot be attributed entirely to the PHY abstraction.

Proposed research equivalence margins, to justify and freeze after the pilot: no more than
0.05 absolute BLER discrepancy through the selected transition region and no more than 1 dB
at a declared BLER crossing, with an interval supporting the chosen margin. Test multi-attempt
HARQ sequences and partial collisions explicitly. These proposed margins do not replace any
standardized receiver-performance requirement.

If a margin fails, restrict the abstraction's declared validity domain, improve its model, or
use waveform results for that case. Record such failures as findings rather than deleting cases.

## 11. Optional physical measurement campaign

For a physical-validation contribution, add a separate plan with equipment calibration and
measurement uncertainty:

- **Conducted link:** two compatible sidelink devices or a calibrated waveform source/receiver,
  attenuation, and a known reference plane. Sweep received power and compare measured BLER,
  feedback behavior, and sensitivity against the frozen waveform model.
- **Receiver characterization:** characterize overall NF, gain, clipping/ADC behavior, CFO, and
  relevant transmitter impairments. Separate component specifications from measured chain behavior.
- **Outdoor holdout:** record antenna placement/pattern, positions, velocities, obstructions,
  received power, packets, and clock accuracy. Use separate propagation-calibration and validation
  locations or runs.
- **Time measurement:** calibrate clocks and quantify timestamp uncertainty. One-way latency
  requires a defensible shared time reference; log the clock uncertainty alongside sub-ms claims.

Without this campaign, limit conclusions to validated simulation behavior and the externally
supported assumptions used by the model.

## 12. Reproducibility artifacts

IEEE encourages sharing methods, data, and code so experiments and conclusions can be verified.
[IEEE Author Center: Research Reproducibility](https://journals.ieeeauthorcenter.ieee.org/create-your-ieee-journal-article/research-reproducibility/).

Archive a frozen source revision plus its complete working-tree changes, configuration files,
config/table hashes, specification manifest, MATLAB/toolbox versions, OS/hardware, seed/stream
manifest, exogenous traces, and analysis revision. A commit ID alone does not identify an
experiment conducted with modified or untracked files.

For each run, store:

```text
run_id, campaign_id, replicate_id, source_revision, source_patch_hash,
configuration_hash, PHY_table_hash, tool_versions,
scenario/layout, exogenous_trace_ids, random_stream_ids,
warmup_window, observation_cohort, followup_window,
generated/eligible/on_time/late/lost/censored counts,
packet_and_attempt_logs, resource_logs, receiver_state_logs,
metric_estimates, uncertainty_intervals, runtime_and_memory
```

Generate figures and tables from archived raw records with one documented analysis command.
Publish successful and failed cases, denominator definitions, validity limits, and enough
metadata for an independent reader to regenerate each result. Provide a small smoke dataset
and a full-campaign manifest with expected runtime and storage.

## 13. Manuscript experiment-design section

A useful section sequence is:

1. Research questions and hypotheses.
2. Platform architecture, feature coverage, reference versions, and deviations.
3. Independent verification, receiver tests, and abstraction validation.
4. Scenarios, factor levels, baselines, and interventions.
5. Measurement boundaries, eligibility rules, and endpoints.
6. Replication, uncertainty, sample-size justification, and decision rules.
7. Reproducibility and threats to validity.

Example protocol paragraph, to adapt before running the study:

> We will evaluate a frozen Release 16 NR sidelink Mode 2 implementation through deterministic
> procedure checks, waveform receiver experiments, and system-level deployment experiments.
> Independent reference cases will establish correctness of the selected bit mappings and state
> transitions. PHY abstraction parameters will be constructed on calibration cases and assessed
> on held-out waveform cases with predefined equivalence margins. The primary application
> endpoint will be deadline delivery reliability over a receiver cohort defined before observing
> decoding outcomes. Policy comparisons will replay common exogenous traffic and propagation
> traces across independent deployment drops. We will report effect sizes, uncertainty
> intervals, losses, and censored outcomes, and release the configuration, trace, and analysis
> artifacts needed to regenerate every reported figure.

Replace future tense with the procedures actually executed when writing the completed paper.
Report selected run counts, durations, cases, and margins explicitly; the paragraph alone is
not the experimental specification.

## 14. Suggested main figures and execution order

Suggested main-paper figures:

1. Architecture and feature-to-evidence coverage.
2. Independent procedure/reference-case agreement.
3. Control/data/feedback receiver curves with uncertainty.
4. Held-out waveform-versus-abstraction agreement and failure cases.
5. Deadline reliability versus density and offered load, by flow.
6. Latency/reception-gap distributions with the loss denominator visible.
7. Controlled mechanism and ablation results.
8. Reliability/capacity operating envelope and sensitivity to assumptions.

Place exhaustive format vectors, per-case tables, and secondary sweeps in supplementary material.

Execution order:

- [ ] Freeze scope, primary claims, references, and measurement definitions.
- [ ] Resolve the tracked correctness issues and mapping/latency prerequisites.
- [ ] Add independent vectors and deterministic mechanism cases.
- [ ] Run a separate pilot for precision, dependence, stationarity, and computation budgets.
- [ ] Freeze the main design and separate calibration/holdout cases.
- [ ] Run receiver and matched abstraction campaigns.
- [ ] Run selected deployment conditions and paired policy comparisons.
- [ ] Run physical holdout measurements if making device/environment validity claims.
- [ ] Generate all figures from archived records and audit every claim against its evidence.

Treat broad validation as a maintained evidence matrix. Select a coherent subset of scientific
questions for the main article, and publish the remaining coverage as a reproducible supplement.
