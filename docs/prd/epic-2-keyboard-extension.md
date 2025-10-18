# Epic 2: Keyboard Extension & Real-Time Detection

**Epic ID:** 2  
**Epic Title:** Keyboard Extension & Real-Time Detection  
**Priority:** P0 (Critical - Core Feature)  
**Timeline:** Week 2  
**Dependencies:** Epic 1 (Backend API must be functional)

---

## Epic Goal

Build the TypeSafe custom keyboard extension that captures typed text, performs real-time scam detection via backend API calls, and displays inline alerts with explanations directly in the keyboard interface.

---

## Epic Description

This epic delivers the primary user-facing feature of TypeSafe: a custom iOS keyboard that intercepts typed text, sends snippets to the backend for AI analysis, and displays warning banners when potential scams are detected. Users can tap alerts to see detailed explanations, all within the keyboard interface without disrupting their typing flow.

---

## User Stories

### Story 2.1: Keyboard Extension Target & Basic Setup

**As a** developer,  
**I want** a keyboard extension target in the Xcode project,  
**so that** I can build a custom iOS keyboard for TypeSafe.

**Acceptance Criteria:**
1. Keyboard extension target created in Xcode project
2. `Info.plist` configured with keyboard extension settings
3. Basic `KeyboardViewController` subclass created
4. App Group configured for data sharing between app and keyboard
5. Keyboard extension compiles and can be enabled in iOS Settings
6. Basic keyboard UI displays with standard QWERTY layout
7. Keyboard can insert text into any text field

**Priority:** P0

---

### Story 2.2: Text Capture & Snippet Management

**As a** keyboard extension,  
**I want** to capture typed text in manageable snippets,  
**so that** I can send appropriate context to the backend for analysis.

**Acceptance Criteria:**
1. Text captured via `UITextDocumentProxy` as user types
2. Maintains sliding window of last 300 characters
3. Triggers analysis after significant typing (e.g., space, punctuation, or every 50 chars)
4. Avoids sending password field content (detect secure text entry)
5. Memory-efficient text buffer (no leak over time)
6. Unit tests verify snippet windowing logic

**Priority:** P0

---

### Story 2.3: Backend API Integration (Analyze Text)

**As a** keyboard extension,  
**I want** to call the backend `/analyze-text` endpoint with text snippets,  
**so that** I can receive real-time scam detection results.

**Acceptance Criteria:**
1. HTTPS client configured for backend API calls
2. Keyboard sends `POST /analyze-text` with `{session_id, app_bundle, text}`
3. Session ID generated and persisted (anonymous UUID)
4. Current app bundle ID captured from `UITextDocumentProxy`
5. API calls made asynchronously (non-blocking)
6. Request timeout set to 2.5s
7. Network errors handled gracefully (silent failure, no user disruption)
8. Full Access permission enforced (prompt user if disabled)

**Priority:** P0

---

### Story 2.4: Inline Risk Alert Banners

**As a** keyboard user,  
**I want** visual alerts displayed above the keyboard when scams are detected,  
**so that** I'm warned in real-time without leaving my current app.

**Acceptance Criteria:**
1. Alert banner view created above keyboard input area
2. Banner displays when risk_level is `medium` or `high`
3. Color-coded: Amber for medium risk, Red for high risk
4. Shows icon (⚠️) and brief message ("Possible Scam Detected")
5. Banner auto-dismisses after 10 seconds or on user dismiss
6. Does not block keyboard typing (user can continue typing)
7. Optional vibration feedback on high-risk detection (Haptics API)

**Priority:** P0

---

### Story 2.5: "Explain Why" Popover Detail

**As a** keyboard user,  
**I want** to tap the alert banner to see why text was flagged,  
**so that** I understand the specific scam pattern detected.

**Acceptance Criteria:**
1. Tapping alert banner opens detail popover/card
2. Popover displays:
   - Risk level (Medium/High)
   - Category (e.g., "OTP Phishing", "Payment Scam")
   - AI-generated explanation (one-liner from backend)
3. Popover has "Got It" dismiss button
4. Popover dismisses on tapping outside or explicit close
5. Accessible via VoiceOver (explanation read aloud)

**Priority:** P1

---

### Story 2.6: App Group Shared State

**As a** keyboard extension,  
**I want** to share minimal state with the companion app via App Group,  
**so that** I can access latest screenshot scan results and sync settings.

**Acceptance Criteria:**
1. App Group identifier configured (`group.com.typesafe.shared`)
2. Shared `UserDefaults` suite created for App Group
3. Keyboard reads latest scan result flag from shared storage
4. Keyboard writes last analysis timestamp to shared storage
5. Settings (e.g., alert preferences) synced via App Group
6. Data stored is minimal and privacy-safe (no raw text)

**Priority:** P1

---

### Story 2.7: Privacy & Full Access Handling

**As a** keyboard user,  
**I want** clear prompts about Full Access and privacy,  
**so that** I understand what permissions are needed and why.

**Acceptance Criteria:**
1. Keyboard detects if Full Access is disabled
2. Displays in-keyboard message: "Enable Full Access to detect scams in real-time"
3. Link to Settings provided (if possible via keyboard UI)
4. When Full Access is disabled, keyboard functions as basic keyboard (no API calls)
5. Privacy message explains: "TypeSafe only analyzes text for scam detection, not stored"
6. Keyboard respects secure text entry fields (no analysis for passwords)

**Priority:** P0

---

### Story 2.8: Keyboard Performance & Stability

**As a** keyboard user,  
**I want** the keyboard to be responsive and stable,  
**so that** my typing experience is not degraded.

**Acceptance Criteria:**
1. Keyboard input latency < 100ms (key press to character insertion)
2. Memory footprint < 30MB during normal operation
3. No memory leaks over extended typing sessions (Instruments validation)
4. API calls do not block UI thread
5. Graceful degradation if backend is unreachable (silent failure)
6. No crashes during 1000+ character typing session
7. Performance profiling completed and optimized

**Priority:** P0

---

## Technical Dependencies

**iOS Frameworks:**
- UIKit (Keyboard UI)
- Foundation (Networking, App Group)
- Haptics (optional vibration feedback)

**Backend Integration:**
- Epic 1 backend API (must be deployed and accessible)

**Xcode Configuration:**
- App Group entitlement
- Keyboard extension target
- Full Access capability

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|---------|------------|
| **Full Access rejection by users** | High | Clear privacy messaging; keyboard works in limited mode without Full Access |
| **Keyboard performance degradation** | High | Async API calls; aggressive profiling; memory optimization |
| **Network latency** | Medium | Timeouts; non-blocking calls; silent failure for bad network |
| **Apple App Review privacy concerns** | High | Explicit consent flows; privacy manifest; no PII storage |

---

## Definition of Done

- [ ] All 8 stories completed with acceptance criteria met
- [ ] Keyboard extension can be installed and enabled on iOS device
- [ ] Real-time scam detection works end-to-end (typing → backend → alert)
- [ ] Alert banners display correctly for medium/high risk detections
- [ ] "Explain Why" popover shows detailed scam information
- [ ] Performance validated: < 100ms input latency, < 30MB memory
- [ ] Privacy messaging clear and Full Access handled gracefully
- [ ] Integration tested on physical iOS device (not just simulator)

---

## Notes

This epic delivers the core value proposition of TypeSafe. Stories 2.1-2.4 are critical path (P0) and must be completed sequentially. Stories 2.5-2.6 enhance UX (P1) and can be completed in parallel with later P0 stories.

**Estimated Timeline:** Week 2 (5-7 days of focused development)

**Testing Note:** Keyboard extensions must be tested on physical devices for realistic performance and user experience validation.

