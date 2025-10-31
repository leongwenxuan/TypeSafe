# Story 8.4: Exa Web Search Tool Integration

**Story ID:** 8.4  
**Epic:** Epic 8 - MCP Agent with Multi-Tool Orchestration  
**Priority:** P0 (Critical for External Validation)  
**Effort:** 16 hours  
**Assignee:** Backend Developer  
**Status:** 📝 Ready for Development

---

## User Story

**As an** MCP agent,  
**I want** to search the web for scam reports and complaints,  
**so that** I can find evidence of scams not yet in our database.

---

## Description

The Exa Web Search Tool provides the agent's ability to discover **new scams** and find **external evidence** from the web. While the Scam Database Tool (Story 8.3) handles known scams, Exa Search discovers:

- Recent scam complaints on Reddit, forums, complaint sites
- News articles about new scam campaigns
- BBB reports and consumer protection warnings
- Social media discussions about suspicious entities

**Why Exa over Google Search?**
- **Better for scam detection:** Exa specializes in finding discussions and complaints
- **Neural search:** Understands semantic meaning, not just keywords
- **Forum/discussion focus:** Prioritizes Reddit, complaint sites, BBB
- **Clean API:** Easy integration, predictable costs

**Real-World Example:**
```
User screenshot: "Call +1-888-NEW-SCAM for prize"
↓
Scam Database: NOT FOUND (new scam number)
↓
Exa Search: "888-NEW-SCAM scam complaints"
↓
Results: 12 Reddit posts, 3 BBB complaints, 1 ScamWarners thread
↓
Agent: "HIGH RISK - Found 12 recent web complaints about this number"
```

---

## Acceptance Criteria

### API Integration
- [ ] 1. Exa API key configured in environment variables (`EXA_API_KEY`)
- [ ] 2. `ExaSearchTool` class created in `app/agents/tools/exa_search.py`
- [ ] 3. API endpoint: `https://api.exa.ai/search` (POST request)
- [ ] 4. Request headers: `x-api-key`, `Content-Type: application/json`
- [ ] 5. Timeout: 5 seconds per search (fail gracefully on timeout)
- [ ] 6. Error handling: Retry once on network errors, then fail gracefully

### Query Optimization
- [ ] 7. Query templates optimized for scam detection:
   - Phone: `"{number}" scam complaints OR fraud reports`
   - URL: `"{domain}" phishing OR scam warning`
   - Email: `"{email}" spam OR scam reports`
- [ ] 8. Uses Exa's `use_autoprompt=True` for better query expansion
- [ ] 9. Category filtering: Prioritize `discussion` and `news` categories
- [ ] 10. Num results: Default 10, configurable (cost optimization)
- [ ] 11. Date filtering: Last 90 days for recency (optional parameter)

### Result Processing
- [ ] 12. Returns list of results with: `title`, `snippet`, `url`, `published_date`, `score`
- [ ] 13. Result filtering: Prioritize high-authority sources (Reddit, BBB, government sites)
- [ ] 14. Result scoring: Rank by relevance and source credibility
- [ ] 15. Snippet extraction: Extract relevant context (100-200 chars)
- [ ] 16. Deduplication: Remove duplicate results from same domain

### Performance & Cost Control
- [ ] 17. Rate limiting: Max 10 searches per agent scan (prevent runaway costs)
- [ ] 18. Caching: Cache results for 24 hours (same entity, same query)
- [ ] 19. Cache key: Hash of `entity_type + entity_value + query_template`
- [ ] 20. Cache storage: Redis with 24-hour TTL
- [ ] 21. Cost tracking: Log API usage and costs per scan
- [ ] 22. Daily budget cap: Alert if daily spend > $10 (configurable)

### Testing
- [ ] 23. Unit tests with mocked Exa API responses
- [ ] 24. Integration tests with real API (staging only, rate-limited)
- [ ] 25. Cost analysis: Track API costs per scan type
- [ ] 26. Performance tests: Query latency under load
- [ ] 27. Error handling tests: Timeout, rate limit, invalid API key

---

## Technical Implementation

### Core Implementation

**`app/agents/tools/exa_search.py`:**

```python
"""Exa Web Search Tool for MCP Agent."""

import os
import httpx
import hashlib
import logging
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
from datetime import datetime, timedelta
import json

logger = logging.getLogger(__name__)


@dataclass
class ExaSearchResult:
    """Single search result from Exa."""
    title: str
    url: str
    snippet: str
    published_date: Optional[str]
    score: float
    domain: str
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "title": self.title,
            "url": self.url,
            "snippet": self.snippet,
            "published_date": self.published_date,
            "score": self.score,
            "domain": self.domain
        }


@dataclass
class ExaSearchResponse:
    """Response from Exa search."""
    results: List[ExaSearchResult]
    query: str
    cached: bool = False
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "results": [r.to_dict() for r in self.results],
            "query": self.query,
            "cached": self.cached,
            "result_count": len(self.results)
        }


class ExaSearchTool:
    """
    Tool for searching the web using Exa API.
    
    Exa provides neural search optimized for finding discussions, complaints,
    and reports - perfect for scam detection.
    """
    
    # Query templates for different entity types
    QUERY_TEMPLATES = {
        "phone": '"{entity}" scam complaints OR fraud reports OR "is this a scam"',
        "url": '"{entity}" phishing OR scam warning OR "is this site safe"',
        "email": '"{entity}" spam OR scam reports OR fraudulent',
        "bitcoin": '"{entity}" scam OR fraud OR stolen',
        "payment": '"{entity}" scam OR suspicious OR fraud'
    }
    
    # Trusted source domains (boost in scoring)
    TRUSTED_DOMAINS = {
        'reddit.com', 'bbb.org', 'ftc.gov', 'consumer.ftc.gov',
        'scamwarners.com', 'scam-detector.com', 'scamalert.sg',
        'reportfraud.ftc.gov', 'consumeraffairs.com'
    }
    
    def __init__(
        self, 
        api_key: Optional[str] = None,
        cache_enabled: bool = True,
        max_results: int = 10
    ):
        """
        Initialize Exa search tool.
        
        Args:
            api_key: Exa API key (defaults to env var EXA_API_KEY)
            cache_enabled: Enable result caching (24 hour TTL)
            max_results: Maximum results per search (default: 10)
        """
        self.api_key = api_key or os.getenv('EXA_API_KEY')
        if not self.api_key:
            raise ValueError("EXA_API_KEY not configured")
        
        self.base_url = "https://api.exa.ai/search"
        self.cache_enabled = cache_enabled
        self.max_results = max_results
        self.timeout = 5.0  # 5 second timeout
        
        # Initialize cache (Redis)
        if cache_enabled:
            try:
                import redis
                self.cache = redis.from_url(
                    os.getenv('REDIS_URL', 'redis://localhost:6379/2'),
                    decode_responses=True
                )
                logger.info("Exa search cache enabled (Redis)")
            except Exception as e:
                logger.warning(f"Failed to initialize cache: {e}. Caching disabled.")
                self.cache_enabled = False
        
        logger.info(f"ExaSearchTool initialized (max_results={max_results})")
    
    async def search_scam_reports(
        self, 
        entity: str, 
        entity_type: str
    ) -> ExaSearchResponse:
        """
        Search for scam reports about an entity.
        
        Args:
            entity: Entity to search for (phone number, URL, email, etc.)
            entity_type: Type of entity (phone, url, email, bitcoin, payment)
        
        Returns:
            ExaSearchResponse with results
        """
        # Build query from template
        query = self._build_query(entity, entity_type)
        
        # Check cache first
        if self.cache_enabled:
            cached_result = self._get_cached(entity, entity_type, query)
            if cached_result:
                logger.info(f"Cache hit for {entity_type}: {entity}")
                return cached_result
        
        # Perform search
        try:
            results = await self._execute_search(query)
            
            # Post-process results
            processed_results = self._process_results(results)
            
            response = ExaSearchResponse(
                results=processed_results,
                query=query,
                cached=False
            )
            
            # Cache results
            if self.cache_enabled:
                self._cache_result(entity, entity_type, query, response)
            
            logger.info(f"Exa search completed: {len(processed_results)} results for {entity}")
            return response
        
        except Exception as e:
            logger.error(f"Exa search failed for {entity}: {e}", exc_info=True)
            # Return empty results on error
            return ExaSearchResponse(results=[], query=query, cached=False)
    
    def _build_query(self, entity: str, entity_type: str) -> str:
        """Build optimized search query from template."""
        template = self.QUERY_TEMPLATES.get(entity_type, '"{entity}" scam OR fraud')
        query = template.format(entity=entity)
        return query
    
    async def _execute_search(self, query: str) -> List[Dict[str, Any]]:
        """
        Execute Exa API search.
        
        Args:
            query: Search query string
        
        Returns:
            Raw API results
        """
        payload = {
            "query": query,
            "num_results": self.max_results,
            "use_autoprompt": True,  # Let Exa optimize query
            "category": "discussion",  # Prioritize discussions/forums
            "start_published_date": (datetime.now() - timedelta(days=90)).isoformat()  # Last 90 days
        }
        
        headers = {
            "x-api-key": self.api_key,
            "Content-Type": "application/json"
        }
        
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            try:
                response = await client.post(
                    self.base_url,
                    json=payload,
                    headers=headers
                )
                response.raise_for_status()
                
                data = response.json()
                return data.get('results', [])
            
            except httpx.TimeoutException:
                logger.warning(f"Exa search timeout for query: {query}")
                raise
            
            except httpx.HTTPStatusError as e:
                if e.response.status_code == 429:
                    logger.error("Exa API rate limit exceeded")
                elif e.response.status_code == 401:
                    logger.error("Exa API authentication failed (invalid key)")
                else:
                    logger.error(f"Exa API error {e.response.status_code}: {e.response.text}")
                raise
    
    def _process_results(self, raw_results: List[Dict[str, Any]]) -> List[ExaSearchResult]:
        """
        Process and score search results.
        
        Args:
            raw_results: Raw results from Exa API
        
        Returns:
            List of processed ExaSearchResult objects
        """
        processed = []
        seen_domains = set()
        
        for item in raw_results:
            # Extract domain
            domain = self._extract_domain(item.get('url', ''))
            
            # Deduplication: Skip if we already have result from this domain
            if domain in seen_domains:
                continue
            seen_domains.add(domain)
            
            # Calculate score
            base_score = item.get('score', 0.5)
            trust_bonus = 0.3 if domain in self.TRUSTED_DOMAINS else 0.0
            final_score = min(base_score + trust_bonus, 1.0)
            
            result = ExaSearchResult(
                title=item.get('title', 'No title'),
                url=item.get('url', ''),
                snippet=self._extract_snippet(item),
                published_date=item.get('published_date'),
                score=final_score,
                domain=domain
            )
            
            processed.append(result)
        
        # Sort by score (highest first)
        processed.sort(key=lambda x: x.score, reverse=True)
        
        return processed
    
    def _extract_domain(self, url: str) -> str:
        """Extract domain from URL."""
        from urllib.parse import urlparse
        parsed = urlparse(url)
        return parsed.netloc.lower()
    
    def _extract_snippet(self, item: Dict[str, Any]) -> str:
        """Extract and truncate snippet."""
        snippet = item.get('snippet', item.get('text', ''))
        
        # Truncate to 200 chars
        if len(snippet) > 200:
            snippet = snippet[:197] + '...'
        
        return snippet
    
    def _get_cache_key(self, entity: str, entity_type: str, query: str) -> str:
        """Generate cache key."""
        key_string = f"{entity_type}:{entity}:{query}"
        key_hash = hashlib.md5(key_string.encode()).hexdigest()
        return f"exa_search:{key_hash}"
    
    def _get_cached(
        self, 
        entity: str, 
        entity_type: str, 
        query: str
    ) -> Optional[ExaSearchResponse]:
        """Retrieve cached search results."""
        if not self.cache_enabled:
            return None
        
        try:
            cache_key = self._get_cache_key(entity, entity_type, query)
            cached_data = self.cache.get(cache_key)
            
            if cached_data:
                data = json.loads(cached_data)
                results = [
                    ExaSearchResult(**r) for r in data['results']
                ]
                return ExaSearchResponse(
                    results=results,
                    query=data['query'],
                    cached=True
                )
        
        except Exception as e:
            logger.warning(f"Cache retrieval error: {e}")
        
        return None
    
    def _cache_result(
        self, 
        entity: str, 
        entity_type: str, 
        query: str, 
        response: ExaSearchResponse
    ):
        """Cache search results."""
        if not self.cache_enabled:
            return
        
        try:
            cache_key = self._get_cache_key(entity, entity_type, query)
            cache_data = {
                "results": [r.to_dict() for r in response.results],
                "query": response.query
            }
            
            # Cache for 24 hours
            self.cache.setex(
                cache_key,
                86400,  # 24 hours in seconds
                json.dumps(cache_data)
            )
        
        except Exception as e:
            logger.warning(f"Cache storage error: {e}")


# Singleton instance
_tool_instance = None

def get_exa_search_tool() -> ExaSearchTool:
    """Get singleton ExaSearchTool instance."""
    global _tool_instance
    if _tool_instance is None:
        _tool_instance = ExaSearchTool()
    return _tool_instance
```

### Cost Tracking Middleware

**`app/agents/tools/exa_cost_tracker.py`:**

```python
"""Cost tracking for Exa API usage."""

import logging
from datetime import datetime, date
from typing import Dict
import redis
import os

logger = logging.getLogger(__name__)


class ExaCostTracker:
    """Track Exa API usage and costs."""
    
    # Exa pricing (as of 2025)
    COST_PER_SEARCH = 0.005  # $0.005 per search
    DAILY_BUDGET_LIMIT = 10.0  # $10 per day default
    
    def __init__(self):
        """Initialize cost tracker."""
        self.redis = redis.from_url(
            os.getenv('REDIS_URL', 'redis://localhost:6379/2'),
            decode_responses=True
        )
    
    def track_search(self, entity_type: str, entity_value: str):
        """
        Track a single search API call.
        
        Args:
            entity_type: Type of entity searched
            entity_value: Entity value (hashed for privacy)
        """
        today = date.today().isoformat()
        key = f"exa_cost:{today}"
        
        # Increment daily count
        self.redis.hincrby(key, "search_count", 1)
        
        # Calculate and store cost
        current_cost = float(self.redis.hget(key, "total_cost") or 0)
        new_cost = current_cost + self.COST_PER_SEARCH
        self.redis.hset(key, "total_cost", new_cost)
        
        # Set expiry (7 days)
        self.redis.expire(key, 604800)
        
        # Check budget limit
        if new_cost > self.DAILY_BUDGET_LIMIT:
            logger.warning(
                f"Daily Exa budget exceeded: ${new_cost:.2f} (limit: ${self.DAILY_BUDGET_LIMIT})"
            )
        
        logger.info(f"Exa search tracked: {entity_type} (daily cost: ${new_cost:.2f})")
    
    def get_daily_stats(self, date_str: Optional[str] = None) -> Dict[str, Any]:
        """Get daily usage statistics."""
        if not date_str:
            date_str = date.today().isoformat()
        
        key = f"exa_cost:{date_str}"
        
        search_count = int(self.redis.hget(key, "search_count") or 0)
        total_cost = float(self.redis.hget(key, "total_cost") or 0)
        
        return {
            "date": date_str,
            "search_count": search_count,
            "total_cost": total_cost,
            "budget_limit": self.DAILY_BUDGET_LIMIT,
            "remaining_budget": max(0, self.DAILY_BUDGET_LIMIT - total_cost)
        }
```

---

## Testing Strategy

**`tests/test_exa_search_tool.py`:**

```python
"""Unit tests for Exa Search Tool."""

import pytest
from unittest.mock import AsyncMock, patch
from app.agents.tools.exa_search import ExaSearchTool, ExaSearchResponse


@pytest.fixture
def exa_tool():
    """Fixture providing ExaSearchTool instance."""
    with patch.dict('os.environ', {'EXA_API_KEY': 'test-key'}):
        return ExaSearchTool(cache_enabled=False)


@pytest.mark.asyncio
class TestExaSearch:
    """Test Exa search functionality."""
    
    async def test_search_phone(self, exa_tool):
        """Test phone number search."""
        # Mock API response
        mock_response = {
            "results": [
                {
                    "title": "Scam alert: 800-555-1234",
                    "url": "https://reddit.com/r/scams/post123",
                    "snippet": "This number called claiming to be IRS...",
                    "score": 0.9,
                    "published_date": "2025-10-01"
                }
            ]
        }
        
        with patch.object(exa_tool, '_execute_search', new=AsyncMock(return_value=mock_response['results'])):
            response = await exa_tool.search_scam_reports("+18005551234", "phone")
        
        assert isinstance(response, ExaSearchResponse)
        assert len(response.results) >= 1
        assert "scam" in response.query.lower()
    
    async def test_query_building(self, exa_tool):
        """Test query template building."""
        query = exa_tool._build_query("+18005551234", "phone")
        
        assert "+18005551234" in query
        assert "scam" in query.lower() or "fraud" in query.lower()
    
    async def test_result_deduplication(self, exa_tool):
        """Test that duplicate domains are filtered."""
        mock_results = [
            {"title": "Post 1", "url": "https://reddit.com/post1", "score": 0.8},
            {"title": "Post 2", "url": "https://reddit.com/post2", "score": 0.7},  # Duplicate domain
        ]
        
        processed = exa_tool._process_results(mock_results)
        
        # Should only have 1 result (deduplicated by domain)
        assert len(processed) == 1
    
    async def test_trusted_domain_boost(self, exa_tool):
        """Test that trusted domains get score boost."""
        mock_results = [
            {"title": "Reddit post", "url": "https://reddit.com/scam", "score": 0.5},
        ]
        
        processed = exa_tool._process_results(mock_results)
        
        # Score should be boosted (0.5 + 0.3 = 0.8)
        assert processed[0].score > 0.5


@pytest.mark.asyncio
class TestCaching:
    """Test result caching."""
    
    async def test_cache_hit(self, exa_tool):
        """Test that cached results are returned."""
        # This test requires Redis running
        # Implementation depends on test setup
        pass


class TestCostTracking:
    """Test cost tracking."""
    
    def test_track_search(self):
        """Test search cost tracking."""
        from app.agents.tools.exa_cost_tracker import ExaCostTracker
        
        tracker = ExaCostTracker()
        tracker.track_search("phone", "+18005551234")
        
        stats = tracker.get_daily_stats()
        assert stats['search_count'] >= 1
        assert stats['total_cost'] >= ExaCostTracker.COST_PER_SEARCH
```

---

## Cost Analysis

**Pricing:**
- Exa API: ~$5 per 1000 searches
- Cost per search: $0.005
- With 10 searches per agent scan: $0.05 per scan
- With caching (60% hit rate): ~$0.02 per scan

**Monthly Projections:**
```
1000 agent scans/month:
- Without caching: $50
- With caching: $20

5000 agent scans/month:
- Without caching: $250
- With caching: $100
```

**Optimization Strategies:**
- Enable caching (24-hour TTL) - reduces costs by ~60%
- Limit to 10 results per search
- Set daily budget caps with alerts

---

## Success Criteria

- [ ] All 27 acceptance criteria met
- [ ] API integration functional with real Exa account
- [ ] Caching reduces API calls by >50%
- [ ] Query latency < 3 seconds (p95)
- [ ] Cost tracking accurate
- [ ] All unit tests passing
- [ ] Integration with MCP agent tested

---

## Dependencies

- **Upstream:** Story 8.2 (Entity Extraction provides entities to search)
- **Downstream:** Story 8.7 (MCP Agent Orchestration uses this tool)
- **External:** Exa API account and API key

---

**Estimated Effort:** 16 hours  
**Sprint:** Week 9, Days 1-2

