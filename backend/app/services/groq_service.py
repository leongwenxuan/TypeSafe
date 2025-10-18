"""
Groq integration for scam text analysis.
"""
import asyncio
import json
import logging
from typing import Dict, Any, Optional

from groq import AsyncGroq, GroqError, APITimeoutError, RateLimitError, AuthenticationError

from app.config import settings
from app.services.prompts import SCAM_DETECTION_SYSTEM_PROMPT
from app.services.cache import TTLCache

# Configure logging
logger = logging.getLogger(__name__)

# Global cache instance
_cache = TTLCache(ttl_seconds=60, max_size=100)

# Groq client (initialized lazily)
_client: Optional[AsyncGroq] = None


def get_client() -> AsyncGroq:
    """
    Get or initialize Groq client.
    
    Returns:
        AsyncGroq client instance
        
    Raises:
        ValueError: If GROQ_API_KEY is not configured
    """
    global _client
    
    if _client is None:
        if not settings.groq_api_key:
            raise ValueError("GROQ_API_KEY not configured in environment")
        
        _client = AsyncGroq(
            api_key=settings.groq_api_key,
            timeout=1.5  # 1.5s timeout for Groq API calls
        )
        logger.info("Groq client initialized")
    
    return _client


def _create_fallback_response(reason: str) -> Dict[str, Any]:
    """
    Create fallback response for errors/timeouts.
    
    Args:
        reason: Explanation for fallback
        
    Returns:
        Standardized unknown risk response
    """
    return {
        "risk_level": "unknown",
        "confidence": 0.0,
        "category": "unknown",
        "explanation": reason
    }


def _normalize_response(raw_response: str) -> Dict[str, Any]:
    """
    Parse and normalize Groq response to unified schema.
    
    Args:
        raw_response: JSON string from Groq
        
    Returns:
        Normalized response dict with risk_level, confidence, category, explanation
    """
    try:
        parsed = json.loads(raw_response)
        
        # Validate and normalize risk_level
        risk_level = parsed.get("risk_level", "unknown").lower()
        if risk_level not in ["low", "medium", "high"]:
            risk_level = "unknown"
        
        # Validate and normalize confidence
        confidence = float(parsed.get("confidence", 0.0))
        confidence = max(0.0, min(1.0, confidence))  # Clamp to 0.0-1.0
        
        # Validate category
        category = parsed.get("category", "unknown").lower()
        valid_categories = ["otp_phishing", "payment_scam", "impersonation", "unknown"]
        if category not in valid_categories:
            category = "unknown"
        
        # Get explanation
        explanation = parsed.get("explanation", "No explanation provided")
        
        return {
            "risk_level": risk_level,
            "confidence": confidence,
            "category": category,
            "explanation": explanation
        }
    
    except (json.JSONDecodeError, ValueError, KeyError) as e:
        logger.error(f"Failed to parse Groq response: {e}")
        return _create_fallback_response("Failed to parse AI response")


async def analyze_text(text: str) -> Dict[str, Any]:
    """
    Analyze text for scam intent using Groq.
    
    Implements:
    - Response caching for identical text
    - 1.5s timeout with graceful fallback
    - Error handling for Groq API errors
    - Normalized response format
    
    Args:
        text: Text to analyze (max 300 chars recommended)
        
    Returns:
        Dict with keys:
        - risk_level: "low" | "medium" | "high" | "unknown"
        - confidence: float 0.0-1.0
        - category: "otp_phishing" | "payment_scam" | "impersonation" | "unknown"
        - explanation: str
    """
    # Handle empty text
    if not text or not text.strip():
        return _create_fallback_response("Empty text provided")
    
    # Check cache first
    cached = _cache.get(text)
    if cached is not None:
        logger.info(f"Cache hit for text length {len(text)}")
        return cached
    
    try:
        # Get Groq client
        client = get_client()
        
        # Call Groq API with timeout
        response = await client.chat.completions.create(
            model="llama-3.3-70b-versatile",  # Fast and capable Groq model
            messages=[
                {"role": "system", "content": SCAM_DETECTION_SYSTEM_PROMPT},
                {"role": "user", "content": text}
            ],
            temperature=0.3,  # Lower temperature for more consistent results
            max_tokens=150    # Limit response size
        )
        
        # Extract and normalize response
        raw_content = response.choices[0].message.content
        if not raw_content:
            logger.warning("Groq returned empty content")
            return _create_fallback_response("AI returned empty response")
        
        result = _normalize_response(raw_content)
        
        # Cache successful response
        _cache.set(text, result)
        
        logger.info(
            f"Analyzed text (length={len(text)}): "
            f"risk={result['risk_level']}, confidence={result['confidence']:.2f}"
        )
        
        return result
    
    except APITimeoutError:
        logger.warning(f"Groq API timeout for text length {len(text)}")
        return _create_fallback_response("Analysis timed out")
    
    except RateLimitError:
        logger.error("Groq rate limit exceeded")
        return _create_fallback_response("Analysis unavailable (rate limit)")
    
    except AuthenticationError:
        logger.critical("Groq authentication failed - check API key")
        return _create_fallback_response("Analysis unavailable (auth error)")
    
    except GroqError as e:
        logger.error(f"Groq API error: {type(e).__name__} - {str(e)}")
        return _create_fallback_response("Analysis unavailable (API error)")
    
    except Exception as e:
        logger.exception(f"Unexpected error in analyze_text: {e}")
        return _create_fallback_response("Analysis failed unexpectedly")


def clear_cache() -> None:
    """Clear the response cache. Useful for testing."""
    _cache.clear()
    logger.info("Groq response cache cleared")


def get_cache_stats() -> Dict[str, int]:
    """
    Get cache statistics.
    
    Returns:
        Dict with cache_size
    """
    return {"cache_size": _cache.size()}

