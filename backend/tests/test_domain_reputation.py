"""
Unit tests for Domain Reputation Tool (Story 8.5).

Tests all aspects of domain reputation checking including:
- Domain age checks (WHOIS)
- SSL certificate validation
- VirusTotal integration
- Google Safe Browsing integration
- Risk scoring logic
- Caching behavior
- Error handling
"""

import pytest
from unittest.mock import patch, MagicMock, AsyncMock
from datetime import datetime, timedelta
import json

from app.agents.tools.domain_reputation import (
    DomainReputationTool,
    DomainReputationResult,
    get_domain_reputation_tool
)


@pytest.fixture
def domain_tool():
    """Fixture providing DomainReputationTool with cache disabled."""
    return DomainReputationTool(cache_enabled=False)


@pytest.fixture
def domain_tool_with_keys():
    """Fixture providing DomainReputationTool with API keys."""
    return DomainReputationTool(
        virustotal_api_key="test_vt_key",
        safe_browsing_api_key="test_sb_key",
        cache_enabled=False
    )


@pytest.mark.asyncio
class TestDomainExtraction:
    """Test domain extraction from various URL formats."""
    
    async def test_extract_domain_from_full_url(self, domain_tool):
        """Test extracting domain from full URL."""
        domain = domain_tool._extract_domain("https://example.com/path?query=1")
        assert domain == "example.com"
    
    async def test_extract_domain_from_bare_domain(self, domain_tool):
        """Test extracting domain from bare domain."""
        domain = domain_tool._extract_domain("example.com")
        assert domain == "example.com"
    
    async def test_extract_domain_removes_www(self, domain_tool):
        """Test that www prefix is removed."""
        domain = domain_tool._extract_domain("https://www.example.com")
        assert domain == "example.com"
    
    async def test_extract_domain_removes_port(self, domain_tool):
        """Test that port is removed."""
        domain = domain_tool._extract_domain("https://example.com:8080")
        assert domain == "example.com"
    
    async def test_extract_domain_handles_subdomain(self, domain_tool):
        """Test subdomain handling."""
        domain = domain_tool._extract_domain("https://api.example.com")
        assert domain == "api.example.com"
    
    async def test_extract_domain_empty_input(self, domain_tool):
        """Test handling of empty input."""
        domain = domain_tool._extract_domain("")
        assert domain == ""


@pytest.mark.asyncio
class TestDomainAgeCheck:
    """Test WHOIS domain age checks."""
    
    async def test_new_domain_flagged(self, domain_tool):
        """Test that new domains (< 30 days) are flagged as suspicious."""
        mock_whois = MagicMock()
        mock_whois.creation_date = datetime.now() - timedelta(days=5)
        
        with patch('app.agents.tools.domain_reputation.whois') as mock_whois_module:
            mock_whois_module.whois = MagicMock(return_value=mock_whois)
            
            result = await domain_tool._check_domain_age("new-domain.com")
        
        assert result['age_days'] == 5
        assert result['suspicious'] is True
    
    async def test_old_domain_not_flagged(self, domain_tool):
        """Test that old domains (> 30 days) are not flagged."""
        mock_whois = MagicMock()
        mock_whois.creation_date = datetime.now() - timedelta(days=365)
        
        with patch('app.agents.tools.domain_reputation.whois') as mock_whois_module:
            mock_whois_module.whois = MagicMock(return_value=mock_whois)
            
            result = await domain_tool._check_domain_age("old-domain.com")
        
        assert result['age_days'] == 365
        assert result['suspicious'] is False
    
    async def test_whois_handles_date_list(self, domain_tool):
        """Test handling of WHOIS returning list of dates."""
        mock_whois = MagicMock()
        # Some domains return multiple creation dates
        mock_whois.creation_date = [
            datetime.now() - timedelta(days=100),
            datetime.now() - timedelta(days=50)
        ]
        
        with patch('app.agents.tools.domain_reputation.whois') as mock_whois_module:
            mock_whois_module.whois = MagicMock(return_value=mock_whois)
            
            result = await domain_tool._check_domain_age("domain.com")
        
        # Should use first date
        assert result['age_days'] == 100
    
    async def test_whois_timeout_handled(self, domain_tool):
        """Test graceful handling of WHOIS timeout."""
        with patch('app.agents.tools.domain_reputation.whois') as mock_whois_module:
            # Simulate timeout
            async def slow_whois(*args):
                import asyncio
                await asyncio.sleep(10)
            
            mock_whois_module.whois = slow_whois
            
            result = await domain_tool._check_domain_age("slow-domain.com")
        
        assert result['age_days'] is None
        assert 'error' in result
    
    async def test_whois_not_available(self, domain_tool):
        """Test handling when python-whois is not installed."""
        with patch('app.agents.tools.domain_reputation.whois', None):
            tool = DomainReputationTool(cache_enabled=False)
            result = await tool._check_domain_age("domain.com")
        
        assert result['age_days'] is None
        assert 'error' in result


@pytest.mark.asyncio
class TestSSLCheck:
    """Test SSL certificate validation."""
    
    async def test_valid_ssl_certificate(self, domain_tool):
        """Test detection of valid SSL certificate."""
        mock_cert = {
            'notAfter': (datetime.now() + timedelta(days=90)).strftime('%b %d %H:%M:%S %Y GMT')
        }
        
        with patch('socket.create_connection') as mock_socket:
            mock_ssl = MagicMock()
            mock_ssl.__enter__().getpeercert.return_value = mock_cert
            mock_socket.return_value.__enter__().return_value = MagicMock()
            
            with patch('ssl.create_default_context') as mock_ssl_ctx:
                mock_ssl_ctx.return_value.wrap_socket.return_value = mock_ssl
                
                result = await domain_tool._check_ssl("valid-domain.com")
        
        assert result['valid'] is True
        assert result['expiry_days'] > 0
    
    async def test_expired_ssl_certificate(self, domain_tool):
        """Test detection of expired SSL certificate."""
        mock_cert = {
            'notAfter': (datetime.now() - timedelta(days=10)).strftime('%b %d %H:%M:%S %Y GMT')
        }
        
        with patch('socket.create_connection') as mock_socket:
            mock_ssl = MagicMock()
            mock_ssl.__enter__().getpeercert.return_value = mock_cert
            
            with patch('ssl.create_default_context') as mock_ssl_ctx:
                mock_ssl_ctx.return_value.wrap_socket.return_value = mock_ssl
                
                result = await domain_tool._check_ssl("expired-domain.com")
        
        assert result['valid'] is False
        assert result['expired'] is True
    
    async def test_missing_ssl_certificate(self, domain_tool):
        """Test detection of missing SSL certificate."""
        with patch('socket.create_connection') as mock_socket:
            mock_socket.side_effect = Exception("Connection refused")
            
            result = await domain_tool._check_ssl("no-ssl-domain.com")
        
        assert result['valid'] is False
        assert 'error' in result
    
    async def test_ssl_check_timeout(self, domain_tool):
        """Test handling of SSL check timeout."""
        with patch('socket.create_connection') as mock_socket:
            # Simulate timeout
            import asyncio
            async def slow_connect(*args, **kwargs):
                await asyncio.sleep(10)
                return MagicMock()
            
            mock_socket.side_effect = slow_connect
            
            result = await domain_tool._check_ssl("slow-domain.com")
        
        assert result['valid'] is False
        assert 'error' in result


@pytest.mark.asyncio
class TestVirusTotal:
    """Test VirusTotal integration."""
    
    async def test_virustotal_clean_domain(self, domain_tool_with_keys):
        """Test VirusTotal check for clean domain."""
        mock_response = {
            'data': {
                'attributes': {
                    'last_analysis_stats': {
                        'malicious': 0,
                        'suspicious': 0,
                        'harmless': 70,
                        'undetected': 10
                    }
                }
            }
        }
        
        with patch('httpx.AsyncClient') as mock_client:
            mock_client.return_value.__aenter__.return_value.get = AsyncMock(
                return_value=MagicMock(
                    json=lambda: mock_response,
                    raise_for_status=lambda: None
                )
            )
            
            result = await domain_tool_with_keys._check_virustotal("clean-domain.com")
        
        assert result['malicious'] == 0
        assert result['total'] == 80
        assert result['flagged'] is False
    
    async def test_virustotal_malicious_domain(self, domain_tool_with_keys):
        """Test VirusTotal check for malicious domain."""
        mock_response = {
            'data': {
                'attributes': {
                    'last_analysis_stats': {
                        'malicious': 15,
                        'suspicious': 5,
                        'harmless': 50,
                        'undetected': 10
                    }
                }
            }
        }
        
        with patch('httpx.AsyncClient') as mock_client:
            mock_client.return_value.__aenter__.return_value.get = AsyncMock(
                return_value=MagicMock(
                    json=lambda: mock_response,
                    raise_for_status=lambda: None
                )
            )
            
            result = await domain_tool_with_keys._check_virustotal("malicious-domain.com")
        
        assert result['malicious'] == 20  # malicious + suspicious
        assert result['flagged'] is True
    
    async def test_virustotal_domain_not_found(self, domain_tool_with_keys):
        """Test VirusTotal check for domain not in database."""
        import httpx
        
        with patch('httpx.AsyncClient') as mock_client:
            mock_response = MagicMock()
            mock_response.status_code = 404
            
            mock_client.return_value.__aenter__.return_value.get = AsyncMock(
                side_effect=httpx.HTTPStatusError(
                    "Not found",
                    request=MagicMock(),
                    response=mock_response
                )
            )
            
            result = await domain_tool_with_keys._check_virustotal("new-domain.com")
        
        assert result['malicious'] == 0
        assert result['not_found'] is True
    
    async def test_virustotal_rate_limit(self, domain_tool_with_keys):
        """Test handling of VirusTotal rate limit."""
        import httpx
        
        with patch('httpx.AsyncClient') as mock_client:
            mock_response = MagicMock()
            mock_response.status_code = 429
            
            mock_client.return_value.__aenter__.return_value.get = AsyncMock(
                side_effect=httpx.HTTPStatusError(
                    "Rate limit",
                    request=MagicMock(),
                    response=mock_response
                )
            )
            
            result = await domain_tool_with_keys._check_virustotal("domain.com")
        
        assert 'error' in result
        assert 'rate limit' in result['error'].lower()
    
    async def test_virustotal_no_api_key(self, domain_tool):
        """Test VirusTotal check without API key."""
        result = await domain_tool._check_virustotal("domain.com")
        
        assert result['malicious'] == 0
        assert 'error' in result


@pytest.mark.asyncio
class TestSafeBrowsing:
    """Test Google Safe Browsing integration."""
    
    async def test_safe_browsing_clean_domain(self, domain_tool_with_keys):
        """Test Safe Browsing check for clean domain."""
        mock_response = {}  # Empty response = no threats
        
        with patch('httpx.AsyncClient') as mock_client:
            mock_client.return_value.__aenter__.return_value.post = AsyncMock(
                return_value=MagicMock(
                    json=lambda: mock_response,
                    raise_for_status=lambda: None
                )
            )
            
            result = await domain_tool_with_keys._check_safe_browsing("clean-domain.com")
        
        assert result['flagged'] is False
    
    async def test_safe_browsing_flagged_domain(self, domain_tool_with_keys):
        """Test Safe Browsing check for flagged domain."""
        mock_response = {
            'matches': [
                {'threatType': 'MALWARE'},
                {'threatType': 'SOCIAL_ENGINEERING'}
            ]
        }
        
        with patch('httpx.AsyncClient') as mock_client:
            mock_client.return_value.__aenter__.return_value.post = AsyncMock(
                return_value=MagicMock(
                    json=lambda: mock_response,
                    raise_for_status=lambda: None
                )
            )
            
            result = await domain_tool_with_keys._check_safe_browsing("malicious-domain.com")
        
        assert result['flagged'] is True
        assert 'MALWARE' in result['threat_types']
        assert 'SOCIAL_ENGINEERING' in result['threat_types']
    
    async def test_safe_browsing_no_api_key(self, domain_tool):
        """Test Safe Browsing check without API key."""
        result = await domain_tool._check_safe_browsing("domain.com")
        
        assert result['flagged'] is False
        assert 'error' in result


@pytest.mark.asyncio
class TestRiskCalculation:
    """Test risk scoring logic."""
    
    async def test_high_risk_new_domain_no_ssl_flagged(self, domain_tool):
        """Test high risk for new domain with no SSL and flagged by services."""
        age_result = {"age_days": 5, "suspicious": True}
        ssl_result = {"valid": False, "expiry_days": None}
        vt_result = {"malicious": 20, "total": 70, "flagged": True}
        sb_result = {"flagged": True}
        
        risk_level, risk_score = domain_tool._calculate_risk(
            age_result, ssl_result, vt_result, sb_result
        )
        
        assert risk_level == "high"
        assert risk_score >= 70
    
    async def test_medium_risk_new_domain_valid_ssl(self, domain_tool):
        """Test medium risk for new domain with valid SSL but not flagged."""
        age_result = {"age_days": 15, "suspicious": True}
        ssl_result = {"valid": True, "expiry_days": 90}
        vt_result = {"malicious": 0, "total": 70, "flagged": False}
        sb_result = {"flagged": False}
        
        risk_level, risk_score = domain_tool._calculate_risk(
            age_result, ssl_result, vt_result, sb_result
        )
        
        assert risk_level in ["low", "medium"]
        assert risk_score < 70
    
    async def test_low_risk_old_domain_clean(self, domain_tool):
        """Test low risk for old domain with valid SSL and clean reputation."""
        age_result = {"age_days": 365, "suspicious": False}
        ssl_result = {"valid": True, "expiry_days": 90}
        vt_result = {"malicious": 0, "total": 70, "flagged": False}
        sb_result = {"flagged": False}
        
        risk_level, risk_score = domain_tool._calculate_risk(
            age_result, ssl_result, vt_result, sb_result
        )
        
        assert risk_level == "low"
        assert risk_score < 40
    
    async def test_risk_with_partial_checks(self, domain_tool):
        """Test risk calculation when some checks fail."""
        age_result = {"age_days": None, "error": True}
        ssl_result = {"valid": False, "expiry_days": None}
        vt_result = {"malicious": 0, "total": 0, "error": True}
        sb_result = {"flagged": True}
        
        risk_level, risk_score = domain_tool._calculate_risk(
            age_result, ssl_result, vt_result, sb_result
        )
        
        # Should still calculate risk based on available data
        assert risk_level in ["low", "medium", "high", "unknown"]
        assert 0 <= risk_score <= 100


@pytest.mark.asyncio
class TestFullDomainCheck:
    """Test complete domain reputation checks."""
    
    async def test_complete_domain_check(self, domain_tool_with_keys):
        """Test full domain check with all services."""
        # Mock all checks
        with patch.object(domain_tool_with_keys, '_check_domain_age') as mock_age, \
             patch.object(domain_tool_with_keys, '_check_ssl') as mock_ssl, \
             patch.object(domain_tool_with_keys, '_check_virustotal') as mock_vt, \
             patch.object(domain_tool_with_keys, '_check_safe_browsing') as mock_sb:
            
            mock_age.return_value = {"age_days": 100, "suspicious": False}
            mock_ssl.return_value = {"valid": True, "expiry_days": 90}
            mock_vt.return_value = {"malicious": 0, "total": 70, "flagged": False}
            mock_sb.return_value = {"flagged": False}
            
            result = await domain_tool_with_keys.check_domain("https://example.com")
        
        assert result.domain == "example.com"
        assert result.risk_level == "low"
        assert result.age_days == 100
        assert result.ssl_valid is True
        assert all(result.checks_completed.values())
    
    async def test_malicious_domain_detection(self, domain_tool_with_keys):
        """Test detection of clearly malicious domain."""
        with patch.object(domain_tool_with_keys, '_check_domain_age') as mock_age, \
             patch.object(domain_tool_with_keys, '_check_ssl') as mock_ssl, \
             patch.object(domain_tool_with_keys, '_check_virustotal') as mock_vt, \
             patch.object(domain_tool_with_keys, '_check_safe_browsing') as mock_sb:
            
            mock_age.return_value = {"age_days": 3, "suspicious": True}
            mock_ssl.return_value = {"valid": False, "expiry_days": None}
            mock_vt.return_value = {"malicious": 25, "total": 70, "flagged": True}
            mock_sb.return_value = {"flagged": True}
            
            result = await domain_tool_with_keys.check_domain("malicious-site.com")
        
        assert result.risk_level == "high"
        assert result.risk_score >= 70
        assert result.virustotal_malicious > 0
        assert result.safe_browsing_flagged is True
    
    async def test_graceful_degradation(self, domain_tool_with_keys):
        """Test that check continues even if some services fail."""
        with patch.object(domain_tool_with_keys, '_check_domain_age') as mock_age, \
             patch.object(domain_tool_with_keys, '_check_ssl') as mock_ssl, \
             patch.object(domain_tool_with_keys, '_check_virustotal') as mock_vt, \
             patch.object(domain_tool_with_keys, '_check_safe_browsing') as mock_sb:
            
            mock_age.side_effect = Exception("WHOIS service down")
            mock_ssl.return_value = {"valid": True, "expiry_days": 90}
            mock_vt.side_effect = Exception("VT service down")
            mock_sb.return_value = {"flagged": False}
            
            result = await domain_tool_with_keys.check_domain("example.com")
        
        # Should still return result with available data
        assert result.domain == "example.com"
        assert result.checks_completed['ssl'] is True
        assert result.checks_completed['safe_browsing'] is True
        assert result.checks_completed['domain_age'] is False
        assert result.checks_completed['virustotal'] is False


@pytest.mark.asyncio
class TestCaching:
    """Test caching functionality."""
    
    async def test_cache_stores_results(self):
        """Test that results are cached."""
        mock_redis = MagicMock()
        mock_redis.ping.return_value = True
        mock_redis.get.return_value = None
        
        with patch('redis.from_url', return_value=mock_redis):
            tool = DomainReputationTool(cache_enabled=True)
            
            with patch.object(tool, '_check_domain_age') as mock_age, \
                 patch.object(tool, '_check_ssl') as mock_ssl, \
                 patch.object(tool, '_check_virustotal') as mock_vt, \
                 patch.object(tool, '_check_safe_browsing') as mock_sb:
                
                mock_age.return_value = {"age_days": 100}
                mock_ssl.return_value = {"valid": True, "expiry_days": 90}
                mock_vt.return_value = {"malicious": 0, "total": 70}
                mock_sb.return_value = {"flagged": False}
                
                await tool.check_domain("example.com")
            
            # Verify cache write was called
            assert mock_redis.setex.called
    
    async def test_cache_retrieval(self):
        """Test that cached results are used."""
        cached_result = {
            "domain": "example.com",
            "age_days": 100,
            "ssl_valid": True,
            "ssl_expiry_days": 90,
            "virustotal_malicious": 0,
            "virustotal_total": 70,
            "safe_browsing_flagged": False,
            "risk_level": "low",
            "risk_score": 10.0,
            "checks_completed": {"domain_age": True, "ssl": True, "virustotal": True, "safe_browsing": True},
            "error_messages": {}
        }
        
        mock_redis = MagicMock()
        mock_redis.ping.return_value = True
        mock_redis.get.return_value = json.dumps(cached_result)
        
        with patch('redis.from_url', return_value=mock_redis):
            tool = DomainReputationTool(cache_enabled=True)
            
            result = await tool.check_domain("example.com")
        
        assert result.domain == "example.com"
        assert result.risk_level == "low"
        # Verify cache was checked
        assert mock_redis.get.called


@pytest.mark.asyncio
class TestSingletonPattern:
    """Test singleton instance pattern."""
    
    async def test_get_singleton_instance(self):
        """Test that get_domain_reputation_tool returns singleton."""
        instance1 = get_domain_reputation_tool()
        instance2 = get_domain_reputation_tool()
        
        assert instance1 is instance2


@pytest.mark.asyncio
class TestEdgeCases:
    """Test edge cases and error handling."""
    
    async def test_invalid_url(self, domain_tool):
        """Test handling of invalid URL."""
        result = await domain_tool.check_domain("")
        
        assert result.risk_level == "unknown"
        assert 'general' in result.error_messages
    
    async def test_url_normalization(self, domain_tool):
        """Test that different URL formats are normalized correctly."""
        urls = [
            "https://example.com",
            "http://example.com",
            "example.com",
            "www.example.com",
            "https://www.example.com/path?query=1",
        ]
        
        for url in urls:
            domain = domain_tool._extract_domain(url)
            assert domain == "example.com"
    
    async def test_concurrent_checks(self, domain_tool_with_keys):
        """Test that multiple checks can run concurrently."""
        with patch.object(domain_tool_with_keys, '_check_domain_age') as mock_age, \
             patch.object(domain_tool_with_keys, '_check_ssl') as mock_ssl, \
             patch.object(domain_tool_with_keys, '_check_virustotal') as mock_vt, \
             patch.object(domain_tool_with_keys, '_check_safe_browsing') as mock_sb:
            
            mock_age.return_value = {"age_days": 100}
            mock_ssl.return_value = {"valid": True, "expiry_days": 90}
            mock_vt.return_value = {"malicious": 0, "total": 70}
            mock_sb.return_value = {"flagged": False}
            
            # Run multiple checks
            import asyncio
            results = await asyncio.gather(
                domain_tool_with_keys.check_domain("domain1.com"),
                domain_tool_with_keys.check_domain("domain2.com"),
                domain_tool_with_keys.check_domain("domain3.com")
            )
        
        assert len(results) == 3
        assert all(r.domain for r in results)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

