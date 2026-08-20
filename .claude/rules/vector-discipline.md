---
paths:
  - "+vec/**"
  - "+test/**"
---
Vector dumps are a deliverable, not debug output. The hardware phase consumes them and the
golden set becomes the acceptance contract for the C port.

- Every layer boundary dumps input and output in the frozen format, behind the dump flag.
- A dump file records the spec versions it was generated under and the config hash.
- After a set is frozen and tagged it is never edited. A correction is a new tagged set with a
  written rationale.
- Do not generate vectors from a module whose worked example has not passed. A frozen set
  built on a misread clause propagates the misreading into silicon.
- Never adjust an implementation and its worked example together to make them agree. Report
  the disagreement.
