"""
Scam Database Tool for MCP Agent.

Provides fast lookups against a curated database of known scam entities (phones, URLs,
emails, payment details). This is the fastest tool in the MCP agent toolkit with
sub-10ms query performance using indexed database lookups.

Story: 8.3 - Scam Database Tool
"""

from typing import Dict, List, Any, Optional, Union
from datetime import datetime, timezone
import logging
from dataclasses import dataclass, field, asdict
from urllib.parse import urlparse

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
    evidence: List[Dict[str, Any]] = field(default_factory=list)
    last_reported: Optional[str] = None
    verified: bool = False
    first_seen: Optional[str] = None
    notes: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return asdict(self)
    
    def __str__(self) -> str:
        """Human-readable string representation."""
        if not self.found:
            return f"ScamLookupResult(NOT FOUND: {self.entity_type}/{self.entity_value})"
        return (
            f"ScamLookupResult(FOUND: {self.entity_type}/{self.entity_value}, "
            f"reports={self.report_count}, risk={self.risk_score}, verified={self.verified})"
        )


class ScamDatabaseTool:
    """
    Tool for querying scam database.
    
    Provides fast lookups against known scam entities with high confidence results.
    All data is local in Supabase for sub-10ms query performance.
    
    Features:
    - Multiple entity types: phone, url, email, payment, bitcoin
    - Bulk lookup support
    - Evidence trail with sources
    - Risk score calculation
    - Report count tracking
    
    Example:
        >>> tool = ScamDatabaseTool()
        >>> result = tool.check_phone("+18005551234")
        >>> if result.found:
        ...     print(f"Scam found with {result.report_count} reports")
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
            phone: Phone number in E164 format (e.g., +18005551234) or any format
        
        Returns:
            ScamLookupResult with details if found
            
        Example:
            >>> tool.check_phone("+1-800-555-1234")
            ScamLookupResult(FOUND: phone/+18005551234, reports=47, ...)
        """
        # Normalize phone number (remove formatting, keep + and digits)
        normalized = self._normalize_phone(phone)
        return self._lookup("phone", normalized)
    
    def check_url(self, url: str, domain_only: bool = True) -> ScamLookupResult:
        """
        Check if URL is in scam database.
        
        Args:
            url: Full URL or domain
            domain_only: If True, extract and match domain only (more flexible)
        
        Returns:
            ScamLookupResult with details if found
            
        Example:
            >>> tool.check_url("http://scam-site.com/page")
            >>> tool.check_url("scam-site.com")
        """
        if domain_only:
            # Extract domain for matching
            value = self._extract_domain(url)
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
            
        Example:
            >>> tool.check_email("scam@example.com")
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
            
        Example:
            >>> tool.check_payment("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa", "bitcoin")
        """
        return self._lookup(payment_type, payment_value)
    
    def check_bulk(self, entities: List[Dict[str, str]]) -> List[ScamLookupResult]:
        """
        Check multiple entities in one database query (optimized for performance).
        
        Args:
            entities: List of dicts with 'type' and 'value' keys
                     Example: [{"type": "phone", "value": "+18005551234"}, ...]
        
        Returns:
            List of ScamLookupResult objects in same order as input
            
        Example:
            >>> entities = [
            ...     {"type": "phone", "value": "+18005551234"},
            ...     {"type": "url", "value": "scam-site.com"}
            ... ]
            >>> results = tool.check_bulk(entities)
        """
        if not entities:
            return []
        
        results = []
        
        try:
            # Normalize entities
            normalized_entities = []
            for entity in entities:
                entity_type = entity.get("type")
                entity_value = entity.get("value")
                
                if not entity_type or not entity_value:
                    continue
                
                # Normalize based on type
                if entity_type == "phone":
                    normalized_value = self._normalize_phone(entity_value)
                elif entity_type == "url":
                    normalized_value = self._extract_domain(entity_value)
                elif entity_type == "email":
                    normalized_value = entity_value.lower()
                else:
                    normalized_value = entity_value
                
                normalized_entities.append({
                    "type": entity_type,
                    "value": normalized_value
                })
            
            if not normalized_entities:
                return []
            
            # Build OR query for bulk lookup
            # Query all entities at once using OR conditions
            or_conditions = []
            for entity in normalized_entities:
                or_conditions.append(
                    f'and(entity_type.eq.{entity["type"]},entity_value.eq.{entity["value"]})'
                )
            
            response = self.supabase.table('scam_reports').select('*').or_(
                ','.join(or_conditions)
            ).execute()
            
            # Create lookup map for found entities
            found_entities = {
                (row['entity_type'], row['entity_value']): row
                for row in response.data
            }
            
            # Build results maintaining order
            for entity in normalized_entities:
                entity_type = entity["type"]
                entity_value = entity["value"]
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
            # Return not-found results for all entities on error
            for entity in entities:
                results.append(ScamLookupResult(
                    found=False,
                    entity_type=entity.get("type", "unknown"),
                    entity_value=entity.get("value", "")
                ))
        
        return results
    
    def add_report(
        self,
        entity_type: str,
        entity_value: str,
        evidence: Optional[Dict[str, Any]] = None,
        notes: Optional[str] = None
    ) -> bool:
        """
        Add or update scam report.
        
        If the entity already exists, increments report count and updates evidence.
        If new, creates a new record with initial risk score.
        
        Args:
            entity_type: Type of entity (phone, url, email, payment, bitcoin)
            entity_value: Normalized entity value
            evidence: Optional evidence dict with source, url, date
            notes: Optional admin notes
        
        Returns:
            True if successful, False otherwise
            
        Example:
            >>> tool.add_report(
            ...     "phone",
            ...     "+18005551234",
            ...     evidence={"source": "user_report", "date": "2025-10-18"}
            ... )
        """
        try:
            # Normalize value based on type
            if entity_type == "phone":
                entity_value = self._normalize_phone(entity_value)
            elif entity_type == "url":
                entity_value = self._extract_domain(entity_value)
            elif entity_type == "email":
                entity_value = entity_value.lower()
            
            # Check if exists
            existing = self._lookup(entity_type, entity_value)
            
            if existing.found:
                # Update existing: increment count, add evidence, update timestamp
                new_evidence = existing.evidence.copy()
                if evidence:
                    new_evidence.append(evidence)
                
                new_count = existing.report_count + 1
                
                # Calculate days since last report for risk score
                if existing.last_reported:
                    last_reported_dt = datetime.fromisoformat(
                        existing.last_reported.replace('Z', '+00:00')
                    )
                    days_since = (datetime.now(timezone.utc) - last_reported_dt).days
                else:
                    days_since = 0
                
                # Recalculate risk score using database function
                calc_response = self.supabase.rpc(
                    'calculate_risk_score',
                    {
                        'p_report_count': new_count,
                        'p_verified': existing.verified,
                        'p_days_since_last_report': 0  # Just reported now
                    }
                ).execute()
                
                new_risk_score = float(calc_response.data) if calc_response.data else 70.0
                
                # Update record
                update_data = {
                    'report_count': new_count,
                    'last_reported': datetime.now(timezone.utc).isoformat(),
                    'evidence': new_evidence,
                    'risk_score': new_risk_score
                }
                
                if notes:
                    update_data['notes'] = notes
                
                self.supabase.table('scam_reports').update(update_data).eq(
                    'entity_type', entity_type
                ).eq('entity_value', entity_value).execute()
                
                logger.info(
                    f"Updated scam report: {entity_type}/{entity_value} "
                    f"(count: {new_count}, risk: {new_risk_score})"
                )
            else:
                # Insert new
                now = datetime.now(timezone.utc).isoformat()
                insert_data = {
                    'entity_type': entity_type,
                    'entity_value': entity_value,
                    'report_count': 1,
                    'risk_score': 50.0,  # Default initial score
                    'evidence': [evidence] if evidence else [],
                    'first_seen': now,
                    'last_reported': now,
                    'notes': notes
                }
                
                self.supabase.table('scam_reports').insert(insert_data).execute()
                
                logger.info(f"Added new scam report: {entity_type}/{entity_value}")
            
            return True
        
        except Exception as e:
            logger.error(f"Error adding scam report: {e}", exc_info=True)
            return False
    
    def get_all_reports(
        self,
        entity_type: Optional[str] = None,
        limit: int = 100,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        """
        Get all scam reports with optional filtering.
        
        Args:
            entity_type: Optional filter by entity type
            limit: Maximum number of records (default 100)
            offset: Offset for pagination (default 0)
        
        Returns:
            List of scam report dictionaries
        """
        try:
            query = self.supabase.table('scam_reports').select('*')
            
            if entity_type:
                query = query.eq('entity_type', entity_type)
            
            query = query.order('risk_score', desc=True).limit(limit).offset(offset)
            
            response = query.execute()
            return response.data or []
        
        except Exception as e:
            logger.error(f"Error fetching reports: {e}", exc_info=True)
            return []
    
    # =========================================================================
    # Private Helper Methods
    # =========================================================================
    
    def _lookup(self, entity_type: str, entity_value: str) -> ScamLookupResult:
        """
        Internal lookup method.
        
        Args:
            entity_type: Type of entity (phone, url, email, payment, bitcoin)
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
            
            if response and response.data:
                return self._parse_result(response.data, found=True)
            else:
                return ScamLookupResult(
                    found=False,
                    entity_type=entity_type,
                    entity_value=entity_value
                )
        
        except Exception as e:
            logger.error(
                f"Database lookup error for {entity_type}/{entity_value}: {e}",
                exc_info=True
            )
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
            evidence=row.get('evidence') or [],
            last_reported=row.get('last_reported'),
            verified=row.get('verified', False),
            first_seen=row.get('first_seen'),
            notes=row.get('notes')
        )
    
    @staticmethod
    def _normalize_phone(phone: str) -> str:
        """
        Normalize phone number to consistent format.
        
        Removes all formatting except + and digits.
        
        Args:
            phone: Phone number in any format
        
        Returns:
            Normalized phone number (e.g., "+18005551234")
        """
        # Keep only + and digits
        normalized = ''.join(c for c in phone if c.isdigit() or c == '+')
        
        # Ensure it starts with +
        if not normalized.startswith('+'):
            # Assume US number if no country code
            normalized = '+1' + normalized
        
        return normalized
    
    @staticmethod
    def _extract_domain(url: str) -> str:
        """
        Extract domain from URL.
        
        Args:
            url: Full URL or domain
        
        Returns:
            Lowercase domain (e.g., "example.com")
        """
        # Add scheme if missing for proper parsing
        if not url.startswith(('http://', 'https://')):
            url = f'https://{url}'
        
        try:
            parsed = urlparse(url)
            domain = parsed.netloc.lower()
            
            # Remove www. prefix if present
            if domain.startswith('www.'):
                domain = domain[4:]
            
            return domain
        except Exception:
            # If parsing fails, return lowercase original
            return url.lower()


# =============================================================================
# Singleton Instance
# =============================================================================

_tool_instance: Optional[ScamDatabaseTool] = None


def get_scam_database_tool() -> ScamDatabaseTool:
    """
    Get singleton ScamDatabaseTool instance.
    
    Returns:
        Singleton instance of ScamDatabaseTool
    """
    global _tool_instance
    if _tool_instance is None:
        _tool_instance = ScamDatabaseTool()
    return _tool_instance

