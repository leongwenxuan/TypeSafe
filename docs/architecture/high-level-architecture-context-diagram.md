# High-Level Architecture (Context Diagram)

```
+-------------------- iOS Device --------------------+
|                                                    |
|  [ Any App ]     [ TypeSafe Keyboard ]             |
|     |                 |  send text (snippet)       |
|     |                 v                             |
|     |         +--------------------+                |
|     |         |  Keyboard Client   |                |
|     |         +----------+---------+                |
|     |                    | HTTPS                     |
|     |                    v                          |
|     |         +--------------------+                |
|     |         |  Companion App     |                |
|     |         |  (Scan, Settings)  |                |
|     |         +----------+---------+                |
|     |         (App Group Shared Storage)            |
+------------------------|---------------------------+
                         |
                         | Internet (TLS)
                         v
+------------------------+---------------------------+
|                TypeSafe Backend (FastAPI)          |
|  - /analyze-text   - /scan-image   - /results      |
|  - Risk aggregation & normalization                 |
|        |                  |                        |
|        |                  |                        |
|   OpenAI (Text)      Gemini (Multi-modal)          |
|        |                  |                        |
|                  Supabase (Postgres + Storage)     |
+----------------------------------------------------+
```

