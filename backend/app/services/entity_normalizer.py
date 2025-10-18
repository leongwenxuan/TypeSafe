"""Entity normalization utilities.

This module provides utility functions for normalizing and validating
extracted entities to ensure consistency and reduce false positives.
"""

import re
from urllib.parse import urlparse, urlunparse
from typing import Optional

from app.services.entity_patterns import (
    COMMON_LEGITIMATE_DOMAINS,
    COMMON_EMAIL_DOMAINS,
    URL_SHORTENERS
)


def normalize_url(url: str) -> str:
    """
    Normalize URL to consistent format.
    
    Steps:
    1. Deobfuscate (hxxps → https, example[.]com → example.com)
    2. Add https:// if no protocol
    3. Lowercase domain only (preserve path case)
    4. Remove trailing slashes
    
    Args:
        url: Raw URL string
        
    Returns:
        Normalized URL string
        
    Examples:
        >>> normalize_url("EXAMPLE.COM")
        'https://example.com'
        >>> normalize_url("hxxps://example[.]com/path")
        'https://example.com/path'
    """
    if not url:
        return ""
    
    # Deobfuscate common patterns
    url = url.replace('hxxp://', 'http://')
    url = url.replace('hxxps://', 'https://')
    url = re.sub(r'\[?\.\]?', '.', url)  # example[.]com → example.com
    url = re.sub(r'\s+', '', url)  # Remove any whitespace
    
    # Add protocol if missing
    if not url.startswith(('http://', 'https://', 'ftp://')):
        url = 'https://' + url
    
    # Parse and normalize
    try:
        parsed = urlparse(url)
        
        # Lowercase the domain (netloc) but preserve path case
        normalized_netloc = parsed.netloc.lower()
        
        # Remove default ports
        if ':443' in normalized_netloc and parsed.scheme == 'https':
            normalized_netloc = normalized_netloc.replace(':443', '')
        elif ':80' in normalized_netloc and parsed.scheme == 'http':
            normalized_netloc = normalized_netloc.replace(':80', '')
        
        # Reconstruct URL
        normalized = urlunparse((
            parsed.scheme.lower(),
            normalized_netloc,
            parsed.path.rstrip('/') if parsed.path != '/' else '',
            parsed.params,
            parsed.query,
            ''  # Remove fragment
        ))
        
        return normalized
    except Exception:
        # If parsing fails, return cleaned version
        return url.lower()


def normalize_email(email: str) -> str:
    """
    Normalize email address to lowercase and trim whitespace.
    
    Args:
        email: Raw email address
        
    Returns:
        Normalized email address
        
    Examples:
        >>> normalize_email("User@EXAMPLE.COM  ")
        'user@example.com'
    """
    return email.lower().strip()


def extract_domain_from_url(url: str) -> str:
    """
    Extract the domain from a URL (without subdomain if possible).
    
    Args:
        url: URL string (normalized or not)
        
    Returns:
        Domain string (e.g., "example.com")
        
    Examples:
        >>> extract_domain_from_url("https://www.example.com/path")
        'example.com'
        >>> extract_domain_from_url("https://subdomain.example.co.uk/")
        'example.co.uk'
    """
    # Remove protocol if present
    domain = re.sub(r'^https?://', '', url)
    
    # Remove path, query, and fragment
    domain = domain.split('/')[0]
    domain = domain.split('?')[0]
    domain = domain.split('#')[0]
    
    # Remove port
    if ':' in domain:
        domain = domain.split(':')[0]
    
    # Lowercase
    domain = domain.lower()
    
    # Try to get the base domain (remove www, but keep subdomains for complex TLDs)
    # This is a simplified approach; for production consider using a library like tldextract
    if domain.startswith('www.'):
        domain = domain[4:]
    
    return domain


def extract_domain_from_email(email: str) -> str:
    """
    Extract domain from email address.
    
    Args:
        email: Email address
        
    Returns:
        Domain string
        
    Examples:
        >>> extract_domain_from_email("user@example.com")
        'example.com'
    """
    if '@' not in email:
        return ""
    
    return email.split('@')[1].lower()


def should_filter_domain(domain: str, filter_common: bool = True) -> bool:
    """
    Check if domain should be filtered out (common legitimate domain).
    
    Args:
        domain: Domain string
        filter_common: Whether to apply common domain filtering
        
    Returns:
        True if domain should be filtered (i.e., it's a common legitimate site)
        
    Examples:
        >>> should_filter_domain("google.com")
        True
        >>> should_filter_domain("suspicious-site.com")
        False
    """
    if not filter_common:
        return False
    
    domain = domain.lower()
    
    # Check exact match
    if domain in COMMON_LEGITIMATE_DOMAINS:
        return True
    
    # Check if it's a subdomain of a common domain
    for common_domain in COMMON_LEGITIMATE_DOMAINS:
        if domain.endswith('.' + common_domain):
            return True
    
    return False


def should_filter_email_domain(domain: str, filter_common: bool = True) -> bool:
    """
    Check if email domain should be filtered out.
    
    Args:
        domain: Email domain
        filter_common: Whether to apply filtering
        
    Returns:
        True if domain should be filtered
    """
    if not filter_common:
        return False
    
    return domain.lower() in COMMON_EMAIL_DOMAINS


def is_url_shortener(domain: str) -> bool:
    """
    Check if domain is a known URL shortener.
    
    Args:
        domain: Domain string
        
    Returns:
        True if domain is a URL shortener
        
    Examples:
        >>> is_url_shortener("bit.ly")
        True
        >>> is_url_shortener("example.com")
        False
    """
    return domain.lower() in URL_SHORTENERS


def deobfuscate_text(text: str) -> str:
    """
    Deobfuscate text to make entities easier to extract.
    
    Handles patterns like:
    - "user [at] example [dot] com" → "user@example.com"
    - "example [.] com" → "example.com"
    - "user AT example DOT com" → "user@example.com"
    
    Args:
        text: Text to deobfuscate
        
    Returns:
        Deobfuscated text
    """
    # Replace [at] and variants with @
    text = re.sub(r'\s*\[at\]\s*', '@', text, flags=re.IGNORECASE)
    text = re.sub(r'\s+at\s+', '@', text, flags=re.IGNORECASE)
    text = re.sub(r'\s*\(at\)\s*', '@', text, flags=re.IGNORECASE)
    
    # Replace [dot] and variants with .
    text = re.sub(r'\s*\[dot\]\s*', '.', text, flags=re.IGNORECASE)
    text = re.sub(r'\s+dot\s+', '.', text, flags=re.IGNORECASE)
    text = re.sub(r'\s*\(dot\)\s*', '.', text, flags=re.IGNORECASE)
    
    # Replace [.] with .
    text = re.sub(r'\[\.\]', '.', text)
    
    return text


def is_valid_email_format(email: str) -> bool:
    """
    Perform basic email format validation.
    
    Args:
        email: Email address to validate
        
    Returns:
        True if email format is valid
    """
    # Must have exactly one @
    if email.count('@') != 1:
        return False
    
    # Split into username and domain
    parts = email.split('@')
    if len(parts) != 2:
        return False
    
    username, domain = parts
    
    # Username and domain must not be empty
    if not username or not domain:
        return False
    
    # Domain must have at least one dot
    if '.' not in domain:
        return False
    
    # Domain parts must not be empty
    domain_parts = domain.split('.')
    if any(not part for part in domain_parts):
        return False
    
    # Check for consecutive dots
    if '..' in email:
        return False
    
    # Basic character validation (simplified)
    # Username can have: letters, numbers, dots, underscores, hyphens, plus
    username_pattern = re.compile(r'^[a-z0-9._%+-]+$', re.IGNORECASE)
    if not username_pattern.match(username):
        return False
    
    # Domain should be alphanumeric with dots and hyphens
    domain_pattern = re.compile(r'^[a-z0-9.-]+$', re.IGNORECASE)
    if not domain_pattern.match(domain):
        return False
    
    # TLD should be at least 2 characters
    tld = domain_parts[-1]
    if len(tld) < 2:
        return False
    
    return True


def normalize_phone_display(phone_e164: str) -> str:
    """
    Convert E164 phone number to a more readable format.
    
    Args:
        phone_e164: Phone number in E164 format (e.g., "+18005551234")
        
    Returns:
        Formatted phone number (e.g., "+1 (800) 555-1234")
    """
    if not phone_e164 or not phone_e164.startswith('+'):
        return phone_e164
    
    # Simple US number formatting
    if phone_e164.startswith('+1') and len(phone_e164) == 12:
        return f"+1 ({phone_e164[2:5]}) {phone_e164[5:8]}-{phone_e164[8:]}"
    
    # For other countries, just return E164
    return phone_e164


def extract_numeric_amount(amount_str: str) -> Optional[float]:
    """
    Extract numeric value from amount string.
    
    Args:
        amount_str: String containing monetary amount
        
    Returns:
        Float value or None if cannot parse
        
    Examples:
        >>> extract_numeric_amount("$1,000.50")
        1000.5
        >>> extract_numeric_amount("€ 1.234,56")
        1234.56
    """
    # Remove currency symbols and letters
    cleaned = re.sub(r'[^\d.,\s-]', '', amount_str)
    cleaned = cleaned.strip()
    
    if not cleaned:
        return None
    
    # Handle European format (1.234,56) vs US format (1,234.56)
    # Heuristic: if there's a comma after the last dot, it's European
    if ',' in cleaned and '.' in cleaned:
        # Both present - determine format
        last_comma = cleaned.rfind(',')
        last_dot = cleaned.rfind('.')
        
        if last_comma > last_dot:
            # European: 1.234,56
            cleaned = cleaned.replace('.', '').replace(',', '.')
        else:
            # US: 1,234.56
            cleaned = cleaned.replace(',', '')
    elif ',' in cleaned:
        # Only comma - could be thousands separator or decimal
        # If comma is in last 3 positions, likely decimal
        if len(cleaned) - cleaned.rfind(',') <= 3:
            cleaned = cleaned.replace(',', '.')
        else:
            cleaned = cleaned.replace(',', '')
    
    # Remove spaces
    cleaned = cleaned.replace(' ', '')
    
    try:
        return float(cleaned)
    except ValueError:
        return None


def detect_currency_symbol(text: str) -> Optional[str]:
    """
    Detect currency symbol in text and return currency code.
    
    Args:
        text: Text containing currency symbol
        
    Returns:
        Currency code (e.g., "USD", "EUR") or None
    """
    currency_map = {
        '$': 'USD',
        '€': 'EUR',
        '£': 'GBP',
        '¥': 'JPY',
        '₹': 'INR',
        '₽': 'RUB',
        'C$': 'CAD',
        'A$': 'AUD',
        'CHF': 'CHF',
        'HK$': 'HKD',
        'S$': 'SGD',
        '₩': 'KRW',
        '₪': 'ILS',
        '฿': 'THB',
        '₱': 'PHP',
    }
    
    for symbol, code in currency_map.items():
        if symbol in text:
            return code
    
    # Check for currency codes
    currency_codes = ['USD', 'EUR', 'GBP', 'JPY', 'CNY', 'INR', 'AUD', 'CAD', 
                      'CHF', 'HKD', 'SGD', 'KRW', 'BTC', 'ETH']
    
    text_upper = text.upper()
    for code in currency_codes:
        if code in text_upper:
            return code
    
    return None

