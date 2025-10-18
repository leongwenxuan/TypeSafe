# 📘 TypeSafe Product Requirements Document (PRD) — v1 (MVP)

**Version:** 1.0  
**Date:** October 2025  
**Owner:** Daniel Leong  
**Contributors:** Mary (Analyst), Sarah (Product Owner), Winston (Architect)  

---

## 1. Overview

**TypeSafe** is an AI-powered **iOS keyboard extension** and **companion app** designed to prevent users from falling for scams while they type, paste, or share messages.  

The product detects scam-like intent, suspicious URLs, or phishing messages in real time, and provides friendly in-keyboard alerts or explanations — while maintaining strict privacy compliance.

---

## 2. Problem Statement

Users are frequently targeted by social engineering scams through text, chat, or messaging apps.  
Current mobile protections are reactive (post-report), not proactive.  

**TypeSafe’s opportunity:**  
Enable **real-time scam prevention** at the **point of typing**, by providing an intelligent, privacy-respectful keyboard layer.

---

## 3. Objectives & Key Results (KR)

| Objective | Key Result |
|------------|------------|
| **Detect scam intent early** | ≥ 90 % accuracy for scam-like text detection |
| **Build user trust** | ≥ 80 % of users rate alerts as “helpful” |
| **Preserve privacy** | 100 % compliance with Apple App Store policies |
| **Demonstrate feasibility** | Working end-to-end demo (text + screenshot analysis) by launch |

---

## 4. Target Users & Use Cases

| User Type | Scenario | Goal |
|------------|-----------|------|
| **General user** | Typing or pasting unknown messages | Get instant scam alert |
| **Concerned user** | Receives suspicious WhatsApp/SMS screenshot | Scan and verify authenticity |
| **Early adopter / tester** | Uses keyboard daily | Experience privacy-safe AI assistant |
| **Hackathon jury** | Evaluates prototype | See real-time detection with simple UX |

---

## 5. Scope (What’s Included)

✅ **In Scope**
- Text-based scam detection while typing  
- Screenshot scanning via companion app  
- Inline warning banners (⚠️ Possible Scam Detected)  
- Short explanation popovers (“Looks like an OTP request”)  
- Voice alert toggle for accessibility  
- Local OCR (Vision Framework) + AI analysis (OpenAI / Gemini)  
- Secure Supabase backend for result storage  

❌ **Out of Scope**
- Background message monitoring  
- Continuous screen recording  
- Multi-language support (English only for MVP)  
- Partner integrations or sponsor dashboards  

---

## 6. Core Features (Functional Requirements)

| Feature | Description | Priority |
|----------|--------------|----------|
| **Real-Time Scam Detection** | Keyboard captures typed text and sends small snippets to backend → OpenAI GPT returns risk level + reason | P0 |
| **Inline Alerts** | Yellow/red banners above keyboard; optional vibration feedback | P0 |
| **Explain Why** | Tap banner → AI-generated explanation (“This resembles a payment scam”) | P1 |
| **Screenshot Scan** | Companion app button → capture screen → OCR → Gemini analysis | P0 |
| **Voice Alerts** | Optional spoken warning via ElevenLabs API | P2 |
| **Scan History** | Show last 5 scans with risk level and timestamp | P1 |
| **Privacy Controls** | Manual “Full Access” toggle, “Delete all data” button | P0 |

---

## 7. User Flow Summary

### A. Typing Flow
1. User types a message in any app using TypeSafe keyboard.  
2. Keyboard intercepts text → calls `/analyze-text` API.  
3. Backend (FastAPI + OpenAI) returns risk score + reason.  
4. Keyboard displays ⚠️ banner if risk > threshold.  
5. User can tap → see short explanation.

### B. Screenshot Flow
1. User opens TypeSafe app → taps “Scan My Screen”.  
2. App captures screenshot → runs Vision OCR → sends image + text to backend.  
3. Backend uses Gemini API for visual + text analysis.  
4. Result displayed with confidence and reason; stored in Supabase.  
5. Keyboard retrieves latest result and displays if relevant.

---

## 8. Design Principles & UX Intent

| Principle | Description |
|------------|-------------|
| **Minimal Interruption** | Alerts appear like predictive text; never block typing |
| **Calm Visual Language** | Blue → Amber → Red gradient for risk state |
| **Explain Don’t Scare** | Plain, empathetic language (“This might be unsafe”) |
| **Accessibility** | Optional audio alerts + voice-over readouts |
| **Privacy First** | Manual triggers, local OCR, no PII storage |

---

## 9. Dependencies

| Dependency | Role |
|-------------|------|
| **OpenAI API** | Text reasoning & intent classification |
| **Gemini API** | Multimodal image + text scam detection |
| **Supabase** | Backend storage and result sync |
| **Apple Vision Framework** | Local OCR processing |
| **ElevenLabs** | Optional voice output |

---

## 10. Non-Functional Requirements

| Area | Requirement |
|-------|--------------|
| **Performance** | Response < 2 seconds per scan |
| **Uptime** | Backend ≥ 99 % |
| **Data Retention** | Auto-delete after 7 days |
| **Security** | HTTPS + TLS 1.3 + anonymized session IDs |
| **Scalability** | Single tenant MVP; ready for multi-region scale in v2 |

---

## 11. Risks & Mitigation

| Risk | Impact | Mitigation |
|------|---------|-------------|
| **Apple Privacy Review Rejection** | 🚨 High | Explicit user consent; no background capture |
| **False Positives** | ⚠️ Medium | Rule threshold + manual review mode |
| **Latency / Model Delay** | ⚠️ Medium | Parallel API calls (OpenAI + Gemini async) |
| **Limited Dataset** | ⚠️ Medium | Manually curated examples for fine-tuning |
| **User Overload** | ⚠️ Low | Friendly copy + clear dismiss actions |

---

## 12. Success Metrics / Acceptance Criteria

| Category | Metric / Threshold |
|-----------|------------------|
| **Functional** | 90 % accuracy on known scam examples |
| **Performance** | < 2 s end-to-end latency |
| **UX Trust** | ≥ 80 % positive feedback |
| **Stability** | ≤ 1 crash per 1 000 sessions |
| **Privacy** | No user data leak or retention breach |

---

## 13. Milestones / Timeline

| Week | Deliverable |
|------|--------------|
| **1** | MVP architecture + API integration |
| **2** | Keyboard extension alert demo |
| **3** | Screenshot scanner + OCR pipeline |
| **4** | Final UX + voice alert (optional) |

---

## 14. Approval & Next Steps

**MVP Goal:**  
Deliver a working demo showing text + screenshot scam detection with inline alerts and clear explanations.

**Next Steps:**  
- UX prototype → Apple review-safe design  
- Finalize API keys & infrastructure  
- Conduct pilot with 5–10 beta users  
- Gather metrics for v2 ILM upgrade  

---

**End of Document — TypeSafe PRD v1**  
