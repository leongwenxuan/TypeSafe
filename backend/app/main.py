"""
TypeSafe Backend API - Main Application

FastAPI backend service for AI-powered scam detection.
Handles requests from iOS keyboard extension and companion app.
"""
import logging
import os
import uuid
from datetime import datetime, timezone
from typing import Callable, Dict, Any

from fastapi import FastAPI, Request, Response, HTTPException, File, Form, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, field_validator
import imghdr
import asyncio
import json
import redis.asyncio as redis

from app.config import settings
from app.services.risk_aggregator import analyze_text_aggregated, aggregate_results
from app.services.gemini_service import analyze_image
from app.services.groq_service import analyze_text as analyze_text_groq
from app.db.operations import insert_text_analysis, insert_scan_result, get_latest_result, ensure_session_exists
from app.agents.worker import celery_app
from app.agents.tasks.example_task import example_agent_task
from app.agents.tools.scam_database import get_scam_database_tool

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
    for scam risk using Groq, stores the result in Supabase, and returns
    a normalized risk assessment.
    
    Args:
        request: Request body with session_id, app_bundle, and text
        req: FastAPI Request object for accessing request_id
    
    Returns:
        AnalyzeTextResponse with risk_level, confidence, category, explanation, and timestamp
    
    Raises:
        HTTPException 400: Invalid input (malformed UUID, empty text, etc.)
        HTTPException 500: Service error (Groq failure, database error)
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
        
        # Ensure session exists before storing result
        try:
            # Create session if it doesn't exist
            session_data = ensure_session_exists(session_uuid)
            logger.info(
                f"Session ensured: session_id={session_uuid} "
                f"request_id={request_id}"
            )
            
            # Store analysis result in database
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


async def _check_worker_availability() -> bool:
    """
    Quick check if Celery worker is available.
    
    Returns:
        True if worker is available, False otherwise
    """
    try:
        inspect = celery_app.control.inspect(timeout=0.5)
        active_workers = inspect.active()
        return active_workers is not None and len(active_workers) > 0
    except Exception as e:
        logger.warning(f"Worker availability check failed: {e}")
        return False


async def _analyze_fast_path(
    image_data: bytes | None,
    ocr_text: str,
    mime_type: str | None,
    user_country: str | None,
    session_uuid: uuid.UUID,
    request_id: str
) -> Dict[str, Any]:
    """
    Fast path analysis using Gemini/Groq (existing logic).
    
    Args:
        image_data: Optional image bytes
        ocr_text: OCR text to analyze
        mime_type: Optional MIME type of image
        user_country: Optional user country
        session_uuid: Session UUID
        request_id: Request ID for logging
    
    Returns:
        Risk analysis result dict
    """
    # Primary analysis path: Gemini
    gemini_result = None
    openai_result = None
    
    try:
        gemini_result = await analyze_image(
            image_data=image_data,
            ocr_text=ocr_text,
            mime_type=mime_type,
            user_country=user_country
        )
        logger.info(
            f"Gemini analysis succeeded: risk_level={gemini_result.get('risk_level')} "
            f"request_id={request_id}"
        )
    except Exception as e:
        logger.warning(
            f"Gemini analysis failed: {type(e).__name__} request_id={request_id}"
        )
        # Gemini failed, will try Groq fallback
    
    # Fallback path: Groq text-only analysis
    if not gemini_result or gemini_result.get('risk_level') == 'unknown':
        try:
            openai_result = await analyze_text_groq(text=ocr_text)
            logger.info(
                f"Groq fallback succeeded: risk_level={openai_result.get('risk_level')} "
                f"request_id={request_id}"
            )
        except Exception as e:
            logger.warning(
                f"Groq fallback failed: {type(e).__name__} request_id={request_id}"
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
    
    # Ensure session exists before storing result
    try:
        # Create session if it doesn't exist (same as /analyze-text)
        session_data = ensure_session_exists(session_uuid)
        logger.info(
            f"Session ensured: session_id={session_uuid} "
            f"request_id={request_id}"
        )
        
        # Store result in database
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
    return {
        **risk_response,
        'ts': timestamp
    }


@app.post("/scan-image")
async def scan_image(
    session_id: str = Form(...),
    ocr_text: str = Form(...),
    user_country: str = Form(None),
    image: UploadFile = File(None),
    req: Request = None
):
    """
    Analyze screenshot with OCR text for scam risk using smart routing.
    
    This endpoint uses smart routing to decide between fast path and agent path:
    - Fast Path: No entities detected, uses Gemini/Groq analysis only (1-3s)
    - Agent Path: Contains entities, requires tool investigation (5-30s)
    
    Args:
        session_id: Random UUID for session tracking (form field)
        ocr_text: Text extracted from screenshot via OCR (form field, max 5000 chars)
        user_country: Optional user country code for localization (form field)
        image: Optional screenshot image file (PNG/JPEG, max 4MB)
        req: FastAPI Request object for accessing request_id
    
    Returns:
        Fast path: {"type": "simple", "result": {...}}
        Agent path: {"type": "agent", "task_id": "...", "ws_url": "...", "estimated_time": "..."}
    
    Raises:
        HTTPException 400: Invalid input (malformed UUID, invalid image format/size, etc.)
        HTTPException 422: Pydantic validation failure
        HTTPException 500: Service error (provider failures, database error)
    """
    request_id = getattr(req.state, 'request_id', 'unknown') if req else 'unknown'
    routing_start = datetime.now(timezone.utc)
    
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
                f"user_country={user_country} "
                f"request_id={request_id}"
            )
        else:
            logger.info(
                f"scan_image: session_id={session_id} "
                f"ocr_text_length={len(ocr_text)} image=None "
                f"user_country={user_country} "
                f"request_id={request_id}"
            )
        
        # =============================================================================
        # SMART ROUTING LOGIC (Story 8.10)
        # =============================================================================
        
        # Step 1: Quick entity extraction check (< 100ms)
        from app.services.entity_extractor import get_entity_extractor
        from app.metrics.routing_metrics import get_metrics_tracker
        
        extractor = get_entity_extractor()
        entities = extractor.extract(ocr_text)
        
        has_entities = entities.has_entities()
        entity_extraction_time = (datetime.now(timezone.utc) - routing_start).total_seconds() * 1000
        
        logger.info(
            f"Entity extraction complete: has_entities={has_entities} "
            f"count={entities.entity_count()} time_ms={entity_extraction_time:.2f} "
            f"request_id={request_id}"
        )
        
        # Get metrics tracker
        metrics_tracker = get_metrics_tracker()
        
        # Step 2: Routing decision
        # Route to agent path if entities found AND agent is enabled AND worker is available
        if has_entities and settings.enable_mcp_agent:
            # Check if Celery worker is available (quick health check)
            worker_available = await _check_worker_availability()
            
            if worker_available:
                # AGENT PATH: Enqueue MCP agent task
                logger.info(
                    f"Routing to AGENT PATH: entities={entities.entity_count()} "
                    f"request_id={request_id}"
                )
                
                # Ensure session exists
                session_data = ensure_session_exists(session_uuid)
                
                # Generate task ID
                task_id = str(uuid.uuid4())
                
                # Import agent task
                from app.agents.mcp_agent import analyze_with_mcp_agent
                
                # Enqueue agent task
                analyze_with_mcp_agent.apply_async(
                    args=[task_id, ocr_text, str(session_uuid), {"country": user_country}],
                    task_id=task_id
                )
                
                logger.info(
                    f"Agent task enqueued: task_id={task_id} request_id={request_id}"
                )
                
                # Record metrics
                metrics_tracker.record_routing_decision(
                    route_type='agent_path',
                    has_entities=True,
                    entity_count=entities.entity_count(),
                    routing_time_ms=entity_extraction_time,
                    session_id=str(session_uuid),
                    request_id=request_id
                )
                
                # Get API domain from environment or request Host header
                # Priority: 1. API_DOMAIN env var, 2. Host header from request, 3. localhost:8000
                api_domain = os.getenv('API_DOMAIN') or req.headers.get('host', 'localhost:8000')
                
                # Use WSS for ngrok/production, WS for localhost
                if 'ngrok' in api_domain or settings.environment in ['production', 'staging']:
                    ws_protocol = 'wss'
                else:
                    ws_protocol = 'ws'
                
                ws_url = f"{ws_protocol}://{api_domain}/ws/agent-progress/{task_id}"
                logger.info(f"WebSocket URL: {ws_url}")
                
                # Return agent path response
                return {
                    "type": "agent",
                    "task_id": task_id,
                    "ws_url": ws_url,
                    "estimated_time": "5-30 seconds",
                    "entities_found": entities.entity_count()
                }
            else:
                logger.warning(
                    f"Worker unavailable, falling back to FAST PATH request_id={request_id}"
                )
                # Record fallback metrics
                metrics_tracker.record_routing_decision(
                    route_type='fast_path',
                    has_entities=True,
                    entity_count=entities.entity_count(),
                    routing_time_ms=entity_extraction_time,
                    session_id=str(session_uuid),
                    request_id=request_id,
                    fallback_reason='worker_unavailable'
                )
                # Fall through to fast path
        else:
            logger.info(
                f"Routing to FAST PATH: has_entities={has_entities} "
                f"agent_enabled={settings.enable_mcp_agent} request_id={request_id}"
            )
            
            # Determine fallback reason
            fallback_reason = None
            if has_entities and not settings.enable_mcp_agent:
                fallback_reason = 'agent_disabled'
            
            # Record metrics for fast path
            metrics_tracker.record_routing_decision(
                route_type='fast_path',
                has_entities=has_entities,
                entity_count=entities.entity_count(),
                routing_time_ms=entity_extraction_time,
                session_id=str(session_uuid),
                request_id=request_id,
                fallback_reason=fallback_reason
            )
        
        # =============================================================================
        # FAST PATH: Existing Gemini/Groq analysis
        # =============================================================================
        
        fast_path_start = datetime.now(timezone.utc)
        result = await _analyze_fast_path(
            image_data=image_data,
            ocr_text=ocr_text,
            mime_type=mime_type,
            user_country=user_country,
            session_uuid=session_uuid,
            request_id=request_id
        )
        fast_path_time = (datetime.now(timezone.utc) - fast_path_start).total_seconds() * 1000
        
        # Update metrics with total time
        if metrics_tracker.metrics:
            metrics_tracker.metrics[-1].total_time_ms = fast_path_time
        
        return {
            "type": "simple",
            "result": result
        }
        
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


@app.get("/metrics/routing")
async def get_routing_metrics(window_minutes: int = 60, req: Request = None):
    """
    Get routing metrics and statistics (Story 8.10).
    
    Returns statistics about routing decisions, including percentages of
    agent path vs fast path, latency metrics, and fallback rates.
    
    Args:
        window_minutes: Time window for statistics (default 60 minutes)
        req: FastAPI Request object for accessing request_id
    
    Returns:
        JSON with routing statistics
    """
    request_id = getattr(req.state, 'request_id', 'unknown') if req else 'unknown'
    
    try:
        from app.metrics.routing_metrics import get_metrics_tracker
        
        metrics_tracker = get_metrics_tracker()
        
        # Get routing stats
        stats = metrics_tracker.get_routing_stats(window_minutes=window_minutes)
        
        # Get latency stats for both paths
        fast_path_latency = metrics_tracker.get_latency_stats(
            route_type='fast_path',
            window_minutes=window_minutes
        )
        agent_path_latency = metrics_tracker.get_latency_stats(
            route_type='agent_path',
            window_minutes=window_minutes
        )
        
        # Check for alerts
        alerts = metrics_tracker.check_alert_conditions()
        
        logger.info(
            f"Routing metrics retrieved: window={window_minutes}min "
            f"total_scans={stats['total_scans']} request_id={request_id}"
        )
        
        return {
            "routing_stats": stats,
            "fast_path_latency": fast_path_latency,
            "agent_path_latency": agent_path_latency,
            "alerts": alerts
        }
        
    except Exception as e:
        logger.error(
            f"Failed to get routing metrics: {type(e).__name__} request_id={request_id}",
            exc_info=True
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to retrieve routing metrics: {str(e)}"
        )


@app.get("/health/agent")
async def agent_health_check(req: Request):
    """
    Health check for MCP agent worker availability (Story 8.10).
    
    Checks if Celery workers are active and responsive for agent tasks.
    Used by load balancers and monitoring to detect worker issues.
    
    Args:
        req: FastAPI Request object for accessing request_id
    
    Returns:
        JSON with agent status, worker count, and timestamp
    
    Raises:
        HTTPException 503: If no workers are active
    """
    request_id = getattr(req.state, 'request_id', 'unknown')
    
    try:
        logger.info(f"Agent health check starting: request_id={request_id}")
        
        # Check if workers are active
        worker_available = await _check_worker_availability()
        
        if not worker_available:
            logger.warning(f"No active agent workers found request_id={request_id}")
            raise HTTPException(
                status_code=503,
                detail="No active agent workers"
            )
        
        # Get detailed worker info
        inspect = celery_app.control.inspect(timeout=1.0)
        active_workers = inspect.active()
        active_task_count = sum(len(tasks) for tasks in (active_workers or {}).values())
        
        logger.info(
            f"Agent health check passed: workers={len(active_workers or {})} "
            f"active_tasks={active_task_count} request_id={request_id}"
        )
        
        return JSONResponse(
            status_code=200,
            content={
                "status": "healthy",
                "agent_enabled": settings.enable_mcp_agent,
                "workers_active": len(active_workers or {}),
                "active_tasks": active_task_count,
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            f"Agent health check failed: {type(e).__name__} request_id={request_id}",
            exc_info=True
        )
        raise HTTPException(
            status_code=503,
            detail=f"Agent health check failed: {str(e)}"
        )


@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "service": "TypeSafe API",
        "version": "1.0",
        "docs": "/docs"
    }


# ============================================================================
# Celery Task Management Endpoints
# ============================================================================

class EnqueueTaskRequest(BaseModel):
    """Request model for enqueuing a task"""
    data: dict = Field(
        ...,
        description="Task input data",
        examples=[{"key": "value", "simulate_failure": False}]
    )


class TaskStatusResponse(BaseModel):
    """Response model for task status"""
    task_id: str = Field(..., description="Task UUID")
    status: str = Field(..., description="Task status (PENDING, STARTED, PROGRESS, SUCCESS, FAILURE)")
    result: dict | None = Field(None, description="Task result (if completed)")
    error: str | None = Field(None, description="Error message (if failed)")
    meta: dict | None = Field(None, description="Task metadata (progress, etc.)")


class CeleryHealthResponse(BaseModel):
    """Response model for Celery health check"""
    status: str = Field(..., description="Health status")
    workers: list = Field(..., description="List of active worker names")
    active_tasks: int = Field(..., description="Number of active tasks across all workers")


@app.post("/tasks/enqueue", response_model=dict, status_code=202)
async def enqueue_task(request: EnqueueTaskRequest, req: Request):
    """
    Enqueue a new agent task for asynchronous processing.
    
    This endpoint demonstrates the Celery infrastructure by enqueuing
    an example task. Future stories will add MCP agent orchestration tasks.
    
    Args:
        request: Request body with task input data
        req: FastAPI Request object for accessing request_id
    
    Returns:
        dict with task_id, status, and message
    
    Raises:
        HTTPException 500: If task enqueueing fails
    """
    request_id = getattr(req.state, 'request_id', 'unknown')
    
    try:
        # Generate unique task ID
        task_uuid = str(uuid.uuid4())
        
        logger.info(
            f"Enqueueing task: task_id={task_uuid} request_id={request_id}"
        )
        
        # Enqueue task with custom task_id
        result = example_agent_task.apply_async(
            args=[task_uuid, request.data],
            task_id=task_uuid
        )
        
        logger.info(
            f"Task enqueued successfully: task_id={result.id} request_id={request_id}"
        )
        
        return {
            "task_id": result.id,
            "status": "pending",
            "message": "Task enqueued successfully"
        }
        
    except Exception as e:
        logger.error(
            f"Failed to enqueue task: {type(e).__name__} request_id={request_id}",
            exc_info=True
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to enqueue task: {str(e)}"
        )


@app.get("/tasks/status/{task_id}", response_model=TaskStatusResponse, status_code=200)
async def get_task_status(task_id: str, req: Request):
    """
    Get the current status of a task.
    
    This endpoint retrieves the current state of a Celery task,
    including progress updates, results, or error information.
    
    Args:
        task_id: UUID of the task to check
        req: FastAPI Request object for accessing request_id
    
    Returns:
        TaskStatusResponse with task_id, status, result, error, and meta
    
    Raises:
        HTTPException 400: If task_id is invalid format
        HTTPException 404: If task is not found
    """
    request_id = getattr(req.state, 'request_id', 'unknown')
    
    try:
        # Validate task_id is a UUID
        try:
            uuid.UUID(task_id)
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail="Invalid task_id format. Must be a valid UUID."
            )
        
        logger.info(
            f"Checking task status: task_id={task_id} request_id={request_id}"
        )
        
        # Get task result from Celery
        result = celery_app.AsyncResult(task_id)
        
        response = {
            "task_id": task_id,
            "status": result.state,
            "result": None,
            "error": None,
            "meta": None
        }
        
        # Add result or error based on state
        if result.successful():
            response["result"] = result.result
        elif result.failed():
            response["error"] = str(result.info)
        elif result.state == 'PROGRESS':
            response["meta"] = result.info
        
        logger.info(
            f"Task status retrieved: task_id={task_id} status={result.state} request_id={request_id}"
        )
        
        return TaskStatusResponse(**response)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            f"Failed to get task status: {type(e).__name__} request_id={request_id}",
            exc_info=True
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to retrieve task status: {str(e)}"
        )


@app.get("/health/celery", response_model=CeleryHealthResponse, status_code=200)
async def celery_health_check(req: Request):
    """
    Check Celery worker health and status.
    
    This endpoint verifies that Celery workers are active and responsive.
    Used for monitoring and load balancer health checks.
    
    Args:
        req: FastAPI Request object for accessing request_id
    
    Returns:
        CeleryHealthResponse with status, workers, and active_tasks
    
    Raises:
        HTTPException 503: If no workers are active or health check fails
    """
    request_id = getattr(req.state, 'request_id', 'unknown')
    
    try:
        logger.info(f"Celery health check starting: request_id={request_id}")
        
        # Check if workers are active
        inspect = celery_app.control.inspect()
        active_workers = inspect.active()
        
        if not active_workers:
            logger.warning(f"No active Celery workers found request_id={request_id}")
            raise HTTPException(
                status_code=503,
                detail="No active Celery workers"
            )
        
        # Count active tasks across all workers
        active_task_count = sum(len(tasks) for tasks in active_workers.values())
        
        logger.info(
            f"Celery health check passed: workers={len(active_workers)} "
            f"active_tasks={active_task_count} request_id={request_id}"
        )
        
        return CeleryHealthResponse(
            status="healthy",
            workers=list(active_workers.keys()),
            active_tasks=active_task_count
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            f"Celery health check failed: {type(e).__name__} request_id={request_id}",
            exc_info=True
        )
        raise HTTPException(
            status_code=503,
            detail=f"Celery health check failed: {str(e)}"
        )


# =============================================================================
# Admin API Endpoints - Scam Report Management
# =============================================================================

class CreateScamReportRequest(BaseModel):
    """Request model for creating a scam report."""
    entity_type: str = Field(
        ...,
        description="Type of entity: phone, url, email, payment, or bitcoin"
    )
    entity_value: str = Field(
        ...,
        description="Entity value (will be normalized)"
    )
    evidence: dict = Field(
        default=None,
        description="Evidence object with source, url, date fields"
    )
    notes: str = Field(
        default=None,
        description="Admin notes about this scam"
    )
    
    @field_validator('entity_type')
    @classmethod
    def validate_entity_type(cls, v: str) -> str:
        """Validate entity_type is one of the allowed types"""
        allowed = ['phone', 'url', 'email', 'payment', 'bitcoin']
        if v not in allowed:
            raise ValueError(f'entity_type must be one of {allowed}')
        return v


class UpdateScamReportRequest(BaseModel):
    """Request model for updating a scam report."""
    verified: bool = Field(
        default=None,
        description="Whether this scam is manually verified"
    )
    risk_score: float = Field(
        default=None,
        ge=0.0,
        le=100.0,
        description="Manual risk score override (0-100)"
    )
    notes: str = Field(
        default=None,
        description="Admin notes"
    )


class ScamReportResponse(BaseModel):
    """Response model for scam report operations."""
    message: str
    report: dict = None


class ScamReportsListResponse(BaseModel):
    """Response model for listing scam reports."""
    reports: list
    count: int
    limit: int
    offset: int


@app.post(
    "/admin/scam-reports",
    response_model=ScamReportResponse,
    status_code=201,
    tags=["admin"]
)
async def create_scam_report(request: CreateScamReportRequest, req: Request):
    """
    Add new scam report to database.
    
    Creates a new scam report or updates an existing one if the entity
    already exists. Requires admin authentication (to be implemented).
    
    Args:
        request: CreateScamReportRequest with entity details
        req: FastAPI Request object
    
    Returns:
        ScamReportResponse with success message
    
    Raises:
        HTTPException 400: If entity_type is invalid
        HTTPException 500: If database operation fails
    """
    request_id = getattr(req.state, 'request_id', 'unknown')
    
    try:
        logger.info(
            f"Creating scam report: type={request.entity_type} "
            f"value={request.entity_value} request_id={request_id}"
        )
        
        tool = get_scam_database_tool()
        
        success = tool.add_report(
            entity_type=request.entity_type,
            entity_value=request.entity_value,
            evidence=request.evidence,
            notes=request.notes
        )
        
        if not success:
            raise HTTPException(
                status_code=500,
                detail="Failed to create scam report"
            )
        
        logger.info(
            f"Scam report created successfully: type={request.entity_type} "
            f"request_id={request_id}"
        )
        
        return ScamReportResponse(
            message="Scam report created successfully"
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            f"Failed to create scam report: {type(e).__name__} request_id={request_id}",
            exc_info=True
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create scam report: {str(e)}"
        )


@app.get(
    "/admin/scam-reports",
    response_model=ScamReportsListResponse,
    tags=["admin"]
)
async def list_scam_reports(
    req: Request,
    entity_type: str = None,
    min_risk_score: float = None,
    verified_only: bool = False,
    limit: int = 100,
    offset: int = 0
):
    """
    List scam reports with filters.
    
    Retrieves scam reports from the database with optional filtering by
    entity type, risk score, and verification status.
    
    Args:
        req: FastAPI Request object
        entity_type: Optional filter by entity type
        min_risk_score: Optional minimum risk score filter
        verified_only: If True, only return verified reports
        limit: Maximum number of reports to return (default 100)
        offset: Offset for pagination (default 0)
    
    Returns:
        ScamReportsListResponse with list of reports
    
    Raises:
        HTTPException 500: If database query fails
    """
    request_id = getattr(req.state, 'request_id', 'unknown')
    
    try:
        logger.info(
            f"Listing scam reports: entity_type={entity_type} "
            f"min_risk_score={min_risk_score} verified_only={verified_only} "
            f"limit={limit} offset={offset} request_id={request_id}"
        )
        
        from app.db.client import get_supabase_client
        supabase = get_supabase_client()
        
        query = supabase.table('scam_reports').select('*')
        
        if entity_type:
            query = query.eq('entity_type', entity_type)
        
        if min_risk_score is not None:
            query = query.gte('risk_score', min_risk_score)
        
        if verified_only:
            query = query.eq('verified', True)
        
        query = query.order('last_reported', desc=True).limit(limit).offset(offset)
        
        response = query.execute()
        
        logger.info(
            f"Scam reports retrieved: count={len(response.data)} request_id={request_id}"
        )
        
        return ScamReportsListResponse(
            reports=response.data or [],
            count=len(response.data or []),
            limit=limit,
            offset=offset
        )
    
    except Exception as e:
        logger.error(
            f"Failed to list scam reports: {type(e).__name__} request_id={request_id}",
            exc_info=True
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to list scam reports: {str(e)}"
        )


@app.patch(
    "/admin/scam-reports/{report_id}",
    response_model=ScamReportResponse,
    tags=["admin"]
)
async def update_scam_report(
    report_id: int,
    request: UpdateScamReportRequest,
    req: Request
):
    """
    Update scam report (verify, adjust risk score, add notes).
    
    Allows admins to manually verify reports, override risk scores, or
    add notes. At least one field must be provided.
    
    Args:
        report_id: ID of the scam report to update
        request: UpdateScamReportRequest with fields to update
        req: FastAPI Request object
    
    Returns:
        ScamReportResponse with updated report
    
    Raises:
        HTTPException 400: If no fields provided to update
        HTTPException 404: If report not found
        HTTPException 500: If database operation fails
    """
    request_id = getattr(req.state, 'request_id', 'unknown')
    
    try:
        logger.info(
            f"Updating scam report: id={report_id} request_id={request_id}"
        )
        
        from app.db.client import get_supabase_client
        supabase = get_supabase_client()
        
        update_data = {}
        if request.verified is not None:
            update_data['verified'] = request.verified
        if request.risk_score is not None:
            update_data['risk_score'] = request.risk_score
        if request.notes is not None:
            update_data['notes'] = request.notes
        
        if not update_data:
            raise HTTPException(
                status_code=400,
                detail="No fields to update"
            )
        
        response = supabase.table('scam_reports').update(update_data).eq(
            'id', report_id
        ).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=404,
                detail="Scam report not found"
            )
        
        logger.info(
            f"Scam report updated successfully: id={report_id} request_id={request_id}"
        )
        
        return ScamReportResponse(
            message="Scam report updated successfully",
            report=response.data[0]
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            f"Failed to update scam report: {type(e).__name__} request_id={request_id}",
            exc_info=True
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to update scam report: {str(e)}"
        )


@app.delete(
    "/admin/scam-reports/{report_id}",
    response_model=ScamReportResponse,
    tags=["admin"]
)
async def delete_scam_report(report_id: int, req: Request):
    """
    Delete scam report (remove false positive).
    
    Permanently removes a scam report from the database. Use with caution.
    Typically used to remove false positives or duplicate entries.
    
    Args:
        report_id: ID of the scam report to delete
        req: FastAPI Request object
    
    Returns:
        ScamReportResponse with success message
    
    Raises:
        HTTPException 404: If report not found
        HTTPException 500: If database operation fails
    """
    request_id = getattr(req.state, 'request_id', 'unknown')
    
    try:
        logger.info(
            f"Deleting scam report: id={report_id} request_id={request_id}"
        )
        
        from app.db.client import get_supabase_client
        supabase = get_supabase_client()
        
        response = supabase.table('scam_reports').delete().eq(
            'id', report_id
        ).execute()
        
        if not response.data:
            raise HTTPException(
                status_code=404,
                detail="Scam report not found"
            )
        
        logger.info(
            f"Scam report deleted successfully: id={report_id} request_id={request_id}"
        )
        
        return ScamReportResponse(
            message="Scam report deleted successfully"
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            f"Failed to delete scam report: {type(e).__name__} request_id={request_id}",
            exc_info=True
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete scam report: {str(e)}"
        )


class ScamAnalyticsResponse(BaseModel):
    """Response model for scam analytics."""
    total_reports: int
    by_type: dict
    by_risk_level: dict
    top_scams: list
    recent_additions: list
    stats_generated_at: str


@app.get(
    "/admin/scam-analytics",
    response_model=ScamAnalyticsResponse,
    tags=["admin"]
)
async def get_scam_analytics(req: Request):
    """
    Get scam database analytics and statistics.
    
    Provides comprehensive statistics about the scam database including:
    - Total report counts
    - Breakdown by entity type (phone, url, email, etc.)
    - Breakdown by risk level (low, medium, high, critical)
    - Top 10 most reported scams
    - 20 most recent additions
    
    Args:
        req: FastAPI Request object
    
    Returns:
        ScamAnalyticsResponse with analytics data
    
    Raises:
        HTTPException 500: If database query fails
    """
    request_id = getattr(req.state, 'request_id', 'unknown')
    
    try:
        logger.info(f"Fetching scam analytics: request_id={request_id}")
        
        from app.db.client import get_supabase_client
        supabase = get_supabase_client()
        
        # Get all reports for analysis
        all_reports_response = supabase.table('scam_reports').select('*').execute()
        all_reports = all_reports_response.data or []
        
        total_reports = len(all_reports)
        
        # Count by entity type
        by_type = {}
        by_risk_level = {'low': 0, 'medium': 0, 'high': 0, 'critical': 0}
        
        for report in all_reports:
            # Count by type
            entity_type = report.get('entity_type', 'unknown')
            by_type[entity_type] = by_type.get(entity_type, 0) + 1
            
            # Count by risk level
            risk_score = report.get('risk_score', 0)
            if risk_score >= 90:
                by_risk_level['critical'] += 1
            elif risk_score >= 70:
                by_risk_level['high'] += 1
            elif risk_score >= 40:
                by_risk_level['medium'] += 1
            else:
                by_risk_level['low'] += 1
        
        # Get top 10 most reported scams
        top_scams_response = supabase.table('scam_reports').select('*').order(
            'report_count', desc=True
        ).limit(10).execute()
        
        top_scams = []
        for report in (top_scams_response.data or []):
            top_scams.append({
                'entity_type': report.get('entity_type'),
                'entity_value': report.get('entity_value'),
                'report_count': report.get('report_count'),
                'risk_score': report.get('risk_score'),
                'verified': report.get('verified', False)
            })
        
        # Get 20 most recent additions
        recent_response = supabase.table('scam_reports').select('*').order(
            'created_at', desc=True
        ).limit(20).execute()
        
        recent_additions = []
        for report in (recent_response.data or []):
            recent_additions.append({
                'entity_type': report.get('entity_type'),
                'entity_value': report.get('entity_value'),
                'risk_score': report.get('risk_score'),
                'created_at': report.get('created_at'),
                'verified': report.get('verified', False)
            })
        
        logger.info(
            f"Analytics generated: total={total_reports} types={len(by_type)} "
            f"request_id={request_id}"
        )
        
        return ScamAnalyticsResponse(
            total_reports=total_reports,
            by_type=by_type,
            by_risk_level=by_risk_level,
            top_scams=top_scams,
            recent_additions=recent_additions,
            stats_generated_at=datetime.now(timezone.utc).isoformat()
        )
    
    except Exception as e:
        logger.error(
            f"Failed to fetch analytics: {type(e).__name__} request_id={request_id}",
            exc_info=True
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch analytics: {str(e)}"
        )


# =============================================================================
# WebSocket Progress Streaming (Story 8.9)
# =============================================================================

@app.websocket("/ws/agent-progress/{task_id}")
async def agent_progress_stream(websocket: WebSocket, task_id: str):
    """
    Stream agent progress updates via WebSocket.
    
    This endpoint subscribes to Redis Pub/Sub for agent progress updates
    and streams them in real-time to connected clients. Clients receive
    JSON messages with step, tool, message, and percent completion.
    
    Args:
        websocket: WebSocket connection
        task_id: Unique agent task identifier
    
    Message Format:
        {
            "step": "entity_extraction" | "scam_db" | "exa_search" | "domain_reputation" | 
                    "phone_validator" | "reasoning" | "completed" | "failed",
            "tool": Optional tool name for UI mapping,
            "message": Human-readable progress message,
            "percent": Completion percentage (0-100),
            "timestamp": ISO timestamp,
            "error": Optional boolean indicating error state
        }
    
    Connection Management:
        - Heartbeat every 15 seconds to keep connection alive
        - Auto-closes when task completes or fails
        - Gracefully handles client disconnection
        - Timeout if no messages for 60 seconds
    """
    await websocket.accept()
    logger.info(f"WebSocket connected: task_id={task_id}")
    
    redis_client = None
    pubsub = None
    heartbeat_task = None
    
    try:
        # Connect to Redis
        redis_url = settings.redis_url
        redis_client = await redis.from_url(redis_url, decode_responses=True)
        pubsub = redis_client.pubsub()
        
        # Subscribe to progress channel
        channel = f'agent_progress:{task_id}'
        await pubsub.subscribe(channel)
        logger.debug(f"Subscribed to Redis channel: {channel}")
        
        # Send initial connection message
        await websocket.send_json({
            "step": "connected",
            "message": "Connected to agent progress stream",
            "percent": 0,
            "timestamp": datetime.now(timezone.utc).isoformat()
        })
        
        # Start heartbeat task
        heartbeat_task = asyncio.create_task(_websocket_heartbeat(websocket))
        
        # Stream messages with timeout
        timeout_seconds = 60
        last_message_time = asyncio.get_event_loop().time()
        
        async for message in pubsub.listen():
            # Update last message time
            last_message_time = asyncio.get_event_loop().time()
            
            if message['type'] == 'message':
                try:
                    # Parse and validate message
                    data = json.loads(message['data'])
                    
                    # Send to client
                    await websocket.send_text(message['data'])
                    logger.debug(f"Progress sent: task_id={task_id} step={data.get('step')}")
                    
                    # Check if task completed or failed
                    if data.get('step') in ['completed', 'failed']:
                        logger.info(f"Task {task_id} {data.get('step')}, closing WebSocket")
                        break
                
                except json.JSONDecodeError as e:
                    logger.warning(f"Invalid JSON in progress message: {message['data']}, error: {e}")
                except Exception as e:
                    logger.error(f"Error sending message: {e}", exc_info=True)
                    break
            
            # Check for timeout (no messages for 60 seconds)
            elif asyncio.get_event_loop().time() - last_message_time > timeout_seconds:
                logger.warning(f"WebSocket timeout for task {task_id} (no messages for {timeout_seconds}s)")
                await websocket.send_json({
                    "step": "failed",
                    "message": "Connection timeout - task may have failed",
                    "percent": 0,
                    "error": True,
                    "timestamp": datetime.now(timezone.utc).isoformat()
                })
                break
        
    except WebSocketDisconnect:
        logger.info(f"WebSocket disconnected: task_id={task_id}")
    
    except Exception as e:
        logger.error(f"WebSocket error for task {task_id}: {e}", exc_info=True)
        try:
            await websocket.send_json({
                "step": "failed",
                "message": f"Server error: {str(e)}",
                "percent": 0,
                "error": True,
                "timestamp": datetime.now(timezone.utc).isoformat()
            })
        except:
            pass
    
    finally:
        # Cancel heartbeat
        if heartbeat_task:
            heartbeat_task.cancel()
            try:
                await heartbeat_task
            except asyncio.CancelledError:
                pass
        
        # Cleanup Redis
        if pubsub:
            try:
                await pubsub.unsubscribe(f'agent_progress:{task_id}')
                await pubsub.close()
                logger.debug(f"Unsubscribed from Redis channel: agent_progress:{task_id}")
            except Exception as e:
                logger.error(f"Error cleaning up Redis pubsub: {e}")
        
        if redis_client:
            try:
                await redis_client.close()
            except Exception as e:
                logger.error(f"Error closing Redis client: {e}")
        
        # Close WebSocket
        try:
            await websocket.close()
        except:
            pass
        
        logger.info(f"WebSocket cleanup complete: task_id={task_id}")


async def _websocket_heartbeat(websocket: WebSocket, interval: int = 15):
    """
    Send periodic heartbeat to keep connection alive.
    
    Args:
        websocket: WebSocket connection
        interval: Heartbeat interval in seconds (default 15)
    """
    try:
        while True:
            await asyncio.sleep(interval)
            await websocket.send_json({
                "heartbeat": True,
                "timestamp": datetime.now(timezone.utc).isoformat()
            })
            logger.debug("Heartbeat sent")
    except asyncio.CancelledError:
        logger.debug("Heartbeat task cancelled")
    except Exception as e:
        logger.error(f"Heartbeat error: {e}")


# =============================================================================
# Agent Task Status Endpoint (Story 8.10)
# =============================================================================

class AgentTaskStatusResponse(BaseModel):
    """Response model for agent task status."""
    task_id: str = Field(..., description="Task UUID")
    status: str = Field(..., description="Task status (pending, processing, completed, failed)")
    result: Dict[str, Any] | None = Field(None, description="Task result (if completed)")
    error: str | None = Field(None, description="Error message (if failed)")
    progress: Dict[str, Any] | None = Field(None, description="Progress information")


@app.get("/agent-task/{task_id}/status", response_model=AgentTaskStatusResponse, status_code=200)
async def get_agent_task_status(task_id: str, req: Request):
    """
    Get the current status of an agent task.
    
    This endpoint polls the Celery task state and returns the current status.
    Used by clients that prefer polling over WebSocket streaming.
    
    Args:
        task_id: UUID of the agent task to check
        req: FastAPI Request object for accessing request_id
    
    Returns:
        AgentTaskStatusResponse with task status and result
    
    Raises:
        HTTPException 400: If task_id is invalid format
        HTTPException 404: If task is not found
        HTTPException 500: If status retrieval fails
    """
    request_id = getattr(req.state, 'request_id', 'unknown')
    
    try:
        # Validate task_id is a UUID
        try:
            uuid.UUID(task_id)
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail="Invalid task_id format. Must be a valid UUID."
            )
        
        logger.info(
            f"Checking agent task status: task_id={task_id} request_id={request_id}"
        )
        
        # Get task result from Celery
        from celery.result import AsyncResult
        result = AsyncResult(task_id, app=celery_app)
        
        # Map Celery states to our states
        state_map = {
            'PENDING': 'pending',
            'STARTED': 'processing',
            'PROGRESS': 'processing',
            'SUCCESS': 'completed',
            'FAILURE': 'failed',
            'RETRY': 'processing',
            'REVOKED': 'failed'
        }
        
        status = state_map.get(result.state, result.state.lower())
        
        response_data = {
            "task_id": task_id,
            "status": status,
            "result": None,
            "error": None,
            "progress": None
        }
        
        # Add result or error based on state
        if result.successful():
            response_data["result"] = result.result
        elif result.failed():
            response_data["error"] = str(result.info)
        elif result.state == 'PROGRESS':
            response_data["progress"] = result.info
        
        logger.info(
            f"Agent task status retrieved: task_id={task_id} status={status} request_id={request_id}"
        )
        
        return AgentTaskStatusResponse(**response_data)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            f"Failed to get agent task status: {type(e).__name__} request_id={request_id}",
            exc_info=True
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to retrieve task status: {str(e)}"
        )


@app.get("/agent-task/{task_id}/result")
async def get_agent_task_result(task_id: str, req: Request):
    """
    Get the final result of a completed agent task.
    
    This endpoint retrieves the analysis result from the database after
    the agent task has completed. Used by iOS app to fetch final results.
    
    Args:
        task_id: UUID of the completed agent task
        req: FastAPI Request object
    
    Returns:
        Agent analysis result with risk level, evidence, and reasoning
    
    Raises:
        HTTPException 404: If task not found or not completed
        HTTPException 500: If result retrieval fails
    """
    request_id = getattr(req.state, 'request_id', 'unknown')
    
    try:
        logger.info(f"Fetching agent task result: task_id={task_id} request_id={request_id}")
        
        from app.db.client import get_supabase_client
        supabase = get_supabase_client()
        
        # Query agent_scan_results table
        response = supabase.table('agent_scan_results').select('*').eq(
            'task_id', task_id
        ).maybe_single().execute()
        
        if not response.data:
            raise HTTPException(
                status_code=404,
                detail=f"Agent task result not found: {task_id}"
            )
        
        result = response.data
        
        logger.info(
            f"Agent result retrieved: task_id={task_id} risk={result.get('risk_level')} "
            f"request_id={request_id}"
        )
        
        # Get agent_reasoning from database and use it for both explanation and reasoning
        agent_reasoning = result.get('agent_reasoning', 'Analysis completed')
        
        # Extract category from evidence_summary if available
        evidence_summary = result.get('evidence_summary', {})
        category = 'unknown'
        if isinstance(evidence_summary, dict):
            # Try to infer category from tools_used or evidence
            tools_used = evidence_summary.get('tools_used', [])
            if 'scam_db' in tools_used:
                category = 'scam'
            elif 'domain_reputation' in tools_used:
                category = 'phishing'
        
        return {
            "task_id": result.get('task_id', task_id),
            "risk_level": result.get('risk_level', 'unknown'),
            "confidence": result.get('confidence', 0.0),
            "category": category,
            "explanation": agent_reasoning,  # Use agent_reasoning from DB
            "reasoning": agent_reasoning,     # Use agent_reasoning from DB
            "evidence": result.get('tool_results', []),  # Use tool_results from DB
            "entities_found": result.get('entities_found', {}),
            "tools_used": evidence_summary.get('tools_used', []) if isinstance(evidence_summary, dict) else [],
            "processing_time_ms": result.get('processing_time_ms', 0),
            "completed_at": result.get('created_at')  # Use created_at from DB
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            f"Failed to retrieve agent result: {type(e).__name__} request_id={request_id}",
            exc_info=True
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to retrieve task result: {str(e)}"
        )


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

