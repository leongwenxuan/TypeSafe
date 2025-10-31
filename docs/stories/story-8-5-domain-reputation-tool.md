# Story 8.5: Domain Reputation Tool

**Story ID:** 8.5  
**Epic:** Epic 8 - MCP Agent with Multi-Tool Orchestration  
**Priority:** P1 (Important for URL Scams)  
**Effort:** 14 hours  
**Assignee:** Backend Developer  
**Status:** 📝 Ready for Development

---

## User Story

**As an** MCP agent,  
**I want** to check domain reputation and safety scores,  
**so that** I can identify malicious URLs and phishing sites.

---

## Description

The Domain Reputation Tool analyzes URLs to detect phishing sites, malware hosts, and fraudulent domains. It checks multiple signals:

1. **Domain Age** (WHOIS lookup) - New domains are often suspicious
2. **SSL Certificate** - Valid, expired, or missing SSL
3. **VirusTotal Scan** - Malicious reports from 70+ antivirus engines
4. **Google Safe Browsing** - Free API for known malicious sites
5. **DNS Records** - Suspicious patterns (frequent IP changes)

**Real-World Example:**
```
User screenshot: "Click here: suspicious-bank-login.com"
↓
Domain Reputation Tool checks:
- Domain age: 7 days old ⚠️
- SSL: Missing ⚠️
- VirusTotal: 15/70 engines flagged as phishing 🚨
- Safe Browsing: Flagged as malicious 🚨
↓
Agent: "HIGH RISK - New domain (7 days), no SSL, flagged by 15 security engines"
```

---

## Acceptance Criteria

### Core Functionality
- [ ] 1. `DomainReputationTool` class created in `app/agents/tools/domain_reputation.py`
- [ ] 2. Checks multiple signals: domain age, SSL, VirusTotal, Safe Browsing
- [ ] 3. Return format: `{"domain": str, "age_days": int, "ssl_valid": bool, "virustotal_score": int, "safe_browsing_flagged": bool, "risk_level": str}`
- [ ] 4. Risk levels: `low`, `medium`, `high` based on combined signals
- [ ] 5. Handles both full URLs and domains

### Domain Age Check (WHOIS)
- [ ] 6. Uses `python-whois` library for domain age lookup
- [ ] 7. Calculates days since domain creation
- [ ] 8. Flags domains < 30 days as suspicious
- [ ] 9. Handles WHOIS query failures gracefully (domain privacy, invalid domain)
- [ ] 10. Timeout: 3 seconds for WHOIS lookup

### SSL Certificate Check
- [ ] 11. Verifies SSL certificate validity
- [ ] 12. Checks certificate expiration date
- [ ] 13. Detects self-signed certificates
- [ ] 14. Handles missing certificates (HTTP only)
- [ ] 15. Timeout: 2 seconds for SSL check

### VirusTotal Integration
- [ ] 16. Uses VirusTotal API v3 for domain/URL scanning
- [ ] 17. Returns count of engines flagging as malicious
- [ ] 18. Free tier compatible (4 requests/minute rate limit)
- [ ] 19. Caching: 7-day TTL for domain reputations
- [ ] 20. Fallback: If VirusTotal unavailable, use Safe Browsing only

### Google Safe Browsing
- [ ] 21. Uses Google Safe Browsing Lookup API v4 (free)
- [ ] 22. Checks for phishing, malware, unwanted software
- [ ] 23. Rate limit: 10,000 requests/day (within free tier)
- [ ] 24. Timeout: 2 seconds

### Performance & Caching
- [ ] 25. All checks run in parallel (async)
- [ ] 26. Total check time: < 5 seconds (p95)
- [ ] 27. Caching: Domain reputation cached for 7 days
- [ ] 28. Cache key: `domain:reputation:{domain_hash}`
- [ ] 29. Graceful degradation: Return partial results if some checks fail

### Testing
- [ ] 30. Unit tests with mocked API responses
- [ ] 31. Integration tests with real domains (staging)
- [ ] 32. Test cases: new vs old domains, SSL vs no SSL, clean vs flagged
- [ ] 33. Performance benchmarks

---

## Technical Implementation

**`app/agents/tools/domain_reputation.py`:**

```python
"""Domain Reputation Tool for MCP Agent."""

import os
import ssl
import socket
import whois
import httpx
import hashlib
import logging
import asyncio
from typing import Dict, Any, Optional
from dataclasses import dataclass
from datetime import datetime, timedelta
from urllib.parse import urlparse
import json

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
    risk_level: str  # low, medium, high
    risk_score: float  # 0-100
    checks_completed: Dict[str, bool]
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "domain": self.domain,
            "age_days": self.age_days,
            "ssl_valid": self.ssl_valid,
            "ssl_expiry_days": self.ssl_expiry_days,
            "virustotal_malicious": self.virustotal_malicious,
            "virustotal_total": self.virustotal_total,
            "safe_browsing_flagged": self.safe_browsing_flagged,
            "risk_level": self.risk_level,
            "risk_score": self.risk_score,
            "checks_completed": self.checks_completed
        }


class DomainReputationTool:
    """
    Tool for checking domain reputation and safety.
    
    Checks domain age, SSL certificate, VirusTotal, and Google Safe Browsing.
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
            virustotal_api_key: VirusTotal API key (optional)
            safe_browsing_api_key: Google Safe Browsing API key (optional)
            cache_enabled: Enable result caching
        """
        self.virustotal_api_key = virustotal_api_key or os.getenv('VIRUSTOTAL_API_KEY')
        self.safe_browsing_api_key = safe_browsing_api_key or os.getenv('SAFE_BROWSING_API_KEY')
        self.cache_enabled = cache_enabled
        
        # Initialize cache
        if cache_enabled:
            try:
                import redis
                self.cache = redis.from_url(
                    os.getenv('REDIS_URL', 'redis://localhost:6379/2'),
                    decode_responses=True
                )
            except Exception as e:
                logger.warning(f"Cache initialization failed: {e}")
                self.cache_enabled = False
        
        logger.info("DomainReputationTool initialized")
    
    async def check_domain(self, url: str) -> DomainReputationResult:
        """
        Check domain reputation for URL.
        
        Args:
            url: Full URL or domain name
        
        Returns:
            DomainReputationResult with all check results
        """
        # Extract domain
        domain = self._extract_domain(url)
        
        # Check cache
        if self.cache_enabled:
            cached = self._get_cached(domain)
            if cached:
                logger.info(f"Cache hit for domain: {domain}")
                return cached
        
        # Run all checks in parallel
        checks_completed = {}
        
        try:
            results = await asyncio.gather(
                self._check_domain_age(domain),
                self._check_ssl(domain),
                self._check_virustotal(domain),
                self._check_safe_browsing(domain),
                return_exceptions=True
            )
            
            age_result, ssl_result, vt_result, sb_result = results
            
            # Handle exceptions
            if isinstance(age_result, Exception):
                logger.warning(f"Domain age check failed: {age_result}")
                age_result = {"age_days": None, "error": True}
            checks_completed['domain_age'] = not age_result.get('error', False)
            
            if isinstance(ssl_result, Exception):
                logger.warning(f"SSL check failed: {ssl_result}")
                ssl_result = {"valid": False, "expiry_days": None, "error": True}
            checks_completed['ssl'] = not ssl_result.get('error', False)
            
            if isinstance(vt_result, Exception):
                logger.warning(f"VirusTotal check failed: {vt_result}")
                vt_result = {"malicious": 0, "total": 0, "error": True}
            checks_completed['virustotal'] = not vt_result.get('error', False)
            
            if isinstance(sb_result, Exception):
                logger.warning(f"Safe Browsing check failed: {sb_result}")
                sb_result = {"flagged": False, "error": True}
            checks_completed['safe_browsing'] = not sb_result.get('error', False)
            
            # Calculate risk
            risk_level, risk_score = self._calculate_risk(
                age_result, ssl_result, vt_result, sb_result
            )
            
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
                checks_completed=checks_completed
            )
            
            # Cache result
            if self.cache_enabled:
                self._cache_result(domain, result)
            
            return result
        
        except Exception as e:
            logger.error(f"Domain reputation check failed for {domain}: {e}", exc_info=True)
            # Return minimal result
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
                checks_completed=checks_completed
            )
    
    def _extract_domain(self, url: str) -> str:
        """Extract domain from URL."""
        # Add protocol if missing
        if not url.startswith(('http://', 'https://')):
            url = 'https://' + url
        
        parsed = urlparse(url)
        domain = parsed.netloc.lower()
        
        # Remove port if present
        domain = domain.split(':')[0]
        
        return domain
    
    async def _check_domain_age(self, domain: str) -> Dict[str, Any]:
        """Check domain age using WHOIS."""
        try:
            # Run WHOIS in thread pool (blocking operation)
            loop = asyncio.get_event_loop()
            w = await asyncio.wait_for(
                loop.run_in_executor(None, whois.whois, domain),
                timeout=3.0
            )
            
            creation_date = w.creation_date
            if isinstance(creation_date, list):
                creation_date = creation_date[0]
            
            if creation_date:
                age_days = (datetime.now() - creation_date).days
                return {
                    "age_days": age_days,
                    "created": creation_date.isoformat(),
                    "suspicious": age_days < 30
                }
        
        except asyncio.TimeoutError:
            logger.warning(f"WHOIS timeout for {domain}")
        except Exception as e:
            logger.debug(f"WHOIS lookup failed for {domain}: {e}")
        
        return {"age_days": None, "error": True}
    
    async def _check_ssl(self, domain: str) -> Dict[str, Any]:
        """Check SSL certificate validity."""
        try:
            context = ssl.create_default_context()
            
            # Run SSL check in thread pool
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
                expiry_date = datetime.strptime(expiry_str, '%b %d %H:%M:%S %Y %Z')
                days_until_expiry = (expiry_date - datetime.now()).days
                
                return {
                    "valid": days_until_expiry > 0,
                    "expiry_days": days_until_expiry,
                    "expired": days_until_expiry < 0
                }
        
        except asyncio.TimeoutError:
            logger.warning(f"SSL check timeout for {domain}")
        except Exception as e:
            logger.debug(f"SSL check failed for {domain}: {e}")
        
        return {"valid": False, "expiry_days": None, "error": True}
    
    async def _check_virustotal(self, domain: str) -> Dict[str, Any]:
        """Check domain reputation on VirusTotal."""
        if not self.virustotal_api_key:
            logger.debug("VirusTotal API key not configured")
            return {"malicious": 0, "total": 0, "error": True}
        
        try:
            url = f"https://www.virustotal.com/api/v3/domains/{domain}"
            headers = {"x-apikey": self.virustotal_api_key}
            
            async with httpx.AsyncClient(timeout=3.0) as client:
                response = await client.get(url, headers=headers)
                response.raise_for_status()
                
                data = response.json()
                stats = data.get('data', {}).get('attributes', {}).get('last_analysis_stats', {})
                
                malicious = stats.get('malicious', 0)
                suspicious = stats.get('suspicious', 0)
                total = sum(stats.values())
                
                return {
                    "malicious": malicious + suspicious,
                    "total": total,
                    "flagged": (malicious + suspicious) > 0
                }
        
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                # Domain not in VirusTotal database (might be very new)
                return {"malicious": 0, "total": 0, "not_found": True}
            logger.warning(f"VirusTotal API error: {e}")
        except Exception as e:
            logger.warning(f"VirusTotal check failed: {e}")
        
        return {"malicious": 0, "total": 0, "error": True}
    
    async def _check_safe_browsing(self, domain: str) -> Dict[str, Any]:
        """Check domain with Google Safe Browsing API."""
        if not self.safe_browsing_api_key:
            logger.debug("Safe Browsing API key not configured")
            return {"flagged": False, "error": True}
        
        try:
            url = f"https://safebrowsing.googleapis.com/v4/threatMatches:find?key={self.safe_browsing_api_key}"
            
            payload = {
                "client": {
                    "clientId": "typesafe",
                    "clientVersion": "1.0"
                },
                "threatInfo": {
                    "threatTypes": ["MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE"],
                    "platformTypes": ["ANY_PLATFORM"],
                    "threatEntryTypes": ["URL"],
                    "threatEntries": [
                        {"url": f"https://{domain}"},
                        {"url": f"http://{domain}"}
                    ]
                }
            }
            
            async with httpx.AsyncClient(timeout=2.0) as client:
                response = await client.post(url, json=payload)
                response.raise_for_status()
                
                data = response.json()
                matches = data.get('matches', [])
                
                return {
                    "flagged": len(matches) > 0,
                    "threat_types": [m.get('threatType') for m in matches]
                }
        
        except Exception as e:
            logger.warning(f"Safe Browsing check failed: {e}")
        
        return {"flagged": False, "error": True}
    
    def _calculate_risk(
        self,
        age_result: Dict,
        ssl_result: Dict,
        vt_result: Dict,
        sb_result: Dict
    ) -> tuple[str, float]:
        """
        Calculate overall risk level and score.
        
        Returns:
            Tuple of (risk_level, risk_score)
        """
        score = 0.0
        
        # Domain age (0-30 points)
        age_days = age_result.get('age_days')
        if age_days is not None:
            if age_days < 7:
                score += 30
            elif age_days < 30:
                score += 20
            elif age_days < 90:
                score += 10
        
        # SSL certificate (0-20 points)
        if not ssl_result.get('valid'):
            score += 20
        elif ssl_result.get('expiry_days', 0) < 30:
            score += 10
        
        # VirusTotal (0-40 points)
        vt_malicious = vt_result.get('malicious', 0)
        vt_total = vt_result.get('total', 0)
        if vt_total > 0:
            vt_ratio = vt_malicious / vt_total
            score += vt_ratio * 40
        
        # Safe Browsing (0-40 points)
        if sb_result.get('flagged'):
            score += 40
        
        # Determine risk level
        if score >= 70:
            risk_level = "high"
        elif score >= 40:
            risk_level = "medium"
        else:
            risk_level = "low"
        
        return risk_level, min(score, 100.0)
    
    def _get_cache_key(self, domain: str) -> str:
        """Generate cache key for domain."""
        domain_hash = hashlib.md5(domain.encode()).hexdigest()
        return f"domain_reputation:{domain_hash}"
    
    def _get_cached(self, domain: str) -> Optional[DomainReputationResult]:
        """Get cached domain reputation."""
        if not self.cache_enabled:
            return None
        
        try:
            key = self._get_cache_key(domain)
            cached_data = self.cache.get(key)
            
            if cached_data:
                data = json.loads(cached_data)
                return DomainReputationResult(**data)
        
        except Exception as e:
            logger.warning(f"Cache retrieval error: {e}")
        
        return None
    
    def _cache_result(self, domain: str, result: DomainReputationResult):
        """Cache domain reputation result."""
        if not self.cache_enabled:
            return
        
        try:
            key = self._get_cache_key(domain)
            cache_data = result.to_dict()
            
            # Cache for 7 days
            self.cache.setex(
                key,
                604800,  # 7 days
                json.dumps(cache_data)
            )
        
        except Exception as e:
            logger.warning(f"Cache storage error: {e}")


# Singleton instance
_tool_instance = None

def get_domain_reputation_tool() -> DomainReputationTool:
    """Get singleton DomainReputationTool instance."""
    global _tool_instance
    if _tool_instance is None:
        _tool_instance = DomainReputationTool()
    return _tool_instance
```

---

## Testing Strategy

```python
"""Unit tests for Domain Reputation Tool."""

import pytest
from unittest.mock import patch, AsyncMock
from app.agents.tools.domain_reputation import DomainReputationTool


@pytest.fixture
def domain_tool():
    """Fixture providing DomainReputationTool."""
    return DomainReputationTool(cache_enabled=False)


@pytest.mark.asyncio
class TestDomainReputation:
    """Test domain reputation checks."""
    
    async def test_new_domain_flagged(self, domain_tool):
        """Test that new domains are flagged as suspicious."""
        # Mock WHOIS returning 5-day-old domain
        with patch.object(domain_tool, '_check_domain_age', 
                         return_value={"age_days": 5, "suspicious": True}):
            result = await domain_tool.check_domain("new-scam-site.com")
        
        assert result.age_days == 5
        assert result.risk_level in ["high", "medium"]
    
    async def test_missing_ssl_flagged(self, domain_tool):
        """Test that missing SSL increases risk."""
        with patch.object(domain_tool, '_check_ssl',
                         return_value={"valid": False, "expiry_days": None}):
            result = await domain_tool.check_domain("no-ssl-site.com")
        
        assert result.ssl_valid is False
        assert result.risk_score > 0
    
    async def test_virustotal_detection(self, domain_tool):
        """Test VirusTotal malicious detection."""
        with patch.object(domain_tool, '_check_virustotal',
                         return_value={"malicious": 15, "total": 70}):
            result = await domain_tool.check_domain("malicious-site.com")
        
        assert result.virustotal_malicious == 15
        assert result.risk_level == "high"
```

---

## Success Criteria

- [ ] All 33 acceptance criteria met
- [ ] Parallel checks complete in < 5 seconds
- [ ] Caching reduces API calls
- [ ] All unit tests passing
- [ ] Integration with MCP agent tested

---

**Estimated Effort:** 14 hours  
**Sprint:** Week 9, Days 2-3

