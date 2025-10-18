# Data Flows

## 5.1 Text Analysis (real-time)
1. Keyboard batches the last N chars (e.g., up to 300).  
2. `POST /analyze-text` with anonymized `session_id`.  
3. Backend → OpenAI; produce risk + reason.  
4. Backend stores normalized result; returns JSON.  
5. Keyboard shows banner if `risk_level ∈ {medium, high}`.

**Request**
```http
POST /analyze-text
{ "session_id":"anon-uuid", "app_bundle":"com.whatsapp", "text":"send me your OTP" }
```
**Response**
```json
{ "risk_level":"high","confidence":0.93,"category":"otp_phishing","explanation":"Asking for OTP." }
```

## 5.2 Screenshot Scan (user-initiated)
1. Companion app receives screenshot; runs **Vision OCR** locally.  
2. `POST /scan-image` with OCR text + (optional) image.  
3. Backend → Gemini (image+text) + OpenAI (text) → aggregate.  
4. Persist in Supabase; return verdict; write a small **App Group** flag for keyboard.  
5. Keyboard polls shared storage; displays confirmation banner.

