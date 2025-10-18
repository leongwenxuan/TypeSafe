"""
Tests for Gemini service with mocked API responses.
"""
import pytest
import asyncio
from unittest.mock import Mock, patch, MagicMock

from app.services import gemini_service
from app.services.gemini_service import (
    get_model,
    analyze_image,
    detect_mime_type,
    _normalize_response,
    _create_fallback_response,
    MAX_IMAGE_SIZE
)


# Sample image bytes for testing
PNG_HEADER = b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde'
JPEG_HEADER = b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00'


class TestGeminiModelInitialization:
    """Test Gemini model initialization."""
    
    @patch('app.services.gemini_service.settings')
    @patch('app.services.gemini_service.genai')
    def test_model_initialization_with_valid_key(self, mock_genai, mock_settings):
        """Test model initializes successfully with valid API key."""
        mock_settings.gemini_api_key = "test-gemini-key-123"
        
        # Reset global model
        gemini_service._model = None
        
        # Mock GenerativeModel
        mock_model = MagicMock()
        mock_genai.GenerativeModel.return_value = mock_model
        
        model = get_model()
        assert model is not None
        mock_genai.configure.assert_called_once_with(api_key="test-gemini-key-123")
    
    @patch('app.services.gemini_service.settings')
    def test_model_initialization_fails_without_key(self, mock_settings):
        """Test model initialization fails without API key."""
        mock_settings.gemini_api_key = ""
        
        # Reset global model
        gemini_service._model = None
        
        with pytest.raises(ValueError, match="GEMINI_API_KEY not configured"):
            get_model()


class TestResponseNormalization:
    """Test response parsing and normalization."""
    
    def test_normalize_valid_response(self):
        """Test normalizing a valid Gemini response."""
        raw_response = '''
        {
            "risk_level": "high",
            "confidence": 0.89,
            "category": "visual_scam",
            "explanation": "Fake banking interface requesting credentials"
        }
        '''
        result = _normalize_response(raw_response)
        
        assert result["risk_level"] == "high"
        assert result["confidence"] == 0.89
        assert result["category"] == "visual_scam"
        assert "Fake banking interface" in result["explanation"]
    
    def test_normalize_response_with_missing_fields(self):
        """Test normalization with missing fields uses defaults."""
        raw_response = '{"risk_level": "medium"}'
        result = _normalize_response(raw_response)
        
        assert result["risk_level"] == "medium"
        assert result["confidence"] == 0.0
        assert result["category"] == "unknown"
        assert result["explanation"] == "No explanation provided"
    
    def test_normalize_invalid_risk_level(self):
        """Test normalization with invalid risk_level defaults to unknown."""
        raw_response = '{"risk_level": "extreme", "confidence": 0.9}'
        result = _normalize_response(raw_response)
        
        assert result["risk_level"] == "unknown"
    
    def test_normalize_confidence_clamping(self):
        """Test confidence values are clamped to 0.0-1.0 range."""
        # Test upper bound
        raw_response = '{"risk_level": "high", "confidence": 1.5}'
        result = _normalize_response(raw_response)
        assert result["confidence"] == 1.0
        
        # Test lower bound
        raw_response = '{"risk_level": "low", "confidence": -0.5}'
        result = _normalize_response(raw_response)
        assert result["confidence"] == 0.0
    
    def test_normalize_invalid_category(self):
        """Test normalization with invalid category defaults to unknown."""
        raw_response = '{"risk_level": "high", "category": "invalid_category"}'
        result = _normalize_response(raw_response)
        
        assert result["category"] == "unknown"
    
    def test_normalize_malformed_json(self):
        """Test normalization with malformed JSON returns fallback."""
        raw_response = 'not valid json{'
        result = _normalize_response(raw_response)
        
        assert result["risk_level"] == "unknown"
        assert result["confidence"] == 0.0
        assert "Failed to parse" in result["explanation"]
    
    def test_normalize_visual_scam_category(self):
        """Test new visual_scam category is accepted."""
        raw_response = '''
        {
            "risk_level": "high",
            "confidence": 0.85,
            "category": "visual_scam",
            "explanation": "Fake UI elements detected"
        }
        '''
        result = _normalize_response(raw_response)
        
        assert result["category"] == "visual_scam"


class TestImageFormatDetection:
    """Test image format detection."""
    
    def test_detect_png_format(self):
        """Test PNG format detection."""
        mime_type = detect_mime_type(PNG_HEADER)
        assert mime_type == "image/png"
    
    def test_detect_jpeg_format(self):
        """Test JPEG format detection."""
        mime_type = detect_mime_type(JPEG_HEADER)
        assert mime_type == "image/jpeg"
    
    def test_detect_unsupported_format(self):
        """Test unsupported format raises ValueError."""
        # GIF header
        gif_header = b'GIF89a'
        
        with pytest.raises(ValueError, match="Unsupported image format"):
            detect_mime_type(gif_header)
    
    def test_detect_invalid_image_data(self):
        """Test invalid image data raises ValueError."""
        invalid_data = b'not an image'
        
        with pytest.raises(ValueError, match="Unsupported image format"):
            detect_mime_type(invalid_data)


class TestFallbackResponse:
    """Test fallback response creation."""
    
    def test_fallback_response_structure(self):
        """Test fallback response has correct structure."""
        result = _create_fallback_response("Test reason")
        
        assert result["risk_level"] == "unknown"
        assert result["confidence"] == 0.0
        assert result["category"] == "unknown"
        assert result["explanation"] == "Test reason"


@pytest.mark.asyncio
class TestAnalyzeImage:
    """Test image analysis function."""
    
    @patch('app.services.gemini_service.get_model')
    async def test_analyze_image_success(self, mock_get_model):
        """Test successful image analysis."""
        # Mock Gemini response
        mock_response = Mock()
        mock_response.text = '''
        {
            "risk_level": "high",
            "confidence": 0.92,
            "category": "otp_phishing",
            "explanation": "Screenshot shows OTP request"
        }
        '''
        
        mock_model = Mock()
        mock_model.generate_content = Mock(return_value=mock_response)
        mock_get_model.return_value = mock_model
        
        result = await analyze_image(PNG_HEADER, "Enter your OTP code")
        
        assert result["risk_level"] == "high"
        assert result["confidence"] == 0.92
        assert result["category"] == "otp_phishing"
        assert "OTP request" in result["explanation"]
    
    @patch('app.services.gemini_service.get_model')
    async def test_analyze_image_with_no_ocr(self, mock_get_model):
        """Test image analysis without OCR text."""
        mock_response = Mock()
        mock_response.text = '''
        {
            "risk_level": "medium",
            "confidence": 0.65,
            "category": "visual_scam",
            "explanation": "Suspicious UI elements"
        }
        '''
        
        mock_model = Mock()
        mock_model.generate_content = Mock(return_value=mock_response)
        mock_get_model.return_value = mock_model
        
        result = await analyze_image(PNG_HEADER)
        
        assert result["risk_level"] == "medium"
        assert result["category"] == "visual_scam"
    
    async def test_analyze_empty_image(self):
        """Test analysis with empty image data returns fallback."""
        result = await analyze_image(b"")
        
        assert result["risk_level"] == "unknown"
        assert "Empty image" in result["explanation"]
    
    async def test_analyze_oversized_image(self):
        """Test analysis with oversized image returns error."""
        # Create image larger than MAX_IMAGE_SIZE
        large_image = PNG_HEADER + b'x' * (MAX_IMAGE_SIZE + 1)
        
        result = await analyze_image(large_image)
        
        assert result["risk_level"] == "unknown"
        assert "too large" in result["explanation"]
    
    async def test_analyze_unsupported_format(self):
        """Test analysis with unsupported format returns error."""
        # GIF format
        gif_header = b'GIF89a'
        
        result = await analyze_image(gif_header)
        
        assert result["risk_level"] == "unknown"
        assert "Unsupported image format" in result["explanation"]
    
    @patch('app.services.gemini_service.get_model')
    async def test_analyze_image_timeout(self, mock_get_model):
        """Test analysis timeout handling."""
        mock_model = Mock()
        
        # Mock generate_content to simulate slow response
        async def slow_generate():
            await asyncio.sleep(2)  # Longer than 1.5s timeout
            return Mock()
        
        mock_model.generate_content = Mock()
        mock_get_model.return_value = mock_model
        
        # Mock asyncio.to_thread to raise TimeoutError
        with patch('asyncio.to_thread', side_effect=asyncio.TimeoutError):
            result = await analyze_image(PNG_HEADER, "test")
            
            assert result["risk_level"] == "unknown"
            assert "timed out" in result["explanation"]
    
    @patch('app.services.gemini_service.get_model')
    async def test_analyze_image_rate_limit_error(self, mock_get_model):
        """Test rate limit error handling."""
        mock_model = Mock()
        mock_model.generate_content = Mock(side_effect=Exception("429 rate limit"))
        mock_get_model.return_value = mock_model
        
        result = await analyze_image(PNG_HEADER, "test")
        
        assert result["risk_level"] == "unknown"
        assert "rate limit" in result["explanation"]
    
    @patch('app.services.gemini_service.get_model')
    async def test_analyze_image_auth_error(self, mock_get_model):
        """Test authentication error handling."""
        mock_model = Mock()
        mock_model.generate_content = Mock(side_effect=Exception("401 authentication failed"))
        mock_get_model.return_value = mock_model
        
        result = await analyze_image(PNG_HEADER, "test")
        
        assert result["risk_level"] == "unknown"
        assert "auth error" in result["explanation"]
    
    @patch('app.services.gemini_service.get_model')
    async def test_analyze_image_server_error(self, mock_get_model):
        """Test server error handling."""
        mock_model = Mock()
        mock_model.generate_content = Mock(side_effect=Exception("500 server error"))
        mock_get_model.return_value = mock_model
        
        result = await analyze_image(PNG_HEADER, "test")
        
        assert result["risk_level"] == "unknown"
        assert "server error" in result["explanation"]
    
    @patch('app.services.gemini_service.get_model')
    async def test_analyze_image_empty_response(self, mock_get_model):
        """Test handling of empty API response."""
        mock_response = Mock()
        mock_response.text = None
        
        mock_model = Mock()
        mock_model.generate_content = Mock(return_value=mock_response)
        mock_get_model.return_value = mock_model
        
        result = await analyze_image(PNG_HEADER, "test")
        
        assert result["risk_level"] == "unknown"
        assert "empty response" in result["explanation"]
    
    @patch('app.services.gemini_service.get_model')
    async def test_analyze_image_malformed_response(self, mock_get_model):
        """Test handling of malformed JSON response."""
        mock_response = Mock()
        mock_response.text = "not valid json"
        
        mock_model = Mock()
        mock_model.generate_content = Mock(return_value=mock_response)
        mock_get_model.return_value = mock_model
        
        result = await analyze_image(PNG_HEADER, "test")
        
        assert result["risk_level"] == "unknown"
        assert "Failed to parse" in result["explanation"]
    
    @patch('app.services.gemini_service.get_model')
    async def test_analyze_image_with_mime_type(self, mock_get_model):
        """Test image analysis with explicit MIME type."""
        mock_response = Mock()
        mock_response.text = '''
        {
            "risk_level": "low",
            "confidence": 0.1,
            "category": "unknown",
            "explanation": "Benign screenshot"
        }
        '''
        
        mock_model = Mock()
        mock_model.generate_content = Mock(return_value=mock_response)
        mock_get_model.return_value = mock_model
        
        result = await analyze_image(JPEG_HEADER, "normal text", mime_type="image/jpeg")
        
        assert result["risk_level"] == "low"
    
    @patch('app.services.gemini_service.get_model')
    async def test_analyze_image_multimodal_content(self, mock_get_model):
        """Test that multimodal content is properly constructed."""
        mock_response = Mock()
        mock_response.text = '''
        {
            "risk_level": "medium",
            "confidence": 0.7,
            "category": "impersonation",
            "explanation": "Possible fake authority message"
        }
        '''
        
        mock_model = Mock()
        mock_model.generate_content = Mock(return_value=mock_response)
        mock_get_model.return_value = mock_model
        
        ocr_text = "This is from your bank manager"
        result = await analyze_image(PNG_HEADER, ocr_text)
        
        # Verify generate_content was called
        assert mock_model.generate_content.called
        
        # Verify call included prompt, image, and OCR text
        call_args = mock_model.generate_content.call_args[0][0]
        assert len(call_args) == 3  # prompt, image, ocr text
        assert isinstance(call_args[1], dict)  # image dict
        assert 'mime_type' in call_args[1]
        assert 'data' in call_args[1]
        assert ocr_text in call_args[2]
        
        assert result["risk_level"] == "medium"


@pytest.mark.asyncio
class TestAnalyzeImageCoverage:
    """Additional tests for edge cases and coverage."""
    
    @patch('app.services.gemini_service.get_model')
    async def test_analyze_image_high_confidence_scam(self, mock_get_model):
        """Test high-confidence scam detection."""
        mock_response = Mock()
        mock_response.text = '''
        {
            "risk_level": "high",
            "confidence": 0.98,
            "category": "payment_scam",
            "explanation": "Clear payment scam indicators"
        }
        '''
        
        mock_model = Mock()
        mock_model.generate_content = Mock(return_value=mock_response)
        mock_get_model.return_value = mock_model
        
        result = await analyze_image(PNG_HEADER, "Send $500 urgently")
        
        assert result["risk_level"] == "high"
        assert result["confidence"] == 0.98
        assert result["category"] == "payment_scam"
    
    @patch('app.services.gemini_service.get_model')
    async def test_analyze_image_benign_content(self, mock_get_model):
        """Test benign content detection."""
        mock_response = Mock()
        mock_response.text = '''
        {
            "risk_level": "low",
            "confidence": 0.05,
            "category": "unknown",
            "explanation": "Normal conversation screenshot"
        }
        '''
        
        mock_model = Mock()
        mock_model.generate_content = Mock(return_value=mock_response)
        mock_get_model.return_value = mock_model
        
        result = await analyze_image(PNG_HEADER, "See you tomorrow!")
        
        assert result["risk_level"] == "low"
        assert result["confidence"] == 0.05
    
    async def test_analyze_image_whitespace_only_ocr(self):
        """Test handling of whitespace-only OCR text."""
        # This should be treated as empty OCR
        with patch('app.services.gemini_service.get_model') as mock_get_model:
            mock_response = Mock()
            mock_response.text = '{"risk_level": "low", "confidence": 0.1, "category": "unknown", "explanation": "test"}'
            
            mock_model = Mock()
            mock_model.generate_content = Mock(return_value=mock_response)
            mock_get_model.return_value = mock_model
            
            result = await analyze_image(PNG_HEADER, "   \n\t  ")
            
            # Verify only 2 parts (prompt + image, no OCR text added)
            call_args = mock_model.generate_content.call_args[0][0]
            assert len(call_args) == 2
    
    @patch('app.services.gemini_service.get_model')
    async def test_analyze_unexpected_exception(self, mock_get_model):
        """Test handling of unexpected exceptions."""
        mock_model = Mock()
        mock_model.generate_content = Mock(side_effect=RuntimeError("Unexpected error"))
        mock_get_model.return_value = mock_model
        
        result = await analyze_image(PNG_HEADER, "test")
        
        assert result["risk_level"] == "unknown"
        assert "failed unexpectedly" in result["explanation"]

