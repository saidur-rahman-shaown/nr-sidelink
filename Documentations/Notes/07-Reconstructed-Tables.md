# Reconstructed Tables

> **Why this file exists:** PDF text extraction destroyed every table grid in the
> pasted notes. The numbers usually survived, but as an unlabelled run-on with no
> row/column separation — and in a few cases (Tables 16.1-1 and 16.1-2) the cells
> came out in an order that does **not** match the source, so reading them off the
> flattened text gives wrong values.
>
> Every table below was re-read from the source PDFs in `../`. Use these, not the
> inline versions in files 01–05.

| Table | Source PDF | Page |
|---|---|---|
| 8.1.3.1-1, 8.1.3.1-2 | `38214-gh0.pdf` | 158 |
| 8.1.3.2-1 | `38214-gh0.pdf` | 159 |
| 8.1.4-1, 8.1.4-2 | `38214-gh0.pdf` | 162 |
| 8.1.6-1, 8.1.6-2 | `38214-gh0.pdf` | 163–164 |
| 16.1-1, 16.1-2 | `38213-gh0.pdf` | 165 |
| 16.3-1, 16.3-2, 16.3-3 | `38213-gh0.pdf` | 172–173 |

---

## TS 38.214 — PSSCH data procedures

### Table 8.1.3.1-1: Mapping of one bit of MCS table indicator to MCS table

| MCS table indicator | MCS table |
|---|---|
| `'0'` | Table 5.1.3.1-1 |
| `'1'` | 1st table provided by `sl-Additional-MCS-Table` |

### Table 8.1.3.1-2: Mapping of two bits of MCS table indicator to MCS table

| MCS table indicator | MCS table |
|---|---|
| `'00'` | Table 5.1.3.1-1 |
| `'01'` | 1st table provided by `sl-Additional-MCS-Table` |
| `'10'` | 2nd table provided by `sl-Additional-MCS-Table` |
| `'11'` | reserved |

### Table 8.1.3.2-1: `N_RE^DMRS` according to `sl-PSSCH-DMRS-TimePatternList`

| `sl-PSSCH-DMRS-TimePatternList` | `N_RE^DMRS` |
|---|---|
| {2} | 12 |
| {3} | 18 |
| {4} | 24 |
| {2,3} | 15 |
| {2,4} | 18 |
| {3,4} | 21 |
| {2,3,4} | 18 |

Used in the PSSCH RE count for TBS (§8.1.3.2):

```
N'_RE = N_sc^RB × (N_symb^sh − N_symb^PSFCH) − N_oh^PRB − N_RE^DMRS
N_RE  = N'_RE × n_PRB − N_RE^SCI,1 − N_RE^SCI,2
```

with `N_sc^RB = 12`, `N_symb^sh = sl-LengthSymbols − 2`, `N_oh^PRB` from
`sl-X-Overhead`, and:

- `N_symb^PSFCH = 3` if the SCI 1-A 'PSFCH overhead indication' field is `1`
  **and** `sl-PSFCH-Period` is 2 or 4;
- `N_symb^PSFCH = 3` if `sl-PSFCH-Period` is 1;
- `N_symb^PSFCH = 0` if `sl-PSFCH-Period` is 0, or otherwise.

### Table 8.1.4-1: `T^SL_proc,0` depending on sub-carrier spacing

| `μ_SL` | SCS | `T^SL_proc,0` [slots] |
|---|---|---|
| 0 | 15 kHz | 1 |
| 1 | 30 kHz | 1 |
| 2 | 60 kHz | 2 |
| 3 | 120 kHz | 4 |

### Table 8.1.4-2: `T^SL_proc,1` depending on sub-carrier spacing

| `μ_SL` | SCS | `T^SL_proc,1` [slots] |
|---|---|---|
| 0 | 15 kHz | 3 |
| 1 | 30 kHz | 5 |
| 2 | 60 kHz | 9 |
| 3 | 120 kHz | 17 |

### Table 8.1.6-1: Congestion control processing time, timing capability 1

| `μ` | `N` [slots] |
|---|---|
| 0 | 2 |
| 1 | 2 |
| 2 | 4 |
| 3 | 8 |

### Table 8.1.6-2: Congestion control processing time, timing capability 2

| `μ` | `N` [slots] |
|---|---|
| 0 | 2 |
| 1 | 4 |
| 2 | 8 |
| 3 | 16 |

### Table 8.6-1: PSSCH preparation time

| `μ` | `N_2` [symbols] |
|---|---|
| 0 | 10 |
| 1 | 12 |
| 2 | 23 |
| 3 | 36 |

`μ` is whichever of (`μ_DL`, `μ_SL`) gives the largest `T_proc`.

---

## TS 38.213 — UE procedures for sidelink control

### Table 16.1-1: Slot configuration period when one pattern is indicated

> ⚠ The flattened paste of this table in file 05 has the rows out of order and is
> **not usable**. This is the correct mapping.

| `a_1, a_2, a_3, a_4` | Period of *pattern1* `P` (msec) |
|---|---|
| 0, 0, 0, 0 | 0.5 |
| 0, 0, 0, 1 | 0.625 |
| 0, 0, 1, 0 | 1 |
| 0, 0, 1, 1 | 1.25 |
| 0, 1, 0, 0 | 2 |
| 0, 1, 0, 1 | 2.5 |
| 0, 1, 1, 0 | 4 |
| 0, 1, 1, 1 | 5 |
| 1, 0, 0, 0 | 10 |
| Reserved | Reserved |

### Table 16.1-2: Slot configuration period and granularity, two patterns

> ⚠ Same caveat — the flattened paste interleaves the `P`, `P_2` and granularity
> columns beyond recovery.

| `a_1, a_2, a_3, a_4` | *pattern1* `P` (msec) | *pattern2* `P_2` (msec) | `w` 15 kHz | `w` 30 kHz | `w` 60 kHz | `w` 120 kHz |
|---|---|---|---|---|---|---|
| 0, 0, 0, 0 | 0.5 | 0.5 | 1 | 1 | 1 | 1 |
| 0, 0, 0, 1 | 0.625 | 0.625 | 1 | 1 | 1 | 1 |
| 0, 0, 1, 0 | 1 | 1 | 1 | 1 | 1 | 1 |
| 0, 0, 1, 1 | 0.5 | 2 | 1 | 1 | 1 | 1 |
| 0, 1, 0, 0 | 1.25 | 1.25 | 1 | 1 | 1 | 1 |
| 0, 1, 0, 1 | 2 | 0.5 | 1 | 1 | 1 | 1 |
| 0, 1, 1, 0 | 1 | 3 | 1 | 1 | 2 | 2 |
| 0, 1, 1, 1 | 2 | 2 | 1 | 1 | 2 | 2 |
| 1, 0, 0, 0 | 3 | 1 | 1 | 1 | 2 | 2 |
| 1, 0, 0, 1 | 1 | 4 | 1 | 1 | 2 | 2 |
| 1, 0, 1, 0 | 2 | 3 | 1 | 1 | 2 | 2 |
| 1, 0, 1, 1 | 2.5 | 2.5 | 1 | 1 | 2 | 2 |
| 1, 1, 0, 0 | 3 | 2 | 1 | 1 | 2 | 2 |
| 1, 1, 0, 1 | 4 | 1 | 1 | 1 | 2 | 2 |
| 1, 1, 1, 0 | 5 | 5 | 1 | 1 | 2 | 4 |
| 1, 1, 1, 1 | 10 | 10 | 1 | 2 | 4 | 8 |

> In the source, the granularity block is drawn as merged cells: rows
> `0,0,0,0` … `0,1,0,1` share `w = 1` across all four SCS; rows `0,1,1,0` …
> `1,1,0,1` share `w = 1` for 15/30 kHz and `w = 2` for 60/120 kHz. The last two
> rows are per-SCS. The expansion above is that merge written out.

### Table 16.3-1: Set of cyclic shift pairs (`m_0`)

| `N_CS^PSFCH` | Pair 0 | Pair 1 | Pair 2 | Pair 3 | Pair 4 | Pair 5 |
|---|---|---|---|---|---|---|
| 1 | 0 | – | – | – | – | – |
| 2 | 0 | 3 | – | – | – | – |
| 3 | 0 | 2 | 4 | – | – | – |
| 6 | 0 | 1 | 2 | 3 | 4 | 5 |

### Table 16.3-2: HARQ-ACK bit → cyclic shift, when ACK **or** NACK is reported

| HARQ-ACK value | 0 (NACK) | 1 (ACK) |
|---|---|---|
| Sequence cyclic shift | 0 | 6 |

Applies when the UE detects SCI format 2-A with Cast type indicator `"01"` or `"10"`
(unicast / groupcast option 2).

### Table 16.3-3: HARQ-ACK bit → cyclic shift, when **only NACK** is reported

| HARQ-ACK value | 0 (NACK) | 1 (ACK) |
|---|---|---|
| Sequence cyclic shift | 0 | N/A |

Applies when the UE detects SCI format 2-B, or SCI format 2-A with Cast type
indicator `"11"` (groupcast option 1 — NACK-only feedback).

### Table 16.5-1: Values of `N`

| `μ` | `N` |
|---|---|
| 0 | 14 |
| 1 | 18 |
| 2 | 28 |
| 3 | 32 |

---

## Related formulas the tables feed

**PSFCH resource count and index** (§16.3):

```
R_PRB,CS^PSFCH = N_type^PSFCH × M_subch,slot^PSFCH × N_CS^PSFCH

index = (P_ID + M_ID) mod R_PRB,CS^PSFCH
```

`P_ID` is the physical layer source ID from SCI 2-A/2-B; `M_ID` is the receiving
UE's identity for groupcast option 2 (Cast type `"01"`), else zero.

**S-SSB transmit power** (§16.2.0):

```
P_S-SSB(i) = min( P_CMAX , P_O,S-SSB + 10·log10(2^μ · M_RB^S-SSB) + α_S-SSB · PL )   [dBm]
```

with `M_RB^S-SSB = 11` PRBs.

**PSSCH transmit power** (§16.2.1):

```
P_PSSCH(i) = min( P_CMAX , P_MAX,CBR , min( P_PSSCH,D(i) , P_PSSCH,SL(i) ) )   [dBm]
```

`P_MAX,CBR` comes from `sl-MaxTxPower` for the priority level and the CBR range
containing the CBR measured in slot `i − N` — this is the coupling between
congestion control and power control.
