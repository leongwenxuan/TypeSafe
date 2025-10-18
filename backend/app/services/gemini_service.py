"""
Gemini integration for multimodal scam image analysis.
"""
import asyncio
import json
import logging
import imghdr
from typing import Dict, Any, Optional

import google.generativeai as genai
from google.generativeai.types import HarmCategory, HarmBlockThreshold

from app.config import settings
from app.services.prompts import GEMINI_MULTIMODAL_SCAM_PROMPT

# Configure logging
logger = logging.getLogger(__name__)

# Gemini model instance (initialized lazily)
_model: Optional[genai.GenerativeModel] = None

# Image size limit (4MB)
MAX_IMAGE_SIZE = 4 * 1024 * 1024


def get_model() -> genai.GenerativeModel:
    """
    Get or initialize Gemini model.
    
    Returns:
        GenerativeModel instance
        
    Raises:
        ValueError: If GEMINI_API_KEY is not configured
    """
    global _model
    
    if _model is None:
        if not settings.gemini_api_key:
            raise ValueError("GEMINI_API_KEY not configured in environment")
        
        # Configure Gemini with API key
        genai.configure(api_key=settings.gemini_api_key)
        
        # Initialize model with safety settings
        _model = genai.GenerativeModel(
            model_name='gemini-1.5-flash-latest',
            safety_settings={
                HarmCategory.HARM_CATEGORY_HATE_SPEECH: HarmBlockThreshold.BLOCK_NONE,
                HarmCategory.HARM_CATEGORY_HARASSMENT: HarmBlockThreshold.BLOCK_NONE,
                HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: HarmBlockThreshold.BLOCK_NONE,
                HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: HarmBlockThreshold.BLOCK_NONE,
            }
        )
        logger.info("Gemini model initialized")
    
    return _model


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
    Parse and normalize Gemini response to unified schema.
    
    Args:
        raw_response: JSON string from Gemini
        
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
        
        # Validate category (includes visual_scam for Gemini)
        category = parsed.get("category", "unknown").lower()
        valid_categories = ["otp_phishing", "payment_scam", "impersonation", "visual_scam", "unknown"]
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
        logger.error(f"Failed to parse Gemini response: {e}")
        return _create_fallback_response("Failed to parse AI response")


def detect_mime_type(image_bytes: bytes) -> str:
    """
    Detect MIME type from image bytes.
    
    Args:
        image_bytes: Raw image bytes
        
    Returns:
        MIME type string (image/png or image/jpeg)
        
    Raises:
        ValueError: If image format is not supported
    """
    img_type = imghdr.what(None, h=image_bytes)
    
    if img_type == 'png':
        return 'image/png'
    elif img_type == 'jpeg':
        return 'image/jpeg'
    else:
        raise ValueError(f"Unsupported image format: {img_type}")


async def analyze_image(
    image_data: bytes,
    ocr_text: str = "",
    mime_type: Optional[str] = None
) -> Dict[str, Any]:
    """
    Analyze image for scam intent using Gemini multimodal API.
    
    Implements:
    - Image format validation (PNG, JPEG)
    - Size limit enforcement (4MB max)
    - 1.5s timeout with graceful fallback
    - Error handling for Gemini API errors
    - Normalized response format
    
    Args:
        image_data: Raw image bytes
        ocr_text: OCR-extracted text from image (optional)
        mime_type: MIME type of image (auto-detected if not provided)
        
    Returns:
        Dict with keys:
        - risk_level: "low" | "medium" | "high" | "unknown"
        - confidence: float 0.0-1.0
        - category: "otp_phishing" | "payment_scam" | "impersonation" | "visual_scam" | "unknown"
        - explanation: str
    """
    # Validate image data
    if not image_data:
        return _create_fallback_response("Empty image provided")
    
    # Check image size
    if len(image_data) > MAX_IMAGE_SIZE:
        return _create_fallback_response(f"Image too large (max {MAX_IMAGE_SIZE // (1024 * 1024)}MB)")
    
    # Detect MIME type if not provided
    try:
        if mime_type is None:
            mime_type = detect_mime_type(image_data)
    except ValueError as e:
        logger.error(f"Invalid image format: {e}")
        return _create_fallback_response("Unsupported image format")
    
    try:
        # Get Gemini model
        model = get_model()
        
        # Prepare multimodal content
        content_parts = [GEMINI_MULTIMODAL_SCAM_PROMPT]
        
        # Add image
        content_parts.append({
            'mime_type': mime_type,
            'data': image_data
        })
        
        # Add OCR text if provided
        if ocr_text and ocr_text.strip():
            content_parts.append(f"\nOCR extracted text: {ocr_text}")
        
        # Call Gemini API with timeout
        response = await asyncio.wait_for(
            asyncio.to_thread(
                model.generate_content,
                content_parts,
                generation_config={'temperature': 0.3}
            ),
            timeout=1.5
        )
        
        # Extract response text
        if not response or not response.text:
            logger.warning("Gemini returned empty response")
            return _create_fallback_response("AI returned empty response")
        
        result = _normalize_response(response.text)
        
        logger.info(
            f"Analyzed image (size={len(image_data)}, ocr_len={len(ocr_text)}): "
            f"risk={result['risk_level']}, confidence={result['confidence']:.2f}"
        )
        
        return result
    
    except asyncio.TimeoutError:
        logger.warning(f"Gemini API timeout for image size {len(image_data)}")
        return _create_fallback_response("Analysis timed out")
    
    except Exception as e:
        error_type = type(e).__name__
        error_msg = str(e)
        
        # Log detailed error info
        logger.error(
            f"Gemini error: {error_type}, "
            f"image_size={len(image_data)}, ocr_length={len(ocr_text)}, "
            f"message={error_msg}"
        )
        
        # Handle specific error types
        if "429" in error_msg or "quota" in error_msg.lower():
            return _create_fallback_response("Analysis unavailable (rate limit)")
        elif "401" in error_msg or "403" in error_msg or "authentication" in error_msg.lower():
            logger.critical("Gemini authentication failed - check API key")
            return _create_fallback_response("Analysis unavailable (auth error)")
        elif "500" in error_msg or "503" in error_msg:
            return _create_fallback_response("Analysis unavailable (server error)")
        else:
            return _create_fallback_response("Analysis failed unexpectedly")

