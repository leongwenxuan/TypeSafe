"""
Database module for Supabase integration.

This module provides database client initialization and CRUD operations
for TypeSafe's data persistence layer.
"""

from .client import get_supabase_client
from .operations import (
    insert_session,
    insert_text_analysis,
    insert_scan_result,
    get_latest_result,
)

__all__ = [
    "get_supabase_client",
    "insert_session",
    "insert_text_analysis",
    "insert_scan_result",
    "get_latest_result",
]

