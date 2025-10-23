"""Unit tests for LinkedIn Search endpoint (Story 9.2).

Tests cover:
- Request/response model validation
- LinkedIn profile parser
- Rate limiting
- Feature flag
- Error handling
- Analytics logging
"""

import pytest
import json
from unittest.mock import AsyncMock, patch, MagicMock
from fastapi.testclient import TestClient

from app.main import app, parse_linkedin_profile, LinkedInProfile
from app.config import settings


# Test client
client = TestClient(app)


# =============================================================================
# LinkedIn Profile Parser Tests
# =============================================================================

def test_linkedin_profile_parser_valid():
    """Test parser with valid LinkedIn result."""
    exa_result = {
        "title": "John Smith - Senior Software Engineer | LinkedIn",
        "url": "https://linkedin.com/in/johnsmith123",
        "snippet": "Experienced software engineer at Google working on distributed systems...",
        "score": 0.95
    }

    profile = parse_linkedin_profile(exa_result)

    assert profile is not None
    assert profile.name == "John Smith"
    assert profile.title == "Experienced software engineer"
    assert profile.company == "Google"
    assert profile.profile_url == "https://linkedin.com/in/johnsmith123"
    assert "Experienced software engineer" in profile.snippet
    assert len(profile.snippet) <= 200


def test_linkedin_profile_parser_alternative_format():
    """Test parser with alternative title format."""
    exa_result = {
        "title": "Jane Doe | LinkedIn",
        "url": "https://www.linkedin.com/in/janedoe",
        "snippet": "Product Manager @ Microsoft. Leading cloud initiatives.",
        "score": 0.92
    }

    profile = parse_linkedin_profile(exa_result)

    assert profile is not None
    assert profile.name == "Jane Doe"
    assert profile.company == "Microsoft"
    assert profile.profile_url == "https://www.linkedin.com/in/janedoe"


def test_linkedin_profile_parser_invalid_url():
    """Test parser rejects non-profile URLs."""
    # Company page
    exa_result = {
        "title": "Google - Company Profile | LinkedIn",
        "url": "https://linkedin.com/company/google",
        "snippet": "Google is a technology company...",
        "score": 0.88
    }

    profile = parse_linkedin_profile(exa_result)
    assert profile is None

    # Job posting
    exa_result = {
        "title": "Software Engineer - Google | LinkedIn Jobs",
        "url": "https://linkedin.com/jobs/view/12345",
        "snippet": "We are hiring...",
        "score": 0.85
    }

    profile = parse_linkedin_profile(exa_result)
    assert profile is None


def test_linkedin_profile_parser_snippet_truncation():
    """Test parser truncates long snippets to 200 chars."""
    long_snippet = "A" * 500
    exa_result = {
        "title": "Test User | LinkedIn",
        "url": "https://linkedin.com/in/testuser",
        "snippet": long_snippet,
        "score": 0.9
    }

    profile = parse_linkedin_profile(exa_result)

    assert profile is not None
    assert len(profile.snippet) == 200


def test_linkedin_profile_parser_no_company():
    """Test parser handles missing company gracefully."""
    exa_result = {
        "title": "Freelancer Name | LinkedIn",
        "url": "https://linkedin.com/in/freelancer",
        "snippet": "Independent consultant working with clients worldwide.",
        "score": 0.87
    }

    profile = parse_linkedin_profile(exa_result)

    assert profile is not None
    assert profile.company == "Unknown"


def test_linkedin_profile_parser_malformed_data():
    """Test parser handles malformed data gracefully."""
    exa_result = {
        "title": "",
        "url": "https://linkedin.com/in/test",
        "snippet": "",
        "score": 0.5
    }

    profile = parse_linkedin_profile(exa_result)

    # Should still return a profile, even with minimal data
    assert profile is not None
    assert profile.profile_url == "https://linkedin.com/in/test"


# =============================================================================
# Endpoint Tests - Valid Requests
# =============================================================================

@pytest.mark.asyncio
async def test_linkedin_search_valid_request():
    """Test successful LinkedIn search with valid prompt."""
    mock_exa_results = [
        {
            "title": "John Smith - Senior Software Engineer | LinkedIn",
            "url": "https://linkedin.com/in/johnsmith123",
            "snippet": "Experienced software engineer at Google...",
            "score": 0.95
        }
    ]

    with patch('app.main.settings.enable_linkedin_search', True), \
         patch('app.agents.tools.exa_search.get_exa_search_tool') as mock_get_tool, \
         patch('redis.asyncio.from_url') as mock_redis:

        # Mock Exa search tool
        mock_tool = AsyncMock()
        mock_tool.search_linkedin_profiles.return_value = mock_exa_results
        mock_get_tool.return_value = mock_tool

        # Mock Redis (no rate limiting)
        mock_redis_client = AsyncMock()
        mock_redis_client.get.return_value = None
        mock_redis_client.incr.return_value = 1
        mock_redis_client.expire.return_value = True
        mock_redis_client.close.return_value = None
        mock_redis.return_value = mock_redis_client

        # Make request
        response = client.post("/search-linkedin", json={
            "session_id": "123e4567-e89b-12d3-a456-426614174000",
            "prompt": "John Smith",
            "max_results": 5
        })

        # Assert response
        assert response.status_code == 200
        data = response.json()
        assert data["type"] == "linkedin_search"
        assert len(data["results"]) == 1
        assert data["results"][0]["name"] == "John Smith"
        assert data["source"] == "exa"
        assert "search_time_ms" in data


# =============================================================================
# Endpoint Tests - Validation Errors
# =============================================================================

def test_linkedin_search_empty_prompt():
    """Test empty prompt returns 422 validation error."""
    response = client.post("/search-linkedin", json={
        "session_id": "123e4567-e89b-12d3-a456-426614174000",
        "prompt": "",
        "max_results": 5
    })

    assert response.status_code == 422


def test_linkedin_search_prompt_too_short():
    """Test 1-char prompt returns 422 validation error."""
    response = client.post("/search-linkedin", json={
        "session_id": "123e4567-e89b-12d3-a456-426614174000",
        "prompt": "A",
        "max_results": 5
    })

    assert response.status_code == 422


def test_linkedin_search_prompt_too_long():
    """Test prompt >100 chars returns 422 validation error."""
    long_prompt = "A" * 101
    response = client.post("/search-linkedin", json={
        "session_id": "123e4567-e89b-12d3-a456-426614174000",
        "prompt": long_prompt,
        "max_results": 5
    })

    assert response.status_code == 422


def test_linkedin_search_invalid_session_id():
    """Test non-UUID session_id returns 422 validation error."""
    response = client.post("/search-linkedin", json={
        "session_id": "not-a-uuid",
        "prompt": "John Smith",
        "max_results": 5
    })

    assert response.status_code == 422


def test_linkedin_search_whitespace_only_prompt():
    """Test whitespace-only prompt returns 422 validation error."""
    response = client.post("/search-linkedin", json={
        "session_id": "123e4567-e89b-12d3-a456-426614174000",
        "prompt": "   ",
        "max_results": 5
    })

    assert response.status_code == 422


def test_linkedin_search_max_results_too_high():
    """Test max_results >10 returns 422 validation error."""
    response = client.post("/search-linkedin", json={
        "session_id": "123e4567-e89b-12d3-a456-426614174000",
        "prompt": "John Smith",
        "max_results": 11
    })

    assert response.status_code == 422


# =============================================================================
# Endpoint Tests - Feature Flag
# =============================================================================

@pytest.mark.asyncio
async def test_feature_flag_disabled():
    """Test 503 error when feature flag is disabled."""
    with patch('app.main.settings.enable_linkedin_search', False):
        response = client.post("/search-linkedin", json={
            "session_id": "123e4567-e89b-12d3-a456-426614174000",
            "prompt": "John Smith",
            "max_results": 5
        })

        assert response.status_code == 503
        assert "not available" in response.json()["detail"]


# =============================================================================
# Endpoint Tests - Rate Limiting
# =============================================================================

@pytest.mark.asyncio
async def test_rate_limiting():
    """Test 429 error on 11th request in same hour."""
    with patch('app.main.settings.enable_linkedin_search', True), \
         patch('redis.asyncio.from_url') as mock_redis:

        # Mock Redis with count at limit
        mock_redis_client = AsyncMock()
        mock_redis_client.get.return_value = "10"  # Already at limit
        mock_redis_client.close.return_value = None
        mock_redis.return_value = mock_redis_client

        # Make request
        response = client.post("/search-linkedin", json={
            "session_id": "123e4567-e89b-12d3-a456-426614174000",
            "prompt": "John Smith",
            "max_results": 5
        })

        assert response.status_code == 429
        assert "Rate limit exceeded" in response.json()["detail"]


# =============================================================================
# Endpoint Tests - Error Handling
# =============================================================================

@pytest.mark.asyncio
async def test_linkedin_search_no_results():
    """Test empty results array when no profiles found."""
    with patch('app.main.settings.enable_linkedin_search', True), \
         patch('app.agents.tools.exa_search.get_exa_search_tool') as mock_get_tool, \
         patch('redis.asyncio.from_url') as mock_redis:

        # Mock Exa with empty results
        mock_tool = AsyncMock()
        mock_tool.search_linkedin_profiles.return_value = []
        mock_get_tool.return_value = mock_tool

        # Mock Redis
        mock_redis_client = AsyncMock()
        mock_redis_client.get.return_value = None
        mock_redis_client.incr.return_value = 1
        mock_redis_client.expire.return_value = True
        mock_redis_client.close.return_value = None
        mock_redis.return_value = mock_redis_client

        # Make request
        response = client.post("/search-linkedin", json={
            "session_id": "123e4567-e89b-12d3-a456-426614174000",
            "prompt": "NonexistentPerson12345",
            "max_results": 5
        })

        # Should still return 200 with empty array
        assert response.status_code == 200
        data = response.json()
        assert data["results"] == []
        assert data["type"] == "linkedin_search"


@pytest.mark.asyncio
async def test_linkedin_search_exa_api_failure():
    """Test 500 error when Exa API fails."""
    with patch('app.main.settings.enable_linkedin_search', True), \
         patch('app.agents.tools.exa_search.get_exa_search_tool') as mock_get_tool, \
         patch('redis.asyncio.from_url') as mock_redis:

        # Mock Exa to raise exception
        mock_tool = AsyncMock()
        mock_tool.search_linkedin_profiles.side_effect = Exception("API timeout")
        mock_get_tool.return_value = mock_tool

        # Mock Redis
        mock_redis_client = AsyncMock()
        mock_redis_client.get.return_value = None
        mock_redis_client.incr.return_value = 1
        mock_redis_client.expire.return_value = True
        mock_redis_client.close.return_value = None
        mock_redis.return_value = mock_redis_client

        # Make request
        response = client.post("/search-linkedin", json={
            "session_id": "123e4567-e89b-12d3-a456-426614174000",
            "prompt": "John Smith",
            "max_results": 5
        })

        assert response.status_code == 500
        assert "temporarily unavailable" in response.json()["detail"]


# =============================================================================
# Endpoint Tests - Non-Profile Results Filtering
# =============================================================================

@pytest.mark.asyncio
async def test_linkedin_search_filters_non_profiles():
    """Test that non-profile URLs are filtered out."""
    mock_exa_results = [
        {
            "title": "John Smith | LinkedIn",
            "url": "https://linkedin.com/in/johnsmith",
            "snippet": "Engineer at Google",
            "score": 0.95
        },
        {
            "title": "Google - Company | LinkedIn",
            "url": "https://linkedin.com/company/google",
            "snippet": "Technology company",
            "score": 0.90
        },
        {
            "title": "Software Engineer Job | LinkedIn",
            "url": "https://linkedin.com/jobs/view/12345",
            "snippet": "We are hiring",
            "score": 0.85
        }
    ]

    with patch('app.main.settings.enable_linkedin_search', True), \
         patch('app.agents.tools.exa_search.get_exa_search_tool') as mock_get_tool, \
         patch('redis.asyncio.from_url') as mock_redis:

        # Mock Exa
        mock_tool = AsyncMock()
        mock_tool.search_linkedin_profiles.return_value = mock_exa_results
        mock_get_tool.return_value = mock_tool

        # Mock Redis
        mock_redis_client = AsyncMock()
        mock_redis_client.get.return_value = None
        mock_redis_client.incr.return_value = 1
        mock_redis_client.expire.return_value = True
        mock_redis_client.close.return_value = None
        mock_redis.return_value = mock_redis_client

        # Make request
        response = client.post("/search-linkedin", json={
            "session_id": "123e4567-e89b-12d3-a456-426614174000",
            "prompt": "John Smith",
            "max_results": 5
        })

        # Should only include 1 profile (first one)
        assert response.status_code == 200
        data = response.json()
        assert len(data["results"]) == 1
        assert "johnsmith" in data["results"][0]["profile_url"]
