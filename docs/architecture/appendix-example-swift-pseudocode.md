# Appendix — Example Swift Pseudocode

```swift
// Keyboard → analyze text
func analyze(snippet: String) {
  let body = ["session_id": sessionId, "app_bundle": currentBundle, "text": snippet]
  postJSON("/analyze-text", body) { result in
    if result.risk_level != "low" { showBanner(result) }
  }
}
```

```swift
// App → OCR + scan image
func scan(image: UIImage) {
  let ocrText = runVisionOCR(image)
  uploadMultipart("/scan-image", fields: ["session_id": sessionId, "ocr_text": ocrText], file: image)
}
```

---

**End — TypeSafe Architecture Spec (v1)**

