"""Comprehensive unit tests for entity extraction.

This test suite covers all acceptance criteria for Story 8.2:
- Phone number extraction (various formats, international, vanity)
- URL extraction (full URLs, shortened, obfuscated)
- Email extraction (various formats, obfuscated)
- Payment details extraction (account numbers, crypto, wire instructions)
- Monetary amount extraction (various currencies and formats)
- Performance benchmarks
- Edge cases
"""

import pytest
import time
from app.services.entity_extractor import (
    EntityExtractor,
    ExtractedEntities,
    get_entity_extractor,
    extract_entities
)


class TestPhoneExtraction:
    """Test phone number extraction - AC 1-7."""
    
    def test_standard_phone_formats_us(self):
        """AC 1-2: Extract phone numbers in various US formats."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            ("+1 (800) 555-1234", "+18005551234"),
            ("1-800-555-1234", "+18005551234"),
            ("800.555.1234", "+18005551234"),
            ("(800) 555-1234", "+18005551234"),
            ("800 555 1234", "+18005551234"),
            ("+1 800-555-1234", "+18005551234"),
        ]
        
        for input_text, expected in test_cases:
            result = extractor.extract(input_text)
            assert len(result.phones) >= 1, f"Failed to extract from: {input_text}"
            assert result.phones[0]["value"] == expected, f"Expected {expected}, got {result.phones[0]['value']}"
            assert result.phones[0]["valid"] == True
    
    def test_international_phones(self):
        """AC 4: Support international phone numbers with country codes."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            ("+44 20 7946 0958", "+442079460958"),  # UK
            ("+86 10 1234 5678", "+861012345678"),  # China
            ("+33 1 23 45 67 89", "+33123456789"),  # France
            ("+61 2 1234 5678", "+61212345678"),  # Australia
            ("+91 11 2345 6789", "+911123456789"),  # India
        ]
        
        for input_text, expected in test_cases:
            result = extractor.extract(input_text)
            assert len(result.phones) >= 1, f"Failed to extract from: {input_text}"
            assert result.phones[0]["value"] == expected
    
    def test_vanity_numbers(self):
        """AC 3: Detect vanity numbers like 1-800-FLOWERS."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            "Call 1-800-FLOWERS for delivery",
            "Contact 1-800-GOTJUNK today",
            "Dial 1-888-COMCAST now",
            "1-800-CONTACTS",
        ]
        
        for text in test_cases:
            result = extractor.extract(text)
            assert len(result.phones) >= 1, f"Failed to extract vanity from: {text}"
            # Should have either a vanity type or be detected as phone
            has_vanity = any(p["type"] == "vanity" for p in result.phones)
            assert has_vanity, f"No vanity number found in: {text}"
    
    def test_multiple_phones(self):
        """AC 6: Handle multiple phone numbers in single text block."""
        extractor = EntityExtractor(filter_common_domains=False)
        text = "Call +1-800-555-1234 or +1-888-555-9999 for assistance"
        result = extractor.extract(text)
        
        assert len(result.phones) >= 2, "Should extract at least 2 phone numbers"
        phone_values = [p["value"] for p in result.phones]
        assert "+18005551234" in phone_values
        assert "+18885559999" in phone_values
    
    def test_phone_normalization_e164(self):
        """AC 5: Normalize all phone numbers to E164 format."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        # Different formats should normalize to same E164
        inputs = [
            "+1 (800) 555-1234",
            "1-800-555-1234",
            "(800) 555-1234",
            "800.555.1234",
        ]
        
        expected = "+18005551234"
        
        for text in inputs:
            result = extractor.extract(text)
            assert len(result.phones) >= 1
            assert result.phones[0]["value"] == expected
    
    def test_phone_type_detection(self):
        """Verify phone number type detection (mobile, landline, toll-free)."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        # Toll-free number
        result = extractor.extract("+1-800-555-1234")
        assert result.phones[0]["type"] == "toll_free"
        
        # Regular US number (type may vary)
        result = extractor.extract("+1-415-555-1234")
        assert result.phones[0]["type"] in ["mobile", "landline", "fixed_or_mobile"]
    
    def test_invalid_phone_filtering(self):
        """AC 7: Filter out invalid/incomplete numbers."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        # Too short
        result = extractor.extract("Call 123 today")
        assert len(result.phones) == 0
        
        # Just a year (should not be detected as phone)
        result = extractor.extract("The year 2025 was great")
        phone_2025 = any("2025" in p["value"] for p in result.phones)
        assert not phone_2025


class TestURLExtraction:
    """Test URL extraction - AC 8-14."""
    
    def test_full_urls_with_protocol(self):
        """AC 8: Extract full URLs with http/https."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            "https://example.com",
            "http://suspicious-site.com/phishing",
            "https://example.com/path?query=value&key=123",
            "https://subdomain.example.com/page",
        ]
        
        for url in test_cases:
            result = extractor.extract(url)
            assert len(result.urls) >= 1, f"Failed to extract: {url}"
            assert result.urls[0]["value"].startswith("http")
    
    def test_urls_without_protocol(self):
        """AC 9: Extract URLs without protocol and add https://."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            ("Visit example.com for details", "https://example.com"),
            ("Go to suspicious-phishing.com", "https://suspicious-phishing.com"),
            ("Check out test.co.uk", "https://test.co.uk"),
        ]
        
        for text, expected_start in test_cases:
            result = extractor.extract(text)
            assert len(result.urls) >= 1, f"Failed to extract from: {text}"
            assert result.urls[0]["value"].startswith("https://")
    
    def test_shortened_urls(self):
        """AC 10: Detect shortened URLs."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            "Click bit.ly/abc123",
            "Check out t.co/xyz789",
            "Visit tinyurl.com/test123",
            "Go to is.gd/short",
        ]
        
        for text in test_cases:
            result = extractor.extract(text)
            assert len(result.urls) >= 1, f"Failed to extract from: {text}"
            assert result.urls[0]["is_shortened"] == True
    
    def test_obfuscated_urls(self):
        """AC 11: Handle obfuscated URLs."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            ("Visit hxxps://example.com", "https://example.com"),
            ("Go to example[.]com", "https://example.com"),
            ("Check hxxp://test[.]site.com", "http://test.site.com"),
        ]
        
        for text, expected_domain in test_cases:
            result = extractor.extract(text)
            assert len(result.urls) >= 1, f"Failed to extract from: {text}"
            # Check that domain is normalized
            assert "example.com" in result.urls[0]["value"] or "test.site.com" in result.urls[0]["value"]
    
    def test_domain_filtering(self):
        """AC 13: Filter out common legitimate domains when enabled."""
        extractor_filter = EntityExtractor(filter_common_domains=True)
        extractor_no_filter = EntityExtractor(filter_common_domains=False)
        
        common_domains = [
            "Search on google.com",
            "Watch youtube.com/video",
            "Visit apple.com for details",
            "Check facebook.com",
        ]
        
        for text in common_domains:
            # With filtering
            result_filtered = extractor_filter.extract(text)
            assert len(result_filtered.urls) == 0, f"Should filter: {text}"
            
            # Without filtering
            result_no_filter = extractor_no_filter.extract(text)
            assert len(result_no_filter.urls) >= 1, f"Should extract: {text}"
    
    def test_url_normalization(self):
        """AC 14: Normalize URLs (lowercase domain)."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            ("Visit EXAMPLE.COM", "example.com"),
            ("Go to Example.COM/Path", "example.com"),
        ]
        
        for text, expected_domain in test_cases:
            result = extractor.extract(text)
            assert len(result.urls) >= 1
            assert expected_domain in result.urls[0]["domain"].lower()


class TestEmailExtraction:
    """Test email extraction - AC 15-20."""
    
    def test_standard_email_formats(self):
        """AC 15: Extract standard email formats."""
        extractor = EntityExtractor(filter_common_emails=False)
        
        test_cases = [
            "user@example.com",
            "contact@suspicious-site.com",
            "admin@test.co.uk",
            "info@subdomain.example.com",
        ]
        
        for email in test_cases:
            result = extractor.extract(email)
            assert len(result.emails) >= 1, f"Failed to extract: {email}"
            assert result.emails[0]["value"] == email.lower()
    
    def test_email_plus_addressing(self):
        """AC 16: Handle plus addressing (user+tag@example.com)."""
        extractor = EntityExtractor(filter_common_emails=False)
        
        emails = [
            "user+tag@example.com",
            "john+work@company.com",
            "test+spam@site.org",
        ]
        
        for email in emails:
            result = extractor.extract(email)
            assert len(result.emails) >= 1, f"Failed to extract: {email}"
            assert "+" in result.emails[0]["value"]
    
    def test_email_dot_addressing(self):
        """AC 17: Handle dot addressing (first.last@example.com)."""
        extractor = EntityExtractor(filter_common_emails=False)
        
        emails = [
            "first.last@example.com",
            "john.doe@company.com",
            "a.b.c@test.org",
        ]
        
        for email in emails:
            result = extractor.extract(email)
            assert len(result.emails) >= 1, f"Failed to extract: {email}"
    
    def test_obfuscated_emails(self):
        """AC 18: Detect obfuscated emails."""
        extractor = EntityExtractor(filter_common_emails=False)
        
        test_cases = [
            ("Contact user [at] example [dot] com", "user@example.com"),
            ("Email admin at test dot org", "admin@test.org"),
            ("Reach out to support (at) company (dot) com", "support@company.com"),
        ]
        
        for text, expected in test_cases:
            result = extractor.extract(text)
            assert len(result.emails) >= 1, f"Failed to extract from: {text}"
            assert result.emails[0]["value"] == expected
    
    def test_email_validation(self):
        """AC 19: Validate email format."""
        extractor = EntityExtractor(filter_common_emails=False)
        
        # Valid emails
        valid = ["user@example.com", "test.email@site.co.uk"]
        for email in valid:
            result = extractor.extract(email)
            assert len(result.emails) >= 1
        
        # Invalid emails (should not be extracted)
        invalid = ["notanemail", "missing@domain", "@nodomain.com", "no-at-sign.com"]
        for email in invalid:
            result = extractor.extract(email)
            # May extract 0 or may extract but be invalid format
            if len(result.emails) > 0:
                # If extracted, should not match the invalid input exactly
                assert result.emails[0]["value"] != email
    
    def test_email_domain_filtering(self):
        """AC 20: Filter out common email providers when enabled."""
        extractor_filter = EntityExtractor(filter_common_emails=True)
        extractor_no_filter = EntityExtractor(filter_common_emails=False)
        
        common_emails = [
            "user@gmail.com",
            "test@yahoo.com",
            "contact@outlook.com",
        ]
        
        for email in common_emails:
            # With filtering
            result_filtered = extractor_filter.extract(email)
            assert len(result_filtered.emails) == 0, f"Should filter: {email}"
            
            # Without filtering
            result_no_filter = extractor_no_filter.extract(email)
            assert len(result_no_filter.emails) >= 1, f"Should extract: {email}"


class TestPaymentExtraction:
    """Test payment details extraction - AC 21-25."""
    
    def test_account_numbers(self):
        """AC 21: Detect bank account numbers."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            "Send payment to Account: 123456789",
            "Acct: 987654321",
            "Account #: 111222333",
            "acc 123456789012",
        ]
        
        for text in test_cases:
            result = extractor.extract(text)
            payments = [p for p in result.payments if p["type"] == "account_number"]
            assert len(payments) >= 1, f"Failed to extract from: {text}"
    
    def test_bitcoin_addresses(self):
        """AC 22: Extract Bitcoin addresses."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        btc_addresses = [
            "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa",  # Genesis block
            "3J98t1WpEZ73CNmYviecrnyiWrnqRhWNLy",  # P2SH address
            "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",  # Bech32
        ]
        
        for address in btc_addresses:
            text = f"Send BTC to {address}"
            result = extractor.extract(text)
            payments = [p for p in result.payments if p["type"] == "bitcoin"]
            assert len(payments) >= 1, f"Failed to extract: {address}"
    
    def test_wire_transfer_instructions(self):
        """AC 23: Detect wire transfer instructions."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            "Wire to account immediately",
            "Send money to the following account",
            "Transfer funds to this account",
            "Wire payment now",
        ]
        
        for text in test_cases:
            result = extractor.extract(text)
            payments = [p for p in result.payments if p["type"] == "wire_instruction"]
            assert len(payments) >= 1, f"Failed to extract from: {text}"
    
    def test_routing_numbers(self):
        """AC 24: Identify routing numbers."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            "Routing: 123456789",
            "RTN: 987654321",
            "Routing number: 111222333",
        ]
        
        for text in test_cases:
            result = extractor.extract(text)
            payments = [p for p in result.payments if p["type"] == "routing_number"]
            assert len(payments) >= 1, f"Failed to extract from: {text}"
    
    def test_payment_app_usernames(self):
        """AC 25: Handle payment app usernames ($CashApp, @Venmo)."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            ("Send to $MyUsername", "cashapp"),
            ("Pay @VenmoUser", "venmo"),
            ("$CashAppUser", "cashapp"),
            ("@VenmoPayment", "venmo"),
        ]
        
        for text, expected_type in test_cases:
            result = extractor.extract(text)
            payments = [p for p in result.payments if p["type"] == expected_type]
            assert len(payments) >= 1, f"Failed to extract from: {text}"


class TestMonetaryAmounts:
    """Test monetary amount extraction - AC 26-30."""
    
    def test_amounts_with_symbols(self):
        """AC 26: Extract amounts with currency symbols."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            ("Send $500", 500.0, "USD"),
            ("Pay €100", 100.0, "EUR"),
            ("Transfer £50", 50.0, "GBP"),
            ("₹1000 required", 1000.0, "INR"),
        ]
        
        for text, expected_amount, expected_currency in test_cases:
            result = extractor.extract(text)
            assert len(result.amounts) >= 1, f"Failed to extract from: {text}"
            assert result.amounts[0]["currency"] == expected_currency, f"Currency mismatch for {text}"
            assert result.amounts[0]["amount_numeric"] == expected_amount, f"Amount mismatch for {text}: got {result.amounts[0]['amount_numeric']}, expected {expected_amount}"
    
    def test_written_amounts(self):
        """AC 27: Detect written amounts (USD 1000, 1000 dollars)."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            "Pay USD 1000 immediately",
            "Transfer 500 dollars",
            "Send 100 EUR",
            "1000 pounds required",
        ]
        
        for text in test_cases:
            result = extractor.extract(text)
            assert len(result.amounts) >= 1, f"Failed to extract from: {text}"
    
    def test_various_amount_formats(self):
        """AC 28: Handle various formats ($1,000.00, 1.000,00 EUR)."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            "$1,000.00",
            "$10,500.50",
            "€1,234.56",
            "£100.00",
        ]
        
        for text in test_cases:
            result = extractor.extract(text)
            assert len(result.amounts) >= 1, f"Failed to extract from: {text}"
            assert result.amounts[0]["amount_numeric"] > 0
    
    def test_payment_requests(self):
        """AC 29: Identify payment requests."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            "Send $500 immediately",
            "Pay $100 now",
            "Transfer $1000 today",
        ]
        
        for text in test_cases:
            result = extractor.extract(text)
            # Should extract both amount and urgent payment indicator
            assert len(result.amounts) >= 1, f"Failed to extract amount from: {text}"
            has_urgent = any(p["type"] == "urgent_payment_request" for p in result.payments)
            assert has_urgent, f"Failed to detect urgency in: {text}"
    
    def test_currency_extraction(self):
        """AC 30: Extract currency type."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        test_cases = [
            ("$100", "USD"),
            ("€200", "EUR"),
            ("£300", "GBP"),
            ("¥400", "JPY"),
        ]
        
        for text, expected_currency in test_cases:
            result = extractor.extract(text)
            assert len(result.amounts) >= 1
            assert result.amounts[0]["currency"] == expected_currency


class TestPerformanceAndQuality:
    """Test performance and quality - AC 31-36."""
    
    def test_small_text_performance(self):
        """AC 31: Processing time < 100ms for typical OCR text (500 chars)."""
        extractor = EntityExtractor()
        
        text = (
            "Call +1-800-555-1234 or visit example.com. "
            "Email: user@test.com. Send $500 to account 123456789. "
        ) * 5  # ~500 chars
        
        start = time.time()
        result = extractor.extract(text)
        elapsed = (time.time() - start) * 1000  # Convert to ms
        
        assert elapsed < 100, f"Took {elapsed}ms, expected < 100ms"
        assert result.entity_count() > 0
    
    def test_large_text_performance(self):
        """AC 32: Processing time < 500ms for large text blocks (5000 chars)."""
        extractor = EntityExtractor()
        
        # Generate ~5000 character text with multiple entities
        text = (
            "Contact us at +1-800-555-1234 or visit https://example.com. "
            "Email support@test.com. Transfer $1000 to account 123456789. "
            "Urgent: wire money immediately! Bitcoin: 1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa. "
            "Call now or visit suspicious-site.org. Send payment to @VenmoUser or $CashApp. "
        ) * 20  # ~5000+ chars
        
        start = time.time()
        result = extractor.extract(text)
        elapsed = (time.time() - start) * 1000
        
        assert elapsed < 500, f"Took {elapsed}ms, expected < 500ms"
        assert result.entity_count() > 0
    
    def test_structured_data_output(self):
        """AC 33: Returns structured data with all entity types."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        text = (
            "Call +1-800-555-1234, visit example.com, "
            "email user@test.com, send $500 to account 123456789"
        )
        
        result = extractor.extract(text)
        data = result.to_dict()
        
        # Check structure
        assert "phones" in data
        assert "urls" in data
        assert "emails" in data
        assert "payments" in data
        assert "amounts" in data
        
        # Check that all are lists
        for key in data:
            assert isinstance(data[key], list)
    
    def test_empty_text_handling(self):
        """AC 36: Handle edge case - empty text."""
        extractor = EntityExtractor()
        
        result = extractor.extract("")
        assert result.entity_count() == 0
        
        result = extractor.extract("   ")
        assert result.entity_count() == 0
        
        result = extractor.extract(None)
        assert result.entity_count() == 0
    
    def test_special_characters_handling(self):
        """AC 36: Handle edge case - special characters and Unicode."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        # Should not crash on special characters
        special_texts = [
            "!@#$%^&*()_+-=[]{}|;:',.<>?/~`",
            "你好世界 +1-800-555-1234",
            "Café ☕ email@example.com",
            "🔥 Hot deal! Visit site.com 💰",
        ]
        
        for text in special_texts:
            result = extractor.extract(text)
            assert result is not None
    
    def test_very_long_text(self):
        """AC 36: Handle edge case - very long text."""
        extractor = EntityExtractor()
        
        # 50,000 character text
        long_text = "This is a test. " * 3000
        
        result = extractor.extract(long_text)
        assert result is not None


class TestRealWorldScenarios:
    """Test with real-world scam scenarios."""
    
    def test_phishing_email_scenario(self):
        """Extract entities from typical phishing email."""
        extractor = EntityExtractor(filter_common_domains=False, filter_common_emails=False)
        
        text = """
        URGENT: Your bank account has been compromised!
        
        Call us immediately at +1-800-555-FAKE
        Or visit secure-bank-login.com
        
        Send verification payment of $500 to account: 987654321
        Routing: 123456789
        
        Contact: fraud@fake-bank.com
        """
        
        result = extractor.extract(text)
        
        # Should extract phone, URL, email, account number, routing, amount
        assert len(result.phones) >= 1
        assert len(result.urls) >= 1
        assert len(result.emails) >= 1
        assert len(result.amounts) >= 1
        
        # Should detect urgent payment request
        has_account = any(p["type"] == "account_number" for p in result.payments)
        has_routing = any(p["type"] == "routing_number" for p in result.payments)
        assert has_account
        assert has_routing
    
    def test_crypto_scam_scenario(self):
        """Extract entities from cryptocurrency scam."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        text = """
        Send 0.5 BTC to: 1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa
        
        Visit our site: crypto-doubler.com
        Contact: admin@crypto-scam.com
        
        Double your money! Send now!
        """
        
        result = extractor.extract(text)
        
        # Should extract Bitcoin address, URL, email
        has_bitcoin = any(p["type"] == "bitcoin" for p in result.payments)
        assert has_bitcoin
        assert len(result.urls) >= 1
        assert len(result.emails) >= 1
    
    def test_mixed_international_scenario(self):
        """Extract entities with international formats."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        text = """
        Contact our offices:
        US: +1-800-555-1234
        UK: +44 20 7946 0958
        China: +86 10 1234 5678
        
        Payment: €1,000 or $1,200
        """
        
        result = extractor.extract(text)
        
        # Should extract multiple international phone numbers
        assert len(result.phones) >= 3
        
        # Should extract multiple currency amounts
        assert len(result.amounts) >= 2


class TestHelperMethods:
    """Test helper methods and utilities."""
    
    def test_has_entities_method(self):
        """Test ExtractedEntities.has_entities() method."""
        # Empty result
        empty = ExtractedEntities([], [], [], [], [])
        assert empty.has_entities() == False
        
        # With entities
        with_data = ExtractedEntities([{"value": "+18005551234"}], [], [], [], [])
        assert with_data.has_entities() == True
    
    def test_entity_count_method(self):
        """Test ExtractedEntities.entity_count() method."""
        result = ExtractedEntities(
            phones=[{"value": "+18005551234"}],
            urls=[{"value": "https://example.com"}],
            emails=[{"value": "user@test.com"}],
            payments=[{"type": "bitcoin", "value": "1ABC..."}],
            amounts=[{"amount": "500", "currency": "USD"}]
        )
        
        assert result.entity_count() == 5
    
    def test_high_risk_indicators(self):
        """Test ExtractedEntities.has_high_risk_indicators() method."""
        # No high risk
        low_risk = ExtractedEntities(
            phones=[{"value": "+18005551234"}],
            urls=[],
            emails=[],
            payments=[],
            amounts=[{"amount": "10", "amount_numeric": 10, "currency": "USD"}]
        )
        assert low_risk.has_high_risk_indicators() == False
        
        # With Bitcoin (high risk)
        high_risk = ExtractedEntities(
            phones=[],
            urls=[],
            emails=[],
            payments=[{"type": "bitcoin", "value": "1ABC..."}],
            amounts=[]
        )
        assert high_risk.has_high_risk_indicators() == True
        
        # With large amount (high risk)
        large_amount = ExtractedEntities(
            phones=[],
            urls=[],
            emails=[],
            payments=[],
            amounts=[{"amount": "5000", "amount_numeric": 5000, "currency": "USD"}]
        )
        assert large_amount.has_high_risk_indicators() == True
    
    def test_singleton_getter(self):
        """Test get_entity_extractor() singleton."""
        instance1 = get_entity_extractor()
        instance2 = get_entity_extractor()
        
        assert instance1 is instance2  # Should be same instance
    
    def test_convenience_function(self):
        """Test extract_entities() convenience function."""
        text = "Call +1-800-555-1234 or visit example.com"
        result = extract_entities(text, filter_common=False)
        
        assert isinstance(result, dict)
        assert "phones" in result
        assert "urls" in result
        assert len(result["phones"]) >= 1
        assert len(result["urls"]) >= 1


class TestEdgeCasesAndBoundaries:
    """Test edge cases and boundary conditions."""
    
    def test_no_entities_in_plain_text(self):
        """Test that plain text without entities returns empty result."""
        extractor = EntityExtractor()
        
        plain_texts = [
            "This is just plain text with nothing suspicious.",
            "The quick brown fox jumps over the lazy dog.",
            "No entities here, just words and sentences.",
        ]
        
        for text in plain_texts:
            result = extractor.extract(text)
            assert result.entity_count() == 0
    
    def test_duplicate_entity_handling(self):
        """Test that duplicate entities are deduplicated."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        # Same phone number repeated
        text = "Call +1-800-555-1234 or +1-800-555-1234 or (800) 555-1234"
        result = extractor.extract(text)
        
        # Should deduplicate to 1 phone number
        assert len(result.phones) == 1
    
    def test_malformed_entities(self):
        """Test handling of malformed entities."""
        extractor = EntityExtractor(filter_common_domains=False)
        
        # Malformed email (no domain)
        result = extractor.extract("Email: user@")
        assert len(result.emails) == 0
        
        # Malformed URL (just protocol)
        result = extractor.extract("Visit https://")
        assert len(result.urls) == 0
    
    def test_context_preservation(self):
        """Test that payment context is preserved."""
        extractor = EntityExtractor()
        
        text = "Wire money immediately to account 123456789 for urgent processing"
        result = extractor.extract(text)
        
        # Should have payment with context
        account_payments = [p for p in result.payments if p["type"] == "account_number"]
        assert len(account_payments) >= 1
        assert "context" in account_payments[0]
        assert len(account_payments[0]["context"]) > 0


# Performance benchmark test (can be run separately)
@pytest.mark.benchmark
class TestPerformanceBenchmarks:
    """Performance benchmarks for entity extraction."""
    
    def test_benchmark_100_extractions(self):
        """Benchmark: 100 extractions should complete quickly."""
        extractor = EntityExtractor()
        
        text = (
            "Call +1-800-555-1234 or visit example.com. "
            "Email: user@test.com. Send $500 to account 123456789."
        )
        
        start = time.time()
        for _ in range(100):
            extractor.extract(text)
        elapsed = time.time() - start
        
        avg_time_ms = (elapsed / 100) * 1000
        print(f"\nAverage extraction time: {avg_time_ms:.2f}ms")
        
        # Should average under 50ms per extraction
        assert avg_time_ms < 50


if __name__ == "__main__":
    # Run tests with pytest
    pytest.main([__file__, "-v", "--tb=short"])

