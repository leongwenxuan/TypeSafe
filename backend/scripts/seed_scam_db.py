"""
Seed scam database with initial data from multiple sources.

This script imports known scam data from:
- PhishTank (verified phishing URLs)
- FTC Consumer Sentinel (optional CSV data)
- Manual seed data

Story: 8.12 - Database Seeding & Maintenance
"""

import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import httpx
import csv
import asyncio
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime
from pathlib import Path

from app.agents.tools.scam_database import get_scam_database_tool

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class ScamDatabaseSeeder:
    """Main seeder class for populating scam database."""
    
    def __init__(self):
        """Initialize seeder with scam database tool."""
        self.tool = get_scam_database_tool()
        self.stats = {
            'phishtank_added': 0,
            'phishtank_duplicates': 0,
            'ftc_added': 0,
            'ftc_duplicates': 0,
            'manual_added': 0,
            'errors': 0
        }
    
    async def seed_from_phishtank(self, limit: Optional[int] = None) -> None:
        """
        Seed from PhishTank verified phishing URLs.
        
        Args:
            limit: Optional limit on number of entries to import (for testing)
        """
        logger.info("=" * 80)
        logger.info("Fetching PhishTank data...")
        logger.info("=" * 80)
        
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                # PhishTank free API endpoint (no key required for verified data)
                response = await client.get(
                    "http://data.phishtank.com/data/online-valid.json",
                    follow_redirects=True
                )
                response.raise_for_status()
                data = response.json()
            
            total_entries = len(data)
            logger.info(f"Fetched {total_entries} PhishTank entries")
            
            if limit:
                data = data[:limit]
                logger.info(f"Limited to first {limit} entries for testing")
            
            # Process in batches for better progress tracking
            batch_size = 100
            
            for i, entry in enumerate(data, 1):
                try:
                    url = entry.get('url')
                    phish_id = entry.get('phish_id')
                    submission_time = entry.get('submission_time')
                    verified = entry.get('verified', 'yes') == 'yes'
                    
                    if not url:
                        logger.warning(f"Skipping entry {i}: No URL found")
                        continue
                    
                    # Create evidence object
                    evidence = {
                        "source": "PhishTank",
                        "phish_id": phish_id,
                        "url": f"http://www.phishtank.com/phish_detail.php?phish_id={phish_id}",
                        "submission_time": submission_time,
                        "verified": verified
                    }
                    
                    # Add to database
                    success = self.tool.add_report(
                        entity_type="url",
                        entity_value=url,
                        evidence=evidence,
                        notes=f"PhishTank verified phishing URL (ID: {phish_id})"
                    )
                    
                    if success:
                        self.stats['phishtank_added'] += 1
                    else:
                        self.stats['phishtank_duplicates'] += 1
                    
                    # Progress reporting
                    if i % batch_size == 0:
                        logger.info(
                            f"Progress: {i}/{len(data)} processed | "
                            f"Added: {self.stats['phishtank_added']} | "
                            f"Duplicates: {self.stats['phishtank_duplicates']}"
                        )
                
                except Exception as e:
                    logger.error(f"Error processing PhishTank entry {i}: {e}")
                    self.stats['errors'] += 1
                    continue
            
            logger.info("=" * 80)
            logger.info(
                f"PhishTank seeding complete: {self.stats['phishtank_added']} URLs added, "
                f"{self.stats['phishtank_duplicates']} duplicates skipped"
            )
            logger.info("=" * 80)
        
        except Exception as e:
            logger.error(f"Fatal error fetching PhishTank data: {e}", exc_info=True)
            raise
    
    def seed_from_ftc_csv(self, csv_path: str) -> None:
        """
        Seed from FTC Consumer Sentinel CSV data.
        
        Expected CSV columns:
        - phone_number: Phone number of scammer
        - complaint_type: Type of scam
        - date: Date of report
        - description: Optional description
        
        Args:
            csv_path: Path to FTC CSV file
        """
        csv_file = Path(csv_path)
        
        if not csv_file.exists():
            logger.warning(f"FTC CSV file not found: {csv_path}")
            return
        
        logger.info("=" * 80)
        logger.info(f"Reading FTC data from {csv_path}")
        logger.info("=" * 80)
        
        try:
            with open(csv_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                
                for i, row in enumerate(reader, 1):
                    try:
                        phone = row.get('phone_number')
                        complaint_type = row.get('complaint_type', 'Unknown')
                        date = row.get('date', datetime.now().isoformat())
                        description = row.get('description', '')
                        
                        if not phone:
                            continue
                        
                        # Create evidence
                        evidence = {
                            "source": "FTC Consumer Sentinel",
                            "complaint_type": complaint_type,
                            "date": date,
                            "description": description[:200] if description else None
                        }
                        
                        # Add to database
                        success = self.tool.add_report(
                            entity_type="phone",
                            entity_value=phone,
                            evidence=evidence,
                            notes=f"FTC report: {complaint_type}"
                        )
                        
                        if success:
                            self.stats['ftc_added'] += 1
                        else:
                            self.stats['ftc_duplicates'] += 1
                        
                        # Progress reporting
                        if i % 100 == 0:
                            logger.info(
                                f"Progress: {i} processed | "
                                f"Added: {self.stats['ftc_added']} | "
                                f"Duplicates: {self.stats['ftc_duplicates']}"
                            )
                    
                    except Exception as e:
                        logger.error(f"Error processing FTC row {i}: {e}")
                        self.stats['errors'] += 1
                        continue
            
            logger.info("=" * 80)
            logger.info(
                f"FTC seeding complete: {self.stats['ftc_added']} phone numbers added, "
                f"{self.stats['ftc_duplicates']} duplicates skipped"
            )
            logger.info("=" * 80)
        
        except Exception as e:
            logger.error(f"Error reading FTC CSV: {e}", exc_info=True)
    
    def seed_manual_data(self) -> None:
        """
        Seed additional manual/curated scam data.
        
        This includes high-confidence scams from various sources that aren't
        automatically imported.
        """
        logger.info("=" * 80)
        logger.info("Seeding manual curated data...")
        logger.info("=" * 80)
        
        # Additional high-profile scam domains
        manual_urls = [
            {
                "url": "secure-login-verify.com",
                "notes": "Generic credential harvesting site",
                "source": "manual_curation"
            },
            {
                "url": "account-verification-required.net",
                "notes": "Generic phishing template",
                "source": "manual_curation"
            },
            {
                "url": "update-billing-info.com",
                "notes": "Payment credential phishing",
                "source": "manual_curation"
            },
            {
                "url": "confirm-your-identity.net",
                "notes": "Identity theft phishing",
                "source": "manual_curation"
            }
        ]
        
        # Additional known scam phone numbers
        manual_phones = [
            {
                "phone": "+18885551234",
                "notes": "Robocall warranty scam",
                "complaint_type": "warranty_scam"
            },
            {
                "phone": "+18775552345",
                "notes": "IRS impersonation",
                "complaint_type": "irs_scam"
            }
        ]
        
        # Add manual URLs
        for item in manual_urls:
            try:
                evidence = {
                    "source": item["source"],
                    "date": datetime.now().isoformat(),
                    "verified": True
                }
                
                success = self.tool.add_report(
                    entity_type="url",
                    entity_value=item["url"],
                    evidence=evidence,
                    notes=item["notes"]
                )
                
                if success:
                    self.stats['manual_added'] += 1
            
            except Exception as e:
                logger.error(f"Error adding manual URL {item['url']}: {e}")
                self.stats['errors'] += 1
        
        # Add manual phones
        for item in manual_phones:
            try:
                evidence = {
                    "source": "manual_curation",
                    "complaint_type": item["complaint_type"],
                    "date": datetime.now().isoformat(),
                    "verified": True
                }
                
                success = self.tool.add_report(
                    entity_type="phone",
                    entity_value=item["phone"],
                    evidence=evidence,
                    notes=item["notes"]
                )
                
                if success:
                    self.stats['manual_added'] += 1
            
            except Exception as e:
                logger.error(f"Error adding manual phone {item['phone']}: {e}")
                self.stats['errors'] += 1
        
        logger.info(f"Manual data seeding complete: {self.stats['manual_added']} entries added")
    
    def print_summary(self) -> None:
        """Print seeding summary statistics."""
        logger.info("")
        logger.info("=" * 80)
        logger.info("SEEDING SUMMARY")
        logger.info("=" * 80)
        logger.info(f"PhishTank:")
        logger.info(f"  - Added: {self.stats['phishtank_added']}")
        logger.info(f"  - Duplicates: {self.stats['phishtank_duplicates']}")
        logger.info(f"FTC Data:")
        logger.info(f"  - Added: {self.stats['ftc_added']}")
        logger.info(f"  - Duplicates: {self.stats['ftc_duplicates']}")
        logger.info(f"Manual Data:")
        logger.info(f"  - Added: {self.stats['manual_added']}")
        logger.info(f"Errors: {self.stats['errors']}")
        logger.info("")
        total_added = (
            self.stats['phishtank_added'] + 
            self.stats['ftc_added'] + 
            self.stats['manual_added']
        )
        logger.info(f"TOTAL ADDED: {total_added}")
        logger.info("=" * 80)


async def main():
    """Main entry point for seeding script."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Seed scam database with initial data')
    parser.add_argument(
        '--phishtank-limit',
        type=int,
        help='Limit PhishTank entries (for testing)',
        default=None
    )
    parser.add_argument(
        '--ftc-csv',
        type=str,
        help='Path to FTC CSV file',
        default=None
    )
    parser.add_argument(
        '--skip-phishtank',
        action='store_true',
        help='Skip PhishTank seeding'
    )
    parser.add_argument(
        '--skip-manual',
        action='store_true',
        help='Skip manual data seeding'
    )
    
    args = parser.parse_args()
    
    print("\n" + "=" * 80)
    print("SCAM DATABASE SEEDING SCRIPT")
    print("=" * 80)
    print("This will populate the scam_reports database with known scam data.")
    print("This may take several minutes for large datasets.")
    print("=" * 80 + "\n")
    
    seeder = ScamDatabaseSeeder()
    
    try:
        # Seed from PhishTank (largest dataset)
        if not args.skip_phishtank:
            await seeder.seed_from_phishtank(limit=args.phishtank_limit)
        
        # Seed from FTC CSV if provided
        if args.ftc_csv:
            seeder.seed_from_ftc_csv(args.ftc_csv)
        
        # Seed manual curated data
        if not args.skip_manual:
            seeder.seed_manual_data()
        
        # Print summary
        seeder.print_summary()
        
        print("\n✅ Seeding complete!\n")
        
    except KeyboardInterrupt:
        print("\n\n⚠️  Seeding interrupted by user")
        seeder.print_summary()
    except Exception as e:
        logger.error(f"Fatal error during seeding: {e}", exc_info=True)
        seeder.print_summary()
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())

