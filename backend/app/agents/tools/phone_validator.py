"""Phone Number Validator Tool for MCP Agent."""

import phonenumbers
from phonenumbers import geocoder, carrier, PhoneNumberType
from typing import Dict, Any, Optional
from dataclasses import dataclass
import logging

logger = logging.getLogger(__name__)


@dataclass
class PhoneValidationResult:
    """Phone number validation result."""
    number: str  # E164 format
    valid: bool
    country: str
    country_code: int
    region: str
    number_type: str
    carrier: Optional[str]
    suspicious: bool
    suspicious_reason: Optional[str]
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "number": self.number,
            "valid": self.valid,
            "country": self.country,
            "country_code": self.country_code,
            "region": self.region,
            "number_type": self.number_type,
            "carrier": self.carrier,
            "suspicious": self.suspicious,
            "suspicious_reason": self.suspicious_reason
        }


class PhoneValidatorTool:
    """
    Tool for validating phone numbers and detecting suspicious patterns.
    
    Uses Google's phonenumbers library (offline, no API calls).
    """
    
    # Phone number type mapping
    TYPE_NAMES = {
        PhoneNumberType.MOBILE: "mobile",
        PhoneNumberType.FIXED_LINE: "landline",
        PhoneNumberType.FIXED_LINE_OR_MOBILE: "landline_or_mobile",
        PhoneNumberType.TOLL_FREE: "toll_free",
        PhoneNumberType.PREMIUM_RATE: "premium_rate",
        PhoneNumberType.SHARED_COST: "shared_cost",
        PhoneNumberType.VOIP: "voip",
        PhoneNumberType.PERSONAL_NUMBER: "personal",
        PhoneNumberType.PAGER: "pager",
        PhoneNumberType.UAN: "uan",
        PhoneNumberType.VOICEMAIL: "voicemail",
        PhoneNumberType.UNKNOWN: "unknown"
    }
    
    def __init__(self, default_region: str = "US"):
        """
        Initialize phone validator tool.
        
        Args:
            default_region: Default country code for parsing (e.g., "US")
        """
        self.default_region = default_region
        logger.info(f"PhoneValidatorTool initialized (default_region={default_region})")
    
    def validate(self, phone: str, region: Optional[str] = None) -> PhoneValidationResult:
        """
        Validate phone number and check for suspicious patterns.
        
        Args:
            phone: Phone number string (any format)
            region: Optional region hint for parsing (defaults to self.default_region)
        
        Returns:
            PhoneValidationResult with validation details
        """
        region = region or self.default_region
        
        try:
            # Parse phone number
            parsed = phonenumbers.parse(phone, region)
            
            # Basic validation
            is_valid = phonenumbers.is_valid_number(parsed)
            is_possible = phonenumbers.is_possible_number(parsed)
            
            # Format to E164
            e164_number = phonenumbers.format_number(
                parsed,
                phonenumbers.PhoneNumberFormat.E164
            )
            
            # Get number type
            number_type = phonenumbers.number_type(parsed)
            type_name = self.TYPE_NAMES.get(number_type, "unknown")
            
            # Get geographic info
            country = geocoder.country_name_for_number(parsed, "en")
            region_desc = geocoder.description_for_number(parsed, "en")
            
            # Get carrier info (best effort)
            carrier_name = carrier.name_for_number(parsed, "en")
            
            # Check for suspicious patterns first
            suspicious, reason = self._check_suspicious_patterns(parsed, e164_number)
            
            # Additional checks
            if not is_valid:
                # Keep suspicious pattern reason if found, otherwise use generic invalid message
                if not suspicious:
                    suspicious = True
                    reason = "Invalid phone number format"
            elif number_type == PhoneNumberType.PREMIUM_RATE:
                # Premium rate check only for valid numbers
                suspicious = True
                reason = "Premium rate number (high cost)"
            
            return PhoneValidationResult(
                number=e164_number,
                valid=is_valid,
                country=country or "Unknown",
                country_code=parsed.country_code,
                region=region_desc or country or "Unknown",
                number_type=type_name,
                carrier=carrier_name if carrier_name else None,
                suspicious=suspicious,
                suspicious_reason=reason if suspicious else None
            )
        
        except phonenumbers.NumberParseException as e:
            logger.debug(f"Failed to parse phone number '{phone}': {e}")
            return PhoneValidationResult(
                number=phone,
                valid=False,
                country="Unknown",
                country_code=0,
                region="Unknown",
                number_type="unknown",
                carrier=None,
                suspicious=True,
                suspicious_reason=f"Invalid format: {str(e)}"
            )
        
        except Exception as e:
            logger.error(f"Phone validation error for '{phone}': {e}", exc_info=True)
            return PhoneValidationResult(
                number=phone,
                valid=False,
                country="Unknown",
                country_code=0,
                region="Unknown",
                number_type="unknown",
                carrier=None,
                suspicious=True,
                suspicious_reason="Validation error"
            )
    
    def _check_suspicious_patterns(
        self,
        parsed: phonenumbers.PhoneNumber,
        e164: str
    ) -> tuple[bool, Optional[str]]:
        """
        Check for suspicious phone number patterns.
        
        Args:
            parsed: Parsed PhoneNumber object
            e164: E164 formatted number
        
        Returns:
            Tuple of (is_suspicious, reason)
        """
        # Extract national number (without country code)
        national_num = str(parsed.national_number)
        
        # Pattern 1: All same digit (e.g., 1111111111)
        if len(set(national_num)) <= 1:
            return True, f"Suspicious pattern: all same digit ({national_num[0]})"
        
        # Pattern 2: All zeros
        if national_num.strip('0') == '':
            return True, "Suspicious pattern: all zeros"
        
        # Pattern 3: Sequential digits (e.g., 1234567890)
        if self._is_sequential(national_num):
            return True, "Suspicious pattern: sequential digits"
        
        # Pattern 4: Repeating patterns (e.g., 123123123)
        if self._is_repeating_pattern(national_num):
            return True, "Suspicious pattern: repeating sequence"
        
        # Pattern 5: Too many same digits (e.g., 1111122222)
        digit_counts = {digit: national_num.count(digit) for digit in set(national_num)}
        max_count = max(digit_counts.values())
        if max_count > len(national_num) * 0.6:  # More than 60% same digit
            return True, f"Suspicious pattern: {max_count}/{len(national_num)} digits are the same"
        
        # Not suspicious
        return False, None
    
    def _is_sequential(self, num_str: str) -> bool:
        """Check if number is sequential (e.g., 1234567890 or 9876543210)."""
        # Forward sequential
        if num_str == ''.join(str(i % 10) for i in range(int(num_str[0]), int(num_str[0]) + len(num_str))):
            return True
        
        # Backward sequential
        if num_str == ''.join(str(i % 10) for i in range(int(num_str[0]), int(num_str[0]) - len(num_str), -1)):
            return True
        
        # Check for ascending/descending patterns
        diffs = [int(num_str[i+1]) - int(num_str[i]) for i in range(len(num_str)-1)]
        if len(set(diffs)) == 1 and diffs[0] in [1, -1]:
            return True
        
        return False
    
    def _is_repeating_pattern(self, num_str: str) -> bool:
        """Check if number has repeating patterns (e.g., 123123123)."""
        # Check for patterns of length 2-5
        for pattern_len in range(2, min(6, len(num_str) // 2 + 1)):
            pattern = num_str[:pattern_len]
            repeated = pattern * (len(num_str) // pattern_len)
            
            # Allow one digit difference (not perfect repeat)
            if repeated[:len(num_str)] == num_str or repeated[:len(num_str)-1] == num_str[:-1]:
                return True
        
        return False
    
    def validate_bulk(self, phones: list[str], region: Optional[str] = None) -> list[PhoneValidationResult]:
        """
        Validate multiple phone numbers in batch.
        
        Args:
            phones: List of phone number strings
            region: Optional region hint
        
        Returns:
            List of PhoneValidationResult objects
        """
        return [self.validate(phone, region) for phone in phones]


# Singleton instance
_tool_instance = None

def get_phone_validator_tool() -> PhoneValidatorTool:
    """Get singleton PhoneValidatorTool instance."""
    global _tool_instance
    if _tool_instance is None:
        _tool_instance = PhoneValidatorTool()
    return _tool_instance

