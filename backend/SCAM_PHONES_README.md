# Scam Phone Numbers Database

This document describes the `scam_phones` table in Supabase and how to use it with the MCP (Model Context Protocol) integration.

## Overview

The `scam_phones` table stores known scam phone numbers for validation and detection purposes. It includes metadata such as scam type, report counts, and notes about each number.

## Table Schema

```sql
create table scam_phones (
  id uuid primary key default gen_random_uuid(),
  phone_number text not null unique,
  country_code text,
  report_count integer default 1,
  first_reported_at timestamptz default now(),
  last_reported_at timestamptz default now(),
  scam_type text,
  notes text,
  created_at timestamptz default now()
);
```

### Fields

- **id**: Unique identifier (UUID)
- **phone_number**: The phone number (unique, with formatting like "+1 (734) 733-6172")
- **country_code**: Country calling code (e.g., "+1" for US/Canada)
- **report_count**: Number of times this number has been reported
- **first_reported_at**: Timestamp of first report
- **last_reported_at**: Timestamp of most recent report
- **scam_type**: Type of scam (e.g., "IRS Impersonation", "Tech Support Scam")
- **notes**: Additional information about the scam
- **created_at**: Record creation timestamp

## Pre-loaded Example Data

The table comes pre-loaded with 10 example scam numbers, including:

1. **+1 (734) 733-6172** - IRS Impersonation (15 reports)
2. **+1 (202) 555-0147** - Tech Support Scam (23 reports)
3. **+1 (646) 555-0198** - Social Security Scam (8 reports)
4. **+1 (305) 555-0143** - Bank Fraud (12 reports)
5. **+44 20 7946 0958** - HMRC Scam (19 reports)
6. **+1 (415) 555-0176** - Prize/Lottery Scam (31 reports)
7. **+1 (512) 555-0134** - Romance Scam (6 reports)
8. **+91 22 4567 8901** - Tech Support Scam (14 reports)
9. **+1 (888) 555-0192** - Robocall Scam (27 reports)
10. **+61 2 9876 5432** - ATO Scam (9 reports)

## Setup Instructions

### 1. Run the Migration

Execute the migration in your Supabase SQL Editor:

```bash
# In Supabase Dashboard → SQL Editor
# Copy and paste the contents of: migrations/005_create_scam_phones.sql
```

Or from command line (if you have Supabase CLI):

```bash
supabase db push migrations/005_create_scam_phones.sql
```

### 2. Verify Installation

Check that the table exists and data is loaded:

```sql
-- Count records
SELECT COUNT(*) FROM scam_phones;

-- View all records
SELECT phone_number, scam_type, report_count 
FROM scam_phones 
ORDER BY report_count DESC;

-- Check for specific number
SELECT * FROM scam_phones 
WHERE phone_number = '+1 (734) 733-6172';
```

## Python API Usage

### Import Functions

```python
from app.db.operations import (
    check_scam_phone,
    insert_scam_phone,
    get_all_scam_phones,
    search_scam_phones_by_country
)
```

### Check if a Phone Number is a Scam

```python
# Check specific number
result = check_scam_phone("+1 (734) 733-6172")

if result:
    print(f"⚠️  Scam detected!")
    print(f"Type: {result['scam_type']}")
    print(f"Reported {result['report_count']} times")
    print(f"Notes: {result['notes']}")
else:
    print("✓ Number not found in scam database")
```

### Add or Update a Scam Number

```python
# Add new scam number (or update if exists)
result = insert_scam_phone(
    phone_number="+1 (555) 999-8888",
    country_code="+1",
    scam_type="Fake Warranty Call",
    notes="Pretends to be car warranty company",
    report_count=1
)

print(f"Added/Updated: {result['phone_number']}")
print(f"Total reports: {result['report_count']}")
```

### Get All Scam Numbers

```python
# Get top 100 most reported scam numbers
scams = get_all_scam_phones(limit=100)

for scam in scams:
    print(f"{scam['phone_number']}: {scam['scam_type']} ({scam['report_count']} reports)")
```

### Search by Country

```python
# Get all US scam numbers
us_scams = search_scam_phones_by_country("+1")
print(f"Found {len(us_scams)} US scam numbers")

# Get all UK scam numbers
uk_scams = search_scam_phones_by_country("+44")
print(f"Found {len(uk_scams)} UK scam numbers")
```

## MCP Integration

The scam phone database can be used with MCP tools for agent orchestration:

### Example MCP Tool Definition

```json
{
  "name": "check_scam_phone",
  "description": "Check if a phone number is in the scam database",
  "inputSchema": {
    "type": "object",
    "properties": {
      "phone_number": {
        "type": "string",
        "description": "Phone number to check (with country code)"
      }
    },
    "required": ["phone_number"]
  }
}
```

### Example Agent Usage

```python
# In an MCP agent tool
def handle_check_scam_phone(phone_number: str) -> dict:
    """MCP tool handler for checking scam phones."""
    result = check_scam_phone(phone_number)
    
    if result:
        return {
            "is_scam": True,
            "scam_type": result["scam_type"],
            "report_count": result["report_count"],
            "confidence": "high",
            "notes": result["notes"]
        }
    else:
        return {
            "is_scam": False,
            "confidence": "unknown",
            "message": "Number not found in scam database"
        }
```

## Testing

Run the test script to verify everything is working:

```bash
cd backend
python test_scam_phones.py
```

This will:
1. Check for the specific number +1 (734) 733-6172
2. List all scam numbers
3. Search for US scam numbers
4. Add a test entry
5. Verify the test entry

## REST API Endpoints (Optional)

You can add REST API endpoints in `main.py`:

```python
@app.get("/api/v1/scam-phones/check")
async def api_check_scam_phone(phone_number: str):
    """Check if a phone number is a scam."""
    result = check_scam_phone(phone_number)
    
    if result:
        return {
            "is_scam": True,
            "data": result
        }
    else:
        return {
            "is_scam": False,
            "message": "Number not found in database"
        }


@app.get("/api/v1/scam-phones")
async def api_get_scam_phones(
    limit: int = 100,
    country_code: Optional[str] = None
):
    """Get scam phone numbers, optionally filtered by country."""
    if country_code:
        results = search_scam_phones_by_country(country_code, limit)
    else:
        results = get_all_scam_phones(limit)
    
    return {
        "count": len(results),
        "scam_phones": results
    }


@app.post("/api/v1/scam-phones/report")
async def api_report_scam_phone(
    phone_number: str,
    country_code: Optional[str] = None,
    scam_type: Optional[str] = None,
    notes: Optional[str] = None
):
    """Report a new scam phone number."""
    result = insert_scam_phone(
        phone_number=phone_number,
        country_code=country_code,
        scam_type=scam_type,
        notes=notes
    )
    
    return {
        "success": True,
        "data": result
    }
```

## Use Cases

### 1. Real-time Phone Validation

```python
def validate_phone_number(phone: str) -> dict:
    """Validate a phone number against scam database."""
    scam_data = check_scam_phone(phone)
    
    if scam_data:
        return {
            "valid": False,
            "risk_level": "high",
            "reason": f"Known scam: {scam_data['scam_type']}",
            "report_count": scam_data['report_count']
        }
    
    return {
        "valid": True,
        "risk_level": "low"
    }
```

### 2. Text Analysis Enhancement

```python
import re

def analyze_text_for_scam_phones(text: str) -> list:
    """Extract and check phone numbers from text."""
    # Simple phone regex (adjust as needed)
    phone_pattern = r'\+?\d{1,3}[\s\-\.]?\(?\d{3}\)?[\s\-\.]?\d{3}[\s\-\.]?\d{4}'
    phones = re.findall(phone_pattern, text)
    
    scam_phones_found = []
    for phone in phones:
        result = check_scam_phone(phone)
        if result:
            scam_phones_found.append(result)
    
    return scam_phones_found
```

### 3. Screenshot OCR Integration

```python
def check_screenshot_for_scams(ocr_text: str) -> dict:
    """Check OCR text for scam phone numbers."""
    scam_phones = analyze_text_for_scam_phones(ocr_text)
    
    if scam_phones:
        return {
            "risk_level": "high",
            "category": "scam_phone_detected",
            "scam_phones": scam_phones,
            "explanation": f"Detected {len(scam_phones)} known scam phone number(s)"
        }
    
    return {
        "risk_level": "low",
        "category": "no_scam_phones"
    }
```

## Maintenance

### Adding New Scam Numbers

```python
# Add individual number
insert_scam_phone(
    phone_number="+1 (555) 123-4567",
    country_code="+1",
    scam_type="New Scam Type",
    notes="Description of scam"
)
```

### Bulk Import

```python
# Bulk import from list
scam_list = [
    ("+1 (555) 111-1111", "+1", "Type 1", "Notes 1"),
    ("+1 (555) 222-2222", "+1", "Type 2", "Notes 2"),
]

for phone, code, stype, notes in scam_list:
    insert_scam_phone(phone, code, stype, notes)
```

### Cleanup Old Data (Optional)

If you want to implement retention for scam phones:

```sql
-- Delete scam phones with low report counts older than 1 year
DELETE FROM scam_phones 
WHERE report_count < 3 
  AND created_at < now() - interval '1 year';
```

## Security Considerations

1. **Data Validation**: Always validate phone number format before insertion
2. **Rate Limiting**: Implement rate limits on report endpoints to prevent abuse
3. **Moderation**: Consider implementing a review process for new reports
4. **Privacy**: Ensure compliance with local data protection laws

## Future Enhancements

- [ ] Add phone number normalization for better matching
- [ ] Implement fuzzy matching for similar numbers
- [ ] Add geographic data (city, state) for better context
- [ ] Integrate with external scam databases
- [ ] Add reporting confidence scores
- [ ] Implement machine learning for scam prediction

## Support

For issues or questions:
1. Check the test script: `python test_scam_phones.py`
2. Verify migration was run successfully
3. Check Supabase connection in `.env`
4. Review logs for error messages


