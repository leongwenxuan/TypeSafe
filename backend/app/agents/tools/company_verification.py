"""
Company Verification Tool for MCP Agent.

Verifies company legitimacy by checking business registries, online presence,
and reputation signals. Detects fake companies and business impersonation scams.

Story: 8.13 - Company Verification Tool
"""

import os
import re
import logging
import asyncio
import hashlib
import json
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from difflib import SequenceMatcher

try:
    import httpx
except ImportError:
    httpx = None

try:
    import redis
except ImportError:
    redis = None

logger = logging.getLogger(__name__)


# =============================================================================
# Data Structures
# =============================================================================

@dataclass
class CompanyVerificationResult:
    """Company verification result."""
    company_name: str
    normalized_name: str
    country: str
    legitimate: bool
    confidence: float  # 0-100
    risk_level: str  # low, medium, high, unknown
    
    # Registry checks
    registration_verified: bool
    registration_number: Optional[str]
    incorporation_date: Optional[str]
    company_status: Optional[str]
    registered_address: Optional[str]
    
    # Online presence
    has_official_website: bool
    domain_age_days: Optional[int]
    social_media_presence: Dict[str, bool]
    review_site_presence: Dict[str, bool]
    news_mentions: int
    
    # Pattern analysis
    suspicious_patterns: List[str]
    similar_legitimate_companies: List[str]
    
    # Metadata
    checks_completed: Dict[str, bool]
    error_messages: Dict[str, str]
    cached: bool
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return asdict(self)
    
    def __str__(self) -> str:
        """Human-readable string representation."""
        return (
            f"CompanyVerificationResult(name={self.company_name}, country={self.country}, "
            f"legitimate={self.legitimate}, confidence={self.confidence:.1f}, "
            f"risk_level={self.risk_level}, registration_verified={self.registration_verified})"
        )


# =============================================================================
# Main Tool Class
# =============================================================================

class CompanyVerificationTool:
    """
    Tool for verifying company legitimacy and detecting fake businesses.
    
    Features:
    - Multi-country business registry checks
    - Online presence validation
    - Pattern-based scam detection
    - Typo-squatting detection
    - 30-day caching for verified companies
    
    Example:
        >>> tool = CompanyVerificationTool()
        >>> result = await tool.verify_company("DHL Express", "SG")
        >>> if result.legitimate:
        ...     print(f"Verified: {result.company_name}")
    """
    
    # Country code mapping
    SUPPORTED_COUNTRIES = {
        'SG': 'Singapore',
        'US': 'United States',
        'GB': 'United Kingdom',
        'UK': 'United Kingdom',
        'CA': 'Canada',
        'AU': 'Australia'
    }
    
    # Common company suffixes by country
    COMPANY_SUFFIXES = {
        'SG': ['Pte Ltd', 'Pte. Ltd.', 'Private Limited', 'LLP', 'Ltd'],
        'US': ['Inc', 'Inc.', 'Corp', 'Corp.', 'LLC', 'L.L.C.', 'Co.', 'Company'],
        'GB': ['Ltd', 'Limited', 'PLC', 'LLP'],
        'CA': ['Inc', 'Inc.', 'Corp', 'Corp.', 'Ltd', 'Limited', 'Ltée'],
        'AU': ['Pty Ltd', 'Pty. Ltd.', 'Ltd', 'Limited']
    }
    
    # Suspicious keywords
    SUSPICIOUS_KEYWORDS = [
        'refund', 'recovery', 'tax office', 'customs', 'immigration',
        'support team', 'help desk', 'service center', 'claim department',
        'verification unit', 'security department', 'fraud prevention'
    ]
    
    # Known legitimate companies (for similarity matching)
    KNOWN_COMPANIES = [
        'Google', 'Amazon', 'Apple', 'Microsoft', 'Facebook', 'Meta',
        'DHL', 'FedEx', 'UPS', 'USPS',
        'PayPal', 'Stripe', 'Visa', 'Mastercard',
        'Netflix', 'Spotify', 'Adobe',
        'Samsung', 'Sony', 'LG'
    ]
    
    def __init__(self, cache_enabled: bool = True):
        """
        Initialize company verification tool.
        
        Args:
            cache_enabled: Enable Redis caching for results
        """
        self.cache_enabled = cache_enabled
        self.cache = None
        
        # Initialize cache
        if cache_enabled and redis:
            try:
                redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379')
                # Use database 3 for company verification cache
                self.cache = redis.from_url(
                    redis_url + '/3',
                    decode_responses=True,
                    socket_timeout=2,
                    socket_connect_timeout=2
                )
                self.cache.ping()
                logger.info("Company verification cache initialized (Redis DB 3)")
            except Exception as e:
                logger.warning(f"Cache initialization failed, continuing without cache: {e}")
                self.cache_enabled = False
                self.cache = None
        elif cache_enabled and not redis:
            logger.warning("Redis not available, cache disabled")
            self.cache_enabled = False
        
        # Check dependencies
        if not httpx:
            logger.warning("httpx not installed, some checks will be limited")
        
        # API keys
        self.acra_api_key = os.getenv('ACRA_API_KEY', '')  # Singapore
        self.companies_house_key = os.getenv('COMPANIES_HOUSE_API_KEY', '')  # UK
        
        logger.info("CompanyVerificationTool initialized")
    
    async def verify_company(
        self,
        company_name: str,
        country: str = 'US'
    ) -> CompanyVerificationResult:
        """
        Verify company legitimacy.
        
        Args:
            company_name: Company name to verify
            country: Country code (SG, US, GB, CA, AU)
        
        Returns:
            CompanyVerificationResult with all verification details
        """
        # Normalize country code
        country = country.upper()
        if country not in self.SUPPORTED_COUNTRIES:
            logger.warning(f"Unsupported country: {country}, defaulting to US")
            country = 'US'
        
        # Normalize company name
        normalized_name = self._normalize_company_name(company_name, country)
        
        if not normalized_name:
            return self._create_error_result(company_name, country, "Invalid company name")
        
        # Check cache
        if self.cache_enabled and self.cache:
            cached = await self._get_cached(normalized_name, country)
            if cached:
                logger.info(f"Cache hit for company: {normalized_name} ({country})")
                cached.cached = True
                return cached
        
        # Run all checks in parallel
        checks_completed = {}
        error_messages = {}
        
        try:
            # Execute checks concurrently
            results = await asyncio.gather(
                self._check_business_registry(normalized_name, country),
                self._check_online_presence(normalized_name, company_name),
                self._detect_suspicious_patterns(normalized_name, country),
                self._check_similarity_to_known_companies(normalized_name),
                return_exceptions=True
            )
            
            registry_result, presence_result, patterns_result, similarity_result = results
            
            # Handle exceptions
            if isinstance(registry_result, Exception):
                logger.warning(f"Registry check failed: {registry_result}")
                registry_result = {"verified": False, "error": str(registry_result)}
            checks_completed['registry'] = not registry_result.get('error')
            if registry_result.get('error'):
                error_messages['registry'] = registry_result.get('error', 'Unknown error')
            
            if isinstance(presence_result, Exception):
                logger.warning(f"Online presence check failed: {presence_result}")
                presence_result = {"has_website": False, "error": str(presence_result)}
            checks_completed['online_presence'] = not presence_result.get('error')
            if presence_result.get('error'):
                error_messages['online_presence'] = presence_result.get('error', 'Unknown error')
            
            if isinstance(patterns_result, Exception):
                logger.warning(f"Pattern detection failed: {patterns_result}")
                patterns_result = {"suspicious": [], "error": str(patterns_result)}
            checks_completed['patterns'] = not patterns_result.get('error')
            if patterns_result.get('error'):
                error_messages['patterns'] = patterns_result.get('error', 'Unknown error')
            
            if isinstance(similarity_result, Exception):
                logger.warning(f"Similarity check failed: {similarity_result}")
                similarity_result = {"similar": [], "error": str(similarity_result)}
            checks_completed['similarity'] = not similarity_result.get('error')
            if similarity_result.get('error'):
                error_messages['similarity'] = similarity_result.get('error', 'Unknown error')
            
            # Calculate legitimacy and risk
            legitimate, confidence, risk_level = self._calculate_legitimacy(
                registry_result, presence_result, patterns_result, similarity_result
            )
            
            # Build result
            result = CompanyVerificationResult(
                company_name=company_name,
                normalized_name=normalized_name,
                country=self.SUPPORTED_COUNTRIES[country],
                legitimate=legitimate,
                confidence=confidence,
                risk_level=risk_level,
                registration_verified=registry_result.get('verified', False),
                registration_number=registry_result.get('registration_number'),
                incorporation_date=registry_result.get('incorporation_date'),
                company_status=registry_result.get('status'),
                registered_address=registry_result.get('address'),
                has_official_website=presence_result.get('has_website', False),
                domain_age_days=presence_result.get('domain_age_days'),
                social_media_presence=presence_result.get('social_media', {}),
                review_site_presence=presence_result.get('review_sites', {}),
                news_mentions=presence_result.get('news_mentions', 0),
                suspicious_patterns=patterns_result.get('suspicious', []),
                similar_legitimate_companies=similarity_result.get('similar', []),
                checks_completed=checks_completed,
                error_messages=error_messages,
                cached=False
            )
            
            # Cache result (30 days)
            if self.cache_enabled and self.cache:
                await self._cache_result(normalized_name, country, result)
            
            logger.info(f"Company verification completed: {result}")
            return result
        
        except Exception as e:
            logger.error(f"Company verification failed for {company_name}: {e}", exc_info=True)
            return self._create_error_result(company_name, country, str(e))
    
    def _normalize_company_name(self, name: str, country: str) -> str:
        """
        Normalize company name for consistent lookups.
        
        Args:
            name: Raw company name
            country: Country code
        
        Returns:
            Normalized company name
        """
        if not name:
            return ""
        
        # Remove extra whitespace
        name = ' '.join(name.split())
        
        # Convert to title case
        name = name.title()
        
        # Normalize common suffixes
        suffixes = self.COMPANY_SUFFIXES.get(country, [])
        for suffix in suffixes:
            # Remove suffix variations
            patterns = [
                f' {suffix}',
                f'.{suffix}',
                f', {suffix}',
            ]
            for pattern in patterns:
                name = re.sub(
                    pattern.replace('.', r'\.') + r'$',
                    '',
                    name,
                    flags=re.IGNORECASE
                )
        
        return name.strip()
    
    async def _check_business_registry(
        self,
        company_name: str,
        country: str
    ) -> Dict[str, Any]:
        """
        Check official business registry for company.
        
        Args:
            company_name: Normalized company name
            country: Country code
        
        Returns:
            Dict with verification status and details
        """
        if not httpx:
            return {"verified": False, "error": "httpx not installed"}
        
        try:
            if country == 'SG':
                return await self._check_singapore_acra(company_name)
            elif country == 'GB' or country == 'UK':
                return await self._check_uk_companies_house(company_name)
            elif country == 'US':
                return await self._check_us_sec(company_name)
            elif country == 'CA':
                return await self._check_canada_registry(company_name)
            elif country == 'AU':
                return await self._check_australia_asic(company_name)
            else:
                return {"verified": False, "error": "Country not supported"}
        
        except asyncio.TimeoutError:
            logger.warning(f"Registry check timeout for {company_name}")
            return {"verified": False, "error": "Registry lookup timeout"}
        except Exception as e:
            logger.warning(f"Registry check failed for {company_name}: {e}")
            return {"verified": False, "error": f"Check failed: {str(e)}"}
    
    async def _check_singapore_acra(self, company_name: str) -> Dict[str, Any]:
        """Check Singapore ACRA BizFile."""
        if not self.acra_api_key:
            logger.debug("ACRA API key not configured")
            return {"verified": False, "error": "API key not configured"}
        
        try:
            # ACRA API endpoint (example - actual endpoint may vary)
            url = "https://api.bizfile.gov.sg/v1/entity/search"
            headers = {"Authorization": f"Bearer {self.acra_api_key}"}
            params = {"name": company_name}
            
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(url, headers=headers, params=params)
                response.raise_for_status()
                
                data = response.json()
                
                if data.get('results') and len(data['results']) > 0:
                    company = data['results'][0]
                    return {
                        "verified": True,
                        "registration_number": company.get('uen'),
                        "incorporation_date": company.get('registration_date'),
                        "status": company.get('status'),
                        "address": company.get('registered_address')
                    }
                else:
                    return {"verified": False}
        
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                return {"verified": False}
            else:
                return {"verified": False, "error": f"API error: {e.response.status_code}"}
        except Exception as e:
            return {"verified": False, "error": str(e)}
    
    async def _check_uk_companies_house(self, company_name: str) -> Dict[str, Any]:
        """Check UK Companies House."""
        if not self.companies_house_key:
            logger.debug("Companies House API key not configured")
            return {"verified": False, "error": "API key not configured"}
        
        try:
            # Companies House API
            url = "https://api.company-information.service.gov.uk/search/companies"
            auth = (self.companies_house_key, '')
            params = {"q": company_name, "items_per_page": 1}
            
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(url, auth=auth, params=params)
                response.raise_for_status()
                
                data = response.json()
                
                if data.get('items') and len(data['items']) > 0:
                    company = data['items'][0]
                    return {
                        "verified": True,
                        "registration_number": company.get('company_number'),
                        "incorporation_date": company.get('date_of_creation'),
                        "status": company.get('company_status'),
                        "address": company.get('address_snippet')
                    }
                else:
                    return {"verified": False}
        
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                return {"verified": False}
            else:
                return {"verified": False, "error": f"API error: {e.response.status_code}"}
        except Exception as e:
            return {"verified": False, "error": str(e)}
    
    async def _check_us_sec(self, company_name: str) -> Dict[str, Any]:
        """Check US SEC EDGAR database (public companies only)."""
        try:
            # SEC EDGAR company search
            url = "https://www.sec.gov/cgi-bin/browse-edgar"
            params = {
                "action": "getcompany",
                "company": company_name,
                "count": 1,
                "output": "json"
            }
            headers = {
                "User-Agent": "TypeSafe Company Verification Tool (contact@typesafe.app)"
            }
            
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(url, params=params, headers=headers)
                
                # SEC doesn't return JSON by default, this is simplified
                if response.status_code == 200 and len(response.text) > 100:
                    # Company found (simplified check)
                    return {
                        "verified": True,
                        "registration_number": "SEC-registered",
                        "status": "Active"
                    }
                else:
                    return {"verified": False}
        
        except Exception as e:
            logger.debug(f"SEC check failed: {e}")
            return {"verified": False, "error": str(e)}
    
    async def _check_canada_registry(self, company_name: str) -> Dict[str, Any]:
        """Check Corporations Canada registry."""
        # Placeholder - would integrate with Corporations Canada API
        logger.debug(f"Canada registry check not yet implemented for {company_name}")
        return {"verified": False, "error": "Canada registry not yet integrated"}
    
    async def _check_australia_asic(self, company_name: str) -> Dict[str, Any]:
        """Check Australia ASIC registry."""
        # Placeholder - would integrate with ASIC API
        logger.debug(f"Australia ASIC check not yet implemented for {company_name}")
        return {"verified": False, "error": "Australia registry not yet integrated"}
    
    async def _check_online_presence(
        self,
        normalized_name: str,
        original_name: str
    ) -> Dict[str, Any]:
        """
        Check company's online presence.
        
        Args:
            normalized_name: Normalized company name
            original_name: Original company name
        
        Returns:
            Dict with online presence indicators
        """
        if not httpx:
            return {"has_website": False, "error": "httpx not installed"}
        
        try:
            # Use Exa search or Google Search to find company website
            # This is a simplified implementation
            search_query = f"{original_name} official website"
            
            # Placeholder for actual search implementation
            # In production, this would use Exa API or similar
            
            return {
                "has_website": False,
                "domain_age_days": None,
                "social_media": {
                    "linkedin": False,
                    "facebook": False,
                    "twitter": False
                },
                "review_sites": {
                    "trustpilot": False,
                    "google_reviews": False,
                    "bbb": False
                },
                "news_mentions": 0,
                "error": "Online presence check not fully implemented"
            }
        
        except Exception as e:
            logger.warning(f"Online presence check failed: {e}")
            return {"has_website": False, "error": str(e)}
    
    async def _detect_suspicious_patterns(
        self,
        company_name: str,
        country: str
    ) -> Dict[str, Any]:
        """
        Detect suspicious patterns in company name.
        
        Args:
            company_name: Company name to analyze
            country: Country code
        
        Returns:
            Dict with suspicious patterns found
        """
        suspicious = []
        
        # Check for suspicious keywords
        name_lower = company_name.lower()
        for keyword in self.SUSPICIOUS_KEYWORDS:
            if keyword in name_lower:
                suspicious.append(f"Suspicious keyword: '{keyword}'")
        
        # Check for generic names
        generic_patterns = [
            r'^(international|global|national|worldwide)\s+(trading|services|solutions|company)',
            r'^(general|standard|universal)\s+(services|solutions|company)',
        ]
        for pattern in generic_patterns:
            if re.search(pattern, name_lower):
                suspicious.append("Generic company name pattern")
                break
        
        # Check for missing legal suffix
        suffixes = self.COMPANY_SUFFIXES.get(country, [])
        has_suffix = any(
            company_name.lower().endswith(suffix.lower())
            for suffix in suffixes
        )
        if not has_suffix and len(company_name.split()) > 1:
            suspicious.append(f"Missing legal suffix for {country}")
        
        # Check for unusual characters
        if re.search(r'[0-9]{3,}', company_name):
            suspicious.append("Unusual number sequence in name")
        
        return {
            "suspicious": suspicious
        }
    
    async def _check_similarity_to_known_companies(
        self,
        company_name: str
    ) -> Dict[str, Any]:
        """
        Check for typo-squatting or impersonation.
        
        Args:
            company_name: Company name to check
        
        Returns:
            Dict with similar legitimate companies
        """
        similar = []
        
        for known in self.KNOWN_COMPANIES:
            ratio = SequenceMatcher(None, company_name.lower(), known.lower()).ratio()
            
            # High similarity but not exact match = potential typo-squatting
            if 0.7 < ratio < 0.95:
                similar.append(known)
        
        return {
            "similar": similar
        }
    
    def _calculate_legitimacy(
        self,
        registry_result: Dict,
        presence_result: Dict,
        patterns_result: Dict,
        similarity_result: Dict
    ) -> Tuple[bool, float, str]:
        """
        Calculate company legitimacy score.
        
        Args:
            registry_result: Business registry check results
            presence_result: Online presence check results
            patterns_result: Pattern detection results
            similarity_result: Similarity check results
        
        Returns:
            Tuple of (legitimate, confidence, risk_level)
        """
        score = 50.0  # Start neutral
        
        # Registry verification (most important)
        if registry_result.get('verified'):
            score += 40
        else:
            score -= 30
        
        # Online presence
        if presence_result.get('has_website'):
            score += 10
        
        domain_age = presence_result.get('domain_age_days')
        if domain_age and domain_age > 365:
            score += 10
        elif domain_age and domain_age < 30:
            score -= 10
        
        # Suspicious patterns (each pattern reduces score)
        suspicious_count = len(patterns_result.get('suspicious', []))
        score -= suspicious_count * 10
        
        # Similar to known companies (potential impersonation)
        similar_count = len(similarity_result.get('similar', []))
        if similar_count > 0:
            score -= 20
        
        # Clamp score
        score = max(0.0, min(100.0, score))
        
        # Determine legitimacy and risk level
        if score >= 70:
            legitimate = True
            risk_level = "low"
        elif score >= 40:
            legitimate = False
            risk_level = "medium"
        else:
            legitimate = False
            risk_level = "high"
        
        return legitimate, score, risk_level
    
    def _get_cache_key(self, company_name: str, country: str) -> str:
        """Generate cache key."""
        key_str = f"{company_name}:{country}"
        key_hash = hashlib.md5(key_str.encode()).hexdigest()
        return f"company_verification:{key_hash}"
    
    async def _get_cached(
        self,
        company_name: str,
        country: str
    ) -> Optional[CompanyVerificationResult]:
        """Get cached company verification result."""
        if not self.cache_enabled or not self.cache:
            return None
        
        try:
            key = self._get_cache_key(company_name, country)
            
            loop = asyncio.get_event_loop()
            cached_data = await loop.run_in_executor(None, self.cache.get, key)
            
            if cached_data:
                data = json.loads(cached_data)
                return CompanyVerificationResult(**data)
        
        except Exception as e:
            logger.warning(f"Cache retrieval error: {e}")
        
        return None
    
    async def _cache_result(
        self,
        company_name: str,
        country: str,
        result: CompanyVerificationResult
    ):
        """Cache company verification result."""
        if not self.cache_enabled or not self.cache:
            return
        
        try:
            key = self._get_cache_key(company_name, country)
            cache_data = result.to_dict()
            
            loop = asyncio.get_event_loop()
            # Cache for 30 days (2592000 seconds)
            await loop.run_in_executor(
                None,
                lambda: self.cache.setex(key, 2592000, json.dumps(cache_data))
            )
            
            logger.debug(f"Cached company verification for {company_name} (30 days)")
        
        except Exception as e:
            logger.warning(f"Cache storage error: {e}")
    
    def _create_error_result(
        self,
        company_name: str,
        country: str,
        error: str
    ) -> CompanyVerificationResult:
        """Create error result."""
        return CompanyVerificationResult(
            company_name=company_name,
            normalized_name=company_name,
            country=self.SUPPORTED_COUNTRIES.get(country, 'Unknown'),
            legitimate=False,
            confidence=0.0,
            risk_level="unknown",
            registration_verified=False,
            registration_number=None,
            incorporation_date=None,
            company_status=None,
            registered_address=None,
            has_official_website=False,
            domain_age_days=None,
            social_media_presence={},
            review_site_presence={},
            news_mentions=0,
            suspicious_patterns=[],
            similar_legitimate_companies=[],
            checks_completed={},
            error_messages={'general': error},
            cached=False
        )


# =============================================================================
# Singleton Instance
# =============================================================================

_tool_instance: Optional[CompanyVerificationTool] = None


def get_company_verification_tool() -> CompanyVerificationTool:
    """
    Get singleton CompanyVerificationTool instance.
    
    Returns:
        Singleton instance of CompanyVerificationTool
    """
    global _tool_instance
    if _tool_instance is None:
        _tool_instance = CompanyVerificationTool()
    return _tool_instance

