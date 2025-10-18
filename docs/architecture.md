# 🏗️ TypeSafe — Architecture Specification (v1 / MVP)

**Version:** 1.0  
**Date:** October 2025  
**Owner:** Winston (Architect)  

---

## 1) Overview & Goals

TypeSafe v1 is an **iOS keyboard extension** + **companion app** with a lightweight **backend** that performs AI-assisted scam detection on **typed text** and **user-triggered screenshots**.

**Primary goals**
- Real-time text risk detection with clear inline feedback.
- On-device OCR + backend multimodal analysis for screenshots.
- Strict privacy: explicit consent, minimal data, short retention.
- Simplicity suitable for hackathon demo, but forward-compatible with v2 ILM.

**Non-goals (v1)**
- No background monitoring.
- No partner dashboards / sponsor flows.
- No multi-language (English-only).

---

## 2) Key Constraints & Assumptions

- iOS **Keyboard Extension sandbox**: can read what the user types **via our keyboard only**; cannot capture screen.  
- **Screenshots** must be initiated from the **companion app** (user action).  
- **Full Access** required for network calls from the keyboard.  
- **Privacy**: no raw PII storage, anonymized session IDs, 7‑day retention for analysis artifacts.  
- Latency target **< 2s** round trip for text analysis.

---

## 3) High-Level Architecture (Context Diagram)

```
+-------------------- iOS Device --------------------+
|                                                    |
|  [ Any App ]     [ TypeSafe Keyboard ]             |
|     |                 |  send text (snippet)       |
|     |                 v                             |
|     |         +--------------------+                |
|     |         |  Keyboard Client   |                |
|     |         +----------+---------+                |
|     |                    | HTTPS                     |
|     |                    v                          |
|     |         +--------------------+                |
|     |         |  Companion App     |                |
|     |         |  (Scan, Settings)  |                |
|     |         +----------+---------+                |
|     |         (App Group Shared Storage)            |
+------------------------|---------------------------+
                         |
                         | Internet (TLS)
                         v
+------------------------+---------------------------+
|                TypeSafe Backend (FastAPI)          |
|  - /analyze-text   - /scan-image   - /results      |
|  - Risk aggregation & normalization                 |
|        |                  |                        |
|        |                  |                        |
|   OpenAI (Text)      Gemini (Multi-modal)          |
|        |                  |                        |
|                  Supabase (Postgres + Storage)     |
+----------------------------------------------------+
```

---

## 4) Component Responsibilities

### 4.1 Keyboard Extension (Swift + UIKit)
- Capture typed text via `UITextDocumentProxy` (ephemeral snippet windows).
- Display inline **risk banners** and **explain** popover.
- Make **HTTPS** calls to backend (when Full Access granted).
- Read/write minimal state via **App Group** (e.g., latest scan verdict).

### 4.2 Companion App (SwiftUI)
- “**Scan My Screen**” entrypoint; receives user-selected screenshot.
- Run **Apple Vision** OCR locally (`VNRecognizeTextRequest`).
- Upload OCR text + (optionally) the image to backend for analysis.
- Show **history** (last 5 results) and settings (privacy, voice).

### 4.3 Backend API (Python FastAPI)
- Endpoints:
  - `POST /analyze-text` → OpenAI text intent classification → risk JSON.
  - `POST /scan-image` → Gemini multimodal + OpenAI text reasoning.
  - `GET  /results/latest?session_id=...` → latest normalized verdict.
- **Risk Aggregator**: normalize provider outputs → `{risk_level, confidence, category, explanation}`.
- Persistence in **Supabase** (short retention, anonymized).

### 4.4 External Services
- **OpenAI**: scam intent, tone heuristics, “explain why” summaries.
- **Gemini**: multimodal screenshot understanding (visual + extracted text).

### 4.5 Data Store (Supabase / Postgres)
- Tables: `scan_results`, `text_analyses`, `sessions`, `settings`.
- Policies: row-level access disabled (backend-only); 7‑day TTL job.

---

## 5) Data Flows

### 5.1 Text Analysis (real-time)
1. Keyboard batches the last N chars (e.g., up to 300).  
2. `POST /analyze-text` with anonymized `session_id`.  
3. Backend → OpenAI; produce risk + reason.  
4. Backend stores normalized result; returns JSON.  
5. Keyboard shows banner if `risk_level ∈ {medium, high}`.

**Request**
```http
POST /analyze-text
{ "session_id":"anon-uuid", "app_bundle":"com.whatsapp", "text":"send me your OTP" }
```
**Response**
```json
{ "risk_level":"high","confidence":0.93,"category":"otp_phishing","explanation":"Asking for OTP." }
```

### 5.2 Screenshot Scan (user-initiated)
1. Companion app receives screenshot; runs **Vision OCR** locally.  
2. `POST /scan-image` with OCR text + (optional) image.  
3. Backend → Gemini (image+text) + OpenAI (text) → aggregate.  
4. Persist in Supabase; return verdict; write a small **App Group** flag for keyboard.  
5. Keyboard polls shared storage; displays confirmation banner.

---

## 6) Public API (Backend)

### 6.1 `POST /analyze-text`
- **Body**: `{ session_id, app_bundle, text }`
- **Returns**: `{ risk_level, confidence, category, explanation }`
- **Errors**: `400` invalid input, `429` rate limit, `500` provider error

### 6.2 `POST /scan-image`
- **Body**: multipart with `{ session_id, ocr_text, image? }`
- **Returns**: `{ risk_level, confidence, category, explanation }`

### 6.3 `GET /results/latest?session_id=...`
- **Returns**: most recent normalized result for the session.

**Common response schema**
```json
{
  "risk_level": "low|medium|high",
  "confidence": 0.0,
  "category": "otp_phishing|payment_scam|impersonation|unknown",
  "explanation": "human-friendly one-liner",
  "ts": "2025-10-18T02:30:00Z"
}
```

---

## 7) Data Model (Supabase / Postgres)

```sql
create table sessions (
  session_id uuid primary key,
  created_at timestamptz default now()
);

create table text_analyses (
  id bigserial primary key,
  session_id uuid references sessions(session_id),
  app_bundle text,
  snippet text,
  risk_level text check (risk_level in ('low','medium','high')),
  confidence numeric,
  category text,
  explanation text,
  created_at timestamptz default now()
);

create table scan_results (
  id bigserial primary key,
  session_id uuid references sessions(session_id),
  ocr_text text,
  risk_level text,
  confidence numeric,
  category text,
  explanation text,
  created_at timestamptz default now()
);
```

**Retention**
```sql
-- daily job: delete older than 7 days
delete from text_analyses where created_at < now() - interval '7 days';
delete from scan_results where created_at < now() - interval '7 days';
```

---

## 8) Security & Privacy

- **Transport**: HTTPS (TLS 1.3), HSTS on backend.  
- **Auth**: Backend API-key from the app; rotate keys via secrets manager.  
- **Minimization**: send only small text snippets; screenshots optional.  
- **Anonymization**: `session_id` = random UUID, no PII.  
- **Local-first**: OCR on-device; screenshot upload is opt-in.  
- **App Group**: secure shared container for keyboard↔app flags only.  
- **Compliance**: App Store privacy manifest; easy “Delete my data” action.

---

## 9) Performance & Capacity

- **Targets**: `<2s` p95 for `/analyze-text`; `<3.5s` for `/scan-image`.  
- **Concurrency**: 50 rps burst (hackathon scale).  
- **Caching**: short-lived in-memory cache for identical text checks.  
- **Resilience**: timeouts 1.5s per provider; graceful degradation to local rules if providers fail.

---

## 10) Deployment & Environments

| Env | Purpose | Notes |
|-----|--------|-------|
| **Local** | Dev iteration | Uvicorn + ngrok for device testing |
| **Staging** | Pre-demo | Test API keys, Supabase staging |
| **Prod (Demo)** | Live demo | Cloud host (Render/Vercel) + Cloudflare proxy |

- Infra as simple code: Dockerfile for FastAPI service.  
- Logs & metrics: basic request logs; Supabase query stats.

---

## 11) Observability & Testing

- **Logging**: request ID, latency, provider outcome (no payloads).  
- **Metrics**: risk distribution, FP/FN counters (labelled examples).  
- **Synthetic tests**: seeded prompts for OTP, payment scams, impersonation.  
- **iOS UI tests**: keyboard banner visibility, app scan flow e2e.

---

## 12) Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| App Review privacy concerns | Explicit consent flows; no background capture |
| Provider latency | Parallelize calls; aggressive timeouts + fallback |
| False positives | Tunable thresholds; explainability; dismiss affordance |
| Data exposure | Minimize payloads; 7‑day TTL; encrypted transit |
| Keyboard instability | Keep memory footprint low; avoid heavy sync |

---

## 13) ADR Snapshot (Architecture Decision Records)

- **ADR-001**: Use **Supabase** (Postgres) over Firebase → SQL + ease of use.  
- **ADR-002**: Keep **OCR on-device** via Vision → privacy + speed.  
- **ADR-003**: **Single backend** with provider calls in-process (no queue) for v1 → simplicity.  
- **ADR-004**: No WebSockets for v1; keyboard polls App Group flag → iOS-safe + simpler.  
- **ADR-005**: Normalize provider outputs into a **unified risk schema**.

---

## 14) Future Hooks (v2 Readiness)

- Replace in-process provider calls with an **ILM orchestration layer**.  
- Add URL reputation & entity extraction tools.  
- Introduce Redis cache + background threat feed sync.  
- WebSocket push for faster keyboard updates.

---

## 15) Appendix — Example Swift Pseudocode

```swift
// Keyboard → analyze text
func analyze(snippet: String) {
  let body = ["session_id": sessionId, "app_bundle": currentBundle, "text": snippet]
  postJSON("/analyze-text", body) { result in
    if result.risk_level != "low" { showBanner(result) }
  }
}
```

```swift
// App → OCR + scan image
func scan(image: UIImage) {
  let ocrText = runVisionOCR(image)
  uploadMultipart("/scan-image", fields: ["session_id": sessionId, "ocr_text": ocrText], file: image)
}
```

---

**End — TypeSafe Architecture Spec (v1)**
