# Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| App Review privacy concerns | Explicit consent flows; no background capture |
| Provider latency | Parallelize calls; aggressive timeouts + fallback |
| False positives | Tunable thresholds; explainability; dismiss affordance |
| Data exposure | Minimize payloads; 7‑day TTL; encrypted transit |
| Keyboard instability | Keep memory footprint low; avoid heavy sync |

