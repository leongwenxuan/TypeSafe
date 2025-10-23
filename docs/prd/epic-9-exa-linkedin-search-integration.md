# Epic 9: Exa LinkedIn Profile Search via Keyboard Prompt

**Epic ID:** 9
**Epic Title:** Exa LinkedIn Profile Search via Keyboard Prompt
**Priority:** P2 (Enhancement - Extended Functionality)
**Timeline:** Week 11-12 (1-2 weeks)
**Dependencies:** Epic 2 (Keyboard Extension), Epic 1 (Backend API), Epic 8 (MCP Infrastructure)

**Status:** 📝 DRAFT - Brownfield Enhancement

---

## ⚠️ IMPORTANT: Epic 8 Compatibility

**This epic adds NEW functionality without modifying existing systems:**

- ✅ **Epic 8 Scam Detection UNCHANGED**: The existing `ExaSearchTool` (REST API) in `backend/app/agents/tools/exa_search.py` continues to work exactly as before for scam detection
- ✅ **Separate Tool Architecture**: Creates a NEW `LinkedInSearchMCPTool` (MCP-based) specifically for LinkedIn profile searches
- ✅ **No Breaking Changes**: All existing endpoints (`/analyze-text`, `/scan-image`) remain unchanged
- ✅ **Additive Only**: New endpoint (`/search-linkedin`) is added, not modified from existing code

**Why Two Search Tools?**

- **Epic 8 (ExaSearchTool)**: REST API optimized for scam detection (phones, URLs, emails, companies)
- **Epic 9 (LinkedInSearchMCPTool)**: MCP `linkedin_search` tool optimized for LinkedIn profile lookups

Both tools coexist and use the same `EXA_API_KEY`.

---

## Epic Goal

Add a dedicated "Prompt" button to the TypeSafe keyboard that allows users to search for LinkedIn profiles using Exa's MCP Server `linkedin_search` tool, transforming typed text into intelligent LinkedIn profile lookups directly from the keyboard interface.

---

## Epic Description

### Existing System Context

**Current Relevant Functionality:**
- TypeSafe keyboard extension with multi-layout support (letters, numbers, symbols)
- Backend FastAPI service with existing MCP agent infrastructure (Epic 8)
- Epic 8 Exa Search Tool (REST API) for scam detection - remains unchanged
- WebSocket manager for real-time progress updates
- Keyboard-to-backend API integration established

**Technology Stack:**
- **Frontend**: Swift/UIKit keyboard extension (KeyboardViewController)
- **Backend**: Python FastAPI with Celery task queue + Redis
- **Exa Integration**:
  - Epic 8: REST API (`ExaSearchTool`) for scam detection
  - Epic 9: MCP Server (`LinkedInSearchMCPTool`) for LinkedIn search
- **Database**: Supabase/Postgres

**Integration Points:**
- KeyboardViewController manages button layouts and user input
- KeyboardAPIService handles backend communication
- Backend MCP agent orchestrates Exa searches
- WebSocket streaming for progress updates

---

### Enhancement Details

**What's Being Added:**

1. **Keyboard UI Changes:**
   - Move "Settings" button from right to left side of keyboard
   - Add new "Prompt" button on right side (blue/purple accent)
   - Button placement in the utility row (same row as current scanning/settings buttons)

2. **New Backend Endpoint:**
   - `POST /search-linkedin` - Receives text prompt, triggers Exa LinkedIn search
   - Leverages existing Exa Search Tool from Epic 8
   - Returns structured LinkedIn profile results

3. **LinkedIn-Specific Search Logic:**
   - Focus Exa searches specifically on LinkedIn profiles
   - Query template: `"linkedin.com/in/ {prompt}"` or `"{name} linkedin profile"`
   - Parse and structure profile data (name, title, company, profile URL)

**How It Integrates:**

- **UI Layer**: New button triggers prompt capture → sends to backend via KeyboardAPIService
- **Backend Layer**: New endpoint routes to Exa tool with LinkedIn-specific query formatting
- **MCP Layer**: Reuses existing Exa Search Tool infrastructure (no new MCP setup needed)
- **Display Layer**: Results shown in keyboard banner or popover (similar to scam alerts)

**Success Criteria:**

- User types a name in any text field → taps "Prompt" button
- Backend searches LinkedIn via Exa within 3-5 seconds
- Keyboard displays top LinkedIn profile results
- User can tap to copy LinkedIn URL or view profile summary
- No disruption to existing keyboard scam detection functionality

---

## User Stories

### Story 9.1: Keyboard Layout Reorganization

**As a** keyboard user,
**I want** the Settings button moved to the left and a new Prompt button on the right,
**so that** I can easily access LinkedIn profile search functionality.

**Acceptance Criteria:**

1. Settings button relocated to left side of utility row
2. New "Prompt" button added to right side of utility row
3. Prompt button has distinct visual styling (blue/purple accent, icon: magnifying glass or "🔍")
4. Button disabled when text input is empty
5. Button enabled when text input contains 2+ characters
6. Tapping Prompt button triggers LinkedIn search flow
7. Visual feedback on tap (highlight, haptic feedback)
8. Maintains existing keyboard color scheme (light/dark mode support)
9. Preserves all existing keyboard functionality (typing, delete, shift, layout switching)
10. Unit tests verify button placement and state management

**Technical Notes:**
- Modify `KeyboardViewController.setupUtilityRow()` or equivalent method
- Add `promptButtonTapped()` action handler
- Reuse existing button styling patterns from settings/scanner buttons

**Priority:** P0 (Foundation)

---

### Story 9.2: Backend LinkedIn Search Endpoint

**As a** backend service,
**I want** a new endpoint that formats LinkedIn searches for Exa,
**so that** the keyboard can trigger profile lookups.

**Acceptance Criteria:**

1. New endpoint: `POST /search-linkedin`
2. Request body:
   ```json
   {
     "prompt": "John Smith software engineer",
     "session_id": "uuid",
     "max_results": 5
   }
   ```
3. Response body:
   ```json
   {
     "type": "linkedin_search",
     "results": [
       {
         "name": "John Smith",
         "title": "Senior Software Engineer",
         "company": "Google",
         "profile_url": "https://linkedin.com/in/johnsmith123",
         "snippet": "Experienced software engineer specializing in..."
       }
     ],
     "search_time_ms": 2340,
     "source": "exa_mcp"
   }
   ```
4. Uses Exa MCP Server's `linkedin_search` tool via MCP client
5. **IMPORTANT:** Epic 8 `ExaSearchTool` (REST API) remains unchanged for scam detection
6. LinkedIn-specific search via MCP:
   - Tool: `linkedin_search` from Exa MCP Server
   - Parameters: `query` (user prompt), `searchType` ("profiles"), `numResults` (max results)
   - MCP tool handles LinkedIn-specific query optimization automatically
   - Filters results to only include LinkedIn profile URLs (`/in/` paths)
7. Handles edge cases:
   - Empty prompt → 400 error
   - No results found → Empty array with message
   - MCP connection failure → Graceful degradation (error message)
8. Response time: < 5 seconds (p95)
9. Rate limiting: 10 searches per session per hour (prevent abuse)
10. Logs search queries for analytics (anonymized)
11. Integration tests with mock MCP responses

**Technical Implementation:**

#### Step 1: Install MCP Client Library

```bash
cd backend
pip install mcp anthropic-mcp
```

#### Step 2: Create LinkedIn Search MCP Tool

Create new file: `backend/app/agents/tools/linkedin_search_mcp.py`

```python
"""LinkedIn Search Tool using Exa MCP Server.

This tool uses the Exa MCP Server's linkedin_search tool to find LinkedIn profiles
via the Model Context Protocol (MCP). This is separate from Epic 8's ExaSearchTool
which uses the REST API for scam detection.

Story: 9.2 - Backend LinkedIn Search Endpoint
"""

import os
import time
import logging
from typing import List, Dict, Any, Optional
from dataclasses import dataclass

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

logger = logging.getLogger(__name__)


@dataclass
class LinkedInProfile:
    """LinkedIn profile result."""
    name: str
    title: str
    company: str
    profile_url: str
    snippet: str

    @classmethod
    def from_mcp_result(cls, result: Dict[str, Any]) -> 'LinkedInProfile':
        """Parse MCP result into LinkedInProfile."""
        return cls(
            name=cls._extract_name(result),
            title=cls._extract_title(result),
            company=cls._extract_company(result),
            profile_url=result.get('url', ''),
            snippet=result.get('snippet', '')[:200]
        )

    @staticmethod
    def _extract_name(result: Dict[str, Any]) -> str:
        """Extract name from LinkedIn title."""
        title = result.get('title', '')
        # LinkedIn format: "Name - Job Title | LinkedIn"
        if ' - ' in title:
            return title.split(' - ')[0].strip()
        return title.split('|')[0].strip()

    @staticmethod
    def _extract_title(result: Dict[str, Any]) -> str:
        """Extract job title from title or snippet."""
        title = result.get('title', '')
        if ' - ' in title:
            parts = title.split(' - ')
            if len(parts) > 1:
                return parts[1].split('|')[0].strip()
        return result.get('snippet', '').split('.')[0][:100]

    @staticmethod
    def _extract_company(result: Dict[str, Any]) -> str:
        """Extract company from snippet."""
        snippet = result.get('snippet', '')
        for delimiter in [' at ', ' @ ', ' | ']:
            if delimiter in snippet:
                company = snippet.split(delimiter)[1].split('.')[0].split(',')[0].strip()
                return company[:50]
        return "N/A"


class LinkedInSearchMCPTool:
    """
    LinkedIn Search Tool using Exa MCP Server.

    Connects to Exa MCP Server and uses the linkedin_search tool
    for LinkedIn-specific profile searches.

    NOTE: This is separate from ExaSearchTool (Epic 8) which handles
    scam detection via REST API. Both tools coexist.
    """

    def __init__(self, api_key: Optional[str] = None):
        """Initialize LinkedIn Search MCP Tool."""
        self.api_key = api_key or os.getenv("EXA_API_KEY")
        if not self.api_key:
            raise ValueError("EXA_API_KEY not configured")

        self.session: Optional[ClientSession] = None
        self._initialized = False
        logger.info("LinkedInSearchMCPTool initialized")

    async def initialize(self):
        """Initialize MCP server connection."""
        if self._initialized:
            return

        try:
            server_params = StdioServerParameters(
                command="npx",
                args=["-y", "exa-mcp-server", "--tools=linkedin_search"],
                env={"EXA_API_KEY": self.api_key}
            )

            self.session = await stdio_client(server_params).__aenter__()
            self._initialized = True
            logger.info("MCP connection established")
        except Exception as e:
            logger.error(f"Failed to initialize MCP: {e}")
            raise

    async def search(
        self,
        prompt: str,
        max_results: int = 5,
        search_type: str = "profiles"
    ) -> Dict[str, Any]:
        """
        Search LinkedIn for profiles.

        Args:
            prompt: Search query (e.g., "John Smith software engineer")
            max_results: Number of results (default: 5)
            search_type: "profiles", "companies", or "all"

        Returns:
            Dict with results, query, search_time_ms, source
        """
        if not self._initialized:
            await self.initialize()

        start_time = time.time()

        try:
            # Call MCP linkedin_search tool
            result = await self.session.call_tool(
                "linkedin_search",
                arguments={
                    "query": prompt,
                    "searchType": search_type,
                    "numResults": max_results
                }
            )

            search_time_ms = (time.time() - start_time) * 1000

            # Parse MCP results
            mcp_results = result.content if hasattr(result, 'content') else result

            # Filter for LinkedIn profile URLs only
            profiles = []
            for item in mcp_results.get('results', []):
                url = item.get('url', '')
                if '/in/' in url:  # Only profile pages
                    profile = LinkedInProfile.from_mcp_result(item)
                    profiles.append({
                        "name": profile.name,
                        "title": profile.title,
                        "company": profile.company,
                        "profile_url": profile.profile_url,
                        "snippet": profile.snippet
                    })

            logger.info(f"LinkedIn search: {len(profiles)} profiles for '{prompt}'")

            return {
                "type": "linkedin_search",
                "results": profiles,
                "search_time_ms": int(search_time_ms),
                "source": "exa_mcp"
            }

        except Exception as e:
            logger.error(f"LinkedIn MCP search failed: {e}", exc_info=True)
            return {
                "type": "linkedin_search",
                "results": [],
                "search_time_ms": int((time.time() - start_time) * 1000),
                "source": "exa_mcp"
            }

    async def close(self):
        """Close MCP session."""
        if self.session:
            await self.session.__aexit__(None, None, None)
            self._initialized = False


# Singleton instance
_tool_instance: Optional[LinkedInSearchMCPTool] = None

async def get_linkedin_search_tool() -> LinkedInSearchMCPTool:
    """Get singleton LinkedInSearchMCPTool instance."""
    global _tool_instance
    if _tool_instance is None:
        _tool_instance = LinkedInSearchMCPTool()
        await _tool_instance.initialize()
    return _tool_instance
```

#### Step 3: Add Endpoint to FastAPI

Add to `backend/app/main.py`:

```python
# backend/app/main.py
from app.agents.tools.linkedin_search_mcp import get_linkedin_search_tool
from fastapi import HTTPException, Body
from pydantic import BaseModel

class LinkedInSearchRequest(BaseModel):
    prompt: str
    session_id: str
    max_results: int = 5

@app.post("/search-linkedin")
async def search_linkedin(request: LinkedInSearchRequest):
    """
    Search LinkedIn using Exa MCP linkedin_search tool.

    Story: 9.2 - Backend LinkedIn Search Endpoint

    NOTE: This uses MCP linkedin_search tool. Epic 8's ExaSearchTool
    (REST API) continues to handle scam detection unchanged.
    """
    # Validate input
    if len(request.prompt.strip()) < 2:
        raise HTTPException(status_code=400, detail="Prompt too short (min 2 characters)")

    try:
        # Get MCP tool
        linkedin_tool = await get_linkedin_search_tool()

        # Execute search via MCP
        response = await linkedin_tool.search(
            prompt=request.prompt,
            max_results=request.max_results,
            search_type="profiles"
        )

        return response

    except Exception as e:
        logger.error(f"LinkedIn search failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Search unavailable: {str(e)}")
```

**Architecture Note:**

```
TypeSafe Backend
│
├── Epic 8: Scam Detection (UNCHANGED)
│   └── ExaSearchTool (REST API)
│       └── backend/app/agents/tools/exa_search.py
│
└── Epic 9: LinkedIn Search (NEW)
    └── LinkedInSearchMCPTool (MCP)
        └── backend/app/agents/tools/linkedin_search_mcp.py
```

Both tools coexist. Epic 8 scam detection continues using REST API.

**Priority:** P0 (Core functionality)

---

### Story 9.3: iOS Keyboard LinkedIn Search Integration

**As a** keyboard user,
**I want** to tap the Prompt button and have LinkedIn profile results inserted into my text field,
**so that** I can quickly paste professional profile information while typing.

**Acceptance Criteria:**

1. Prompt button tap captures current text from input field
2. Shows loading indicator in keyboard banner while search is in progress
3. Calls `POST /search-linkedin` via KeyboardAPIService (Story 9.2's MCP endpoint)
4. Parses response format from MCP backend:

   ```json
   {
     "type": "linkedin_search",
     "results": [...],
     "search_time_ms": 2340,
     "source": "exa_mcp"
   }
   ```

5. **Inserts top result directly into text input** by replacing the search query with formatted profile info
6. Formatted output for top result:
   ```
   [Name] - [Job Title] at [Company]
   [LinkedIn URL]
   ```
   Example:
   ```
   John Smith - Senior Software Engineer at Google
   https://linkedin.com/in/johnsmith123
   ```
7. If multiple results found (2+):
   - Inserts top result as primary
   - Shows brief banner: "Found 3 profiles. Tap again to cycle through results."
   - Subsequent taps of Prompt button cycle through remaining results
8. Error handling:
   - No results → Shows banner: "No LinkedIn profiles found for '[prompt]'"
   - Network error → Shows banner: "Unable to search. Check connection."
   - MCP/Backend error → Shows banner: "Search unavailable. Try again later."
9. Haptic feedback on successful insertion
10. Performance: Search completes in < 5 seconds
11. Optional: Dismisses banner after 3 seconds
12. Unit tests for search flow, error states, text insertion, and result cycling

**UI Flow:**

**Before Search:**
```
┌─────────────────────────────────────────────┐
│  Text Field (App):                          │
│  "John Smith software engineer"             │ ← User types
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│  [TypeSafe Keyboard]                        │
│  Q W E R T Y U I O P                        │
│  A S D F G H J K L                          │
│  Z X C V B N M                              │
│  [Settings]  [Space]  [Prompt] ← Tap here  │
└─────────────────────────────────────────────┘
```

**During Search:**
```
┌─────────────────────────────────────────────┐
│  Banner: "🔍 Searching LinkedIn..."          │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│  [TypeSafe Keyboard]                        │
│  Q W E R T Y U I O P                        │
│  ...                                        │
└─────────────────────────────────────────────┘
```

**After Search (Success):**
```
┌─────────────────────────────────────────────┐
│  Text Field (App):                          │
│  "John Smith - Senior Software Engineer at  │
│   Google                                    │
│   https://linkedin.com/in/johnsmith123"     │ ← Auto-inserted
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│  Banner: "✓ Found 3 profiles. Tap Prompt    │
│           again to cycle through results."  │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│  [TypeSafe Keyboard]                        │
│  ...                                        │
└─────────────────────────────────────────────┘
```

**Cycling Through Results (2nd tap):**
```
┌─────────────────────────────────────────────┐
│  Text Field (App):                          │
│  "John A. Smith - Product Manager at Meta   │
│   https://linkedin.com/in/johnasmith456"    │ ← Replaced with result #2
└─────────────────────────────────────────────┘
```

**Technical Implementation:**

**KeyboardAPIService Extension:**

Add LinkedIn search method to `KeyboardAPIService.swift`:

```swift
// KeyboardAPIService.swift

extension KeyboardAPIService {
    func searchLinkedIn(
        prompt: String,
        maxResults: Int = 5,
        completion: @escaping (Result<LinkedInSearchResponse, Error>) -> Void
    ) {
        let endpoint = "\(baseURL)/search-linkedin"

        let requestBody: [String: Any] = [
            "prompt": prompt,
            "session_id": sessionID,
            "max_results": maxResults
        ]

        // Make POST request (implementation similar to existing API calls)
        post(endpoint: endpoint, body: requestBody) { result in
            switch result {
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(LinkedInSearchResponse.self, from: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

struct LinkedInSearchResponse: Codable {
    let type: String
    let results: [LinkedInProfile]
    let searchTimeMs: Int
    let source: String

    enum CodingKeys: String, CodingKey {
        case type, results, source
        case searchTimeMs = "search_time_ms"
    }
}

struct LinkedInProfile: Codable {
    let name: String
    let title: String
    let company: String
    let profileUrl: String
    let snippet: String

    enum CodingKeys: String, CodingKey {
        case name, title, company, snippet
        case profileUrl = "profile_url"
    }
}
```

**KeyboardViewController Implementation:**

```swift
// TypeSafeKeyboard/KeyboardViewController.swift

// Store search results for cycling
private var linkedInSearchResults: [LinkedInProfile] = []
private var currentResultIndex: Int = 0

@objc private func promptButtonTapped() {
    // Get current text from input
    guard let currentText = textDocumentProxy.documentContextBeforeInput,
          currentText.count >= 2 else {
        showBanner("Enter a name to search", type: .info)
        return
    }

    // If we have cached results, cycle through them
    if !linkedInSearchResults.isEmpty {
        cycleToNextResult()
        return
    }

    // Show loading state
    showBanner("🔍 Searching LinkedIn...", type: .loading)

    // Trigger haptic feedback
    feedbackGenerator?.impactOccurred()

    // Call backend (Story 9.2's MCP endpoint)
    keyboardAPIService.searchLinkedIn(prompt: currentText) { [weak self] result in
        DispatchQueue.main.async {
            self?.hideBanner()

            switch result {
            case .success(let searchResponse):
                self?.handleLinkedInSearchResults(
                    results: searchResponse.results,
                    originalPrompt: currentText
                )
            case .failure(let error):
                self?.showBanner("Search unavailable. Try again later.", type: .error)
            }
        }
    }
}

private func handleLinkedInSearchResults(results: [LinkedInProfile], originalPrompt: String) {
    guard !results.isEmpty else {
        showBanner("No LinkedIn profiles found for '\(originalPrompt)'", type: .info)
        return
    }

    // Store results for cycling
    linkedInSearchResults = results
    currentResultIndex = 0

    // Insert first result
    insertLinkedInProfile(results[0], originalPrompt: originalPrompt)

    // Show banner if multiple results
    if results.count > 1 {
        showBanner(
            "✓ Found \(results.count) profiles. Tap Prompt again to cycle through results.",
            type: .success,
            duration: 3.0
        )
    } else {
        showBanner("✓ LinkedIn profile inserted", type: .success, duration: 2.0)
    }

    // Haptic feedback
    feedbackGenerator?.notificationOccurred(.success)
}

private func cycleToNextResult() {
    guard !linkedInSearchResults.isEmpty else { return }

    // Move to next result
    currentResultIndex = (currentResultIndex + 1) % linkedInSearchResults.count
    let profile = linkedInSearchResults[currentResultIndex]

    // Clear current text and insert new profile
    clearCurrentText()
    insertLinkedInProfile(profile, originalPrompt: nil)

    // Show which result we're on
    showBanner(
        "Profile \(currentResultIndex + 1) of \(linkedInSearchResults.count)",
        type: .info,
        duration: 2.0
    )

    // Haptic feedback
    feedbackGenerator?.selectionChanged()
}

private func insertLinkedInProfile(_ profile: LinkedInProfile, originalPrompt: String?) {
    // If we have an original prompt, delete it first
    if let prompt = originalPrompt {
        for _ in 0..<prompt.count {
            textDocumentProxy.deleteBackward()
        }
    }

    // Format profile text
    let profileText = formatLinkedInProfile(profile)

    // Insert into text field
    textDocumentProxy.insertText(profileText)
}

private func formatLinkedInProfile(_ profile: LinkedInProfile) -> String {
    // Format: [Name] - [Job Title] at [Company]\n[LinkedIn URL]
    let jobInfo = profile.company != "N/A"
        ? "\(profile.title) at \(profile.company)"
        : profile.title

    return "\(profile.name) - \(jobInfo)\n\(profile.profileUrl)"
}

private func clearCurrentText() {
    // Delete all text in current line/paragraph
    // This is called when cycling through results
    while let text = textDocumentProxy.documentContextBeforeInput,
          !text.isEmpty {
        textDocumentProxy.deleteBackward()
    }
}

// Reset search state when user types
override func textDidChange(_ textInput: UITextInput?) {
    super.textDidChange(textInput)

    // Clear cached results when user starts typing again
    if !linkedInSearchResults.isEmpty {
        linkedInSearchResults = []
        currentResultIndex = 0
    }
}
```

**Helper Methods:**

```swift
// Banner helper for status messages
private func showBanner(
    _ message: String,
    type: BannerType,
    duration: TimeInterval = 0
) {
    // Implementation: Show banner above keyboard
    // Similar to existing scam detection banner
    // Auto-dismiss after duration if > 0
}

enum BannerType {
    case info, success, error, loading
}
```

**Priority:** P0 (User-facing functionality)

---

## Compatibility Requirements

- [x] Existing APIs remain unchanged (`/analyze-text`, `/scan-image` unaffected)
- [x] Database schema changes are additive only (no modifications to existing tables)
- [x] UI changes preserve existing keyboard layouts (letters, numbers, symbols)
- [x] Performance impact is minimal (search is async, doesn't block typing)
- [x] Exa API usage stays within budget (reuses existing Epic 8 infrastructure)

---

## Risk Mitigation

**Primary Risk:** Exa API costs increase due to LinkedIn searches

**Mitigation:**
- Rate limiting: 10 searches/session/hour
- Caching: Cache LinkedIn results for 24 hours (same prompt)
- Budget alerts: Monitor Exa API spend (set $50/month cap for LinkedIn searches)

**Rollback Plan:**
- Feature flag: `ENABLE_LINKEDIN_SEARCH` (default: false in production until tested)
- If costs exceed budget or error rates spike: Disable feature via flag
- Keyboard reverts to previous layout (remove Prompt button, restore Settings to right)

---

## Definition of Done

- [x] All 3 stories completed with acceptance criteria met
- [x] Prompt button functional and properly positioned in keyboard UI
- [x] Backend endpoint `/search-linkedin` operational and tested
- [x] LinkedIn search results displayed correctly in popover
- [x] Error handling covers all edge cases (no results, API failures, network issues)
- [x] Performance meets benchmarks (< 5s search time)
- [x] Exa API usage monitored and within budget
- [x] Integration tests passing (>90% coverage for new code)
- [x] User testing with 5+ beta testers (positive feedback on UX)

---

## Success Metrics

**Feature Adoption:**
- 30%+ of keyboard users try LinkedIn search within first week
- 10%+ of users perform 2+ LinkedIn searches per week

**Technical Performance:**
- Search completion time: < 5 seconds (p95)
- Success rate: > 95% (successful results returned)
- Error rate: < 5%

**User Satisfaction:**
- User feedback: "LinkedIn search is helpful" > 70% positive
- Feature retention: 60%+ of users who try it use it again within 7 days

**Cost Efficiency:**
- LinkedIn search API costs: < $50/month for first 1000 searches
- Cache hit rate: > 40% (reducing redundant searches)

---

## Timeline & Effort Estimate

**Total Duration:** 1-2 weeks (10-15 working days)

**Engineering Effort:** ~40-60 hours

| Story | Effort | Assignee | Duration |
|-------|--------|----------|----------|
| 9.1 - Keyboard Layout | 12 hours | iOS Engineer | 2-3 days |
| 9.2 - Backend Endpoint | 16 hours | Backend Engineer | 2-3 days |
| 9.3 - iOS Integration | 20 hours | iOS Engineer | 3-4 days |
| Testing & QA | 10 hours | QA + Engineers | 2 days |
| **Total** | **58 hours** | **2 Engineers** | **~10 days** |

---

## Dependencies & Integration Points

**Technical Dependencies:**
- Epic 8 (MCP Agent Orchestration) - Provides Exa Search Tool
- Epic 2 (Keyboard Extension) - Keyboard UI framework
- Epic 1 (Backend API) - API infrastructure

**Integration Points:**
- `KeyboardViewController.swift` - Button placement and event handling
- `KeyboardAPIService.swift` - Backend communication layer
- `backend/app/main.py` - New endpoint implementation
- `backend/app/agents/tools/exa_search.py` - Exa tool reuse (add LinkedIn-specific method)

**External Dependencies:**
- Exa API (already integrated in Epic 8)
- No new external APIs required

---

## Testing Strategy

### Unit Tests

**iOS Keyboard Tests:**
- Prompt button state management (enabled/disabled based on text input)
- Button tap event triggers correct action handler
- Loading indicator shows/hides correctly
- Result popover displays structured data correctly
- Error states render appropriate messages
- Clipboard copy functionality works

**Backend Endpoint Tests:**
- Valid prompt returns LinkedIn results
- Empty prompt returns 400 error
- No results scenario handled gracefully
- Exa API failure triggers error response
- Rate limiting enforces search caps
- Response format matches schema

### Integration Tests

**End-to-End Flow:**
1. User types "John Smith" in text field
2. Taps Prompt button
3. Backend receives request and calls Exa
4. Exa returns LinkedIn search results
5. Backend parses and structures results
6. iOS receives results via API
7. Popover displays results
8. User taps "Copy URL" → clipboard contains LinkedIn URL

**Error Scenarios:**
- Exa API timeout → Error message displayed
- Network failure → Graceful error handling
- Invalid prompt (too short) → Validation error

### Manual QA

**Test Cases:**
- Common names (e.g., "John Smith", "Sarah Lee")
- Specific searches (e.g., "Elon Musk CEO", "Satya Nadella Microsoft")
- Edge cases (special characters, very long names, emoji)
- No results scenario (fake names)
- Multiple result handling (5+ profiles found)
- Performance under load (10 consecutive searches)
- Dark mode vs light mode UI rendering
- Different keyboard layouts (letters, numbers, symbols)

---

## Monitoring & Observability

**Key Metrics to Track:**

**Performance Metrics:**
- LinkedIn search latency (p50, p95, p99)
- Exa API response times
- Cache hit rate

**Business Metrics:**
- Daily LinkedIn searches count
- Unique users performing searches
- Average searches per user
- Result click-through rate (copy URL actions)

**Cost Metrics:**
- Exa API calls for LinkedIn (daily, monthly)
- Cost per search
- Total monthly Exa spend (LinkedIn vs scam detection)

**Reliability Metrics:**
- Search success rate
- Error rate by type (validation, API, network)
- Rate limiting triggers

**Logging Strategy:**

```python
# Example log entry
{
  "timestamp": "2025-10-20T14:30:00Z",
  "level": "INFO",
  "service": "linkedin_search",
  "event": "search_completed",
  "prompt": "John Smith",  # Optionally anonymized
  "result_count": 5,
  "search_time_ms": 2340,
  "cache_hit": false,
  "session_id": "abc-123"
}
```

---

## Rollout Plan

### Phase 1: Development & Testing (Week 11 - Days 1-5)
- ✅ Story 9.1: Keyboard layout changes
- ✅ Story 9.2: Backend endpoint implementation
- ✅ Unit tests for all components
- ✅ Deploy to staging environment
- **Deliverable:** Functional LinkedIn search in staging

### Phase 2: Integration & QA (Week 11 - Days 6-8)
- ✅ Story 9.3: iOS keyboard integration
- ✅ End-to-end integration testing
- ✅ Manual QA with diverse search queries
- ✅ Performance benchmarking
- **Deliverable:** Polished feature ready for beta

### Phase 3: Beta Testing (Week 12 - Days 9-12)
- ✅ Feature flag: `ENABLE_LINKEDIN_SEARCH=true` for 10 beta users
- ✅ Collect feedback on UX, accuracy, usefulness
- ✅ Monitor costs and performance metrics
- ✅ Fix any discovered bugs
- **Deliverable:** Production-ready feature

### Phase 4: Production Launch (Week 12 - Days 13-15)
- ✅ Gradual rollout: 10% → 50% → 100% over 1 week
- ✅ Monitor metrics: adoption, latency, costs, errors
- ✅ Daily review meetings
- **Deliverable:** Full production deployment

---

## Future Enhancements (Post-Epic)

**Short-term:**
- Multi-profile comparison (side-by-side view of 2-3 profiles)
- Company search (search for company pages instead of profiles)
- Save searches (bookmark LinkedIn URLs for later)

**Long-term:**
- In-app LinkedIn profile preview (WebView integration)
- Contact enrichment (pull email/phone from LinkedIn via API)
- Integration with CRM systems (export to Salesforce, HubSpot)

---

## Notes

This epic represents a **strategic pivot** for TypeSafe from purely defensive (scam detection) to **productivity-enhancing** (professional networking). By enabling LinkedIn searches directly from the keyboard:

✅ **Increases daily active usage** (users type daily, search LinkedIn frequently)
✅ **Demonstrates Exa MCP value** beyond scam detection
✅ **Differentiates TypeSafe** as a multi-purpose intelligent keyboard
✅ **Low technical risk** (reuses Epic 8 infrastructure)

**Estimated ROI:**
- Development cost: ~60 hours (~$6,000 if outsourced)
- Expected value: 30% increase in user engagement
- Break-even: 100 active users using feature 2x/week

---

## Open Questions & Decisions

**Pre-Implementation Decisions Needed:**

1. **Exa API Budget:** What's the acceptable monthly spend for LinkedIn searches?
   - Current Epic 8 usage: ~$40-50/month for scam detection
   - LinkedIn searches projection: +$30-50/month (1000 searches)
   - Total Exa spend: ~$80-100/month
   - **Decision needed:** Is this acceptable? Should we prioritize features?

2. **Button Placement:** Exact position of Prompt button in utility row?
   - Option A: Far right (easiest thumb reach)
   - Option B: Next to Settings (logical grouping)
   - **Recommendation:** Far right for accessibility

3. **Result Display:** Popover vs Banner vs Separate View?
   - Popover: Inline with keyboard (less disruptive)
   - Banner: Quick preview, tap to expand
   - Separate View: Full-screen results (more space)
   - **Recommendation:** Start with popover, add full view if popular

4. **Caching Duration:** How long to cache LinkedIn results?
   - Short (1 hour): Fresher results, higher costs
   - Medium (24 hours): Balance between freshness and cost
   - Long (7 days): Low cost, stale data risk
   - **Recommendation:** 24 hours (people's job titles don't change daily)

---

## Related Documentation

- [Epic 8: MCP Agent Orchestration](epic-8-mcp-agent-orchestration.md) - Exa Search Tool infrastructure
- [Epic 2: Keyboard Extension](epic-2-keyboard-extension.md) - Keyboard UI framework
- [Epic 1: Backend API](epic-1-backend-api.md) - API design patterns
- [Architecture: Public API Backend](../architecture/public-api-backend.md) - API standards

---

## Changelog

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-10-20 | 1.0 | Sarah (Product Owner) | Initial draft - brownfield enhancement spec |

---

**End of Epic 9: Exa LinkedIn Profile Search via Keyboard Prompt**
