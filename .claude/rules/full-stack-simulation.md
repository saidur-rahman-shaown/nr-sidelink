Every simulation that produces a result someone will read (latency, throughput, reliability,
range, collisions, anything reported) carries **every packet through the full stack and the RF
waveform, and back**:

    application -> SDAP -> PDCP -> RLC -> MAC -> PHY (+stack/)
      -> IQ at 30.72 Msps (30 kHz SCS, mu = 1)
      -> transmitter hardware (rf.txHardware: DAC, IQ imbalance, phase noise, carrier error,
         PA calibrated to 23 dBm at the antenna port)
      -> channel (path loss, fading in continuous time, propagation delay; every transmitter's
         waveform summed at every receiver; thermal noise)
      -> receiver hardware (rf.rxHardware: LO error, AGC, ADC)
      -> PHY decode -> MAC -> RLC -> PDCP -> SDAP -> application

Latency, delivery and loss are measured **at the receiving application**, on application
timestamps.

- **The harness for this is `+harness/+deploy/`** (`harness.deploy.run`, configured from
  `deployConfig.m`; the two-UE case is `twoUeConfig.m` / `runTwoUe`). `+harness/+field/` is full
  stack at waveform level but without the RF hardware models, so it is second choice.
- **No abstraction as the deliverable.** `+harness/+sls/` (BLER tables, SINR formula, slot-level
  descriptors) and link-level curves read off a table do not produce reported results. They may
  be used to debug, to cross-check, or to size a run, and must be labelled as such wherever they
  appear.
- **If the full stack is too slow for what was asked, say so and ask before falling back.** Give
  the cost (waveform deployment: about 4 min of wall clock per simulated second at 12 UEs, about
  1-2 s per second for two UEs) and propose a smaller full-stack run first: fewer packets, fewer
  UEs, a shorter time. Never silently substitute the abstracted path.
- **Whatever the full stack cannot do yet is a gap to report, not a reason to switch paths.** For
  example, `+stack/` models one transmit pool, ideal sync, and ACK/NACK feedback for unicast only.
  State it next to the result.
- **A full-stack result that looks wrong is a defect to find, not a reason to switch paths.** The
  first full-stack two-UE run (2026-10-28) exposed PHY defects that every abstracted result had
  hidden (`+stack/CLAUDE.md`, "Known defects").
