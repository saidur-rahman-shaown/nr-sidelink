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

- **MATLAB 5G Toolbox package functions (`nrXxx`) may be called directly.** Relaxed from a
  strict toolbox-free rule by explicit user decision (2026-08-21), so each spec's
  implementation stays physically inside its own `+tsXXXXX/` package folder — easy to
  cross-check line-by-line against that spec's PDF — instead of being split across a package
  folder and an indirection layer in `+phy/+lib/`. Non-5G-Toolbox MATLAB functionality
  (`comm.*` System objects, `lteZadoffChuSeq`, etc.) is still out of bounds here; call `nrXxx`
  5G Toolbox package functions only, and still cite the clause each call covers.
  **Known tradeoff, accepted for now:** the C/HDL port will need to replace every direct
  `nrXxx` call site individually rather than swapping out one `+phy/+lib/` layer. This does
  not retroactively change code already routed through `+phy/+lib/` (e.g. `+phy/+ts38211/`'s
  clause-5 primitives still call `phy.lib.goldSeq` etc.) — both patterns coexist; routing a
  new wrapper through `+phy/+lib/` is no longer mandatory, not forbidden.
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
