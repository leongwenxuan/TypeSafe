# User Flow Summary

## A. Typing Flow
1. User types a message in any app using TypeSafe keyboard.  
2. Keyboard intercepts text → calls `/analyze-text` API.  
3. Backend (FastAPI + OpenAI) returns risk score + reason.  
4. Keyboard displays ⚠️ banner if risk > threshold.  
5. User can tap → see short explanation.

## B. Screenshot Flow
1. User opens TypeSafe app → taps "Scan My Screen".  
2. App captures screenshot → runs Vision OCR → sends image + text to backend.  
3. Backend uses Gemini API for visual + text analysis.  
4. Result displayed with confidence and reason; stored in Supabase.  
5. Keyboard retrieves latest result and displays if relevant.

