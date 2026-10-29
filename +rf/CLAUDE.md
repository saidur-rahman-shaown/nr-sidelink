# RF (non-normative) — the boundary that keeps the baseband separable

There is **no "RF SAP" in any 3GPP specification.** This package is our own boundary, kept
outside `+phy/` so the baseband can be replaced, ported or driven from a file without the
channel or the harness noticing.

| Module | What it does |
|---|---|
| `toAir` | attaches `.ueId` and `.posXY` to a validated PHY-SAP request |
| `noiseFloorDbm` | kTB + noise figure |
| `txFrontEnd` | scales a baseband slot to the transmit power: mean power over the transmitted samples (guard excluded) = P_tx, in sqrt(W) |
| `hwDefaults` / `hwIdeal` | transmitter/receiver impairment parameters: typical 5.9 GHz C-V2X module values, each with its basis; `hwIdeal` switches every impairment off for ablation |
| `txHardwareInit` / `txHardware` | DAC → IQ imbalance (`iqimbal`) → phase noise (`comm.PhaseNoise`) → carrier error (`comm.PhaseFrequencyOffset`, continuous phase) → Rapp PA (`comm.MemorylessNonlinearity`), drive calibrated so the antenna port averages 23 dBm **after** compression |
| `rxHardwareInit` / `rxHardware` | thermal noise at the NF → LO error and phase noise → IQ imbalance → AGC set on the AGC symbol → ADC quantisation/clipping → digital rescale to absolute sqrt(W) |

`toAir` is deliberately **additive**: it does not modify the request, so the identical
descriptor drives both the abstracted and the waveform path. Transmit power is decided upstream
by `phy.ts38213.slPowerControl` — currently a max-power-always policy — and travels in
`txPowerDbm`. The hardware chains are used by the waveform-level deployment (`+harness/+deploy/`)
only; `txFrontEnd` alone remains the ideal path for the LLS and the field harness.

### Hardware models: measured, and the one trap
`test_rfHardware` measures, rather than assumes: PA output 23.00 dBm, transmit EVM 5.5 % (TS
38.101-1's 64QAM limit is 8 %), in-band emission into non-adjacent sub-channels −48 dBc, the drawn
carrier error recovered to within 1 Hz, and the receiver preserving absolute power.

**`comm.PhaseNoise` designs its shaping filter at setup, and the cost explodes at low offsets.** A
mask starting at 1 kHz took 14.6 s per object at 30.72 MHz; two objects per UE made a 40-UE
deployment spend ~19 min before its first slot. From 10 kHz it is 0.9 s. Phase noise below
~2 kHz rotates a whole 0.5 ms slot and is removed by the per-slot DM-RS estimate, so the decoder
cannot tell the difference (in-slot RMS phase 1.2° either way).

`noiseFloorDbm` names its constant: `10*log10(k*290*1000)` = −173.98 dBm/Hz, written from
k and T rather than as a bare `-174`.
