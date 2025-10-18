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


class TestScanImageHappyPath:
    """Test suite for successful /scan-image endpoint scenarios"""
    
    def test_scan_image_with_image_and_text_gemini_success(self, client):
        """Test scan-image with image and OCR text, Gemini succeeds"""
        from unittest.mock import patch, AsyncMock
        import io
        
        mock_gemini_response = {
            'risk_level': 'high',
            'confidence': 0.95,
            'category': 'visual_scam',
            'explanation': 'Screenshot shows fake banking interface'
        }
        
        mock_db_response = {'id': 'test-id', 'created_at': '2025-01-18T10:30:00Z'}
        
        # Create a simple PNG image (1x1 red pixel)
        png_data = (
            b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01'
            b'\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\xcf'
            b'\xc0\x00\x00\x00\x03\x00\x01\x00\x18\xdd\x8d\xb4\x00\x00\x00\x00IEND\xaeB`\x82'
        )
        
        with patch('app.main.analyze_image', new_callable=AsyncMock) as mock_gemini:
            with patch('app.main.insert_scan_result') as mock_insert:
                mock_gemini.return_value = mock_gemini_response.copy()
                mock_insert.return_value = mock_db_response
                
                response = client.post(
                    "/scan-image",
                    data={
                        "session_id": "123e4567-e89b-12d3-a456-426614174000",
                        "ocr_text": "Click here to verify your bank account"
                    },
                    files={"image": ("test.png", io.BytesIO(png_data), "image/png")}
                )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data['risk_level'] == 'high'
        assert data['confidence'] == 0.95
        assert data['category'] == 'visual_scam'
        assert 'explanation' in data
        assert 'ts' in data
    
    def test_scan_image_text_only_openai_fallback(self, client):
        """Test scan-image with OCR text only (no image), OpenAI fallback"""
        from unittest.mock import patch, AsyncMock
        
        mock_openai_response = {
            'risk_level': 'medium',
            'confidence': 0.75,
            'category': 'otp_phishing',
            'explanation': 'Suspicious OTP request message'
        }
        
        mock_db_response = {'id': 'test-id', 'created_at': '2025-01-18T10:30:00Z'}
        
        # Gemini will not be called since no image
        with patch('app.main.analyze_image', new_callable=AsyncMock) as mock_gemini:
            with patch('app.main.analyze_text', new_callable=AsyncMock) as mock_openai:
                with patch('app.main.insert_scan_result') as mock_insert:
                    # Gemini returns unknown since no image
                    mock_gemini.return_value = {'risk_level': 'unknown', 'confidence': 0.0, 'category': 'unknown', 'explanation': 'No image provided'}
                    mock_openai.return_value = mock_openai_response.copy()
                    mock_insert.return_value = mock_db_response
                    
                    response = client.post(
                        "/scan-image",
                        data={
                            "session_id": "123e4567-e89b-12d3-a456-426614174000",
                            "ocr_text": "Your OTP code is 123456"
                        }
                    )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data['risk_level'] == 'medium'
        assert data['confidence'] == 0.75
        assert data['category'] == 'otp_phishing'
    
    def test_scan_image_both_providers_aggregated(self, client):
        """Test scan-image with Gemini returning unknown, triggering OpenAI fallback and aggregation"""
        from unittest.mock import patch, AsyncMock
        import io
        
        # Gemini returns unknown (triggers fallback), OpenAI returns valid result
        # Both non-unknown results trigger aggregation
        mock_gemini_response = {
            'risk_level': 'unknown',
            'confidence': 0.0,
            'category': 'unknown',
            'explanation': 'Cannot analyze image'
        }
        
        mock_openai_response = {
            'risk_level': 'medium',
            'confidence': 0.78,
            'category': 'otp_phishing',
            'explanation': 'Text suggests OTP phishing'
        }
        
        mock_db_response = {'id': 'test-id', 'created_at': '2025-01-18T10:30:00Z'}
        
        png_data = (
            b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01'
            b'\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\xcf'
            b'\xc0\x00\x00\x00\x03\x00\x01\x00\x18\xdd\x8d\xb4\x00\x00\x00\x00IEND\xaeB`\x82'
        )
        
        with patch('app.main.analyze_image', new_callable=AsyncMock) as mock_gemini:
            with patch('app.main.analyze_text', new_callable=AsyncMock) as mock_openai:
                with patch('app.main.insert_scan_result') as mock_insert:
                    mock_gemini.return_value = mock_gemini_response.copy()
                    mock_openai.return_value = mock_openai_response.copy()
                    mock_insert.return_value = mock_db_response
                    
                    response = client.post(
                        "/scan-image",
                        data={
                            "session_id": "123e4567-e89b-12d3-a456-426614174000",
                            "ocr_text": "Your OTP: 123456"
                        },
                        files={"image": ("test.png", io.BytesIO(png_data), "image/png")}
                    )
        
        assert response.status_code == 200
        data = response.json()
        
        # Verify OpenAI result is returned (since Gemini was unknown)
        assert data['risk_level'] == 'medium'
        assert data['confidence'] == 0.78
        assert data['category'] == 'otp_phishing'
        # Verify both were called (Gemini then fallback to OpenAI)
        mock_gemini.assert_called_once()
        mock_openai.assert_called_once()


class TestScanImageValidation:
    """Test suite for request validation on /scan-image endpoint"""
    
    def test_missing_session_id_returns_422(self, client):
        """Test missing session_id returns validation error"""
        response = client.post(
            "/scan-image",
            data={
                "ocr_text": "Test message"
            }
        )
        
        assert response.status_code == 422
        data = response.json()
        assert 'detail' in data
    
    def test_invalid_uuid_format_returns_400(self, client):
        """Test invalid UUID format returns 400 error"""
        response = client.post(
            "/scan-image",
            data={
                "session_id": "not-a-valid-uuid",
                "ocr_text": "Test message"
            }
        )
        
        assert response.status_code == 400
        data = response.json()
        assert 'detail' in data
        assert 'UUID' in data['detail']
    
    def test_missing_ocr_text_returns_422(self, client):
        """Test missing ocr_text returns validation error"""
        response = client.post(
            "/scan-image",
            data={
                "session_id": "123e4567-e89b-12d3-a456-426614174000"
            }
        )
        
        assert response.status_code == 422
    
    def test_empty_ocr_text_returns_422(self, client):
        """Test empty ocr_text returns validation error"""
        response = client.post(
            "/scan-image",
            data={
                "session_id": "123e4567-e89b-12d3-a456-426614174000",
                "ocr_text": ""
            }
        )
        
        assert response.status_code == 422
        data = response.json()
        assert 'detail' in data
    
    def test_whitespace_only_ocr_text_returns_422(self, client):
        """Test whitespace-only ocr_text returns validation error"""
        response = client.post(
            "/scan-image",
            data={
                "session_id": "123e4567-e89b-12d3-a456-426614174000",
                "ocr_text": "   \n\t  "
            }
        )
        
        assert response.status_code == 422
    
    def test_ocr_text_exceeds_max_length_returns_400(self, client):
        """Test OCR text exceeding 5000 chars returns 400 error"""
        long_text = "A" * 5001
        
        response = client.post(
            "/scan-image",
            data={
                "session_id": "123e4567-e89b-12d3-a456-426614174000",
                "ocr_text": long_text
            }
        )
        
        assert response.status_code == 400
        data = response.json()
        assert 'detail' in data
        assert '5000' in data['detail']
    
    def test_invalid_image_format_returns_400(self, client):
        """Test invalid image format returns 400 error"""
        import io
        
        # Create invalid image data (not PNG or JPEG)
        invalid_data = b'This is not an image file'
        
        response = client.post(
            "/scan-image",
            data={
                "session_id": "123e4567-e89b-12d3-a456-426614174000",
                "ocr_text": "Test message"
            },
            files={"image": ("test.txt", io.BytesIO(invalid_data), "text/plain")}
        )
        
        assert response.status_code == 400
        data = response.json()
        assert 'detail' in data
        assert 'format' in data['detail'].lower()
    
    def test_image_too_large_returns_400(self, client):
        """Test image larger than 4MB returns 400 error"""
        import io
        
        # Create image data larger than 4MB
        large_data = b'\x89PNG\r\n\x1a\n' + (b'X' * (4 * 1024 * 1024 + 1))
        
        response = client.post(
            "/scan-image",
            data={
                "session_id": "123e4567-e89b-12d3-a456-426614174000",
                "ocr_text": "Test message"
            },
            files={"image": ("test.png", io.BytesIO(large_data), "image/png")}
        )
        
        assert response.status_code == 400
        data = response.json()
        assert 'detail' in data
        assert '4MB' in data['detail']


class TestScanImageErrorHandling:
    """Test suite for error handling on /scan-image endpoint"""
    
    def test_gemini_failure_triggers_openai_fallback(self, client):
        """Test Gemini failure triggers OpenAI fallback"""
        from unittest.mock import patch, AsyncMock
        import io
        
        mock_openai_response = {
            'risk_level': 'medium',
            'confidence': 0.70,
            'category': 'payment_scam',
            'explanation': 'Suspicious payment request'
        }
        
        mock_db_response = {'id': 'test-id', 'created_at': '2025-01-18T10:30:00Z'}
        
        png_data = (
            b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01'
            b'\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\xcf'
            b'\xc0\x00\x00\x00\x03\x00\x01\x00\x18\xdd\x8d\xb4\x00\x00\x00\x00IEND\xaeB`\x82'
        )
        
        with patch('app.main.analyze_image', new_callable=AsyncMock) as mock_gemini:
            with patch('app.main.analyze_text', new_callable=AsyncMock) as mock_openai:
                with patch('app.main.insert_scan_result') as mock_insert:
                    # Gemini fails
                    mock_gemini.side_effect = Exception("Gemini API error")
                    mock_openai.return_value = mock_openai_response.copy()
                    mock_insert.return_value = mock_db_response
                    
                    response = client.post(
                        "/scan-image",
                        data={
                            "session_id": "123e4567-e89b-12d3-a456-426614174000",
                            "ocr_text": "Send money to this account"
                        },
                        files={"image": ("test.png", io.BytesIO(png_data), "image/png")}
                    )
        
        assert response.status_code == 200
        data = response.json()
        
        # Should return OpenAI result
        assert data['risk_level'] == 'medium'
        assert data['category'] == 'payment_scam'
        mock_openai.assert_called_once()
    
    def test_both_providers_fail_returns_fallback(self, client):
        """Test both providers failing returns safe fallback response"""
        from unittest.mock import patch, AsyncMock
        
        mock_db_response = {'id': 'test-id', 'created_at': '2025-01-18T10:30:00Z'}
        
        with patch('app.main.analyze_image', new_callable=AsyncMock) as mock_gemini:
            with patch('app.main.analyze_text', new_callable=AsyncMock) as mock_openai:
                with patch('app.main.insert_scan_result') as mock_insert:
                    # Both providers fail
                    mock_gemini.side_effect = Exception("Gemini error")
                    mock_openai.side_effect = Exception("OpenAI error")
                    mock_insert.return_value = mock_db_response
                    
                    response = client.post(
                        "/scan-image",
                        data={
                            "session_id": "123e4567-e89b-12d3-a456-426614174000",
                            "ocr_text": "Test message"
                        }
                    )
        
        assert response.status_code == 200
        data = response.json()
        
        # Should return safe fallback
        assert data['risk_level'] == 'unknown'
        assert data['confidence'] == 0.0
        assert data['category'] == 'unknown'
        assert 'Unable to complete analysis' in data['explanation']
    
    def test_database_failure_returns_500(self, client):
        """Test database insertion failure returns 500 error"""
        from unittest.mock import patch, AsyncMock
        import io
        
        mock_gemini_response = {
            'risk_level': 'low',
            'confidence': 0.20,
            'category': 'unknown',
            'explanation': 'No scam indicators'
        }
        
        png_data = (
            b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01'
            b'\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\xcf'
            b'\xc0\x00\x00\x00\x03\x00\x01\x00\x18\xdd\x8d\xb4\x00\x00\x00\x00IEND\xaeB`\x82'
        )
        
        with patch('app.main.analyze_image', new_callable=AsyncMock) as mock_gemini:
            with patch('app.main.insert_scan_result') as mock_insert:
                mock_gemini.return_value = mock_gemini_response.copy()
                mock_insert.side_effect = Exception("Database connection error")
                
                response = client.post(
                    "/scan-image",
                    data={
                        "session_id": "123e4567-e89b-12d3-a456-426614174000",
                        "ocr_text": "Hello world"
                    },
                    files={"image": ("test.png", io.BytesIO(png_data), "image/png")}
                )
        
        assert response.status_code == 500
        data = response.json()
        assert 'detail' in data
        # Should not expose internal error details
        assert 'Database connection' not in data['detail']


class TestScanImageIntegration:
    """Test suite for integration scenarios on /scan-image endpoint"""
    
    def test_response_matches_schema(self, client):
        """Test response matches ScanImageResponse schema"""
        from unittest.mock import patch, AsyncMock
        
        mock_gemini_response = {
            'risk_level': 'low',
            'confidence': 0.10,
            'category': 'unknown',
            'explanation': 'No suspicious content detected'
        }
        
        mock_db_response = {'id': 'test-id', 'created_at': '2025-01-18T10:30:00Z'}
        
        with patch('app.main.analyze_image', new_callable=AsyncMock) as mock_gemini:
            with patch('app.main.insert_scan_result') as mock_insert:
                mock_gemini.return_value = mock_gemini_response.copy()
                mock_insert.return_value = mock_db_response
                
                response = client.post(
                    "/scan-image",
                    data={
                        "session_id": "123e4567-e89b-12d3-a456-426614174000",
                        "ocr_text": "Hello, this is a normal message"
                    }
                )
        
        assert response.status_code == 200
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
    
    def test_database_insert_called_with_correct_data(self, client):
        """Test database insert is called with correct parameters"""
        from unittest.mock import patch, AsyncMock
        from uuid import UUID
        
        mock_gemini_response = {
            'risk_level': 'high',
            'confidence': 0.90,
            'category': 'visual_scam',
            'explanation': 'Fake interface detected'
        }
        
        mock_db_response = {'id': 'test-id', 'created_at': '2025-01-18T10:30:00Z'}
        
        test_session_id = "123e4567-e89b-12d3-a456-426614174000"
        test_ocr_text = "Click here to verify"
        
        with patch('app.main.analyze_image', new_callable=AsyncMock) as mock_gemini:
            with patch('app.main.insert_scan_result') as mock_insert:
                mock_gemini.return_value = mock_gemini_response.copy()
                mock_insert.return_value = mock_db_response
                
                response = client.post(
                    "/scan-image",
                    data={
                        "session_id": test_session_id,
                        "ocr_text": test_ocr_text
                    }
                )
        
        # Verify database insert was called with correct parameters
        mock_insert.assert_called_once()
        call_args = mock_insert.call_args
        
        # Check if positional or keyword arguments were used
        if call_args.args:
            assert call_args.args[0] == UUID(test_session_id)
            assert call_args.args[1] == test_ocr_text
            risk_data = call_args.args[2]
        else:
            assert call_args.kwargs['session_id'] == UUID(test_session_id)
            assert call_args.kwargs['ocr_text'] == test_ocr_text
            risk_data = call_args.kwargs['risk_data']
        
        # Verify risk_data
        assert risk_data['risk_level'] == 'high'
        assert risk_data['confidence'] == 0.90
        assert risk_data['category'] == 'visual_scam'
        
        assert response.status_code == 200
    
    def test_multipart_form_parsing_with_image(self, client):
        """Test multipart form data parsing with image upload"""
        from unittest.mock import patch, AsyncMock
        import io
        
        mock_gemini_response = {
            'risk_level': 'medium',
            'confidence': 0.65,
            'category': 'otp_phishing',
            'explanation': 'OTP request detected'
        }
        
        mock_db_response = {'id': 'test-id', 'created_at': '2025-01-18T10:30:00Z'}
        
        # Create valid PNG
        png_data = (
            b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01'
            b'\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\xcf'
            b'\xc0\x00\x00\x00\x03\x00\x01\x00\x18\xdd\x8d\xb4\x00\x00\x00\x00IEND\xaeB`\x82'
        )
        
        with patch('app.main.analyze_image', new_callable=AsyncMock) as mock_gemini:
            with patch('app.main.insert_scan_result') as mock_insert:
                mock_gemini.return_value = mock_gemini_response.copy()
                mock_insert.return_value = mock_db_response
                
                response = client.post(
                    "/scan-image",
                    data={
                        "session_id": "123e4567-e89b-12d3-a456-426614174000",
                        "ocr_text": "Your OTP is 654321"
                    },
                    files={"image": ("screenshot.png", io.BytesIO(png_data), "image/png")}
                )
        
        assert response.status_code == 200
        
        # Verify analyze_image was called with image data
        mock_gemini.assert_called_once()
        call_kwargs = mock_gemini.call_args.kwargs
        assert call_kwargs['image_data'] is not None
        assert call_kwargs['ocr_text'] == "Your OTP is 654321"
        assert call_kwargs['mime_type'] == "image/png"
    
    def test_privacy_conscious_logging(self, client):
        """Test that no sensitive content is logged"""
        from unittest.mock import patch, AsyncMock
        import logging
        
        mock_gemini_response = {
            'risk_level': 'low',
            'confidence': 0.15,
            'category': 'unknown',
            'explanation': 'No risk detected'
        }
        
        mock_db_response = {'id': 'test-id', 'created_at': '2025-01-18T10:30:00Z'}
        
        # Capture log messages
        with patch('app.main.logger') as mock_logger:
            with patch('app.main.analyze_image', new_callable=AsyncMock) as mock_gemini:
                with patch('app.main.insert_scan_result') as mock_insert:
                    mock_gemini.return_value = mock_gemini_response.copy()
                    mock_insert.return_value = mock_db_response
                    
                    sensitive_text = "My password is secret123!"
                    
                    response = client.post(
                        "/scan-image",
                        data={
                            "session_id": "123e4567-e89b-12d3-a456-426614174000",
                            "ocr_text": sensitive_text
                        }
                    )
        
        assert response.status_code == 200
        
        # Verify sensitive text was NOT logged
        for call in mock_logger.info.call_args_list:
            log_message = str(call)
            assert sensitive_text not in log_message
        
        # Verify at least one scan_image log contains metadata
        scan_image_logs = [str(call) for call in mock_logger.info.call_args_list if 'scan_image:' in str(call)]
        assert len(scan_image_logs) > 0
        # Should log metadata only (ocr_text_length, not content)
        assert any('ocr_text_length' in log for log in scan_image_logs)


class TestGetLatestResultHappyPath:
    """Test suite for GET /results/latest endpoint happy paths"""
    
    def test_retrieve_latest_text_analysis_result(self, client):
        """Test retrieving latest result when only text_analyses exists"""
        from unittest.mock import patch
        
        mock_db_response = {
            'type': 'text_analysis',
            'data': {
                'id': 1,
                'session_id': '123e4567-e89b-12d3-a456-426614174000',
                'app_bundle': 'com.whatsapp',
                'snippet': 'Test message',
                'risk_level': 'medium',
                'confidence': 0.75,
                'category': 'otp_phishing',
                'explanation': 'Suspicious OTP request detected',
                'created_at': '2025-01-18T10:30:00Z'
            },
            'created_at': '2025-01-18T10:30:00Z'
        }
        
        with patch('app.main.get_latest_result') as mock_get_latest:
            mock_get_latest.return_value = mock_db_response
            
            response = client.get(
                "/results/latest",
                params={"session_id": "123e4567-e89b-12d3-a456-426614174000"}
            )
        
        assert response.status_code == 200
        data = response.json()
        
        # Verify response schema
        assert 'risk_level' in data
        assert 'confidence' in data
        assert 'category' in data
        assert 'explanation' in data
        assert 'ts' in data
        
        # Verify data matches text_analysis result
        assert data['risk_level'] == 'medium'
        assert data['confidence'] == 0.75
        assert data['category'] == 'otp_phishing'
        assert data['explanation'] == 'Suspicious OTP request detected'
        assert data['ts'] == '2025-01-18T10:30:00Z'
    
    def test_retrieve_latest_scan_result(self, client):
        """Test retrieving latest result when only scan_results exists"""
        from unittest.mock import patch
        
        mock_db_response = {
            'type': 'scan_result',
            'data': {
                'id': 2,
                'session_id': '123e4567-e89b-12d3-a456-426614174000',
                'ocr_text': 'Pay $1000 now',
                'risk_level': 'high',
                'confidence': 0.90,
                'category': 'payment_scam',
                'explanation': 'Urgent payment request detected',
                'created_at': '2025-01-18T11:00:00Z'
            },
            'created_at': '2025-01-18T11:00:00Z'
        }
        
        with patch('app.main.get_latest_result') as mock_get_latest:
            mock_get_latest.return_value = mock_db_response
            
            response = client.get(
                "/results/latest",
                params={"session_id": "123e4567-e89b-12d3-a456-426614174000"}
            )
        
        assert response.status_code == 200
        data = response.json()
        
        # Verify data matches scan_result
        assert data['risk_level'] == 'high'
        assert data['confidence'] == 0.90
        assert data['category'] == 'payment_scam'
        assert data['explanation'] == 'Urgent payment request detected'
        assert data['ts'] == '2025-01-18T11:00:00Z'
    
    def test_retrieve_most_recent_when_both_exist(self, client):
        """Test most recent result is returned when both text and scan results exist"""
        from unittest.mock import patch
        
        # Mock returns scan_result as most recent
        mock_db_response = {
            'type': 'scan_result',
            'data': {
                'id': 3,
                'session_id': '123e4567-e89b-12d3-a456-426614174000',
                'ocr_text': 'Latest scan',
                'risk_level': 'low',
                'confidence': 0.30,
                'category': 'unknown',
                'explanation': 'No scam indicators',
                'created_at': '2025-01-18T12:00:00Z'
            },
            'created_at': '2025-01-18T12:00:00Z'
        }
        
        with patch('app.main.get_latest_result') as mock_get_latest:
            mock_get_latest.return_value = mock_db_response
            
            response = client.get(
                "/results/latest",
                params={"session_id": "123e4567-e89b-12d3-a456-426614174000"}
            )
        
        assert response.status_code == 200
        data = response.json()
        
        # Verify most recent (scan_result) is returned
        assert data['risk_level'] == 'low'
        assert data['ts'] == '2025-01-18T12:00:00Z'


class TestGetLatestResultValidation:
    """Test suite for validation on GET /results/latest endpoint"""
    
    def test_missing_session_id_returns_422(self, client):
        """Test missing session_id query parameter returns 422 error"""
        response = client.get("/results/latest")
        
        assert response.status_code == 422
        data = response.json()
        assert 'detail' in data
    
    def test_invalid_uuid_format_returns_400(self, client):
        """Test invalid UUID format returns 400 error"""
        response = client.get(
            "/results/latest",
            params={"session_id": "not-a-valid-uuid"}
        )
        
        assert response.status_code == 400
        data = response.json()
        assert 'detail' in data
        assert 'UUID' in data['detail']
    
    def test_empty_session_id_returns_400(self, client):
        """Test empty session_id returns 400 error"""
        response = client.get(
            "/results/latest",
            params={"session_id": ""}
        )
        
        assert response.status_code == 400
        data = response.json()
        assert 'detail' in data
    
    def test_malformed_uuid_returns_400(self, client):
        """Test malformed UUID returns 400 error"""
        response = client.get(
            "/results/latest",
            params={"session_id": "123e4567-e89b-12d3-a456-42661417400x"}
        )
        
        assert response.status_code == 400
        data = response.json()
        assert 'detail' in data
        assert 'UUID' in data['detail']


class TestGetLatestResultNotFound:
    """Test suite for not found scenarios on GET /results/latest endpoint"""
    
    def test_no_results_for_session_returns_404(self, client):
        """Test valid session_id but no results returns 404 error"""
        from unittest.mock import patch
        
        with patch('app.main.get_latest_result') as mock_get_latest:
            mock_get_latest.return_value = None
            
            response = client.get(
                "/results/latest",
                params={"session_id": "123e4567-e89b-12d3-a456-426614174000"}
            )
        
        assert response.status_code == 404
        data = response.json()
        assert 'detail' in data
        assert 'No results found' in data['detail']
    
    def test_valid_session_no_data_returns_404(self, client):
        """Test valid session with no analysis data returns 404"""
        from unittest.mock import patch
        
        with patch('app.main.get_latest_result') as mock_get_latest:
            # Simulate session exists but no analyses
            mock_get_latest.return_value = None
            
            response = client.get(
                "/results/latest",
                params={"session_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"}
            )
        
        assert response.status_code == 404
        data = response.json()
        assert 'detail' in data


class TestGetLatestResultErrorHandling:
    """Test suite for error handling on GET /results/latest endpoint"""
    
    def test_database_query_failure_returns_500(self, client):
        """Test database query failure returns 500 error"""
        from unittest.mock import patch
        
        with patch('app.main.get_latest_result') as mock_get_latest:
            mock_get_latest.side_effect = Exception("Database connection error")
            
            response = client.get(
                "/results/latest",
                params={"session_id": "123e4567-e89b-12d3-a456-426614174000"}
            )
        
        assert response.status_code == 500
        data = response.json()
        assert 'detail' in data
        # Sanitized error message (no database details)
        assert 'Database connection error' not in data['detail']
        assert 'try again' in data['detail'].lower()
    
    def test_database_timeout_returns_500(self, client):
        """Test database timeout returns 500 error"""
        from unittest.mock import patch
        
        with patch('app.main.get_latest_result') as mock_get_latest:
            mock_get_latest.side_effect = TimeoutError("Database timeout")
            
            response = client.get(
                "/results/latest",
                params={"session_id": "123e4567-e89b-12d3-a456-426614174000"}
            )
        
        assert response.status_code == 500
        data = response.json()
        assert 'detail' in data
    
    def test_unexpected_error_returns_500(self, client):
        """Test unexpected error returns 500 with sanitized message"""
        from unittest.mock import patch
        
        with patch('app.main.get_latest_result') as mock_get_latest:
            mock_get_latest.side_effect = RuntimeError("Unexpected internal error")
            
            response = client.get(
                "/results/latest",
                params={"session_id": "123e4567-e89b-12d3-a456-426614174000"}
            )
        
        assert response.status_code == 500
        data = response.json()
        assert 'detail' in data
        # Verify sensitive error details are not exposed
        assert 'Unexpected internal error' not in data['detail']


class TestGetLatestResultPrivacy:
    """Test suite for privacy requirements on GET /results/latest endpoint"""
    
    def test_no_content_logged(self, client):
        """Test that retrieved content (text, explanation) is not logged"""
        from unittest.mock import patch
        
        sensitive_explanation = "This is a sensitive explanation with PII"
        
        mock_db_response = {
            'type': 'text_analysis',
            'data': {
                'id': 1,
                'session_id': '123e4567-e89b-12d3-a456-426614174000',
                'app_bundle': 'com.test',
                'snippet': 'Sensitive text content',
                'risk_level': 'low',
                'confidence': 0.50,
                'category': 'unknown',
                'explanation': sensitive_explanation,
                'created_at': '2025-01-18T10:30:00Z'
            },
            'created_at': '2025-01-18T10:30:00Z'
        }
        
        with patch('app.main.get_latest_result') as mock_get_latest:
            with patch('app.main.logger') as mock_logger:
                mock_get_latest.return_value = mock_db_response
                
                response = client.get(
                    "/results/latest",
                    params={"session_id": "123e4567-e89b-12d3-a456-426614174000"}
                )
        
        assert response.status_code == 200
        
        # Verify sensitive content was NOT logged
        for call in mock_logger.info.call_args_list:
            log_message = str(call)
            assert sensitive_explanation not in log_message
            assert 'Sensitive text content' not in log_message
        
        # Verify session_id WAS logged (it's not PII, just a random UUID)
        get_latest_logs = [str(call) for call in mock_logger.info.call_args_list if 'get_latest_result:' in str(call)]
        assert len(get_latest_logs) > 0
        assert any('session_id' in log for log in get_latest_logs)

