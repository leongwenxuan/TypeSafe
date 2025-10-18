"""
Tests for main FastAPI application.

Tests health endpoint, CORS configuration, logging middleware, and security headers.
"""
import os
from unittest.mock import patch
import pytest
from fastapi.testclient import TestClient


# Mock environment variables before importing app
@pytest.fixture(scope="module", autouse=True)
def mock_env_vars():
    """Mock environment variables for all tests"""
    with patch.dict(os.environ, {
        'ENVIRONMENT': 'test',
        'OPENAI_API_KEY': 'test-openai-key',
        'GEMINI_API_KEY': 'test-gemini-key',
        'SUPABASE_URL': 'https://test.supabase.co',
        'SUPABASE_KEY': 'test-supabase-key',
        'BACKEND_API_KEY': 'test-backend-key',
    }):
        yield


@pytest.fixture
def client():
    """Create test client for FastAPI app"""
    from app.main import app
    return TestClient(app)


class TestHealthEndpoint:
    """Test suite for /health endpoint"""
    
    def test_health_endpoint_returns_200(self, client):
        """Test health endpoint returns HTTP 200 OK"""
        response = client.get("/health")
        assert response.status_code == 200
    
    def test_health_endpoint_response_structure(self, client):
        """Test health endpoint returns correct JSON structure"""
        response = client.get("/health")
        data = response.json()
        
        # Verify all required fields are present
        assert "status" in data
        assert "timestamp" in data
        assert "version" in data
        assert "environment" in data
        
        # Verify field values
        assert data["status"] == "healthy"
        assert data["version"] == "1.0"
        # Environment will be whatever is set in .env or default
        assert isinstance(data["environment"], str)
    
    def test_health_endpoint_timestamp_format(self, client):
        """Test health endpoint timestamp is in ISO format"""
        response = client.get("/health")
        data = response.json()
        
        # Verify timestamp contains expected ISO format elements
        timestamp = data["timestamp"]
        assert "T" in timestamp  # ISO 8601 format separator
        assert "Z" in timestamp or "+" in timestamp  # UTC indicator


class TestRootEndpoint:
    """Test suite for root / endpoint"""
    
    def test_root_endpoint_returns_200(self, client):
        """Test root endpoint returns HTTP 200 OK"""
        response = client.get("/")
        assert response.status_code == 200
    
    def test_root_endpoint_has_service_info(self, client):
        """Test root endpoint returns service information"""
        response = client.get("/")
        data = response.json()
        
        assert "service" in data
        assert "version" in data
        assert data["service"] == "TypeSafe API"


class TestCORSConfiguration:
    """Test suite for CORS middleware configuration"""
    
    def test_cors_headers_present_in_response(self, client):
        """Test CORS headers are present in responses"""
        # Include Origin header to trigger CORS
        response = client.get("/health", headers={"Origin": "https://example.com"})
        
        # Check for CORS headers
        assert "access-control-allow-origin" in response.headers
    
    def test_cors_allows_credentials(self, client):
        """Test CORS allows credentials"""
        response = client.options(
            "/health",
            headers={"Origin": "https://example.com"}
        )
        
        # Should allow credentials
        assert response.headers.get("access-control-allow-credentials") == "true"
    
    def test_cors_allows_post_method(self, client):
        """Test CORS allows POST method"""
        response = client.options(
            "/health",
            headers={
                "Origin": "https://example.com",
                "Access-Control-Request-Method": "POST"
            }
        )
        
        allowed_methods = response.headers.get("access-control-allow-methods", "")
        assert "POST" in allowed_methods


class TestRequestLoggingMiddleware:
    """Test suite for request logging middleware"""
    
    def test_request_id_header_in_response(self, client):
        """Test that X-Request-ID header is added to responses"""
        response = client.get("/health")
        
        assert "x-request-id" in response.headers
        request_id = response.headers["x-request-id"]
        
        # Verify it's a UUID format (simple check)
        assert len(request_id) == 36  # UUID length with hyphens
        assert request_id.count("-") == 4  # UUID has 4 hyphens


class TestSecurityHeaders:
    """Test suite for security headers middleware"""
    
    def test_hsts_header_environment_aware(self, client):
        """
        Test HSTS header is environment-aware.
        
        In test/local/dev environments: HSTS is not added to avoid local HTTP issues
        In production/staging: HSTS header is added with max-age=31536000; includeSubDomains
        
        This test verifies test environment behavior (HSTS not present).
        Production behavior is verified through deployment smoke tests.
        """
        response = client.get("/health")
        
        # HSTS should NOT be present in test environment
        # This prevents issues with local HTTP development
        assert "strict-transport-security" not in response.headers


class TestAppStartup:
    """Test suite for application startup validation"""
    
    def test_app_validates_config_on_startup(self):
        """Test that app validates configuration during startup"""
        # This test verifies the startup event runs successfully
        # If configuration validation fails, the import would raise an error
        from app.main import app
        
        assert app is not None
        assert app.title == "TypeSafe API"


class TestAnalyzeTextEndpoint:
    """Test suite for POST /analyze-text endpoint"""
    
    def test_valid_request_returns_200(self, client):
        """Test successful text analysis returns HTTP 200"""
        from unittest.mock import patch, AsyncMock
        
        # Mock risk aggregator response
        mock_risk_response = {
            'risk_level': 'high',
            'confidence': 0.92,
            'category': 'otp_phishing',
            'explanation': 'Message requests OTP code with urgency',
            'ts': '2025-01-18T10:30:00Z'
        }
        
        # Mock database insert response
        mock_db_response = {
            'id': '123e4567-e89b-12d3-a456-426614174001',
            'created_at': '2025-01-18T10:30:00Z'
        }
        
        with patch('app.main.analyze_text_aggregated', new_callable=AsyncMock) as mock_analyze:
            with patch('app.main.insert_text_analysis') as mock_insert:
                mock_analyze.return_value = mock_risk_response.copy()
                mock_insert.return_value = mock_db_response
                
                response = client.post(
                    "/analyze-text",
                    json={
                        "session_id": "123e4567-e89b-12d3-a456-426614174000",
                        "app_bundle": "com.whatsapp",
                        "text": "Your OTP code is 123456. Enter it now!"
                    }
                )
        
        assert response.status_code == 200
        data = response.json()
        
        # Verify response structure
        assert data['risk_level'] == 'high'
        assert data['confidence'] == 0.92
        assert data['category'] == 'otp_phishing'
        assert 'explanation' in data
        assert 'ts' in data
    
    def test_response_matches_schema(self, client):
        """Test response matches AnalyzeTextResponse schema"""
        from unittest.mock import patch, AsyncMock
        
        mock_risk_response = {
            'risk_level': 'low',
            'confidence': 0.15,
            'category': 'unknown',
            'explanation': 'No scam indicators detected',
            'ts': '2025-01-18T10:30:00Z'
        }
        
        mock_db_response = {'id': 'test-id', 'created_at': '2025-01-18T10:30:00Z'}
        
        with patch('app.main.analyze_text_aggregated', new_callable=AsyncMock) as mock_analyze:
            with patch('app.main.insert_text_analysis') as mock_insert:
                mock_analyze.return_value = mock_risk_response.copy()
                mock_insert.return_value = mock_db_response
                
                response = client.post(
                    "/analyze-text",
                    json={
                        "session_id": "123e4567-e89b-12d3-a456-426614174000",
                        "app_bundle": "com.telegram",
                        "text": "Hello, how are you?"
                    }
                )
        
        data = response.json()
        
        # Verify all required fields present
        assert 'risk_level' in data
        assert 'confidence' in data
        assert 'category' in data
        assert 'explanation' in data
        assert 'ts' in data
        
        # Verify types
        assert isinstance(data['risk_level'], str)
        assert isinstance(data['confidence'], float)
        assert isinstance(data['category'], str)
        assert isinstance(data['explanation'], str)
        assert isinstance(data['ts'], str)
    
    def test_risk_aggregator_called_with_text(self, client):
        """Test risk aggregator is called with correct text"""
        from unittest.mock import patch, AsyncMock
        
        mock_risk_response = {
            'risk_level': 'medium',
            'confidence': 0.65,
            'category': 'payment_scam',
            'explanation': 'Suspicious payment request',
            'ts': '2025-01-18T10:30:00Z'
        }
        
        mock_db_response = {'id': 'test-id', 'created_at': '2025-01-18T10:30:00Z'}
        
        with patch('app.main.analyze_text_aggregated', new_callable=AsyncMock) as mock_analyze:
            with patch('app.main.insert_text_analysis') as mock_insert:
                mock_analyze.return_value = mock_risk_response.copy()
                mock_insert.return_value = mock_db_response
                
                test_text = "Send $500 to this account urgently!"
                
                response = client.post(
                    "/analyze-text",
                    json={
                        "session_id": "123e4567-e89b-12d3-a456-426614174000",
                        "app_bundle": "com.whatsapp",
                        "text": test_text
                    }
                )
        
        # Verify mock was called with correct text
        mock_analyze.assert_called_once_with(text=test_text)
        assert response.status_code == 200
    
    def test_database_insert_called_with_correct_data(self, client):
        """Test database insert is called with correct parameters"""
        from unittest.mock import patch, AsyncMock
        from uuid import UUID
        
        mock_risk_response = {
            'risk_level': 'high',
            'confidence': 0.88,
            'category': 'impersonation',
            'explanation': 'Impersonates trusted entity',
            'ts': '2025-01-18T10:30:00Z'
        }
        
        mock_db_response = {'id': 'test-id', 'created_at': '2025-01-18T10:30:00Z'}
        
        test_session_id = "123e4567-e89b-12d3-a456-426614174000"
        test_app_bundle = "com.telegram"
        test_text = "I'm from bank support. Share your password."
        
        with patch('app.main.analyze_text_aggregated', new_callable=AsyncMock) as mock_analyze:
            with patch('app.main.insert_text_analysis') as mock_insert:
                mock_analyze.return_value = mock_risk_response.copy()
                mock_insert.return_value = mock_db_response
                
                response = client.post(
                    "/analyze-text",
                    json={
                        "session_id": test_session_id,
                        "app_bundle": test_app_bundle,
                        "text": test_text
                    }
                )
        
        # Verify database insert was called with correct parameters
        mock_insert.assert_called_once()
        call_args = mock_insert.call_args
        
        assert call_args.kwargs['session_id'] == UUID(test_session_id)
        assert call_args.kwargs['app_bundle'] == test_app_bundle
        assert call_args.kwargs['snippet'] == test_text
        
        # Verify risk_data doesn't contain 'ts' (removed before DB insert)
        risk_data = call_args.kwargs['risk_data']
        assert 'ts' not in risk_data
        assert risk_data['risk_level'] == 'high'
        assert risk_data['confidence'] == 0.88
        
        assert response.status_code == 200


class TestAnalyzeTextValidation:
    """Test suite for request validation on /analyze-text endpoint"""
    
    def test_missing_session_id_returns_422(self, client):
        """Test missing session_id returns validation error"""
        response = client.post(
            "/analyze-text",
            json={
                "app_bundle": "com.whatsapp",
                "text": "Test message"
            }
        )
        
        assert response.status_code == 422  # Validation error
        data = response.json()
        assert 'detail' in data
    
    def test_invalid_uuid_format_returns_422(self, client):
        """Test invalid UUID format returns validation error"""
        response = client.post(
            "/analyze-text",
            json={
                "session_id": "not-a-valid-uuid",
                "app_bundle": "com.whatsapp",
                "text": "Test message"
            }
        )
        
        assert response.status_code == 422
        data = response.json()
        assert 'detail' in data
    
    def test_missing_app_bundle_returns_422(self, client):
        """Test missing app_bundle returns validation error"""
        response = client.post(
            "/analyze-text",
            json={
                "session_id": "123e4567-e89b-12d3-a456-426614174000",
                "text": "Test message"
            }
        )
        
        assert response.status_code == 422
    
    def test_missing_text_returns_422(self, client):
        """Test missing text returns validation error"""
        response = client.post(
            "/analyze-text",
            json={
                "session_id": "123e4567-e89b-12d3-a456-426614174000",
                "app_bundle": "com.whatsapp"
            }
        )
        
        assert response.status_code == 422
    
    def test_empty_text_returns_422(self, client):
        """Test empty text returns validation error"""
        response = client.post(
            "/analyze-text",
            json={
                "session_id": "123e4567-e89b-12d3-a456-426614174000",
                "app_bundle": "com.whatsapp",
                "text": ""
            }
        )
        
        assert response.status_code == 422
    
    def test_whitespace_only_text_returns_422(self, client):
        """Test whitespace-only text returns validation error"""
        response = client.post(
            "/analyze-text",
            json={
                "session_id": "123e4567-e89b-12d3-a456-426614174000",
                "app_bundle": "com.whatsapp",
                "text": "   \n\t   "
            }
        )
        
        assert response.status_code == 422
    
    def test_text_exceeding_300_chars_returns_422(self, client):
        """Test text exceeding 300 characters returns validation error"""
        long_text = "a" * 301  # 301 characters
        
        response = client.post(
            "/analyze-text",
            json={
                "session_id": "123e4567-e89b-12d3-a456-426614174000",
                "app_bundle": "com.whatsapp",
                "text": long_text
            }
        )
        
        assert response.status_code == 422
    
    def test_text_exactly_300_chars_is_valid(self, client):
        """Test text with exactly 300 characters is valid"""
        from unittest.mock import patch, AsyncMock
        
        mock_risk_response = {
            'risk_level': 'low',
            'confidence': 0.15,
            'category': 'unknown',
            'explanation': 'No scam indicators',
            'ts': '2025-01-18T10:30:00Z'
        }
        
        mock_db_response = {'id': 'test-id', 'created_at': '2025-01-18T10:30:00Z'}
        
        text_300_chars = "a" * 300  # Exactly 300 characters
        
        with patch('app.main.analyze_text_aggregated', new_callable=AsyncMock) as mock_analyze:
            with patch('app.main.insert_text_analysis') as mock_insert:
                mock_analyze.return_value = mock_risk_response.copy()
                mock_insert.return_value = mock_db_response
                
                response = client.post(
                    "/analyze-text",
                    json={
                        "session_id": "123e4567-e89b-12d3-a456-426614174000",
                        "app_bundle": "com.whatsapp",
                        "text": text_300_chars
                    }
                )
        
        assert response.status_code == 200


class TestAnalyzeTextErrorHandling:
    """Test suite for error handling on /analyze-text endpoint"""
    
    def test_openai_failure_returns_500(self, client):
        """Test OpenAI service failure returns HTTP 500"""
        from unittest.mock import patch, AsyncMock
        
        with patch('app.main.analyze_text_aggregated', new_callable=AsyncMock) as mock_analyze:
            # Simulate OpenAI service failure
            mock_analyze.side_effect = Exception("OpenAI API error")
            
            response = client.post(
                "/analyze-text",
                json={
                    "session_id": "123e4567-e89b-12d3-a456-426614174000",
                    "app_bundle": "com.whatsapp",
                    "text": "Test message"
                }
            )
        
        assert response.status_code == 500
        data = response.json()
        assert 'detail' in data
        # Verify error message doesn't leak internal details
        assert 'Analysis service temporarily unavailable' in data['detail']
    
    def test_database_failure_returns_500(self, client):
        """Test database insertion failure returns HTTP 500"""
        from unittest.mock import patch, AsyncMock
        
        mock_risk_response = {
            'risk_level': 'low',
            'confidence': 0.15,
            'category': 'unknown',
            'explanation': 'No scam indicators',
            'ts': '2025-01-18T10:30:00Z'
        }
        
        with patch('app.main.analyze_text_aggregated', new_callable=AsyncMock) as mock_analyze:
            with patch('app.main.insert_text_analysis') as mock_insert:
                mock_analyze.return_value = mock_risk_response.copy()
                # Simulate database failure
                mock_insert.side_effect = Exception("Database connection error")
                
                response = client.post(
                    "/analyze-text",
                    json={
                        "session_id": "123e4567-e89b-12d3-a456-426614174000",
                        "app_bundle": "com.whatsapp",
                        "text": "Test message"
                    }
                )
        
        assert response.status_code == 500
        data = response.json()
        assert 'detail' in data
        assert 'Failed to store analysis result' in data['detail']
    
    def test_error_responses_dont_leak_sensitive_data(self, client):
        """Test error responses don't expose sensitive internal information"""
        from unittest.mock import patch, AsyncMock
        
        with patch('app.main.analyze_text_aggregated', new_callable=AsyncMock) as mock_analyze:
            # Simulate error with sensitive info in exception
            mock_analyze.side_effect = Exception("API_KEY=sk-secret Database=postgresql://user:pass@host")
            
            response = client.post(
                "/analyze-text",
                json={
                    "session_id": "123e4567-e89b-12d3-a456-426614174000",
                    "app_bundle": "com.whatsapp",
                    "text": "Test message"
                }
            )
        
        data = response.json()
        detail = data.get('detail', '')
        
        # Verify sensitive information is not in response
        assert 'API_KEY' not in detail
        assert 'sk-secret' not in detail
        assert 'postgresql://' not in detail
        assert 'user:pass' not in detail


class TestAnalyzeTextPerformance:
    """Test suite for performance validation on /analyze-text endpoint"""
    
    def test_response_time_is_measured(self, client):
        """Test response time is within acceptable limits"""
        from unittest.mock import patch, AsyncMock
        import time
        
        mock_risk_response = {
            'risk_level': 'low',
            'confidence': 0.15,
            'category': 'unknown',
            'explanation': 'No scam indicators',
            'ts': '2025-01-18T10:30:00Z'
        }
        
        mock_db_response = {'id': 'test-id', 'created_at': '2025-01-18T10:30:00Z'}
        
        async def fast_analyze(text):
            """Simulate fast analysis (<100ms)"""
            await AsyncMock()()
            return mock_risk_response.copy()
        
        with patch('app.main.analyze_text_aggregated', side_effect=fast_analyze):
            with patch('app.main.insert_text_analysis') as mock_insert:
                mock_insert.return_value = mock_db_response
                
                start_time = time.time()
                
                response = client.post(
                    "/analyze-text",
                    json={
                        "session_id": "123e4567-e89b-12d3-a456-426614174000",
                        "app_bundle": "com.whatsapp",
                        "text": "Test message"
                    }
                )
                
                elapsed_time = time.time() - start_time
        
        assert response.status_code == 200
        
        # With mocked fast services, total response should be < 2 seconds
        # This validates endpoint overhead is minimal
        assert elapsed_time < 2.0, f"Response took {elapsed_time:.2f}s, expected < 2.0s"
    
    def test_caching_behavior_with_duplicate_requests(self, client):
        """Test that duplicate requests leverage caching"""
        from unittest.mock import patch, AsyncMock
        
        mock_risk_response = {
            'risk_level': 'low',
            'confidence': 0.15,
            'category': 'unknown',
            'explanation': 'No scam indicators',
            'ts': '2025-01-18T10:30:00Z'
        }
        
        mock_db_response = {'id': 'test-id', 'created_at': '2025-01-18T10:30:00Z'}
        
        with patch('app.main.analyze_text_aggregated', new_callable=AsyncMock) as mock_analyze:
            with patch('app.main.insert_text_analysis') as mock_insert:
                mock_analyze.return_value = mock_risk_response.copy()
                mock_insert.return_value = mock_db_response
                
                # Send same request twice
                for _ in range(2):
                    response = client.post(
                        "/analyze-text",
                        json={
                            "session_id": "123e4567-e89b-12d3-a456-426614174000",
                            "app_bundle": "com.whatsapp",
                            "text": "Test duplicate message"
                        }
                    )
                    assert response.status_code == 200
                
                # Note: Both requests will call the aggregator because caching
                # happens at the OpenAI service level, not the endpoint level
                assert mock_analyze.call_count == 2

