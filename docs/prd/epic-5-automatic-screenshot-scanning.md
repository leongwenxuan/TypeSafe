# Epic 5: Automatic Screenshot Scanning

**Epic ID:** 5  
**Epic Title:** Automatic Screenshot Scanning  
**Priority:** P2 (Enhancement - UX Optimization)  
**Timeline:** Week 5-6  
**Dependencies:** Epic 4 (Screenshot Detection & Notifications), Epic 3 (Companion App)

---

## Epic Goal

Eliminate the manual photo selection step by automatically fetching and scanning the most recent screenshot when users tap "Scan Now" in the keyboard banner, creating a truly seamless screenshot-to-result workflow while maintaining iOS privacy compliance.

---

## Epic Description

This epic completes the screenshot scanning user experience by removing the friction point identified in the current Epic 4 implementation. When users take screenshots and tap "Scan Now" on the keyboard banner, the app will automatically:

1. Request Photos library access (if not already granted)
2. Fetch the most recent screenshot from the user's photo library
3. Trigger OCR and backend analysis automatically
4. Display results immediately

This transforms the workflow from:
- **Current:** Screenshot → Banner → Tap "Scan Now" → App Opens → **Tap "Scan My Screen"** → Select Photo → Scan → Results
- **New:** Screenshot → Banner → Tap "Scan Now" → App Opens → **Automatic Scan** → Results

**Key Enhancement:** Removes 2-3 manual steps, reducing time-to-result from ~10-15 seconds to ~3-5 seconds.

---

## Existing System Context

**Current Implementation (Epic 4):**
- ✅ Screenshot detection via `UIApplication.userDidTakeScreenshotNotification`
- ✅ App Group notification system (`SharedStorageManager`)
- ✅ Keyboard polling and banner display
- ✅ Deep link to companion app (`typesafe://scan`)
- ✅ Manual photo picker (`PhotosPicker` in `ScanView`)

**Technology Stack:**
- Swift/SwiftUI for iOS app
- Photos Framework for library access
- Existing OCR pipeline (Apple Vision)
- Existing backend API (`/scan-image`)

**Integration Points:**
- `DeepLinkCoordinator`: Handles URL scheme navigation
- `ScanView`: Current manual scan interface
- `OCRService`: Processes images to text
- `APIService`: Uploads to backend

---

## Stories

### Story 5.1: Photos Framework Integration & Permission Management

**As a** companion app,  
**I want** to request and manage Photos library access,  
**so that** I can automatically fetch screenshots for scanning.

**Acceptance Criteria:**

1. App requests Photos library permission on first launch (after onboarding)
2. Permission request message clearly explains automatic screenshot scanning
3. Handles all permission states: authorized, limited, denied, notDetermined
4. Falls back to manual picker if permission denied
5. Allows users to re-request permissions from Settings screen
6. Permission status cached and checked before automatic fetching
7. Works with both "All Photos" and "Limited Photos" access modes
8. Complies with iOS privacy guidelines and App Store review requirements

**Technical Notes:**
- Add `NSPhotoLibraryUsageDescription` to Info.plist
- Use `PHPhotoLibrary.requestAuthorization(for: .readWrite)`
- Handle `PHAuthorizationStatus` states gracefully
- Settings toggle: "Automatic Screenshot Scanning" (default: ON)

**Priority:** P0 (Must have for epic completion)

---

### Story 5.2: Automatic Screenshot Fetch & Scan Trigger

**As a** user tapping "Scan Now" from keyboard banner,  
**I want** the app to automatically fetch and scan my screenshot,  
**so that** I get results immediately without manual selection.

**Acceptance Criteria:**

1. Deep link URL scheme enhanced: `typesafe://scan?auto=true`
2. When `auto=true`, app automatically fetches most recent screenshot
3. Fetches screenshot using `PHAsset.fetchAssets` with screenshot filter
4. Verifies screenshot timestamp matches notification (within 60 seconds)
5. Converts `PHAsset` to `UIImage` for OCR processing
6. Triggers existing OCR pipeline automatically
7. Displays loading indicator during automatic scan
8. Falls back to manual picker if automatic fetch fails
9. Updates scan history with "Auto-scanned" indicator
10. Respects "Automatic Screenshot Scanning" setting toggle

**Technical Implementation:**
- Add `autoScanScreenshot()` method to `ScanView`
- Use `PHAsset.fetchAssets(with: .image, options: fetchOptions)` with:
  - `sortDescriptors`: `[NSSortDescriptor(key: "creationDate", ascending: false)]`
  - `predicate`: `NSPredicate(format: "mediaSubtype == %d", PHAssetMediaSubtype.photoScreenshot.rawValue)`
  - `fetchLimit: 1`
- Use `PHImageManager.default().requestImage()` to convert asset to UIImage
- Hook into existing `processImage()` flow from `OCRService`

**Priority:** P0 (Core functionality)

---

### Story 5.3: Error Handling & Edge Cases

**As a** user expecting automatic scanning,  
**I want** clear feedback when automatic scanning fails,  
**so that** I can understand what happened and manually scan if needed.

**Acceptance Criteria:**

1. Shows error banner if Photos permission denied (with "Settings" button)
2. Falls back to manual picker if screenshot not found
3. Handles case where screenshot was deleted before scan
4. Handles "Limited Photos" access (screenshot may not be available)
5. Shows timeout error if screenshot fetch takes > 5 seconds
6. Gracefully handles concurrent scans (debounce multiple taps)
7. Logs automatic scan failures for debugging
8. Updates UI to indicate automatic vs manual scan source
9. Provides clear user feedback for all error states

**Error Messages:**
- **Permission Denied:** "Enable Photos access in Settings for automatic scanning"
- **Screenshot Not Found:** "Screenshot not found. Opening manual picker..."
- **Fetch Failed:** "Couldn't load screenshot automatically. Select manually."

**Priority:** P1 (Important for production quality)

---

## Compatibility Requirements

**Existing Functionality:**
- ✅ Manual scanning via "Scan My Screen" button must still work
- ✅ Epic 4 banner and detection system unchanged
- ✅ Keyboard notification polling continues as-is
- ✅ App Group storage format unchanged
- ✅ Backend API calls unchanged (`/scan-image`)

**Backward Compatibility:**
- ✅ Users can still manually select photos if preferred
- ✅ Settings allow disabling automatic scanning
- ✅ Graceful degradation if permissions denied
- ✅ No breaking changes to existing features

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|---------|------------|
| **App Store rejection** | High | Follow Apple's privacy guidelines; transparent permission messaging; allow manual fallback |
| **"Limited Photos" restriction** | Medium | Fall back to manual picker; detect permission level before attempting auto-fetch |
| **Screenshot already deleted** | Low | Handle `nil` asset gracefully; show clear error and fall back to picker |
| **Performance impact** | Low | Async fetch with timeout (5s); cancel pending operations on view dismiss |
| **Privacy concerns** | Medium | Clear messaging; user toggles; only fetch on explicit "Scan Now" action |

---

## Privacy & App Store Compliance

**Privacy-First Design:**

✅ Permission requested only when feature is used (not on app launch)  
✅ Clear explanation in permission prompt  
✅ User control via Settings toggle  
✅ Falls back gracefully if permission denied  
✅ Only fetches screenshots when user explicitly taps "Scan Now"  
✅ No background photo access  
✅ Transparent about when and why photos are accessed

**App Store Review Preparation:**

- Update App Privacy details in App Store Connect
- Document automatic scanning in app description
- Provide clear opt-out mechanism in Settings
- Include permission explanation in screenshots/video
- Prepare reviewer notes explaining the feature purpose

---

## Technical Dependencies

**iOS Frameworks:**
- Photos Framework (`import Photos`)
- PHPhotoLibrary for permission management
- PHAsset for screenshot fetching
- PHImageManager for asset conversion

**Existing TypeSafe Components:**
- Epic 4: Deep link coordinator and URL scheme
- Epic 3: OCR service and backend integration
- Epic 2: Settings management
- Epic 4: Screenshot notification system

**New Components:**
- Photos permission manager
- Automatic screenshot fetcher
- Enhanced deep link parameter handling
- Error recovery and fallback logic

---

## Definition of Done

- [ ] Story 5.1: Photos permission flow implemented and tested
- [ ] Story 5.2: Automatic screenshot fetch and scan working end-to-end
- [ ] Story 5.3: All error cases handled with clear user feedback
- [ ] Settings toggle for automatic scanning functional
- [ ] Manual fallback works when automatic scan fails
- [ ] Privacy messaging reviewed and approved
- [ ] App Store compliance verified
- [ ] Performance tested: < 3 second fetch time on iPhone 12+
- [ ] Integration tested across iOS 16.0-17.x
- [ ] Edge cases tested: deleted screenshots, limited access, denied permissions

---

## Success Metrics

**User Experience:**
- Reduce screenshot-to-result time from ~12s to ~4s (67% improvement)
- 80%+ of scans use automatic flow (vs manual picker)
- < 5% automatic scan failures requiring fallback

**Technical Performance:**
- Screenshot fetch completes in < 2 seconds (p95)
- No memory leaks with repeated automatic scans
- Graceful handling of all error states

**Adoption:**
- Track automatic scan vs manual scan ratio
- Monitor permission grant rate
- Measure user retention of automatic scanning feature

---

## Rollback Plan

If issues arise post-release:

1. **Immediate:** Disable automatic scanning via Settings default (set to OFF)
2. **Short-term:** Release hotfix removing `auto=true` parameter from deep link
3. **Long-term:** Revert to Epic 4 implementation (notification + manual scan)

The manual scanning flow (Epic 3) remains fully functional as fallback.

---

## Implementation Notes

**Recommended Approach:**

1. Implement Stories in order: 5.1 → 5.2 → 5.3
2. Feature flag automatic scanning during development
3. Beta test with internal users before public release
4. Monitor automatic scan success rate via analytics
5. Collect user feedback on permission messaging clarity

**Testing Priority:**

- Focus on real devices (Photos Framework doesn't work in Simulator for some scenarios)
- Test across iOS versions: 16.0, 16.4, 17.0, 17.2
- Test with different permission states and photo library sizes
- Verify App Store compliance with privacy expert review

**Estimated Timeline:** 1-2 weeks

- Week 1: Stories 5.1 and 5.2 (core functionality)
- Week 2: Story 5.3 (polish and edge cases)

---

## Notes

This epic represents the completion of TypeSafe's screenshot scanning vision. By eliminating manual selection friction, we expect:

- Higher user satisfaction scores
- Increased screenshot scanning adoption
- Positive reviews highlighting the seamless UX

The automatic flow positions TypeSafe as a best-in-class scam detection tool with industry-leading user experience.

**Post-Epic Enhancement Ideas:**
- Background screenshot scanning (iOS 18+ background processing)
- Batch scanning of multiple screenshots
- AI-powered screenshot prioritization (scan risky-looking images first)

