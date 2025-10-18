# Epic 1: Backend API & Infrastructure

**Epic ID:** 1  
**Epic Title:** Backend API & Infrastructure  
**Priority:** P0 (Critical - Foundation for all features)  
**Timeline:** Week 1  
**Dependencies:** None (foundational epic)

---

## Epic Goal

Establish the TypeSafe backend infrastructure with FastAPI, integrate AI providers (OpenAI & Gemini), set up Supabase for data persistence, and expose REST API endpoints for text and image scam analysis.

---

## Epic Description

This epic delivers the foundational backend services required for TypeSafe's scam detection capabilities. It includes setting up the FastAPI server, integrating with OpenAI for text analysis and Gemini for multimodal screenshot analysis, configuring Supabase for storing scan results, and implementing the core risk aggregation logic that normalizes provider outputs into a unified risk schema.

---

## User Stories

### Story 1.1: Backend Service Setup & Configuration

**As a** developer,  
**I want** a FastAPI backend service with proper configuration management,  
**so that** we have a secure, maintainable foundation for our API endpoints.

**Acceptance Criteria:**
1. FastAPI application runs locally with uvicorn
2. Environment variable configuration for API keys (OpenAI, Gemini, Supabase)
3. Basic request/response logging configured
4. CORS configured for iOS app integration
5. Health check endpoint (`/health`) returns service status
6. HTTPS/TLS configuration ready for deployment

**Priority:** P0

---

### Story 1.2: Supabase Database Setup & Schema

**As a** developer,  
**I want** Supabase configured with proper database schemas,  
**so that** we can persist scan results and session data securely.

**Acceptance Criteria:**
1. Supabase project created and connected to backend
2. `sessions` table created with session_id (UUID) and timestamps
3. `text_analyses` table created with all required fields (session_id, snippet, risk_level, confidence, category, explanation, timestamps)
4. `scan_results` table created with OCR text and analysis results
5. 7-day retention policy configured (automated cleanup job)
6. Backend can successfully read/write to all tables
7. Row-level security disabled (backend-only access) and configured

**Priority:** P0

---

### Story 1.3: OpenAI Integration for Text Analysis

**As a** developer,  
**I want** OpenAI API integrated for scam intent detection,  
**so that** we can analyze typed text for potential scam patterns.

**Acceptance Criteria:**
1. OpenAI client library configured with API key
2. Prompt engineering for scam detection (OTP phishing, payment scams, impersonation)
3. Text analysis function returns risk_level (low/medium/high), confidence, category, and explanation
4. Timeout configured (1.5s) with graceful error handling
5. Response caching for identical text snippets (in-memory, short-lived)
6. Unit tests for OpenAI integration with mock responses

**Priority:** P0

---

### Story 1.4: Gemini Integration for Multimodal Analysis

**As a** developer,  
**I want** Gemini API integrated for screenshot analysis,  
**so that** we can detect scams in images with both visual and text context.

**Acceptance Criteria:**
1. Gemini client library configured with API key
2. Multimodal prompt accepts both image data and OCR text
3. Image analysis returns risk assessment consistent with unified schema
4. Timeout configured (1.5s) with graceful error handling
5. Support for common image formats (PNG, JPEG)
6. Unit tests for Gemini integration with mock responses

**Priority:** P0

---

### Story 1.5: Risk Aggregation & Normalization

**As a** developer,  
**I want** a risk aggregator that normalizes AI provider outputs,  
**so that** we return consistent risk assessments regardless of provider.

**Acceptance Criteria:**
1. Risk aggregator function accepts provider-specific outputs
2. Normalizes to unified schema: `{risk_level, confidence, category, explanation, timestamp}`
3. Risk categories: `otp_phishing`, `payment_scam`, `impersonation`, `unknown`
4. Confidence scores normalized to 0.0-1.0 range
5. Explanation text is human-friendly and concise (one-liner)
6. Unit tests verify normalization for various provider responses

**Priority:** P0

---

### Story 1.6: POST /analyze-text API Endpoint

**As a** keyboard extension,  
**I want** an API endpoint to analyze text snippets,  
**so that** I can get real-time scam detection results while users type.

**Acceptance Criteria:**
1. `POST /analyze-text` endpoint accepts `{session_id, app_bundle, text}`
2. Calls OpenAI integration with text snippet
3. Stores result in `text_analyses` table with session tracking
4. Returns normalized risk assessment JSON
5. Response time < 2s (p95)
6. Proper error responses: 400 (invalid input), 429 (rate limit), 500 (provider error)
7. Integration tests verify end-to-end flow

**Priority:** P0

---

### Story 1.7: POST /scan-image API Endpoint

**As a** companion app,  
**I want** an API endpoint to analyze screenshots with OCR text,  
**so that** users can scan suspicious messages for scam detection.

**Acceptance Criteria:**
1. `POST /scan-image` endpoint accepts multipart form with `{session_id, ocr_text, image?}`
2. Calls Gemini integration with image and/or OCR text
3. Optionally calls OpenAI for text-only analysis if image fails
4. Aggregates results if multiple providers used
5. Stores result in `scan_results` table
6. Returns normalized risk assessment JSON
7. Response time < 3.5s (p95)
8. Integration tests verify end-to-end flow

**Priority:** P0

---

### Story 1.8: GET /results/latest API Endpoint

**As a** keyboard extension,  
**I want** an API endpoint to retrieve the latest scan result,  
**so that** I can display recent screenshot analysis results in the keyboard.

**Acceptance Criteria:**
1. `GET /results/latest?session_id=...` endpoint retrieves most recent result
2. Queries both `text_analyses` and `scan_results` tables
3. Returns the latest result by timestamp
4. Returns 404 if no results found for session
5. Response time < 500ms
6. Integration tests verify retrieval logic

**Priority:** P1

---

## Technical Dependencies

**External Services:**
- OpenAI API (GPT-4 or GPT-3.5-turbo)
- Google Gemini API
- Supabase (Postgres + hosted backend)

**Infrastructure:**
- Python 3.11+
- FastAPI framework
- Uvicorn ASGI server
- Environment configuration (.env)

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|---------|------------|
| **Provider API latency** | Medium | Aggressive timeouts (1.5s); parallel calls where possible |
| **API key exposure** | High | Environment variables; secrets manager; never commit keys |
| **Rate limiting from providers** | Medium | Implement request caching; retry logic with backoff |
| **Database connection issues** | High | Connection pooling; health checks; graceful degradation |

---

## Definition of Done

- [ ] All 8 stories completed with acceptance criteria met
- [ ] Backend runs locally and responds to all API endpoints
- [ ] OpenAI and Gemini integrations tested with real API keys
- [ ] Supabase tables created and backend can read/write successfully
- [ ] Integration tests pass for all endpoints
- [ ] Backend deployed to staging environment (optional for MVP)
- [ ] API documentation generated (Swagger/OpenAPI)

---

## Notes

This epic is the foundation for all TypeSafe features. Stories should be completed sequentially (1.1 → 1.2 → ... → 1.8) as each builds on previous infrastructure.

**Estimated Timeline:** Week 1 (5-7 days of focused development)

