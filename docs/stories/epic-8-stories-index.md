# Epic 8: MCP Agent Stories - Index

**Epic:** MCP Agent with Multi-Tool Orchestration  
**Total Stories:** 13  
**Total Effort:** ~182 hours (4-5 weeks for 2 developers)

---

## Story Summary

| Story ID | Title | Priority | Effort | Sprint Week |
|----------|-------|----------|--------|-------------|
| **8.1** | Celery & Redis Infrastructure Setup | P0 | 16h | Week 8, Days 1-2 |
| **8.2** | Entity Extraction Service | P0 | 20h | Week 8, Days 2-3 |
| **8.3** | Scam Database Tool | P0 | 18h | Week 8, Days 3-4 |
| **8.4** | Exa Web Search Tool Integration | P0 | 16h | Week 9, Days 1-2 |
| **8.5** | Domain Reputation Tool | P1 | 14h | Week 9, Days 2-3 |
| **8.6** | Phone Number Validator Tool | P1 | 10h | Week 9, Day 3 |
| **8.7** | MCP Agent Task Orchestration | P0 | 24h | Week 9, Days 3-5 |
| **8.8** | Agent Reasoning with LLM | P0 | 12h | Week 9, Day 5 |
| **8.9** | WebSocket Progress Streaming | P0 | 12h | Week 10, Days 1-2 |
| **8.10** | Smart Routing Logic | P0 | 10h | Week 10, Day 2 |
| **8.11** | iOS App Agent Progress Display | P1 | 16h | Week 10, Days 3-4 |
| **8.12** | Database Seeding & Maintenance | P1 | 14h | Week 10, Days 4-5 |
| **8.13** | Company Verification Tool | P1 | 16h | Week 11, Days 1-2 |

**Total:** 182 hours

---

## Implementation Order

### Phase 1: Foundation (Week 8)
**Goal:** Set up infrastructure and core tools

1. **Story 8.1** - Celery & Redis Infrastructure
   - Sets up async task queue
   - Required for all subsequent stories
   - Testing: Smoke tests with example tasks

2. **Story 8.2** - Entity Extraction Service
   - Extracts phones, URLs, emails from text
   - Fast, offline processing
   - Testing: 100+ test cases with diverse formats

3. **Story 8.3** - Scam Database Tool
   - Local database for known scams
   - Fastest tool (< 10ms lookups)
   - Testing: CRUD operations, performance

**Phase 1 Deliverable:** Working infrastructure with entity extraction and database lookups

---

### Phase 2: Tool Integration (Week 9)
**Goal:** Add all specialized tools and agent orchestration

4. **Story 8.4** - Exa Web Search Tool
   - Search web for scam reports
   - Caching for cost optimization
   - Testing: Mock API responses, real integration tests

5. **Story 8.5** - Domain Reputation Tool
   - Check URLs against VirusTotal, Safe Browsing
   - WHOIS, SSL validation
   - Testing: New vs old domains, malicious vs clean

6. **Story 8.6** - Phone Number Validator Tool
   - Fast, offline phone validation
   - Suspicious pattern detection
   - Testing: International numbers, edge cases

7. **Story 8.7** - MCP Agent Task Orchestration ⭐
   - **Core story** - orchestrates all tools
   - Entity-based routing
   - Evidence collection
   - Testing: End-to-end with mocked tools

8. **Story 8.8** - Agent Reasoning with LLM
   - Intelligent verdict generation
   - Cites evidence in explanations
   - Testing: Diverse evidence scenarios

**Phase 2 Deliverable:** Functional MCP agent with all tools integrated

---

### Phase 3: Frontend & Polish (Week 10)
**Goal:** Real-time progress display and production readiness

9. **Story 8.9** - WebSocket Progress Streaming
   - Real-time updates to clients
   - Redis Pub/Sub integration
   - Testing: Concurrent connections, error handling

10. **Story 8.10** - Smart Routing Logic
    - Routes simple scans to fast path
    - Complex scans to agent path
    - Testing: Routing decisions, fallback

11. **Story 8.11** - iOS App Agent Progress Display
    - Beautiful progress UI
    - WebSocket client
    - Evidence breakdown
    - Testing: UI tests, manual QA

12. **Story 8.12** - Database Seeding & Maintenance
    - Seed with 10,000+ known scams
    - Admin API for management
    - Automated daily updates
    - Testing: Seeding scripts, archival

**Phase 3 Deliverable:** Complete end-to-end flow with polished UX

---

### Phase 4: Additional Tools (Week 11)
**Goal:** Expand agent capabilities with specialized verification

13. **Story 8.13** - Company Verification Tool
    - Multi-country business registry checks
    - Fake company detection
    - Typo-squatting and impersonation detection
    - Testing: Real companies, fake companies, pattern detection

**Phase 4 Deliverable:** Enhanced agent with company verification for business impersonation scams

---

## Dependencies

### Critical Path
```
8.1 (Infrastructure)
  ↓
8.2 (Entity Extraction)
  ↓
8.3, 8.4, 8.5, 8.6 (Tools - can be parallel)
  ↓
8.7 (Orchestration) ← depends on all tools
  ↓
8.8 (Reasoning) ← uses orchestration
  ↓
8.9 (WebSocket) ← streams progress
  ↓
8.10 (Routing) ← integrates everything
  ↓
8.11 (iOS UI) ← displays progress
  ↓
8.12 (Seeding) ← operational requirement
  ↓
8.13 (Company Verification) ← additional tool (can be parallel with 8.12)
```

### Parallelization Opportunities

**Week 8:**
- Story 8.1 → Must be first (foundation)
- Story 8.2 → Can start after 8.1
- Story 8.3 → Can start after 8.2

**Week 9:**
- Stories 8.4, 8.5, 8.6 → **Can all be done in parallel** (3 developers)
- Story 8.7 → Waits for 8.3-8.6 to complete
- Story 8.8 → Can start after 8.7

**Week 10:**
- Story 8.9 → Can be parallel with 8.10
- Story 8.10 → Can be parallel with 8.9
- Story 8.11 → Waits for 8.9 (needs WebSocket)
- Story 8.12 → Can be parallel with everything (operational)

**Week 11:**
- Story 8.13 → Can be parallel with 8.12 or standalone (new tool)

---

## Team Allocation

### Backend Developer 1
- Week 8: Stories 8.1, 8.2, 8.3
- Week 9: Stories 8.4, 8.7, 8.8
- Week 10: Stories 8.9, 8.10, 8.12
- Week 11: Story 8.13

### Backend Developer 2 (Optional for parallelization)
- Week 9: Stories 8.5, 8.6 (parallel with Dev 1's 8.4)
- Week 10: Story 8.12 (parallel with Dev 1)
- Week 11: Story 8.13 (parallel with Dev 1 or standalone)

### iOS Developer
- Week 10: Story 8.11
- Can start earlier if backend ready

---

## Testing Strategy

### Unit Tests (Per Story)
- Each story has 15-30 unit tests
- Mock external dependencies
- Cover edge cases and error scenarios

### Integration Tests
- Story 8.7: End-to-end agent workflow
- Story 8.9: WebSocket streaming
- Story 8.10: Fast vs agent routing
- Story 8.11: iOS WebSocket client

### Manual QA
- Real screenshots (50+ diverse test cases)
- Performance benchmarking
- Cost tracking
- User acceptance testing (20 internal users)

---

## Key Files Created

### Backend
```
backend/app/
├── agents/
│   ├── worker.py                    # Story 8.1
│   ├── mcp_agent.py                 # Story 8.7
│   ├── reasoning.py                 # Story 8.8
│   └── tools/
│       ├── scam_database.py         # Story 8.3
│       ├── exa_search.py            # Story 8.4
│       ├── domain_reputation.py     # Story 8.5
│       ├── phone_validator.py       # Story 8.6
│       └── company_verification.py  # Story 8.13
├── services/
│   ├── entity_extractor.py          # Story 8.2 (+ 8.13 enhancements)
│   ├── entity_patterns.py           # Story 8.2 (+ 8.13 company patterns)
│   └── entity_normalizer.py         # Story 8.2
└── main.py                          # Updated in 8.9, 8.10

backend/scripts/
├── seed_scam_db.py                  # Story 8.12
├── update_phishtank.py              # Story 8.12
└── archive_old_scams.py             # Story 8.12

backend/migrations/
└── 005_create_scam_reports.sql      # Story 8.3
```

### iOS
```
TypeSafe/Views/
├── AgentProgressView.swift          # Story 8.11
└── AgentProgressViewModel.swift     # Story 8.11
```

---

## Success Metrics

### Technical Performance
- Entity extraction: < 100ms
- Scam DB lookup: < 10ms
- Agent scan (complex): < 30s (p95)
- Fast path scan: < 3s (maintained)
- WebSocket reliability: < 1% connection failures

### Business Impact
- False negative reduction: 40% improvement
- User trust: >80% positive feedback
- Feature adoption: >60% of entity-containing scans use agent
- Cost: < $100/month for 5000 scans

### Quality Gates
- Unit test coverage: >90%
- Integration test coverage: >80%
- No P0 bugs in production
- Performance benchmarks met

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| External API downtime | Graceful degradation, fallback to available tools |
| Cost overruns | Caching, budget caps, daily alerts |
| Agent reasoning errors | Confidence thresholds, human review queue |
| Celery worker crashes | Auto-restart, retry logic, redundant workers |
| Complex scaling | Start with 1 worker, horizontal scaling later |

---

## Notes

- All stories are **production-ready** with full testing
- Each story is **independently deployable** (with dependencies)
- Stories 8.4, 8.5, 8.6 can be **parallelized** for faster delivery
- Story 8.7 is the **critical integration point** - all tools come together
- Story 8.11 (iOS) can be developed **concurrently** with backend stories
- Story 8.13 (Company Verification) is an **optional enhancement** that can be added anytime after 8.2
- Company verification addresses a specific scam category: **business impersonation**

---

## Quick Start for Developers

1. **Read Epic 8 main document** for overall context
2. **Start with Story 8.1** - infrastructure is required first
3. **Work in order** unless parallelizing tools (8.4-8.6)
4. **Run tests** after each story completion
5. **Integration test** after Phase 2 (Week 9)
6. **Full QA** after Phase 3 (Week 10)

---

**Last Updated:** October 18, 2025  
**Status:** 13 stories drafted and ready for development (Story 8.13 added for company verification)

