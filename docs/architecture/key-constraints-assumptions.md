# Key Constraints & Assumptions

- iOS **Keyboard Extension sandbox**: can read what the user types **via our keyboard only**; cannot capture screen.  
- **Screenshots** must be initiated from the **companion app** (user action).  
- **Full Access** required for network calls from the keyboard.  
- **Privacy**: no raw PII storage, anonymized session IDs, 7‑day retention for analysis artifacts.  
- Latency target **< 2s** round trip for text analysis.

