"""Regex patterns for entity extraction.

This module contains all the regex patterns used by the EntityExtractor
to identify and extract different types of entities from text.
"""

import re
from typing import List

# URL patterns - Multiple patterns to catch various URL formats
URL_PATTERNS: List[re.Pattern] = [
    # Full URLs with protocol (http/https)
    re.compile(r'https?://[^\s<>"{}|\\^`\[\]]+', re.IGNORECASE),
    
    # URLs without protocol but with common TLDs (e.g., example.com)
    # Matches domain.tld/optional-path but not plain words
    re.compile(
        r'\b(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}(?:/[^\s<>"{}|\\^`\[\]]*)?',
        re.IGNORECASE
    ),
    
    # Obfuscated URLs with hxxp/hxxps
    re.compile(r'hxxps?://[^\s<>"{}|\\^`\[\]]+', re.IGNORECASE),
    
    # URLs with brackets for obfuscation (e.g., example[.]com)
    re.compile(
        r'\b(?:[a-z0-9-]+(?:\[?\.\]?|\.))+[a-z]{2,}(?:/[^\s]*)?',
        re.IGNORECASE
    ),
]

# Email patterns
EMAIL_PATTERNS: List[re.Pattern] = [
    # Standard email format: username@domain.tld
    re.compile(
        r'\b[a-z0-9][a-z0-9._%+-]*[a-z0-9]@[a-z0-9][a-z0-9.-]*\.[a-z]{2,}\b',
        re.IGNORECASE
    ),
    
    # Also catch single character usernames
    re.compile(
        r'\b[a-z0-9][a-z0-9._%+-]*@[a-z0-9][a-z0-9.-]*\.[a-z]{2,}\b',
        re.IGNORECASE
    ),
]

# Payment patterns - Dictionary mapping pattern names to compiled regex
PAYMENT_PATTERNS = {
    # Bank account numbers - Matches "Account: 12345678" or "Acct #: 123456789"
    "account_number": re.compile(
        r'(?:account|acct|acc)[\s:#]*(\d{8,20})',
        re.IGNORECASE
    ),
    
    # Routing numbers - US banking routing numbers (9 digits)
    "routing_number": re.compile(
        r'(?:routing|rtn|routing\s*number)[\s:#]*(\d{9})',
        re.IGNORECASE
    ),
    
    # Bitcoin addresses - Standard Bitcoin address format
    # Starts with 1, 3, or bc1, followed by alphanumeric chars
    "bitcoin": re.compile(
        r'\b(?:1[a-km-zA-HJ-NP-Z1-9]{25,34}|3[a-km-zA-HJ-NP-Z1-9]{25,34}|bc1[a-zA-HJ-NP-Z0-9]{39,59})\b'
    ),
    
    # Ethereum addresses - 0x followed by 40 hex characters
    "ethereum": re.compile(
        r'\b0x[a-fA-F0-9]{40}\b'
    ),
    
    # Venmo usernames - @username format
    "venmo": re.compile(
        r'(?:@[a-zA-Z0-9_-]{1,30})\b'
    ),
    
    # Cash App usernames - $username format
    "cashapp": re.compile(
        r'\$[a-zA-Z][a-zA-Z0-9_-]{0,29}\b'
    ),
    
    # Wire transfer instructions - Common wire transfer keywords
    "wire_instruction": re.compile(
        r'\b(?:wire|send|transfer)[\s]+(?:to|money|funds|payment)',
        re.IGNORECASE
    ),
    
    # IBAN - International Bank Account Number
    "iban": re.compile(
        r'\b[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}\b'
    ),
    
    # SWIFT/BIC codes
    "swift": re.compile(
        r'\b[A-Z]{6}[A-Z0-9]{2}(?:[A-Z0-9]{3})?\b'
    ),
}

# Monetary amount patterns
AMOUNT_PATTERNS: List[re.Pattern] = [
    # Currency symbols with amounts (e.g., $500, €100.50, £1,000.00)
    re.compile(r'[$€£¥₹₽]\s*\d+(?:[,\s]\d{3})*(?:\.\d{2})?', re.IGNORECASE),
    
    # Currency codes followed by amounts (e.g., USD 1000, EUR 500.50)
    re.compile(
        r'\b(?:USD|EUR|GBP|JPY|CNY|INR|AUD|CAD|CHF|HKD|SGD)\s+\d+(?:[,\s]\d{3})*(?:\.\d{2})?\b',
        re.IGNORECASE
    ),
    
    # Amounts with currency codes (e.g., 1000 USD, 500.50 EUR)
    re.compile(
        r'\b\d+(?:[,\s]\d{3})*(?:\.\d{2})?\s+(?:USD|EUR|GBP|JPY|CNY|INR|AUD|CAD|CHF|HKD|SGD|dollars?|euros?|pounds?)\b',
        re.IGNORECASE
    ),
    
    # Bitcoin amounts (e.g., 0.5 BTC, 1000 satoshis)
    re.compile(
        r'\b\d+(?:\.\d+)?\s*(?:BTC|bitcoin|satoshis?|sats?)\b',
        re.IGNORECASE
    ),
]

# Additional pattern sets for filtering and validation

# Common legitimate domains to filter (reduce false positives)
COMMON_LEGITIMATE_DOMAINS = {
    # Major tech companies
    'google.com', 'youtube.com', 'facebook.com', 'twitter.com', 'x.com',
    'apple.com', 'microsoft.com', 'amazon.com', 'netflix.com',
    'linkedin.com', 'instagram.com', 'tiktok.com', 'reddit.com',
    'wikipedia.org', 'github.com', 'stackoverflow.com',
    
    # Email providers
    'gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com',
    'icloud.com', 'me.com', 'mac.com', 'protonmail.com',
    'aol.com', 'mail.com', 'zoho.com',
    
    # Common services
    'paypal.com', 'venmo.com', 'cashapp.com', 'stripe.com',
    'shopify.com', 'ebay.com', 'etsy.com', 'craigslist.org',
    'ups.com', 'fedex.com', 'usps.com', 'dhl.com',
    
    # Government and official
    'irs.gov', 'usps.com', 'ssa.gov', 'usa.gov',
    'gov', 'edu', 'mil',  # TLDs
}

# Known URL shortener domains
URL_SHORTENERS = {
    'bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'ow.ly',
    'is.gd', 'buff.ly', 'adf.ly', 'bc.vc', 'tiny.cc',
    'short.link', 'shorturl.at', 'rebrand.ly', 'cutt.ly',
    'bl.ink', 'lnkd.in', 'soo.gd', 'clck.ru', 'v.gd',
}

# Common email domains to filter (reduce false positives for scam detection)
COMMON_EMAIL_DOMAINS = {
    'gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com',
    'icloud.com', 'me.com', 'mac.com', 'aol.com',
    'protonmail.com', 'mail.com', 'zoho.com', 'yandex.com',
    'gmx.com', 'tutanota.com', 'fastmail.com',
}

# Patterns that look like phone numbers but aren't (e.g., dates, IDs)
FALSE_POSITIVE_PHONE_PATTERNS: List[re.Pattern] = [
    # Dates in various formats
    re.compile(r'\b\d{4}[-/.]\d{2}[-/.]\d{2}\b'),  # 2025-10-18
    re.compile(r'\b\d{2}[-/.]\d{2}[-/.]\d{4}\b'),  # 10/18/2025
    re.compile(r'\b\d{8}\b'),  # 20251018
    
    # Common ID patterns
    re.compile(r'\b[A-Z]{2}\d{6,}\b'),  # ID123456
    re.compile(r'\b\d{3}-\d{2}-\d{4}\b'),  # SSN format (but could be phone)
]

# Vanity number pattern (e.g., 1-800-FLOWERS, +1-800-555-FAKE)
# Matches toll-free numbers with letters anywhere after the prefix
VANITY_NUMBER_PATTERN = re.compile(
    r'(?:\+?1[-.\s]?)?(?:\()?8(?:00|44|55|66|77|88)(?:\))?[-.\s]?(?:\d{1,3}[-.\s]?)?[A-Z]{3,}(?:[-.\s]?[A-Z0-9]{3,})?\b',
    re.IGNORECASE
)

# Payment request phrases that indicate urgency or pressure
URGENT_PAYMENT_PHRASES: List[re.Pattern] = [
    re.compile(r'\b(?:send|pay|transfer)[\s\$€£¥₹₽]+(?:\d+|\w+)?\s*(?:now|immediately|urgent|asap|today)\b', re.IGNORECASE),
    re.compile(r'\b(?:urgent|immediate)\s+(?:payment|transfer|wire)\b', re.IGNORECASE),
    re.compile(r'\bpay\s+within\s+\d+\s+(?:hours?|minutes?|days?)\b', re.IGNORECASE),
    re.compile(r'\b(?:account\s+will\s+be|account\s+has\s+been)\s+(?:suspended|closed|frozen)\b', re.IGNORECASE),
    re.compile(r'\bfinal\s+(?:notice|warning|reminder)\b', re.IGNORECASE),
]

# Company name patterns - Extract company names with legal suffixes or department names
COMPANY_PATTERNS: List[re.Pattern] = [
    # Singapore companies - Pte Ltd, LLP
    re.compile(
        r'\b([A-Z][a-zA-Z]+(?: [A-Z][a-zA-Z]+)*)\s+(?:Pte\.?\s*Ltd\.?|Private Limited|LLP)\b'
    ),
    
    # US companies - Inc, Corp, LLC
    re.compile(
        r'\b([A-Z][a-zA-Z]+(?: [A-Z][a-zA-Z]+)*)\s+(?:Inc\.?|Corp\.?|Corporation|LLC|L\.L\.C\.?|Co\.?)\b'
    ),
    
    # UK/Australia companies - Ltd, Limited, Pty Ltd
    re.compile(
        r'\b([A-Z][a-zA-Z]+(?: [A-Z][a-zA-Z]+)*)\s+(?:Ltd\.?|Limited|PLC|Pty\.?\s*Ltd\.?)\b'
    ),
    
    # Generic company patterns (often used in scams)
    re.compile(
        r'\b([A-Z][a-zA-Z]+(?: [A-Z][a-zA-Z]+)*)\s+(?:Company|Corporation|Services|Solutions)\b'
    ),
    
    # Department/division patterns (often scam indicators)
    # e.g., "Microsoft Security Department", "Amazon Refund Center"
    re.compile(
        r'\b([A-Z][a-zA-Z]+(?: [A-Z][a-zA-Z]+)*)\s+(?:Department|Division|Unit|Center|Centre|Team|Office)\b'
    ),
]

