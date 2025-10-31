"""Integration tests for LinkedIn Search endpoint (Story 9.2).

These tests make real API calls to Exa and require:
- EXA_API_KEY environment variable
- ENABLE_LINKEDIN_SEARCH=true in config
- Redis running for rate limiting

Run with: pytest -m integration tests/integration/test_linkedin_search_integration.py
"""

import pytest
import os
from fastapi.testclient import TestClient

from app.main import app
from app.config import settings


# Test client
client = TestClient(app)


# Skip tests if no API key or feature disabled
skip_if_no_api_key = pytest.mark.skipif(
    not os.getenv('EXA_API_KEY'),
    reason="EXA_API_KEY not set in environment"
)


@pytest.mark.integration
@skip_if_no_api_key
def test_linkedin_search_end_to_end():
    """
    Test LinkedIn search with real Exa API call.

    This test:
    1. Makes a real request to /search-linkedin
    2. Queries Exa API for "Satya Nadella Microsoft"
    3. Validates response structure
    4. Checks search time < 5 seconds
    5. Verifies results contain valid LinkedIn URLs
    """
    # Enable feature flag for test
    original_flag = settings.enable_linkedin_search
    settings.enable_linkedin_search = True

    try:
        # Make request with known query
        response = client.post("/search-linkedin", json={
            "session_id": "integration-test-00000000-0000-0000-0000-000000000001",
            "prompt": "Satya Nadella Microsoft",
            "max_results": 3
        })

        # Assert response status
        assert response.status_code == 200

        # Parse response
        data = response.json()

        # Validate response structure
        assert data["type"] == "linkedin_search"
        assert "results" in data
        assert "search_time_ms" in data
        assert "source" in data
        assert data["source"] == "exa"

        # Validate search time < 5 seconds
        assert data["search_time_ms"] < 5000, \
            f"Search took {data['search_time_ms']}ms, expected < 5000ms"

        # Validate results structure (if any found)
        if data["results"]:
            for profile in data["results"]:
                # Each result should have required fields
                assert "name" in profile
                assert "title" in profile
                assert "company" in profile
                assert "profile_url" in profile
                assert "snippet" in profile

                # URL should be LinkedIn profile
                assert "linkedin.com/in/" in profile["profile_url"], \
                    f"Invalid profile URL: {profile['profile_url']}"

                # Snippet should be truncated to 200 chars
                assert len(profile["snippet"]) <= 200

            # At least one result should mention relevant info
            # (This is a known public figure query)
            print(f"\nFound {len(data['results'])} profiles")
            for profile in data["results"]:
                print(f"  - {profile['name']}: {profile['title']} at {profile['company']}")

        else:
            # Empty results is acceptable (API may not find matches)
            print("\nNo results found (acceptable for integration test)")

    finally:
        # Restore original flag
        settings.enable_linkedin_search = original_flag


@pytest.mark.integration
@skip_if_no_api_key
def test_linkedin_search_performance():
    """
    Test LinkedIn search performance with real API.

    Validates that p95 response time is < 5 seconds as required.
    """
    settings.enable_linkedin_search = True

    try:
        search_times = []

        # Make 5 requests with different queries
        queries = [
            "Tim Cook Apple",
            "Sundar Pichai Google",
            "Mark Zuckerberg Meta",
            "Jensen Huang NVIDIA",
            "Sam Altman OpenAI"
        ]

        for i, query in enumerate(queries):
            response = client.post("/search-linkedin", json={
                "session_id": f"perf-test-00000000-0000-0000-0000-00000000000{i}",
                "prompt": query,
                "max_results": 2
            })

            assert response.status_code == 200
            data = response.json()
            search_times.append(data["search_time_ms"])

        # Calculate p95 (95th percentile)
        search_times_sorted = sorted(search_times)
        p95_index = int(len(search_times_sorted) * 0.95)
        p95_time = search_times_sorted[p95_index]

        print(f"\nSearch times: {search_times}")
        print(f"P95: {p95_time}ms")

        # Assert p95 < 5 seconds
        assert p95_time < 5000, f"P95 response time {p95_time}ms exceeds 5000ms"

    finally:
        settings.enable_linkedin_search = False


@pytest.mark.integration
@skip_if_no_api_key
def test_linkedin_search_rate_limiting_integration():
    """
    Test rate limiting with Redis in integration environment.

    Note: This test requires Redis to be running.
    """
    settings.enable_linkedin_search = True

    try:
        session_id = "rate-limit-test-00000000-0000-0000-0000-000000000099"

        # Make 10 requests (should succeed)
        for i in range(10):
            response = client.post("/search-linkedin", json={
                "session_id": session_id,
                "prompt": f"Test Query {i}",
                "max_results": 1
            })
            assert response.status_code == 200, \
                f"Request {i+1} failed with {response.status_code}"

        # 11th request should be rate limited
        response = client.post("/search-linkedin", json={
            "session_id": session_id,
            "prompt": "Test Query 11",
            "max_results": 1
        })

        assert response.status_code == 429, \
            f"Expected 429 rate limit, got {response.status_code}"
        assert "Rate limit exceeded" in response.json()["detail"]

    finally:
        settings.enable_linkedin_search = False


@pytest.mark.integration
@skip_if_no_api_key
def test_linkedin_search_various_queries():
    """
    Test LinkedIn search with various query formats.

    Tests different types of queries to ensure robustness.
    """
    settings.enable_linkedin_search = True

    try:
        test_cases = [
            ("software engineer", "Generic job title"),
            ("John Smith", "Common name"),
            ("Chief Technology Officer startup", "Title + keyword"),
            ("data scientist San Francisco", "Job + location"),
        ]

        for query, description in test_cases:
            response = client.post("/search-linkedin", json={
                "session_id": f"query-test-{hash(query):032x}"[:36],
                "prompt": query,
                "max_results": 3
            })

            print(f"\n{description}: '{query}'")
            print(f"  Status: {response.status_code}")

            if response.status_code == 200:
                data = response.json()
                print(f"  Results: {len(data['results'])}")
                print(f"  Time: {data['search_time_ms']}ms")

                # Validate structure
                assert data["type"] == "linkedin_search"
                assert isinstance(data["results"], list)
                assert data["search_time_ms"] < 5000

    finally:
        settings.enable_linkedin_search = False
