"""
Supabase client initialization and connection management.
"""

from typing import Optional
from supabase import create_client, Client
from ..config import settings


# Global client instance (singleton pattern)
_supabase_client: Optional[Client] = None


def get_supabase_client() -> Client:
    """
    Get or create Supabase client instance.
    
    This function implements a singleton pattern to reuse the same client
    across the application. The client handles connection pooling internally.
    
    Returns:
        Client: Initialized Supabase client
        
    Raises:
        ValueError: If SUPABASE_URL or SUPABASE_KEY are not configured
    """
    global _supabase_client
    
    if _supabase_client is None:
        # Validate required credentials
        if not settings.supabase_url or not settings.supabase_key:
            raise ValueError(
                "SUPABASE_URL and SUPABASE_KEY must be set in environment. "
                "Check your .env file."
            )
        
        # Create client with service role key for backend-only access
        _supabase_client = create_client(
            supabase_url=settings.supabase_url,
            supabase_key=settings.supabase_key
        )
    
    return _supabase_client


def reset_client() -> None:
    """
    Reset the global client instance.
    
    Useful for testing or when credentials change.
    """
    global _supabase_client
    _supabase_client = None

