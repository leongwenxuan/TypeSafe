"""
TypeSafe Backend API - Main Application

FastAPI backend service for AI-powered scam detection.
Handles requests from iOS keyboard extension and companion app.
"""
import logging
import uuid
from datetime import datetime, timezone
from typing import Callable

from fastapi import FastAPI, Request, Response, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, field_validator

from app.config import settings
from app.services.risk_aggregator import analyze_text_aggregated
from app.db.operations import insert_text_analysis

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

