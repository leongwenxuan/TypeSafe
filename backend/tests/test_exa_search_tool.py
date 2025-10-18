"""Unit tests for Exa Search Tool.

Tests the Exa Web Search Tool functionality including:
- API integration with mocked responses
- Query building
- Result processing and scoring
- Caching mechanism
- Error handling
- Cost tracking

Story: 8.4 - Exa Web Search Tool Integration
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from datetime import datetime, timedelta
import json

from app.agents.tools.exa_search import (
    ExaSearchTool,
    ExaSearchResponse,
    ExaSearchResult
)
from app.agents.tools.exa_cost_tracker import ExaCostTracker


# =============================================================================
# Fixtures
# =============================================================================

@pytest.fixture
def mock_redis():
    """Mock Redis client."""
    with patch('redis.from_url') as mock:
        redis_mock = MagicMock()
        mock.return_value = redis_mock
        yield redis_mock


@pytest.fixture
def exa_tool_no_cache():
    """Fixture providing ExaSearchTool instance without caching."""
    with patch.dict('os.environ', {'EXA_API_KEY': 'test-api-key'}):
        with patch('app.config.settings') as mock_settings:
            mock_settings.exa_api_key = 'test-api-key'
            mock_settings.exa_max_results = 10
            mock_settings.exa_cache_ttl = 86400
            tool = ExaSearchTool(cache_enabled=False)
            yield tool


@pytest.fixture
def exa_tool_with_cache(mock_redis):
    """Fixture providing ExaSearchTool instance with caching enabled."""
    with patch.dict('os.environ', {'EXA_API_KEY': 'test-api-key'}):
        with patch('app.config.settings') as mock_settings:
            mock_settings.exa_api_key = 'test-api-key'
            mock_settings.exa_max_results = 10
            mock_settings.exa_cache_ttl = 86400
            mock_settings.redis_url = 'redis://localhost:6379'
            tool = ExaSearchTool(cache_enabled=True)
            tool.cache = mock_redis
            yield tool


@pytest.fixture
def mock_exa_response():
    """Mock successful Exa API response."""
    return [
        {
            "title": "Scam Alert: +1-800-555-1234 is a known scam",
            "url": "https://reddit.com/r/scams/post123",
            "snippet": "This number called me claiming to be from the IRS. It's definitely a scam...",
            "score": 0.9,
            "published_date": "2025-10-01T10:00:00Z"
        },
        {
            "title": "Beware of 800-555-1234",
            "url": "https://bbb.org/scam-tracker/report/12345",
            "snippet": "Multiple complaints filed about this phone number...",
            "score": 0.85,
            "published_date": "2025-09-28T15:30:00Z"
        },
        {
            "title": "Another Reddit post about the same number",
            "url": "https://reddit.com/r/scams/post456",
            "snippet": "Same scam number called again...",
            "score": 0.7,
            "published_date": "2025-09-25T08:00:00Z"
        }
    ]


# =============================================================================
# Test ExaSearchTool
# =============================================================================

class TestExaSearchTool:
    """Test ExaSearchTool functionality."""
    
    def test_init_without_api_key(self):
        """Test that tool raises error if API key not configured."""
        with patch('app.agents.tools.exa_search.settings') as mock_settings:
            mock_settings.exa_api_key = ""
            
            with pytest.raises(ValueError, match="EXA_API_KEY not configured"):
                ExaSearchTool(api_key=None, cache_enabled=False)
    
    def test_init_with_custom_params(self):
        """Test initialization with custom parameters."""
        with patch('app.config.settings') as mock_settings:
            mock_settings.exa_api_key = 'test-key'
            mock_settings.exa_max_results = 10
            mock_settings.exa_cache_ttl = 86400
            
            tool = ExaSearchTool(
                api_key='custom-key',
                cache_enabled=False,
                max_results=5,
                timeout=3.0
            )
            
            assert tool.api_key == 'custom-key'
            assert tool.max_results == 5
            assert tool.timeout == 3.0
            assert tool.cache_enabled is False
    
    @pytest.mark.asyncio
    async def test_search_phone_success(self, exa_tool_no_cache, mock_exa_response):
        """Test successful phone number search."""
        # Mock the _execute_search method
        with patch.object(
            exa_tool_no_cache,
            '_execute_search',
            new=AsyncMock(return_value=mock_exa_response)
        ):
            response = await exa_tool_no_cache.search_scam_reports(
                "+18005551234",
                "phone"
            )
        
        assert isinstance(response, ExaSearchResponse)
        assert len(response.results) >= 1
        assert response.cached is False
        assert "scam" in response.query.lower() or "fraud" in response.query.lower()
    
    @pytest.mark.asyncio
    async def test_search_url(self, exa_tool_no_cache, mock_exa_response):
        """Test URL search."""
        with patch.object(
            exa_tool_no_cache,
            '_execute_search',
            new=AsyncMock(return_value=mock_exa_response)
        ):
            response = await exa_tool_no_cache.search_scam_reports(
                "scam-site.com",
                "url"
            )
        
        assert isinstance(response, ExaSearchResponse)
        assert "phishing" in response.query.lower() or "scam" in response.query.lower()
    
    @pytest.mark.asyncio
    async def test_search_email(self, exa_tool_no_cache, mock_exa_response):
        """Test email search."""
        with patch.object(
            exa_tool_no_cache,
            '_execute_search',
            new=AsyncMock(return_value=mock_exa_response)
        ):
            response = await exa_tool_no_cache.search_scam_reports(
                "scammer@example.com",
                "email"
            )
        
        assert isinstance(response, ExaSearchResponse)
        assert "spam" in response.query.lower() or "scam" in response.query.lower()
    
    def test_query_building(self, exa_tool_no_cache):
        """Test query template building for different entity types."""
        # Phone query
        phone_query = exa_tool_no_cache._build_query("+18005551234", "phone")
        assert "+18005551234" in phone_query
        assert "scam" in phone_query.lower() or "fraud" in phone_query.lower()
        
        # URL query
        url_query = exa_tool_no_cache._build_query("scam-site.com", "url")
        assert "scam-site.com" in url_query
        assert "phishing" in url_query.lower() or "scam" in url_query.lower()
        
        # Email query
        email_query = exa_tool_no_cache._build_query("test@example.com", "email")
        assert "test@example.com" in email_query
        assert "spam" in email_query.lower() or "scam" in email_query.lower()
        
        # Unknown type (fallback)
        unknown_query = exa_tool_no_cache._build_query("test", "unknown")
        assert "test" in unknown_query
        assert "scam" in unknown_query.lower() or "fraud" in unknown_query.lower()
    
    def test_result_deduplication(self, exa_tool_no_cache):
        """Test that duplicate domains are filtered out."""
        mock_results = [
            {
                "title": "Post 1",
                "url": "https://reddit.com/r/scams/post1",
                "score": 0.9,
                "snippet": "First post"
            },
            {
                "title": "Post 2",
                "url": "https://reddit.com/r/scams/post2",
                "score": 0.8,
                "snippet": "Second post"
            },  # Duplicate domain
            {
                "title": "BBB Report",
                "url": "https://bbb.org/report/123",
                "score": 0.85,
                "snippet": "BBB complaint"
            }
        ]
        
        processed = exa_tool_no_cache._process_results(mock_results)
        
        # Should only have 2 results (reddit deduplicated)
        assert len(processed) == 2
        domains = [r.domain for r in processed]
        assert domains.count("reddit.com") == 1
    
    def test_trusted_domain_boost(self, exa_tool_no_cache):
        """Test that trusted domains get score boost."""
        mock_results = [
            {
                "title": "Reddit post",
                "url": "https://reddit.com/r/scams/post",
                "score": 0.5,
                "snippet": "Reddit discussion"
            },
            {
                "title": "BBB Report",
                "url": "https://bbb.org/report",
                "score": 0.5,
                "snippet": "BBB complaint"
            },
            {
                "title": "Unknown site",
                "url": "https://unknown-site.com/post",
                "score": 0.5,
                "snippet": "Random site"
            }
        ]
        
        processed = exa_tool_no_cache._process_results(mock_results)
        
        # Reddit and BBB should have boosted scores
        reddit_result = next(r for r in processed if r.domain == "reddit.com")
        bbb_result = next(r for r in processed if r.domain == "bbb.org")
        unknown_result = next(r for r in processed if r.domain == "unknown-site.com")
        
        assert reddit_result.score > 0.5  # Boosted
        assert bbb_result.score > 0.5  # Boosted
        assert unknown_result.score == 0.5  # Not boosted
    
    def test_snippet_truncation(self, exa_tool_no_cache):
        """Test that long snippets are truncated."""
        long_text = "A" * 300
        item = {"snippet": long_text}
        
        snippet = exa_tool_no_cache._extract_snippet(item)
        
        assert len(snippet) <= 200
        assert snippet.endswith("...")
    
    def test_domain_extraction(self, exa_tool_no_cache):
        """Test domain extraction from various URL formats."""
        test_cases = [
            ("https://www.example.com/path", "example.com"),
            ("http://example.com", "example.com"),
            ("https://subdomain.example.com", "subdomain.example.com"),
            ("https://www.example.com", "example.com"),
            ("https://example.com/path", "example.com")
        ]
        
        for url, expected_domain in test_cases:
            domain = exa_tool_no_cache._extract_domain(url)
            assert domain == expected_domain, f"Failed for URL: {url}, got '{domain}', expected '{expected_domain}'"
    
    @pytest.mark.asyncio
    async def test_error_handling_timeout(self, exa_tool_no_cache):
        """Test graceful handling of API timeout."""
        import httpx
        
        # Mock timeout error
        with patch.object(
            exa_tool_no_cache,
            '_execute_search',
            new=AsyncMock(side_effect=httpx.TimeoutException("Timeout"))
        ):
            response = await exa_tool_no_cache.search_scam_reports(
                "+18005551234",
                "phone"
            )
        
        # Should return empty results, not crash
        assert isinstance(response, ExaSearchResponse)
        assert len(response.results) == 0
        assert response.cached is False
    
    @pytest.mark.asyncio
    async def test_error_handling_api_error(self, exa_tool_no_cache):
        """Test graceful handling of API errors."""
        # Mock general exception
        with patch.object(
            exa_tool_no_cache,
            '_execute_search',
            new=AsyncMock(side_effect=Exception("API Error"))
        ):
            response = await exa_tool_no_cache.search_scam_reports(
                "+18005551234",
                "phone"
            )
        
        # Should return empty results, not crash
        assert isinstance(response, ExaSearchResponse)
        assert len(response.results) == 0


# =============================================================================
# Test Caching
# =============================================================================

class TestCaching:
    """Test result caching functionality."""
    
    @pytest.mark.asyncio
    async def test_cache_miss_then_hit(self, exa_tool_with_cache, mock_exa_response):
        """Test cache miss followed by cache hit."""
        entity = "+18005551234"
        entity_type = "phone"
        
        # Mock Redis to return None first (cache miss)
        exa_tool_with_cache.cache.get.return_value = None
        
        # First call - cache miss, should call API
        with patch.object(
            exa_tool_with_cache,
            '_execute_search',
            new=AsyncMock(return_value=mock_exa_response)
        ) as mock_execute:
            response1 = await exa_tool_with_cache.search_scam_reports(
                entity,
                entity_type
            )
        
        assert response1.cached is False
        assert mock_execute.called
        
        # Verify cache was set
        assert exa_tool_with_cache.cache.setex.called
        
        # Mock cache hit for second call
        cached_data = {
            "results": [r.to_dict() for r in response1.results],
            "query": response1.query
        }
        exa_tool_with_cache.cache.get.return_value = json.dumps(cached_data)
        
        # Second call - cache hit, should NOT call API
        with patch.object(
            exa_tool_with_cache,
            '_execute_search',
            new=AsyncMock(return_value=mock_exa_response)
        ) as mock_execute:
            response2 = await exa_tool_with_cache.search_scam_reports(
                entity,
                entity_type
            )
        
        assert response2.cached is True
        assert not mock_execute.called
    
    def test_cache_key_generation(self, exa_tool_with_cache):
        """Test cache key generation is consistent."""
        key1 = exa_tool_with_cache._get_cache_key(
            "+18005551234",
            "phone",
            "test query"
        )
        key2 = exa_tool_with_cache._get_cache_key(
            "+18005551234",
            "phone",
            "test query"
        )
        key3 = exa_tool_with_cache._get_cache_key(
            "+18005559999",
            "phone",
            "test query"
        )
        
        # Same input = same key
        assert key1 == key2
        # Different input = different key
        assert key1 != key3
        # Key format
        assert key1.startswith("exa_search:")


# =============================================================================
# Test Cost Tracking
# =============================================================================

class TestCostTracking:
    """Test cost tracking functionality."""
    
    @pytest.fixture
    def cost_tracker(self, mock_redis):
        """Fixture providing ExaCostTracker instance."""
        with patch('app.config.settings') as mock_settings:
            mock_settings.exa_daily_budget = 10.0
            mock_settings.redis_url = 'redis://localhost:6379'
            
            tracker = ExaCostTracker()
            tracker.redis = mock_redis
            yield tracker
    
    def test_track_search(self, cost_tracker):
        """Test tracking a search increments counters."""
        # Mock Redis responses
        cost_tracker.redis.hincrby.return_value = 1
        cost_tracker.redis.hget.return_value = "0"
        
        result = cost_tracker.track_search("phone", "+18005551234")
        
        assert result["search_count"] == 1
        assert result["total_cost"] > 0
        assert cost_tracker.redis.hincrby.called
        assert cost_tracker.redis.hset.called
    
    def test_get_daily_stats(self, cost_tracker):
        """Test getting daily statistics."""
        # Mock Redis response
        cost_tracker.redis.hgetall.return_value = {
            "search_count": "5",
            "total_cost": "0.025",
            "entity_type:phone": "3",
            "entity_type:url": "2"
        }
        
        stats = cost_tracker.get_daily_stats()
        
        assert stats["search_count"] == 5
        assert stats["total_cost"] == 0.025
        assert stats["entity_type_counts"]["phone"] == 3
        assert stats["entity_type_counts"]["url"] == 2
    
    def test_budget_exceeded_warning(self, cost_tracker):
        """Test that budget exceeded triggers warning."""
        # Mock current cost exceeding budget
        cost_tracker.redis.hincrby.return_value = 100
        cost_tracker.redis.hget.return_value = "12.0"  # Over $10 limit
        
        with patch('app.agents.tools.exa_cost_tracker.logger') as mock_logger:
            result = cost_tracker.track_search("phone", "+18005551234")
            
            assert result["budget_exceeded"] is True
            # Should log warning
            assert any(
                call[0][0].startswith("⚠️ Daily Exa budget")
                for call in mock_logger.warning.call_args_list
            )
    
    def test_is_budget_exceeded(self, cost_tracker):
        """Test budget exceeded check."""
        # Mock under budget
        cost_tracker.redis.hgetall.return_value = {
            "search_count": "5",
            "total_cost": "5.0"
        }
        assert cost_tracker.is_budget_exceeded() is False
        
        # Mock over budget
        cost_tracker.redis.hgetall.return_value = {
            "search_count": "300",
            "total_cost": "15.0"
        }
        assert cost_tracker.is_budget_exceeded() is True
    
    def test_weekly_stats(self, cost_tracker):
        """Test weekly statistics aggregation."""
        # Mock daily stats
        cost_tracker.redis.hgetall.return_value = {
            "search_count": "10",
            "total_cost": "0.05"
        }
        
        stats = cost_tracker.get_weekly_stats()
        
        assert "total_searches" in stats
        assert "total_cost" in stats
        assert "avg_daily_cost" in stats
        assert len(stats["daily_breakdown"]) == 7


# =============================================================================
# Integration Tests
# =============================================================================

@pytest.mark.asyncio
class TestIntegration:
    """Integration tests with real-like scenarios."""
    
    async def test_full_search_workflow(self, exa_tool_no_cache, mock_exa_response):
        """Test complete search workflow from query to results."""
        # Mock API call
        with patch.object(
            exa_tool_no_cache,
            '_execute_search',
            new=AsyncMock(return_value=mock_exa_response)
        ):
            response = await exa_tool_no_cache.search_scam_reports(
                "+18005551234",
                "phone"
            )
        
        # Verify response structure
        assert isinstance(response, ExaSearchResponse)
        assert len(response.results) > 0
        assert response.query != ""
        
        # Verify result structure
        for result in response.results:
            assert isinstance(result, ExaSearchResult)
            assert result.title
            assert result.url
            assert result.domain
            assert 0 <= result.score <= 1
    
    async def test_empty_results_handling(self, exa_tool_no_cache):
        """Test handling of empty search results."""
        # Mock empty API response
        with patch.object(
            exa_tool_no_cache,
            '_execute_search',
            new=AsyncMock(return_value=[])
        ):
            response = await exa_tool_no_cache.search_scam_reports(
                "+18005559999",
                "phone"
            )
        
        assert isinstance(response, ExaSearchResponse)
        assert len(response.results) == 0
        assert response.query != ""


# =============================================================================
# Utility Tests
# =============================================================================

class TestUtilities:
    """Test utility functions and edge cases."""
    
    def test_dataclass_to_dict(self):
        """Test dataclass conversion to dictionary."""
        result = ExaSearchResult(
            title="Test",
            url="https://example.com",
            snippet="Test snippet",
            published_date="2025-10-01",
            score=0.9,
            domain="example.com"
        )
        
        result_dict = result.to_dict()
        assert isinstance(result_dict, dict)
        assert result_dict["title"] == "Test"
        assert result_dict["score"] == 0.9
    
    def test_response_to_dict(self):
        """Test response conversion to dictionary."""
        result = ExaSearchResult(
            title="Test",
            url="https://example.com",
            snippet="Test snippet",
            published_date="2025-10-01",
            score=0.9,
            domain="example.com"
        )
        
        response = ExaSearchResponse(
            results=[result],
            query="test query",
            cached=False
        )
        
        response_dict = response.to_dict()
        assert isinstance(response_dict, dict)
        assert response_dict["result_count"] == 1
        assert response_dict["cached"] is False
        assert len(response_dict["results"]) == 1

