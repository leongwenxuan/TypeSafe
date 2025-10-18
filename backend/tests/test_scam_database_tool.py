"""
Unit tests for Scam Database Tool.

Tests all functionality of the ScamDatabaseTool including:
- Phone number lookups and normalization
- URL/domain lookups and extraction
- Email lookups
- Payment/bitcoin lookups
- Bulk lookups
- Adding and updating reports
- Evidence handling
- Risk score calculation

Story: 8.3 - Scam Database Tool
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime, timezone

from app.agents.tools.scam_database import (
    ScamDatabaseTool,
    ScamLookupResult,
    get_scam_database_tool
)


# =============================================================================
# Fixtures
# =============================================================================

@pytest.fixture
def mock_supabase_client():
    """Mock Supabase client for testing."""
    mock_client = Mock()
    mock_table = Mock()
    mock_client.table.return_value = mock_table
    return mock_client


@pytest.fixture
def scam_tool(mock_supabase_client):
    """Fixture providing ScamDatabaseTool instance with mocked client."""
    return ScamDatabaseTool(supabase_client=mock_supabase_client)


# =============================================================================
# Test Phone Number Lookups
# =============================================================================

class TestPhoneLookup:
    """Test phone number lookups and normalization."""
    
    def test_check_phone_found(self, scam_tool, mock_supabase_client):
        """Test successful phone lookup."""
        # Mock database response
        mock_response = Mock()
        mock_response.data = {
            'entity_type': 'phone',
            'entity_value': '+18005551234',
            'report_count': 47,
            'risk_score': 95.5,
            'evidence': [{'source': 'ftc', 'date': '2025-10-01'}],
            'last_reported': '2025-10-18T10:00:00Z',
            'verified': True,
            'first_seen': '2025-09-01T00:00:00Z',
            'notes': 'Known IRS scam'
        }
        
        mock_supabase_client.table().select().eq().eq().maybe_single().execute.return_value = mock_response
        
        # Test lookup
        result = scam_tool.check_phone("+1-800-555-1234")
        
        assert result.found is True
        assert result.entity_type == 'phone'
        assert result.entity_value == '+18005551234'
        assert result.report_count == 47
        assert result.risk_score == 95.5
        assert result.verified is True
        assert len(result.evidence) == 1
        assert result.notes == 'Known IRS scam'
    
    def test_check_phone_not_found(self, scam_tool, mock_supabase_client):
        """Test phone lookup for non-existent number."""
        mock_response = Mock()
        mock_response.data = None
        
        mock_supabase_client.table().select().eq().eq().maybe_single().execute.return_value = mock_response
        
        result = scam_tool.check_phone("+19999999999")
        
        assert result.found is False
        assert result.entity_type == 'phone'
        assert result.report_count == 0
        assert result.risk_score == 0.0
    
    def test_phone_normalization(self, scam_tool):
        """Test phone number normalization."""
        # Test various formats
        assert scam_tool._normalize_phone("+1-800-555-1234") == "+18005551234"
        assert scam_tool._normalize_phone("1 (800) 555-1234") == "+18005551234"
        assert scam_tool._normalize_phone("800.555.1234") == "+18005551234"
        assert scam_tool._normalize_phone("+44 20 7946 0958") == "+442079460958"
        
        # Test adding country code for US numbers
        assert scam_tool._normalize_phone("8005551234") == "+18005551234"


# =============================================================================
# Test URL/Domain Lookups
# =============================================================================

class TestURLLookup:
    """Test URL lookups and domain extraction."""
    
    def test_check_url_found(self, scam_tool, mock_supabase_client):
        """Test successful URL lookup."""
        mock_response = Mock()
        mock_response.data = {
            'entity_type': 'url',
            'entity_value': 'scam-site.com',
            'report_count': 34,
            'risk_score': 88.0,
            'evidence': [{'source': 'phishtank', 'date': '2025-10-10'}],
            'last_reported': '2025-10-17T15:30:00Z',
            'verified': True,
            'first_seen': '2025-09-15T00:00:00Z',
            'notes': 'Bank phishing site'
        }
        
        mock_supabase_client.table().select().eq().eq().maybe_single().execute.return_value = mock_response
        
        result = scam_tool.check_url("http://scam-site.com/page")
        
        assert result.found is True
        assert result.entity_type == 'url'
        assert result.entity_value == 'scam-site.com'
        assert result.report_count == 34
    
    def test_domain_extraction(self, scam_tool):
        """Test domain extraction from various URL formats."""
        # Full URLs
        assert scam_tool._extract_domain("http://scam-site.com/page") == "scam-site.com"
        assert scam_tool._extract_domain("https://scam-site.com/path/to/page") == "scam-site.com"
        
        # Without protocol
        assert scam_tool._extract_domain("scam-site.com") == "scam-site.com"
        
        # With www
        assert scam_tool._extract_domain("www.scam-site.com") == "scam-site.com"
        assert scam_tool._extract_domain("https://www.scam-site.com") == "scam-site.com"
        
        # With subdomains
        assert scam_tool._extract_domain("https://secure.scam-site.com") == "secure.scam-site.com"
    
    def test_domain_matching_consistency(self, scam_tool, mock_supabase_client):
        """Test that different URL formats match same domain."""
        mock_response = Mock()
        mock_response.data = None
        mock_supabase_client.table().select().eq().eq().maybe_single().execute.return_value = mock_response
        
        # All these should normalize to the same domain
        result1 = scam_tool.check_url("http://scam-site.com/page")
        result2 = scam_tool.check_url("https://scam-site.com/different")
        result3 = scam_tool.check_url("scam-site.com")
        
        assert result1.entity_value == result2.entity_value == result3.entity_value


# =============================================================================
# Test Email Lookups
# =============================================================================

class TestEmailLookup:
    """Test email lookups."""
    
    def test_check_email_found(self, scam_tool, mock_supabase_client):
        """Test successful email lookup."""
        mock_response = Mock()
        mock_response.data = {
            'entity_type': 'email',
            'entity_value': 'scam@example.com',
            'report_count': 12,
            'risk_score': 75.0,
            'evidence': [],
            'last_reported': '2025-10-15T12:00:00Z',
            'verified': False,
            'first_seen': '2025-10-01T00:00:00Z',
            'notes': None
        }
        
        mock_supabase_client.table().select().eq().eq().maybe_single().execute.return_value = mock_response
        
        result = scam_tool.check_email("scam@example.com")
        
        assert result.found is True
        assert result.entity_type == 'email'
        assert result.report_count == 12
    
    def test_email_case_insensitive(self, scam_tool, mock_supabase_client):
        """Test email lookup is case-insensitive."""
        mock_response = Mock()
        mock_response.data = None
        mock_supabase_client.table().select().eq().eq().maybe_single().execute.return_value = mock_response
        
        result1 = scam_tool.check_email("SCAM@EXAMPLE.COM")
        result2 = scam_tool.check_email("scam@example.com")
        
        # Both should be normalized to lowercase
        assert result1.entity_value == result2.entity_value == "scam@example.com"


# =============================================================================
# Test Payment/Bitcoin Lookups
# =============================================================================

class TestPaymentLookup:
    """Test payment and bitcoin address lookups."""
    
    def test_check_bitcoin(self, scam_tool, mock_supabase_client):
        """Test bitcoin address lookup."""
        mock_response = Mock()
        mock_response.data = {
            'entity_type': 'bitcoin',
            'entity_value': '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa',
            'report_count': 67,
            'risk_score': 92.0,
            'evidence': [{'source': 'bitcoinabuse', 'date': '2025-10-01'}],
            'last_reported': '2025-10-16T08:00:00Z',
            'verified': True,
            'first_seen': '2025-08-01T00:00:00Z',
            'notes': 'Sextortion scam'
        }
        
        mock_supabase_client.table().select().eq().eq().maybe_single().execute.return_value = mock_response
        
        result = scam_tool.check_payment(
            '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa',
            payment_type='bitcoin'
        )
        
        assert result.found is True
        assert result.entity_type == 'bitcoin'
        assert result.report_count == 67
    
    def test_check_payment_generic(self, scam_tool, mock_supabase_client):
        """Test generic payment detail lookup."""
        mock_response = Mock()
        mock_response.data = None
        mock_supabase_client.table().select().eq().eq().maybe_single().execute.return_value = mock_response
        
        result = scam_tool.check_payment('ACCT123456789', payment_type='payment')
        
        assert result.entity_type == 'payment'


# =============================================================================
# Test Bulk Lookups
# =============================================================================

class TestBulkLookup:
    """Test bulk lookup functionality."""
    
    def test_check_bulk_mixed(self, scam_tool, mock_supabase_client):
        """Test bulk check with mixed entity types."""
        # Mock database response
        mock_response = Mock()
        mock_response.data = [
            {
                'entity_type': 'phone',
                'entity_value': '+18005551234',
                'report_count': 47,
                'risk_score': 95.5,
                'evidence': [],
                'last_reported': '2025-10-18T10:00:00Z',
                'verified': True,
                'first_seen': '2025-09-01T00:00:00Z',
                'notes': None
            }
        ]
        
        mock_supabase_client.table().select().or_().execute.return_value = mock_response
        
        entities = [
            {"type": "phone", "value": "+18005551234"},
            {"type": "url", "value": "safe-site.com"},
            {"type": "email", "value": "test@example.com"}
        ]
        
        results = scam_tool.check_bulk(entities)
        
        assert len(results) == 3
        assert results[0].found is True  # Phone found
        assert results[0].entity_type == 'phone'
        assert results[1].found is False  # URL not found
        assert results[2].found is False  # Email not found
    
    def test_check_bulk_empty(self, scam_tool):
        """Test bulk check with empty list."""
        results = scam_tool.check_bulk([])
        assert results == []
    
    def test_check_bulk_normalization(self, scam_tool, mock_supabase_client):
        """Test bulk check normalizes entities correctly."""
        mock_response = Mock()
        mock_response.data = []
        mock_supabase_client.table().select().or_().execute.return_value = mock_response
        
        entities = [
            {"type": "phone", "value": "1-800-555-1234"},
            {"type": "url", "value": "http://example.com/page"},
            {"type": "email", "value": "TEST@EXAMPLE.COM"}
        ]
        
        results = scam_tool.check_bulk(entities)
        
        # Verify normalization happened
        assert results[0].entity_value == '+18005551234'
        assert results[1].entity_value == 'example.com'
        assert results[2].entity_value == 'test@example.com'


# =============================================================================
# Test Adding Reports
# =============================================================================

class TestAddReport:
    """Test adding and updating scam reports."""
    
    def test_add_new_report(self, scam_tool, mock_supabase_client):
        """Test adding a new scam report."""
        # Mock lookup returns not found
        mock_lookup_response = Mock()
        mock_lookup_response.data = None
        
        # Mock insert succeeds
        mock_insert_response = Mock()
        mock_insert_response.data = [{'id': 1}]
        
        mock_supabase_client.table().select().eq().eq().maybe_single().execute.return_value = mock_lookup_response
        mock_supabase_client.table().insert().execute.return_value = mock_insert_response
        
        success = scam_tool.add_report(
            entity_type="phone",
            entity_value="+11234567890",
            evidence={"source": "test", "url": "http://test.com", "date": "2025-10-18"},
            notes="Test scam report"
        )
        
        assert success is True
    
    def test_update_existing_report(self, scam_tool, mock_supabase_client):
        """Test updating an existing report (incrementing count)."""
        # Mock lookup returns existing report
        mock_lookup_response = Mock()
        mock_lookup_response.data = {
            'entity_type': 'phone',
            'entity_value': '+11234567890',
            'report_count': 5,
            'risk_score': 60.0,
            'evidence': [{'source': 'old', 'date': '2025-10-01'}],
            'last_reported': '2025-10-15T10:00:00Z',
            'verified': False,
            'first_seen': '2025-10-01T00:00:00Z',
            'notes': None
        }
        
        # Mock RPC for risk score calculation
        mock_rpc_response = Mock()
        mock_rpc_response.data = 75.0
        
        # Mock update succeeds
        mock_update_response = Mock()
        mock_update_response.data = [{'id': 1}]
        
        mock_supabase_client.table().select().eq().eq().maybe_single().execute.return_value = mock_lookup_response
        mock_supabase_client.rpc().execute.return_value = mock_rpc_response
        mock_supabase_client.table().update().eq().eq().execute.return_value = mock_update_response
        
        success = scam_tool.add_report(
            entity_type="phone",
            entity_value="+11234567890",
            evidence={"source": "new", "date": "2025-10-18"}
        )
        
        assert success is True
    
    def test_add_report_handles_error(self, scam_tool, mock_supabase_client):
        """Test add_report handles database errors gracefully."""
        # Mock lookup raises exception
        mock_supabase_client.table().select().eq().eq().maybe_single().execute.side_effect = Exception("DB Error")
        
        success = scam_tool.add_report(
            entity_type="phone",
            entity_value="+11234567890"
        )
        
        assert success is False


# =============================================================================
# Test Lookup Result
# =============================================================================

class TestScamLookupResult:
    """Test ScamLookupResult dataclass."""
    
    def test_to_dict(self):
        """Test conversion to dictionary."""
        result = ScamLookupResult(
            found=True,
            entity_type='phone',
            entity_value='+18005551234',
            report_count=47,
            risk_score=95.5,
            evidence=[{'source': 'ftc'}],
            last_reported='2025-10-18T10:00:00Z',
            verified=True,
            first_seen='2025-09-01T00:00:00Z',
            notes='Test note'
        )
        
        result_dict = result.to_dict()
        
        assert result_dict['found'] is True
        assert result_dict['entity_type'] == 'phone'
        assert result_dict['report_count'] == 47
        assert result_dict['risk_score'] == 95.5
        assert len(result_dict['evidence']) == 1
    
    def test_string_representation(self):
        """Test string representation."""
        result_found = ScamLookupResult(
            found=True,
            entity_type='phone',
            entity_value='+18005551234',
            report_count=47,
            risk_score=95.5
        )
        
        result_not_found = ScamLookupResult(
            found=False,
            entity_type='phone',
            entity_value='+19999999999'
        )
        
        assert "FOUND" in str(result_found)
        assert "reports=47" in str(result_found)
        assert "NOT FOUND" in str(result_not_found)


# =============================================================================
# Test Singleton
# =============================================================================

class TestSingleton:
    """Test singleton pattern."""
    
    def test_get_scam_database_tool_singleton(self):
        """Test that get_scam_database_tool returns singleton."""
        with patch('app.agents.tools.scam_database.get_supabase_client'):
            tool1 = get_scam_database_tool()
            tool2 = get_scam_database_tool()
            
            # Should be same instance
            assert tool1 is tool2


# =============================================================================
# Test Error Handling
# =============================================================================

class TestErrorHandling:
    """Test error handling in various scenarios."""
    
    def test_lookup_handles_database_error(self, scam_tool, mock_supabase_client):
        """Test lookup handles database errors gracefully."""
        mock_supabase_client.table().select().eq().eq().maybe_single().execute.side_effect = Exception("DB Connection Error")
        
        result = scam_tool.check_phone("+18005551234")
        
        # Should return not found result instead of raising exception
        assert result.found is False
        assert result.entity_type == 'phone'
    
    def test_bulk_lookup_handles_error(self, scam_tool, mock_supabase_client):
        """Test bulk lookup handles errors gracefully."""
        mock_supabase_client.table().select().or_().execute.side_effect = Exception("DB Error")
        
        entities = [
            {"type": "phone", "value": "+18005551234"},
            {"type": "url", "value": "example.com"}
        ]
        
        results = scam_tool.check_bulk(entities)
        
        # Should return not-found results for all entities
        assert len(results) == 2
        assert all(not r.found for r in results)


# =============================================================================
# Integration-style Tests (can be skipped if no test database)
# =============================================================================

@pytest.mark.integration
class TestIntegration:
    """Integration tests with real database (optional)."""
    
    def test_full_workflow(self):
        """Test complete workflow: add, lookup, update."""
        # This would test with a real test database
        # Skip in unit tests, run separately with test database
        pytest.skip("Requires test database")

