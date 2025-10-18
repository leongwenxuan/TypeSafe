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

