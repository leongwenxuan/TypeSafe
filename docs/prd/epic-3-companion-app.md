# Epic 3: Companion App & Screenshot Scanner

**Epic ID:** 3  
**Epic Title:** Companion App & Screenshot Scanner  
**Priority:** P0 (Critical - Secondary Core Feature)  
**Timeline:** Week 3  
**Dependencies:** Epic 1 (Backend API), Epic 2 (for App Group integration)

---

## Epic Goal

Build the TypeSafe companion app with screenshot scanning capabilities, on-device OCR processing, scan history, and privacy controls, enabling users to analyze suspicious messages captured as screenshots.

---

## Epic Description

This epic delivers the companion app that complements the keyboard extension. Users can trigger screenshot scans, which use Apple Vision Framework for local OCR, then send the extracted text and optional image to the backend for multimodal scam analysis. The app displays results, maintains scan history, and provides privacy controls (Full Access toggle, data deletion).

---

## User Stories

### Story 3.1: Main App UI Structure & Navigation

**As a** user,  
**I want** a clean, intuitive app interface,  
**so that** I can easily access scan, history, and settings features.

**Acceptance Criteria:**
1. SwiftUI-based main app with tab navigation
2. Three main tabs: "Scan", "History", "Settings"
3. App icon and branding consistent with TypeSafe identity
4. Launch screen displays during app startup
5. App supports iOS 16.0+ (minimum target)
6. Dark mode support for all screens
7. Accessibility labels for VoiceOver

**Priority:** P0

---

### Story 3.2: Screenshot Capture & Selection

**As a** user,  
**I want** to select or capture screenshots to scan for scams,  
**so that** I can analyze suspicious messages I receive.

**Acceptance Criteria:**
1. "Scan My Screen" button prominently displayed on Scan tab
2. Tapping button opens iOS Photo Picker (PHPickerViewController)
3. User can select existing screenshots from Photos library
4. Selected image displayed in preview before scanning
5. Option to capture new screenshot (via iOS screenshot mechanism)
6. Image format validation (PNG, JPEG supported)
7. Error handling for unsupported formats or access denied

**Priority:** P0

---

### Story 3.3: On-Device OCR with Vision Framework

**As a** user,  
**I want** my screenshot text extracted locally on my device,  
**so that** my privacy is protected and OCR is fast.

**Acceptance Criteria:**
1. Apple Vision Framework integrated (`VNRecognizeTextRequest`)
2. OCR runs on selected screenshot image
3. Text extraction supports English language (MVP)
4. Recognition level set to "accurate" for best results
5. Extracted text displayed in preview (editable text view)
6. User can review/edit OCR text before submitting for analysis
7. OCR processing time < 2s for typical screenshot
8. Error handling for OCR failures (displays message, allows retry)

**Priority:** P0

---

### Story 3.4: Backend Integration (Scan Image API)

**As a** companion app,  
**I want** to send OCR text and optional screenshot to backend,  
**so that** I can get AI-powered scam analysis results.

**Acceptance Criteria:**
1. API client calls `POST /scan-image` with multipart form data
2. Sends session_id (anonymous UUID), ocr_text, and optional image
3. Session ID persisted in UserDefaults (per user, anonymous)
4. Image sent only if user opts in (privacy setting)
5. API call made asynchronously with loading indicator
6. Request timeout set to 4s
7. Network error handling with retry option
8. Results parsed and displayed in result view

**Priority:** P0

---

### Story 3.5: Scan Result Display

**As a** user,  
**I want** to see clear, understandable scan results,  
**so that** I know if the screenshot contains a potential scam.

**Acceptance Criteria:**
1. Result view displays after scan completes
2. Shows risk level with color coding (Green: Low, Amber: Medium, Red: High)
3. Displays confidence percentage (e.g., "93% confident")
4. Shows scam category (e.g., "OTP Phishing", "Payment Scam")
5. Displays AI explanation in plain, empathetic language
6. Includes timestamp of scan
7. "Scan Another" button to return to main scan screen
8. Option to save result to history

**Priority:** P0

---

### Story 3.6: Scan History & Storage

**As a** user,  
**I want** to view my recent scan history,  
**so that** I can reference previous scam detections.

**Acceptance Criteria:**
1. History tab displays last 5 scans (newest first)
2. Each history item shows: thumbnail, risk level, category, timestamp
3. Tapping history item opens detailed result view
4. History stored locally using Core Data or UserDefaults
5. Automatic cleanup of scans older than 7 days (privacy compliance)
6. Empty state message when no history: "No scans yet"
7. Pull-to-refresh to sync latest results from backend (optional)

**Priority:** P1

---

### Story 3.7: App Group Integration & Keyboard Sync

**As a** user,  
**I want** my keyboard to know about recent screenshot scans,  
**so that** I can see relevant alerts while typing.

**Acceptance Criteria:**
1. App writes latest scan result to App Group shared storage
2. Shared data includes: risk_level, category, timestamp (no raw text)
3. Keyboard reads shared storage and displays confirmation banner
4. Banner in keyboard says "Latest scan: [Risk Level] - [Category]"
5. Shared state minimal (< 1KB) for privacy
6. App updates shared state immediately after scan completion

**Priority:** P1

---

### Story 3.8: Privacy Controls & Settings

**As a** user,  
**I want** privacy controls and settings,  
**so that** I control my data and understand how TypeSafe uses it.

**Acceptance Criteria:**
1. Settings tab displays privacy options
2. Toggle: "Enable Full Access" (with explanation and link to iOS Settings)
3. Toggle: "Send Screenshot Images" (default: OFF for privacy)
4. Button: "Delete All Data" (clears history, resets session ID)
5. Data deletion confirmation dialog
6. Privacy policy link (external web view or Safari)
7. App version number displayed in settings
8. Optional: Voice Alert toggle (if voice feature implemented)

**Priority:** P0

---

## Technical Dependencies

**iOS Frameworks:**
- SwiftUI (App UI)
- Vision Framework (OCR)
- PhotosUI / PHPickerViewController (image selection)
- Core Data or UserDefaults (history storage)
- App Group (keyboard sync)

**Backend Integration:**
- Epic 1 backend API (POST /scan-image)

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|---------|------------|
| **OCR accuracy issues** | Medium | Allow user to edit OCR text before submission; Vision is generally accurate |
| **User confusion about permissions** | Medium | Clear privacy messaging; explain each permission with benefits |
| **Backend latency for image uploads** | Medium | Optimize image size; show loading indicators; implement timeout |
| **Privacy concerns about image upload** | High | Default to NOT sending images; only send OCR text unless user opts in |

---

## Definition of Done

- [ ] All 8 stories completed with acceptance criteria met
- [ ] Companion app installed and functional on iOS device
- [ ] Screenshot scan flow works end-to-end (select → OCR → backend → result)
- [ ] On-device OCR extracts text accurately (tested with real screenshots)
- [ ] Scan results displayed clearly with color-coded risk levels
- [ ] History stores and displays last 5 scans correctly
- [ ] App Group integration syncs scan results to keyboard
- [ ] Privacy controls functional (delete data, toggle settings)
- [ ] App tested on physical iOS device for realistic UX

---

## Notes

This epic delivers the screenshot scanning feature, a key differentiator for TypeSafe. Stories 3.1-3.5 are critical path (P0) and should be completed sequentially. Stories 3.6-3.8 enhance UX and privacy (P1) and can be completed in parallel.

**Estimated Timeline:** Week 3 (5-7 days of focused development)

**Privacy Note:** By default, only OCR text should be sent to backend, NOT the screenshot image itself. Image upload should be opt-in to maximize user privacy and trust.

