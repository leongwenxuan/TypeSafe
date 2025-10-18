"""
Domain Reputation Tool for MCP Agent.

Analyzes URLs to detect phishing sites, malware hosts, and fraudulent domains by checking
multiple signals: domain age, SSL certificate, VirusTotal, and Google Safe Browsing.

Story: 8.5 - Domain Reputation Tool
"""

import os
import ssl
import socket
import hashlib
import logging
import asyncio
import json
from typing import Dict, Any, Optional
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from urllib.parse import urlparse

try:
    import whois
except ImportError:
    whois = None

try:
    import httpx
except ImportError:
    httpx = None

try:
    import redis
except ImportError:
    redis = None

logger = logging.getLogger(__name__)


@dataclass
class DomainReputationResult:
    """Domain reputation check result."""
    domain: str
    age_days: Optional[int]
    ssl_valid: bool
    ssl_expiry_days: Optional[int]
    virustotal_malicious: int
    virustotal_total: int
    safe_browsing_flagged: bool
    risk_level: str  # low, medium, high, unknown
    risk_score: float  # 0-100
    checks_completed: Dict[str, bool]
    error_messages: Dict[str, str]
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return asdict(self)
    
    def __str__(self) -> str:
        """Human-readable string representation."""
        return (
            f"DomainReputationResult(domain={self.domain}, risk_level={self.risk_level}, "
            f"risk_score={self.risk_score:.1f}, age_days={self.age_days}, "
            f"ssl_valid={self.ssl_valid}, vt_malicious={self.virustotal_malicious}/{self.virustotal_total}, "
            f"safe_browsing_flagged={self.safe_browsing_flagged})"
        )


class DomainReputationTool:
    """
    Tool for checking domain reputation and safety.
    
    Checks domain age (WHOIS), SSL certificate validity, VirusTotal scans,
    and Google Safe Browsing API to provide comprehensive domain reputation analysis.
    
    Features:
    - Multiple parallel checks for fast results (<5s p95)
    - Graceful degradation if individual checks fail
    - 7-day caching for domain reputations
    - Risk scoring based on multiple signals
    
    Example:
        >>> tool = DomainReputationTool()
        >>> result = await tool.check_domain("suspicious-site.com")
        >>> if result.risk_level == "high":
        ...     print(f"High risk domain! Score: {result.risk_score}")
    """
    
    def __init__(
        self,
        virustotal_api_key: Optional[str] = None,
        safe_browsing_api_key: Optional[str] = None,
        cache_enabled: bool = True
    ):
        """
        Initialize domain reputation tool.
        
        Args:
            virustotal_api_key: VirusTotal API key (optional, falls back to env var)
            safe_browsing_api_key: Google Safe Browsing API key (optional, falls back to env var)
            cache_enabled: Enable Redis caching for results
        """
        self.virustotal_api_key = virustotal_api_key or os.getenv('VIRUSTOTAL_API_KEY')
        self.safe_browsing_api_key = safe_browsing_api_key or os.getenv('SAFE_BROWSING_API_KEY')
        self.cache_enabled = cache_enabled
        self.cache = None
        
        # Initialize cache if enabled
        if cache_enabled and redis:
            try:
                redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379')
                # Use database 2 for domain reputation cache
                self.cache = redis.from_url(
                    redis_url + '/2',
                    decode_responses=True,
                    socket_timeout=2,
                    socket_connect_timeout=2
                )
                # Test connection
                self.cache.ping()
                logger.info("Domain reputation cache initialized (Redis DB 2)")
            except Exception as e:
                logger.warning(f"Cache initialization failed, continuing without cache: {e}")
                self.cache_enabled = False
                self.cache = None
        elif cache_enabled and not redis:
            logger.warning("Redis not available, cache disabled")
            self.cache_enabled = False
        
        # Check dependencies
        if not whois:
            logger.warning("python-whois not installed, domain age checks will be skipped")
        if not httpx:
            logger.warning("httpx not installed, external API checks will be skipped")
        
        logger.info("DomainReputationTool initialized")
    
    async def check_domain(self, url: str) -> DomainReputationResult:
        """
        Check domain reputation for URL.
        
        Runs multiple checks in parallel:
        1. Domain age (WHOIS)
        2. SSL certificate validity
        3. VirusTotal scan results
        4. Google Safe Browsing check
        
        Args:
            url: Full URL or domain name
        
        Returns:
            DomainReputationResult with all check results and risk assessment
        """
        # Extract domain
        domain = self._extract_domain(url)
        
        if not domain:
            return self._create_error_result("Invalid domain")
        
        # Check cache first
        if self.cache_enabled and self.cache:
            cached = await self._get_cached(domain)
            if cached:
                logger.info(f"Cache hit for domain: {domain}")
                return cached
        
        # Run all checks in parallel
        checks_completed = {}
        error_messages = {}
        
        try:
            # Execute all checks concurrently
            results = await asyncio.gather(
                self._check_domain_age(domain),
                self._check_ssl(domain),
                self._check_virustotal(domain),
                self._check_safe_browsing(domain),
                return_exceptions=True
            )
            
            age_result, ssl_result, vt_result, sb_result = results
            
            # Handle exceptions and track which checks completed
            if isinstance(age_result, Exception):
                logger.warning(f"Domain age check failed: {age_result}")
                age_result = {"age_days": None, "error": str(age_result)}
            checks_completed['domain_age'] = not age_result.get('error')
            if age_result.get('error'):
                error_messages['domain_age'] = age_result.get('error', 'Unknown error')
            
            if isinstance(ssl_result, Exception):
                logger.warning(f"SSL check failed: {ssl_result}")
                ssl_result = {"valid": False, "expiry_days": None, "error": str(ssl_result)}
            checks_completed['ssl'] = not ssl_result.get('error')
            if ssl_result.get('error'):
                error_messages['ssl'] = ssl_result.get('error', 'Unknown error')
            
            if isinstance(vt_result, Exception):
                logger.warning(f"VirusTotal check failed: {vt_result}")
                vt_result = {"malicious": 0, "total": 0, "error": str(vt_result)}
            checks_completed['virustotal'] = not vt_result.get('error')
            if vt_result.get('error'):
                error_messages['virustotal'] = vt_result.get('error', 'Unknown error')
            
            if isinstance(sb_result, Exception):
                logger.warning(f"Safe Browsing check failed: {sb_result}")
                sb_result = {"flagged": False, "error": str(sb_result)}
            checks_completed['safe_browsing'] = not sb_result.get('error')
            if sb_result.get('error'):
                error_messages['safe_browsing'] = sb_result.get('error', 'Unknown error')
            
            # Calculate risk level and score
            risk_level, risk_score = self._calculate_risk(
                age_result, ssl_result, vt_result, sb_result
            )
            
            # Build result
            result = DomainReputationResult(
                domain=domain,
                age_days=age_result.get('age_days'),
                ssl_valid=ssl_result.get('valid', False),
                ssl_expiry_days=ssl_result.get('expiry_days'),
                virustotal_malicious=vt_result.get('malicious', 0),
                virustotal_total=vt_result.get('total', 0),
                safe_browsing_flagged=sb_result.get('flagged', False),
                risk_level=risk_level,
                risk_score=risk_score,
                checks_completed=checks_completed,
                error_messages=error_messages
            )
            
            # Cache result (7 days)
            if self.cache_enabled and self.cache:
                await self._cache_result(domain, result)
            
            logger.info(f"Domain reputation check completed: {result}")
            return result
        
        except Exception as e:
            logger.error(f"Domain reputation check failed for {domain}: {e}", exc_info=True)
            return self._create_error_result(str(e), domain)
    
    def _extract_domain(self, url: str) -> str:
        """
        Extract domain from URL.
        
        Args:
            url: Full URL or domain name
        
        Returns:
            Lowercase domain (e.g., "example.com") or empty string if invalid
        """
        if not url:
            return ""
        
        # Add protocol if missing
        if not url.startswith(('http://', 'https://')):
            url = 'https://' + url
        
        try:
            parsed = urlparse(url)
            domain = parsed.netloc.lower()
            
            # Remove port if present
            domain = domain.split(':')[0]
            
            # Remove www. prefix
            if domain.startswith('www.'):
                domain = domain[4:]
            
            return domain
        except Exception as e:
            logger.error(f"Error extracting domain from {url}: {e}")
            return ""
    
    async def _check_domain_age(self, domain: str) -> Dict[str, Any]:
        """
        Check domain age using WHOIS lookup.
        
        Args:
            domain: Domain name
        
        Returns:
            Dict with age_days, created timestamp, and suspicious flag
        """
        if not whois:
            return {"age_days": None, "error": "python-whois not installed"}
        
        try:
            # Run WHOIS in thread pool (blocking I/O)
            loop = asyncio.get_event_loop()
            w = await asyncio.wait_for(
                loop.run_in_executor(None, whois.whois, domain),
                timeout=3.0
            )
            
            creation_date = w.creation_date
            
            # Handle list of dates (some domains return multiple)
            if isinstance(creation_date, list):
                creation_date = creation_date[0]
            
            if creation_date:
                # Make timezone-aware if naive
                if creation_date.tzinfo is None:
                    creation_date = creation_date.replace(tzinfo=None)
                
                age_days = (datetime.now() - creation_date).days
                
                return {
                    "age_days": age_days,
                    "created": creation_date.isoformat(),
                    "suspicious": age_days < 30
                }
            else:
                logger.debug(f"No creation date found for {domain}")
                return {"age_days": None, "error": "Creation date not available"}
        
        except asyncio.TimeoutError:
            logger.warning(f"WHOIS timeout for {domain}")
            return {"age_days": None, "error": "WHOIS lookup timeout"}
        except Exception as e:
            logger.debug(f"WHOIS lookup failed for {domain}: {e}")
            return {"age_days": None, "error": f"WHOIS lookup failed: {str(e)}"}
    
    async def _check_ssl(self, domain: str) -> Dict[str, Any]:
        """
        Check SSL certificate validity.
        
        Args:
            domain: Domain name
        
        Returns:
            Dict with valid flag, expiry_days, and error info
        """
        try:
            context = ssl.create_default_context()
            
            # Run SSL check in thread pool (blocking I/O)
            loop = asyncio.get_event_loop()
            
            def check_cert():
                with socket.create_connection((domain, 443), timeout=2) as sock:
                    with context.wrap_socket(sock, server_hostname=domain) as ssock:
                        cert = ssock.getpeercert()
                        return cert
            
            cert = await asyncio.wait_for(
                loop.run_in_executor(None, check_cert),
                timeout=3.0
            )
            
            # Parse expiry date
            expiry_str = cert.get('notAfter')
            if expiry_str:
                # Format: 'Jan 1 00:00:00 2026 GMT'
                expiry_date = datetime.strptime(expiry_str, '%b %d %H:%M:%S %Y %Z')
                days_until_expiry = (expiry_date - datetime.now()).days
                
                return {
                    "valid": days_until_expiry > 0,
                    "expiry_days": days_until_expiry,
                    "expired": days_until_expiry < 0
                }
            else:
                return {"valid": False, "expiry_days": None, "error": "No expiry date in certificate"}
        
        except asyncio.TimeoutError:
            logger.warning(f"SSL check timeout for {domain}")
            return {"valid": False, "expiry_days": None, "error": "SSL check timeout"}
        except socket.gaierror as e:
            logger.debug(f"SSL check failed for {domain}: Domain not found")
            return {"valid": False, "expiry_days": None, "error": "Domain not found"}
        except Exception as e:
            logger.debug(f"SSL check failed for {domain}: {e}")
            return {"valid": False, "expiry_days": None, "error": f"SSL check failed: {str(e)}"}
    
    async def _check_virustotal(self, domain: str) -> Dict[str, Any]:
        """
        Check domain reputation on VirusTotal.
        
        Args:
            domain: Domain name
        
        Returns:
            Dict with malicious count, total engines, and flagged status
        """
        if not self.virustotal_api_key:
            logger.debug("VirusTotal API key not configured")
            return {"malicious": 0, "total": 0, "error": "API key not configured"}
        
        if not httpx:
            return {"malicious": 0, "total": 0, "error": "httpx not installed"}
        
        try:
            url = f"https://www.virustotal.com/api/v3/domains/{domain}"
            headers = {"x-apikey": self.virustotal_api_key}
            
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(url, headers=headers)
                response.raise_for_status()
                
                data = response.json()
                stats = data.get('data', {}).get('attributes', {}).get('last_analysis_stats', {})
                
                malicious = stats.get('malicious', 0)
                suspicious = stats.get('suspicious', 0)
                harmless = stats.get('harmless', 0)
                undetected = stats.get('undetected', 0)
                total = malicious + suspicious + harmless + undetected
                
                return {
                    "malicious": malicious + suspicious,
                    "total": total,
                    "flagged": (malicious + suspicious) > 0,
                    "stats": stats
                }
        
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                # Domain not in VirusTotal database (might be very new)
                logger.debug(f"Domain {domain} not found in VirusTotal")
                return {"malicious": 0, "total": 0, "not_found": True}
            elif e.response.status_code == 429:
                logger.warning("VirusTotal rate limit exceeded")
                return {"malicious": 0, "total": 0, "error": "Rate limit exceeded"}
            else:
                logger.warning(f"VirusTotal API error: {e}")
                return {"malicious": 0, "total": 0, "error": f"API error: {e.response.status_code}"}
        except httpx.TimeoutException:
            logger.warning(f"VirusTotal check timeout for {domain}")
            return {"malicious": 0, "total": 0, "error": "API timeout"}
        except Exception as e:
            logger.warning(f"VirusTotal check failed for {domain}: {e}")
            return {"malicious": 0, "total": 0, "error": f"Check failed: {str(e)}"}
    
    async def _check_safe_browsing(self, domain: str) -> Dict[str, Any]:
        """
        Check domain with Google Safe Browsing API.
        
        Args:
            domain: Domain name
        
        Returns:
            Dict with flagged status and threat types
        """
        if not self.safe_browsing_api_key:
            logger.debug("Safe Browsing API key not configured")
            return {"flagged": False, "error": "API key not configured"}
        
        if not httpx:
            return {"flagged": False, "error": "httpx not installed"}
        
        try:
            url = f"https://safebrowsing.googleapis.com/v4/threatMatches:find?key={self.safe_browsing_api_key}"
            
            payload = {
                "client": {
                    "clientId": "typesafe",
                    "clientVersion": "1.0.0"
                },
                "threatInfo": {
                    "threatTypes": ["MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE", "POTENTIALLY_HARMFUL_APPLICATION"],
                    "platformTypes": ["ANY_PLATFORM"],
                    "threatEntryTypes": ["URL"],
                    "threatEntries": [
                        {"url": f"https://{domain}"},
                        {"url": f"http://{domain}"},
                        {"url": f"https://{domain}/"},
                        {"url": f"http://{domain}/"}
                    ]
                }
            }
            
            async with httpx.AsyncClient(timeout=3.0) as client:
                response = await client.post(url, json=payload)
                response.raise_for_status()
                
                data = response.json()
                matches = data.get('matches', [])
                
                threat_types = []
                if matches:
                    threat_types = list(set(m.get('threatType') for m in matches))
                
                return {
                    "flagged": len(matches) > 0,
                    "threat_types": threat_types,
                    "match_count": len(matches)
                }
        
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 429:
                logger.warning("Safe Browsing rate limit exceeded")
                return {"flagged": False, "error": "Rate limit exceeded"}
            else:
                logger.warning(f"Safe Browsing API error: {e}")
                return {"flagged": False, "error": f"API error: {e.response.status_code}"}
        except httpx.TimeoutException:
            logger.warning(f"Safe Browsing check timeout for {domain}")
            return {"flagged": False, "error": "API timeout"}
        except Exception as e:
            logger.warning(f"Safe Browsing check failed for {domain}: {e}")
            return {"flagged": False, "error": f"Check failed: {str(e)}"}
    
    def _calculate_risk(
        self,
        age_result: Dict,
        ssl_result: Dict,
        vt_result: Dict,
        sb_result: Dict
    ) -> tuple[str, float]:
        """
        Calculate overall risk level and score based on all checks.
        
        Risk scoring:
        - Domain age: 0-30 points (newer = higher risk)
        - SSL certificate: 0-20 points (missing/expired = higher risk)
        - VirusTotal: 0-40 points (more detections = higher risk)
        - Safe Browsing: 0-40 points (flagged = high risk)
        
        Args:
            age_result: Domain age check results
            ssl_result: SSL check results
            vt_result: VirusTotal check results
            sb_result: Safe Browsing check results
        
        Returns:
            Tuple of (risk_level, risk_score)
            risk_level: 'low', 'medium', 'high', or 'unknown'
            risk_score: 0-100 float
        """
        score = 0.0
        checks_available = 0
        
        # Domain age (0-30 points)
        age_days = age_result.get('age_days')
        if age_days is not None:
            checks_available += 1
            if age_days < 7:
                score += 30  # Very new domain
            elif age_days < 30:
                score += 20  # New domain
            elif age_days < 90:
                score += 10  # Fairly new
            # else: 0 points for established domains
        
        # SSL certificate (0-20 points)
        if not ssl_result.get('error'):
            checks_available += 1
            if not ssl_result.get('valid'):
                score += 20  # No valid SSL or expired
            elif ssl_result.get('expiry_days', 0) < 30:
                score += 10  # Expiring soon (suspicious)
        
        # VirusTotal (0-40 points)
        if not vt_result.get('error'):
            checks_available += 1
            vt_malicious = vt_result.get('malicious', 0)
            vt_total = vt_result.get('total', 0)
            
            if vt_total > 0:
                vt_ratio = vt_malicious / vt_total
                score += vt_ratio * 40  # Scale to 0-40 based on detection ratio
            elif vt_result.get('not_found'):
                # Domain not in VT database (could be very new)
                score += 5  # Small penalty for unknown domains
        
        # Safe Browsing (0-40 points)
        if not sb_result.get('error'):
            checks_available += 1
            if sb_result.get('flagged'):
                score += 40  # Flagged by Google = high risk
        
        # Determine risk level
        if checks_available == 0:
            # No checks completed successfully
            return "unknown", 50.0
        
        # Normalize score if not all checks were available
        if checks_available < 4:
            # Scale score proportionally
            max_possible = 0
            if age_days is not None:
                max_possible += 30
            if not ssl_result.get('error'):
                max_possible += 20
            if not vt_result.get('error'):
                max_possible += 40
            if not sb_result.get('error'):
                max_possible += 40
            
            if max_possible > 0:
                score = (score / max_possible) * 100
        
        # Cap at 100
        score = min(score, 100.0)
        
        # Assign risk level based on score
        if score >= 70:
            risk_level = "high"
        elif score >= 40:
            risk_level = "medium"
        else:
            risk_level = "low"
        
        return risk_level, score
    
    def _get_cache_key(self, domain: str) -> str:
        """Generate cache key for domain."""
        domain_hash = hashlib.md5(domain.encode()).hexdigest()
        return f"domain_reputation:{domain_hash}"
    
    async def _get_cached(self, domain: str) -> Optional[DomainReputationResult]:
        """
        Get cached domain reputation.
        
        Args:
            domain: Domain name
        
        Returns:
            Cached DomainReputationResult or None
        """
        if not self.cache_enabled or not self.cache:
            return None
        
        try:
            key = self._get_cache_key(domain)
            
            # Run Redis operation in thread pool
            loop = asyncio.get_event_loop()
            cached_data = await loop.run_in_executor(None, self.cache.get, key)
            
            if cached_data:
                data = json.loads(cached_data)
                return DomainReputationResult(**data)
        
        except Exception as e:
            logger.warning(f"Cache retrieval error for {domain}: {e}")
        
        return None
    
    async def _cache_result(self, domain: str, result: DomainReputationResult):
        """
        Cache domain reputation result.
        
        Args:
            domain: Domain name
            result: DomainReputationResult to cache
        """
        if not self.cache_enabled or not self.cache:
            return
        
        try:
            key = self._get_cache_key(domain)
            cache_data = result.to_dict()
            
            # Run Redis operation in thread pool
            loop = asyncio.get_event_loop()
            # Cache for 7 days (604800 seconds)
            await loop.run_in_executor(
                None,
                lambda: self.cache.setex(key, 604800, json.dumps(cache_data))
            )
            
            logger.debug(f"Cached domain reputation for {domain} (7 days)")
        
        except Exception as e:
            logger.warning(f"Cache storage error for {domain}: {e}")
    
    def _create_error_result(self, error: str, domain: str = "unknown") -> DomainReputationResult:
        """
        Create error result when checks fail.
        
        Args:
            error: Error message
            domain: Domain name
        
        Returns:
            DomainReputationResult with unknown risk level
        """
        return DomainReputationResult(
            domain=domain,
            age_days=None,
            ssl_valid=False,
            ssl_expiry_days=None,
            virustotal_malicious=0,
            virustotal_total=0,
            safe_browsing_flagged=False,
            risk_level="unknown",
            risk_score=50.0,
            checks_completed={
                'domain_age': False,
                'ssl': False,
                'virustotal': False,
                'safe_browsing': False
            },
            error_messages={'general': error}
        )


# =============================================================================
# Singleton Instance
# =============================================================================

_tool_instance: Optional[DomainReputationTool] = None


def get_domain_reputation_tool() -> DomainReputationTool:
    """
    Get singleton DomainReputationTool instance.
    
    Returns:
        Singleton instance of DomainReputationTool
    """
    global _tool_instance
    if _tool_instance is None:
        _tool_instance = DomainReputationTool()
    return _tool_instance

