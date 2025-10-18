# 🧠 TypeSafe Product & Architecture Brainstorm  
### *Structured Technical Design Document (v1 → v2)*  

---

## 📘 Overview

**TypeSafe** is an AI-powered iOS keyboard extension and companion app designed to **prevent scam messages** by analyzing user-typed text and screenshots.  
It combines **real-time language intelligence**, **image-based phishing detection**, and **clear user feedback** — all while maintaining strict privacy compliance.

---

## 🏗️ Architecture Layers

| Layer | Description |
|--------|--------------|
| **Keyboard Extension** | Provides real-time scam detection and inline warnings while the user types. |
| **Companion App** | Hosts permissions, manages screenshot scanning, and displays results. |
| **Backend + AI Stack** | Handles reasoning, OCR, and multimodal analysis using OpenAI, Gemini, and Supabase. |
| **ILM Layer (v2)** | Intelligent Logic & Mediation layer that orchestrates modular “tools” for reasoning, scanning, and verification. |

---

## 🎯 MVP (Version 1) Objective

> Build a working iOS keyboard that detects and explains scam messages typed or pasted by the user,  
> and allows screenshot scanning for scam content — backed by AI reasoning and clear user feedback.

---

## 🚀 Version 1 – MVP Feature Stack

| Category | Feature | Technology | Goal |
|-----------|----------|-------------|------|
| **Text Scam Detection** | Real-time scam intent detection | OpenAI GPT API | Detect language patterns and scam phrasing |
| **Screenshot Scanning** | Manual “Scan My Screen” feature | Apple Vision OCR + Gemini API | Multimodal scam detection |
| **Explain Why** | Quick explanation popover | OpenAI summarization | Builds trust and user understanding |
| **Storage + Sync** | Risk results and settings | Supabase | Lightweight backend and sync layer |
| **Voice Alerts (Optional)** | Spoken warning phrases | ElevenLabs API | Adds accessible, emotional alerts |
| **Privacy & Permissions** | Full access + screenshot consent | Apple Privacy Manifest | App Store compliance |

---

## 🎨 UI / UX Design Summary

### **Keyboard Extension**
- Inline warning banners with emojis (⚠️, 🚨, ✅)
- Tap-to-expand “Explain Why” mini sheet
- Suggestion bar repurposed for alert cards
- Minimal and non-intrusive

### **Companion App**
- **Home Tab:** “Scan My Screen” button + recent scans  
- **Insights Tab:** Scan history, risk trends  
- **Learn Tab:** Static safety guides (no gamification)  
- **Settings Tab:** Permissions, voice toggle, privacy controls  

**Design Style:**  
Soft gradients, blue/amber/red risk colors, SF Rounded font, minimalist Apple-native aesthetic.

---

## 🖼️ Screenshot Feature (MVP Flow)

**Problem:**  
Users often *receive* scams (screenshots, fake messages). TypeSafe lets them scan these visually.

**Flow:**
1. User taps **“Scan Screen”** in the companion app.  
2. Screenshot captured → processed with **Vision OCR**.  
3. Extracted text + image sent to backend → analyzed with **Gemini** and **OpenAI**.  
4. Backend returns:
   ```json
   {
     "risk_level": "high",
     "category": "phishing",
     "confidence": 0.93,
     "explanation": "Screenshot mimics SingPost phishing template."
   }
   ```
5. Result shown in app + synced to keyboard.

**Privacy:**  
- Screenshot only uploaded after explicit tap.  
- OCR done locally when possible.  
- All user data anonymized.

---

## 🧭 Feature Matrix — v1 vs v2

| Category | **v1 – MVP (Now)** | **v2 – Evolution (ILM + Tool-Calling)** | 🎯 Goal |
|-----------|--------------------|------------------------------------------|--------|
| **Text Scam Detection** | OpenAI GPT classification | Multi-model orchestration (OpenAI + Anthropic + Gemini) | Higher accuracy |
| **Screenshot Scanning** | Manual OCR + Gemini | Automated pipeline (OCR + threat lookup + visual reasoning) | Tool-chaining |
| **Risk Aggregation** | Single score | Multi-tool weighted aggregation | Smarter detection |
| **Explainability** | One-line reason | Structured multi-layer reasoning | Transparency |
| **Voice Alerts** | Static | Contextual, multilingual | Accessibility |
| **Storage** | Supabase | Supabase + Redis for state caching | Scale |
| **Settings** | Manual toggles | ILM developer config panel | Dynamic control |
| **Privacy** | Consent-only data sharing | Tool sandboxing (context isolation) | Compliance |
| **UI/UX** | Minimal banners | Animated adaptive alerts | User clarity |

---

## 🧠 Intelligent Logic & Mediation (ILM) Layer — v2 Core Concept

**Purpose:**  
The ILM layer is a *modular reasoning engine* that orchestrates multiple AI models and tools.  
It dynamically calls specific APIs (tools) depending on the input type, context, or model response.

### **Responsibilities**
1. **Tool Invocation** — Dynamically call tools (e.g., OCR, URL check, explanation).  
2. **Model Routing** — Decide which LLM or vision model to use.  
3. **Aggregation** — Merge tool outputs into a unified risk verdict.  
4. **Explainability** — Return human-readable justification.  
5. **Privacy Mediation** — Ensure tools receive only necessary data.

---

## 🧩 ILM Tool Registry Example

```json
{
  "tools": {
    "intent_classifier": {
      "type": "llm",
      "provider": "openai",
      "input": "text",
      "output": "intent_score"
    },
    "ocr_extractor": {
      "type": "vision",
      "provider": "groq",
      "input": "image",
      "output": "text"
    },
    "url_reputation": {
      "type": "http",
      "provider": "exa",
      "input": "url",
      "output": "risk_label"
    },
    "risk_aggregator": {
      "type": "core",
      "provider": "local",
      "input": "multi",
      "output": "risk_summary"
    }
  }
}
```

---

## 🧮 Tool-Calling Prioritization Matrix (v2)

| Tool | Description | Impact | Effort | Priority | Notes |
|-------|-------------|---------|---------|-----------|-------|
| **Intent Classifier** | Text scam intent detection | ⭐⭐⭐⭐ | ⭐⭐ | 🔥 Immediate | OpenAI/Anthropic |
| **OCR Extractor** | Screenshot text extraction | ⭐⭐⭐⭐ | ⭐ | 🔥 Immediate | Apple Vision or Groq |
| **Risk Aggregator** | Combines tool results | ⭐⭐⭐⭐⭐ | ⭐⭐ | 🔥 Immediate | ILM core |
| **Policy Enforcer** | Maps risk to UI action | ⭐⭐⭐⭐ | ⭐⭐ | 🔥 Immediate | Connects ILM → UI |
| **Explainability Generator** | “Why flagged” summary | ⭐⭐⭐ | ⭐ | 🔥 Immediate | User trust |
| **URL Reputation Checker** | URL fraud lookup | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⚙️ Next | Exa or Prime Intellect |
| **Visual Phishing Detector** | Detects fake layouts | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⚙️ Next | Gemini multimodal |
| **Entity Extractor** | Names, brands, phone parsing | ⭐⭐⭐ | ⭐⭐ | ⚙️ Next | Local model |
| **Threat Feed Sync** | Pulls fresh scam lists | ⭐⭐⭐ | ⭐⭐ | ⚙️ Next | Background update |
| **Voice Alert Generator** | Contextual TTS alerts | ⭐⭐ | ⭐⭐ | 🎵 Optional | ElevenLabs |
| **Knowledge Graph Mapper** | Scam cluster linking | ⭐⭐⭐ | ⭐⭐⭐⭐ | 🧠 Later | Prime Intellect |

---

## 🧩 Phase Rollout Plan

| Phase | Focus | Tools | Deliverable |
|-------|--------|--------|--------------|
| **v2 Core (ILM Build)** | Create orchestrator & tool registry | Intent Classifier, Risk Aggregator, Policy Enforcer, OCR Extractor | Replace static APIs with modular tools |
| **v2.1 (Expanded Intelligence)** | Add multi-tool capability | URL Reputation, Visual Detector | Hybrid text + image detection |
| **v2.2 (External Intelligence)** | Connect external threat feeds | Entity Extractor, Threat Sync | Real-world context awareness |
| **v2.3 (UX Evolution)** | Add personalization and TTS | Voice Generator, ILM settings panel | More adaptive experience |

---

## ⚙️ Tool Design Principles

| Principle | Description |
|------------|-------------|
| **Stateless** | Each tool performs one small, testable function |
| **Context Minimization** | Only pass necessary info (no raw user data) |
| **Parallel Execution** | Run OCR + URL checks concurrently |
| **Composable Results** | Return structured JSON → aggregate easily |
| **Declarative Routing** | ILM decides based on data type or LLM hint |
| **Explainability by Design** | Every verdict shows which tools fired |

---

## ✅ v2 Deliverables Summary

| Deliverable | Description |
|--------------|-------------|
| 🧠 ILM Core Orchestrator | Manages tool invocation, routing, and aggregation |
| 🧩 Tool Registry | JSON-configured tool definitions |
| ⚙️ Modular Tools | OCR, Intent Classifier, Risk Aggregator, Explain Generator |
| 🧾 Unified Risk Schema | Standardized JSON result for UI/keyboard |
| 🔐 Privacy Sandbox | Redaction layer before tool calls |
| 🧭 Developer Config Panel | Toggle tools, view performance metrics |

---

## 🪄 Design Direction Recap

- **Tone:** Helpful, calm, trustworthy — never alarmist.  
- **Colors:**  
  - 🟢 Safe = #29C773  
  - 🟡 Caution = #FFC300  
  - 🔴 Danger = #FF3B30  
- **Typography:** SF Pro Rounded / Medium for titles.  
- **Animations:** Smooth fades for alerts, haptic feedback on warning.  

---

## 🔒 Privacy by Design Summary

| Rule | Implementation |
|------|----------------|
| **Explicit consent** | All analysis triggered by typing or manual tap |
| **Minimal data** | Only snippets or OCR text sent to backend |
| **Local OCR** | Vision API runs on-device first |
| **App Group Storage** | Secure keyboard–app data bridge |
| **Deletion controls** | “Clear all scans” option in Settings |

---

## 📈 Strategic Roadmap Snapshot

| Version | Core Milestone | Focus |
|----------|----------------|--------|
| **v1 (Hackathon)** | Real-time text & screenshot scan | Demonstrate prevention & clarity |
| **v1.5** | Stable API integration + Supabase storage | Backend reliability |
| **v2 (ILM Launch)** | Modular tool orchestration layer | Multi-tool intelligence |
| **v2.1+** | Real-time orchestration tuning | Smarter + faster responses |

---

## 🧩 TL;DR

**v1:**  
> Simple, clear, working keyboard with text + screenshot scam detection (OpenAI + Gemini + Supabase).  

**v2:**  
> Agentic, tool-calling system with ILM orchestrator. Modular, extensible, and intelligent — ready for multiple API integrations and adaptive behavior.
