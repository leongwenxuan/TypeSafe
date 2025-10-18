# 🏗️ TypeSafe – MVP Architecture Document (v1)

**Version:** 1.0  
**Author:** Winston (Architect Agent)  
**Date:** October 2025

---

## 🧩 1. System Overview

**TypeSafe** is an AI-powered iOS keyboard extension and companion app designed to prevent scams in real time by analyzing user-typed text and screenshots.

Two-part system:

1. **Keyboard Extension** — Runs within any app, intercepts typed text, and provides real-time scam analysis feedback.  
2. **Companion App** — Handles screenshots, user settings, and result visualization.

Both connect securely to a **backend AI orchestration layer** for reasoning and analysis.

---

## ⚙️ 2. High-Level Architecture

```
+---------------------------------------------------------------+
|                        TypeSafe System                        |
+---------------------------------------------------------------+
|                     Apple iOS Ecosystem                       |
|                                                               |
|  +-----------------+     +-----------------+     +------------+
|  | Keyboard Ext.   | --> | Companion App   | --> | Backend    |
|  | (Swift + UI)    |     | (Swift + SwiftUI)|    | (Python /  |
|  |                 |     |                 |     | FastAPI)   |
|  +-----------------+     +-----------------+     +------------+
|                                                               |
|             AI / Data Services (3rd Party APIs)               |
|     +------------+   +---------------+   +----------------+   |
|     |  OpenAI    |   |  Gemini API   |   |  Supabase DB   |   |
|     +------------+   +---------------+   +----------------+   |
+---------------------------------------------------------------+
```

---

## 🧠 3. Core Components

| Component | Description | Technologies |
|------------|--------------|--------------|
| **Keyboard Extension** | Captures typed input, sends for scam detection, and displays inline alerts. | Swift, UIKit |
| **Companion App** | Allows screenshot scanning, shows analysis history, and manages settings. | SwiftUI, Vision Framework |
| **Backend (API Server)** | Receives text/screenshot data, calls AI APIs (OpenAI, Gemini), and aggregates results. | FastAPI (Python) |
| **Database** | Stores anonymized results, settings, and model responses. | Supabase (PostgreSQL) |
| **AI Services** | Third-party APIs providing NLP and multimodal analysis. | OpenAI (text), Gemini (image+text) |

---

## 🧭 4. Data Flow Overview

### A. Real-Time Typing Analysis
```
[User typing in keyboard]
     ↓
Keyboard Extension
     ↓
Detects new text → sends to Backend
     ↓
Backend calls OpenAI (intent + scam classification)
     ↓
Result (risk level, explanation)
     ↓
Keyboard displays alert banner ("⚠️ Possible scam detected")
```

### B. Screenshot Scan Flow
```
User → Companion App → "Scan My Screen"
     ↓
iOS Vision Framework (OCR) extracts text
     ↓
Backend receives image + OCR text
     ↓
Gemini analyzes screenshot (visual + text reasoning)
     ↓
Result stored in Supabase
     ↓
Keyboard fetches verdict via App Group container
     ↓
Displays warning if confirmed phishing layout
```

---

## ☁️ 5. Backend Architecture

**Primary Responsibilities**
- Manage all AI API calls.
- Aggregate risk signals.
- Store results in Supabase.
- Serve REST endpoints for both keyboard and app.

**Key Endpoints**

| Endpoint | Purpose |
|-----------|----------|
| `POST /analyze-text` | Accepts text payload, returns scam classification. |
| `POST /scan-image` | Accepts screenshot + OCR text for multimodal detection. |
| `GET /results/latest` | Returns latest risk verdict for keyboard display. |

**Example Response**
```json
{
  "risk_level": "high",
  "confidence": 0.94,
  "category": "OTP phishing",
  "explanation": "Message asks for verification code, typical scam pattern."
}
```

---

## 🧠 6. AI Integration Design

| API | Purpose | Input | Output | Integration Mode |
|------|----------|--------|---------|------------------|
| **OpenAI GPT** | Text intent + scam tone classification | User text snippet | Risk category, reasoning summary | Synchronous REST call |
| **Gemini API** | Multimodal phishing detection (image + text) | Screenshot image + OCR text | Visual + linguistic risk classification | Asynchronous call |
| **Supabase** | Data storage, analytics | Result JSON | Persistent storage + sync | Direct REST + PostgREST |
| **Apple Vision Framework** | Local OCR on device | Screenshot | Text extraction | On-device (no network) |

---

## 🔐 7. Security & Privacy Design

| Area | Implementation | Purpose |
|------|----------------|----------|
| **Data Transmission** | HTTPS with TLS 1.3 | Secure API communication |
| **App–Keyboard Sync** | iOS App Groups | Local secure storage bridge |
| **Data Minimization** | Only send short text snippets (<300 chars) | Reduce exposure |
| **Screenshot Handling** | User-triggered capture only | Apple compliance |
| **Anonymization** | No user IDs, only session hashes | Privacy-first design |
| **Storage Retention** | Auto-delete scans after 7 days | Data hygiene |

---

## 🧱 8. Technology Stack

| Layer | Tech Stack | Reason |
|--------|-------------|--------|
| Frontend | Swift (UIKit, SwiftUI) | Native iOS integration |
| Backend | Python + FastAPI | Lightweight, async API support |
| Database | Supabase (PostgreSQL) | Simple managed backend |
| AI APIs | OpenAI, Gemini | Reliable reasoning and multimodal power |
| OCR | Apple Vision Framework | On-device, privacy-safe |
| Auth & Security | App Group Containers, HTTPS | Secure local + remote flow |

---

## 🔄 9. Deployment Overview

| Environment | Description | Tools |
|--------------|--------------|-------|
| **Development** | Local testing via Xcode simulator + ngrok for API tunnel | Xcode, FastAPI Uvicorn |
| **Staging** | Hosted backend with test API keys | Supabase staging + Render or Vercel |
| **Production** | Hardened backend with monitoring | Supabase Prod + Cloudflare proxy |

**Build Tools**
- Swift Package Manager  
- GitHub Actions (optional CI/CD for backend)  
- API key vault using `.env` secrets

---

## 🔔 10. System Interaction Diagram (Textual)

```
+-----------------------+
|  Keyboard Extension   |
|  - Capture input      |
|  - Display alert      |
+----------+------------+
           |
           | HTTPS / JSON
           v
+-----------------------+
|  Backend API Server   |
|  - Validate request   |
|  - Call OpenAI        |
|  - Aggregate results  |
|  - Store in Supabase  |
+----------+------------+
           |
           | REST / WebSocket (future)
           v
+-----------------------+
|     Supabase DB       |
|  - Risk logs          |
|  - OCR text           |
|  - Confidence history |
+-----------------------+
```

---

## 🧩 11. Scalability Considerations

| Area | v1 Limitation | Future v2 Upgrade |
|-------|----------------|------------------|
| AI API throughput | Sequential calls | ILM orchestration (parallel multi-model) |
| Caching | None | Supabase + Redis cache |
| Response latency | ~2–3 seconds | Parallel execution, model routing |
| Horizontal scaling | Limited | Stateless microservices via ILM |
| Multi-region users | US-centric | Edge caching, CDN distribution |

---

## 🧠 12. Key Architectural Decisions (ADR Summary)

| Decision | Rationale |
|-----------|------------|
| Use Supabase instead of Firebase | Easier SQL access + Postgres functions |
| Keep OCR on-device | Privacy compliance & speed |
| Single backend orchestrator (v1) | Minimize latency; easier to debug |
| No background monitoring | Apple sandbox limitation |
| Modular service separation | Prepares for ILM integration in v2 |

---

## 🔒 13. Compliance & Review Checklist

- [x] Explicit user consent for screenshots  
- [x] No persistent logging of keystrokes  
- [x] No automatic content capture  
- [x] HTTPS enforced for all API calls  
- [x] Anonymized data model (no PII)  
- [x] “Delete my scans” feature available  

---

## 🧩 14. Summary

**TypeSafe v1** implements a clean, privacy-compliant, and scalable foundation for scam prevention:
- **Keyboard → Backend → AI → Feedback loop**
- Real-time text scanning + manual screenshot analysis
- All built atop trusted, composable APIs (OpenAI, Gemini, Supabase).

This architecture is simple enough for hackathon success, yet **forward-compatible** with the ILM system in v2.
