# Story 8.12: Database Seeding & Maintenance

**Story ID:** 8.12  
**Epic:** Epic 8 - MCP Agent with Multi-Tool Orchestration  
**Priority:** P1 (Operational Requirement)  
**Effort:** 14 hours  
**Assignee:** Backend Developer  
**Status:** 📝 Ready for Development

---

## User Story

**As a** system administrator,  
**I want** tools to seed and maintain the scam database,  
**so that** the agent has up-to-date scam intelligence.

---

## Description

Provides operational tools to populate and maintain the `scam_reports` database:

1. **Initial Seeding** - Import 10,000+ known scams from public sources
2. **Admin API** - Manual report submission and management
3. **Automated Updates** - Daily fetch from PhishTank and other sources
4. **Data Quality** - Deduplication, archival, false positive removal

**Data Sources:**
- PhishTank API (phishing URLs)
- FTC Consumer Sentinel (reported scam numbers)
- Community submissions
- Manual admin entries

---

## Acceptance Criteria

### Admin API Endpoints
- [ ] 1. `POST /admin/scam-reports` - Add new scam report
- [ ] 2. `GET /admin/scam-reports` - List reports with pagination and filters
- [ ] 3. `PATCH /admin/scam-reports/{id}` - Update report (verify, adjust risk score)
- [ ] 4. `DELETE /admin/scam-reports/{id}` - Remove false positive
- [ ] 5. Admin authentication required (API key or OAuth)
- [ ] 6. Rate limiting: Max 100 requests/hour per admin

### Seeding Scripts
- [ ] 7. Script: `backend/scripts/seed_scam_db.py`
- [ ] 8. Imports from PhishTank JSON API
- [ ] 9. Imports from FTC CSV data (if available)
- [ ] 10. Handles large datasets (10,000+ entries)
- [ ] 11. Deduplicates before insert
- [ ] 12. Progress reporting during seeding

### Automated Updates
- [ ] 13. Cron job: Daily PhishTank fetch (script: `scripts/update_phishtank.py`)
- [ ] 14. Fetches only new/updated entries (incremental)
- [ ] 15. Updates existing entries (increment report count)
- [ ] 16. Logs all updates with timestamp

### Data Quality
- [ ] 17. Deduplication: Prevent duplicate entity_type + entity_value
- [ ] 18. Archival: Move reports > 1 year old to `archived_scam_reports` table
- [ ] 19. False positive removal: Admin can flag and delete
- [ ] 20. Risk score recalculation: Batch job updates scores based on recency

### Analytics Dashboard
- [ ] 21. Endpoint: `GET /admin/scam-analytics` - Database statistics
- [ ] 22. Returns: Total reports, by type, by risk level, recent additions
- [ ] 23. Top scams: Most reported entities
- [ ] 24. Trending scams: Fastest growing report counts

### Testing
- [ ] 25. Unit tests for seeding logic
- [ ] 26. Integration tests with test database
- [ ] 27. Test duplicate handling
- [ ] 28. Test archival logic

---

## Technical Implementation

### Seeding Script

**`backend/scripts/seed_scam_db.py`:**

```python
"""Seed scam database with initial data."""

import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import httpx
import csv
from app.agents.tools.scam_database import get_scam_database_tool
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def seed_from_phishtank():
    """Seed from PhishTank verified phishing URLs."""
    logger.info("Fetching PhishTank data...")
    
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.get(
            "http://data.phishtank.com/data/online-valid.json"
        )
        data = response.json()
    
    logger.info(f"Fetched {len(data)} PhishTank entries")
    
    tool = get_scam_database_tool()
    added = 0
    
    for entry in data:
        url = entry.get('url')
        if url:
            success = tool.add_report(
                entity_type="url",
                entity_value=url,
                evidence={
                    "source": "PhishTank",
                    "url": f"http://www.phishtank.com/phish_detail.php?phish_id={entry.get('phish_id')}",
                    "date": entry.get('submission_time')
                }
            )
            if success:
                added += 1
        
        if added % 100 == 0:
            logger.info(f"Progress: {added} URLs added")
    
    logger.info(f"PhishTank seeding complete: {added} URLs added")


def seed_from_ftc_csv(csv_path: str):
    """Seed from FTC Consumer Sentinel CSV."""
    logger.info(f"Reading FTC data from {csv_path}")
    
    tool = get_scam_database_tool()
    added = 0
    
    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            phone = row.get('phone_number')
            if phone:
                success = tool.add_report(
                    entity_type="phone",
                    entity_value=phone,
                    evidence={
                        "source": "FTC Consumer Sentinel",
                        "complaint_type": row.get('complaint_type'),
                        "date": row.get('date')
                    }
                )
                if success:
                    added += 1
    
    logger.info(f"FTC seeding complete: {added} phone numbers added")


if __name__ == "__main__":
    import asyncio
    
    print("Starting scam database seeding...")
    print("This will take several minutes for large datasets.")
    
    # Seed from PhishTank
    asyncio.run(seed_from_phishtank())
    
    # Seed from FTC (if CSV available)
    # seed_from_ftc_csv("data/ftc_complaints.csv")
    
    print("Seeding complete!")
```

### Automated Update Script

**`backend/scripts/update_phishtank.py`:**

```python
"""Daily PhishTank update script."""

import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import httpx
import asyncio
from datetime import datetime, timedelta
from app.agents.tools.scam_database import get_scam_database_tool
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def update_phishtank():
    """Fetch and update PhishTank data (incremental)."""
    logger.info("Fetching latest PhishTank data...")
    
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.get(
            "http://data.phishtank.com/data/online-valid.json"
        )
        data = response.json()
    
    # Filter to entries from last 24 hours
    yesterday = datetime.now() - timedelta(days=1)
    recent_entries = [
        e for e in data 
        if datetime.fromisoformat(e.get('submission_time', '').replace('Z', '+00:00')) > yesterday
    ]
    
    logger.info(f"Found {len(recent_entries)} new entries from last 24 hours")
    
    tool = get_scam_database_tool()
    added = 0
    
    for entry in recent_entries:
        url = entry.get('url')
        if url:
            success = tool.add_report(
                entity_type="url",
                entity_value=url,
                evidence={
                    "source": "PhishTank",
                    "url": f"http://www.phishtank.com/phish_detail.php?phish_id={entry.get('phish_id')}",
                    "date": entry.get('submission_time')
                }
            )
            if success:
                added += 1
    
    logger.info(f"PhishTank update complete: {added} new URLs added")


if __name__ == "__main__":
    asyncio.run(update_phishtank())
```

### Admin Endpoints

**Already implemented in Story 8.3, but expanded here:**

```python
@router.get("/admin/scam-analytics")
async def get_scam_analytics():
    """Get scam database analytics."""
    from app.db.client import get_supabase_client
    supabase = get_supabase_client()
    
    # Total counts by type
    type_counts = supabase.table('scam_reports').select(
        'entity_type', count='exact'
    ).execute()
    
    # Top reported entities
    top_scams = supabase.table('scam_reports').select('*').order(
        'report_count', desc=True
    ).limit(10).execute()
    
    # Recent additions
    recent = supabase.table('scam_reports').select('*').order(
        'created_at', desc=True
    ).limit(20).execute()
    
    return {
        "total_reports": type_counts.count,
        "by_type": {...},  # Group by entity_type
        "top_scams": top_scams.data,
        "recent_additions": recent.data
    }
```

### Archival Job

**`backend/scripts/archive_old_scams.py`:**

```python
"""Archive scam reports older than 1 year with no recent activity."""

from datetime import datetime, timedelta
from app.db.client import get_supabase_client

def archive_old_scams():
    """Move old scams to archived table."""
    supabase = get_supabase_client()
    
    # Find reports > 1 year old
    one_year_ago = (datetime.now() - timedelta(days=365)).isoformat()
    
    old_reports = supabase.table('scam_reports').select('*').lt(
        'last_reported', one_year_ago
    ).execute()
    
    logger.info(f"Found {len(old_reports.data)} reports to archive")
    
    # Move to archive table
    for report in old_reports.data:
        # Insert into archive
        supabase.table('archived_scam_reports').insert(report).execute()
        
        # Delete from main table
        supabase.table('scam_reports').delete().eq('id', report['id']).execute()
    
    logger.info("Archival complete")

if __name__ == "__main__":
    archive_old_scams()
```

---

## Cron Jobs

**Setup cron jobs on server:**

```bash
# /etc/cron.d/typesafe-scam-updates

# Daily PhishTank update (2 AM)
0 2 * * * /path/to/venv/bin/python /path/to/backend/scripts/update_phishtank.py

# Weekly archival (Sunday 3 AM)
0 3 * * 0 /path/to/venv/bin/python /path/to/backend/scripts/archive_old_scams.py
```

---

## Success Criteria

- [ ] All 28 acceptance criteria met
- [ ] Database seeded with 10,000+ entries
- [ ] Admin API functional
- [ ] Daily updates automated
- [ ] Archival working correctly
- [ ] All tests passing

---

**Estimated Effort:** 14 hours  
**Sprint:** Week 10, Days 4-5

