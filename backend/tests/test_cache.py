"""
Tests for TTL cache implementation.
"""
import time
import pytest

from app.services.cache import TTLCache


class TestTTLCache:
    """Test suite for TTLCache."""
    
    def test_cache_initialization(self):
        """Test cache initializes with correct parameters."""
        cache = TTLCache(ttl_seconds=30, max_size=50)
        assert cache.ttl_seconds == 30
        assert cache.max_size == 50
        assert cache.size() == 0
    
    def test_cache_set_and_get(self):
        """Test basic cache set and get operations."""
        cache = TTLCache()
        
        test_response = {
            "risk_level": "high",
            "confidence": 0.9,
            "category": "otp_phishing",
            "explanation": "Test response"
        }
        
        cache.set("test text", test_response)
        retrieved = cache.get("test text")
        
        assert retrieved == test_response
        assert cache.size() == 1
    
    def test_cache_miss(self):
        """Test cache returns None for missing keys."""
        cache = TTLCache()
        assert cache.get("nonexistent") is None
    
    def test_cache_key_normalization(self):
        """Test cache normalizes keys (case-insensitive, stripped)."""
        cache = TTLCache()
        
        test_response = {"risk_level": "low"}
        
        # Set with one format
        cache.set("  Test Text  ", test_response)
        
        # Should retrieve with different format
        assert cache.get("test text") == test_response
        assert cache.get("TEST TEXT") == test_response
        assert cache.get("  test text  ") == test_response
    
    def test_cache_ttl_expiration(self):
        """Test cache entries expire after TTL."""
        cache = TTLCache(ttl_seconds=1)  # 1 second TTL
        
        cache.set("expire_test", {"risk_level": "medium"})
        
        # Should exist immediately
        assert cache.get("expire_test") is not None
        
        # Wait for expiration
        time.sleep(1.1)
        
        # Should be expired
        assert cache.get("expire_test") is None
        assert cache.size() == 0
    
    def test_cache_max_size_enforcement(self):
        """Test cache enforces max size limit."""
        cache = TTLCache(max_size=3)
        
        # Add 3 entries (fill to max)
        cache.set("text1", {"risk_level": "low"})
        cache.set("text2", {"risk_level": "medium"})
        cache.set("text3", {"risk_level": "high"})
        
        assert cache.size() == 3
        
        # Add 4th entry - should evict oldest
        cache.set("text4", {"risk_level": "low"})
        
        assert cache.size() == 3
        assert cache.get("text1") is None  # Oldest should be evicted
        assert cache.get("text4") is not None  # Newest should exist
    
    def test_cache_update_existing_key(self):
        """Test updating existing cache entry doesn't increase size."""
        cache = TTLCache(max_size=5)
        
        cache.set("update_test", {"risk_level": "low"})
        assert cache.size() == 1
        
        # Update same key
        cache.set("update_test", {"risk_level": "high"})
        assert cache.size() == 1
        
        # Should have new value
        assert cache.get("update_test")["risk_level"] == "high"
    
    def test_cache_clear(self):
        """Test cache clear removes all entries."""
        cache = TTLCache()
        
        cache.set("text1", {"risk_level": "low"})
        cache.set("text2", {"risk_level": "medium"})
        
        assert cache.size() == 2
        
        cache.clear()
        
        assert cache.size() == 0
        assert cache.get("text1") is None
        assert cache.get("text2") is None
    
    def test_cache_different_texts_different_keys(self):
        """Test different texts generate different cache keys."""
        cache = TTLCache()
        
        cache.set("text one", {"risk_level": "low"})
        cache.set("text two", {"risk_level": "high"})
        
        assert cache.get("text one")["risk_level"] == "low"
        assert cache.get("text two")["risk_level"] == "high"
        assert cache.size() == 2

