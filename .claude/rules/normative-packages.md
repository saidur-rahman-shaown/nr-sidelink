---
paths:
  - "+phy/+ts38211/**"
  - "+phy/+ts38212/**"
  - "+phy/+ts38213/**"
  - "+phy/+ts38214/**"
  - "+phy/+ts38215/**"
  - "+phy/+chan/**"
  - "+mac/**"
  - "+rlc/**"
  - "+pdcp/**"
  - "+sdap/**"
  - "+pc5s/**"
  - "+cfg/**"
---
These are the **normative packages**. Code here must be bit-exact against any other compliant
implementation and must survive the C and HDL port unchanged in behaviour.

- **No MATLAB toolbox call. None.** Not `nrPolarEncode`, not `lteZadoffChuSeq`, not `comm.*`.
  If you need one, it belongs behind a wrapper in `+phy/+lib/` and this code calls the
  wrapper. Flag any violation before writing anything else. `+phy/+lib/CLAUDE.md` governs how
  each wrapper body is chosen — toolbox function first if one exists for the clause,
  hand-written only if none does — this file only fixes that the call cannot happen here.
- No cell arrays, containers.Map, tables, objects, dynamic field names, `varargin`, or `eval`
  on a function interface. Flat numeric arrays and plain scalar structs only.
- No hidden state. No `persistent`, no `global`. State lives in explicit objects that
  serialise and diff.
- No magic numbers. Every literal is a named spec table entry or a config field. A bare `31`,
  `1600`, `127`, or `24` in a body is a defect.
- Write the loop the spec describes. Do not vectorise a normative formula into something
  clever. Speed is not this code's job.
- Where the spec constrains a parameter range or a cross-field relationship, write the
  assertion.

Every function carries this header, filled from `cfg/specVersions.json`:

    % <one-line behaviour>
    % Spec:   TS 38.211 V16.x.y, clause 8.4.1.1, para 2
    % Inputs: ...  (with dynamic range for each numeric quantity)
    % Outputs: ...

`+phy/+rx/`, `+phy/+lib/`, `+harness/`, and `+app/` are **not** normative. Toolbox calls are
expected there. Interfaces to normative packages must still be flat, and a change there must
never force a change here — if it seems to, the interface is wrong.
