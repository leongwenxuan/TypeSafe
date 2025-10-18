# Unit Test Setup Instructions for Story 2.2

## Overview
Story 2.2 requires setting up a unit test target to validate TextSnippetManager and SecureTextDetector classes. The test files have been created but need to be added to an Xcode test target.

## Test Files Created
- `TypeSafeTests/TextSnippetManagerTests.swift` - 25+ tests for snippet windowing logic
- `TypeSafeTests/SecureTextDetectorTests.swift` - 15+ tests for secure field detection

## Manual Setup Steps (Via Xcode)

### Step 1: Create Unit Test Target

1. Open `TypeSafe.xcodeproj` in Xcode
2. Go to **File → New → Target**
3. Select **iOS → Unit Testing Bundle**
4. Name it: `TypeSafeTests`
5. Set Product Name: `TypeSafeTests`
6. Click **Finish**

### Step 2: Add Test Files to Target

1. In Xcode Project Navigator, locate the test files:
   - `TypeSafeTests/TextSnippetManagerTests.swift`
   - `TypeSafeTests/SecureTextDetectorTests.swift`
2. Right-click each file → **Add Files to "TypeSafe"**
3. Ensure **Target Membership** includes `TypeSafeTests`

### Step 3: Configure Test Target Dependencies

1. Select the `TypeSafe` project in Project Navigator
2. Select the `TypeSafeTests` target
3. Go to **Build Phases** tab
4. Under **Dependencies**, click **+**
5. Add `TypeSafeKeyboard` as a dependency
6. Under **Link Binary with Libraries**, click **+**
7. Add `TypeSafeKeyboard.appex`

### Step 4: Enable Testability

1. Select the `TypeSafeKeyboard` target
2. Go to **Build Settings**
3. Search for "Enable Testability"
4. Set **Enable Testability** to **YES** for Debug configuration

### Step 5: Update Test File Imports (if needed)

The test files use `@testable import TypeSafeKeyboard`. Ensure this works:
1. If you get import errors, check that TypeSafeKeyboard is properly linked
2. Ensure the module name matches: `TypeSafeKeyboard`

### Step 6: Run Unit Tests

1. Select the `TypeSafeTests` scheme in Xcode
2. Press **Cmd + U** to run all tests
3. Or click on individual test methods to run specific tests

Expected Results:
- All TextSnippetManager tests should pass (25+ tests)
- All SecureTextDetector tests should pass (15+ tests)
- Total test execution time: < 1 second

## Alternative: Command Line Setup

If you prefer command-line setup, you'll need to manually edit the `TypeSafe.xcodeproj/project.pbxproj` file. This is not recommended due to complexity.

## Verification

After setup, verify:
```bash
cd /Users/leongwenxuan/Desktop/TypeSafe
xcodebuild test -project TypeSafe.xcodeproj -scheme TypeSafeTests -destination 'platform=iOS Simulator,id=CBA0BBD1-372F-438D-B057-FECC17EDCB44'
```

Expected output should show all tests passing.

## Test Coverage Goals

Target coverage:
- TextSnippetManager: 95%+ line coverage
- SecureTextDetector: 90%+ line coverage

## Notes

- Test files use mocking for UITextDocumentProxy
- Tests are isolated and don't require UI or simulator
- Tests validate all acceptance criteria for Story 2.2
- Debug logs in KeyboardViewController help with manual integration testing

## Next Steps After Test Setup

1. Run all unit tests and verify they pass
2. Proceed with Task 7: Manual integration testing on simulator
3. Use Xcode Console to view debug logs during manual testing
4. Verify snippet triggers appear in logs when typing

