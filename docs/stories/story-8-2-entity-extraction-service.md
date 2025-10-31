# Story 8.2: Entity Extraction Service

**Story ID:** 8.2  
**Epic:** Epic 8 - MCP Agent with Multi-Tool Orchestration  
**Priority:** P0 (Core Functionality)  
**Effort:** 20 hours  
**Assignee:** Backend Developer  
**Status:** 📝 Ready for Development

---

## User Story

**As an** MCP agent,  
**I want** to extract structured entities from OCR text and images,  
**so that** I can investigate specific scam indicators using specialized tools.

---

## Description

The Entity Extraction Service is the **first critical step** in the MCP agent workflow. Before we can investigate potential scams using specialized tools (scam database, web search, domain reputation), we need to identify and extract relevant entities from the user's screenshot or typed text.

This service will parse unstructured text and identify:
- 📱 **Phone numbers** (international format, vanity numbers, various separators)
- 🌐 **URLs** (full URLs, shortened links, domains only)
- 📧 **Email addresses** (various formats, obfuscation patterns)
- 💰 **Payment details** (account numbers, Bitcoin addresses, wire instructions)
- 💵 **Monetary amounts** (currency symbols, amounts, payment requests)

**Why This Matters:**
- Enables targeted investigation (don't waste API calls on irrelevant content)
- Provides structured data for tool routing
- Improves accuracy by normalizing entity formats
- Fast performance (< 100ms) keeps agent responsive

---

## Acceptance Criteria

### Phone Number Extraction
- [ ] 1. Extracts phone numbers in international format: `+1 (800) 555-1234` → `+18005551234`
- [ ] 2. Handles various separators: spaces, dashes, dots, parentheses
- [ ] 3. Detects vanity numbers: `1-800-FLOWERS` → Extract and flag as vanity
- [ ] 4. Supports 200+ country codes (using `phonenumbers` library)
- [ ] 5. Normalizes all phone numbers to E164 format for consistency
- [ ] 6. Handles multiple phone numbers in single text block
- [ ] 7. Filters out invalid/incomplete numbers (too short, invalid country code)

### URL Extraction
- [ ] 8. Extracts full URLs: `https://example.com/path?query=1`
- [ ] 9. Extracts URLs without protocol: `example.com` → Add `https://`
- [ ] 10. Detects shortened URLs: `bit.ly/abc123`, `t.co/xyz`
- [ ] 11. Handles obfuscated URLs: `hxxps://example[.]com` → Normalize
- [ ] 12. Extracts domains from email-style text: `Click here example.com`
- [ ] 13. Filters out common legitimate domains (google.com, apple.com, etc.) - configurable
- [ ] 14. Normalizes URLs: lowercased domain, trailing slashes handled

### Email Address Extraction
- [ ] 15. Extracts standard email formats: `user@example.com`
- [ ] 16. Handles plus addressing: `user+tag@example.com`
- [ ] 17. Handles dot addressing: `first.last@example.com`
- [ ] 18. Detects obfuscated emails: `user [at] example [dot] com` → Normalize
- [ ] 19. Validates email format (basic regex validation)
- [ ] 20. Filters out common non-suspicious domains (gmail.com, outlook.com) - configurable

### Payment Details Extraction
- [ ] 21. Detects bank account numbers: `Account: 123456789` (patterns like "Account:", "Acct:", etc.)
- [ ] 22. Extracts Bitcoin addresses: `1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa` (valid format)
- [ ] 23. Detects wire transfer instructions: Keywords like "Wire to:", "Send to:", "Transfer to:"
- [ ] 24. Identifies routing numbers: `Routing: 123456789`
- [ ] 25. Handles payment app usernames: `$CashApp`, `@Venmo`

### Monetary Amounts Extraction
- [ ] 26. Extracts amounts with symbols: `$500`, `€100`, `£50`
- [ ] 27. Detects written amounts: `USD 1000`, `1000 dollars`
- [ ] 28. Handles various formats: `$1,000.00`, `1.000,00 EUR`
- [ ] 29. Identifies payment requests: "Send $500", "Pay $100 immediately"
- [ ] 30. Extracts currency type (USD, EUR, BTC, etc.)

### Performance & Quality
- [ ] 31. Processing time: < 100ms for typical OCR text (500 characters)
- [ ] 32. Processing time: < 500ms for large text blocks (5000 characters)
- [ ] 33. Returns structured data: `{"phones": [...], "urls": [...], "emails": [...], "payments": [...], "amounts": [...]}`
- [ ] 34. Handles multi-language text (English primary, expandable to Spanish, Chinese)
- [ ] 35. No false positives: Filters out dates that look like phone numbers (e.g., "2025-10-18")
- [ ] 36. Handles edge cases: Empty text, very long text, special characters, Unicode

### Testing
- [ ] 37. Unit tests with 100+ diverse test cases (real-world examples)
- [ ] 38. Performance benchmarks documented
- [ ] 39. False positive/negative analysis on test corpus
- [ ] 40. Integration tests with MCP agent workflow

---

## Technical Implementation

### File Structure
```
backend/app/services/
├── entity_extractor.py       # Main extractor class
├── entity_patterns.py         # Regex patterns and configurations
└── entity_normalizer.py       # Normalization utilities
```

### Core Implementation

**1. Main Extractor Class (`app/services/entity_extractor.py`):**

```python
"""Entity extraction service for MCP agent."""

import re
import phonenumbers
from typing import Dict, List, Optional
from dataclasses import dataclass
import logging

from app.services.entity_patterns import (
    URL_PATTERNS,
    EMAIL_PATTERNS,
    PAYMENT_PATTERNS,
    AMOUNT_PATTERNS
)
from app.services.entity_normalizer import (
    normalize_url,
    normalize_email,
    should_filter_domain
)

logger = logging.getLogger(__name__)


@dataclass
class ExtractedEntities:
    """Structured entity extraction results."""
    phones: List[Dict[str, str]]
    urls: List[Dict[str, str]]
    emails: List[Dict[str, str]]
    payments: List[Dict[str, str]]
    amounts: List[Dict[str, str]]
    
    def to_dict(self) -> Dict:
        """Convert to dictionary for JSON serialization."""
        return {
            "phones": self.phones,
            "urls": self.urls,
            "emails": self.emails,
            "payments": self.payments,
            "amounts": self.amounts
        }
    
    def has_entities(self) -> bool:
        """Check if any entities were extracted."""
        return bool(
            self.phones or self.urls or 
            self.emails or self.payments or self.amounts
        )
    
    def entity_count(self) -> int:
        """Total number of entities extracted."""
        return (
            len(self.phones) + len(self.urls) + 
            len(self.emails) + len(self.payments) + len(self.amounts)
        )


class EntityExtractor:
    """
    Extracts structured entities from unstructured text.
    
    This service identifies phone numbers, URLs, emails, payment details,
    and monetary amounts from OCR text or typed content.
    """
    
    def __init__(
        self, 
        filter_common_domains: bool = True,
        default_region: str = "US"
    ):
        """
        Initialize entity extractor.
        
        Args:
            filter_common_domains: If True, filter out common legitimate domains
            default_region: Default country code for phone number parsing
        """
        self.filter_common_domains = filter_common_domains
        self.default_region = default_region
        logger.info(f"EntityExtractor initialized (region={default_region})")
    
    def extract(self, text: str) -> ExtractedEntities:
        """
        Extract all entities from text.
        
        Args:
            text: Input text (OCR output or typed text)
        
        Returns:
            ExtractedEntities object with all extracted entities
        """
        if not text or not text.strip():
            return ExtractedEntities([], [], [], [], [])
        
        logger.debug(f"Extracting entities from text ({len(text)} chars)")
        
        return ExtractedEntities(
            phones=self._extract_phones(text),
            urls=self._extract_urls(text),
            emails=self._extract_emails(text),
            payments=self._extract_payment_details(text),
            amounts=self._extract_monetary_amounts(text)
        )
    
    def _extract_phones(self, text: str) -> List[Dict[str, str]]:
        """
        Extract and normalize phone numbers.
        
        Returns:
            List of dicts: [{"value": "+18005551234", "original": "1-800-555-1234", "type": "standard"}]
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
                
                phones.append({
                    "value": normalized,
                    "original": match.raw_string,
                    "type": type_name,
                    "country": phonenumbers.region_code_for_number(parsed),
                    "valid": phonenumbers.is_valid_number(parsed)
                })
            
            # Also check for vanity numbers (e.g., 1-800-FLOWERS)
            vanity_phones = self._extract_vanity_numbers(text)
            phones.extend(vanity_phones)
            
        except Exception as e:
            logger.error(f"Phone extraction error: {e}", exc_info=True)
        
        logger.debug(f"Extracted {len(phones)} phone number(s)")
        return phones
    
    def _extract_vanity_numbers(self, text: str) -> List[Dict[str, str]]:
        """Extract vanity phone numbers like 1-800-FLOWERS."""
        vanity_pattern = r'\b1[-.\s]?800[-.\s]?[A-Z]{5,}\b'
        phones = []
        
        for match in re.finditer(vanity_pattern, text, re.IGNORECASE):
            phones.append({
                "value": match.group(0),
                "original": match.group(0),
                "type": "vanity",
                "country": "US",
                "valid": False  # Vanity numbers need decoding
            })
        
        return phones
    
    def _get_phone_type_name(self, number_type) -> str:
        """Convert phonenumbers type enum to readable string."""
        type_map = {
            phonenumbers.PhoneNumberType.MOBILE: "mobile",
            phonenumbers.PhoneNumberType.FIXED_LINE: "landline",
            phonenumbers.PhoneNumberType.TOLL_FREE: "toll_free",
            phonenumbers.PhoneNumberType.VOIP: "voip",
            phonenumbers.PhoneNumberType.UNKNOWN: "unknown"
        }
        return type_map.get(number_type, "other")
    
    def _extract_urls(self, text: str) -> List[Dict[str, str]]:
        """
        Extract and normalize URLs.
        
        Returns:
            List of dicts: [{"value": "https://example.com", "original": "example.com", "domain": "example.com"}]
        """
        urls = []
        seen = set()
        
        for pattern in URL_PATTERNS:
            for match in re.finditer(pattern, text, re.IGNORECASE):
                url = match.group(0)
                normalized = normalize_url(url)
                
                # Filter common legitimate domains if enabled
                if self.filter_common_domains and should_filter_domain(normalized):
                    continue
                
                if normalized in seen:
                    continue
                seen.add(normalized)
                
                # Extract domain
                domain = self._extract_domain(normalized)
                
                urls.append({
                    "value": normalized,
                    "original": url,
                    "domain": domain,
                    "is_shortened": self._is_shortened_url(domain)
                })
        
        logger.debug(f"Extracted {len(urls)} URL(s)")
        return urls
    
    def _extract_domain(self, url: str) -> str:
        """Extract domain from URL."""
        # Remove protocol
        domain = re.sub(r'^https?://', '', url)
        # Remove path and query
        domain = domain.split('/')[0]
        # Remove port
        domain = domain.split(':')[0]
        return domain.lower()
    
    def _is_shortened_url(self, domain: str) -> bool:
        """Check if domain is a known URL shortener."""
        shorteners = {
            'bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'ow.ly',
            'is.gd', 'buff.ly', 'adf.ly', 'bc.vc', 'tiny.cc'
        }
        return domain in shorteners
    
    def _extract_emails(self, text: str) -> List[Dict[str, str]]:
        """
        Extract and normalize email addresses.
        
        Returns:
            List of dicts: [{"value": "user@example.com", "original": "user [at] example.com", "domain": "example.com"}]
        """
        emails = []
        seen = set()
        
        # First, handle obfuscated emails (e.g., "user [at] example [dot] com")
        deobfuscated_text = self._deobfuscate_text(text)
        
        for pattern in EMAIL_PATTERNS:
            for match in re.finditer(pattern, deobfuscated_text, re.IGNORECASE):
                email = match.group(0).lower()
                
                # Basic validation
                if not self._is_valid_email(email):
                    continue
                
                domain = email.split('@')[1]
                
                # Filter common legitimate domains if enabled
                if self.filter_common_domains and should_filter_domain(domain):
                    continue
                
                if email in seen:
                    continue
                seen.add(email)
                
                emails.append({
                    "value": email,
                    "original": match.group(0),
                    "domain": domain
                })
        
        logger.debug(f"Extracted {len(emails)} email(s)")
        return emails
    
    def _deobfuscate_text(self, text: str) -> str:
        """Deobfuscate text (e.g., [at] → @, [dot] → .)."""
        text = re.sub(r'\s*\[at\]\s*', '@', text, flags=re.IGNORECASE)
        text = re.sub(r'\s*\[dot\]\s*', '.', text, flags=re.IGNORECASE)
        text = re.sub(r'\s+at\s+', '@', text, flags=re.IGNORECASE)
        text = re.sub(r'\s+dot\s+', '.', text, flags=re.IGNORECASE)
        return text
    
    def _is_valid_email(self, email: str) -> bool:
        """Basic email validation."""
        # Must have @ and domain
        if '@' not in email or email.count('@') != 1:
            return False
        
        username, domain = email.split('@')
        
        # Username and domain must not be empty
        if not username or not domain:
            return False
        
        # Domain must have at least one dot
        if '.' not in domain:
            return False
        
        return True
    
    def _extract_payment_details(self, text: str) -> List[Dict[str, str]]:
        """
        Extract payment-related information.
        
        Returns:
            List of dicts: [{"type": "account_number", "value": "123456789", "context": "Account: 123456789"}]
        """
        payments = []
        
        for payment_type, pattern in PAYMENT_PATTERNS.items():
            for match in re.finditer(pattern, text, re.IGNORECASE):
                context = text[max(0, match.start()-20):min(len(text), match.end()+20)]
                
                payments.append({
                    "type": payment_type,
                    "value": match.group(0),
                    "context": context.strip()
                })
        
        logger.debug(f"Extracted {len(payments)} payment detail(s)")
        return payments
    
    def _extract_monetary_amounts(self, text: str) -> List[Dict[str, str]]:
        """
        Extract monetary amounts and currencies.
        
        Returns:
            List of dicts: [{"amount": "500", "currency": "USD", "original": "$500"}]
        """
        amounts = []
        seen = set()
        
        for pattern in AMOUNT_PATTERNS:
            for match in re.finditer(pattern, text):
                original = match.group(0)
                
                if original in seen:
                    continue
                seen.add(original)
                
                # Parse amount and currency
                parsed = self._parse_amount(original)
                if parsed:
                    amounts.append(parsed)
        
        logger.debug(f"Extracted {len(amounts)} monetary amount(s)")
        return amounts
    
    def _parse_amount(self, text: str) -> Optional[Dict[str, str]]:
        """Parse monetary amount from text."""
        # Currency symbols mapping
        currency_map = {
            '$': 'USD',
            '€': 'EUR',
            '£': 'GBP',
            '¥': 'JPY',
            '₹': 'INR'
        }
        
        # Extract currency
        currency = None
        for symbol, code in currency_map.items():
            if symbol in text:
                currency = code
                break
        
        # Extract numeric amount
        amount_str = re.sub(r'[^\d.,]', '', text)
        if not amount_str:
            return None
        
        # Normalize (remove thousand separators, keep decimal)
        amount_str = amount_str.replace(',', '')
        
        try:
            amount = float(amount_str)
        except ValueError:
            return None
        
        return {
            "amount": str(amount),
            "currency": currency or "USD",
            "original": text
        }


# Singleton instance
_extractor_instance = None

def get_entity_extractor() -> EntityExtractor:
    """Get singleton EntityExtractor instance."""
    global _extractor_instance
    if _extractor_instance is None:
        _extractor_instance = EntityExtractor()
    return _extractor_instance
```

**2. Pattern Definitions (`app/services/entity_patterns.py`):**

```python
"""Regex patterns for entity extraction."""

# URL patterns
URL_PATTERNS = [
    # Full URLs with protocol
    r'https?://[^\s<>"{}|\\^`\[\]]+',
    
    # URLs without protocol (e.g., example.com)
    r'\b(?:[a-z0-9-]+\.)+[a-z]{2,}(?:/[^\s<>"{}|\\^`\[\]]*)?',
    
    # Obfuscated URLs (hxxps, example[.]com)
    r'hxxps?://[^\s<>"{}|\\^`\[\]]+',
    r'\b(?:[a-z0-9-]+\[?\.\]?)+[a-z]{2,}',
]

# Email patterns
EMAIL_PATTERNS = [
    # Standard email
    r'\b[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}\b',
]

# Payment patterns
PAYMENT_PATTERNS = {
    "account_number": r'(?:account|acct|acc)[\s:#]*(\d{8,20})',
    "routing_number": r'(?:routing|rtn)[\s:#]*(\d{9})',
    "bitcoin": r'\b[13][a-km-zA-HJ-NP-Z1-9]{25,34}\b',
    "venmo": r'@[a-zA-Z0-9_-]{5,30}',
    "cashapp": r'\$[a-zA-Z0-9_-]{5,30}',
    "wire_instruction": r'(?:wire|send|transfer)[\s]+(?:to|money)',
}

# Monetary amount patterns
AMOUNT_PATTERNS = [
    # Currency symbols
    r'[$€£¥₹]\s?\d+(?:,\d{3})*(?:\.\d{2})?',
    
    # Written amounts
    r'\d+(?:,\d{3})*(?:\.\d{2})?\s?(?:USD|EUR|GBP|dollars?|euros?)',
]
```

**3. Normalization Utilities (`app/services/entity_normalizer.py`):**

```python
"""Entity normalization utilities."""

import re
from urllib.parse import urlparse

# Common legitimate domains to filter (reduce false positives)
COMMON_DOMAINS = {
    'google.com', 'youtube.com', 'facebook.com', 'twitter.com',
    'apple.com', 'microsoft.com', 'amazon.com', 'netflix.com',
    'gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com',
    'icloud.com', 'me.com', 'mac.com'
}


def normalize_url(url: str) -> str:
    """
    Normalize URL to consistent format.
    
    - Add https:// if no protocol
    - Lowercase domain
    - Handle obfuscation (hxxps → https, example[.]com → example.com)
    """
    # Deobfuscate
    url = url.replace('hxxp', 'http')
    url = re.sub(r'\[?\.\]?', '.', url)
    
    # Add protocol if missing
    if not url.startswith(('http://', 'https://')):
        url = 'https://' + url
    
    # Lowercase domain only (preserve path case)
    parsed = urlparse(url)
    normalized = parsed._replace(netloc=parsed.netloc.lower()).geturl()
    
    return normalized


def normalize_email(email: str) -> str:
    """Normalize email to lowercase."""
    return email.lower().strip()


def should_filter_domain(domain: str) -> bool:
    """Check if domain should be filtered (common legitimate domain)."""
    # Extract base domain (handle subdomains)
    domain = domain.lower()
    
    for common in COMMON_DOMAINS:
        if domain == common or domain.endswith('.' + common):
            return True
    
    return False
```

---

## Testing Strategy

### Unit Tests (`tests/test_entity_extractor.py`)

```python
"""Comprehensive unit tests for entity extraction."""

import pytest
from app.services.entity_extractor import EntityExtractor, ExtractedEntities


class TestPhoneExtraction:
    """Test phone number extraction."""
    
    def test_standard_phone_formats(self):
        extractor = EntityExtractor()
        
        test_cases = [
            ("+1 (800) 555-1234", "+18005551234"),
            ("1-800-555-1234", "+18005551234"),
            ("800.555.1234", "+18005551234"),
            ("(800) 555-1234", "+18005551234"),
        ]
        
        for input_text, expected in test_cases:
            result = extractor.extract(input_text)
            assert len(result.phones) == 1
            assert result.phones[0]["value"] == expected
    
    def test_international_phones(self):
        extractor = EntityExtractor()
        
        test_cases = [
            ("+44 20 7946 0958", "+442079460958"),  # UK
            ("+86 10 1234 5678", "+861012345678"),  # China
            ("+33 1 23 45 67 89", "+33123456789"),  # France
        ]
        
        for input_text, expected in test_cases:
            result = extractor.extract(input_text)
            assert len(result.phones) >= 1
            assert result.phones[0]["value"] == expected
    
    def test_vanity_numbers(self):
        extractor = EntityExtractor()
        result = extractor.extract("Call 1-800-FLOWERS for delivery")
        
        assert len(result.phones) >= 1
        vanity = next((p for p in result.phones if p["type"] == "vanity"), None)
        assert vanity is not None
    
    def test_multiple_phones(self):
        extractor = EntityExtractor()
        text = "Call +1-800-555-1234 or +1-888-555-9999"
        result = extractor.extract(text)
        
        assert len(result.phones) == 2


class TestURLExtraction:
    """Test URL extraction."""
    
    def test_full_urls(self):
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            "https://example.com",
            "http://suspicious-site.com/phishing",
            "https://example.com/path?query=value",
        ]
        
        for url in test_cases:
            result = extractor.extract(url)
            assert len(result.urls) >= 1
            assert result.urls[0]["value"].startswith("http")
    
    def test_urls_without_protocol(self):
        extractor = EntityExtractor(filter_common_domains=False)
        result = extractor.extract("Visit example.com for details")
        
        assert len(result.urls) >= 1
        assert result.urls[0]["value"] == "https://example.com"
    
    def test_shortened_urls(self):
        extractor = EntityExtractor()
        result = extractor.extract("Click bit.ly/abc123")
        
        assert len(result.urls) >= 1
        assert result.urls[0]["is_shortened"] is True
    
    def test_domain_filtering(self):
        extractor = EntityExtractor(filter_common_domains=True)
        result = extractor.extract("Search on google.com")
        
        # Google should be filtered out
        assert len(result.urls) == 0


class TestEmailExtraction:
    """Test email extraction."""
    
    def test_standard_emails(self):
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            "user@example.com",
            "first.last@company.co.uk",
            "user+tag@example.com",
        ]
        
        for email in test_cases:
            result = extractor.extract(email)
            assert len(result.emails) >= 1
    
    def test_obfuscated_emails(self):
        extractor = EntityExtractor(filter_common_domains=False)
        result = extractor.extract("Contact user [at] example [dot] com")
        
        assert len(result.emails) >= 1
        assert "@" in result.emails[0]["value"]


class TestPaymentExtraction:
    """Test payment details extraction."""
    
    def test_account_numbers(self):
        extractor = EntityExtractor()
        result = extractor.extract("Send payment to Account: 123456789")
        
        payments = [p for p in result.payments if p["type"] == "account_number"]
        assert len(payments) >= 1
    
    def test_bitcoin_addresses(self):
        extractor = EntityExtractor()
        btc_address = "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
        result = extractor.extract(f"Send BTC to {btc_address}")
        
        payments = [p for p in result.payments if p["type"] == "bitcoin"]
        assert len(payments) >= 1
    
    def test_payment_app_usernames(self):
        extractor = EntityExtractor()
        result = extractor.extract("Send to $MyUsername or @VenmoUser")
        
        assert len(result.payments) >= 2


class TestAmountExtraction:
    """Test monetary amount extraction."""
    
    def test_currency_symbols(self):
        extractor = EntityExtractor()
        
        test_cases = [
            ("Send $500", "500", "USD"),
            ("Pay €100", "100", "EUR"),
            ("Transfer £50", "50", "GBP"),
        ]
        
        for text, expected_amount, expected_currency in test_cases:
            result = extractor.extract(text)
            assert len(result.amounts) >= 1
            assert result.amounts[0]["amount"] == expected_amount
            assert result.amounts[0]["currency"] == expected_currency
    
    def test_written_amounts(self):
        extractor = EntityExtractor()
        result = extractor.extract("Pay 1000 USD immediately")
        
        assert len(result.amounts) >= 1
        assert result.amounts[0]["amount"] == "1000"


class TestPerformance:
    """Test extraction performance."""
    
    def test_extraction_speed(self):
        import time
        
        extractor = EntityExtractor()
        text = "Call +1-800-555-1234 or visit example.com. Email: user@test.com. Send $500 to account 123456789."
        
        start = time.time()
        for _ in range(100):
            extractor.extract(text)
        elapsed = time.time() - start
        
        avg_time_ms = (elapsed / 100) * 1000
        assert avg_time_ms < 100  # Should be under 100ms


class TestEdgeCases:
    """Test edge cases."""
    
    def test_empty_text(self):
        extractor = EntityExtractor()
        result = extractor.extract("")
        
        assert result.entity_count() == 0
    
    def test_no_entities(self):
        extractor = EntityExtractor()
        result = extractor.extract("This is just plain text with nothing suspicious.")
        
        assert result.entity_count() == 0
    
    def test_special_characters(self):
        extractor = EntityExtractor()
        result = extractor.extract("!@#$%^&*()_+-=[]{}|;:',.<>?/~`")
        
        # Should not crash
        assert result is not None
```

---

## Performance Benchmarks

**Target Performance:**
- Small text (< 500 chars): < 100ms
- Medium text (500-2000 chars): < 200ms
- Large text (2000-5000 chars): < 500ms

**Benchmark Results (Expected):**
```
Text Size | Avg Time | p95 Time | Entities Found
----------|----------|----------|---------------
100 chars | 15ms     | 25ms     | 2-3
500 chars | 45ms     | 80ms     | 5-8
2000 chars| 180ms    | 350ms    | 15-20
5000 chars| 420ms    | 650ms    | 30-40
```

---

## Success Criteria

- [ ] All 40 acceptance criteria met
- [ ] 100+ unit tests passing
- [ ] Performance benchmarks met
- [ ] Zero false positives on test corpus (100 samples)
- [ ] < 5% false negative rate on test corpus
- [ ] Integration with MCP agent workflow tested
- [ ] Documentation complete with examples

---

## Dependencies

- **Upstream:** Story 8.1 (Celery infrastructure not directly required, but good to have)
- **Downstream:** Stories 8.3-8.7 (all tools depend on extracted entities)

---

## Notes

- **Library Dependencies:** `phonenumbers`, standard Python `re` module
- **Extensibility:** Easy to add new entity types (e.g., social security numbers, addresses)
- **Privacy:** No extracted entities are logged or stored without user consent
- **Performance:** Using compiled regex patterns for speed

---

**Estimated Effort:** 20 hours  
**Sprint:** Week 8, Days 2-3

