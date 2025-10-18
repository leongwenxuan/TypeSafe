# Exa Search Tool - Quick Reference Guide

**Story 8.4** | **Status:** ✅ Complete | **Tests:** 23/23 Passing

---

## Setup

### 1. Environment Variables
```bash
# Required
EXA_API_KEY=your_exa_api_key_here

# Optional (with defaults)
EXA_CACHE_TTL=86400          # 24 hours
EXA_MAX_RESULTS=10           # Max results per search
EXA_DAILY_BUDGET=10.0        # $10 USD daily limit
REDIS_URL=redis://localhost:6379
```

### 2. Get API Key
Sign up at [https://exa.ai](https://exa.ai) and get your API key.

---

## Usage

### Basic Search
```python
from app.agents.tools.exa_search import get_exa_search_tool

# Get singleton instance
tool = get_exa_search_tool()

# Search for phone number
response = await tool.search_scam_reports("+18005551234", "phone")

# Check results
for result in response.results:
    print(f"{result.title} [{result.score}]")
    print(f"  {result.url}")
    print(f"  {result.snippet}\n")
```

### Entity Types
```python
# Phone number
await tool.search_scam_reports("+18005551234", "phone")

# URL/Domain
await tool.search_scam_reports("scam-site.com", "url")

# Email
await tool.search_scam_reports("scammer@example.com", "email")

# Bitcoin address
await tool.search_scam_reports("1A1zP1eP5...", "bitcoin")

# Generic payment
await tool.search_scam_reports("ACC123456", "payment")
```

### Check Cache Status
```python
response = await tool.search_scam_reports("+18005551234", "phone")
if response.cached:
    print("Result from cache (no API cost)")
else:
    print("Fresh API result")
```

---

## Cost Tracking

### Track Usage
```python
from app.agents.tools.exa_cost_tracker import get_exa_cost_tracker

tracker = get_exa_cost_tracker()

# Track a search (done automatically by tool)
result = tracker.track_search("phone", "+18005551234")
print(f"Searches today: {result['search_count']}")
print(f"Cost today: ${result['total_cost']:.2f}")
```

### Get Statistics
```python
# Daily stats
stats = tracker.get_daily_stats()
print(f"Searches: {stats['search_count']}")
print(f"Cost: ${stats['total_cost']:.2f}")
print(f"Remaining: ${stats['remaining_budget']:.2f}")
print(f"By type: {stats['entity_type_counts']}")

# Weekly stats
weekly = tracker.get_weekly_stats()
print(f"Week total: ${weekly['total_cost']:.2f}")
print(f"Avg/day: ${weekly['avg_daily_cost']:.2f}")
```

### Check Budget
```python
if tracker.is_budget_exceeded():
    print("⚠️ Daily budget exceeded, skipping search")
else:
    response = await tool.search_scam_reports(entity, type)
```

---

## Response Structure

```python
response = ExaSearchResponse(
    results=[
        ExaSearchResult(
            title="Scam Alert: +1-800-555-1234",
            url="https://reddit.com/r/scams/...",
            snippet="This number called claiming...",
            published_date="2025-10-01T10:00:00Z",
            score=0.9,  # 0-1, higher = more relevant
            domain="reddit.com"
        ),
        # ... more results
    ],
    query='"+18005551234" scam complaints OR fraud reports',
    cached=False,
)
```

---

## Query Templates

The tool automatically builds optimized queries:

| Entity Type | Query Template |
|-------------|----------------|
| phone | `"{entity}" scam complaints OR fraud reports OR "is this a scam"` |
| url | `"{entity}" phishing OR scam warning OR "is this site safe"` |
| email | `"{entity}" spam OR scam reports OR fraudulent` |
| bitcoin | `"{entity}" scam OR fraud OR stolen` |
| payment | `"{entity}" scam OR suspicious OR fraud` |

---

## Trusted Sources

Results from these domains get +0.3 score boost:

- reddit.com
- bbb.org
- ftc.gov, consumer.ftc.gov
- scamwarners.com, scam-detector.com
- scamalert.sg
- reportfraud.ftc.gov
- consumeraffairs.com
- complaintsboard.com
- trustpilot.com, ripoffreport.com
- ic3.gov

---

## Testing

### Run Tests
```bash
cd backend
source venv/bin/activate
pytest tests/test_exa_search_tool.py -v
```

### Test Coverage
```bash
pytest tests/test_exa_search_tool.py --cov=app.agents.tools.exa_search
```

---

## Performance

| Metric | Value |
|--------|-------|
| Timeout | 5 seconds |
| Max Results | 10 (configurable) |
| Date Range | Last 90 days |
| Cache TTL | 24 hours (configurable) |
| Cost per Search | $0.005 |
| Expected Cache Hit Rate | 50-60% |

---

## Troubleshooting

### "EXA_API_KEY not configured"
✅ Add `EXA_API_KEY=your_key` to `.env` file

### Cache not working
✅ Check Redis is running: `redis-cli ping`  
✅ Verify `REDIS_URL` in `.env`

### Timeout errors
✅ Check network connectivity  
✅ Verify Exa API status  
✅ Check for rate limiting (429 errors)

### High costs
✅ Check: `tracker.get_daily_stats()`  
✅ Verify caching is enabled  
✅ Lower `EXA_DAILY_BUDGET` if needed

---

## API Limits

- **Free Tier:** Limited requests/month
- **Paid Tier:** ~$5 per 1000 searches
- **Rate Limit:** Check Exa documentation
- **Timeout:** 5 seconds per request

---

## Integration with MCP Agent

```python
from app.agents.tools.exa_search import get_exa_search_tool
from app.agents.tools.exa_cost_tracker import get_exa_cost_tracker

async def agent_investigate(entity: str, entity_type: str):
    """Agent investigation workflow."""
    
    # Check budget first
    tracker = get_exa_cost_tracker()
    if tracker.is_budget_exceeded():
        return {"error": "Daily budget exceeded"}
    
    # Perform search
    tool = get_exa_search_tool()
    response = await tool.search_scam_reports(entity, entity_type)
    
    # Track cost (automatic if using tool)
    tracker.track_search(entity_type, entity)
    
    # Process results
    if response.results:
        return {
            "found": True,
            "result_count": len(response.results),
            "top_result": response.results[0].to_dict(),
            "evidence": [r.to_dict() for r in response.results[:3]],
            "cached": response.cached
        }
    else:
        return {"found": False, "result_count": 0}
```

---

## Files

| File | Lines | Purpose |
|------|-------|---------|
| `app/agents/tools/exa_search.py` | 527 | Main tool implementation |
| `app/agents/tools/exa_cost_tracker.py` | 333 | Cost tracking |
| `tests/test_exa_search_tool.py` | 677 | Comprehensive tests |
| `app/config.py` | +24 | Configuration |

---

## Next Steps

- ✅ Story 8.4: Complete
- 🔄 Story 8.5: Domain Reputation Tool
- 🔄 Story 8.6: Phone Validator Tool
- 🔄 Story 8.7: MCP Agent Orchestration

---

**Documentation:** See `STORY_8_4_IMPLEMENTATION_SUMMARY.md` for full details  
**Support:** Check logs with `logger.debug()` enabled for detailed execution flow

