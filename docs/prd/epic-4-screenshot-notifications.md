# Epic 4: Screenshot Detection & Cross-App Notifications

**Epic ID:** 4  
**Epic Title:** Screenshot Detection & Cross-App Notifications  
**Priority:** P1 (Enhancement - User Experience Improvement)  
**Timeline:** Week 4  
**Dependencies:** Epic 2 (Keyboard Extension), Epic 3 (Companion App)

---

## Epic Goal

Enable seamless screenshot-to-scan workflow by detecting when users take screenshots and providing instant keyboard prompts to analyze them for scams, creating a frictionless user experience that bridges typing and screenshot analysis.

---

## Epic Description

This epic enhances the TypeSafe user experience by connecting screenshot capture with real-time keyboard notifications. When users take screenshots while typing (common when receiving suspicious messages), the companion app detects the screenshot and notifies the keyboard extension via App Group shared storage. The keyboard then displays a non-intrusive prompt allowing users to immediately scan their screenshot without app switching friction.

This creates a powerful workflow: **Type → Screenshot → Instant Scan Prompt → Quick Analysis** - all without leaving the keyboard context.

---

## User Stories

### Story 4.1: Screenshot Detection & Notification (Companion App)

**As a** companion app,  
**I want** to detect when the user takes screenshots,  
**so that** I can notify the keyboard about potential scam content to analyze.

**Acceptance Criteria:**

1. App registers for `UIApplication.userDidTakeScreenshotNotification`
2. Screenshot detection works when app is active, backgrounded, or suspended
3. Writes screenshot notification to App Group shared storage immediately
4. Notification includes: timestamp, detection flag, and notification ID
5. Shared data remains minimal and privacy-safe (no screenshot content stored)
6. Debounces multiple rapid screenshots (max 1 notification per 5 seconds)
7. Notification persists for 60 seconds then auto-expires
8. Works across all iOS versions 16.0+

**Priority:** P1

---

### Story 4.2: Screenshot Alert Prompt in Keyboard

**As a** keyboard user,  
**I want** to be notified when I take screenshots while typing,  
**so that** I can quickly scan them for scams without switching apps manually.

**Acceptance Criteria:**

1. Keyboard polls App Group storage for screenshot notifications every 2 seconds
2. When notification detected, displays banner: "Screenshot taken - Scan for scams?"
3. Banner includes "Scan Now" button and dismiss "X" button  
4. Banner styled consistently with existing risk alert banners (Story 2.4)
5. Tapping "Scan Now" launches companion app via URL scheme (`typesafe://scan`)
6. Banner auto-dismisses after 15 seconds if not interacted with
7. Only shows notifications from last 60 seconds (respects expiration)
8. User can disable feature via Settings toggle: "Screenshot Scan Prompts"
9. Banner does not block keyboard typing functionality

**Priority:** P1

---

## Technical Architecture

### Screenshot Detection Flow

```text
1. User takes screenshot (iOS system action)
2. Companion app receives UIApplication.userDidTakeScreenshotNotification
3. App writes notification to App Group: group.com.typesafe.shared
4. Keyboard polls shared storage (every 2s when active)
5. Keyboard displays banner prompt
6. User taps "Scan Now" → launches companion app
7. Companion app opens to scan screen for immediate analysis
```

### App Group Data Structure

```swift
// Shared storage key: "screenshot_notifications"
struct ScreenshotNotification: Codable {
    let id: String              // UUID for deduplication
    let timestamp: Date         // When screenshot was taken
    let isActive: Bool          // Whether notification is still valid
    let expiresAt: Date         // Auto-expiration (timestamp + 60s)
}
```

### URL Scheme Integration

- **Scheme:** `typesafe://scan`
- **Purpose:** Deep link from keyboard to companion app scan screen
- **Behavior:** Opens companion app directly to screenshot selection/scan interface

---

## Privacy & Performance Considerations

**Privacy-First Design:**

- ✅ No screenshot content stored in shared storage
- ✅ Only metadata (timestamp, flags) shared between apps
- ✅ User can disable feature completely
- ✅ Notifications auto-expire (60-second TTL)
- ✅ Follows existing App Group privacy patterns

**Performance Optimization:**

- ✅ Minimal polling frequency (2-second intervals)
- ✅ Lightweight shared data structure (< 100 bytes)
- ✅ Debounced notifications prevent spam
- ✅ Auto-cleanup of expired notifications

**User Experience:**

- ✅ Non-intrusive banner design
- ✅ Maintains keyboard typing flow
- ✅ Quick access to scan functionality
- ✅ Consistent with existing TypeSafe UI patterns

---

## Technical Dependencies

**iOS Frameworks:**

- Foundation (UserDefaults, Notifications)
- UIKit (UIApplication notifications)
- App Groups (shared storage)

**Existing TypeSafe Components:**

- Epic 2: App Group shared storage (Story 2.7)
- Epic 2: Alert banner UI patterns (Story 2.4)
- Epic 3: Companion app scan interface (Story 3.2)

**New Components:**

- URL scheme registration (`typesafe://`)
- Screenshot notification polling service
- Cross-app notification data models

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|---------|------------|
| **Battery drain from polling** | Medium | 2-second intervals only when keyboard active; pause when inactive |
| **User finds prompts annoying** | Medium | User toggle to disable; auto-dismiss after 15s; non-blocking design |
| **App Group storage conflicts** | Low | Unique notification IDs; atomic read/write operations |
| **URL scheme conflicts** | Low | Use unique scheme `typesafe://`; register in Info.plist |

---

## Definition of Done

- [ ] Story 4.1 completed: Companion app detects screenshots and writes notifications
- [ ] Story 4.2 completed: Keyboard displays screenshot prompts and launches app
- [ ] URL scheme registered and functional for deep linking
- [ ] App Group integration tested across app lifecycle states
- [ ] Privacy toggle allows users to disable screenshot prompts
- [ ] Performance validated: no significant battery or memory impact
- [ ] User experience tested: seamless screenshot → scan workflow
- [ ] Integration tested on physical iOS device with real screenshot scenarios

---

## Success Metrics

**User Experience:**

- Reduced friction in screenshot-to-scan workflow
- Increased usage of screenshot scanning feature
- Positive user feedback on notification helpfulness

**Technical Performance:**

- < 2% battery impact from polling
- < 1MB additional memory usage
- 100% reliability in screenshot detection

**Adoption:**

- Measure screenshot scan conversion rate (notification → actual scan)
- Track user retention of screenshot prompt feature (enabled vs disabled)

---

## Notes

This epic represents a significant UX enhancement that bridges the gap between TypeSafe's two core features (keyboard text analysis and screenshot scanning). By reducing friction in the screenshot analysis workflow, we expect increased user engagement with the screenshot scanning feature.

**Implementation Order:** Story 4.1 must be completed before Story 4.2, as the keyboard depends on the companion app's notification system.

**Estimated Timeline:** Week 4 (3-4 days of focused development)

**Testing Priority:** Focus on real-world usage scenarios - users receiving suspicious messages, taking screenshots, and immediately wanting to scan them.
