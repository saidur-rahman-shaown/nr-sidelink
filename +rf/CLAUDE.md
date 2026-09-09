# RF (non-normative) — the boundary that keeps the baseband separable

There is **no "RF SAP" in any 3GPP specification.** This package is our own boundary, kept
outside `+phy/` so the baseband can be replaced, ported or driven from a file without the
channel or the harness noticing.

| Module | What it does |
|---|---|
| `toAir` | attaches `.ueId` and `.posXY` to a validated PHY-SAP request |
| `noiseFloorDbm` | kTB + noise figure |

`toAir` is deliberately **additive**: it does not modify the request, so the identical
descriptor drives both the abstracted and the waveform path. Transmit power is decided upstream
by `phy.ts38213.slPowerControl` — currently a max-power-always policy — and travels in
`txPowerDbm`; PA compression, EVM and filter response belong here and are not built.

`noiseFloorDbm` names its constant: `10*log10(k*290*1000)` = −173.98 dBm/Hz, written from
k and T rather than as a bare `-174`.
