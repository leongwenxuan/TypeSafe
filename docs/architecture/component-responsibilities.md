# Component Responsibilities

## 4.1 Keyboard Extension (Swift + UIKit)
- Capture typed text via `UITextDocumentProxy` (ephemeral snippet windows).
- Display inline **risk banners** and **explain** popover.
- Make **HTTPS** calls to backend (when Full Access granted).
- Read/write minimal state via **App Group** (e.g., latest scan verdict).

## 4.2 Companion App (SwiftUI)
- "**Scan My Screen**" entrypoint; receives user-selected screenshot.
- Run **Apple Vision** OCR locally (`VNRecognizeTextRequest`).
- Upload OCR text + (optionally) the image to backend for analysis.
- Show **history** (last 5 results) and settings (privacy, voice).

## 4.3 Backend API (Python FastAPI)
- Endpoints:
  - `POST /analyze-text` → OpenAI text intent classification → risk JSON.
  - `POST /scan-image` → Gemini multimodal + OpenAI text reasoning.
  - `GET  /results/latest?session_id=...` → latest normalized verdict.
- **Risk Aggregator**: normalize provider outputs → `{risk_level, confidence, category, explanation}`.
- Persistence in **Supabase** (short retention, anonymized).

## 4.4 External Services
- **OpenAI**: scam intent, tone heuristics, "explain why" summaries.
- **Gemini**: multimodal screenshot understanding (visual + extracted text).

## 4.5 Data Store (Supabase / Postgres)
- Tables: `scan_results`, `text_analyses`, `sessions`, `settings`.
- Policies: row-level access disabled (backend-only); 7‑day TTL job.

