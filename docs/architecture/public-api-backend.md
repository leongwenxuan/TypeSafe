# Public API (Backend)

## 6.1 `POST /analyze-text`
- **Body**: `{ session_id, app_bundle, text }`
- **Returns**: `{ risk_level, confidence, category, explanation }`
- **Errors**: `400` invalid input, `429` rate limit, `500` provider error

## 6.2 `POST /scan-image`
- **Body**: multipart with `{ session_id, ocr_text, image? }`
- **Returns**: `{ risk_level, confidence, category, explanation }`

## 6.3 `GET /results/latest?session_id=...`
- **Returns**: most recent normalized result for the session.

**Common response schema**
```json
{
  "risk_level": "low|medium|high",
  "confidence": 0.0,
  "category": "otp_phishing|payment_scam|impersonation|unknown",
  "explanation": "human-friendly one-liner",
  "ts": "2025-10-18T02:30:00Z"
}
```

