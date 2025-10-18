# Story 8.13: Company Verification Tool - Quick Reference

**Status:** 📝 Ready for Development  
**Priority:** P1 (Business Impersonation Detection)  
**Effort:** 16 hours

---

## Overview

The **Company Verification Tool** detects fake companies and business impersonation scams by checking official registries, online presence, and suspicious patterns.

**Key Capability:** Identifies fraudulent entities claiming to be legitimate businesses.

---

## Quick Start

### Basic Usage

```python
from app.agents.tools.company_verification import get_company_verification_tool

# Get singleton instance
tool = get_company_verification_tool()

# Verify company
result = await tool.verify_company(
    company_name="DHL Express SG",
    country="SG"  # Singapore
)

# Check result
if result.legitimate:
    print(f"✅ Verified: {result.company_name}")
    print(f"Registration: {result.registration_number}")
    print(f"Confidence: {result.confidence}%")
else:
    print(f"⚠️ FAKE: {result.company_name}")
    print(f"Risk Level: {result.risk_level}")
    print(f"Patterns: {result.suspicious_patterns}")
```

### Real-World Examples

#### Example 1: Fake Courier Company
```python
# Scammer claims: "FedEx Express SG"
result = await tool.verify_company("FedEx Express SG", "SG")

# Result:
# - legitimate: False
# - risk_level: "high"
# - registration_verified: False
# - suspicious_patterns: ["Missing legal suffix for SG"]
# - similar_legitimate_companies: ["FedEx"]

# Agent verdict: "⚠️ HIGH RISK - 'FedEx Express SG' is not registered in Singapore. 
# Similar to legitimate company 'FedEx' but not the same entity."
```

#### Example 2: Legitimate Company
```python
# Real company
result = await tool.verify_company("DHL Express (Singapore) Pte Ltd", "SG")

# Result:
# - legitimate: True
# - risk_level: "low"
# - registration_verified: True
# - registration_number: "198600521G"
# - confidence: 95.0

# Agent verdict: "✅ LOW RISK - Verified legitimate company registered in Singapore."
```

#### Example 3: Impersonation Scam
```python
# Scammer: "Amazon Refund Department"
result = await tool.verify_company("Amazon Refund Department", "US")

# Result:
# - legitimate: False
# - risk_level: "high"
# - registration_verified: False
# - suspicious_patterns: ["Suspicious keyword: 'refund'"]
# - similar_legitimate_companies: ["Amazon"]

# Agent verdict: "🚨 HIGH RISK - This is not a real Amazon entity. 
# Amazon doesn't have a 'Refund Department' as a separate company."
```

---

## Country Support

### Supported Countries

| Country Code | Country Name | Registry | Status |
|--------------|--------------|----------|--------|
| **SG** | Singapore | ACRA BizFile | ✅ Full support |
| **GB/UK** | United Kingdom | Companies House | ✅ Full support |
| **US** | United States | SEC EDGAR | ⚠️ Public companies only |
| **CA** | Canada | Corporations Canada | 🚧 Placeholder |
| **AU** | Australia | ASIC | 🚧 Placeholder |

### API Keys Required

```bash
# Singapore ACRA BizFile API
ACRA_API_KEY=your_acra_api_key_here

# UK Companies House API
COMPANIES_HOUSE_API_KEY=your_companies_house_key_here
```

**Note:** Tool works without API keys but with limited registry verification.

---

## Features

### 1. Business Registry Checks ✅

Verifies company registration in official government databases:
- Registration number
- Incorporation date
- Company status (Active/Dissolved)
- Registered address

### 2. Online Presence Validation 🚧

Checks company's digital footprint:
- Official website
- Domain age
- Social media (LinkedIn, Facebook, Twitter)
- Review sites (Trustpilot, Google Reviews, BBB)
- News mentions

### 3. Pattern Detection ✅

Identifies suspicious characteristics:
- **Suspicious keywords:** "refund", "recovery", "tax office", "customs"
- **Generic names:** "International Trading Company"
- **Missing legal suffix:** Company missing "Pte Ltd", "Inc", etc.
- **Unusual characters:** Excessive numbers in name

### 4. Typo-Squatting Detection ✅

Detects impersonation attempts:
- **Similar names:** "Microssoft" → Similar to "Microsoft"
- **High similarity (70-95%):** Likely fake company trying to impersonate
- **Known legitimate companies:** Compares against database of major brands

### 5. Caching ✅

- **Cache duration:** 30 days (longer than domain cache)
- **Cache key:** MD5 hash of `company_name:country`
- **Redis DB:** Database 3 (separate from other tools)

---

## Result Structure

```python
@dataclass
class CompanyVerificationResult:
    # Basic info
    company_name: str
    normalized_name: str
    country: str
    
    # Verdict
    legitimate: bool           # True = verified, False = fake
    confidence: float          # 0-100
    risk_level: str           # low, medium, high, unknown
    
    # Registry verification
    registration_verified: bool
    registration_number: Optional[str]
    incorporation_date: Optional[str]
    company_status: Optional[str]
    registered_address: Optional[str]
    
    # Online presence
    has_official_website: bool
    domain_age_days: Optional[int]
    social_media_presence: Dict[str, bool]
    review_site_presence: Dict[str, bool]
    news_mentions: int
    
    # Pattern analysis
    suspicious_patterns: List[str]
    similar_legitimate_companies: List[str]
    
    # Metadata
    checks_completed: Dict[str, bool]
    error_messages: Dict[str, str]
    cached: bool
```

---

## Scoring Logic

### Legitimacy Score Calculation

Starting score: **50** (neutral)

**Positive Signals:**
- ✅ Registry verified: **+40 points**
- ✅ Has official website: **+10 points**
- ✅ Domain age > 1 year: **+10 points**

**Negative Signals:**
- ❌ Not in registry: **-30 points**
- ❌ Suspicious pattern: **-10 points each**
- ❌ Similar to known company: **-20 points**
- ❌ Domain age < 30 days: **-10 points**

**Risk Levels:**
- **Low (score ≥ 70):** Legitimate company
- **Medium (score 40-69):** Uncertain, needs review
- **High (score < 40):** Likely fake/scam

---

## Integration with MCP Agent

### Entity Extraction Enhancement

Add company name patterns to `entity_extractor.py`:

```python
# Company name patterns
COMPANY_PATTERNS = [
    # With legal suffix
    r'\b([A-Z][a-zA-Z]+(?: [A-Z][a-zA-Z]+)*) (?:Pte Ltd|Inc|Corp|Limited|LLC)\b',
    
    # Department/division patterns (often scam indicators)
    r'\b([A-Z][a-zA-Z]+(?: [A-Z][a-zA-Z]+)*) (?:Department|Division|Unit|Center)\b',
    
    # Generic company patterns
    r'\b([A-Z][a-zA-Z]+(?: [A-Z][a-zA-Z]+)*) (?:Company|Corporation|Services)\b',
]
```

### Agent Orchestration

In `mcp_agent.py`:

```python
async def _check_company(self, company: str, country: str) -> List[AgentEvidence]:
    """Run tools for company name."""
    evidence = []
    
    tasks = [
        # Company verification (primary tool)
        self._run_tool(
            "company_verification",
            "company",
            company,
            lambda: self.company_tool.verify_company(company, country)
        ),
        # Scam database lookup (secondary)
        self._run_tool(
            "scam_db",
            "company",
            company,
            lambda: self.scam_db_tool.check_entity(company, "company")
        ),
    ]
    
    results = await asyncio.gather(*tasks, return_exceptions=True)
    
    for result in results:
        if isinstance(result, AgentEvidence):
            evidence.append(result)
    
    return evidence
```

---

## Common Scam Patterns

### 1. Fake Courier/Logistics
```
❌ "DHL Express SG"
❌ "FedEx Singapore Pte"
❌ "UPS Delivery Service"
✅ Real: "DHL Express (Singapore) Pte Ltd" (UEN: 198600521G)
```

### 2. Tech Company Impersonation
```
❌ "Apple Support Team"
❌ "Microsoft Security Department"
❌ "Amazon Refund Center"
✅ Real companies don't have these as separate entities
```

### 3. Government Impersonation
```
❌ "Singapore Customs Recovery Unit"
❌ "IRS Tax Collection Services"
❌ "Immigration Verification Department"
✅ Government agencies are not private companies
```

### 4. Typo-Squatting
```
❌ "Microssoft Corporation"
❌ "Paypa1 Inc"
❌ "Goog1e LLC"
✅ Always verify exact spelling
```

### 5. Generic Names
```
❌ "International Trading Company"
❌ "Global Services Ltd"
❌ "Universal Solutions Inc"
✅ Too generic, often used by scammers
```

---

## Performance

### Benchmarks

| Operation | Target | Implementation |
|-----------|--------|----------------|
| Single company check | < 8s (p95) | ✅ Parallel checks |
| Registry lookup | < 5s | ✅ Async HTTP |
| Cache hit | < 50ms | ✅ Redis lookup |
| Pattern detection | < 100ms | ✅ Regex + similarity |

### Optimization

1. **Parallel Execution:** All checks run concurrently
2. **30-Day Caching:** Reduces API calls significantly
3. **Graceful Degradation:** Returns partial results if some checks fail
4. **Timeouts:** 5-second limit per registry check

---

## Testing

### Test Coverage

- ✅ Company name normalization
- ✅ Registry checks (mocked APIs)
- ✅ Pattern detection (40+ test cases)
- ✅ Typo-squatting detection
- ✅ Full verification flow
- ✅ Caching behavior
- ✅ Error handling

### Run Tests

```bash
cd backend
pytest tests/test_company_verification_tool.py -v
```

---

## Cost Estimates

| Service | Free Tier | Cost per 1000 |
|---------|-----------|---------------|
| **Singapore ACRA** | 100/day | $5-10 |
| **UK Companies House** | 600/5min | Free |
| **Redis Caching** | N/A | ~$0.10 |

**With 30-day caching:** ~$2-5 per 1000 unique companies

---

## Troubleshooting

### Issue: "API key not configured"

**Solution:** Add API keys to `.env`:
```bash
ACRA_API_KEY=your_key_here
COMPANIES_HOUSE_API_KEY=your_key_here
```

### Issue: "Country not supported"

**Solution:** Tool defaults to US. Supported: SG, GB, UK, US, CA, AU.

### Issue: "Registry check timeout"

**Solution:** Network issue or API down. Tool returns partial results.

### Issue: "False positive - legitimate company flagged"

**Solution:** Check:
- Correct country code?
- Exact company name with legal suffix?
- Company recently registered (< 30 days)?

---

## Next Steps

1. **Story 8.2:** Add company name extraction to entity extractor
2. **Story 8.7:** Integrate with MCP agent orchestration
3. **Story 8.8:** Use company verification in agent reasoning
4. **Story 8.12:** Seed scam database with fake company names

---

## Related Stories

- **Story 8.2:** Entity Extraction (add company patterns)
- **Story 8.3:** Scam Database (stores fake company names)
- **Story 8.5:** Domain Reputation (checks company websites)
- **Story 8.7:** MCP Agent Orchestration (uses this tool)

---

## Quick Decision Tree

```
Company name detected → Check registry
                       ↓
               Registry verified?
              ↙              ↘
            YES              NO
             ↓               ↓
      Check patterns    Check patterns
             ↓               ↓
    Patterns clean?   Suspicious?
        ↙      ↘         ↙      ↘
      YES      NO      YES      NO
       ↓        ↓        ↓        ↓
   LOW RISK  MEDIUM  HIGH RISK  MEDIUM
              RISK              RISK
```

---

**Created:** October 18, 2025  
**Story:** 8.13 - Company Verification Tool  
**Status:** 📝 Ready for Development


