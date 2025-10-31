"""
Unit tests for risk aggregation and normalization.
"""
import pytest
from datetime import datetime, timezone
from unittest.mock import AsyncMock, patch, MagicMock

from app.services import risk_aggregator


class TestConfidenceNormalization:
    """Test confidence score normalization."""
    
    def test_valid_confidence_scores(self):
        """Test that valid confidence scores pass through."""
        assert risk_aggregator.normalize_confidence(0.0) == 0.0
        assert risk_aggregator.normalize_confidence(0.5) == 0.5
        assert risk_aggregator.normalize_confidence(1.0) == 1.0
    
    def test_negative_confidence_clamped(self):
        """Test that negative confidence scores are clamped to 0.0."""
        assert risk_aggregator.normalize_confidence(-0.5) == 0.0
        assert risk_aggregator.normalize_confidence(-1.0) == 0.0
        assert risk_aggregator.normalize_confidence(-999.9) == 0.0
    
    def test_high_confidence_clamped(self):
        """Test that confidence scores > 1.0 are clamped to 1.0."""
        assert risk_aggregator.normalize_confidence(1.5) == 1.0
        assert risk_aggregator.normalize_confidence(2.0) == 1.0
        assert risk_aggregator.normalize_confidence(999.9) == 1.0
    
    def test_none_confidence_defaults_to_zero(self):
        """Test that None confidence defaults to 0.0."""
        assert risk_aggregator.normalize_confidence(None) == 0.0


class TestCategoryValidation:
    """Test category validation and mapping."""
    
    def test_valid_categories_pass_through(self):
        """Test that valid categories are preserved."""
        assert risk_aggregator.validate_category("otp_phishing") == "otp_phishing"
        assert risk_aggregator.validate_category("payment_scam") == "payment_scam"
        assert risk_aggregator.validate_category("impersonation") == "impersonation"
        assert risk_aggregator.validate_category("visual_scam") == "visual_scam"
        assert risk_aggregator.validate_category("unknown") == "unknown"
    
    def test_case_insensitive_categories(self):
        """Test that categories are case-insensitive."""
        assert risk_aggregator.validate_category("OTP_PHISHING") == "otp_phishing"
        assert risk_aggregator.validate_category("Payment_Scam") == "payment_scam"
        assert risk_aggregator.validate_category("UNKNOWN") == "unknown"
    
    def test_invalid_categories_map_to_unknown(self):
        """Test that invalid categories map to 'unknown'."""
        assert risk_aggregator.validate_category("invalid") == "unknown"
        assert risk_aggregator.validate_category("malware") == "unknown"
        assert risk_aggregator.validate_category("spam") == "unknown"
        assert risk_aggregator.validate_category("") == "unknown"
    
    def test_none_category_maps_to_unknown(self):
        """Test that None category maps to 'unknown'."""
        assert risk_aggregator.validate_category(None) == "unknown"


class TestExplanationFormatting:
    """Test explanation text formatting."""
    
    def test_normal_explanation_preserved(self):
        """Test that normal explanations are preserved."""
        explanation = "Request for OTP code detected"
        assert risk_aggregator.format_explanation(explanation) == explanation
    
    def test_long_explanation_truncated(self):
        """Test that long explanations are truncated to 100 chars."""
        long_explanation = "A" * 150
        formatted = risk_aggregator.format_explanation(long_explanation)
        assert len(formatted) == 100
        assert formatted.endswith("...")
        assert formatted == "A" * 97 + "..."
    
    def test_whitespace_normalized(self):
        """Test that extra whitespace and newlines are removed."""
        messy = "Text   with\n\nmultiple\t\tspaces"
        formatted = risk_aggregator.format_explanation(messy)
        assert formatted == "Text with multiple spaces"
    
    def test_empty_explanation_uses_fallback(self):
        """Test that empty/None explanations use fallback."""
        assert risk_aggregator.format_explanation("") == "Analysis result"
        assert risk_aggregator.format_explanation(None) == "Analysis result"
        assert risk_aggregator.format_explanation("   ") == "Analysis result"


class TestTimestampGeneration:
    """Test ISO 8601 timestamp generation."""
    
    def test_timestamp_format(self):
        """Test that timestamp is in ISO 8601 format with timezone."""
        ts = risk_aggregator.generate_timestamp()
        
        # Should be parseable as ISO 8601
        parsed = datetime.fromisoformat(ts)
        assert parsed.tzinfo is not None  # Has timezone
        
        # Should contain 'T' and timezone indicator
        assert 'T' in ts
        assert ts.endswith('+00:00') or ts.endswith('Z') or '+' in ts or '-' in ts[-6:]
    
    def test_timestamp_is_utc(self):
        """Test that timestamp is in UTC."""
        ts = risk_aggregator.generate_timestamp()
        parsed = datetime.fromisoformat(ts)
        
        # Convert to UTC and verify
        utc_time = parsed.astimezone(timezone.utc)
        assert utc_time.tzinfo == timezone.utc


class TestResponseNormalization:
    """Test provider response normalization."""
    
    def test_normalize_complete_response(self):
        """Test normalization of complete provider response."""
        response = {
            "risk_level": "high",
            "confidence": 0.95,
            "category": "otp_phishing",
            "explanation": "Request for OTP detected"
        }
        
        normalized = risk_aggregator.normalize_response(response, provider="test")
        
        assert normalized["risk_level"] == "high"
        assert normalized["confidence"] == 0.95
        assert normalized["category"] == "otp_phishing"
        assert normalized["explanation"] == "Request for OTP detected"
        assert "ts" in normalized
        assert isinstance(normalized["ts"], str)
    
    def test_normalize_clamps_confidence(self):
        """Test that normalization clamps confidence scores."""
        response = {
            "risk_level": "medium",
            "confidence": 1.5,  # Invalid
            "category": "payment_scam",
            "explanation": "Test"
        }
        
        normalized = risk_aggregator.normalize_response(response)
        assert normalized["confidence"] == 1.0  # Clamped
    
    def test_normalize_invalid_category(self):
        """Test that normalization fixes invalid categories."""
        response = {
            "risk_level": "low",
            "confidence": 0.3,
            "category": "invalid_category",
            "explanation": "Test"
        }
        
        normalized = risk_aggregator.normalize_response(response)
        assert normalized["category"] == "unknown"
    
    def test_normalize_missing_fields_uses_defaults(self):
        """Test that missing fields use safe defaults."""
        response = {}
        
        normalized = risk_aggregator.normalize_response(response)
        
        assert normalized["risk_level"] == "unknown"
        assert normalized["confidence"] == 0.0
        assert normalized["category"] == "unknown"
        assert normalized["explanation"] == "Analysis result"
        assert "ts" in normalized


class TestResultAggregation:
    """Test multi-provider result aggregation."""
    
    def test_single_result_returns_unchanged(self):
        """Test that single result is returned as-is."""
        result = {
            "risk_level": "high",
            "confidence": 0.9,
            "category": "otp_phishing",
            "explanation": "Test",
            "ts": "2025-01-18T00:00:00Z"
        }
        
        aggregated = risk_aggregator.aggregate_results([result])
        assert aggregated == result
    
    def test_empty_results_returns_fallback(self):
        """Test that empty results list returns fallback."""
        aggregated = risk_aggregator.aggregate_results([])
        
        assert aggregated["risk_level"] == "unknown"
        assert aggregated["confidence"] == 0.0
        assert aggregated["category"] == "unknown"
        assert "ts" in aggregated
    
    def test_aggregates_same_risk_level(self):
        """Test aggregation when both providers agree on risk level."""
        results = [
            {
                "risk_level": "high",
                "confidence": 0.9,
                "category": "otp_phishing",
                "explanation": "OTP request",
                "ts": "2025-01-18T00:00:00Z"
            },
            {
                "risk_level": "high",
                "confidence": 0.85,
                "category": "otp_phishing",
                "explanation": "2FA code requested",
                "ts": "2025-01-18T00:01:00Z"
            }
        ]
        
        aggregated = risk_aggregator.aggregate_results(results)
        
        assert aggregated["risk_level"] == "high"
        assert aggregated["confidence"] == 0.875  # Average
        assert aggregated["category"] == "otp_phishing"
        assert "OTP request" in aggregated["explanation"]
    
    def test_prioritizes_higher_risk_level(self):
        """Test that higher risk level wins in aggregation."""
        results = [
            {
                "risk_level": "low",
                "confidence": 0.3,
                "category": "unknown",
                "explanation": "Low risk",
                "ts": "2025-01-18T00:00:00Z"
            },
            {
                "risk_level": "high",
                "confidence": 0.9,
                "category": "payment_scam",
                "explanation": "Payment request",
                "ts": "2025-01-18T00:01:00Z"
            }
        ]
        
        aggregated = risk_aggregator.aggregate_results(results)
        
        assert aggregated["risk_level"] == "high"
        assert aggregated["confidence"] == 0.6  # Average of 0.3 and 0.9
    
    def test_prioritizes_specific_category(self):
        """Test that more specific category wins over 'unknown'."""
        results = [
            {
                "risk_level": "medium",
                "confidence": 0.5,
                "category": "unknown",
                "explanation": "Unclear",
                "ts": "2025-01-18T00:00:00Z"
            },
            {
                "risk_level": "medium",
                "confidence": 0.7,
                "category": "payment_scam",
                "explanation": "Money request",
                "ts": "2025-01-18T00:01:00Z"
            }
        ]
        
        aggregated = risk_aggregator.aggregate_results(results)
        
        assert aggregated["category"] == "payment_scam"
    
    def test_uses_most_recent_timestamp(self):
        """Test that most recent timestamp is used."""
        results = [
            {
                "risk_level": "low",
                "confidence": 0.3,
                "category": "unknown",
                "explanation": "Test 1",
                "ts": "2025-01-18T00:00:00Z"
            },
            {
                "risk_level": "medium",
                "confidence": 0.6,
                "category": "unknown",
                "explanation": "Test 2",
                "ts": "2025-01-18T00:05:00Z"  # Later timestamp
            }
        ]
        
        aggregated = risk_aggregator.aggregate_results(results)
        
        assert aggregated["ts"] == "2025-01-18T00:05:00Z"
    
    def test_concatenates_explanations(self):
        """Test that explanations are concatenated."""
        results = [
            {
                "risk_level": "high",
                "confidence": 0.9,
                "category": "otp_phishing",
                "explanation": "OTP request detected",
                "ts": "2025-01-18T00:00:00Z"
            },
            {
                "risk_level": "high",
                "confidence": 0.85,
                "category": "otp_phishing",
                "explanation": "2FA code requested",
                "ts": "2025-01-18T00:01:00Z"
            }
        ]
        
        aggregated = risk_aggregator.aggregate_results(results)
        
        explanation = aggregated["explanation"]
        assert "OTP request detected" in explanation or "2FA code requested" in explanation
        assert ";" in explanation  # Concatenated with separator


class TestFallbackResponse:
    """Test fallback response creation."""
    
    def test_fallback_has_required_fields(self):
        """Test that fallback response has all required fields."""
        fallback = risk_aggregator.create_fallback_response("Test error")
        
        assert fallback["risk_level"] == "unknown"
        assert fallback["confidence"] == 0.0
        assert fallback["category"] == "unknown"
        assert fallback["explanation"] == "Analysis unavailable"
        assert "ts" in fallback
    
    def test_fallback_logs_context(self, caplog):
        """Test that fallback logs error context."""
        with caplog.at_level("WARNING"):
            risk_aggregator.create_fallback_response("Test error context")
        
        assert "Test error context" in caplog.text


class TestTextAnalysisAggregation:
    """Test text analysis convenience function."""
    
    @pytest.mark.asyncio
    async def test_successful_text_analysis(self):
        """Test successful text analysis with OpenAI."""
        mock_response = {
            "risk_level": "high",
            "confidence": 0.95,
            "category": "otp_phishing",
            "explanation": "OTP request detected"
        }
        
        with patch('app.services.openai_service.analyze_text', new_callable=AsyncMock) as mock_analyze:
            mock_analyze.return_value = mock_response
            
            result = await risk_aggregator.analyze_text_aggregated("Send me your OTP")
            
            assert result["risk_level"] == "high"
            assert result["confidence"] == 0.95
            assert result["category"] == "otp_phishing"
            assert "OTP request detected" in result["explanation"]
            assert "ts" in result
            
            mock_analyze.assert_called_once_with("Send me your OTP")
    
    @pytest.mark.asyncio
    async def test_text_analysis_error_returns_fallback(self):
        """Test that text analysis errors return fallback response."""
        with patch('app.services.openai_service.analyze_text', new_callable=AsyncMock) as mock_analyze:
            mock_analyze.side_effect = Exception("OpenAI API error")
            
            result = await risk_aggregator.analyze_text_aggregated("Test text")
            
            assert result["risk_level"] == "unknown"
            assert result["confidence"] == 0.0
            assert result["category"] == "unknown"
            assert "ts" in result


class TestImageAnalysisAggregation:
    """Test image analysis convenience function."""
    
    @pytest.mark.asyncio
    async def test_successful_image_analysis(self):
        """Test successful image analysis with Gemini."""
        mock_response = {
            "risk_level": "high",
            "confidence": 0.9,
            "category": "visual_scam",
            "explanation": "Fake payment UI detected"
        }
        
        fake_image = b"fake_image_data"
        
        with patch('app.services.gemini_service.analyze_image', new_callable=AsyncMock) as mock_analyze:
            mock_analyze.return_value = mock_response
            
            result = await risk_aggregator.analyze_image_aggregated(
                image_data=fake_image,
                ocr_text="Pay now",
                mime_type="image/png"
            )
            
            assert result["risk_level"] == "high"
            assert result["confidence"] == 0.9
            assert result["category"] == "visual_scam"
            assert "Fake payment UI detected" in result["explanation"]
            assert "ts" in result
            
            mock_analyze.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_image_analysis_error_returns_fallback(self):
        """Test that image analysis errors return fallback response."""
        fake_image = b"fake_image_data"
        
        with patch('app.services.gemini_service.analyze_image', new_callable=AsyncMock) as mock_analyze:
            mock_analyze.side_effect = Exception("Gemini API error")
            
            result = await risk_aggregator.analyze_image_aggregated(
                image_data=fake_image,
                ocr_text="Test",
                mime_type="image/png"
            )
            
            assert result["risk_level"] == "unknown"
            assert result["confidence"] == 0.0
            assert result["category"] == "unknown"
            assert "ts" in result


class TestMultimodalAggregation:
    """Test multimodal analysis with multiple providers."""
    
    @pytest.mark.asyncio
    async def test_multimodal_with_gemini_only(self):
        """Test multimodal analysis using Gemini only."""
        mock_gemini = {
            "risk_level": "high",
            "confidence": 0.9,
            "category": "visual_scam",
            "explanation": "Fake UI detected",
            "ts": "2025-01-18T00:00:00Z"
        }
        
        fake_image = b"fake_image_data"
        
        with patch('app.services.risk_aggregator.analyze_image_aggregated', new_callable=AsyncMock) as mock_img:
            mock_img.return_value = mock_gemini
            
            result = await risk_aggregator.analyze_multimodal_aggregated(
                image_data=fake_image,
                ocr_text="Pay now",
                use_fallback=False  # Don't use OpenAI fallback
            )
            
            assert result["risk_level"] == "high"
            assert result["category"] == "visual_scam"
    
    @pytest.mark.asyncio
    async def test_multimodal_with_gemini_and_openai_fallback(self):
        """Test multimodal analysis using both Gemini and OpenAI."""
        mock_gemini = {
            "risk_level": "high",
            "confidence": 0.9,
            "category": "visual_scam",
            "explanation": "Fake UI",
            "ts": "2025-01-18T00:00:00Z"
        }
        
        mock_openai = {
            "risk_level": "medium",
            "confidence": 0.7,
            "category": "payment_scam",
            "explanation": "Payment request",
            "ts": "2025-01-18T00:01:00Z"
        }
        
        fake_image = b"fake_image_data"
        
        with patch('app.services.risk_aggregator.analyze_image_aggregated', new_callable=AsyncMock) as mock_img, \
             patch('app.services.risk_aggregator.analyze_text_aggregated', new_callable=AsyncMock) as mock_txt:
            
            mock_img.return_value = mock_gemini
            mock_txt.return_value = mock_openai
            
            result = await risk_aggregator.analyze_multimodal_aggregated(
                image_data=fake_image,
                ocr_text="Pay $500 now",
                use_fallback=True  # Use OpenAI fallback
            )
            
            # Should aggregate both results
            assert result["risk_level"] == "high"  # Gemini's higher risk
            assert result["confidence"] == 0.8  # Average of 0.9 and 0.7
    
    @pytest.mark.asyncio
    async def test_multimodal_all_providers_fail(self):
        """Test multimodal when all providers fail."""
        fake_image = b"fake_image_data"
        
        with patch('app.services.risk_aggregator.analyze_image_aggregated', new_callable=AsyncMock) as mock_img, \
             patch('app.services.risk_aggregator.analyze_text_aggregated', new_callable=AsyncMock) as mock_txt:
            
            mock_img.side_effect = Exception("Gemini failed")
            mock_txt.side_effect = Exception("OpenAI failed")
            
            result = await risk_aggregator.analyze_multimodal_aggregated(
                image_data=fake_image,
                ocr_text="Test",
                use_fallback=True
            )
            
            assert result["risk_level"] == "unknown"
            assert result["confidence"] == 0.0
            assert result["explanation"] == "Analysis unavailable"
    
    @pytest.mark.asyncio
    async def test_multimodal_no_ocr_text_skips_openai(self):
        """Test that OpenAI fallback is skipped when no OCR text."""
        mock_gemini = {
            "risk_level": "medium",
            "confidence": 0.6,
            "category": "visual_scam",
            "explanation": "Suspicious UI",
            "ts": "2025-01-18T00:00:00Z"
        }
        
        fake_image = b"fake_image_data"
        
        with patch('app.services.risk_aggregator.analyze_image_aggregated', new_callable=AsyncMock) as mock_img, \
             patch('app.services.risk_aggregator.analyze_text_aggregated', new_callable=AsyncMock) as mock_txt:
            
            mock_img.return_value = mock_gemini
            
            result = await risk_aggregator.analyze_multimodal_aggregated(
                image_data=fake_image,
                ocr_text="",  # No text
                use_fallback=True
            )
            
            # Only Gemini should be called
            mock_img.assert_called_once()
            mock_txt.assert_not_called()
            
            assert result == mock_gemini

