# Epic 8: MCP Agent with Multi-Tool Orchestration

**Epic ID:** 8  
**Epic Title:** MCP Agent with Multi-Tool Orchestration  
**Priority:** P1 (Strategic - Advanced Detection Capabilities)  
**Timeline:** Week 8-10 (3 weeks)  
**Dependencies:** Epic 1 (Backend API), Epic 7 (Real-Time Progress Updates), Epic 3 (Companion App)

**Status:** 📝 DRAFT - Ready for Review

---

## Executive Summary

**TL;DR:** This epic transforms TypeSafe from a "single AI guess" system into an intelligent investigative agent that uses multiple specialized tools to gather evidence before making scam verdicts. Think of it as upgrading from a single doctor's opinion to a team of specialists consulting together.

**Key Changes:**
- 🔧 Add 4 specialized tools: Scam Database, Web Search (Exa), Domain Reputation, Phone Validator
- 🤖 Implement agent orchestration layer that combines tool outputs intelligently
- 📊 Provide transparent evidence breakdown to users ("Found in database + 12 web reports")
- ⚡ Smart routing: Simple scans stay fast (2s), complex scans get deep analysis (10-30s)

**Business Impact:**
- Reduce false negatives by 40% (catch more scams)
- Build unprecedented user trust through evidence transparency
- Differentiate from competitors who use single-AI systems
- Modest cost increase: ~$0.02/scan (vs $0.002 currently) for complex scans

**Timeline:** 3 weeks | **Effort:** 120-150 hours | **Team:** Backend (2), iOS (1), DevOps (0.5)

---

## Epic Goal

Transform TypeSafe's scam detection from a single-AI-call system into an **intelligent agent** that orchestrates multiple tools (database lookups, web searches, domain reputation checks) to provide comprehensive, evidence-based scam assessments with full transparency into its reasoning process.

---

## Epic Description

**Current Limitation:** 

TypeSafe currently relies on a single AI provider (Gemini or Groq) making a one-shot decision about whether content is a scam. This approach:
- ❌ Cannot verify claims against external data sources
- ❌ Misses scams that require web searches (new scam numbers/URLs)
- ❌ Has no memory of previously reported scams
- ❌ Cannot cross-reference multiple signals
- ❌ Limited to what the AI "knows" at training cutoff

**MCP Agent Vision:**

An **agentic system** that:
1. **Extracts entities** from images/text (phone numbers, URLs, email addresses, payment details)
2. **Uses multiple tools** to investigate each entity:
   - 📊 **Scam Database Tool** - Check internal database of reported scams
   - 🔍 **Exa Search Tool** - Web search for scam reports, complaints, warnings
   - 🌐 **Domain Reputation Tool** - Check URL safety, SSL certificates, domain age
   - 📱 **Phone Number Validator Tool** - Validate country codes, carrier info
   - 🏦 **Payment Validator Tool** - Check if payment methods are suspicious
3. **Reasons over evidence** - Agent combines tool outputs to make informed decisions
4. **Explains its work** - Full transparency: "Found 3 scam reports via Exa, number in database"

**Key Innovation:** Move from "AI guesses" to "Agent investigates with evidence"

---

## Problem Statement

### Current System Gaps

| Scenario | Current Behavior | Desired Behavior |
|----------|------------------|------------------|
| **New scam number** | AI says "unknown" (not in training data) | Agent searches web, finds complaints, flags as scam |
| **Suspicious URL** | AI detects phishing patterns | Agent checks domain reputation, SSL cert, recent reports |
| **Legitimate-looking scam** | AI might miss subtle cues | Agent cross-references multiple tools, finds inconsistencies |
| **User wants proof** | AI explanation only | Agent shows: "Found in scam DB + 5 web reports + suspicious domain" |
| **Multi-signal scams** | AI processes one view | Agent combines: foreign number + new domain + urgent language |

### Real-World Example

**Screenshot contains:** "URGENT: Your bank account compromised. Call +1-800-555-FAKE immediately."

**Current System:**
- Gemini analyzes → "High risk - urgency tactics + phone number"
- ✅ Correct, but shallow reasoning

**MCP Agent System:**
- Step 1: Extract entity: `+1-800-555-FAKE`
- Step 2: **Database Tool** → Found in scam database (reported 47 times)
- Step 3: **Exa Search** → "800-555-FAKE scam complaints reddit" → 12 results
- Step 4: **Phone Validator** → Invalid number (fake vanity)
- Step 5: **Agent Reasoning** → "HIGH RISK: Number in scam DB (47 reports), 12 web complaints, invalid phone format"
- ✅ **Evidence-based verdict with sources**

---

## Architecture Overview

### System Design

```
┌──────────────────────────────────────────────────────────────────────┐
│                         FastAPI Backend                               │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  POST /scan-image                                                    │
│         │                                                             │
│         ├─▶ [Entity Extraction] ──▶ Found: 2 phone numbers, 1 URL  │
│         │                                                             │
│         └─▶ [Route Decision]                                         │
│                   │                                                   │
│         ┌─────────┴─────────┐                                        │
│         │                   │                                         │
│    Simple scan?        Complex scan?                                 │
│    (no entities)      (has entities)                                 │
│         │                   │                                         │
│         ▼                   ▼                                         │
│  [Fast Path]         [Enqueue to Celery]                            │
│  Gemini only               │                                         │
│  (1-2 seconds)             │                                         │
│                            ▼                                         │
│              ┌─────────────────────────────┐                        │
│              │   MCP Agent Worker (Celery) │                        │
│              ├─────────────────────────────┤                        │
│              │                              │                        │
│              │  🔹 For each entity:        │                        │
│              │                              │                        │
│              │  Tool 1: Scam Database      │                        │
│              │    ▸ Query: +1-800-555-1234│                        │
│              │    ▸ Result: Found (47 reports)                      │
│              │                              │                        │
│              │  Tool 2: Exa Web Search     │                        │
│              │    ▸ Query: "800-555-1234 scam"                      │
│              │    ▸ Result: 12 complaints  │                        │
│              │                              │                        │
│              │  Tool 3: Phone Validator    │                        │
│              │    ▸ Result: Invalid format │                        │
│              │                              │                        │
│              │  🧠 Agent Reasoning:        │                        │
│              │    Combine all tool outputs │                        │
│              │    Generate verdict + proof │                        │
│              │                              │                        │
│              └──────────────┬───────────────┘                        │
│                            │                                         │
│                            ▼                                         │
│              ┌─────────────────────────────┐                        │
│              │   Redis Pub/Sub Channel     │                        │
│              │   (Progress Broadcasting)   │                        │
│              └──────────────┬───────────────┘                        │
│                            │                                         │
│                            ▼                                         │
│  WebSocket: /ws/agent-progress/{task_id}                           │
│         │                                                             │
│         └──▶ Stream to iOS App                                      │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **Task Queue** | Celery + Redis | Battle-tested, Python-native, easy retry logic |
| **Message Broker** | Redis Pub/Sub | Fast, in-memory, perfect for progress updates |
| **Agent Framework** | Custom (FastAPI + Celery) | Full control, integrates with existing stack |
| **Entity Extraction** | spaCy + regex patterns | Fast, accurate, no API calls needed |
| **Scam Database** | Supabase (Postgres) | Already in stack, add `scam_reports` table |
| **Web Search** | Exa API | Best for scam searches (better than Google) |
| **Domain Reputation** | VirusTotal API | Industry standard, comprehensive data |
| **Phone Validation** | libphonenumber + custom logic | Free, accurate, works offline |

---

## User Stories

### Story 8.1: Celery & Redis Infrastructure Setup

**As a** backend developer,  
**I want** Celery task queue and Redis message broker configured,  
**so that** I can run long-running agent tasks asynchronously.

**Acceptance Criteria:**

1. Redis server running locally (port 6379) and in production
2. Celery installed with Redis as broker: `celery -A app.agents.worker worker --loglevel=info`
3. Celery tasks can be enqueued from FastAPI endpoints
4. Task status tracking: PENDING → STARTED → SUCCESS/FAILURE
5. Automatic retry logic for failed tasks (3 retries with exponential backoff)
6. Task results stored in Redis with 1-hour TTL
7. Celery monitoring with Flower (optional): `celery -A app.agents.worker flower`
8. Health check endpoint for Celery worker status
9. Unit tests verify task enqueue/dequeue flow
10. Docker Compose config includes Redis and Celery worker

**Technical Implementation:**
```python
# backend/app/agents/worker.py
from celery import Celery

celery_app = Celery(
    'typesafe_agent',
    broker='redis://localhost:6379/0',
    backend='redis://localhost:6379/1'
)

celery_app.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
)
```

**Dependencies:**
```txt
celery[redis]==5.3.4
redis==5.0.1
flower==2.0.1  # Optional monitoring
```

**Priority:** P0 (Foundation)

---

### Story 8.2: Entity Extraction Service

**As an** MCP agent,  
**I want** to extract structured entities from OCR text and images,  
**so that** I can investigate specific scam indicators using tools.

**Acceptance Criteria:**

1. `EntityExtractor` service created in `app/services/entity_extractor.py`
2. Extracts phone numbers: international format, vanity numbers, various separators
3. Extracts URLs: http/https, shortened URLs (bit.ly, etc.), domains only
4. Extracts email addresses: various formats, handles obfuscation
5. Extracts payment details: account numbers, Bitcoin addresses, wire instructions
6. Extracts monetary amounts: $500, USD 1000, etc. with currency detection
7. Returns structured data: `{"phones": [...], "urls": [...], "emails": [...], "payments": [...]}`
8. Handles multi-language text (English focus, expandable)
9. Performance: < 100ms for typical OCR text (500 chars)
10. Unit tests with diverse real-world examples (100+ test cases)

**Technical Implementation:**
```python
# backend/app/services/entity_extractor.py
import re
import phonenumbers
from typing import Dict, List

class EntityExtractor:
    def extract(self, text: str) -> Dict[str, List[str]]:
        return {
            "phones": self._extract_phones(text),
            "urls": self._extract_urls(text),
            "emails": self._extract_emails(text),
            "payments": self._extract_payment_details(text),
            "amounts": self._extract_monetary_amounts(text)
        }
    
    def _extract_phones(self, text: str) -> List[str]:
        # Use phonenumbers library + custom regex
        phones = []
        for match in phonenumbers.PhoneNumberMatcher(text, "US"):
            phones.append(phonenumbers.format_number(
                match.number, 
                phonenumbers.PhoneNumberFormat.E164
            ))
        return phones
```

**Test Cases:**
- `+1 (800) 555-1234` → `+18005551234`
- `Call 1-800-FLOWERS` → Vanity number extraction
- `bit.ly/abc123` → URL normalization
- `john@example.com` → Email extraction

**Priority:** P0 (Core functionality)

---

### Story 8.3: Scam Database Tool

**As an** MCP agent,  
**I want** to query a database of reported scams,  
**so that** I can instantly identify known scam entities.

**Acceptance Criteria:**

1. New Supabase table: `scam_reports`
2. Schema:
   ```sql
   - id (bigserial)
   - entity_type (enum: phone, url, email, payment)
   - entity_value (text, indexed)
   - report_count (int, number of reports)
   - risk_score (numeric 0-100)
   - first_seen (timestamptz)
   - last_reported (timestamptz)
   - evidence (jsonb, links to reports, sources)
   - verified (boolean, manually verified by admin)
   ```
3. `ScamDatabaseTool` class with methods: `check_phone()`, `check_url()`, `check_email()`
4. Returns: `{"found": true, "report_count": 47, "risk_score": 95, "evidence": [...]}`
5. Query optimization: Indexed lookups < 10ms
6. Handles fuzzy matching for URLs (domain only vs full URL)
7. Phone number normalization before lookup (E164 format)
8. Bulk check support: check multiple entities in one query
9. Admin API endpoint: `POST /admin/report-scam` for manual submissions
10. Migration script to seed with known scam numbers/URLs

**Technical Implementation:**
```python
# backend/app/agents/tools/scam_database.py
from app.db.client import get_supabase_client

class ScamDatabaseTool:
    def check_phone(self, phone: str) -> Dict[str, Any]:
        supabase = get_supabase_client()
        result = supabase.table('scam_reports').select('*').eq(
            'entity_type', 'phone'
        ).eq(
            'entity_value', phone
        ).maybe_single().execute()
        
        if result.data:
            return {
                "found": True,
                "report_count": result.data['report_count'],
                "risk_score": result.data['risk_score'],
                "evidence": result.data['evidence']
            }
        return {"found": False}
```

**Seed Data Sources:**
- FTC reported scam numbers (public data)
- PhishTank URLs (open source phishing database)
- Scam Detector API (if available)

**Priority:** P0 (High-impact tool)

---

### Story 8.4: Exa Web Search Tool Integration

**As an** MCP agent,  
**I want** to search the web for scam reports and complaints,  
**so that** I can find evidence of scams not yet in our database.

**Acceptance Criteria:**

1. Exa API key configured in environment variables
2. `ExaSearchTool` class created in `app/agents/tools/exa_search.py`
3. Search queries optimized for scam detection:
   - `"{phone_number} scam complaints"`
   - `"{url} phishing reports"`
   - `"is {domain} legitimate"`
4. Returns: List of search results with titles, snippets, URLs
5. Filters results: Reddit posts, complaint sites, BBB reports prioritized
6. Rate limiting: Max 10 searches per scan (cost control)
7. Caching: Cache results for 24 hours (same entity)
8. Timeout: 5 seconds per search (fail gracefully)
9. Result scoring: Ranks results by relevance and source credibility
10. Unit tests with mock Exa responses

**Technical Implementation:**
```python
# backend/app/agents/tools/exa_search.py
import httpx
from typing import List, Dict

class ExaSearchTool:
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://api.exa.ai/search"
    
    async def search_scam_reports(
        self, 
        entity: str, 
        entity_type: str
    ) -> List[Dict[str, str]]:
        query = self._build_query(entity, entity_type)
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                self.base_url,
                json={
                    "query": query,
                    "num_results": 10,
                    "use_autoprompt": True,
                    "category": "discussion"  # Prioritize forums/complaints
                },
                headers={"x-api-key": self.api_key},
                timeout=5.0
            )
        
        results = response.json()
        return self._parse_results(results)
    
    def _build_query(self, entity: str, entity_type: str) -> str:
        templates = {
            "phone": f'"{entity}" scam complaints OR fraud reports',
            "url": f'"{entity}" phishing OR scam warning',
            "email": f'"{entity}" spam OR scam reports'
        }
        return templates.get(entity_type, f'"{entity}" scam')
```

**Cost Optimization:**
- Exa pricing: ~$5 per 1000 searches
- With 10 searches/scan, 100 scans = $5
- Caching reduces redundant searches by ~60%

**Priority:** P0 (Critical for external validation)

---

### Story 8.5: Domain Reputation Tool

**As an** MCP agent,  
**I want** to check domain reputation and safety scores,  
**so that** I can identify malicious URLs and phishing sites.

**Acceptance Criteria:**

1. `DomainReputationTool` class created in `app/agents/tools/domain_reputation.py`
2. Checks multiple signals:
   - Domain age (WHOIS lookup): New domains = suspicious
   - SSL certificate: Valid, expired, or missing
   - VirusTotal scan: Malicious reports from 70+ antivirus engines
   - DNS records: Suspicious patterns (frequent IP changes)
3. Returns comprehensive report:
   ```json
   {
     "domain": "example-phishing.com",
     "age_days": 7,
     "ssl_valid": false,
     "virustotal_score": 15,  // 15 engines flagged as malicious
     "risk_level": "high"
   }
   ```
4. Free tier friendly: Uses Google Safe Browsing API (free) as fallback
5. Caching: Domain reputation cached for 7 days
6. Handles subdomains: Checks both subdomain and root domain
7. Performance: < 2 seconds per domain check
8. Graceful degradation if APIs unavailable

**Technical Implementation:**
```python
# backend/app/agents/tools/domain_reputation.py
import httpx
import whois
from datetime import datetime

class DomainReputationTool:
    def __init__(self, virustotal_api_key: str):
        self.vt_api_key = virustotal_api_key
    
    async def check_domain(self, url: str) -> Dict[str, Any]:
        domain = self._extract_domain(url)
        
        # Parallel checks
        age_check = self._check_domain_age(domain)
        ssl_check = self._check_ssl(domain)
        vt_check = await self._check_virustotal(domain)
        
        risk_score = self._calculate_risk(age_check, ssl_check, vt_check)
        
        return {
            "domain": domain,
            "age_days": age_check['age_days'],
            "ssl_valid": ssl_check['valid'],
            "virustotal_malicious": vt_check['malicious_count'],
            "risk_level": risk_score
        }
    
    def _check_domain_age(self, domain: str) -> Dict:
        try:
            w = whois.whois(domain)
            created = w.creation_date
            if isinstance(created, list):
                created = created[0]
            age = (datetime.now() - created).days
            return {"age_days": age, "suspicious": age < 30}
        except:
            return {"age_days": None, "suspicious": True}
```

**API Requirements:**
- VirusTotal API: Free tier (4 requests/min) or paid
- Google Safe Browsing: Free, 10,000 requests/day
- WHOIS: Free, no rate limits

**Priority:** P1 (Important for URL scams)

---

### Story 8.6: Phone Number Validator Tool

**As an** MCP agent,  
**I want** to validate phone numbers and detect suspicious patterns,  
**so that** I can identify fake or spoofed numbers.

**Acceptance Criteria:**

1. `PhoneValidatorTool` class using `phonenumbers` library
2. Validates:
   - Valid country code and format
   - Number type: mobile, landline, VoIP, toll-free
   - Carrier information (if available)
   - Geographic location match with claimed sender
3. Detects suspicious patterns:
   - Invalid vanity numbers (1-800-FAKEBANK)
   - Foreign country codes when sender claims to be local
   - Known scam number patterns (all zeros, repeating digits)
4. Returns structured report:
   ```json
   {
     "number": "+18005551234",
     "valid": true,
     "country": "US",
     "type": "toll_free",
     "carrier": "Unknown",
     "suspicious": false,
     "reason": null
   }
   ```
5. Works offline (no API calls, library-based)
6. Supports 200+ countries
7. Performance: < 10ms per number

**Technical Implementation:**
```python
# backend/app/agents/tools/phone_validator.py
import phonenumbers
from phonenumbers import geocoder, carrier

class PhoneValidatorTool:
    def validate(self, phone: str) -> Dict[str, Any]:
        try:
            parsed = phonenumbers.parse(phone, None)
            
            return {
                "number": phonenumbers.format_number(
                    parsed, 
                    phonenumbers.PhoneNumberFormat.E164
                ),
                "valid": phonenumbers.is_valid_number(parsed),
                "country": geocoder.country_name_for_number(parsed, "en"),
                "type": self._get_number_type(parsed),
                "carrier": carrier.name_for_number(parsed, "en"),
                "suspicious": self._check_suspicious(parsed)
            }
        except:
            return {"valid": False, "suspicious": True}
    
    def _check_suspicious(self, parsed) -> bool:
        # Check for patterns: all same digit, sequential, etc.
        national_num = str(parsed.national_number)
        return (
            len(set(national_num)) <= 2 or  # All same digits
            national_num == '1234567890'    # Sequential
        )
```

**Priority:** P1 (Fast, high-value checks)

---

### Story 8.7: MCP Agent Task Orchestration

**As an** MCP agent worker,  
**I want** to orchestrate multiple tools in a logical sequence,  
**so that** I can build comprehensive evidence for scam detection.

**Acceptance Criteria:**

1. `MCPAgent` class created in `app/agents/mcp_agent.py`
2. Agent workflow:
   - Step 1: Extract entities from text/image
   - Step 2: For each entity, run relevant tools in parallel
   - Step 3: Collect all tool outputs
   - Step 4: Reason over evidence using LLM (Gemini/GPT-4)
   - Step 5: Generate final verdict with evidence citations
3. Tool routing logic:
   - Phone numbers → Scam DB + Exa Search + Phone Validator
   - URLs → Scam DB + Domain Reputation + Exa Search
   - Emails → Scam DB + Exa Search
4. Progress publishing at each step (Redis Pub/Sub)
5. Error handling: Continue if individual tools fail
6. Timeout: Max 30 seconds total (fail gracefully)
7. Result includes:
   - Risk level (low/medium/high)
   - Confidence score
   - Evidence list (tool outputs)
   - Reasoning explanation
8. Unit tests with mocked tools

**Technical Implementation:**
```python
# backend/app/agents/mcp_agent.py
from celery import Task
from app.agents.worker import celery_app
from app.agents.tools.scam_database import ScamDatabaseTool
from app.agents.tools.exa_search import ExaSearchTool
from app.services.entity_extractor import EntityExtractor

@celery_app.task(bind=True, max_retries=3)
def analyze_with_mcp_agent(
    self: Task,
    task_id: str,
    image_data: bytes,
    ocr_text: str,
    user_country: str
) -> Dict[str, Any]:
    """Main MCP agent task"""
    
    # Initialize tools
    scam_db = ScamDatabaseTool()
    exa_search = ExaSearchTool(os.getenv('EXA_API_KEY'))
    extractor = EntityExtractor()
    
    # Progress tracking
    progress_pub = RedisPublisher(task_id)
    
    # Step 1: Extract entities
    progress_pub.publish("Extracting entities from text...")
    entities = extractor.extract(ocr_text)
    progress_pub.publish(f"Found {len(entities['phones'])} phone numbers, {len(entities['urls'])} URLs")
    
    # Step 2: Run tools for each entity
    evidence = []
    
    for phone in entities['phones']:
        progress_pub.publish(f"Checking phone number: {phone}")
        
        # Run tools in parallel
        db_result = scam_db.check_phone(phone)
        exa_result = await exa_search.search_scam_reports(phone, 'phone')
        
        evidence.append({
            "entity": phone,
            "type": "phone",
            "database": db_result,
            "web_search": exa_result
        })
    
    for url in entities['urls']:
        progress_pub.publish(f"Checking URL: {url}")
        # Similar tool orchestration...
    
    # Step 3: Agent reasoning
    progress_pub.publish("Agent analyzing evidence...")
    final_verdict = await agent_reasoning(evidence, ocr_text)
    
    progress_pub.publish("Analysis complete!")
    return final_verdict
```

**Priority:** P0 (Core agent logic)

---

### Story 8.8: Agent Reasoning with LLM

**As an** MCP agent,  
**I want** to use an LLM to reason over collected evidence,  
**so that** I can generate intelligent verdicts with explanations.

**Acceptance Criteria:**

1. `AgentReasoner` class using GPT-4 or Gemini for reasoning
2. Input: All tool outputs + original OCR text
3. Prompt engineering:
   - "You are a scam detection agent. Analyze the following evidence..."
   - Provides tool outputs in structured format
   - Asks for verdict + reasoning + confidence
4. Output: JSON with `risk_level`, `confidence`, `explanation`, `evidence_used`
5. Handles conflicting evidence gracefully (e.g., DB says safe, Exa finds complaints)
6. Weighs evidence by reliability: DB > VirusTotal > Exa > Phone Validator
7. Timeout: 5 seconds (fallback to heuristic scoring)
8. Unit tests with diverse evidence scenarios

**Prompt Example:**
```
You are a scam detection agent. Analyze this evidence:

OCR Text: "Call +1-800-555-FAKE for your refund"

Evidence collected:
1. Scam Database: FOUND - +18005551234 reported 47 times
2. Exa Search: Found 12 web results mentioning "800-555-FAKE scam"
3. Phone Validator: Invalid vanity number format

Based on this evidence, determine:
- Risk level (low/medium/high)
- Confidence (0-100%)
- Explanation (cite specific evidence)
```

**Priority:** P0 (Critical for intelligent verdicts)

---

### Story 8.9: WebSocket Progress Streaming

**As a** frontend client,  
**I want** to receive real-time updates via WebSocket,  
**so that** I can display agent progress and tool executions to users.

**Acceptance Criteria:**

1. WebSocket endpoint: `ws://api/ws/agent-progress/{task_id}`
2. Subscribes to Redis Pub/Sub channel for task progress
3. Streams messages to client as JSON:
   ```json
   {
     "step": "exa_search",
     "tool": "exa",
     "message": "Searching web for +1-800-555-1234...",
     "percent": 45
   }
   ```
4. Handles client disconnection gracefully (cleanup)
5. Closes WebSocket automatically when task completes
6. Sends heartbeat every 15 seconds to keep connection alive
7. Error messages streamed to client with user-friendly text
8. Integration tests verify WebSocket streaming

**Technical Implementation:**
```python
# backend/app/main.py
from fastapi import WebSocket
import redis.asyncio as redis

@app.websocket("/ws/agent-progress/{task_id}")
async def agent_progress_stream(websocket: WebSocket, task_id: str):
    await websocket.accept()
    
    redis_client = await redis.from_url("redis://localhost")
    pubsub = redis_client.pubsub()
    await pubsub.subscribe(f'agent_progress:{task_id}')
    
    try:
        async for message in pubsub.listen():
            if message['type'] == 'message':
                await websocket.send_text(message['data'])
                
                # Check if task completed
                data = json.loads(message['data'])
                if data.get('step') == 'completed':
                    break
    finally:
        await pubsub.unsubscribe(f'agent_progress:{task_id}')
        await redis_client.close()
        await websocket.close()
```

**Priority:** P0 (Essential for transparency)

---

### Story 8.10: Smart Routing Logic

**As a** backend API,  
**I want** to intelligently route scans to fast path or agent path,  
**so that** simple scans remain fast while complex scans get deep analysis.

**Acceptance Criteria:**

1. Modified `/scan-image` endpoint with routing logic
2. Routing decision based on:
   - **Fast path** (Gemini only): No entities extracted, or generic content
   - **Agent path** (Celery): Phone numbers, URLs, emails, or payment details detected
3. Returns different response schemas:
   - Fast path: Immediate result (1-2s)
   - Agent path: `task_id` + WebSocket URL (5-30s)
4. Client can poll task status: `GET /agent-task/{task_id}/status`
5. Metrics tracked: % of scans using agent vs fast path
6. Feature flag: `ENABLE_MCP_AGENT` (default: true in production)
7. Fallback: If Celery worker down, use fast path
8. Integration tests for both paths

**Technical Implementation:**
```python
# backend/app/main.py
@app.post("/scan-image")
async def scan_image(
    image: UploadFile,
    ocr_text: str = Form(...),
    session_id: str = Form(...)
):
    # Quick entity extraction (lightweight check)
    extractor = EntityExtractor()
    entities = extractor.extract(ocr_text)
    
    has_entities = (
        len(entities['phones']) > 0 or
        len(entities['urls']) > 0 or
        len(entities['emails']) > 0
    )
    
    if has_entities and settings.ENABLE_MCP_AGENT:
        # Route to agent (async)
        task_id = str(uuid.uuid4())
        analyze_with_mcp_agent.delay(
            task_id=task_id,
            image_data=await image.read(),
            ocr_text=ocr_text,
            user_country=get_user_country()
        )
        
        return {
            "type": "agent",
            "task_id": task_id,
            "ws_url": f"ws://api.typesafe.com/ws/agent-progress/{task_id}",
            "estimated_time": "5-30 seconds"
        }
    else:
        # Fast path (existing logic)
        result = await analyze_image(
            image_data=await image.read(),
            ocr_text=ocr_text
        )
        
        return {
            "type": "simple",
            "result": result
        }
```

**Priority:** P0 (Critical for performance)

---

### Story 8.11: iOS App Agent Progress Display

**As a** companion app user,  
**I want** to see detailed agent progress with tool executions,  
**so that** I understand how the agent is investigating my screenshot.

**Acceptance Criteria:**

1. New UI component: `AgentProgressView` in SwiftUI
2. Displays:
   - Current step (e.g., "Checking scam database...")
   - Tool icon + name (database, web search, domain check)
   - Progress bar (0-100%)
   - Tool results as they complete (✅ "Found in database: 47 reports")
3. WebSocket connection management:
   - Connects when agent scan initiated
   - Handles reconnection if connection drops
   - Cleans up on view dismissal
4. Animations: Smooth transitions between steps
5. Final result display with evidence breakdown:
   ```
   🔴 HIGH RISK DETECTED
   
   Evidence:
   ✅ Scam Database: Found (47 reports)
   ✅ Web Search: 12 complaints found
   ✅ Phone Validator: Invalid format
   
   Agent Reasoning:
   "This phone number is confirmed in our scam database with 47 previous reports..."
   ```
6. Accessibility: VoiceOver support for all progress updates
7. Error states: Shows friendly message if agent fails

**UI Mockup:**
```
┌────────────────────────────────────┐
│  🧠 Agent Analyzing Screenshot     │
│                                    │
│  ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░  60%         │
│                                    │
│  ✅ Extracted Entities             │
│     • 1 phone number               │
│     • 1 URL                        │
│                                    │
│  🔄 Checking Scam Database...      │
│  ⏳ Running Web Search...          │
│  ⏳ Validating Phone Number...     │
│                                    │
└────────────────────────────────────┘
```

**Priority:** P1 (Essential UX)

---

### Story 8.12: Database Seeding & Maintenance

**As a** system administrator,  
**I want** tools to seed and maintain the scam database,  
**so that** the agent has up-to-date scam intelligence.

**Acceptance Criteria:**

1. Admin API endpoints:
   - `POST /admin/scam-reports` - Add new scam report
   - `GET /admin/scam-reports?type=phone` - List reports
   - `PATCH /admin/scam-reports/{id}` - Update report (verify, update score)
   - `DELETE /admin/scam-reports/{id}` - Remove false positive
2. Seed script: `backend/scripts/seed_scam_db.py`
3. Data sources for seeding:
   - FTC reported scam numbers (CSV import)
   - PhishTank URLs (JSON API)
   - Community submissions via form
4. Automated updates: Daily cron job to fetch new PhishTank URLs
5. Deduplication: Prevent duplicate entries
6. Archival: Archive reports > 1 year old (move to `archived_scam_reports`)
7. Analytics dashboard: Show top scam numbers, trending scams
8. Rate limiting on submission endpoint (prevent spam)

**Priority:** P1 (Operational requirement)

---

## Technical Architecture Deep Dive

### Data Flow Diagram

```
1. User takes screenshot
         │
         ▼
2. iOS App → POST /scan-image
         │
         ├─▶ [Fast Path: No entities]
         │   → Gemini analysis → Result (2s)
         │
         └─▶ [Agent Path: Has entities]
             → Enqueue Celery task → Return task_id
                    │
                    ▼
3. Celery Worker picks up task
         │
         ├─▶ Extract entities (phones, URLs, emails)
         ├─▶ For each entity:
         │   ├─▶ Tool: Scam Database
         │   ├─▶ Tool: Exa Search
         │   ├─▶ Tool: Domain Reputation
         │   └─▶ Tool: Phone Validator
         │
         ├─▶ Publish progress to Redis (each step)
         └─▶ Agent Reasoning (LLM combines evidence)
                    │
                    ▼
4. iOS App ← WebSocket stream ← Redis Pub/Sub
   Updates UI in real-time:
   - "Checking database..."
   - "Found in database: 47 reports"
   - "Searching web..."
   - "Found 12 complaints"
   - "Analysis complete: HIGH RISK"
         │
         ▼
5. Final result stored in Supabase
   User sees detailed evidence breakdown
```

### Database Schema

**New Tables:**

```sql
-- Scam reports table
CREATE TABLE scam_reports (
  id BIGSERIAL PRIMARY KEY,
  entity_type TEXT NOT NULL,  -- 'phone', 'url', 'email', 'payment'
  entity_value TEXT NOT NULL, -- Normalized value (E164 for phones, lowercase domain for URLs)
  report_count INT DEFAULT 1,
  risk_score NUMERIC(5,2),    -- 0-100 score
  first_seen TIMESTAMPTZ DEFAULT NOW(),
  last_reported TIMESTAMPTZ DEFAULT NOW(),
  evidence JSONB,             -- Links to sources, complaint details
  verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_scam_reports_entity ON scam_reports(entity_type, entity_value);
CREATE INDEX idx_scam_reports_risk_score ON scam_reports(risk_score DESC);

-- Agent task results
CREATE TABLE agent_scan_results (
  id BIGSERIAL PRIMARY KEY,
  task_id UUID UNIQUE NOT NULL,
  session_id UUID REFERENCES sessions(session_id),
  entities_found JSONB,       -- Extracted entities
  tool_results JSONB,         -- All tool outputs
  agent_reasoning TEXT,       -- LLM reasoning
  risk_level TEXT,
  confidence NUMERIC,
  evidence_summary JSONB,     -- Structured evidence for UI
  processing_time_ms INT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_agent_scan_results_session ON agent_scan_results(session_id);
CREATE INDEX idx_agent_scan_results_task_id ON agent_scan_results(task_id);
```

### Performance Benchmarks

| Scenario | Fast Path | Agent Path |
|----------|-----------|------------|
| **No entities** | 1-2s | N/A |
| **1 phone number** | N/A | 5-8s |
| **1 URL** | N/A | 6-10s |
| **Phone + URL** | N/A | 8-15s |
| **Complex (5+ entities)** | N/A | 15-30s |

**Optimization Strategies:**
- Parallel tool execution (not sequential)
- Aggressive caching (Exa results, domain reputation)
- Timeout guards (no tool > 5s)
- Fast-path fallback if agent unavailable

---

## Cost Analysis

### API Costs per Scan

| Tool | Cost per Call | Avg Calls per Scan | Total |
|------|---------------|-------------------|-------|
| **Exa Search** | $0.005 | 2-3 | $0.01-0.015 |
| **VirusTotal** | $0 (free tier) | 1 | $0 |
| **Gemini (reasoning)** | $0.001 | 1 | $0.001 |
| **Scam Database** | $0 (self-hosted) | 3 | $0 |
| **Phone Validator** | $0 (library) | 2 | $0 |
| **Redis** | $0 (self-hosted) | N/A | $0 |
| **Total per scan** | - | - | **~$0.02** |

**Monthly Costs (1000 agent scans):**
- Exa: $10-15
- VirusTotal: $0 (free tier: 500 requests/day)
- Redis: $10 (hosted, or $0 if self-hosted)
- Celery worker: $20 (small VM)
- **Total: ~$40-50/month**

**Cost Optimization:**
- Use free tier APIs where possible
- Cache aggressively (reduce redundant API calls)
- Implement daily Exa budget cap

---

## Testing Strategy

### Unit Tests

**Coverage Target: >90%**

- `EntityExtractor`: 100+ test cases with diverse formats
  - Phone numbers: international, vanity, various separators
  - URLs: shortened, obfuscated, with/without protocol
  - Emails: various formats, plus/dot addressing
  - Edge cases: empty strings, very long text, Unicode characters

- `ScamDatabaseTool`: Mock database queries
  - Found/not found scenarios
  - Bulk check performance
  - Database connection errors

- `ExaSearchTool`: Mock API responses
  - Successful searches with results
  - Empty results
  - API timeout/failure scenarios
  - Rate limiting handling

- `DomainReputationTool`: Mock WHOIS/VirusTotal
  - Valid/invalid/expired SSL certificates
  - New vs old domains
  - Malicious vs clean VirusTotal scores

- `PhoneValidatorTool`: Library-based validation
  - Valid/invalid formats
  - Suspicious pattern detection
  - International number support

- `MCPAgent`: End-to-end with all mocked tools
  - Simple scan (no entities) → fast path
  - Complex scan (multiple entities) → agent path
  - Partial tool failures (continue with available data)
  - Timeout scenarios

### Integration Tests

**Coverage Target: >80%**

- Celery task enqueue/dequeue with real Redis
- Redis Pub/Sub messaging reliability
- WebSocket connection and streaming end-to-end
- Database read/write operations with test database
- Tool orchestration with real APIs (staging only, rate-limited)
- Smart routing logic (fast vs agent path decision)
- Error propagation and recovery

### Load Testing

**Performance Benchmarks:**

- 100 concurrent scans (agent path)
- 1000 concurrent scans (mixed fast/agent)
- Sustained load: 10 scans/second for 1 hour
- Redis memory usage under load
- Celery worker CPU/memory consumption
- Database query performance (scam_reports table)

**Success Criteria:**
- p95 latency < 30s for agent scans
- p95 latency < 3s for fast path scans
- No memory leaks after 1000+ scans
- Celery worker handles 5+ concurrent tasks

### Manual Testing

**QA Test Plan:**

- Real scam screenshots (50+ diverse test cases):
  - Phishing emails
  - Fake bank messages
  - Lottery scams
  - Package delivery scams
  - Romance scams
  - Tech support scams

- Performance benchmarking (100 concurrent scans)
- WebSocket reliability testing (connection drops, timeouts)
- iOS app progress display (visual QA)
- Error handling (network failures, API errors)
- Cost tracking (verify no runaway API spend)

**User Acceptance Testing:**

- 20 internal users testing for 1 week
- Feedback form: clarity, trust, usefulness
- A/B test: Agent vs Fast path user preference
- Net Promoter Score (NPS) measurement

---

## Monitoring & Observability

### Key Metrics to Track

**Performance Metrics:**
- Agent scan latency (p50, p95, p99)
- Fast path scan latency (baseline)
- Tool execution times (individual tools)
- Celery worker queue depth
- Redis memory usage
- Database query latency (scam_reports lookups)

**Business Metrics:**
- Agent vs Fast path usage ratio
- Scam detection accuracy (true/false positives/negatives)
- User confidence scores (feedback surveys)
- Evidence clarity ratings (user feedback)
- Feature adoption rate

**Cost Metrics:**
- Exa API calls per day + cost
- VirusTotal API calls per day
- Gemini reasoning API cost
- Redis hosting cost
- Celery worker compute cost
- Total cost per scan (agent vs fast path)

**Reliability Metrics:**
- Celery worker uptime (%)
- Tool success/failure rates (per tool)
- WebSocket connection success rate
- Error rate by error type
- Fallback to fast path frequency

### Logging Strategy

**Structured Logging (JSON format):**

```python
# Example log entry for agent task
{
  "timestamp": "2025-10-18T10:30:45Z",
  "level": "INFO",
  "service": "mcp_agent",
  "task_id": "abc-123",
  "event": "agent_scan_completed",
  "duration_ms": 12340,
  "entities_found": {"phones": 1, "urls": 1},
  "tools_used": ["scam_db", "exa_search", "phone_validator"],
  "risk_level": "high",
  "confidence": 95,
  "user_country": "US"
}
```

**Log Levels:**
- `DEBUG`: Tool execution details, entity extraction
- `INFO`: Task start/complete, routing decisions
- `WARNING`: Tool timeouts, fallback triggers
- `ERROR`: Task failures, API errors
- `CRITICAL`: System failures, worker crashes

**Log Retention:**
- DEBUG logs: 7 days
- INFO logs: 30 days
- WARNING/ERROR: 90 days
- CRITICAL: 1 year

### Alerting Rules

**Critical Alerts (PagerDuty):**
- Celery worker down for >5 minutes
- Error rate >10% for 10 minutes
- Agent scan p95 latency >60 seconds
- Daily API costs >$100

**Warning Alerts (Slack):**
- Error rate >5% for 30 minutes
- Tool failure rate >10% (individual tool)
- Queue depth >100 tasks
- Cache hit rate <30%

**Info Alerts (Dashboard):**
- Daily cost summary
- Usage statistics (agent vs fast path)
- Accuracy metrics vs baseline

### Dashboards

**Real-Time Operations Dashboard:**
- Current queue depth
- Active Celery workers
- Success/error rates (last 1 hour)
- P95 latency trend

**Business Metrics Dashboard:**
- Daily/weekly scans (agent vs fast path)
- Detection accuracy trends
- User feedback scores
- Cost per scan trends

**Cost Monitoring Dashboard:**
- Daily API spend breakdown
- Cost per scan (rolling average)
- Budget vs actual spending
- Cost projections

### Health Checks

**Backend Health Endpoints:**

```python
GET /health/agent
Response:
{
  "status": "healthy",
  "celery_worker": "up",
  "redis": "connected",
  "scam_db": "operational",
  "exa_api": "available",
  "virustotal_api": "available"
}
```

**Monitoring Frequency:**
- Health checks: Every 30 seconds
- Metric collection: Every 60 seconds
- Cost calculations: Every 5 minutes
- Alert evaluation: Continuous

---

## Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **External API downtime** | High | Medium | Graceful degradation; fallback to fast path; health checks |
| **Cost overruns (Exa)** | Medium | Low | Daily budget caps; aggressive caching; cost alerts |
| **Agent reasoning errors** | High | Medium | Manual verification; confidence thresholds; A/B testing |
| **Celery worker crashes** | High | Low | Auto-restart; retry logic; PagerDuty alerts; redundant workers |
| **Redis memory limits** | Medium | Low | TTL on all keys; eviction policies; memory monitoring |
| **False positives** | Medium | Medium | Human review queue; user feedback loop; confidence thresholds |
| **Complex scaling** | High | Medium | Start with 1 worker; horizontal scaling; queue-based autoscaling |
| **Database performance** | Medium | Low | Indexed queries; connection pooling; query optimization |
| **WebSocket reliability** | Medium | Medium | Automatic reconnection; heartbeats; fallback to polling |

---

## Definition of Done

- [ ] All 12 stories completed with acceptance criteria met
- [ ] Celery + Redis infrastructure running in production
- [ ] Entity extraction accurate (>95% precision on test set)
- [ ] Scam database seeded with 10,000+ entries
- [ ] All tools integrated and tested (DB, Exa, Domain, Phone)
- [ ] Agent reasoning producing coherent verdicts
- [ ] WebSocket streaming working end-to-end
- [ ] iOS app displays agent progress beautifully
- [ ] Performance meets benchmarks (< 30s for complex scans)
- [ ] Cost tracking and budget alerts configured
- [ ] Integration tests passing (>90% coverage)
- [ ] Documentation complete (API, architecture, runbooks)

---

## Success Metrics

**Detection Accuracy:**
- Reduce false negatives by 40% (catch more scams)
- Maintain false positive rate < 5%
- Increase confidence scores (more certain verdicts)

**User Trust:**
- User feedback: "I trust the evidence shown" > 80% positive
- Feature adoption: 60%+ of scans with entities use agent path
- User retention: +15% after agent launch (users feel safer)

**Technical Performance:**
- Agent path completes in < 30s (p95)
- WebSocket reliability: < 1% connection failures
- Celery worker uptime: > 99.5%

**Cost Efficiency:**
- API costs < $100/month for 5000 scans
- Cache hit rate > 50% (reducing redundant API calls)

---

## Rollout Plan

### Development Phases

**Phase 1: Infrastructure (Week 8 - Days 1-5)**
- ✅ Stories 8.1-8.2: Celery, Redis, Entity Extraction
- ✅ Deploy to staging environment
- ✅ Smoke tests with mock tools
- **Deliverable:** Working async task queue with progress streaming

**Phase 2: Tool Integration (Week 9 - Days 6-12)**
- ✅ Stories 8.3-8.6: All tools implemented and tested
- ✅ Story 8.7: Agent orchestration logic
- ✅ Integration testing with real scam data (100+ test cases)
- ✅ Story 8.12: Seed database with 10,000+ known scams
- **Deliverable:** Functional MCP agent in staging, all tools operational

**Phase 3: Frontend & Polish (Week 10 - Days 13-18)**
- ✅ Stories 8.8-8.11: Reasoning, WebSocket, iOS UI
- ✅ Story 8.10: Smart routing implementation
- ✅ Beta testing with internal users (20+ scans)
- ✅ Performance optimization and cost monitoring setup
- **Deliverable:** Complete end-to-end flow with polished UI

**Phase 4: Production Launch (Week 11 - Days 19-21)**
- ✅ Feature flag: `ENABLE_MCP_AGENT=true` for 10% of users
- ✅ Monitor metrics: accuracy, latency, costs, errors
- ✅ Gradual rollout: 10% → 25% → 50% → 100% over 2 weeks
- ✅ Daily review meetings to assess performance
- **Deliverable:** Full production deployment with monitoring

### Rollout Gates & Criteria

**Gate 1: Move from Phase 1 → 2**
- ✅ Celery worker stable for 24 hours (no crashes)
- ✅ Redis Pub/Sub delivering messages reliably (>99%)
- ✅ Entity extraction accuracy >95% on test set

**Gate 2: Move from Phase 2 → 3**
- ✅ All 4 tools operational with <5% failure rate
- ✅ Agent reasoning producing coherent verdicts (manual review of 50 cases)
- ✅ Integration tests passing (>90% coverage)
- ✅ Cost per scan within budget (<$0.03/scan)

**Gate 3: Move from Phase 3 → 4 (Production)**
- ✅ Beta users report positive feedback (>80% satisfaction)
- ✅ Performance benchmarks met (p95 < 30s for agent scans)
- ✅ iOS UI polished and intuitive (UX review approved)
- ✅ Error handling tested (all edge cases covered)

**Gate 4: Scale from 10% → 100%**
- ✅ 10% rollout stable for 3 days (no critical bugs)
- ✅ Accuracy metrics improved vs baseline (false negatives down)
- ✅ Cost tracking confirms budget compliance
- ✅ No user complaints about performance or accuracy

### Rollback Triggers

**Immediate Rollback if:**
- Agent path causing >10% error rate
- Average scan time exceeds 45 seconds (p95)
- Daily API costs exceed $50 (runaway spend)
- Critical bug affecting user experience
- Database performance degradation

**Rollback Procedure:**
1. Set feature flag `ENABLE_MCP_AGENT=false` (instant)
2. All scans revert to fast path (Gemini only)
3. Investigate root cause in staging
4. Fix and re-test before re-enabling

### Migration Strategy

**Backward Compatibility:**
- ✅ Fast path (existing system) remains fully functional
- ✅ No breaking changes to existing API endpoints
- ✅ Database schema changes are additive only (new tables, not modified ones)
- ✅ iOS app works with both fast path and agent path responses

**Data Migration:**
- No user data migration required (new tables only)
- Scam database seeding runs independently
- Progressive enhancement: New scans use agent, old data unchanged

**Feature Toggle:**
- Environment variable: `ENABLE_MCP_AGENT` (default: `false` in staging, `true` in prod after rollout)
- Per-user override: Admin API to enable/disable for specific users (testing)
- Graceful degradation: If agent unavailable, fall back to fast path automatically

---

## Future Enhancements (Post-Epic)

**Short-term (Epic 9):**
- Community reporting: Users can submit scams directly
- Reverse image search: Check if screenshot is from known scam template
- Multi-language support: Detect scams in Chinese, Spanish, etc.

**Long-term (Epic 10+):**
- Machine learning: Train custom scam classifier on our data
- Browser extension: Real-time scam checking while browsing
- SMS integration: Analyze text messages for scams
- Voice call analysis: Detect scam robocalls

---

## Notes

This epic represents a **paradigm shift** from "AI guesses" to "Agent investigates with evidence." By transparently showing users:
- ✅ What the agent found (phone in database, web complaints)
- ✅ How it reached the verdict (reasoning process)
- ✅ Sources of evidence (links, database records)

We build unprecedented trust and differentiate TypeSafe as the most intelligent, transparent scam detection system on the market.

**Estimated Timeline:** 3 weeks (Weeks 8-10)

**Engineering Effort:** ~120-150 hours
- Backend: 70 hours (Stories 8.1-8.8)
- iOS: 30 hours (Stories 8.9, 8.11)
- Database/DevOps: 20 hours (Stories 8.10, 8.12)
- Testing & QA: 30 hours (Integration + Manual testing)

---

## Open Questions & Decisions

**Pre-Implementation Decisions Needed:**

1. **Tool Priority:** Which tools to implement first? 
   - Recommendation: Scam DB (8.3) → Phone Validator (8.6) → Exa Search (8.4) → Domain Reputation (8.5)
   - Rationale: Start with fastest/highest-impact tools, add external APIs last

2. **Agent Reasoning Model:** Use Gemini or GPT-4 for final reasoning?
   - Gemini Pro: Faster, cheaper (~$0.001/call), already integrated
   - GPT-4: Better reasoning, more expensive (~$0.01/call), requires new integration
   - Recommendation: Start with Gemini Pro, add GPT-4 as premium feature later

3. **Database Seeding Source:** Which scam databases to use for initial seeding?
   - FTC Consumer Sentinel Network (public data)
   - PhishTank API (active phishing URLs)
   - Community submissions (manual review required)
   - Recommendation: Start with PhishTank (automated), add FTC data (requires parsing)

4. **Cost Budget:** What's the acceptable API cost per scan?
   - Current: ~$0.002/scan (just Gemini)
   - With MCP Agent: ~$0.02/scan (10x increase)
   - Monthly projection: 5,000 scans × $0.02 = $100/month
   - Decision needed: Is this acceptable? Should we add cost caps?

5. **Performance SLA:** What's the max acceptable agent scan time?
   - Current fast path: 1-3 seconds
   - Proposed agent path: 5-30 seconds
   - User expectation: < 10 seconds ideal, < 30 seconds acceptable
   - Decision: Set timeout at 30s, show progress updates every 2-3s

**Post-Launch Review Points:**

- Week 1: Cost analysis (are we within budget?)
- Week 2: Accuracy metrics (false positive/negative rates vs baseline)
- Week 3: User feedback (do they trust the evidence? Is it clear?)
- Month 1: ROI assessment (does better detection justify higher costs?)

---

## Related Documentation

- [Epic 1: Backend API](epic-1-backend-api.md) - API infrastructure this builds on
- [Epic 7: Real-Time Progress Updates](epic-7-realtime-progress-updates.md) - Progress streaming architecture
- [Epic 3: Companion App](epic-3-companion-app.md) - UI integration points
- [Architecture: Data Flows](../architecture/data-flows.md) - System-wide data flow context
- [Architecture: Public API Backend](../architecture/public-api-backend.md) - API design principles

---

## Changelog

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-10-18 | 1.0 | Product Team | Initial draft - complete specification |

---

**End of Epic 8: MCP Agent with Multi-Tool Orchestration**

