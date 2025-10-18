"""Exa Web Search Tool for MCP Agent.

This tool provides the agent's ability to discover new scams and find external evidence
from the web using Exa's neural search API. Unlike the Scam Database Tool which handles
known scams, Exa Search discovers:

- Recent scam complaints on Reddit, forums, complaint sites
- News articles about new scam campaigns
- BBB reports and consumer protection warnings
- Social media discussions about suspicious entities

Why Exa over Google Search?
- Better for scam detection: Exa specializes in finding discussions and complaints
- Neural search: Understands semantic meaning, not just keywords
- Forum/discussion focus: Prioritizes Reddit, complaint sites, BBB
- Clean API: Easy integration, predictable costs

Story: 8.4 - Exa Web Search Tool Integration
"""

import os
import httpx
import hashlib
import logging
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, field, asdict
from datetime import datetime, timedelta
import json

from app.config import settings

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
        """Convert to dictionary for JSON serialization."""
        return asdict(self)


@dataclass
class ExaSearchResponse:
    """Response from Exa search."""
    results: List[ExaSearchResult] = field(default_factory=list)
    query: str = ""
    cached: bool = False
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
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
    
    Features:
    - Query templates optimized for scam detection
    - Result scoring and filtering by source credibility
    - Redis caching with 24-hour TTL
    - Rate limiting and cost tracking
    - Graceful error handling
    
    Example:
        >>> tool = ExaSearchTool()
        >>> response = await tool.search_scam_reports("+18005551234", "phone")
        >>> if response.results:
        ...     print(f"Found {len(response.results)} web reports")
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
        'reportfraud.ftc.gov', 'consumeraffairs.com', 'complaintsboard.com',
        'trustpilot.com', 'ripoffreport.com', 'ic3.gov'
    }
    
    def __init__(
        self, 
        api_key: Optional[str] = None,
        cache_enabled: bool = True,
        max_results: int = 10,
        timeout: float = 5.0
    ):
        """
        Initialize Exa search tool.
        
        Args:
            api_key: Exa API key (defaults to settings.exa_api_key)
            cache_enabled: Enable result caching (24 hour TTL)
            max_results: Maximum results per search (default: 10)
            timeout: Request timeout in seconds (default: 5.0)
        
        Raises:
            ValueError: If EXA_API_KEY not configured
        """
        self.api_key = api_key or settings.exa_api_key
        if not self.api_key:
            raise ValueError(
                "EXA_API_KEY not configured. Please set it in your .env file or "
                "pass it to the ExaSearchTool constructor."
            )
        
        self.base_url = "https://api.exa.ai/search"
        self.cache_enabled = cache_enabled
        self.max_results = max_results or settings.exa_max_results
        self.timeout = timeout
        
        # Initialize cache (Redis)
        self.cache = None
        if cache_enabled:
            try:
                import redis
                self.cache = redis.from_url(
                    settings.redis_url,
                    decode_responses=True
                )
                logger.info("Exa search cache enabled (Redis)")
            except Exception as e:
                logger.warning(f"Failed to initialize Exa cache: {e}. Caching disabled.")
                self.cache_enabled = False
        
        logger.info(
            f"ExaSearchTool initialized (max_results={self.max_results}, "
            f"timeout={self.timeout}s, cache_enabled={self.cache_enabled})"
        )
    
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
            
        Example:
            >>> response = await tool.search_scam_reports("+18005551234", "phone")
            >>> for result in response.results:
            ...     print(f"{result.title}: {result.url}")
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
            
            logger.info(
                f"Exa search completed: {len(processed_results)} results for "
                f"{entity_type}/{entity}"
            )
            return response
        
        except Exception as e:
            logger.error(f"Exa search failed for {entity}: {e}", exc_info=True)
            # Return empty results on error (graceful degradation)
            return ExaSearchResponse(results=[], query=query, cached=False)
    
    def _build_query(self, entity: str, entity_type: str) -> str:
        """
        Build optimized search query from template.
        
        Args:
            entity: Entity value
            entity_type: Type of entity
        
        Returns:
            Query string
        """
        template = self.QUERY_TEMPLATES.get(
            entity_type, 
            '"{entity}" scam OR fraud'
        )
        query = template.format(entity=entity)
        return query
    
    async def _execute_search(self, query: str) -> List[Dict[str, Any]]:
        """
        Execute Exa API search.
        
        Args:
            query: Search query string
        
        Returns:
            Raw API results
        
        Raises:
            httpx.TimeoutException: If request times out
            httpx.HTTPStatusError: If API returns error status
        """
        payload = {
            "query": query,
            "num_results": self.max_results,
            "use_autoprompt": True,  # Let Exa optimize query
            "category": "discussion",  # Prioritize discussions/forums
            "start_published_date": (
                datetime.now() - timedelta(days=90)
            ).isoformat()  # Last 90 days
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
                    logger.error(
                        f"Exa API error {e.response.status_code}: {e.response.text}"
                    )
                raise
    
    def _process_results(self, raw_results: List[Dict[str, Any]]) -> List[ExaSearchResult]:
        """
        Process and score search results.
        
        Features:
        - Deduplication by domain
        - Source credibility scoring
        - Snippet extraction and truncation
        - Sorting by score
        
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
        """
        Extract domain from URL.
        
        Args:
            url: Full URL
        
        Returns:
            Lowercase domain (e.g., "example.com")
        """
        from urllib.parse import urlparse
        try:
            parsed = urlparse(url)
            domain = parsed.netloc.lower()
            
            # Remove www. prefix if present
            if domain.startswith('www.'):
                domain = domain[4:]
            
            return domain
        except Exception:
            return url.lower()
    
    def _extract_snippet(self, item: Dict[str, Any]) -> str:
        """
        Extract and truncate snippet.
        
        Args:
            item: Raw result item
        
        Returns:
            Truncated snippet (max 200 chars)
        """
        snippet = item.get('snippet', item.get('text', ''))
        
        # Truncate to 200 chars
        if len(snippet) > 200:
            snippet = snippet[:197] + '...'
        
        return snippet
    
    def _get_cache_key(self, entity: str, entity_type: str, query: str) -> str:
        """
        Generate cache key.
        
        Args:
            entity: Entity value
            entity_type: Type of entity
            query: Query string
        
        Returns:
            Cache key string
        """
        key_string = f"{entity_type}:{entity}:{query}"
        key_hash = hashlib.md5(key_string.encode()).hexdigest()
        return f"exa_search:{key_hash}"
    
    def _get_cached(
        self, 
        entity: str, 
        entity_type: str, 
        query: str
    ) -> Optional[ExaSearchResponse]:
        """
        Retrieve cached search results.
        
        Args:
            entity: Entity value
            entity_type: Type of entity
            query: Query string
        
        Returns:
            Cached ExaSearchResponse or None
        """
        if not self.cache_enabled or not self.cache:
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
        """
        Cache search results.
        
        Args:
            entity: Entity value
            entity_type: Type of entity
            query: Query string
            response: ExaSearchResponse to cache
        """
        if not self.cache_enabled or not self.cache:
            return
        
        try:
            cache_key = self._get_cache_key(entity, entity_type, query)
            cache_data = {
                "results": [r.to_dict() for r in response.results],
                "query": response.query
            }
            
            # Cache for configured TTL (default 24 hours)
            self.cache.setex(
                cache_key,
                settings.exa_cache_ttl,
                json.dumps(cache_data)
            )
        
        except Exception as e:
            logger.warning(f"Cache storage error: {e}")


# =============================================================================
# Singleton Instance
# =============================================================================

_tool_instance: Optional[ExaSearchTool] = None


def get_exa_search_tool() -> ExaSearchTool:
    """
    Get singleton ExaSearchTool instance.
    
    Returns:
        Singleton instance of ExaSearchTool
        
    Example:
        >>> tool = get_exa_search_tool()
        >>> response = await tool.search_scam_reports("+18005551234", "phone")
    """
    global _tool_instance
    if _tool_instance is None:
        _tool_instance = ExaSearchTool()
    return _tool_instance

