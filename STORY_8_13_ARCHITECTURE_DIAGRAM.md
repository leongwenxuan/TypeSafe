# Story 8.13: Company Verification Tool - Architecture Diagram

---

## System Architecture with Company Verification Tool

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         TypeSafe iOS App                                 │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  User takes screenshot of suspicious message                     │   │
│  │  "Your package is held by DHL Express SG. Pay $50 to release."  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                  │                                       │
│                                  ▼                                       │
│                            OCR Processing                                │
│                                  │                                       │
└──────────────────────────────────┼───────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Backend FastAPI Server                           │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │           Entity Extraction Service (Story 8.2)                 │    │
│  │                                                                  │    │
│  │  Input: "Your package is held by DHL Express SG"               │    │
│  │                                                                  │    │
│  │  Extracted Entities:                                            │    │
│  │    - Phone: None                                                │    │
│  │    - URL: None                                                  │    │
│  │    - Email: None                                                │    │
│  │    - Company: "DHL Express SG" ← NEW (Story 8.13)             │    │
│  │    - Payment: "$50"                                             │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                  │                                       │
│                                  ▼                                       │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │         MCP Agent Orchestration (Story 8.7)                     │    │
│  │                                                                  │    │
│  │  Entity: "DHL Express SG" (company)                            │    │
│  │    → Route to company verification tools                        │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                  │                                       │
└──────────────────────────────────┼───────────────────────────────────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
                    ▼              ▼              ▼
        ┌───────────────┐  ┌──────────────┐  ┌────────────────┐
        │  Scam Database│  │   Company    │  │  Domain        │
        │  Tool         │  │ Verification │  │  Reputation    │
        │  (Story 8.3)  │  │  Tool        │  │  Tool          │
        │               │  │ (Story 8.13) │  │  (Story 8.5)   │
        └───────────────┘  └──────────────┘  └────────────────┘
                │                  │                  │
                │                  │                  │
                ▼                  ▼                  ▼
    ┌─────────────────┐  ┌──────────────────┐  ┌──────────────┐
    │ Supabase        │  │ Business         │  │ WHOIS        │
    │ scam_reports    │  │ Registries       │  │ Lookup       │
    │                 │  │                  │  │              │
    │ Check: Not found│  │ - ACRA (SG)     │  │ Check domain │
    │                 │  │ - Companies House│  │ age, SSL     │
    └─────────────────┘  │ - SEC (US)      │  └──────────────┘
                         │                  │
                         │ Check: NOT FOUND │
                         │ "DHL Express SG" │
                         │ is NOT registered│
                         └──────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
                    ▼                             ▼
        ┌─────────────────────┐      ┌────────────────────┐
        │ Pattern Detection   │      │ Typo-Squatting     │
        │                     │      │ Detection          │
        │ - Missing "Pte Ltd" │      │                    │
        │   suffix for SG     │      │ Similar to "DHL"   │
        │ - Generic name      │      │ (legitimate)       │
        └─────────────────────┘      └────────────────────┘
                    │                             │
                    └──────────────┬──────────────┘
                                   │
                                   ▼
        ┌──────────────────────────────────────────────────┐
        │         Company Verification Result               │
        │                                                   │
        │  legitimate: False                                │
        │  confidence: 15.0                                 │
        │  risk_level: "high"                              │
        │  registration_verified: False                     │
        │  suspicious_patterns:                             │
        │    - "Missing legal suffix for SG"               │
        │  similar_legitimate_companies:                    │
        │    - "DHL"                                        │
        └──────────────────────────────────────────────────┘
                                   │
                                   ▼
        ┌──────────────────────────────────────────────────┐
        │       Agent Reasoning (Story 8.8)                 │
        │                                                   │
        │  Evidence collected:                              │
        │  1. Company "DHL Express SG" NOT registered       │
        │  2. Missing legal suffix (Pte Ltd)               │
        │  3. Similar to legitimate "DHL"                   │
        │  4. Payment request ($50)                         │
        │                                                   │
        │  Risk Score: 95/100                              │
        │  Verdict: HIGH RISK - SCAM                        │
        └──────────────────────────────────────────────────┘
                                   │
                                   ▼
        ┌──────────────────────────────────────────────────┐
        │           Final Agent Response                    │
        │                                                   │
        │  🚨 HIGH RISK SCAM DETECTED                      │
        │                                                   │
        │  The company "DHL Express SG" is NOT a           │
        │  registered business in Singapore.                │
        │                                                   │
        │  Evidence:                                        │
        │  • No registration found in ACRA database         │
        │  • Missing "Pte Ltd" legal suffix                 │
        │  • Similar name to legitimate DHL                 │
        │  • Suspicious payment request                     │
        │                                                   │
        │  ⚠️ This appears to be a fake company            │
        │  impersonating DHL. DO NOT make any payment.      │
        │                                                   │
        │  Real DHL: "DHL Express (Singapore) Pte Ltd"     │
        │  UEN: 198600521G                                  │
        └──────────────────────────────────────────────────┘
                                   │
                                   ▼
        ┌──────────────────────────────────────────────────┐
        │           Display to User (iOS App)               │
        │                                                   │
        │  [Red Banner]                                     │
        │  🚨 HIGH RISK                                     │
        │                                                   │
        │  This message appears to be from a fake company.  │
        │  "DHL Express SG" is not a registered business.   │
        │                                                   │
        │  [Button: View Details]                           │
        │  [Button: Report Scam]                            │
        └──────────────────────────────────────────────────┘
```

---

## Tool Flow Comparison

### Before Story 8.13 (No Company Verification)

```
User Screenshot: "Package from DHL Express SG"
        ↓
Entity Extraction: No specific entities detected
        ↓
Agent: Can't verify company legitimacy
        ↓
Result: UNCERTAIN - Cannot determine if scam
        ↓
❌ FALSE NEGATIVE - Scam not detected
```

### After Story 8.13 (With Company Verification)

```
User Screenshot: "Package from DHL Express SG"
        ↓
Entity Extraction: "DHL Express SG" (company entity)
        ↓
Company Verification Tool:
  - Registry check: NOT FOUND
  - Pattern check: Missing "Pte Ltd"
  - Similarity: Similar to "DHL" (legitimate)
        ↓
Agent: HIGH RISK - Fake company impersonating DHL
        ↓
Result: HIGH RISK - Scam detected with evidence
        ↓
✅ TRUE POSITIVE - Scam successfully detected
```

---

## Multi-Tool Analysis Flow

### Example: Sophisticated Scam Message

```
Message: "DHL Express SG package ready. 
          Call +65-8888-8888 or visit dhl-sg-delivery.com 
          to claim. Pay $50 handling fee."
```

### Tool Orchestration

```
┌──────────────────────────────────────────────────────────────┐
│              Entity Extraction Results                        │
├──────────────────────────────────────────────────────────────┤
│  Company: "DHL Express SG"                                   │
│  Phone: "+65-8888-8888"                                      │
│  URL: "dhl-sg-delivery.com"                                  │
│  Payment: "$50"                                              │
└──────────────────────────────────────────────────────────────┘
                            │
                ┌───────────┼───────────┐
                │           │           │
                ▼           ▼           ▼
    ┌──────────────┐  ┌───────────┐  ┌─────────────┐
    │  Company     │  │   Phone   │  │   Domain    │
    │ Verification │  │ Validator │  │ Reputation  │
    └──────────────┘  └───────────┘  └─────────────┘
            │               │               │
            ▼               ▼               ▼
    ┌──────────────┐  ┌───────────┐  ┌─────────────┐
    │ NOT          │  │ Suspicious│  │ NOT         │
    │ registered   │  │ pattern   │  │ official    │
    │ in SG        │  │ (all 8s)  │  │ DHL domain  │
    └──────────────┘  └───────────┘  └─────────────┘
            │               │               │
            └───────────────┼───────────────┘
                            │
                            ▼
            ┌──────────────────────────────┐
            │     Agent Reasoning          │
            │                              │
            │  3/3 tools flagged issues:   │
            │  • Fake company              │
            │  • Suspicious phone          │
            │  • Wrong domain              │
            │                              │
            │  Combined Risk: 98/100       │
            │  Verdict: DEFINITE SCAM      │
            └──────────────────────────────┘
```

---

## Caching Architecture

### Redis Database Allocation

```
┌─────────────────────────────────────────────────────────────┐
│                     Redis Server                             │
├─────────────────────────────────────────────────────────────┤
│  DB 0: Celery Task Queue (Story 8.1)                        │
│  DB 1: Celery Results Backend (Story 8.1)                   │
│  DB 2: Domain Reputation Cache (Story 8.5) - 7 days         │
│  DB 3: Company Verification Cache (Story 8.13) - 30 days ← NEW │
│  DB 4: Exa Search Cache (Story 8.4) - 24 hours              │
└─────────────────────────────────────────────────────────────┘
```

### Cache Key Format

```
company_verification:{md5_hash}

Example:
company_verification:a1b2c3d4e5f6g7h8i9j0

Stores:
{
  "company_name": "DHL Express SG",
  "country": "Singapore",
  "legitimate": false,
  "confidence": 15.0,
  "registration_verified": false,
  "cached_at": "2025-10-18T10:30:00Z",
  "expires_at": "2025-11-17T10:30:00Z"  // 30 days later
}
```

---

## Data Flow for Registry Checks

### Singapore Company Check

```
┌─────────────────────────────────────────────────────────────┐
│  Company Verification Tool                                   │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Check Redis Cache (DB 3)                                    │
│  Key: company_verification:{hash("DHL Express SG:SG")}      │
└─────────────────────────────────────────────────────────────┘
                     │
                     ├─ Cache Hit → Return cached result
                     │
                     └─ Cache Miss ▼
                                    
┌─────────────────────────────────────────────────────────────┐
│  ACRA BizFile API Request                                    │
│  https://api.bizfile.gov.sg/v1/entity/search               │
│  Authorization: Bearer {ACRA_API_KEY}                        │
│  Params: { "name": "DHL Express" }                          │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  API Response                                                │
│  {                                                           │
│    "results": []  // NOT FOUND                              │
│  }                                                           │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Process Result                                              │
│  - registration_verified: False                              │
│  - Run pattern detection                                     │
│  - Run similarity check                                      │
│  - Calculate risk score                                      │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Cache Result (30 days)                                      │
│  Redis SETEX company_verification:{hash} 2592000 {...}     │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Return CompanyVerificationResult                            │
└─────────────────────────────────────────────────────────────┘
```

---

## Error Handling and Graceful Degradation

### When Registry API Fails

```
┌─────────────────────────────────────────────────────────────┐
│  Company Verification Tool                                   │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Run All Checks in Parallel (asyncio.gather)                │
│  - Registry check                                            │
│  - Online presence check                                     │
│  - Pattern detection                                         │
│  - Similarity check                                          │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Registry Check FAILS (timeout/API error)                    │
│  ❌ Exception caught                                         │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Continue with Other Checks                                  │
│  ✅ Pattern detection: 2 suspicious patterns                │
│  ✅ Similarity check: Similar to "DHL"                      │
│  ✅ Online presence: No website found                       │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Calculate Risk Based on Available Data                      │
│  - Registry: UNKNOWN (check failed)                         │
│  - Patterns: SUSPICIOUS                                      │
│  - Similarity: HIGH RISK (impersonation)                    │
│                                                              │
│  Result: MEDIUM RISK (partial data)                         │
│  Confidence: 60% (lower due to missing registry data)       │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Return Result with Error Notes                              │
│  - checks_completed: { "registry": false, ... }             │
│  - error_messages: { "registry": "API timeout" }            │
│  - Agent still gets useful information                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Performance Characteristics

### Timing Breakdown

```
Total Company Verification: < 8 seconds (p95)

┌─────────────────────────────────────────────────────────┐
│  Step                               Time                 │
├─────────────────────────────────────────────────────────┤
│  1. Cache lookup                    < 50ms              │
│  2. Registry check (parallel)       < 5s                │
│  3. Online presence (parallel)      < 3s                │
│  4. Pattern detection (parallel)    < 100ms             │
│  5. Similarity check (parallel)     < 50ms              │
│  6. Risk calculation                < 10ms              │
│  7. Cache storage                   < 20ms              │
├─────────────────────────────────────────────────────────┤
│  Total (parallel execution)         ~5-8s               │
│  Total (cache hit)                  < 50ms              │
└─────────────────────────────────────────────────────────┘

* Parallel execution means steps 2-5 run simultaneously
* Longest step determines total time (registry check ~5s)
```

---

## Integration with Agent Reasoning

### Evidence Contribution

```
┌─────────────────────────────────────────────────────────────┐
│              Agent Evidence Collection                        │
├─────────────────────────────────────────────────────────────┤
│  Evidence 1: Scam Database                                   │
│    - Phone +65-8888-8888: NOT FOUND                         │
│    - Weight: Medium (no prior reports)                       │
├─────────────────────────────────────────────────────────────┤
│  Evidence 2: Phone Validator                                 │
│    - Pattern: All same digits (suspicious)                   │
│    - Weight: High (clear pattern)                            │
├─────────────────────────────────────────────────────────────┤
│  Evidence 3: Domain Reputation                               │
│    - Domain age: 3 days (very new)                          │
│    - SSL: Missing                                            │
│    - Weight: High (new domain, no SSL)                       │
├─────────────────────────────────────────────────────────────┤
│  Evidence 4: Company Verification ← NEW (Story 8.13)        │
│    - Registration: NOT FOUND in Singapore                    │
│    - Patterns: Missing legal suffix                          │
│    - Similarity: Impersonating DHL                           │
│    - Weight: VERY HIGH (official registry check)             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Agent Reasoning (Story 8.8)                      │
│                                                              │
│  Risk Score Calculation:                                     │
│  - Scam DB (not found): +0 points                           │
│  - Phone pattern: +25 points                                 │
│  - Domain reputation: +30 points                             │
│  - Company verification: +40 points ← HIGHEST WEIGHT        │
│                                                              │
│  Total: 95/100 → HIGH RISK                                  │
│                                                              │
│  Reasoning:                                                  │
│  "This message contains a fake company impersonating DHL.    │
│   'DHL Express SG' is not registered in Singapore.          │
│   Combined with suspicious phone pattern and new domain,     │
│   this is almost certainly a scam."                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Story Dependencies Visualization

```
┌────────────────────────────────────────────────────────────┐
│                   Epic 8 Tool Ecosystem                     │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Phase 1: Foundation                                        │
│    8.1: Celery & Redis ──┐                                 │
│                          │                                  │
│    8.2: Entity Extraction ├─→ [Required for all tools]    │
│                          │                                  │
│  Phase 2: Core Tools     │                                  │
│    8.3: Scam Database ───┤                                 │
│    8.4: Exa Search ──────┤                                 │
│    8.5: Domain Reputation ┤                                 │
│    8.6: Phone Validator ──┤                                 │
│                          │                                  │
│  Phase 3: Orchestration  │                                  │
│    8.7: Agent Orchestration ←─┘                            │
│    8.8: Agent Reasoning                                     │
│    8.9: WebSocket Streaming                                 │
│    8.10: Smart Routing                                      │
│                                                             │
│  Phase 4: Enhancement                                       │
│    8.13: Company Verification ← NEW                         │
│      │                                                      │
│      ├─ Requires: 8.2 (Entity Extraction)                  │
│      ├─ Enhances: 8.7 (Agent Orchestration)                │
│      └─ Parallel to: 8.12 (Database Seeding)              │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

---

## Summary

The **Company Verification Tool (Story 8.13)** adds a critical capability to TypeSafe's MCP Agent system:

✅ **Detects fake companies** through official registry checks  
✅ **Identifies impersonation** with typo-squatting detection  
✅ **Multi-country support** adapts to user location  
✅ **Seamless integration** with existing tool ecosystem  
✅ **High-value evidence** for agent reasoning (40 points)  
✅ **Performance optimized** with 30-day caching  

**Result:** TypeSafe can now identify business impersonation scams with official government data, providing users with the highest level of confidence in scam detection.

---

**Created:** October 18, 2025  
**Story:** 8.13 - Company Verification Tool  
**Status:** 📝 Architecture Documented


