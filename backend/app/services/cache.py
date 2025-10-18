"""
Simple in-memory cache with TTL support.
"""
import hashlib
import time
from typing import Optional, Dict, Any


class TTLCache:
    """
    In-memory cache with time-to-live (TTL) expiration.
    
    Uses SHA256 hash of content as cache key.
    Implements simple time-based expiration without LRU.
    """
    
    def __init__(self, ttl_seconds: int = 60, max_size: int = 100):
        """
        Initialize cache with TTL and size limit.
        
        Args:
            ttl_seconds: Time-to-live for cache entries (default: 60s)
            max_size: Maximum number of entries (default: 100)
        """
        self.ttl_seconds = ttl_seconds
        self.max_size = max_size
        self._cache: Dict[str, tuple[Any, float]] = {}
    
    def _generate_key(self, text: str) -> str:
        """
        Generate cache key from text using SHA256 hash.
        
        Args:
            text: Input text to hash
            
        Returns:
            Hexadecimal hash string
        """
        # Normalize: lowercase and strip whitespace
        normalized = text.lower().strip()
        return hashlib.sha256(normalized.encode('utf-8')).hexdigest()
    
    def get(self, text: str) -> Optional[Dict[str, Any]]:
        """
        Retrieve cached response for text.
        
        Args:
            text: Text to look up
            
        Returns:
            Cached response dict or None if not found/expired
        """
        key = self._generate_key(text)
        
        if key not in self._cache:
            return None
        
        value, timestamp = self._cache[key]
        
        # Check if expired
        if time.time() - timestamp > self.ttl_seconds:
            del self._cache[key]
            return None
        
        return value
    
    def set(self, text: str, response: Dict[str, Any]) -> None:
        """
        Store response in cache.
        
        Args:
            text: Text key
            response: Response dict to cache
        """
        key = self._generate_key(text)
        
        # Enforce max size by removing oldest entry
        if len(self._cache) >= self.max_size and key not in self._cache:
            # Remove oldest entry (first inserted)
            oldest_key = next(iter(self._cache))
            del self._cache[oldest_key]
        
        self._cache[key] = (response, time.time())
    
    def clear(self) -> None:
        """Clear all cache entries."""
        self._cache.clear()
    
    def size(self) -> int:
        """Return current cache size."""
        return len(self._cache)

