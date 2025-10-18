"""
TypeSafe Backend API - Main Application

FastAPI backend service for AI-powered scam detection.
Handles requests from iOS keyboard extension and companion app.
"""
import logging
import uuid
from datetime import datetime, timezone
from typing import Callable

from fastapi import FastAPI, Request, Response, HTTPException, File, Form, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, field_validator
import imghdr

from app.config import settings
from app.services.risk_aggregator import analyze_text_aggregated, aggregate_results
from app.services.gemini_service import analyze_image
from app.services.openai_service import analyze_text as analyze_text_openai
from app.db.operations import insert_text_analysis, insert_scan_result, get_latest_result

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="TypeSafe API",
    description="AI-powered scam detection for iOS keyboard",
    version="1.0",
)

# CORS configuration for iOS app integration
# NOTE: Default ["*"] is for development only. For production, set specific origins
# via CORS_ORIGINS environment variable (e.g., "https://yourdomain.com")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


# Request/Response Models
class AnalyzeTextRequest(BaseModel):
    """
    Request model for text analysis endpoint.
    
    Attributes:
        session_id: Random UUID for session tracking (anonymized, no PII)
        app_bundle: iOS app bundle identifier (e.g., "com.whatsapp")
        text: Text snippet to analyze (1-300 characters)
    """
    session_id: str = Field(
        ...,
        description="Random UUID for session tracking",
        examples=["123e4567-e89b-12d3-a456-426614174000"]
    )
    app_bundle: str = Field(
        ...,
        description="iOS app bundle identifier",
        examples=["com.whatsapp", "com.telegram"]
    )
    text: str = Field(
        ...,
        min_length=1,
        max_length=300,
        description="Text snippet to analyze for scam risk"
    )
    
    @field_validator('session_id')
    @classmethod
    def validate_session_id(cls, v: str) -> str:
        """Validate session_id is a valid UUID format"""
        try:
            uuid.UUID(v)
            return v
        except ValueError:
            raise ValueError('session_id must be a valid UUID')
    
    @field_validator('text')
    @classmethod
    def validate_text_not_empty(cls, v: str) -> str:
        """Validate text is not just whitespace"""
        if not v.strip():
            raise ValueError('text cannot be empty or whitespace only')
        return v


class AnalyzeTextResponse(BaseModel):
    """
    Response model for text analysis endpoint.
    
    Attributes:
        risk_level: Normalized risk level (low/medium/high)
        confidence: Confidence score (0.0-1.0)
        category: Scam category (otp_phishing/payment_scam/impersonation/unknown)
        explanation: Human-friendly one-line explanation
        ts: ISO timestamp of analysis
    """
    risk_level: str = Field(
        ...,
        description="Normalized risk level",
        examples=["low", "medium", "high"]
    )
    confidence: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="Confidence score between 0.0 and 1.0"
    )
    category: str = Field(
        ...,
        description="Scam category",
        examples=["otp_phishing", "payment_scam", "impersonation", "unknown"]
    )
    explanation: str = Field(
        ...,
        description="Human-friendly explanation"
    )
    ts: str = Field(
        ...,
        description="ISO timestamp of analysis",
        examples=["2025-01-18T10:30:00Z"]
    )


class ScanImageResponse(BaseModel):
    """
    Response model for image scan endpoint.
    
    Attributes:
        risk_level: Normalized risk level (low/medium/high/unknown)
        confidence: Confidence score (0.0-1.0)
        category: Scam category (otp_phishing/payment_scam/impersonation/visual_scam/unknown)
        explanation: Human-friendly one-line explanation
        ts: ISO timestamp of analysis
    """
    risk_level: str = Field(
        ...,
        description="Normalized risk level",
        examples=["low", "medium", "high", "unknown"]
    )
    confidence: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="Confidence score between 0.0 and 1.0"
    )
    category: str = Field(
        ...,
        description="Scam category",
        examples=["otp_phishing", "payment_scam", "impersonation", "visual_scam", "unknown"]
    )
    explanation: str = Field(
        ...,
        description="Human-friendly explanation"
    )
    ts: str = Field(
        ...,
        description="ISO timestamp of analysis",
        examples=["2025-01-18T10:30:00Z"]
    )


@app.middleware("http")
async def add_request_id_and_logging(request: Request, call_next: Callable):
    """
    Middleware to add request ID for tracing and log requests/responses.
    
    Logs:
    - Incoming request: method, path, request_id
    - Outgoing response: status_code, latency, request_id
    """
    # Generate unique request ID
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    
    # Log incoming request (excluding sensitive paths)
    logger.info(
        f"Request: method={request.method} path={request.url.path} request_id={request_id}"
    )
    
    # Process request and measure latency
    start_time = datetime.now(timezone.utc)
    response = await call_next(request)
    latency_ms = (datetime.now(timezone.utc) - start_time).total_seconds() * 1000
    
    # Add request ID to response headers
    response.headers["X-Request-ID"] = request_id
    
    # Log outgoing response
    logger.info(
        f"Response: status={response.status_code} latency_ms={latency_ms:.2f} request_id={request_id}"
    )
    
    return response


@app.middleware("http")
async def add_security_headers(request: Request, call_next: Callable):
    """Add security headers including HSTS for HTTPS enforcement"""
    response = await call_next(request)
    
    # HSTS header for HTTPS enforcement (1 year)
    # Only add HSTS in production/staging to avoid local HTTP development issues
    if settings.environment in ["production", "staging", "prod"]:
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    
    return response


@app.post("/analyze-text", response_model=AnalyzeTextResponse, status_code=200)
async def analyze_text(request: AnalyzeTextRequest, req: Request):
    """
    Analyze text snippet for scam risk using AI providers.
    
    This endpoint receives text from the iOS keyboard extension, analyzes it
    for scam risk using OpenAI, stores the result in Supabase, and returns
    a normalized risk assessment.
    
    Args:
        request: Request body with session_id, app_bundle, and text
        req: FastAPI Request object for accessing request_id
    
    Returns:
        AnalyzeTextResponse with risk_level, confidence, category, explanation, and timestamp
    
    Raises:
        HTTPException 400: Invalid input (malformed UUID, empty text, etc.)
        HTTPException 500: Service error (OpenAI failure, database error)
    """
    request_id = getattr(req.state, 'request_id', 'unknown')
    
    try:
        # Log incoming request with metadata only (privacy: no text content)
        logger.info(
            f"analyze_text: session_id={request.session_id} "
            f"app_bundle={request.app_bundle} text_length={len(request.text)} "
            f"request_id={request_id}"
        )
        
        # Parse session_id to UUID
        try:
            session_uuid = uuid.UUID(request.session_id)
        except ValueError as e:
            logger.warning(f"Invalid UUID format: {e} request_id={request_id}")
            raise HTTPException(
                status_code=400,
                detail="Invalid session_id format. Must be a valid UUID."
            )
        
        # Call risk aggregator to analyze text
        try:
            risk_response = await analyze_text_aggregated(text=request.text)
        except Exception as e:
            logger.error(
                f"Risk aggregator failed: {type(e).__name__} request_id={request_id}",
                exc_info=True
            )
            raise HTTPException(
                status_code=500,
                detail="Analysis service temporarily unavailable. Please try again."
            )
        
        # Extract timestamp before storing (DB doesn't need it)
        timestamp = risk_response.pop('ts', datetime.now(timezone.utc).isoformat())
        
        # Store analysis result in database
        try:
            db_result = insert_text_analysis(
                session_id=session_uuid,
                app_bundle=request.app_bundle,
                snippet=request.text,
                risk_data=risk_response
            )
            logger.info(
                f"Analysis stored: id={db_result.get('id')} "
                f"risk_level={risk_response.get('risk_level')} "
                f"request_id={request_id}"
            )
        except Exception as e:
            logger.error(
                f"Database insert failed: {type(e).__name__} request_id={request_id}",
                exc_info=True
            )
            raise HTTPException(
                status_code=500,
                detail="Failed to store analysis result. Please try again."
            )
        
        # Return normalized response with timestamp
        response_data = {
            **risk_response,
            'ts': timestamp
        }
        
        return AnalyzeTextResponse(**response_data)
        
    except HTTPException:
        # Re-raise HTTP exceptions as-is
        raise
    except Exception as e:
        # Catch-all for unexpected errors
        logger.error(
            f"Unexpected error in analyze_text: {type(e).__name__} request_id={request_id}",
            exc_info=True
        )
        raise HTTPException(
            status_code=500,
            detail="An unexpected error occurred. Please try again."
        )


@app.post("/scan-image", response_model=ScanImageResponse, status_code=200)
async def scan_image(
    session_id: str = Form(...),
    ocr_text: str = Form(...),
    image: UploadFile = File(None),
    req: Request = None
):
    """
    Analyze screenshot with OCR text for scam risk using AI providers.
    
    This endpoint receives a screenshot and/or OCR text from the companion app,
    analyzes it for scam risk using Gemini (with OpenAI fallback), stores the 
    result in Supabase, and returns a normalized risk assessment.
    
    Args:
        session_id: Random UUID for session tracking (form field)
        ocr_text: Text extracted from screenshot via OCR (form field, max 5000 chars)
        image: Optional screenshot image file (PNG/JPEG, max 4MB)
        req: FastAPI Request object for accessing request_id
    
    Returns:
        ScanImageResponse with risk_level, confidence, category, explanation, and timestamp
    
    Raises:
        HTTPException 400: Invalid input (malformed UUID, invalid image format/size, etc.)
        HTTPException 422: Pydantic validation failure
        HTTPException 500: Service error (provider failures, database error)
    """
    request_id = getattr(req.state, 'request_id', 'unknown') if req else 'unknown'
    
    try:
        # Validate session_id UUID format
        try:
            session_uuid = uuid.UUID(session_id)
        except ValueError as e:
            logger.warning(f"Invalid UUID format: {e} request_id={request_id}")
            raise HTTPException(
                status_code=400,
                detail="Invalid session_id format. Must be a valid UUID."
            )
        
        # Validate ocr_text
        if not ocr_text or not ocr_text.strip():
            raise HTTPException(
                status_code=422,
                detail="ocr_text cannot be empty or whitespace only"
            )
        
        if len(ocr_text) > 5000:
            raise HTTPException(
                status_code=400,
                detail="ocr_text exceeds maximum length of 5000 characters"
            )
        
        # Handle image if provided
        image_data = None
        mime_type = None
        
        if image:
            # Read image bytes
            image_bytes = await image.read()
            
            # Validate image size (max 4MB)
            if len(image_bytes) > 4 * 1024 * 1024:
                raise HTTPException(
                    status_code=400,
                    detail="Image size exceeds maximum of 4MB"
                )
            
            # Validate image format using imghdr
            image_format = imghdr.what(None, h=image_bytes)
            if image_format not in ['png', 'jpeg']:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid image format. Only PNG and JPEG are supported."
                )
            
            # Set MIME type
            mime_type = f"image/{image_format}"
            image_data = image_bytes
            
            logger.info(
                f"scan_image: session_id={session_id} "
                f"ocr_text_length={len(ocr_text)} "
                f"image_size={len(image_bytes)} image_format={image_format} "
                f"request_id={request_id}"
            )
        else:
            logger.info(
                f"scan_image: session_id={session_id} "
                f"ocr_text_length={len(ocr_text)} image=None "
                f"request_id={request_id}"
            )
        
        # Primary analysis path: Gemini
        gemini_result = None
        openai_result = None
        
        try:
            gemini_result = await analyze_image(
                image_data=image_data,
                ocr_text=ocr_text,
                mime_type=mime_type
            )
            logger.info(
                f"Gemini analysis succeeded: risk_level={gemini_result.get('risk_level')} "
                f"request_id={request_id}"
            )
        except Exception as e:
            logger.warning(
                f"Gemini analysis failed: {type(e).__name__} request_id={request_id}"
            )
            # Gemini failed, will try OpenAI fallback
        
        # Fallback path: OpenAI text-only analysis
        if not gemini_result or gemini_result.get('risk_level') == 'unknown':
            try:
                openai_result = await analyze_text_openai(text=ocr_text)
                logger.info(
                    f"OpenAI fallback succeeded: risk_level={openai_result.get('risk_level')} "
                    f"request_id={request_id}"
                )
            except Exception as e:
                logger.warning(
                    f"OpenAI fallback failed: {type(e).__name__} request_id={request_id}"
                )
        
        # Aggregate results if both succeeded
        if gemini_result and openai_result and \
           gemini_result.get('risk_level') != 'unknown' and \
           openai_result.get('risk_level') != 'unknown':
            risk_response = aggregate_results([gemini_result, openai_result])
            logger.info(
                f"Results aggregated: risk_level={risk_response.get('risk_level')} "
                f"request_id={request_id}"
            )
        elif gemini_result and gemini_result.get('risk_level') != 'unknown':
            risk_response = gemini_result
        elif openai_result and openai_result.get('risk_level') != 'unknown':
            risk_response = openai_result
        else:
            # Both failed, return safe fallback
            logger.error(
                f"Both providers failed, returning fallback response request_id={request_id}"
            )
            risk_response = {
                "risk_level": "unknown",
                "confidence": 0.0,
                "category": "unknown",
                "explanation": "Unable to complete analysis"
            }
        
        # Generate timestamp for response
        timestamp = datetime.now(timezone.utc).isoformat()
        
        # Store result in database
        try:
            db_result = insert_scan_result(
                session_id=session_uuid,
                ocr_text=ocr_text,
                risk_data=risk_response
            )
            logger.info(
                f"Scan result stored: id={db_result.get('id')} "
                f"risk_level={risk_response.get('risk_level')} "
                f"request_id={request_id}"
            )
        except Exception as e:
            logger.error(
                f"Database insert failed: {type(e).__name__} request_id={request_id}",
                exc_info=True
            )
            raise HTTPException(
                status_code=500,
                detail="Failed to store scan result. Please try again."
            )
        
        # Return normalized response with timestamp
        response_data = {
            **risk_response,
            'ts': timestamp
        }
        
        return ScanImageResponse(**response_data)
        
    except HTTPException:
        # Re-raise HTTP exceptions as-is
        raise
    except Exception as e:
        # Catch-all for unexpected errors
        logger.error(
            f"Unexpected error in scan_image: {type(e).__name__} request_id={request_id}",
            exc_info=True
        )
        raise HTTPException(
            status_code=500,
            detail="An unexpected error occurred. Please try again."
        )


@app.get("/results/latest", response_model=AnalyzeTextResponse, status_code=200)
async def get_latest_result_endpoint(session_id: str, req: Request):
    """
    Retrieve the most recent analysis result for a session.
    
    This endpoint queries both text_analyses and scan_results tables and
    returns the most recent result by timestamp. Used by keyboard extension
    to display recent scan results.
    
    Args:
        session_id: UUID string identifying the session (query parameter)
        req: FastAPI Request object for accessing request_id
    
    Returns:
        AnalyzeTextResponse with risk_level, confidence, category, explanation, and timestamp
    
    Raises:
        HTTPException 400: Invalid session_id format (not a valid UUID)
        HTTPException 404: No results found for the session
        HTTPException 422: Missing session_id query parameter
        HTTPException 500: Database query error
    """
    request_id = getattr(req.state, 'request_id', 'unknown')
    
    try:
        # Log incoming request (privacy: session_id only, no content)
        logger.info(
            f"get_latest_result: session_id={session_id} request_id={request_id}"
        )
        
        # Validate session_id UUID format
        try:
            session_uuid = uuid.UUID(session_id)
        except ValueError as e:
            logger.warning(f"Invalid UUID format: {e} request_id={request_id}")
            raise HTTPException(
                status_code=400,
                detail="Invalid session_id format. Must be a valid UUID."
            )
        
        # Query database for latest result
        try:
            latest_result = get_latest_result(session_uuid)
        except Exception as e:
            logger.error(
                f"Database query failed: {type(e).__name__} request_id={request_id}",
                exc_info=True
            )
            raise HTTPException(
                status_code=500,
                detail="Failed to retrieve results. Please try again."
            )
        
        # Return 404 if no results found
        if not latest_result:
            logger.info(f"No results found for session_id={session_id} request_id={request_id}")
            raise HTTPException(
                status_code=404,
                detail="No results found for this session."
            )
        
        # Extract data from latest_result
        result_data = latest_result['data']
        
        # Build response with unified schema
        response_data = {
            'risk_level': result_data['risk_level'],
            'confidence': result_data['confidence'],
            'category': result_data['category'],
            'explanation': result_data['explanation'],
            'ts': result_data['created_at']
        }
        
        logger.info(
            f"Latest result retrieved: type={latest_result['type']} "
            f"risk_level={response_data['risk_level']} request_id={request_id}"
        )
        
        return AnalyzeTextResponse(**response_data)
        
    except HTTPException:
        # Re-raise HTTP exceptions as-is
        raise
    except Exception as e:
        # Catch-all for unexpected errors
        logger.error(
            f"Unexpected error in get_latest_result: {type(e).__name__} request_id={request_id}",
            exc_info=True
        )
        raise HTTPException(
            status_code=500,
            detail="An unexpected error occurred. Please try again."
        )


@app.get("/health")
async def health_check():
    """
    Health check endpoint for monitoring service status.
    
    Returns:
        JSON with service status, timestamp, and version
    """
    return JSONResponse(
        status_code=200,
        content={
            "status": "healthy",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "version": "1.0",
            "environment": settings.environment
        }
    )


@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "service": "TypeSafe API",
        "version": "1.0",
        "docs": "/docs"
    }


# Startup event
@app.on_event("startup")
async def startup_event():
    """Log startup information and validate configuration"""
    logger.info("=" * 60)
    logger.info("TypeSafe Backend API Starting")
    logger.info(f"Environment: {settings.environment}")
    logger.info(f"CORS Origins: {settings.cors_origins}")
    logger.info("=" * 60)
    
    # Validate critical configuration
    settings.validate_required_keys()
    logger.info("✓ Configuration validated successfully")


# Shutdown event
@app.on_event("shutdown")
async def shutdown_event():
    """Log shutdown information"""
    logger.info("TypeSafe Backend API Shutting Down")

