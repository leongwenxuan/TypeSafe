# Scam Phones - System Architecture

## Overview Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         TypeSafe Backend                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌────────────────────┐         ┌─────────────────────┐         │
│  │   REST API         │         │   MCP Tools         │         │
│  │   (FastAPI)        │         │   (Agent Agents)    │         │
│  ├────────────────────┤         ├─────────────────────┤         │
│  │ GET /scam-phones   │         │ check_scam_phone    │         │
│  │ POST /report       │         │ report_scam         │         │
│  │ GET /check?phone=  │         │ search_by_country   │         │
│  └────────┬───────────┘         └──────────┬──────────┘         │
│           │                                 │                    │
│           └────────────┬────────────────────┘                    │
│                        │                                         │
│           ┌────────────▼─────────────────┐                      │
│           │   Python Operations Layer    │                      │
│           │   (app/db/operations.py)     │                      │
│           ├──────────────────────────────┤                      │
│           │ check_scam_phone()           │                      │
│           │ insert_scam_phone()          │                      │
│           │ get_all_scam_phones()        │                      │
│           │ search_scam_phones_by_country() │                   │
│           └────────────┬─────────────────┘                      │
│                        │                                         │
│           ┌────────────▼─────────────────┐                      │
│           │   Supabase Client            │                      │
│           │   (app/db/client.py)         │                      │
│           └────────────┬─────────────────┘                      │
│                        │                                         │
└────────────────────────┼─────────────────────────────────────────┘
                         │
                         │ HTTPS API Calls
                         │ (postgREST)
                         │
┌────────────────────────▼─────────────────────────────────────────┐
│                      Supabase Cloud                               │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              PostgreSQL Database                         │    │
│  │                                                          │    │
│  │  ┌────────────────────────────────────────────────┐    │    │
│  │  │  scam_phones table                             │    │    │
│  │  ├────────────────────────────────────────────────┤    │    │
│  │  │  id                    UUID PK                 │    │    │
│  │  │  phone_number          TEXT UNIQUE             │    │    │
│  │  │  country_code          TEXT                    │    │    │
│  │  │  report_count          INTEGER                 │    │    │
│  │  │  first_reported_at     TIMESTAMPTZ            │    │    │
│  │  │  last_reported_at      TIMESTAMPTZ            │    │    │
│  │  │  scam_type             TEXT                    │    │    │
│  │  │  notes                 TEXT                    │    │    │
│  │  │  created_at            TIMESTAMPTZ            │    │    │
│  │  └────────────────────────────────────────────────┘    │    │
│  │                                                          │    │
│  │  Indexes:                                               │    │
│  │  - idx_scam_phones_phone_number (for fast lookups)     │    │
│  │  - idx_scam_phones_created_at (for retention)          │    │
│  │                                                          │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagrams

### 1. Check Scam Phone Number

```
┌─────────┐     1. Request       ┌──────────────┐
│  Client │ ──────────────────> │  API/MCP     │
│ (App/AI)│                      │   Endpoint   │
└─────────┘                      └──────┬───────┘
                                        │
                                        │ 2. Call
                                        │
                              ┌─────────▼────────┐
                              │ check_scam_phone()│
                              │  (operations.py)  │
                              └─────────┬─────────┘
                                        │
                                        │ 3. Query
                                        │
                              ┌─────────▼─────────┐
                              │  Supabase Client  │
                              │   GET request     │
                              └─────────┬─────────┘
                                        │
                                        │ 4. SQL Query
                                        │
                              ┌─────────▼─────────┐
                              │   scam_phones     │
                              │      Table        │
                              └─────────┬─────────┘
                                        │
                                        │ 5. Result
                                        │
┌─────────┐     6. Response     ┌───────▼──────────┐
│  Client │ <────────────────── │   Returns:       │
│         │                     │   - is_scam      │
│         │                     │   - scam_type    │
│         │                     │   - report_count │
└─────────┘                     └──────────────────┘
```

### 2. Report New Scam Number

```
┌─────────┐                     ┌──────────────────┐
│  Client │ ───────────────────>│  report_scam()   │
│         │  phone, type, notes │  (operations.py) │
└─────────┘                     └────────┬─────────┘
                                         │
                                         │ Check if exists
                                         │
                               ┌─────────▼──────────┐
                               │ check_scam_phone() │
                               └─────────┬──────────┘
                                         │
                        ┌────────────────┴────────────────┐
                        │                                 │
                  Exists│                           │Not Exists
                        │                                 │
         ┌──────────────▼──────────┐     ┌──────────────▼────────┐
         │  UPDATE                 │     │  INSERT                │
         │  - increment count      │     │  - new record          │
         │  - update timestamp     │     │  - report_count = 1    │
         └──────────────┬──────────┘     └──────────────┬────────┘
                        │                                │
                        └────────────┬───────────────────┘
                                     │
                           ┌─────────▼──────────┐
                           │  Return result     │
                           │  with updated data │
                           └────────────────────┘
```

### 3. Integration with Text Analysis

```
┌──────────────┐
│ User types   │
│ text in      │
│ keyboard     │
└──────┬───────┘
       │
       │ Send text
       │
┌──────▼────────────┐
│ Text Analysis API │
│ (existing)        │
└──────┬────────────┘
       │
       │ Analyze
       │
┌──────▼───────────────────┐
│ Gemini/OpenAI Service   │
│ - Check sentiment       │
│ - Extract entities      │
│ - Extract phone numbers │◄──┐
└──────┬──────────────────┘   │
       │                       │
       │ Phone numbers found   │
       │                       │
┌──────▼──────────────┐        │
│ For each phone:     │        │
│ check_scam_phone()  │────────┘
└──────┬──────────────┘
       │
       │ Enhance result
       │
┌──────▼──────────────────┐
│ Return analysis with:   │
│ - risk_level: "high"    │
│ - scam_phones: [...]    │
│ - explanation: "..."    │
└─────────────────────────┘
```

## Component Responsibilities

### 1. Migration (`005_create_scam_phones.sql`)
**Purpose**: Database schema definition
- Creates table with proper constraints
- Adds indexes for performance
- Pre-loads example data
- Sets up RLS policies

### 2. Database Client (`app/db/client.py`)
**Purpose**: Connection management
- Singleton pattern for Supabase client
- Handles credentials from environment
- Connection pooling

### 3. Operations Layer (`app/db/operations.py`)
**Purpose**: Business logic and data access
- `check_scam_phone()` - Lookup operations
- `insert_scam_phone()` - Add/update with deduplication
- `get_all_scam_phones()` - List operations
- `search_scam_phones_by_country()` - Filtered queries

### 4. API/MCP Layer (to be implemented)
**Purpose**: External interface
- REST API endpoints
- MCP tool definitions
- Input validation
- Response formatting

## Integration Patterns

### Pattern 1: Direct Database Check

```python
from app.db.operations import check_scam_phone

def validate_phone_in_form(phone: str):
    scam = check_scam_phone(phone)
    if scam:
        raise ValidationError(f"Scam detected: {scam['scam_type']}")
```

### Pattern 2: Text Analysis Enhancement

```python
from app.db.operations import check_scam_phone
import re

def analyze_text_with_scam_detection(text: str):
    # Extract phones
    phones = extract_phone_numbers(text)
    
    # Check each
    scam_phones = []
    for phone in phones:
        result = check_scam_phone(phone)
        if result:
            scam_phones.append(result)
    
    # Adjust risk level
    risk_level = "high" if scam_phones else "low"
    
    return {
        "risk_level": risk_level,
        "scam_phones": scam_phones,
        "phone_count": len(phones)
    }
```

### Pattern 3: MCP Tool Integration

```python
# MCP Tool Definition
{
    "name": "check_scam_phone",
    "description": "Check if phone number is known scam",
    "input_schema": {
        "type": "object",
        "properties": {
            "phone_number": {"type": "string"}
        }
    }
}

# Tool Handler
def mcp_check_scam_phone(phone_number: str):
    result = check_scam_phone(phone_number)
    return {
        "is_scam": bool(result),
        "confidence": "high" if result and result['report_count'] > 10 else "medium",
        "data": result
    }
```

## Security Architecture

```
┌─────────────────────────────────────────────┐
│             Security Layers                  │
├─────────────────────────────────────────────┤
│                                             │
│  1. Environment Variables (.env)            │
│     - SUPABASE_URL                          │
│     - SUPABASE_KEY (service_role)           │
│     - Never committed to git                │
│                                             │
│  2. Backend-Only Access                     │
│     - Service role key (not anon key)       │
│     - RLS disabled (backend trusted)        │
│     - No direct client access               │
│                                             │
│  3. API Layer Security (to implement)       │
│     - Authentication required               │
│     - Rate limiting on writes               │
│     - Input validation                      │
│                                             │
│  4. Data Validation                         │
│     - Phone format validation               │
│     - SQL injection prevention (via ORM)    │
│     - Unique constraints in DB              │
│                                             │
└─────────────────────────────────────────────┘
```

## Performance Considerations

### Indexes
```sql
-- Phone number lookup (most common)
CREATE INDEX idx_scam_phones_phone_number ON scam_phones(phone_number);

-- Temporal queries
CREATE INDEX idx_scam_phones_created_at ON scam_phones(created_at);
```

### Query Optimization
- **Lookup by phone**: O(log n) with index
- **Search by country**: O(n) scan with filter
- **List all**: Paginated with LIMIT

### Caching Strategy (Future)
```python
from functools import lru_cache

@lru_cache(maxsize=1000)
def check_scam_phone_cached(phone: str):
    return check_scam_phone(phone)
```

## Scalability

### Current Capacity
- **Table Size**: ~10 rows (example data)
- **Expected Growth**: 10,000-100,000 rows
- **Query Performance**: <10ms for indexed lookups

### Future Scaling Options
1. **Partitioning**: By country_code
2. **Caching**: Redis for hot phone numbers
3. **Replication**: Read replicas for high traffic
4. **CDN**: Distribute static scam lists

## Monitoring & Observability

### Key Metrics to Track
```sql
-- Query frequency
SELECT COUNT(*) FROM pg_stat_user_tables 
WHERE relname = 'scam_phones';

-- Index usage
SELECT idx_scan, idx_tup_read 
FROM pg_stat_user_indexes 
WHERE indexrelname LIKE 'idx_scam_phones%';

-- Table size growth
SELECT pg_size_pretty(pg_total_relation_size('scam_phones'));
```

### Alerts to Set Up
- Table size > 1GB
- Index hit ratio < 95%
- Query latency > 100ms
- Insert failures

## Deployment Checklist

- [ ] Run migration `005_create_scam_phones.sql`
- [ ] Verify table created with `\d scam_phones`
- [ ] Check example data loaded (10 rows)
- [ ] Test operations with `test_scam_phones.py`
- [ ] Set up monitoring queries
- [ ] Document API endpoints
- [ ] Configure rate limiting
- [ ] Set up backup schedule

## Related Documentation

- **Setup Guide**: `SCAM_PHONES_SETUP_SUMMARY.md`
- **User Guide**: `SCAM_PHONES_README.md`
- **SQL Queries**: `migrations/scam_phones_queries.sql`
- **Migration**: `migrations/005_create_scam_phones.sql`
- **Test Script**: `test_scam_phones.py`


