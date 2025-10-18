# Security & Privacy

- **Transport**: HTTPS (TLS 1.3), HSTS on backend.  
- **Auth**: Backend API-key from the app; rotate keys via secrets manager.  
- **Minimization**: send only small text snippets; screenshots optional.  
- **Anonymization**: `session_id` = random UUID, no PII.  
- **Local-first**: OCR on-device; screenshot upload is opt-in.  
- **App Group**: secure shared container for keyboard↔app flags only.  
- **Compliance**: App Store privacy manifest; easy "Delete my data" action.

