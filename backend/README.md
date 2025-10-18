# TypeSafe Backend API

FastAPI backend service for AI-powered scam detection. Handles requests from the iOS keyboard extension and companion app.

## Quick Start

### Prerequisites

- Python 3.11 or higher
- pip (Python package manager)

### Installation

1. **Navigate to backend directory**
   ```bash
   cd backend
   ```

2. **Create and activate virtual environment**
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Setup Supabase Database**
   
   Follow the detailed guide in [SUPABASE_SETUP.md](./SUPABASE_SETUP.md) to:
   - Create your Supabase project
   - Run database migrations
   - Configure environment variables
   
   Quick summary:
   ```bash
   # Create .env file
   cp .env.example .env  # If it exists, or create manually
   
   # Add your credentials
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_KEY=your-service-role-key-here
   OPENAI_API_KEY=your-openai-key-here
   GEMINI_API_KEY=your-gemini-key-here
   BACKEND_API_KEY=your-backend-key-here
   ```

5. **Run the development server**
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

6. **Verify it's running**
   - Open http://localhost:8000 in your browser
   - Visit http://localhost:8000/docs for interactive API documentation
   - Check health: http://localhost:8000/health

## Available Endpoints

- `GET /` - API information
- `GET /health` - Health check endpoint
- `GET /docs` - Interactive API documentation (Swagger UI)
- `GET /redoc` - Alternative API documentation (ReDoc)

## Testing

Run the test suite:

```bash
# Run all tests
pytest tests/ -v

# Run with coverage report
pytest tests/ -v --cov=app --cov-report=term-missing

# Run specific test file
pytest tests/test_main.py -v
```

Current test coverage: **89%**

## Development

### Project Structure

```
backend/
├── app/
│   ├── __init__.py          # Package initialization
│   ├── main.py              # FastAPI app, middleware, endpoints
│   └── config.py            # Configuration management
├── tests/
│   ├── test_config.py       # Configuration tests
│   └── test_main.py         # Application tests
├── requirements.txt         # Python dependencies
├── Dockerfile              # Container configuration
├── DEPLOY.md               # Deployment guide
└── README.md               # This file
```

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `ENVIRONMENT` | Deployment environment (local/staging/production) | No (default: local) |
| `OPENAI_API_KEY` | OpenAI API key for text analysis | Yes |
| `GEMINI_API_KEY` | Google Gemini API key for multimodal analysis | Yes |
| `SUPABASE_URL` | Supabase project URL | Yes |
| `SUPABASE_KEY` | Supabase API key | Yes |
| `BACKEND_API_KEY` | API key for iOS app authentication | Yes |
| `CORS_ORIGINS` | Allowed CORS origins (comma-separated) | No (default: *) |

### Code Quality

```bash
# Run tests with coverage
pytest tests/ --cov=app

# Check for code issues (if you have flake8 installed)
flake8 app/ tests/

# Format code (if you have black installed)
black app/ tests/
```

## Docker

### Build

```bash
docker build -t typesafe-backend:latest .
```

### Run

```bash
docker run -d \
  --name typesafe-backend \
  -p 8000:8000 \
  --env-file .env \
  typesafe-backend:latest
```

### Verify

```bash
# Check logs
docker logs typesafe-backend

# Test health endpoint
curl http://localhost:8000/health
```

## Troubleshooting

### Port already in use

```bash
# Find process using port 8000
lsof -i :8000

# Kill the process or use a different port
uvicorn app.main:app --reload --port 8001
```

### Missing environment variables

If you see `Missing required environment variables` error:
1. Ensure `.env` file exists in the backend directory
2. Verify all required variables are set (see table above)
3. Check for typos in variable names

### Import errors

```bash
# Ensure virtual environment is activated
source venv/bin/activate

# Reinstall dependencies
pip install -r requirements.txt
```

### Tests failing

```bash
# Clean test cache
rm -rf .pytest_cache __pycache__

# Reinstall test dependencies
pip install -r requirements.txt

# Run tests with verbose output
pytest tests/ -vv
```

## Features

✅ **FastAPI Framework** - Modern, fast web framework for building APIs  
✅ **Pydantic Settings** - Type-safe configuration management  
✅ **Request/Response Logging** - Structured logging with request IDs  
✅ **CORS Support** - Configured for iOS app integration  
✅ **Health Checks** - Monitoring endpoint for service status  
✅ **Security Headers** - HSTS for HTTPS enforcement  
✅ **Comprehensive Tests** - 89% code coverage  
✅ **Docker Support** - Production-ready containerization  

## API Documentation

Once the server is running, visit:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Deployment

See [DEPLOY.md](DEPLOY.md) for comprehensive deployment instructions including:
- Cloud deployment (Render, Railway)
- TLS/HTTPS configuration
- Production checklist
- Monitoring and troubleshooting

## License

Part of the TypeSafe project.

