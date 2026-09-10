# KartPad known issues

## KI-001 — Limited free build storage

- Severity: project infrastructure risk (not yet a product defect)
- Observed: approximately 21 GiB free on 2026-08-28 before upstream dependency checkout and translation.
- Impact: full dependency graphs, generated translated shards, and parallel platform builds may exhaust disk space.
- Mitigation: measure each fetch/build stage, keep generated data ignored, use bounded builds, and do not delete user data without explicit authorization.
