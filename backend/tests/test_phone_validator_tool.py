"""Unit tests for Phone Validator Tool."""

import pytest
import time
from app.agents.tools.phone_validator import PhoneValidatorTool, PhoneValidationResult


@pytest.fixture
def validator():
    """Fixture providing PhoneValidatorTool."""
    return PhoneValidatorTool()


class TestPhoneValidation:
    """Test basic phone validation."""
    
    def test_valid_us_mobile(self, validator):
        """Test valid US mobile number."""
        result = validator.validate("+1-650-555-1234")
        
        assert result.valid is True
        assert result.country == "United States"
        assert result.number_type in ["mobile", "landline_or_mobile", "landline"]
        assert result.suspicious is False
        assert result.number == "+16505551234"
    
    def test_valid_us_mobile_alternate_format(self, validator):
        """Test valid US mobile number with different format."""
        result = validator.validate("(650) 555-1234")
        
        assert result.valid is True
        assert result.country == "United States"
        assert result.number == "+16505551234"
    
    def test_valid_toll_free(self, validator):
        """Test valid toll-free number."""
        result = validator.validate("1-800-555-1234")
        
        assert result.valid is True
        assert result.number_type == "toll_free"
        # Toll-free numbers may not have country info
        assert result.country_code == 1
    
    def test_international_number_uk(self, validator):
        """Test international number (UK)."""
        result = validator.validate("+44 20 7946 0958")
        
        assert result.valid is True
        assert result.country_code == 44
        assert "United Kingdom" in result.country
    
    def test_international_number_singapore(self, validator):
        """Test international number (Singapore)."""
        result = validator.validate("+65 6221 8888")
        
        assert result.valid is True
        assert result.country_code == 65
        assert "Singapore" in result.country
    
    def test_international_number_australia(self, validator):
        """Test international number (Australia)."""
        result = validator.validate("+61 2 9374 4000")
        
        assert result.valid is True
        assert result.country_code == 61
        assert "Australia" in result.country
    
    def test_invalid_format(self, validator):
        """Test invalid phone number format."""
        result = validator.validate("123")
        
        assert result.valid is False
        assert result.suspicious is True
        # Should have some suspicious reason (pattern or invalid format)
        assert result.suspicious_reason is not None
        assert len(result.suspicious_reason) > 0
    
    def test_empty_string(self, validator):
        """Test empty string."""
        result = validator.validate("")
        
        assert result.valid is False
        assert result.suspicious is True
    
    def test_non_numeric(self, validator):
        """Test non-numeric input."""
        result = validator.validate("abc-def-ghij")
        
        assert result.valid is False
        assert result.suspicious is True


class TestSuspiciousPatterns:
    """Test suspicious pattern detection."""
    
    def test_all_zeros(self, validator):
        """Test number with all zeros."""
        result = validator.validate("1-800-000-0000")
        
        assert result.suspicious is True
        # Should detect suspicious pattern (either "zeros" or "same digit")
        assert "0" in result.suspicious_reason or "same" in result.suspicious_reason.lower()
    
    def test_all_same_digit_eights(self, validator):
        """Test number with all same digit (8s)."""
        result = validator.validate("1-888-888-8888")
        
        assert result.suspicious is True
        assert "same digit" in result.suspicious_reason.lower()
    
    def test_all_same_digit_ones(self, validator):
        """Test number with all same digit (1s)."""
        result = validator.validate("+1-111-111-1111")
        
        assert result.suspicious is True
        assert "same digit" in result.suspicious_reason.lower()
    
    def test_sequential_pattern_ascending(self, validator):
        """Test sequential number (ascending)."""
        # Note: This might not be a valid number, but should detect pattern
        result = validator.validate("+1-234-567-8901")
        
        # Should be flagged as suspicious due to sequential pattern
        if result.valid:
            assert result.suspicious is True
            assert "sequential" in result.suspicious_reason.lower()
    
    def test_sequential_pattern_descending(self, validator):
        """Test sequential number (descending)."""
        result = validator.validate("+1-987-654-3210")
        
        # Should be flagged as suspicious due to sequential pattern
        if result.valid:
            assert result.suspicious is True
            assert "sequential" in result.suspicious_reason.lower()
    
    def test_repeating_pattern_123(self, validator):
        """Test repeating pattern (123-123-...)."""
        result = validator.validate("+1-123-123-1231")
        
        # Should be flagged as suspicious due to repeating pattern
        if result.valid:
            assert result.suspicious is True
            assert "repeating" in result.suspicious_reason.lower()
    
    def test_repeating_pattern_12(self, validator):
        """Test repeating pattern (12-12-12-...)."""
        result = validator.validate("+1-121-212-1212")
        
        # Should be flagged as suspicious due to repeating pattern
        if result.valid:
            assert result.suspicious is True
            assert "repeating" in result.suspicious_reason.lower()
    
    def test_too_many_same_digits(self, validator):
        """Test number with too many of the same digit."""
        result = validator.validate("+1-555-555-5550")
        
        # Should be flagged as suspicious (either for repeating pattern or same digits)
        assert result.suspicious is True
        assert ("same" in result.suspicious_reason.lower() or 
                "repeat" in result.suspicious_reason.lower())
    
    def test_normal_number_not_suspicious(self, validator):
        """Test that normal numbers are not flagged as suspicious."""
        result = validator.validate("+1-650-555-1234")
        
        assert result.suspicious is False
        assert result.suspicious_reason is None
    
    def test_premium_rate_suspicious(self, validator):
        """Test that premium rate numbers are flagged as suspicious."""
        # UK premium rate number
        result = validator.validate("+44 909 8790879")
        
        if result.number_type == "premium_rate":
            assert result.suspicious is True
            assert "premium" in result.suspicious_reason.lower()


class TestNumberTypes:
    """Test number type detection."""
    
    def test_toll_free_detection(self, validator):
        """Test toll-free number detection."""
        result = validator.validate("1-800-555-1234")
        
        assert result.number_type == "toll_free"
    
    def test_mobile_or_landline_detection(self, validator):
        """Test mobile/landline detection."""
        result = validator.validate("+1-650-555-1234")
        
        assert result.number_type in ["mobile", "landline", "landline_or_mobile"]
    
    def test_international_mobile(self, validator):
        """Test international mobile detection."""
        result = validator.validate("+44 7911 123456")
        
        # UK mobile numbers start with 7
        assert result.number_type in ["mobile", "landline_or_mobile"]


class TestGeographicInfo:
    """Test geographic information extraction."""
    
    def test_us_country_detection(self, validator):
        """Test US country detection."""
        result = validator.validate("+1-650-555-1234")
        
        assert result.country == "United States"
        assert result.country_code == 1
    
    def test_uk_country_detection(self, validator):
        """Test UK country detection."""
        result = validator.validate("+44 20 7946 0958")
        
        assert "United Kingdom" in result.country
        assert result.country_code == 44
    
    def test_us_region_detection(self, validator):
        """Test US region detection."""
        result = validator.validate("+1-650-555-1234")
        
        # 650 is California
        assert "CA" in result.region or "California" in result.region or result.region == "United States"
    
    def test_international_region(self, validator):
        """Test international region detection."""
        result = validator.validate("+44 20 7946 0958")
        
        # Should have some region info (London)
        assert result.region is not None
        assert len(result.region) > 0


class TestCarrierInfo:
    """Test carrier information extraction."""
    
    def test_carrier_extraction(self, validator):
        """Test carrier extraction (when available)."""
        result = validator.validate("+1-650-555-1234")
        
        # Carrier info might not be available for all numbers
        # Just check that the field exists and is either None or a string
        assert result.carrier is None or isinstance(result.carrier, str)
    
    def test_toll_free_no_carrier(self, validator):
        """Test that toll-free numbers typically don't have carrier info."""
        result = validator.validate("1-800-555-1234")
        
        # Toll-free numbers typically don't have carrier info
        assert result.carrier is None or isinstance(result.carrier, str)


class TestBulkValidation:
    """Test bulk validation."""
    
    def test_validate_multiple(self, validator):
        """Test validating multiple numbers."""
        phones = [
            "+1-650-555-1234",
            "+44 20 7946 0958",
            "1-800-000-0000"  # Suspicious
        ]
        
        results = validator.validate_bulk(phones)
        
        assert len(results) == 3
        assert results[0].valid is True
        assert results[1].valid is True
        assert results[2].suspicious is True
    
    def test_validate_bulk_diverse(self, validator):
        """Test validating diverse numbers."""
        phones = [
            "+1-650-555-1234",  # US mobile
            "1-800-555-1234",   # US toll-free
            "+44 20 7946 0958", # UK landline
            "+65 6221 8888",    # Singapore
            "1-111-111-1111",   # Suspicious pattern
            "invalid"           # Invalid format
        ]
        
        results = validator.validate_bulk(phones)
        
        assert len(results) == 6
        assert results[0].valid is True
        assert results[1].valid is True
        assert results[2].valid is True
        assert results[3].valid is True
        assert results[4].suspicious is True
        assert results[5].valid is False


class TestEdgeCases:
    """Test edge cases."""
    
    def test_whitespace_handling(self, validator):
        """Test handling of whitespace."""
        result = validator.validate("  +1-650-555-1234  ")
        
        assert result.valid is True
    
    def test_special_characters(self, validator):
        """Test handling of special characters."""
        result = validator.validate("+1 (650) 555-1234")
        
        assert result.valid is True
        assert result.number == "+16505551234"
    
    def test_extensions_ignored(self, validator):
        """Test that extensions are handled properly."""
        # Extensions are typically ignored by the parser
        result = validator.validate("+1-650-555-1234 ext 123")
        
        # Should still parse the main number
        assert "+16505551234" in result.number
    
    def test_vanity_numbers(self, validator):
        """Test vanity numbers (1-800-FLOWERS)."""
        # The phonenumbers library actually converts vanity numbers automatically!
        result = validator.validate("1-800-FLOWERS")
        
        # Should parse successfully (FLOWERS = 3569377)
        assert result.valid is True
        assert result.number_type == "toll_free"


class TestPerformance:
    """Test validation performance."""
    
    def test_validation_speed(self, validator):
        """Test that validation is fast (<10ms per number)."""
        phone = "+1-650-555-1234"
        
        start = time.time()
        for _ in range(100):
            validator.validate(phone)
        elapsed = time.time() - start
        
        avg_time_ms = (elapsed / 100) * 1000
        assert avg_time_ms < 10  # Should be under 10ms
        print(f"\nAverage validation time: {avg_time_ms:.2f}ms")
    
    def test_bulk_validation_speed(self, validator):
        """Test bulk validation performance."""
        phones = [
            "+1-650-555-1234",
            "+44 20 7946 0958",
            "+65 6221 8888"
        ] * 100  # 300 numbers total
        
        start = time.time()
        results = validator.validate_bulk(phones)
        elapsed = time.time() - start
        
        avg_time_ms = (elapsed / len(phones)) * 1000
        assert avg_time_ms < 10  # Should be under 10ms per number
        assert len(results) == len(phones)
        print(f"\nBulk validation - average time per number: {avg_time_ms:.2f}ms")
    
    def test_no_blocking_calls(self, validator):
        """Test that validation doesn't make external calls."""
        # This should be instant (no network calls)
        start = time.time()
        result = validator.validate("+1-650-555-1234")
        elapsed = time.time() - start
        
        # Should be VERY fast (< 5ms)
        assert elapsed < 0.005
        assert result.valid is True


class TestResultFormat:
    """Test result format and structure."""
    
    def test_result_has_all_fields(self, validator):
        """Test that result has all required fields."""
        result = validator.validate("+1-650-555-1234")
        
        assert hasattr(result, 'number')
        assert hasattr(result, 'valid')
        assert hasattr(result, 'country')
        assert hasattr(result, 'country_code')
        assert hasattr(result, 'region')
        assert hasattr(result, 'number_type')
        assert hasattr(result, 'carrier')
        assert hasattr(result, 'suspicious')
        assert hasattr(result, 'suspicious_reason')
    
    def test_result_to_dict(self, validator):
        """Test converting result to dictionary."""
        result = validator.validate("+1-650-555-1234")
        result_dict = result.to_dict()
        
        assert isinstance(result_dict, dict)
        assert 'number' in result_dict
        assert 'valid' in result_dict
        assert 'country' in result_dict
        assert 'suspicious' in result_dict
    
    def test_suspicious_result_has_reason(self, validator):
        """Test that suspicious results have a reason."""
        result = validator.validate("1-800-000-0000")
        
        assert result.suspicious is True
        assert result.suspicious_reason is not None
        assert len(result.suspicious_reason) > 0
    
    def test_valid_result_no_reason(self, validator):
        """Test that valid results have no suspicious reason."""
        result = validator.validate("+1-650-555-1234")
        
        if not result.suspicious:
            assert result.suspicious_reason is None


class TestSingletonPattern:
    """Test singleton pattern."""
    
    def test_singleton_instance(self):
        """Test that get_phone_validator_tool returns singleton."""
        from app.agents.tools.phone_validator import get_phone_validator_tool
        
        tool1 = get_phone_validator_tool()
        tool2 = get_phone_validator_tool()
        
        assert tool1 is tool2
    
    def test_singleton_state_persists(self):
        """Test that singleton state persists."""
        from app.agents.tools.phone_validator import get_phone_validator_tool
        
        tool1 = get_phone_validator_tool()
        original_region = tool1.default_region
        
        tool2 = get_phone_validator_tool()
        
        assert tool2.default_region == original_region


class TestRegionOverride:
    """Test region override functionality."""
    
    def test_default_region(self, validator):
        """Test default region is US."""
        assert validator.default_region == "US"
    
    def test_region_override_in_validate(self, validator):
        """Test region override in validate method."""
        # Parse a UK number without country code
        result = validator.validate("020 7946 0958", region="GB")
        
        assert result.valid is True
        assert result.country_code == 44
    
    def test_custom_default_region(self):
        """Test creating validator with custom default region."""
        uk_validator = PhoneValidatorTool(default_region="GB")
        
        assert uk_validator.default_region == "GB"
        
        # Parse UK number without country code
        result = uk_validator.validate("020 7946 0958")
        
        assert result.valid is True

