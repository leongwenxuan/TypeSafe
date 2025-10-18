"""
Risk aggregation and normalization for multi-provider scam detection.

This module provides a unified interface for combining results from multiple
AI providers (Groq, Gemini) into a consistent response format. It handles:
- Single-provider normalization
- Multi-provider result aggregation
- Confidence score normalization
- Category validation and mapping
- Error handling and fallback responses
"""
import logging
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional

from app.services import groq_service, gemini_service

# Configure logging
logger = logging.getLogger(__name__)

# Valid risk categories across all providers
VALID_CATEGORIES = [
    "otp_phishing",
    "payment_scam",
    "impersonation",
    "visual_scam",  # Gemini-specific
    "unknown"
]

# Risk level priority (for aggregation)
RISK_PRIORITY = {
    "high": 3,
    "medium": 2,
    "low": 1,
    "unknown": 0
}

# Category specificity priority (for aggregation)
CATEGORY_PRIORITY = {
    "otp_phishing": 4,
    "payment_scam": 4,
    "impersonation": 4,
    "visual_scam": 4,
    "unknown": 1
}


def normalize_confidence(confidence: Optional[float]) -> float:
    """
    Normalize confidence score to 0.0-1.0 range.
    
    Args:
        confidence: Raw confidence score (may be None, negative, or > 1.0)
        
    Returns:
        Normalized confidence in range [0.0, 1.0]
    """
    if confidence is None:
        return 0.0
    
    # Clamp to valid range
    return max(0.0, min(1.0, float(confidence)))


def validate_category(category: Optional[str]) -> str:
    """
    Validate and normalize risk category.
    
    Args:
        category: Raw category string
        
    Returns:
        Valid category or "unknown" if invalid
    """
    if not category:
        return "unknown"
    
    category_lower = category.lower()
    if category_lower in VALID_CATEGORIES:
        return category_lower
    
    return "unknown"


def format_explanation(explanation: Optional[str]) -> str:
    """
    Format explanation text to be concise and clean.
    
    Args:
        explanation: Raw explanation text
        
    Returns:
        Formatted explanation (max 100 chars, single line)
    """
    if not explanation:
        return "Analysis result"
    
    # Remove newlines and extra whitespace
    cleaned = " ".join(explanation.split())
    
    # If only whitespace, return fallback
    if not cleaned:
        return "Analysis result"
    
    # Truncate if too long
    if len(cleaned) > 100:
        return cleaned[:97] + "..."
    
    return cleaned


def generate_timestamp() -> str:
    """
    Generate ISO 8601 timestamp in UTC.
    
    Returns:
        ISO 8601 formatted timestamp string with timezone
    """
    return datetime.now(timezone.utc).isoformat()


def normalize_response(response: Dict[str, Any], provider: str = "unknown") -> Dict[str, Any]:
    """
    Normalize a provider response to unified schema.
    
    This adds a timestamp and ensures all fields are properly formatted.
    Provider services (groq_service, gemini_service) already normalize
    their responses, so this mainly adds the timestamp and validates.
    
    Args:
        response: Provider response dict
        provider: Provider name for logging
        
    Returns:
        Normalized response with unified schema including timestamp
    """
    try:
        return {
            "risk_level": response.get("risk_level", "unknown"),
            "confidence": normalize_confidence(response.get("confidence")),
            "category": validate_category(response.get("category")),
            "explanation": format_explanation(response.get("explanation")),
            "ts": generate_timestamp()
        }
    except Exception as e:
        logger.error(f"Error normalizing {provider} response: {e}")
        return create_fallback_response(f"Normalization error: {str(e)}")


def aggregate_results(results: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Aggregate multiple provider results into single response.
    
    Aggregation rules:
    - Risk level: Use highest priority risk level
    - Confidence: Average all confidence scores
    - Category: Use most specific category
    - Explanation: Concatenate explanations (max 100 chars)
    - Timestamp: Use most recent timestamp
    
    Args:
        results: List of normalized provider responses
        
    Returns:
        Aggregated response in unified schema
    """
    if not results:
        return create_fallback_response("No results to aggregate")
    
    if len(results) == 1:
        return results[0]
    
    try:
        # Aggregate risk level (highest priority wins)
        risk_level = max(
            (r.get("risk_level", "unknown") for r in results),
            key=lambda x: RISK_PRIORITY.get(x, 0)
        )
        
        # Average confidence scores
        confidences = [normalize_confidence(r.get("confidence")) for r in results]
        avg_confidence = sum(confidences) / len(confidences) if confidences else 0.0
        
        # Select most specific category
        category = max(
            (validate_category(r.get("category")) for r in results),
            key=lambda x: CATEGORY_PRIORITY.get(x, 0)
        )
        
        # Concatenate explanations
        explanations = [
            format_explanation(r.get("explanation"))
            for r in results
            if r.get("explanation")
        ]
        combined_explanation = "; ".join(explanations)
        explanation = format_explanation(combined_explanation)
        
        # Use most recent timestamp
        timestamps = [r.get("ts") for r in results if r.get("ts")]
        ts = max(timestamps) if timestamps else generate_timestamp()
        
        return {
            "risk_level": risk_level,
            "confidence": avg_confidence,
            "category": category,
            "explanation": explanation,
            "ts": ts
        }
    
    except Exception as e:
        logger.error(f"Error aggregating results: {e}")
        return create_fallback_response(f"Aggregation error: {str(e)}")


def create_fallback_response(error_context: str) -> Dict[str, Any]:
    """
    Create safe fallback response for errors.
    
    Args:
        error_context: Context about the error (not exposed to user)
        
    Returns:
        Fallback response in unified schema
    """
    logger.warning(f"Creating fallback response: {error_context}")
    
    return {
        "risk_level": "unknown",
        "confidence": 0.0,
        "category": "unknown",
        "explanation": "Analysis unavailable",
        "ts": generate_timestamp()
    }


async def analyze_text_aggregated(text: str) -> Dict[str, Any]:
    """
    Analyze text using Groq with unified response format.
    
    Convenience function that:
    1. Calls Groq service
    2. Normalizes response (adds timestamp)
    3. Handles errors gracefully
    
    Args:
        text: Text to analyze
        
    Returns:
        Unified schema response with timestamp
    """
    try:
        # Groq service already returns normalized response
        response = await groq_service.analyze_text(text)
        
        # Add timestamp and validate
        return normalize_response(response, provider="groq")
    
    except Exception as e:
        logger.error(f"Error in text analysis aggregation: {e}")
        return create_fallback_response(f"Groq service error: {str(e)}")


async def analyze_image_aggregated(
    image_data: bytes,
    ocr_text: str = "",
    mime_type: Optional[str] = None
) -> Dict[str, Any]:
    """
    Analyze image using Gemini with unified response format.
    
    Convenience function that:
    1. Calls Gemini service
    2. Normalizes response (adds timestamp)
    3. Handles errors gracefully
    
    Args:
        image_data: Image bytes
        ocr_text: Optional OCR text from image
        mime_type: Optional MIME type (auto-detected if None)
        
    Returns:
        Unified schema response with timestamp
    """
    try:
        # Gemini service already returns normalized response
        response = await gemini_service.analyze_image(
            image_data=image_data,
            ocr_text=ocr_text,
            mime_type=mime_type
        )
        
        # Add timestamp and validate
        return normalize_response(response, provider="gemini")
    
    except Exception as e:
        logger.error(f"Error in image analysis aggregation: {e}")
        return create_fallback_response(f"Gemini service error: {str(e)}")


async def analyze_multimodal_aggregated(
    image_data: bytes,
    ocr_text: str,
    mime_type: Optional[str] = None,
    use_fallback: bool = True
) -> Dict[str, Any]:
    """
    Analyze image+text using both Gemini and Groq (optional fallback).
    
    Strategy:
    1. Always use Gemini for multimodal analysis (primary)
    2. Optionally use Groq for text-only analysis (fallback)
    3. Aggregate results if both providers used
    
    Args:
        image_data: Image bytes
        ocr_text: OCR text from image
        mime_type: Optional MIME type
        use_fallback: Whether to use Groq as text fallback (default True)
        
    Returns:
        Aggregated unified schema response
    """
    results = []
    
    # Primary: Gemini multimodal analysis
    try:
        gemini_response = await analyze_image_aggregated(
            image_data=image_data,
            ocr_text=ocr_text,
            mime_type=mime_type
        )
        results.append(gemini_response)
    except Exception as e:
        logger.error(f"Gemini analysis failed: {e}")
    
    # Fallback: Groq text-only analysis (if enabled and text available)
    if use_fallback and ocr_text:
        try:
            groq_response = await analyze_text_aggregated(text=ocr_text)
            results.append(groq_response)
        except Exception as e:
            logger.error(f"Groq fallback analysis failed: {e}")
    
    # Aggregate all results
    if results:
        return aggregate_results(results)
    else:
        return create_fallback_response("All providers failed")

