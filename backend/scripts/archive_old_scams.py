"""
Archive old scam reports to maintain database performance.

This script moves scam reports older than 1 year with no recent activity
to the archived_scam_reports table.

Should be run via cron job weekly (recommended: Sunday 3 AM)

Story: 8.12 - Database Seeding & Maintenance
"""

import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import logging
from datetime import datetime, timedelta, timezone
from typing import List, Dict, Any

from app.db.client import get_supabase_client

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/scam_archival.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class ScamArchiver:
    """Handles archiving of old scam reports."""
    
    def __init__(self):
        """Initialize archiver."""
        self.supabase = get_supabase_client()
        self.stats = {
            'candidates': 0,
            'archived': 0,
            'failed': 0,
            'errors': 0
        }
    
    def find_archival_candidates(self, days: int = 365) -> List[Dict[str, Any]]:
        """
        Find scam reports that should be archived.
        
        Criteria:
        - last_reported > N days ago (default 365)
        - Not verified OR verified but inactive
        
        Args:
            days: Age threshold in days (default 365 = 1 year)
        
        Returns:
            List of report records to archive
        """
        logger.info(f"Finding reports older than {days} days...")
        
        try:
            # Calculate cutoff date
            cutoff_date = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
            
            logger.info(f"Cutoff date: {cutoff_date}")
            
            # Query for old reports
            # Note: We'll be more conservative with verified reports
            response = self.supabase.table('scam_reports').select('*').lt(
                'last_reported', cutoff_date
            ).execute()
            
            candidates = response.data or []
            
            # Filter: Keep verified high-risk reports, archive others
            archival_candidates = []
            for report in candidates:
                # Keep verified reports with high risk scores (they're still valuable)
                if report.get('verified') and report.get('risk_score', 0) > 70:
                    logger.debug(
                        f"Keeping verified high-risk report: "
                        f"{report['entity_type']}/{report['entity_value']}"
                    )
                    continue
                
                archival_candidates.append(report)
            
            self.stats['candidates'] = len(archival_candidates)
            logger.info(
                f"Found {len(candidates)} old reports total, "
                f"{len(archival_candidates)} eligible for archival"
            )
            
            return archival_candidates
        
        except Exception as e:
            logger.error(f"Error finding archival candidates: {e}", exc_info=True)
            return []
    
    def archive_reports(self, reports: List[Dict[str, Any]], batch_size: int = 50) -> None:
        """
        Archive reports to archived_scam_reports table.
        
        Args:
            reports: List of reports to archive
            batch_size: Number of reports to process in each batch
        """
        if not reports:
            logger.info("No reports to archive")
            return
        
        logger.info(f"Archiving {len(reports)} reports...")
        
        # Process in batches for better performance
        for i in range(0, len(reports), batch_size):
            batch = reports[i:i + batch_size]
            
            try:
                # Insert into archive table
                archive_records = []
                for report in batch:
                    # Add archival metadata
                    archive_record = report.copy()
                    archive_record['archived_at'] = datetime.now(timezone.utc).isoformat()
                    archive_records.append(archive_record)
                
                # Insert batch into archive
                self.supabase.table('archived_scam_reports').insert(archive_records).execute()
                
                # Delete from main table
                report_ids = [report['id'] for report in batch]
                self.supabase.table('scam_reports').delete().in_('id', report_ids).execute()
                
                self.stats['archived'] += len(batch)
                
                logger.info(
                    f"Archived batch {i//batch_size + 1}: "
                    f"{len(batch)} reports (total: {self.stats['archived']})"
                )
            
            except Exception as e:
                logger.error(f"Error archiving batch {i//batch_size + 1}: {e}", exc_info=True)
                self.stats['failed'] += len(batch)
                self.stats['errors'] += 1
                continue
        
        logger.info("Archival complete")
    
    def cleanup_archives(self, keep_years: int = 3) -> None:
        """
        Clean up very old archives (optional maintenance).
        
        Args:
            keep_years: Number of years of archives to keep (default 3)
        """
        logger.info(f"Cleaning up archives older than {keep_years} years...")
        
        try:
            # Calculate cutoff date for permanent deletion
            cutoff_date = (
                datetime.now(timezone.utc) - timedelta(days=keep_years * 365)
            ).isoformat()
            
            # Count candidates for deletion
            count_response = self.supabase.table('archived_scam_reports').select(
                'id', count='exact'
            ).lt('last_reported', cutoff_date).execute()
            
            deletion_count = count_response.count or 0
            
            if deletion_count > 0:
                logger.info(f"Found {deletion_count} very old archives to delete")
                
                # Delete very old archives
                self.supabase.table('archived_scam_reports').delete().lt(
                    'last_reported', cutoff_date
                ).execute()
                
                logger.info(f"Deleted {deletion_count} very old archives")
            else:
                logger.info("No very old archives to delete")
        
        except Exception as e:
            logger.error(f"Error cleaning up archives: {e}", exc_info=True)
    
    def print_summary(self) -> None:
        """Print archival summary."""
        logger.info("")
        logger.info("=" * 80)
        logger.info("SCAM ARCHIVAL SUMMARY")
        logger.info("=" * 80)
        logger.info(f"Archival candidates found: {self.stats['candidates']}")
        logger.info(f"Successfully archived: {self.stats['archived']}")
        logger.info(f"Failed to archive: {self.stats['failed']}")
        logger.info(f"Errors: {self.stats['errors']}")
        logger.info("=" * 80)
        logger.info(f"Archival completed at: {datetime.now(timezone.utc).isoformat()}")
        logger.info("=" * 80)


def main():
    """Main entry point for archival script."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Archive old scam reports')
    parser.add_argument(
        '--days',
        type=int,
        default=365,
        help='Age threshold in days (default: 365)'
    )
    parser.add_argument(
        '--cleanup-years',
        type=int,
        default=3,
        help='Years of archives to keep before permanent deletion (default: 3)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Find candidates but do not archive'
    )
    parser.add_argument(
        '--skip-cleanup',
        action='store_true',
        help='Skip cleanup of very old archives'
    )
    
    args = parser.parse_args()
    
    logger.info("")
    logger.info("=" * 80)
    logger.info("SCAM REPORT ARCHIVAL SCRIPT")
    logger.info("=" * 80)
    logger.info(f"Started at: {datetime.now(timezone.utc).isoformat()}")
    logger.info(f"Age threshold: {args.days} days")
    logger.info(f"Archive retention: {args.cleanup_years} years")
    if args.dry_run:
        logger.info("Mode: DRY RUN (no database changes)")
    logger.info("=" * 80)
    logger.info("")
    
    archiver = ScamArchiver()
    
    try:
        # Find candidates
        candidates = archiver.find_archival_candidates(days=args.days)
        
        # Archive (unless dry run)
        if not args.dry_run:
            archiver.archive_reports(candidates)
            
            # Optional: cleanup very old archives
            if not args.skip_cleanup:
                archiver.cleanup_archives(keep_years=args.cleanup_years)
        else:
            logger.info("Dry run mode - skipping archival")
        
        # Print summary
        archiver.print_summary()
        
        logger.info("")
        logger.info("✅ Archival complete!")
        logger.info("")
        
    except Exception as e:
        logger.error(f"Fatal error during archival: {e}", exc_info=True)
        archiver.print_summary()
        sys.exit(1)


if __name__ == "__main__":
    main()

