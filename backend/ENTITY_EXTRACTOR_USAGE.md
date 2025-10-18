# Entity Extractor - Usage Guide

## Quick Start

```python
from app.services.entity_extractor import get_entity_extractor

# Get the singleton instance
extractor = get_entity_extractor()

# Extract entities from text
text = "Call +1-800-555-1234 or visit example.com for $500"
result = extractor.extract(text)

# Access extracted entities
print(f"Found {result.entity_count()} entities")
print(f"Phones: {result.phones}")
print(f"URLs: {result.urls}")
print(f"Emails: {result.emails}")
print(f"Payments: {result.payments}")
print(f"Amounts: {result.amounts}")

# Check for high-risk indicators
if result.has_high_risk_indicators():
    print("⚠️ High-risk content detected!")

# Convert to dictionary for JSON serialization
data = result.to_dict()
```

## Configuration Options

### Custom Filtering
```python
from app.services.entity_extractor import EntityExtractor

# Disable common domain filtering (extract all domains)
extractor = EntityExtractor(
    filter_common_domains=False,
    filter_common_emails=False,
    default_region="US"
)

result = extractor.extract(text)
```

### Convenience Function
```python
from app.services.entity_extractor import extract_entities

# Quick extraction with default settings
entities = extract_entities(text, filter_common=True)
# Returns: {"phones": [...], "urls": [...], ...}
```

## Entity Types

### Phone Numbers
```python
{
    "value": "+18005551234",          # E164 normalized
    "original": "1-800-555-1234",     # As found in text
    "type": "toll_free",              # mobile, landline, toll_free, etc.
    "country": "US",                  # Country code
    "valid": true,                    # Is valid number
    "is_possible": true               # Could be valid
}
```

### URLs
```python
{
    "value": "https://example.com",   # Normalized URL
    "original": "example.com",        # As found in text
    "domain": "example.com",          # Extracted domain
    "is_shortened": false             # Is URL shortener
}
```

### Emails
```python
{
    "value": "user@example.com",      # Normalized (lowercase)
    "original": "User@Example.com",   # As found in text
    "domain": "example.com"           # Email domain
}
```

### Payment Details
```python
{
    "type": "bitcoin",                # account_number, routing_number, bitcoin, venmo, cashapp, etc.
    "value": "1A1zP1eP...",          # Extracted value
    "context": "Send BTC to 1A1..."   # Surrounding text (20 chars each side)
}
```

### Monetary Amounts
```python
{
    "amount": "500.0",                # String representation
    "amount_numeric": 500.0,          # Numeric value
    "currency": "USD",                # Currency code
    "original": "$500"                # As found in text
}
```

## Real-World Examples

### Example 1: Phishing Email
```python
text = """
URGENT: Your account has been compromised!
Call +1-800-555-FAKE immediately.
Send $500 to account 123456789 (routing: 987654321)
Contact: fraud@fake-bank.com
"""

result = extractor.extract(text)

# Extract specific entity types
phones = result.phones  # ["+1-800-555-FAKE" (vanity)]
urls = result.urls      # []
emails = result.emails  # ["fraud@fake-bank.com"]
payments = result.payments  # [account_number, routing_number, urgent_payment_request]
amounts = result.amounts    # [{"amount_numeric": 500.0, "currency": "USD"}]
```

### Example 2: Cryptocurrency Scam
```python
text = """
Double your Bitcoin!
Send 0.5 BTC to: 1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa
Visit: crypto-doubler.com
"""

result = extractor.extract(text)

# Check for high-risk indicators
if result.has_high_risk_indicators():
    # Has Bitcoin address - high risk
    for payment in result.payments:
        if payment["type"] == "bitcoin":
            print(f"⚠️ Bitcoin address detected: {payment['value']}")
```

### Example 3: Multi-Language Support
```python
text = """
Contact our offices:
US: +1-800-555-1234
UK: +44 20 7946 0958
China: +86 10 1234 5678

Payment: €1,000 or $1,200
"""

result = extractor.extract(text)

# Extract international phone numbers
for phone in result.phones:
    print(f"{phone['country']}: {phone['value']}")
# Output:
# US: +18005551234
# GB: +442079460958
# CN: +861012345678

# Extract multiple currencies
for amount in result.amounts:
    print(f"{amount['currency']} {amount['amount_numeric']}")
# Output:
# EUR 1000.0
# USD 1200.0
```

## Integration with MCP Agent

### Routing Logic
```python
from app.services.entity_extractor import get_entity_extractor

def analyze_text(text: str):
    extractor = get_entity_extractor()
    entities = extractor.extract(text)
    
    if not entities.has_entities():
        # Fast path - no entities to investigate
        return analyze_with_gemini(text)
    
    # Agent path - has entities to investigate
    return enqueue_mcp_agent_task(text, entities)

def enqueue_mcp_agent_task(text: str, entities):
    """Route to appropriate tools based on entity types."""
    
    # For each phone number -> Story 8.3 (Scam DB), 8.4 (Exa), 8.6 (Validator)
    for phone in entities.phones:
        check_scam_database(phone["value"])
        search_web_for_reports(phone["value"])
        validate_phone_number(phone["value"])
    
    # For each URL -> Story 8.3 (Scam DB), 8.4 (Exa), 8.5 (Domain Reputation)
    for url in entities.urls:
        check_scam_database(url["domain"])
        check_domain_reputation(url["domain"])
        search_web_for_phishing(url["domain"])
    
    # For each email -> Story 8.3 (Scam DB), 8.4 (Exa)
    for email in entities.emails:
        check_scam_database(email["value"])
        search_web_for_spam_reports(email["value"])
    
    # Aggregate results and generate verdict
    return generate_agent_verdict(entities, tool_results)
```

## Performance

- **Small text (< 500 chars)**: < 50ms average
- **Large text (5000 chars)**: < 200ms average
- **Memory efficient**: Singleton pattern, compiled regex
- **Thread-safe**: Immutable patterns, no shared state

## Error Handling

```python
# Graceful handling of edge cases
result = extractor.extract("")           # Returns empty result
result = extractor.extract(None)         # Returns empty result
result = extractor.extract("!@#$%^&*")  # Returns empty result (no entities)

# Invalid entities are filtered automatically
result = extractor.extract("Email: invalid@")  # No emails extracted
```

## Best Practices

1. **Use Singleton**: Call `get_entity_extractor()` instead of creating new instances
2. **Filter Wisely**: Enable filtering for user-facing analysis, disable for testing
3. **Check has_entities()**: Before routing to agent path
4. **Check has_high_risk_indicators()**: For priority routing
5. **Use to_dict()**: For JSON serialization and API responses

## Testing

```python
import pytest
from app.services.entity_extractor import EntityExtractor

def test_custom_extraction():
    extractor = EntityExtractor(filter_common_domains=False)
    
    text = "Visit google.com or call +1-800-555-1234"
    result = extractor.extract(text)
    
    assert len(result.urls) >= 1  # google.com extracted (no filtering)
    assert len(result.phones) >= 1  # Phone extracted
    assert result.phones[0]["value"] == "+18005551234"  # E164 format
```

## Troubleshooting

### "No phone numbers extracted"
- Check if phone number is valid (has country code or is in default region)
- Vanity numbers (1-800-FLOWERS) are detected separately
- Very short numbers (< 7 digits) are filtered

### "URL not extracted"
- Check if URL has valid TLD (.com, .org, etc.)
- Very short domains (< 5 chars) may be filtered
- Enable `filter_common_domains=False` for testing

### "Email not extracted"
- Check if email has valid format (user@domain.tld)
- Domain must have at least one dot
- Enable `filter_common_emails=False` to see all emails

## Support

For issues or questions:
- See test file: `tests/test_entity_extractor.py` for 48 examples
- See implementation: `app/services/entity_extractor.py`
- See patterns: `app/services/entity_patterns.py`

