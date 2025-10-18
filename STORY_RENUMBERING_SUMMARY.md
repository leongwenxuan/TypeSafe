# Epic 2 Story Renumbering Summary

**Date:** 2025-01-18  
**Performed By:** Scrum Master (Bob)  
**Reason:** Technical debt from Story 2.1 required new story insertion

---

## Issue Identified

During Story 2.4 review, user identified that the keyboard lacks number and symbol layouts. Investigation revealed:

- **Story 2.1 AC6** stated "Letters, numbers, punctuation accessible"
- **Implementation** only created letter (QWERTY) layout
- **"123" button** exists but is non-functional (stub method)
- This is a **usability gap** that needs to be addressed

---

## Resolution

Created **new Story 2.5** to address the gap and renumbered subsequent stories.

### New Story Numbering

| Old Number | New Number | Story Title |
|------------|------------|-------------|
| 2.1 | 2.1 | Keyboard Extension Target & Basic Setup *(updated with technical debt documentation)* |
| 2.2 | 2.2 | Text Capture & Snippet Management |
| 2.3 | 2.3 | Backend API Integration |
| 2.4 | 2.4 | Inline Risk Alert Banners |
| **NEW** | **2.5** | **Complete Keyboard Layouts (Numbers & Symbols)** |
| 2.5 | 2.6 | "Explain Why" Popover Detail |
| 2.6 | 2.7 | App Group Shared State |
| 2.7 | 2.8 | Privacy & Full Access Handling |
| 2.8 | 2.9 | Keyboard Performance & Stability |

---

## Files Updated

### ✅ Created Files
- **`docs/stories/2.5.complete-keyboard-layouts-numbers-symbols.md`**
  - Full story with dev notes, tasks, and testing requirements
  - Priority: P0 (critical for keyboard usability)

### ✅ Modified Files

1. **`docs/prd/epic-2-keyboard-extension.md`**
   - Added Story 2.5 definition after Story 2.4
   - Renumbered Stories 2.5-2.8 → 2.6-2.9
   - Updated Definition of Done (8 stories → 9 stories)
   - Added note explaining story renumbering

2. **`docs/stories/2.1.keyboard-extension-target-basic-setup.md`**
   - Added "Known Limitations & Technical Debt" section
   - Documented missing number/symbol layouts
   - Explained reason for deferral
   - Referenced Story 2.5 as resolution

### ⚠️ No File Renaming Required
- Stories 2.6-2.9 do not exist as files yet (only defined in epic)
- No renaming conflicts or confusion
- Future story files will be created with correct numbering

---

## Story 2.5 Details

**Full Title:** Complete Keyboard Layouts (Numbers & Symbols)

**User Story:**
> As a keyboard user, I want to type numbers and symbols using the TypeSafe keyboard, so that I can use it as my primary keyboard for all text input needs.

**Key Acceptance Criteria:**
1. "123" button switches to number/symbol layout
2. Number layout displays: 0-9 and common symbols
3. "#+=" button switches to extended symbols layout
4. "ABC" button returns to letter layout
5. Layout state persists correctly
6. All layouts maintain consistent visual style

**Priority:** P0 (required for full keyboard functionality)

**Implementation Scope:**
- Add `KeyboardLayout` enum (letters, numbers, symbols)
- Implement `createNumberLayout()` method
- Implement `createSymbolLayout()` method
- Wire layout switching buttons
- Extend appearance system for new layouts
- Preserve snippet capture and banner functionality

**Testing:**
- Manual testing of all layout transitions
- Verify all keys insert correct characters
- Test integration with Stories 2.2-2.4 (snippet capture, API, banners)
- Memory profiling for layout switching

---

## Impact on Current Work

### ✅ No Impact on Completed Stories
- Stories 2.1-2.4 remain valid and complete
- Technical debt properly documented in Story 2.1

### ✅ Testing Workaround
- For testing Stories 2.2-2.4 with numbers/symbols:
  - Use external keyboard for number input
  - Or switch to system keyboard temporarily
  - Core scam detection features work independently of layout

### ⏭️ Next Steps
1. **Complete Story 2.4** (currently in progress)
2. **Implement Story 2.5** (keyboard layouts) - now next in queue
3. Continue with Story 2.6 (Explain Why popover)

---

## Rationale for Story Insertion

**Why insert Story 2.5 here instead of deferring to end of epic?**

1. **Logical Grouping:** Stories 2.1-2.5 complete the "basic keyboard functionality" foundation
2. **Dependency Chain:** Story 2.6 (Explain Why popover) builds on top of complete keyboard UI
3. **Testing Efficiency:** Having full keyboard before implementing popover simplifies testing
4. **User Experience:** Natural progression from basic input → complete input → enhanced features

**Why not fix in Story 2.1 retroactively?**

1. **Clean Separation:** Story 2.1 successfully delivered QWERTY layout as MVP
2. **Testing Value:** Stories 2.2-2.4 validated scam detection independent of layout complexity
3. **Documentation:** Clear technical debt documentation maintains transparency
4. **Agile Practice:** Adding stories is better than scope creep in completed stories

---

## Epic 2 Definition of Done Updated

**Old:** All 8 stories completed  
**New:** All 9 stories completed (including complete keyboard layouts)

---

## Communication Notes

- This renumbering was requested by user during Story 2.4 development
- Transparent documentation prevents confusion
- Story files use descriptive names (not just numbers) for clarity
- Epic file serves as source of truth for story sequence

---

**Status:** ✅ Complete  
**Stories Ready for Development:** Story 2.5 (full dev notes included)


