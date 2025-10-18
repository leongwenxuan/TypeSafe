"""Entity extraction service for MCP agent.

This service extracts structured entities (phone numbers, URLs, emails,
payment details, monetary amounts) from unstructured text for scam analysis.
"""

import re
import phonenumbers
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
import logging

from app.services.entity_patterns import (
    URL_PATTERNS,
    EMAIL_PATTERNS,
    PAYMENT_PATTERNS,
    AMOUNT_PATTERNS,
    VANITY_NUMBER_PATTERN,
    URGENT_PAYMENT_PHRASES,
    COMPANY_PATTERNS,
)
from app.services.entity_normalizer import (
    normalize_url,
    normalize_email,
    extract_domain_from_url,
    extract_domain_from_email,
    should_filter_domain,
    should_filter_email_domain,
    is_url_shortener,
    deobfuscate_text,
    is_valid_email_format,
    extract_numeric_amount,
    detect_currency_symbol,
)

logger = logging.getLogger(__name__)


@dataclass
class ExtractedEntities:
    """Structured entity extraction results."""
    phones: List[Dict[str, Any]]
    urls: List[Dict[str, Any]]
    emails: List[Dict[str, Any]]
    payments: List[Dict[str, Any]]
    amounts: List[Dict[str, Any]]
    companies: List[Dict[str, Any]]
    
    def to_dict(self) -> Dict[str, List[Dict[str, Any]]]:
        """Convert to dictionary for JSON serialization."""
        return asdict(self)
    
    def has_entities(self) -> bool:
        """Check if any entities were extracted."""
        return bool(
            self.phones or self.urls or 
            self.emails or self.payments or self.amounts or self.companies
        )
    
    def entity_count(self) -> int:
        """Total number of entities extracted."""
        return (
            len(self.phones) + len(self.urls) + 
            len(self.emails) + len(self.payments) + len(self.amounts) + len(self.companies)
        )
    
    def has_high_risk_indicators(self) -> bool:
        """Check if extracted entities contain high-risk indicators."""
        # Check for cryptocurrency addresses
        has_crypto = any(
            p.get('type') in ['bitcoin', 'ethereum'] 
            for p in self.payments
        )
        
        # Check for wire transfer instructions
        has_wire = any(
            p.get('type') == 'wire_instruction' 
            for p in self.payments
        )
        
        # Check for large amounts
        has_large_amount = any(
            a.get('amount_numeric', 0) > 1000
            for a in self.amounts
        )
        
        return has_crypto or has_wire or has_large_amount


class EntityExtractor:
    """
    Extracts structured entities from unstructured text.
    
    This service identifies phone numbers, URLs, emails, payment details,
    and monetary amounts from OCR text or typed content for scam analysis.
    """
    
    def __init__(
        self, 
        filter_common_domains: bool = True,
        filter_common_emails: bool = True,
        default_region: str = "US"
    ):
        """
        Initialize entity extractor.
        
        Args:
            filter_common_domains: If True, filter out common legitimate domains
            filter_common_emails: If True, filter out common email providers
            default_region: Default country code for phone number parsing
        """
        self.filter_common_domains = filter_common_domains
        self.filter_common_emails = filter_common_emails
        self.default_region = default_region
        logger.info(
            f"EntityExtractor initialized (region={default_region}, "
            f"filter_domains={filter_common_domains}, filter_emails={filter_common_emails})"
        )
    
    def extract(self, text: str) -> ExtractedEntities:
        """
        Extract all entities from text.
        
        Args:
            text: Input text (OCR output or typed text)
        
        Returns:
            ExtractedEntities object with all extracted entities
        """
        if not text or not text.strip():
            return ExtractedEntities([], [], [], [], [], [])
        
        logger.debug(f"Extracting entities from text ({len(text)} chars)")
        
        # Deobfuscate text for better extraction
        deobfuscated_text = deobfuscate_text(text)
        
        return ExtractedEntities(
            phones=self._extract_phones(deobfuscated_text),
            urls=self._extract_urls(deobfuscated_text),
            emails=self._extract_emails(deobfuscated_text),
            payments=self._extract_payment_details(text),  # Use original for context
            amounts=self._extract_monetary_amounts(text),
            companies=self._extract_companies(text)  # Use original to preserve capitalization
        )
    
    def _extract_phones(self, text: str) -> List[Dict[str, Any]]:
        """
        Extract and normalize phone numbers.
        
        Returns:
            List of dicts with phone number details:
            [{"value": "+18005551234", "original": "1-800-555-1234", 
              "type": "toll_free", "country": "US", "valid": true}]
        """
        phones = []
        seen = set()  # Deduplication
        
        try:
            # Use phonenumbers library for robust extraction
            for match in phonenumbers.PhoneNumberMatcher(text, self.default_region):
                parsed = match.number
                
                # Normalize to E164 format
                normalized = phonenumbers.format_number(
                    parsed, 
                    phonenumbers.PhoneNumberFormat.E164
                )
                
                if normalized in seen:
                    continue
                seen.add(normalized)
                
                # Get phone number type
                number_type = phonenumbers.number_type(parsed)
                type_name = self._get_phone_type_name(number_type)
                
                # Check if valid
                is_valid = phonenumbers.is_valid_number(parsed)
                
                phones.append({
                    "value": normalized,
                    "original": match.raw_string,
                    "type": type_name,
                    "country": phonenumbers.region_code_for_number(parsed),
                    "valid": is_valid,
                    "is_possible": phonenumbers.is_possible_number(parsed)
                })
            
            # Also check for vanity numbers (e.g., 1-800-FLOWERS)
            vanity_phones = self._extract_vanity_numbers(text, seen)
            phones.extend(vanity_phones)
            
        except Exception as e:
            logger.error(f"Phone extraction error: {e}", exc_info=True)
        
        logger.debug(f"Extracted {len(phones)} phone number(s)")
        return phones
    
    def _extract_vanity_numbers(
        self, 
        text: str, 
        seen: set
    ) -> List[Dict[str, Any]]:
        """
        Extract vanity phone numbers like 1-800-FLOWERS.
        
        Args:
            text: Text to search
            seen: Set of already seen phone numbers (to avoid duplicates)
            
        Returns:
            List of vanity phone number dicts
        """
        phones = []
        
        for match in VANITY_NUMBER_PATTERN.finditer(text):
            vanity = match.group(0)
            
            # Skip if we've already seen a normalized version
            # (phonenumbers lib might have caught it)
            if vanity in seen:
                continue
            
            phones.append({
                "value": vanity,
                "original": vanity,
                "type": "vanity",
                "country": "US",
                "valid": False,  # Vanity numbers need decoding to validate
                "is_possible": True
            })
        
        return phones
    
    def _get_phone_type_name(self, number_type: int) -> str:
        """Convert phonenumbers type enum to readable string."""
        type_map = {
            phonenumbers.PhoneNumberType.MOBILE: "mobile",
            phonenumbers.PhoneNumberType.FIXED_LINE: "landline",
            phonenumbers.PhoneNumberType.FIXED_LINE_OR_MOBILE: "fixed_or_mobile",
            phonenumbers.PhoneNumberType.TOLL_FREE: "toll_free",
            phonenumbers.PhoneNumberType.PREMIUM_RATE: "premium_rate",
            phonenumbers.PhoneNumberType.SHARED_COST: "shared_cost",
            phonenumbers.PhoneNumberType.VOIP: "voip",
            phonenumbers.PhoneNumberType.PERSONAL_NUMBER: "personal",
            phonenumbers.PhoneNumberType.PAGER: "pager",
            phonenumbers.PhoneNumberType.UAN: "uan",
            phonenumbers.PhoneNumberType.VOICEMAIL: "voicemail",
            phonenumbers.PhoneNumberType.UNKNOWN: "unknown"
        }
        return type_map.get(number_type, "other")
    
    def _extract_urls(self, text: str) -> List[Dict[str, Any]]:
        """
        Extract and normalize URLs.
        
        Returns:
            List of dicts with URL details:
            [{"value": "https://example.com", "original": "example.com", 
              "domain": "example.com", "is_shortened": false}]
        """
        urls = []
        seen = set()
        
        for pattern in URL_PATTERNS:
            for match in pattern.finditer(text):
                url = match.group(0)
                
                # Basic validation - skip if too short or just TLD
                if len(url) < 5 or url.count('.') == 0:
                    continue
                
                # Normalize URL
                normalized = normalize_url(url)
                
                # Extract domain
                domain = extract_domain_from_url(normalized)
                
                # Filter common legitimate domains if enabled
                if self.filter_common_domains and should_filter_domain(domain):
                    continue
                
                # Deduplicate
                if normalized in seen:
                    continue
                seen.add(normalized)
                
                # Check if shortened URL
                is_shortened = is_url_shortener(domain)
                
                urls.append({
                    "value": normalized,
                    "original": url,
                    "domain": domain,
                    "is_shortened": is_shortened
                })
        
        logger.debug(f"Extracted {len(urls)} URL(s)")
        return urls
    
    def _extract_emails(self, text: str) -> List[Dict[str, Any]]:
        """
        Extract and normalize email addresses.
        
        Returns:
            List of dicts with email details:
            [{"value": "user@example.com", "original": "User@Example.com", 
              "domain": "example.com"}]
        """
        emails = []
        seen = set()
        
        for pattern in EMAIL_PATTERNS:
            for match in pattern.finditer(text):
                email = match.group(0)
                
                # Normalize
                normalized = normalize_email(email)
                
                # Validate format
                if not is_valid_email_format(normalized):
                    continue
                
                # Extract domain
                domain = extract_domain_from_email(normalized)
                
                # Filter common email providers if enabled
                if self.filter_common_emails and should_filter_email_domain(domain):
                    continue
                
                # Deduplicate
                if normalized in seen:
                    continue
                seen.add(normalized)
                
                emails.append({
                    "value": normalized,
                    "original": email,
                    "domain": domain
                })
        
        logger.debug(f"Extracted {len(emails)} email(s)")
        return emails
    
    def _extract_payment_details(self, text: str) -> List[Dict[str, Any]]:
        """
        Extract payment-related information.
        
        Returns:
            List of dicts with payment details:
            [{"type": "account_number", "value": "123456789", 
              "context": "Account: 123456789..."}]
        """
        payments = []
        
        for payment_type, pattern in PAYMENT_PATTERNS.items():
            for match in pattern.finditer(text):
                # Get surrounding context (20 chars before and after)
                start = max(0, match.start() - 20)
                end = min(len(text), match.end() + 20)
                context = text[start:end].strip()
                
                # For patterns with groups, extract the matched value
                if pattern.groups > 0:
                    value = match.group(1)
                else:
                    value = match.group(0)
                
                payments.append({
                    "type": payment_type,
                    "value": value,
                    "context": context
                })
        
        # Check for urgent payment phrases (scam indicator)
        for phrase_pattern in URGENT_PAYMENT_PHRASES:
            for match in phrase_pattern.finditer(text):
                start = max(0, match.start() - 20)
                end = min(len(text), match.end() + 20)
                context = text[start:end].strip()
                
                payments.append({
                    "type": "urgent_payment_request",
                    "value": match.group(0),
                    "context": context
                })
        
        logger.debug(f"Extracted {len(payments)} payment detail(s)")
        return payments
    
    def _extract_monetary_amounts(self, text: str) -> List[Dict[str, Any]]:
        """
        Extract monetary amounts and currencies.
        
        Returns:
            List of dicts with amount details:
            [{"amount": "500", "currency": "USD", "original": "$500", 
              "amount_numeric": 500.0}]
        """
        amounts = []
        seen = set()
        
        for pattern in AMOUNT_PATTERNS:
            for match in pattern.finditer(text):
                original = match.group(0)
                
                # Deduplicate
                if original in seen:
                    continue
                seen.add(original)
                
                # Parse amount and currency
                parsed = self._parse_amount(original)
                if parsed:
                    amounts.append(parsed)
        
        logger.debug(f"Extracted {len(amounts)} monetary amount(s)")
        return amounts
    
    def _parse_amount(self, text: str) -> Optional[Dict[str, Any]]:
        """
        Parse monetary amount from text.
        
        Args:
            text: String containing monetary amount
            
        Returns:
            Dict with amount details or None if cannot parse
        """
        # Detect currency
        currency = detect_currency_symbol(text)
        if not currency:
            currency = "USD"  # Default
        
        # Extract numeric value
        numeric_value = extract_numeric_amount(text)
        
        if numeric_value is None:
            return None
        
        return {
            "amount": str(numeric_value),
            "amount_numeric": numeric_value,
            "currency": currency,
            "original": text
        }
    
    def _extract_companies(self, text: str) -> List[Dict[str, Any]]:
        """
        Extract company names from text.
        
        Returns:
            List of dicts with company details:
            [{"value": "DHL Express Pte Ltd", "normalized": "Dhl Express", 
              "category": "registered", "original": "DHL Express Pte Ltd"}]
        """
        companies = []
        seen = set()
        
        for pattern in COMPANY_PATTERNS:
            for match in pattern.finditer(text):
                original = match.group(0)
                
                # Extract company name (group 1 is the company name without suffix)
                if pattern.groups > 0:
                    company_name = match.group(1)
                else:
                    company_name = original
                
                # Deduplicate based on normalized name
                normalized = company_name.strip()
                if normalized.lower() in seen:
                    continue
                seen.add(normalized.lower())
                
                # Categorize based on pattern
                category = self._categorize_company_name(original)
                
                companies.append({
                    "value": original,
                    "normalized": normalized,
                    "category": category,
                    "original": original
                })
        
        logger.debug(f"Extracted {len(companies)} company name(s)")
        return companies
    
    def _categorize_company_name(self, company_name: str) -> str:
        """
        Categorize company name based on suffix/pattern.
        
        Args:
            company_name: Full company name with suffix
            
        Returns:
            Category: "registered" (has legal suffix) or "department" (has department/unit)
        """
        # Check for department/division keywords (often scam indicators)
        department_keywords = [
            'department', 'division', 'unit', 'center', 'centre', 'team', 'office'
        ]
        
        name_lower = company_name.lower()
        for keyword in department_keywords:
            if keyword in name_lower:
                return "department"
        
        # Otherwise, assume it's a registered company (has legal suffix)
        return "registered"


# Singleton instance
_extractor_instance: Optional[EntityExtractor] = None


def get_entity_extractor() -> EntityExtractor:
    """Get singleton EntityExtractor instance."""
    global _extractor_instance
    if _extractor_instance is None:
        _extractor_instance = EntityExtractor()
    return _extractor_instance


# Convenience function for quick extraction
def extract_entities(text: str, filter_common: bool = True) -> Dict[str, List[Dict[str, Any]]]:
    """
    Convenience function to extract entities from text.
    
    Args:
        text: Text to extract entities from
        filter_common: Whether to filter common legitimate domains/emails
        
    Returns:
        Dictionary with extracted entities
    """
    extractor = EntityExtractor(
        filter_common_domains=filter_common,
        filter_common_emails=filter_common
    )
    result = extractor.extract(text)
    return result.to_dict()

