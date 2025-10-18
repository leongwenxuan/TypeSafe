# Story 8.3: Scam Database Tool

**Story ID:** 8.3  
**Epic:** Epic 8 - MCP Agent with Multi-Tool Orchestration  
**Priority:** P0 (High-Impact Tool)  
**Effort:** 18 hours  
**Assignee:** Backend Developer  
**Status:** 📝 Ready for Development

---

## User Story

**As an** MCP agent,  
**I want** to query a database of reported scams,  
**so that** I can instantly identify known scam entities with evidence from previous reports.

---

## Description

The Scam Database Tool provides **instant lookups** against a curated database of known scam phone numbers, URLs, email addresses, and payment details. This is the **fastest and most reliable** tool in the MCP agent toolkit because:

1. **No external API calls** - all data is local in Supabase
2. **Sub-10ms query performance** - indexed database lookups
3. **High confidence** - entities in the database have been reported multiple times
4. **Evidence trail** - stores links to sources, complaint details, report counts

**Real-World Example:**
```
User screenshot: "URGENT: Call +1-800-555-FAKE for refund"
↓
Agent extracts: +18005551234
↓
Scam Database Tool: FOUND - 47 reports, last seen 2 days ago
↓
High confidence verdict: "This number is in our scam database with 47 previous reports"
```

---

## Acceptance Criteria

### Database Schema
- [ ] 1. New Supabase table `scam_reports` created with proper schema
- [ ] 2. Columns: `id`, `entity_type`, `entity_value`, `report_count`, `risk_score`, `first_seen`, `last_reported`, `evidence`, `verified`, `created_at`, `updated_at`
- [ ] 3. Indexes: `entity_type` + `entity_value` (composite), `risk_score`, `last_reported`
- [ ] 4. Entity types: `phone`, `url`, `email`, `payment`, `bitcoin`
- [ ] 5. Risk score: 0-100 scale, calculated based on report count and verification status
- [ ] 6. Evidence JSONB field stores: `[{"source": "reddit", "url": "...", "date": "2025-10-01"}]`
- [ ] 7. Verified flag: Boolean for manually verified scams by admins

### Tool Implementation
- [ ] 8. `ScamDatabaseTool` class created in `app/agents/tools/scam_database.py`
- [ ] 9. Methods: `check_phone()`, `check_url()`, `check_email()`, `check_payment()`, `check_bulk()`
- [ ] 10. Return format: `{"found": bool, "report_count": int, "risk_score": int, "evidence": list, "last_reported": str}`
- [ ] 11. Phone number normalization before lookup (E164 format)
- [ ] 12. URL normalization: domain-only matching (flexible, catches variations)
- [ ] 13. Email case-insensitive matching
- [ ] 14. Bulk check support: query multiple entities in single database call

### Performance
- [ ] 15. Single entity lookup: < 10ms (p95)
- [ ] 16. Bulk lookup (10 entities): < 50ms (p95)
- [ ] 17. Database connection pooling configured
- [ ] 18. Query optimization: All lookups use indexes

### Data Quality
- [ ] 19. Deduplication: Prevent duplicate entries for same entity
- [ ] 20. Increment report count when duplicate reported
- [ ] 21. Update `last_reported` timestamp on new reports
- [ ] 22. Automatic risk score calculation based on reports and recency
- [ ] 23. Archived old reports (> 1 year, no recent activity) move to `archived_scam_reports`

### Admin API
- [ ] 24. `POST /admin/scam-reports` - Add new scam report (requires admin auth)
- [ ] 25. `GET /admin/scam-reports` - List reports with filters (type, risk_score, date range)
- [ ] 26. `PATCH /admin/scam-reports/{id}` - Update report (verify, adjust risk score)
- [ ] 27. `DELETE /admin/scam-reports/{id}` - Remove false positive
- [ ] 28. Rate limiting: Max 100 admin API calls per hour per user

### Testing
- [ ] 29. Unit tests: All CRUD operations
- [ ] 30. Unit tests: Normalization functions (phone E164, URL domain extraction)
- [ ] 31. Integration tests: Real database queries
- [ ] 32. Performance tests: Query latency benchmarks
- [ ] 33. Load test: 1000 concurrent lookups

---

## Technical Implementation

### Database Schema

**Migration: `migrations/005_create_scam_reports.sql`**

```sql
-- Scam reports table
CREATE TABLE scam_reports (
  id BIGSERIAL PRIMARY KEY,
  entity_type TEXT NOT NULL CHECK (entity_type IN ('phone', 'url', 'email', 'payment', 'bitcoin')),
  entity_value TEXT NOT NULL,  -- Normalized value (E164 for phones, lowercase domain for URLs)
  report_count INT DEFAULT 1 CHECK (report_count >= 0),
  risk_score NUMERIC(5,2) DEFAULT 50.0 CHECK (risk_score BETWEEN 0 AND 100),
  first_seen TIMESTAMPTZ DEFAULT NOW(),
  last_reported TIMESTAMPTZ DEFAULT NOW(),
  evidence JSONB DEFAULT '[]'::jsonb,  -- Array of evidence objects
  verified BOOLEAN DEFAULT FALSE,  -- Manually verified by admin
  notes TEXT,  -- Admin notes
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Composite index for fast lookups
CREATE UNIQUE INDEX idx_scam_reports_entity ON scam_reports(entity_type, entity_value);

-- Index for filtering by risk score
CREATE INDEX idx_scam_reports_risk_score ON scam_reports(risk_score DESC);

-- Index for filtering by recency
CREATE INDEX idx_scam_reports_last_reported ON scam_reports(last_reported DESC);

-- Index for verified scams
CREATE INDEX idx_scam_reports_verified ON scam_reports(verified) WHERE verified = TRUE;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_scam_reports_updated_at BEFORE UPDATE ON scam_reports
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to calculate risk score
CREATE OR REPLACE FUNCTION calculate_risk_score(
  p_report_count INT,
  p_verified BOOLEAN,
  p_days_since_last_report INT
) RETURNS NUMERIC AS $$
BEGIN
  -- Base score from report count (max 50 points)
  DECLARE
    base_score NUMERIC := LEAST(p_report_count * 2, 50);
    verified_bonus NUMERIC := CASE WHEN p_verified THEN 30 ELSE 0 END;
    recency_bonus NUMERIC := CASE 
      WHEN p_days_since_last_report < 7 THEN 20
      WHEN p_days_since_last_report < 30 THEN 15
      WHEN p_days_since_last_report < 90 THEN 10
      ELSE 5
    END;
  BEGIN
    RETURN LEAST(base_score + verified_bonus + recency_bonus, 100);
  END;
END;
$$ LANGUAGE plpgsql;

-- Archived scam reports (for historical data)
CREATE TABLE archived_scam_reports (
  LIKE scam_reports INCLUDING ALL
);

COMMENT ON TABLE scam_reports IS 'Active scam reports database for MCP agent lookups';
COMMENT ON COLUMN scam_reports.entity_value IS 'Normalized entity value (E164 for phones, lowercase for domains)';
COMMENT ON COLUMN scam_reports.risk_score IS 'Risk score 0-100 calculated from report count, verification, and recency';
COMMENT ON COLUMN scam_reports.evidence IS 'JSONB array of evidence objects with source, url, date';
```

### Core Implementation

**`app/agents/tools/scam_database.py`:**

```python
"""Scam Database Tool for MCP Agent."""

from typing import Dict, List, Any, Optional
from datetime import datetime, timezone
import logging
from dataclasses import dataclass

from app.db.client import get_supabase_client
from supabase import Client

logger = logging.getLogger(__name__)


@dataclass
class ScamLookupResult:
    """Result from scam database lookup."""
    found: bool
    entity_type: str
    entity_value: str
    report_count: int = 0
    risk_score: float = 0.0
    evidence: List[Dict[str, Any]] = None
    last_reported: Optional[str] = None
    verified: bool = False
    first_seen: Optional[str] = None
    
    def __post_init__(self):
        if self.evidence is None:
            self.evidence = []
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "found": self.found,
            "entity_type": self.entity_type,
            "entity_value": self.entity_value,
            "report_count": self.report_count,
            "risk_score": self.risk_score,
            "evidence": self.evidence,
            "last_reported": self.last_reported,
            "verified": self.verified,
            "first_seen": self.first_seen
        }


class ScamDatabaseTool:
    """
    Tool for querying scam database.
    
    Provides fast lookups against known scam entities (phones, URLs, emails, payments).
    """
    
    def __init__(self, supabase_client: Optional[Client] = None):
        """
        Initialize scam database tool.
        
        Args:
            supabase_client: Optional Supabase client (uses default if not provided)
        """
        self.supabase = supabase_client or get_supabase_client()
        logger.info("ScamDatabaseTool initialized")
    
    def check_phone(self, phone: str) -> ScamLookupResult:
        """
        Check if phone number is in scam database.
        
        Args:
            phone: Phone number in E164 format (e.g., +18005551234)
        
        Returns:
            ScamLookupResult with details if found
        """
        return self._lookup("phone", phone)
    
    def check_url(self, url: str, domain_only: bool = True) -> ScamLookupResult:
        """
        Check if URL is in scam database.
        
        Args:
            url: Full URL or domain
            domain_only: If True, extract and match domain only (more flexible)
        
        Returns:
            ScamLookupResult with details if found
        """
        if domain_only:
            # Extract domain for matching
            from urllib.parse import urlparse
            parsed = urlparse(url if url.startswith('http') else f'https://{url}')
            domain = parsed.netloc.lower()
            value = domain
        else:
            value = url.lower()
        
        return self._lookup("url", value)
    
    def check_email(self, email: str) -> ScamLookupResult:
        """
        Check if email is in scam database.
        
        Args:
            email: Email address
        
        Returns:
            ScamLookupResult with details if found
        """
        return self._lookup("email", email.lower())
    
    def check_payment(self, payment_value: str, payment_type: str = "payment") -> ScamLookupResult:
        """
        Check if payment detail is in scam database.
        
        Args:
            payment_value: Payment identifier (account number, bitcoin address, etc.)
            payment_type: Type of payment ('payment', 'bitcoin')
        
        Returns:
            ScamLookupResult with details if found
        """
        return self._lookup(payment_type, payment_value)
    
    def check_bulk(self, entities: List[Dict[str, str]]) -> List[ScamLookupResult]:
        """
        Check multiple entities in one database query.
        
        Args:
            entities: List of dicts with 'type' and 'value' keys
                     Example: [{"type": "phone", "value": "+18005551234"}, ...]
        
        Returns:
            List of ScamLookupResult objects
        """
        if not entities:
            return []
        
        results = []
        
        try:
            # Build query conditions
            conditions = []
            for entity in entities:
                entity_type = entity.get("type")
                entity_value = entity.get("value")
                if entity_type and entity_value:
                    conditions.append({
                        "entity_type": entity_type,
                        "entity_value": entity_value
                    })
            
            if not conditions:
                return []
            
            # Query database (bulk lookup)
            response = self.supabase.table('scam_reports').select('*').or_(
                ','.join([
                    f'and(entity_type.eq.{c["entity_type"]},entity_value.eq.{c["entity_value"]})'
                    for c in conditions
                ])
            ).execute()
            
            found_entities = {
                (row['entity_type'], row['entity_value']): row
                for row in response.data
            }
            
            # Build results maintaining order
            for entity in entities:
                entity_type = entity.get("type")
                entity_value = entity.get("value")
                key = (entity_type, entity_value)
                
                if key in found_entities:
                    row = found_entities[key]
                    results.append(self._parse_result(row, found=True))
                else:
                    results.append(ScamLookupResult(
                        found=False,
                        entity_type=entity_type,
                        entity_value=entity_value
                    ))
        
        except Exception as e:
            logger.error(f"Bulk lookup error: {e}", exc_info=True)
            # Return not-found results for all entities
            for entity in entities:
                results.append(ScamLookupResult(
                    found=False,
                    entity_type=entity.get("type", "unknown"),
                    entity_value=entity.get("value", "")
                ))
        
        return results
    
    def _lookup(self, entity_type: str, entity_value: str) -> ScamLookupResult:
        """
        Internal lookup method.
        
        Args:
            entity_type: Type of entity (phone, url, email, payment)
            entity_value: Normalized entity value
        
        Returns:
            ScamLookupResult
        """
        try:
            logger.debug(f"Looking up {entity_type}: {entity_value}")
            
            response = self.supabase.table('scam_reports').select('*').eq(
                'entity_type', entity_type
            ).eq(
                'entity_value', entity_value
            ).maybe_single().execute()
            
            if response.data:
                return self._parse_result(response.data, found=True)
            else:
                return ScamLookupResult(
                    found=False,
                    entity_type=entity_type,
                    entity_value=entity_value
                )
        
        except Exception as e:
            logger.error(f"Database lookup error for {entity_type}/{entity_value}: {e}", exc_info=True)
            return ScamLookupResult(
                found=False,
                entity_type=entity_type,
                entity_value=entity_value
            )
    
    def _parse_result(self, row: Dict[str, Any], found: bool) -> ScamLookupResult:
        """Parse database row into ScamLookupResult."""
        return ScamLookupResult(
            found=found,
            entity_type=row['entity_type'],
            entity_value=row['entity_value'],
            report_count=row['report_count'],
            risk_score=float(row['risk_score']),
            evidence=row['evidence'] or [],
            last_reported=row['last_reported'],
            verified=row['verified'],
            first_seen=row['first_seen']
        )
    
    def add_report(
        self,
        entity_type: str,
        entity_value: str,
        evidence: Optional[Dict[str, Any]] = None
    ) -> bool:
        """
        Add or update scam report.
        
        Args:
            entity_type: Type of entity
            entity_value: Normalized entity value
            evidence: Optional evidence dict with source, url, date
        
        Returns:
            True if successful, False otherwise
        """
        try:
            # Check if exists
            existing = self._lookup(entity_type, entity_value)
            
            if existing.found:
                # Update existing: increment count, add evidence, update timestamp
                new_evidence = existing.evidence.copy()
                if evidence:
                    new_evidence.append(evidence)
                
                new_count = existing.report_count + 1
                days_since = (datetime.now(timezone.utc) - 
                             datetime.fromisoformat(existing.last_reported.replace('Z', '+00:00'))).days
                
                # Recalculate risk score
                from app.db.client import get_supabase_client
                calc_response = get_supabase_client().rpc(
                    'calculate_risk_score',
                    {
                        'p_report_count': new_count,
                        'p_verified': existing.verified,
                        'p_days_since_last_report': 0  # Just reported
                    }
                ).execute()
                
                new_risk_score = calc_response.data if calc_response.data else 70.0
                
                # Update
                self.supabase.table('scam_reports').update({
                    'report_count': new_count,
                    'last_reported': datetime.now(timezone.utc).isoformat(),
                    'evidence': new_evidence,
                    'risk_score': new_risk_score
                }).eq('entity_type', entity_type).eq('entity_value', entity_value).execute()
                
                logger.info(f"Updated scam report: {entity_type}/{entity_value} (count: {new_count})")
            else:
                # Insert new
                self.supabase.table('scam_reports').insert({
                    'entity_type': entity_type,
                    'entity_value': entity_value,
                    'report_count': 1,
                    'risk_score': 50.0,  # Default initial score
                    'evidence': [evidence] if evidence else [],
                    'first_seen': datetime.now(timezone.utc).isoformat(),
                    'last_reported': datetime.now(timezone.utc).isoformat()
                }).execute()
                
                logger.info(f"Added new scam report: {entity_type}/{entity_value}")
            
            return True
        
        except Exception as e:
            logger.error(f"Error adding scam report: {e}", exc_info=True)
            return False


# Singleton instance
_tool_instance = None

def get_scam_database_tool() -> ScamDatabaseTool:
    """Get singleton ScamDatabaseTool instance."""
    global _tool_instance
    if _tool_instance is None:
        _tool_instance = ScamDatabaseTool()
    return _tool_instance
```

### Admin API Endpoints

**`app/main.py` (Admin routes):**

```python
"""Admin API endpoints for scam database management."""

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

from app.agents.tools.scam_database import get_scam_database_tool, ScamLookupResult

router = APIRouter(prefix="/admin/scam-reports", tags=["admin"])


class CreateScamReportRequest(BaseModel):
    entity_type: str
    entity_value: str
    evidence: Optional[dict] = None


class UpdateScamReportRequest(BaseModel):
    verified: Optional[bool] = None
    risk_score: Optional[float] = None
    notes: Optional[str] = None


@router.post("/", status_code=201)
async def create_scam_report(request: CreateScamReportRequest):
    """Add new scam report to database."""
    tool = get_scam_database_tool()
    
    success = tool.add_report(
        entity_type=request.entity_type,
        entity_value=request.entity_value,
        evidence=request.evidence
    )
    
    if not success:
        raise HTTPException(status_code=500, detail="Failed to create scam report")
    
    return {"message": "Scam report created successfully"}


@router.get("/")
async def list_scam_reports(
    entity_type: Optional[str] = None,
    min_risk_score: Optional[float] = None,
    verified_only: bool = False,
    limit: int = 100,
    offset: int = 0
):
    """List scam reports with filters."""
    from app.db.client import get_supabase_client
    supabase = get_supabase_client()
    
    query = supabase.table('scam_reports').select('*')
    
    if entity_type:
        query = query.eq('entity_type', entity_type)
    
    if min_risk_score is not None:
        query = query.gte('risk_score', min_risk_score)
    
    if verified_only:
        query = query.eq('verified', True)
    
    query = query.order('last_reported', desc=True).limit(limit).offset(offset)
    
    response = query.execute()
    
    return {
        "reports": response.data,
        "count": len(response.data),
        "limit": limit,
        "offset": offset
    }


@router.patch("/{report_id}")
async def update_scam_report(report_id: int, request: UpdateScamReportRequest):
    """Update scam report (verify, adjust risk score, add notes)."""
    from app.db.client import get_supabase_client
    supabase = get_supabase_client()
    
    update_data = {}
    if request.verified is not None:
        update_data['verified'] = request.verified
    if request.risk_score is not None:
        update_data['risk_score'] = request.risk_score
    if request.notes is not None:
        update_data['notes'] = request.notes
    
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")
    
    response = supabase.table('scam_reports').update(update_data).eq('id', report_id).execute()
    
    if not response.data:
        raise HTTPException(status_code=404, detail="Scam report not found")
    
    return {"message": "Scam report updated successfully", "report": response.data[0]}


@router.delete("/{report_id}")
async def delete_scam_report(report_id: int):
    """Delete scam report (remove false positive)."""
    from app.db.client import get_supabase_client
    supabase = get_supabase_client()
    
    response = supabase.table('scam_reports').delete().eq('id', report_id).execute()
    
    if not response.data:
        raise HTTPException(status_code=404, detail="Scam report not found")
    
    return {"message": "Scam report deleted successfully"}
```

---

## Testing Strategy

**`tests/test_scam_database_tool.py`:**

```python
"""Unit tests for Scam Database Tool."""

import pytest
from app.agents.tools.scam_database import ScamDatabaseTool, ScamLookupResult


@pytest.fixture
def scam_tool():
    """Fixture providing ScamDatabaseTool instance."""
    return ScamDatabaseTool()


class TestPhoneLookup:
    """Test phone number lookups."""
    
    def test_found_phone(self, scam_tool):
        # Assuming seeded database with this number
        result = scam_tool.check_phone("+18005551234")
        
        if result.found:
            assert result.report_count > 0
            assert result.risk_score > 0
    
    def test_not_found_phone(self, scam_tool):
        result = scam_tool.check_phone("+19999999999")
        assert result.found is False


class TestURLLookup:
    """Test URL lookups."""
    
    def test_domain_matching(self, scam_tool):
        # Test that different URL formats match same domain
        result1 = scam_tool.check_url("http://scam-site.com/page")
        result2 = scam_tool.check_url("https://scam-site.com/different")
        result3 = scam_tool.check_url("scam-site.com")
        
        # All should match same domain
        assert result1.entity_value == result2.entity_value == result3.entity_value


class TestBulkLookup:
    """Test bulk lookups."""
    
    def test_bulk_check(self, scam_tool):
        entities = [
            {"type": "phone", "value": "+18005551234"},
            {"type": "url", "value": "scam-site.com"},
            {"type": "email", "value": "scam@example.com"}
        ]
        
        results = scam_tool.check_bulk(entities)
        
        assert len(results) == 3
        assert all(isinstance(r, ScamLookupResult) for r in results)


class TestAddReport:
    """Test adding reports."""
    
    def test_add_new_report(self, scam_tool):
        success = scam_tool.add_report(
            entity_type="phone",
            entity_value="+11234567890",
            evidence={"source": "test", "url": "http://test.com"}
        )
        
        assert success is True
        
        # Verify it was added
        result = scam_tool.check_phone("+11234567890")
        assert result.found is True
    
    def test_increment_existing(self, scam_tool):
        # Add twice
        scam_tool.add_report("phone", "+11234567891")
        scam_tool.add_report("phone", "+11234567891")
        
        result = scam_tool.check_phone("+11234567891")
        assert result.report_count >= 2
```

---

## Seeding Strategy

See **Story 8.12** for comprehensive database seeding implementation.

Initial seed sources:
- Manual CSV import of known scam numbers
- PhishTank API integration
- Community submissions

---

## Success Criteria

- [ ] All 33 acceptance criteria met
- [ ] Query performance: < 10ms for single lookups
- [ ] Admin API functional with all CRUD operations
- [ ] Database migration executed successfully
- [ ] Seeded with 10,000+ initial scam entities
- [ ] All unit tests passing
- [ ] Integration with MCP agent tested

---

## Dependencies

- **Upstream:** Story 8.2 (Entity Extraction for normalization)
- **Downstream:** Story 8.7 (MCP Agent Orchestration uses this tool)

---

**Estimated Effort:** 18 hours  
**Sprint:** Week 8, Days 3-4

