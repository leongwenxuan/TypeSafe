# Performance & Capacity

- **Targets**: `<2s` p95 for `/analyze-text`; `<3.5s` for `/scan-image`.  
- **Concurrency**: 50 rps burst (hackathon scale).  
- **Caching**: short-lived in-memory cache for identical text checks.  
- **Resilience**: timeouts 1.5s per provider; graceful degradation to local rules if providers fail.

