"""
Daily PhishTank update script for automated scam database maintenance.

This script fetches new/updated PhishTank entries from the last 24-48 hours
and updates the scam_reports database incrementally.

Should be run via cron job daily (recommended: 2 AM)

Story: 8.12 - Database Seeding & Maintenance
"""

import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import httpx
import asyncio
import logging
from datetime import datetime, timedelta, timezone
from typing import List, Dict, Any

from app.agents.tools.scam_database import get_scam_database_tool

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/phishtank_update.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class PhishTankUpdater:
    """Handles daily PhishTank updates."""
    
    def __init__(self):
        """Initialize updater."""
        self.tool = get_scam_database_tool()
        self.stats = {
            'total_fetched': 0,
            'recent_entries': 0,
            'added': 0,
            'updated': 0,
            'skipped': 0,
            'errors': 0
        }
    
    async def fetch_recent_entries(self, hours: int = 48) -> List[Dict[str, Any]]:
        """
        Fetch PhishTank entries from the last N hours.
        
        Args:
            hours: Number of hours to look back (default 48 for safety)
        
        Returns:
            List of recent PhishTank entries
        """
        logger.info("Fetching latest PhishTank data...")
        
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.get(
                    "http://data.phishtank.com/data/online-valid.json",
                    follow_redirects=True
                )
                response.raise_for_status()
                data = response.json()
            
            self.stats['total_fetched'] = len(data)
            logger.info(f"Fetched {len(data)} total PhishTank entries")
            
            # Filter to recent entries
            cutoff_time = datetime.now(timezone.utc) - timedelta(hours=hours)
            recent_entries = []
            
            for entry in data:
                submission_time_str = entry.get('submission_time', '')
                if submission_time_str:
                    try:
                        # Parse PhishTank timestamp (ISO format)
                        submission_time = datetime.fromisoformat(
                            submission_time_str.replace('Z', '+00:00')
                        )
                        
                        if submission_time > cutoff_time:
                            recent_entries.append(entry)
                    except Exception as e:
                        logger.debug(f"Error parsing timestamp {submission_time_str}: {e}")
                        continue
            
            self.stats['recent_entries'] = len(recent_entries)
            logger.info(
                f"Found {len(recent_entries)} entries from last {hours} hours "
                f"(since {cutoff_time.isoformat()})"
            )
            
            return recent_entries
        
        except Exception as e:
            logger.error(f"Error fetching PhishTank data: {e}", exc_info=True)
            raise
    
    async def update_database(self, entries: List[Dict[str, Any]]) -> None:
        """
        Update database with recent PhishTank entries.
        
        Args:
            entries: List of PhishTank entries to process
        """
        if not entries:
            logger.info("No new entries to process")
            return
        
        logger.info(f"Processing {len(entries)} entries...")
        
        for i, entry in enumerate(entries, 1):
            try:
                url = entry.get('url')
                phish_id = entry.get('phish_id')
                submission_time = entry.get('submission_time')
                verified = entry.get('verified', 'yes') == 'yes'
                
                if not url:
                    logger.warning(f"Skipping entry {i}: No URL found")
                    self.stats['skipped'] += 1
                    continue
                
                # Create evidence object
                evidence = {
                    "source": "PhishTank",
                    "phish_id": phish_id,
                    "url": f"http://www.phishtank.com/phish_detail.php?phish_id={phish_id}",
                    "submission_time": submission_time,
                    "verified": verified,
                    "update_date": datetime.now(timezone.utc).isoformat()
                }
                
                # Add or update report
                success = self.tool.add_report(
                    entity_type="url",
                    entity_value=url,
                    evidence=evidence,
                    notes=f"PhishTank verified phishing URL (ID: {phish_id})"
                )
                
                if success:
                    # Note: add_report returns True for both new and updated entries
                    self.stats['added'] += 1
                else:
                    self.stats['skipped'] += 1
                
                # Progress reporting every 50 entries
                if i % 50 == 0:
                    logger.info(
                        f"Progress: {i}/{len(entries)} processed | "
                        f"Added/Updated: {self.stats['added']} | "
                        f"Skipped: {self.stats['skipped']}"
                    )
            
            except Exception as e:
                logger.error(f"Error processing entry {i} (URL: {entry.get('url')}): {e}")
                self.stats['errors'] += 1
                continue
        
        logger.info("Database update complete")
    
    def print_summary(self) -> None:
        """Print update summary."""
        logger.info("")
        logger.info("=" * 80)
        logger.info("PHISHTANK UPDATE SUMMARY")
        logger.info("=" * 80)
        logger.info(f"Total entries fetched: {self.stats['total_fetched']}")
        logger.info(f"Recent entries (last 48h): {self.stats['recent_entries']}")
        logger.info(f"Added/Updated: {self.stats['added']}")
        logger.info(f"Skipped: {self.stats['skipped']}")
        logger.info(f"Errors: {self.stats['errors']}")
        logger.info("=" * 80)
        logger.info(f"Update completed at: {datetime.now(timezone.utc).isoformat()}")
        logger.info("=" * 80)


async def main():
    """Main entry point for update script."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Update scam database with latest PhishTank data')
    parser.add_argument(
        '--hours',
        type=int,
        default=48,
        help='Number of hours to look back (default: 48)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Fetch and analyze but do not update database'
    )
    
    args = parser.parse_args()
    
    logger.info("")
    logger.info("=" * 80)
    logger.info("PHISHTANK DAILY UPDATE SCRIPT")
    logger.info("=" * 80)
    logger.info(f"Started at: {datetime.now(timezone.utc).isoformat()}")
    logger.info(f"Looking back: {args.hours} hours")
    if args.dry_run:
        logger.info("Mode: DRY RUN (no database changes)")
    logger.info("=" * 80)
    logger.info("")
    
    updater = PhishTankUpdater()
    
    try:
        # Fetch recent entries
        recent_entries = await updater.fetch_recent_entries(hours=args.hours)
        
        # Update database (unless dry run)
        if not args.dry_run:
            await updater.update_database(recent_entries)
        else:
            logger.info("Dry run mode - skipping database updates")
        
        # Print summary
        updater.print_summary()
        
        logger.info("")
        logger.info("✅ Update complete!")
        logger.info("")
        
    except Exception as e:
        logger.error(f"Fatal error during update: {e}", exc_info=True)
        updater.print_summary()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())

