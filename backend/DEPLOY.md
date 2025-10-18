# TypeSafe Backend Deployment Guide

## Overview

This guide covers deployment of the TypeSafe FastAPI backend service to various environments.

## Prerequisites

- Python 3.11+
- Docker (for containerized deployment)
- API keys: OpenAI, Gemini, Supabase
- Cloud hosting account (Render, Vercel, or similar)

## Environment Configuration

### Required Environment Variables

```bash
ENVIRONMENT=production           # local|staging|production
OPENAI_API_KEY=sk-...           # OpenAI API key
GEMINI_API_KEY=...              # Google Gemini API key
SUPABASE_URL=https://...        # Supabase project URL
SUPABASE_KEY=...                # Supabase API key
BACKEND_API_KEY=...             # API key for iOS app authentication
```

### Optional Configuration

```bash
CORS_ORIGINS=https://yourdomain.com  # Comma-separated list of allowed origins
```

## Local Development

### Setup

```bash
# Navigate to backend directory
cd backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Copy and configure environment
cp .env.example .env
# Edit .env with your actual API keys
```

### Run Locally

```bash
# Start development server with auto-reload
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Server will be available at http://localhost:8000
# API docs at http://localhost:8000/docs
```

### Testing with ngrok (for iOS device testing)

```bash
# In a separate terminal
ngrok http 8000

# Use the ngrok HTTPS URL in your iOS app configuration
```

## Docker Deployment

### Build Docker Image

```bash
# From the backend directory
docker build -t typesafe-backend:latest .
```

### Run Docker Container Locally

```bash
# Run with environment file
docker run -d \
  --name typesafe-backend \
  -p 8000:8000 \
  --env-file .env \
  typesafe-backend:latest

# Check logs
docker logs typesafe-backend

# Stop container
docker stop typesafe-backend
docker rm typesafe-backend
```

### Test Docker Build

```bash
# Build and run
docker build -t typesafe-backend:test .
docker run -p 8000:8000 --env-file .env typesafe-backend:test

# Verify health endpoint
curl http://localhost:8000/health
```

## Cloud Deployment

### Option 1: Render

1. **Create Web Service**
   - Connect GitHub repository
   - Select "Docker" as environment
   - Set environment variables in Render dashboard

2. **Configuration**
   ```yaml
   # render.yaml (optional)
   services:
     - type: web
       name: typesafe-backend
       env: docker
       plan: starter
       healthCheckPath: /health
       envVars:
         - key: ENVIRONMENT
           value: production
         - key: OPENAI_API_KEY
           sync: false
         - key: GEMINI_API_KEY
           sync: false
         - key: SUPABASE_URL
           sync: false
         - key: SUPABASE_KEY
           sync: false
         - key: BACKEND_API_KEY
           sync: false
   ```

### Option 2: Vercel (Serverless)

**Note:** FastAPI on Vercel requires serverless adapter. Alternative recommended for demo.

### Option 3: Railway

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and deploy
railway login
railway init
railway up
```

## TLS/HTTPS Configuration

### Requirements

- **TLS Version:** TLS 1.3 (minimum TLS 1.2)
- **HSTS:** Enabled via middleware (max-age=31536000, includeSubDomains)

### Cloudflare Proxy (Recommended for Demo)

1. Add your domain to Cloudflare
2. Set SSL/TLS to "Full (strict)"
3. Enable "Always Use HTTPS"
4. Enable HSTS in Cloudflare dashboard

### Certificate Management

For self-hosted deployments:

```bash
# Using Let's Encrypt with Certbot
certbot certonly --standalone -d api.typesafe.app

# Configure nginx as reverse proxy with TLS
```

## Production Checklist

- [ ] Environment variables set correctly
- [ ] CORS origins configured (not wildcard *)
- [ ] API keys rotated and stored in secrets manager
- [ ] HTTPS/TLS enabled (TLS 1.3)
- [ ] HSTS headers configured
- [ ] Health check endpoint responding
- [ ] Logging configured and monitored
- [ ] Rate limiting enabled (future story)
- [ ] Backup of Supabase configured

## Monitoring

### Health Check

```bash
curl https://api.typesafe.app/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2025-01-18T12:00:00Z",
  "version": "1.0",
  "environment": "production"
}
```

### Logs

Monitor application logs for:
- Request/response logs with request IDs
- Error traces
- Startup/shutdown events
- Configuration validation

### Metrics to Track

- Response time (p50, p95, p99)
- Request rate (requests per second)
- Error rate (4xx, 5xx responses)
- Health check status

## Scaling Considerations

### Current Architecture (MVP/Demo)

- Single instance deployment
- Burst capacity: 50 RPS
- Suitable for hackathon demo

### Future Scaling

- Horizontal scaling with load balancer
- Caching layer (Redis)
- Database connection pooling
- Rate limiting per API key
- CDN for static content

## Troubleshooting

### Container won't start

```bash
# Check logs
docker logs typesafe-backend

# Common issues:
# - Missing environment variables: Check .env file
# - Port already in use: Change port mapping
# - Build errors: Verify requirements.txt
```

### Configuration validation fails

- Ensure all required environment variables are set
- Check for typos in variable names
- Verify API keys are valid and not expired

### CORS errors

- Add iOS app origin to CORS_ORIGINS
- Verify origin matches exactly (including protocol)
- Check for trailing slashes

## Security Notes

- **Never commit .env files** - Use .env.example as template
- **Rotate API keys regularly** - Especially BACKEND_API_KEY
- **Use secrets manager** - For production deployments
- **Enable rate limiting** - Implement in future story
- **Monitor for abuse** - Track unusual API usage patterns

## Support

For issues or questions:
- Check logs first
- Verify environment configuration
- Test health endpoint
- Review CORS and TLS settings

