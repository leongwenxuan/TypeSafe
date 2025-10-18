"""
Database CRUD operations for TypeSafe tables.

All operations use the Supabase client and follow the schema defined
in the migrations. Functions handle error checking and return structured data.
"""

from typing import Dict, Any, Optional, List
from uuid import UUID
from datetime import datetime, timezone
from .client import get_supabase_client


def insert_session(session_id: UUID) -> Dict[str, Any]:
    """
    Insert a new session record.
    
    Args:
        session_id: UUID identifying the session
        
    Returns:
        Dict containing the inserted session data
        
    Raises:
        Exception: If insert fails
    """
    client = get_supabase_client()
    
    data = {
        "session_id": str(session_id),
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    
    response = client.table("sessions").insert(data).execute()
    
    if not response.data:
        raise Exception("Failed to insert session")
    
    return response.data[0]


def get_session(session_id: UUID) -> Optional[Dict[str, Any]]:
    """
    Get a session record by session_id.
    
    Args:
        session_id: UUID identifying the session
        
    Returns:
        Dict containing the session data, or None if not found
    """
    client = get_supabase_client()
    
    response = client.table("sessions")\
        .select("*")\
        .eq("session_id", str(session_id))\
        .execute()
    
    return response.data[0] if response.data else None


def ensure_session_exists(session_id: UUID) -> Dict[str, Any]:
    """
    Ensure a session exists, creating it if it doesn't.
    
    Args:
        session_id: UUID identifying the session
        
    Returns:
        Dict containing the session data (existing or newly created)
        
    Raises:
        Exception: If session creation fails
    """
    # Check if session already exists
    existing_session = get_session(session_id)
    if existing_session:
        return existing_session
    
    # Session doesn't exist, create it
    return insert_session(session_id)


def insert_text_analysis(
    session_id: UUID,
    app_bundle: str,
    snippet: str,
    risk_data: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Insert a text analysis result.
    
    Args:
        session_id: UUID identifying the session
        app_bundle: App bundle identifier (e.g., "com.example.app")
        snippet: Text snippet that was analyzed
        risk_data: Dictionary containing:
            - risk_level: str ("low", "medium", or "high")
            - confidence: float (0.0 to 1.0)
            - category: str (e.g., "phishing", "credentials", "safe")
            - explanation: str (human-readable explanation)
            
    Returns:
        Dict containing the inserted text_analysis record
        
    Raises:
        ValueError: If risk_level is not valid
        Exception: If insert fails
    """
    # Validate risk_level
    valid_risk_levels = ["low", "medium", "high"]
    risk_level = risk_data.get("risk_level", "").lower()
    if risk_level not in valid_risk_levels:
        raise ValueError(
            f"Invalid risk_level: {risk_level}. "
            f"Must be one of {valid_risk_levels}"
        )
    
    client = get_supabase_client()
    
    data = {
        "session_id": str(session_id),
        "app_bundle": app_bundle,
        "snippet": snippet,
        "risk_level": risk_level,
        "confidence": risk_data.get("confidence", 0.0),
        "category": risk_data.get("category", ""),
        "explanation": risk_data.get("explanation", ""),
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    
    response = client.table("text_analyses").insert(data).execute()
    
    if not response.data:
        raise Exception("Failed to insert text analysis")
    
    return response.data[0]


def insert_scan_result(
    session_id: UUID,
    ocr_text: str,
    risk_data: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Insert a screenshot scan analysis result.
    
    Args:
        session_id: UUID identifying the session
        ocr_text: Text extracted from screenshot via OCR
        risk_data: Dictionary containing:
            - risk_level: str (any string, no constraint)
            - confidence: float (0.0 to 1.0)
            - category: str (e.g., "phishing", "safe")
            - explanation: str (human-readable explanation)
            
    Returns:
        Dict containing the inserted scan_result record
        
    Raises:
        Exception: If insert fails
    """
    client = get_supabase_client()
    
    data = {
        "session_id": str(session_id),
        "ocr_text": ocr_text,
        "risk_level": risk_data.get("risk_level", ""),
        "confidence": risk_data.get("confidence", 0.0),
        "category": risk_data.get("category", ""),
        "explanation": risk_data.get("explanation", ""),
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    
    response = client.table("scan_results").insert(data).execute()
    
    if not response.data:
        raise Exception("Failed to insert scan result")
    
    return response.data[0]


def get_latest_result(session_id: UUID) -> Optional[Dict[str, Any]]:
    """
    Get the most recent analysis result for a session.
    
    Queries both text_analyses and scan_results tables and returns
    the most recent result based on created_at timestamp.
    
    Args:
        session_id: UUID identifying the session
        
    Returns:
        Dict containing the latest result with keys:
            - type: "text_analysis" or "scan_result"
            - data: The result data
            - created_at: Timestamp
        Returns None if no results found
    """
    client = get_supabase_client()
    session_id_str = str(session_id)
    
    # Query text_analyses
    text_response = client.table("text_analyses")\
        .select("*")\
        .eq("session_id", session_id_str)\
        .order("created_at", desc=True)\
        .limit(1)\
        .execute()
    
    # Query scan_results
    scan_response = client.table("scan_results")\
        .select("*")\
        .eq("session_id", session_id_str)\
        .order("created_at", desc=True)\
        .limit(1)\
        .execute()
    
    # Determine which is more recent
    text_result = text_response.data[0] if text_response.data else None
    scan_result = scan_response.data[0] if scan_response.data else None
    
    if not text_result and not scan_result:
        return None
    
    if text_result and not scan_result:
        return {
            "type": "text_analysis",
            "data": text_result,
            "created_at": text_result["created_at"]
        }
    
    if scan_result and not text_result:
        return {
            "type": "scan_result",
            "data": scan_result,
            "created_at": scan_result["created_at"]
        }
    
    # Both exist, compare timestamps
    text_time = datetime.fromisoformat(text_result["created_at"].replace("Z", "+00:00"))
    scan_time = datetime.fromisoformat(scan_result["created_at"].replace("Z", "+00:00"))
    
    if text_time > scan_time:
        return {
            "type": "text_analysis",
            "data": text_result,
            "created_at": text_result["created_at"]
        }
    else:
        return {
            "type": "scan_result",
            "data": scan_result,
            "created_at": scan_result["created_at"]
        }


def get_session_history(
    session_id: UUID,
    limit: int = 10
) -> Dict[str, List[Dict[str, Any]]]:
    """
    Get recent analysis history for a session.
    
    Args:
        session_id: UUID identifying the session
        limit: Maximum number of results per type (default 10)
        
    Returns:
        Dict with keys:
            - text_analyses: List of text analysis results
            - scan_results: List of scan results
    """
    client = get_supabase_client()
    session_id_str = str(session_id)
    
    # Query text_analyses
    text_response = client.table("text_analyses")\
        .select("*")\
        .eq("session_id", session_id_str)\
        .order("created_at", desc=True)\
        .limit(limit)\
        .execute()
    
    # Query scan_results
    scan_response = client.table("scan_results")\
        .select("*")\
        .eq("session_id", session_id_str)\
        .order("created_at", desc=True)\
        .limit(limit)\
        .execute()
    
    return {
        "text_analyses": text_response.data or [],
        "scan_results": scan_response.data or []
    }


def check_scam_phone(phone_number: str) -> Optional[Dict[str, Any]]:
    """
    Check if a phone number exists in the scam_phones database.
    
    Args:
        phone_number: Phone number to check (with or without formatting)
        
    Returns:
        Dict containing the scam phone record if found, None otherwise
    """
    client = get_supabase_client()
    
    response = client.table("scam_phones")\
        .select("*")\
        .eq("phone_number", phone_number)\
        .execute()
    
    return response.data[0] if response.data else None


def insert_scam_phone(
    phone_number: str,
    country_code: Optional[str] = None,
    scam_type: Optional[str] = None,
    notes: Optional[str] = None,
    report_count: int = 1
) -> Dict[str, Any]:
    """
    Insert a new scam phone number or update existing one.
    
    Args:
        phone_number: Phone number (formatted consistently)
        country_code: Optional country code (e.g., "+1")
        scam_type: Optional type of scam (e.g., "IRS Impersonation")
        notes: Optional notes about the scam
        report_count: Number of reports (default 1)
        
    Returns:
        Dict containing the inserted/updated scam_phone record
        
    Raises:
        Exception: If insert fails
    """
    client = get_supabase_client()
    
    # Check if phone already exists
    existing = check_scam_phone(phone_number)
    
    if existing:
        # Update report count and last_reported_at
        data = {
            "report_count": existing["report_count"] + report_count,
            "last_reported_at": datetime.now(timezone.utc).isoformat()
        }
        
        # Update scam_type and notes if provided
        if scam_type:
            data["scam_type"] = scam_type
        if notes:
            data["notes"] = notes
        
        response = client.table("scam_phones")\
            .update(data)\
            .eq("phone_number", phone_number)\
            .execute()
        
        if not response.data:
            raise Exception("Failed to update scam phone")
        
        return response.data[0]
    else:
        # Insert new record
        data = {
            "phone_number": phone_number,
            "country_code": country_code,
            "scam_type": scam_type,
            "notes": notes,
            "report_count": report_count,
            "first_reported_at": datetime.now(timezone.utc).isoformat(),
            "last_reported_at": datetime.now(timezone.utc).isoformat(),
            "created_at": datetime.now(timezone.utc).isoformat()
        }
        
        response = client.table("scam_phones").insert(data).execute()
        
        if not response.data:
            raise Exception("Failed to insert scam phone")
        
        return response.data[0]


def get_all_scam_phones(limit: int = 100) -> List[Dict[str, Any]]:
    """
    Get all scam phone numbers from the database.
    
    Args:
        limit: Maximum number of records to return (default 100)
        
    Returns:
        List of scam phone records
    """
    client = get_supabase_client()
    
    response = client.table("scam_phones")\
        .select("*")\
        .order("report_count", desc=True)\
        .limit(limit)\
        .execute()
    
    return response.data or []


def search_scam_phones_by_country(country_code: str, limit: int = 50) -> List[Dict[str, Any]]:
    """
    Search for scam phones by country code.
    
    Args:
        country_code: Country code to search for (e.g., "+1")
        limit: Maximum number of records to return (default 50)
        
    Returns:
        List of scam phone records for that country
    """
    client = get_supabase_client()
    
    response = client.table("scam_phones")\
        .select("*")\
        .eq("country_code", country_code)\
        .order("report_count", desc=True)\
        .limit(limit)\
        .execute()
    
    return response.data or []


# =============================================================================
# Scam Reports Operations (Story 8.3)
# =============================================================================

def check_scam_entity(entity_type: str, entity_value: str) -> Optional[Dict[str, Any]]:
    """
    Check if an entity exists in the scam_reports database.
    
    Args:
        entity_type: Type of entity (phone, url, email, payment, bitcoin)
        entity_value: Normalized entity value
        
    Returns:
        Dict containing the scam report record if found, None otherwise
    """
    client = get_supabase_client()
    
    response = client.table("scam_reports")\
        .select("*")\
        .eq("entity_type", entity_type)\
        .eq("entity_value", entity_value)\
        .execute()
    
    return response.data[0] if response.data else None


def insert_scam_report(
    entity_type: str,
    entity_value: str,
    evidence: Optional[List[Dict[str, Any]]] = None,
    notes: Optional[str] = None,
    verified: bool = False,
    risk_score: float = 50.0
) -> Dict[str, Any]:
    """
    Insert a new scam report or update existing one.
    
    Args:
        entity_type: Type of entity (phone, url, email, payment, bitcoin)
        entity_value: Normalized entity value
        evidence: Optional list of evidence objects
        notes: Optional admin notes
        verified: Whether manually verified (default False)
        risk_score: Initial risk score (default 50.0)
        
    Returns:
        Dict containing the inserted/updated scam_report record
        
    Raises:
        Exception: If insert fails
    """
    client = get_supabase_client()
    
    # Check if entity already exists
    existing = check_scam_entity(entity_type, entity_value)
    
    if existing:
        # Update report count and last_reported
        new_evidence = existing.get("evidence", []) or []
        if evidence:
            new_evidence.extend(evidence)
        
        data = {
            "report_count": existing["report_count"] + 1,
            "last_reported": datetime.now(timezone.utc).isoformat(),
            "evidence": new_evidence
        }
        
        if notes:
            data["notes"] = notes
        
        response = client.table("scam_reports")\
            .update(data)\
            .eq("entity_type", entity_type)\
            .eq("entity_value", entity_value)\
            .execute()
        
        if not response.data:
            raise Exception("Failed to update scam report")
        
        return response.data[0]
    else:
        # Insert new record
        now = datetime.now(timezone.utc).isoformat()
        data = {
            "entity_type": entity_type,
            "entity_value": entity_value,
            "report_count": 1,
            "risk_score": risk_score,
            "evidence": evidence or [],
            "verified": verified,
            "notes": notes,
            "first_seen": now,
            "last_reported": now,
            "created_at": now
        }
        
        response = client.table("scam_reports").insert(data).execute()
        
        if not response.data:
            raise Exception("Failed to insert scam report")
        
        return response.data[0]


def get_all_scam_reports(
    entity_type: Optional[str] = None,
    min_risk_score: Optional[float] = None,
    verified_only: bool = False,
    limit: int = 100,
    offset: int = 0
) -> List[Dict[str, Any]]:
    """
    Get all scam reports with optional filtering.
    
    Args:
        entity_type: Optional filter by entity type
        min_risk_score: Optional minimum risk score
        verified_only: If True, only return verified reports
        limit: Maximum number of records to return (default 100)
        offset: Offset for pagination (default 0)
        
    Returns:
        List of scam report records
    """
    client = get_supabase_client()
    
    query = client.table("scam_reports").select("*")
    
    if entity_type:
        query = query.eq("entity_type", entity_type)
    
    if min_risk_score is not None:
        query = query.gte("risk_score", min_risk_score)
    
    if verified_only:
        query = query.eq("verified", True)
    
    query = query.order("risk_score", desc=True).limit(limit).offset(offset)
    
    response = query.execute()
    
    return response.data or []


def update_scam_report(
    report_id: int,
    verified: Optional[bool] = None,
    risk_score: Optional[float] = None,
    notes: Optional[str] = None
) -> Dict[str, Any]:
    """
    Update an existing scam report.
    
    Args:
        report_id: ID of the report to update
        verified: Optional verified status
        risk_score: Optional risk score override
        notes: Optional notes
        
    Returns:
        Dict containing the updated scam report record
        
    Raises:
        Exception: If update fails or report not found
    """
    client = get_supabase_client()
    
    update_data = {}
    if verified is not None:
        update_data["verified"] = verified
    if risk_score is not None:
        update_data["risk_score"] = risk_score
    if notes is not None:
        update_data["notes"] = notes
    
    if not update_data:
        raise ValueError("No fields to update")
    
    response = client.table("scam_reports")\
        .update(update_data)\
        .eq("id", report_id)\
        .execute()
    
    if not response.data:
        raise Exception("Scam report not found or update failed")
    
    return response.data[0]


def delete_scam_report(report_id: int) -> Dict[str, Any]:
    """
    Delete a scam report.
    
    Args:
        report_id: ID of the report to delete
        
    Returns:
        Dict containing the deleted scam report record
        
    Raises:
        Exception: If delete fails or report not found
    """
    client = get_supabase_client()
    
    response = client.table("scam_reports")\
        .delete()\
        .eq("id", report_id)\
        .execute()
    
    if not response.data:
        raise Exception("Scam report not found or delete failed")
    
    return response.data[0]

