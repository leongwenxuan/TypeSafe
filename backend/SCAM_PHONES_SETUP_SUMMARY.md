# Scam Phones Table - Setup Summary

## ✅ What Was Created

This summary describes the complete scam phone database implementation using Supabase MCP.

### 1. Database Migration

**File**: `backend/migrations/005_create_scam_phones.sql`

Creates the `scam_phones` table with:
- UUID primary key
- Phone number (unique)
- Country code
- Report counts with timestamps
- Scam type and notes
- Proper indexes for fast lookups

**Pre-loaded with 10 example scam numbers**, including:
- ✓ **+1 (734) 733-6172** (IRS Impersonation)
- And 9 other international scam numbers

### 2. Python Database Operations

**File**: `backend/app/db/operations.py`

Added 4 new functions:
- `check_scam_phone(phone_number)` - Check if number is a scam
- `insert_scam_phone(...)` - Add or update scam number
- `get_all_scam_phones(limit)` - Get all scam numbers
- `search_scam_phones_by_country(country_code)` - Search by country

### 3. Test Script

**File**: `backend/test_scam_phones.py`

Executable test script that demonstrates:
- Checking for specific numbers
- Fetching all scam phones
- Searching by country
- Adding new entries
- Verifying database operations

### 4. Documentation

**Files**:
- `backend/SCAM_PHONES_README.md` - Complete usage guide
- `backend/migrations/README.md` - Updated with new migration
- `backend/SCAM_PHONES_SETUP_SUMMARY.md` - This file

## 🚀 Quick Start

### Step 1: Run the Migration

1. Open Supabase Dashboard → SQL Editor
2. Copy contents of `migrations/005_create_scam_phones.sql`
3. Paste and click "Run"

### Step 2: Test the Setup

```bash
cd backend
python test_scam_phones.py
```

Expected output:
```
============================================================
Scam Phone Database Test
============================================================

[Test 1] Checking for +1 (734) 733-6172...
✓ Found in database!
  Scam Type: IRS Impersonation
  Report Count: 15
  Notes: Reported multiple times claiming to be IRS demanding payment
...
```

### Step 3: Use in Your Code

```python
from app.db.operations import check_scam_phone

# Check if a phone number is a scam
result = check_scam_phone("+1 (734) 733-6172")
if result:
    print(f"⚠️ Scam detected: {result['scam_type']}")
```

## 📊 Pre-loaded Example Data

The table includes these 10 example scam numbers:

| Phone Number | Country | Scam Type | Reports |
|--------------|---------|-----------|---------|
| +1 (734) 733-6172 | US | IRS Impersonation | 15 |
| +1 (415) 555-0176 | US | Prize/Lottery Scam | 31 |
| +1 (888) 555-0192 | US | Robocall Scam | 27 |
| +1 (202) 555-0147 | US | Tech Support Scam | 23 |
| +44 20 7946 0958 | UK | HMRC Scam | 19 |
| +91 22 4567 8901 | India | Tech Support Scam | 14 |
| +1 (305) 555-0143 | US | Bank Fraud | 12 |
| +61 2 9876 5432 | Australia | ATO Scam | 9 |
| +1 (646) 555-0198 | US | Social Security Scam | 8 |
| +1 (512) 555-0134 | US | Romance Scam | 6 |

## 🔧 Integration Points

### 1. MCP Agent Tools

```python
# Use in MCP agent orchestration
from app.db.operations import check_scam_phone

def mcp_check_phone_tool(phone_number: str):
    """MCP tool for checking scam phones."""
    result = check_scam_phone(phone_number)
    return {
        "is_scam": bool(result),
        "data": result if result else None
    }
```

### 2. Text Analysis Service

```python
# Integrate with existing text analysis
import re
from app.db.operations import check_scam_phone

def enhance_text_analysis(text: str, existing_analysis: dict):
    """Add scam phone detection to text analysis."""
    # Extract phone numbers from text
    phones = re.findall(r'\+?\d{1,3}[\s\-\.]?\(?\d{3}\)?[\s\-\.]?\d{3}[\s\-\.]?\d{4}', text)
    
    scam_phones = []
    for phone in phones:
        result = check_scam_phone(phone)
        if result:
            scam_phones.append(result)
    
    # Enhance risk level if scam phones detected
    if scam_phones:
        existing_analysis['risk_level'] = 'high'
        existing_analysis['scam_phones_detected'] = len(scam_phones)
        existing_analysis['scam_details'] = scam_phones
    
    return existing_analysis
```

### 3. REST API Endpoints

Add to `main.py`:

```python
from app.db.operations import check_scam_phone, get_all_scam_phones

@app.get("/api/v1/scam-phones/check")
async def check_scam_endpoint(phone: str):
    result = check_scam_phone(phone)
    return {"is_scam": bool(result), "data": result}

@app.get("/api/v1/scam-phones")
async def list_scam_phones(limit: int = 100):
    results = get_all_scam_phones(limit)
    return {"count": len(results), "data": results}
```

## 📁 File Structure

```
backend/
├── migrations/
│   ├── 001_create_sessions.sql
│   ├── 002_create_text_analyses.sql
│   ├── 003_create_scan_results.sql
│   ├── 004_setup_retention.sql
│   ├── 005_create_scam_phones.sql          ← NEW
│   └── README.md                            ← UPDATED
├── app/
│   └── db/
│       ├── client.py
│       └── operations.py                    ← UPDATED (added 4 functions)
├── test_scam_phones.py                      ← NEW
├── SCAM_PHONES_README.md                    ← NEW
└── SCAM_PHONES_SETUP_SUMMARY.md             ← NEW (this file)
```

## ✨ Key Features

1. **Unique Phone Numbers**: Prevents duplicates
2. **Report Tracking**: Counts how many times each number is reported
3. **Timestamp Tracking**: First and last report dates
4. **Flexible Metadata**: Scam type and notes
5. **Indexed Lookups**: Fast phone number searches
6. **Country Filtering**: Search by country code
7. **Auto-Update**: Inserting existing numbers increments report count
8. **Pre-seeded Data**: Ready to use with 10 examples

## 🎯 Use Cases

1. **Real-time Validation**: Check phone numbers as users type
2. **Text Analysis**: Detect scam phones in analyzed text
3. **Screenshot Scanning**: Flag scam phones in OCR results
4. **User Reporting**: Allow users to report new scams
5. **MCP Tools**: Integrate with AI agent orchestration
6. **Analytics**: Track scam trends by country/type

## 🔒 Security Notes

- Uses Supabase RLS (Row Level Security) disabled for backend-only access
- Service role key required (not anon key)
- Validate phone formats before insertion
- Implement rate limiting on report endpoints
- Consider moderation for user-reported numbers

## 📞 Example Phone Number Formats

The database supports various formats:
- `+1 (734) 733-6172` (formatted)
- `+17347336172` (raw)
- `+44 20 7946 0958` (UK format)
- `+91 22 4567 8901` (India format)

**Note**: Consistency is key! Use the same format for inserting and querying.

## 🆘 Troubleshooting

### Migration fails
- Check Supabase SQL Editor for errors
- Ensure you're using the service role key
- Verify previous migrations ran successfully

### Test script fails
- Verify `.env` file has SUPABASE_URL and SUPABASE_KEY
- Run migration first: `005_create_scam_phones.sql`
- Check Supabase connection: `python -c "from app.db.client import get_supabase_client; get_supabase_client()"`

### Phone not found
- Ensure exact format matches (including spaces, parentheses)
- Check database: `SELECT * FROM scam_phones WHERE phone_number LIKE '%734%';`

## 📚 Next Steps

1. **Run the migration** in Supabase SQL Editor
2. **Test the setup** using `python test_scam_phones.py`
3. **Integrate with MCP tools** (see story-8-6-phone-validator-tool.md)
4. **Add API endpoints** if needed
5. **Implement phone normalization** for better matching

## 📖 Documentation

- Full guide: `SCAM_PHONES_README.md`
- Migration details: `migrations/README.md`
- Python API: See docstrings in `app/db/operations.py`
- Test examples: `test_scam_phones.py`

---

**Created**: October 18, 2025  
**Status**: ✅ Ready to use  
**Migration**: 005_create_scam_phones.sql  
**Tables**: scam_phones  
**Functions**: 4 new operations in operations.py


