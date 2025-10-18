# Deployment & Environments

| Env | Purpose | Notes |
|-----|--------|-------|
| **Local** | Dev iteration | Uvicorn + ngrok for device testing |
| **Staging** | Pre-demo | Test API keys, Supabase staging |
| **Prod (Demo)** | Live demo | Cloud host (Render/Vercel) + Cloudflare proxy |

- Infra as simple code: Dockerfile for FastAPI service.  
- Logs & metrics: basic request logs; Supabase query stats.

