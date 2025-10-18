#!/usr/bin/env python3
"""
Quick test script to demonstrate scam_phones table functionality.

Usage:
    python test_scam_phones.py

Make sure you have:
1. Run the 005_create_scam_phones.sql migration in Supabase
2. Set SUPABASE_URL and SUPABASE_KEY in your .env file
"""

import sys
from pathlib import Path

# Add backend app to path
backend_path = Path(__file__).parent
sys.path.insert(0, str(backend_path))

from app.db.operations import (
    check_scam_phone,
    insert_scam_phone,
    get_all_scam_phones,
    search_scam_phones_by_country
)


def main():
    print("=" * 60)
    print("Scam Phone Database Test")
    print("=" * 60)
    
    # Test 1: Check for the specific phone number
    print("\n[Test 1] Checking for +1 (734) 733-6172...")
    result = check_scam_phone("+1 (734) 733-6172")
    if result:
        print("✓ Found in database!")
        print(f"  Scam Type: {result.get('scam_type')}")
        print(f"  Report Count: {result.get('report_count')}")
        print(f"  Notes: {result.get('notes')}")
    else:
        print("✗ Not found in database")
    
    # Test 2: Get all scam phones
    print("\n[Test 2] Fetching all scam phone numbers...")
    all_scams = get_all_scam_phones(limit=20)
    print(f"✓ Found {len(all_scams)} scam numbers")
    print("\nTop 5 most reported:")
    for i, scam in enumerate(all_scams[:5], 1):
        print(f"  {i}. {scam['phone_number']}")
        print(f"     Type: {scam.get('scam_type', 'Unknown')}")
        print(f"     Reports: {scam.get('report_count', 0)}")
    
    # Test 3: Search by country code
    print("\n[Test 3] Searching for US scam numbers (+1)...")
    us_scams = search_scam_phones_by_country("+1")
    print(f"✓ Found {len(us_scams)} US scam numbers")
    
    # Test 4: Add a new scam number (or update existing)
    print("\n[Test 4] Adding/updating a test scam number...")
    try:
        new_number = "+1 (555) 123-4567"
        result = insert_scam_phone(
            phone_number=new_number,
            country_code="+1",
            scam_type="Test Entry",
            notes="This is a test entry created by test_scam_phones.py",
            report_count=1
        )
        print(f"✓ Successfully added/updated: {new_number}")
        print(f"  Total reports: {result.get('report_count')}")
    except Exception as e:
        print(f"✗ Error: {e}")
    
    # Test 5: Verify the new entry
    print("\n[Test 5] Verifying test entry...")
    test_result = check_scam_phone(new_number)
    if test_result:
        print(f"✓ Test entry verified in database")
        print(f"  ID: {test_result.get('id')}")
        print(f"  Created: {test_result.get('created_at')}")
    
    print("\n" + "=" * 60)
    print("All tests completed!")
    print("=" * 60)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"\n❌ Error running tests: {e}")
        print("\nMake sure you have:")
        print("1. Run the 005_create_scam_phones.sql migration in Supabase")
        print("2. Set SUPABASE_URL and SUPABASE_KEY in your .env file")
        sys.exit(1)

