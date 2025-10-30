"""
Tests for OpenAI service with mocked API responses.
"""
import pytest
from unittest.mock import Mock, AsyncMock, patch
from openai import APITimeoutError, RateLimitError, AuthenticationError, OpenAIError

from app.services import openai_service
from app.services.openai_service import (
    get_client,
    analyze_text,
    clear_cache,
    get_cache_stats,
    _normalize_response,
    _create_fallback_response
)


class TestOpenAIClientInitialization:
    """Test OpenAI client initialization."""
    
    @patch('app.services.openai_service.settings')
    def test_client_initialization_with_valid_key(self, mock_settings):
        """Test client initializes successfully with valid API key."""
        mock_settings.openai_api_key = "sk-test-key-123"
        
        # Reset global client
        openai_service._client = None
        
        client = get_client()
        assert client is not None
    
    @patch('app.services.openai_service.settings')
    def test_client_initialization_fails_without_key(self, mock_settings):
        """Test client initialization fails without API key."""
        mock_settings.openai_api_key = ""
        
        # Reset global client
        openai_service._client = None
        
        with pytest.raises(ValueError, match="OPENAI_API_KEY not configured"):
            get_client()


class TestResponseNormalization:
    """Test response parsing and normalization."""
    
    def test_normalize_valid_response(self):
        """Test normalizing a valid OpenAI response."""
        raw_response = '''
        {
            "risk_level": "high",
            "confidence": 0.92,
            "category": "otp_phishing",
            "explanation": "Text requests OTP code"
        }
        '''
        
        result = _normalize_response(raw_response)
        
        assert result["risk_level"] == "high"
        assert result["confidence"] == 0.92
        assert result["category"] == "otp_phishing"
        assert result["explanation"] == "Text requests OTP code"
    
    def test_normalize_clamps_confidence(self):
        """Test confidence is clamped to 0.0-1.0 range."""
        # Test upper bound
        raw_response = '{"risk_level": "high", "confidence": 1.5, "category": "unknown", "explanation": "test"}'
        result = _normalize_response(raw_response)
        assert result["confidence"] == 1.0
        
        # Test lower bound
        raw_response = '{"risk_level": "low", "confidence": -0.5, "category": "unknown", "explanation": "test"}'
        result = _normalize_response(raw_response)
        assert result["confidence"] == 0.0
    
    def test_normalize_invalid_risk_level(self):
        """Test invalid risk level defaults to unknown."""
        raw_response = '{"risk_level": "extreme", "confidence": 0.5, "category": "unknown", "explanation": "test"}'
        result = _normalize_response(raw_response)
        assert result["risk_level"] == "unknown"
    
    def test_normalize_invalid_category(self):
        """Test invalid category defaults to unknown."""
        raw_response = '{"risk_level": "low", "confidence": 0.5, "category": "invalid_cat", "explanation": "test"}'
        result = _normalize_response(raw_response)
        assert result["category"] == "unknown"
    
    def test_normalize_malformed_json(self):
        """Test malformed JSON returns fallback response."""
        raw_response = "not json at all"
        result = _normalize_response(raw_response)
        
        assert result["risk_level"] == "unknown"
        assert result["confidence"] == 0.0
        assert "parse" in result["explanation"].lower()
    
    def test_normalize_missing_fields(self):
        """Test missing fields use defaults."""
        raw_response = '{"risk_level": "medium"}'
        result = _normalize_response(raw_response)
        
        assert result["risk_level"] == "medium"
        assert result["confidence"] == 0.0
        assert result["category"] == "unknown"
        assert isinstance(result["explanation"], str)


class TestFallbackResponse:
    """Test fallback response creation."""
    
    def test_fallback_response_structure(self):
        """Test fallback response has correct structure."""
        result = _create_fallback_response("test reason")
        
        assert result["risk_level"] == "unknown"
        assert result["confidence"] == 0.0
        assert result["category"] == "unknown"
        assert result["explanation"] == "test reason"


# DISABLED: Analyse Text feature shelved - see docs/EPIC_12_DISABLED_TESTS.md for reactivation
@pytest.mark.skip(reason="Analyse Text feature shelved - Epic 12")
@pytest.mark.asyncio
class TestAnalyzeText:
    """Test analyze_text function with various scenarios."""
    
    async def test_analyze_empty_text(self):
        """Test analyzing empty text returns fallback."""
        result = await analyze_text("")
        
        assert result["risk_level"] == "unknown"
        assert "empty" in result["explanation"].lower()
    
    async def test_analyze_whitespace_text(self):
        """Test analyzing whitespace-only text returns fallback."""
        result = await analyze_text("   ")
        
        assert result["risk_level"] == "unknown"
        assert "empty" in result["explanation"].lower()
    
    @patch('app.services.openai_service.get_client')
    async def test_analyze_successful_response(self, mock_get_client):
        """Test successful text analysis with mocked OpenAI response."""
        # Clear cache for clean test
        clear_cache()
        
        # Mock OpenAI client and response
        mock_client = AsyncMock()
        mock_response = Mock()
        mock_response.choices = [Mock()]
        mock_response.choices[0].message.content = '''
        {
            "risk_level": "high",
            "confidence": 0.95,
            "category": "otp_phishing",
            "explanation": "Text requests OTP code"
        }
        '''
        
        mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
        mock_get_client.return_value = mock_client
        
        result = await analyze_text("Please send me your OTP code")
        
        assert result["risk_level"] == "high"
        assert result["confidence"] == 0.95
        assert result["category"] == "otp_phishing"
        assert "OTP" in result["explanation"]
    
    @patch('app.services.openai_service.get_client')
    async def test_analyze_medium_risk_response(self, mock_get_client):
        """Test medium risk text analysis."""
        clear_cache()
        
        mock_client = AsyncMock()
        mock_response = Mock()
        mock_response.choices = [Mock()]
        mock_response.choices[0].message.content = '''
        {
            "risk_level": "medium",
            "confidence": 0.6,
            "category": "payment_scam",
            "explanation": "Urgent payment request"
        }
        '''
        
        mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
        mock_get_client.return_value = mock_client
        
        result = await analyze_text("Please pay this invoice urgently")
        
        assert result["risk_level"] == "medium"
        assert result["category"] == "payment_scam"
    
    @patch('app.services.openai_service.get_client')
    async def test_analyze_low_risk_response(self, mock_get_client):
        """Test low risk benign text."""
        clear_cache()
        
        mock_client = AsyncMock()
        mock_response = Mock()
        mock_response.choices = [Mock()]
        mock_response.choices[0].message.content = '''
        {
            "risk_level": "low",
            "confidence": 0.9,
            "category": "unknown",
            "explanation": "Normal conversation"
        }
        '''
        
        mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
        mock_get_client.return_value = mock_client
        
        result = await analyze_text("Hello, how are you today?")
        
        assert result["risk_level"] == "low"
        assert result["category"] == "unknown"
    
    @patch('app.services.openai_service.get_client')
    async def test_analyze_timeout_error(self, mock_get_client):
        """Test timeout handling returns fallback."""
        clear_cache()
        
        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(
            side_effect=APITimeoutError(request=Mock())
        )
        mock_get_client.return_value = mock_client
        
        result = await analyze_text("test text")
        
        assert result["risk_level"] == "unknown"
        assert "timed out" in result["explanation"].lower()
    
    @patch('app.services.openai_service.get_client')
    async def test_analyze_rate_limit_error(self, mock_get_client):
        """Test rate limit error handling."""
        clear_cache()
        
        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(
            side_effect=RateLimitError(
                message="Rate limit exceeded",
                response=Mock(),
                body=None
            )
        )
        mock_get_client.return_value = mock_client
        
        result = await analyze_text("test text")
        
        assert result["risk_level"] == "unknown"
        assert "rate limit" in result["explanation"].lower()
    
    @patch('app.services.openai_service.get_client')
    async def test_analyze_authentication_error(self, mock_get_client):
        """Test authentication error handling."""
        clear_cache()
        
        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(
            side_effect=AuthenticationError(
                message="Invalid API key",
                response=Mock(),
                body=None
            )
        )
        mock_get_client.return_value = mock_client
        
        result = await analyze_text("test text")
        
        assert result["risk_level"] == "unknown"
        assert "auth" in result["explanation"].lower()
    
    @patch('app.services.openai_service.get_client')
    async def test_analyze_generic_openai_error(self, mock_get_client):
        """Test generic OpenAI error handling."""
        clear_cache()
        
        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(
            side_effect=OpenAIError("Generic error")
        )
        mock_get_client.return_value = mock_client
        
        result = await analyze_text("test text")
        
        assert result["risk_level"] == "unknown"
        assert "unavailable" in result["explanation"].lower()
    
    @patch('app.services.openai_service.get_client')
    async def test_analyze_empty_openai_response(self, mock_get_client):
        """Test handling of empty OpenAI response."""
        clear_cache()
        
        mock_client = AsyncMock()
        mock_response = Mock()
        mock_response.choices = [Mock()]
        mock_response.choices[0].message.content = None
        
        mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
        mock_get_client.return_value = mock_client
        
        result = await analyze_text("test text")
        
        assert result["risk_level"] == "unknown"
        assert "empty" in result["explanation"].lower()


class TestCaching:
    """Test response caching behavior."""
    
    @pytest.mark.asyncio
    @patch('app.services.openai_service.get_client')
    async def test_cache_stores_response(self, mock_get_client):
        """Test successful response is cached."""
        clear_cache()
        
        mock_client = AsyncMock()
        mock_response = Mock()
        mock_response.choices = [Mock()]
        mock_response.choices[0].message.content = '''
        {"risk_level": "high", "confidence": 0.9, "category": "otp_phishing", "explanation": "test"}
        '''
        
        mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
        mock_get_client.return_value = mock_client
        
        # First call - should hit API
        await analyze_text("test text for caching")
        assert mock_client.chat.completions.create.call_count == 1
        
        # Second call with same text - should use cache
        result = await analyze_text("test text for caching")
        assert mock_client.chat.completions.create.call_count == 1  # Still 1, not 2
        
        assert result["risk_level"] == "high"
    
    @patch('app.services.openai_service.get_client')
    async def test_cache_normalized_keys(self, mock_get_client):
        """Test cache uses normalized keys (case-insensitive)."""
        clear_cache()
        
        mock_client = AsyncMock()
        mock_response = Mock()
        mock_response.choices = [Mock()]
        mock_response.choices[0].message.content = '''
        {"risk_level": "low", "confidence": 0.1, "category": "unknown", "explanation": "test"}
        '''
        
        mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
        mock_get_client.return_value = mock_client
        
        # First call
        await analyze_text("Test Text")
        
        # Second call with different case - should use cache
        await analyze_text("test text")
        
        # Should only call API once
        assert mock_client.chat.completions.create.call_count == 1
    
    @pytest.mark.asyncio
    @patch('app.services.openai_service.get_client')
    async def test_cache_normalized_keys(self, mock_get_client):
        """Test cache uses normalized keys (case-insensitive)."""
        clear_cache()
        
        mock_client = AsyncMock()
        mock_response = Mock()
        mock_response.choices = [Mock()]
        mock_response.choices[0].message.content = '''
        {"risk_level": "low", "confidence": 0.1, "category": "unknown", "explanation": "test"}
        '''
        
        mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
        mock_get_client.return_value = mock_client
        
        # First call
        await analyze_text("Test Text")
        
        # Second call with different case - should use cache
        await analyze_text("test text")
        
        # Should only call API once
        assert mock_client.chat.completions.create.call_count == 1
    
    def test_cache_stats(self):
        """Test cache statistics reporting."""
        clear_cache()
        
        stats = get_cache_stats()
        assert stats["cache_size"] == 0
    
    def test_clear_cache_function(self):
        """Test cache clearing functionality."""
        clear_cache()
        
        # Cache starts empty
        assert get_cache_stats()["cache_size"] == 0
        
        # This is just testing the function exists and runs
        # Actual caching tested in integration tests above
        clear_cache()
        assert get_cache_stats()["cache_size"] == 0

