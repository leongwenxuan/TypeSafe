"""
Tests for prompt templates.
"""
import pytest

from app.services.prompts import SCAM_DETECTION_SYSTEM_PROMPT


class TestPrompts:
    """Test suite for prompt templates."""
    
    def test_scam_detection_prompt_exists(self):
        """Test scam detection prompt is defined."""
        assert SCAM_DETECTION_SYSTEM_PROMPT is not None
        assert isinstance(SCAM_DETECTION_SYSTEM_PROMPT, str)
        assert len(SCAM_DETECTION_SYSTEM_PROMPT) > 0
    
    def test_prompt_contains_risk_levels(self):
        """Test prompt mentions all risk levels."""
        prompt = SCAM_DETECTION_SYSTEM_PROMPT
        
        assert "high" in prompt.lower()
        assert "medium" in prompt.lower()
        assert "low" in prompt.lower()
    
    def test_prompt_contains_categories(self):
        """Test prompt mentions all scam categories."""
        prompt = SCAM_DETECTION_SYSTEM_PROMPT
        
        assert "otp_phishing" in prompt.lower() or "otp" in prompt.lower()
        assert "payment_scam" in prompt.lower() or "payment" in prompt.lower()
        assert "impersonation" in prompt.lower()
        assert "unknown" in prompt.lower()
    
    def test_prompt_specifies_json_format(self):
        """Test prompt requests JSON output format."""
        prompt = SCAM_DETECTION_SYSTEM_PROMPT
        
        assert "json" in prompt.lower()
        assert "risk_level" in prompt.lower()
        assert "confidence" in prompt.lower()
        assert "category" in prompt.lower()
        assert "explanation" in prompt.lower()
    
    def test_prompt_mentions_scam_types(self):
        """Test prompt describes specific scam types."""
        prompt = SCAM_DETECTION_SYSTEM_PROMPT.lower()
        
        # Should mention OTP/verification codes
        assert "otp" in prompt or "verification" in prompt or "2fa" in prompt
        
        # Should mention payment scams
        assert "payment" in prompt or "invoice" in prompt
        
        # Should mention impersonation
        assert "impersonation" in prompt or "identity" in prompt

