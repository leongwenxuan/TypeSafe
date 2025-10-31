"""
Example usage of Domain Reputation Tool (Story 8.5).

This script demonstrates how to use the domain reputation tool to analyze URLs.
"""

import asyncio
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(__file__))

from app.agents.tools.domain_reputation import get_domain_reputation_tool


async def main():
    """Demonstrate domain reputation checking."""
    
    # Get tool instance
    tool = get_domain_reputation_tool()
    
    # Test domains (mix of safe and suspicious)
    test_domains = [
        "google.com",
        "github.com",
        "very-new-suspicious-site-2025.com",
        "malware-test-site.invalid",
    ]
    
    print("=" * 80)
    print("Domain Reputation Tool - Usage Example")
    print("=" * 80)
    print()
    
    for domain in test_domains:
        print(f"Analyzing: {domain}")
        print("-" * 80)
        
        try:
            result = await tool.check_domain(domain)
            
            # Display results
            print(f"  Domain:           {result.domain}")
            print(f"  Risk Level:       {result.risk_level.upper()}")
            print(f"  Risk Score:       {result.risk_score:.1f}/100")
            print()
            print(f"  Domain Age:       {result.age_days if result.age_days else 'Unknown'} days")
            print(f"  SSL Valid:        {'✓' if result.ssl_valid else '✗'}")
            print(f"  SSL Expiry:       {result.ssl_expiry_days if result.ssl_expiry_days else 'N/A'} days")
            print(f"  VirusTotal:       {result.virustotal_malicious}/{result.virustotal_total} flagged")
            print(f"  Safe Browsing:    {'FLAGGED' if result.safe_browsing_flagged else 'Clean'}")
            print()
            print(f"  Checks Completed: {sum(result.checks_completed.values())}/4")
            
            if result.error_messages:
                print(f"  Errors:")
                for check, error in result.error_messages.items():
                    print(f"    - {check}: {error}")
            
            # Risk assessment
            if result.risk_level == "high":
                print(f"\n  ⚠️  WARNING: This domain appears to be HIGH RISK!")
            elif result.risk_level == "medium":
                print(f"\n  ⚡ CAUTION: This domain shows some suspicious indicators.")
            elif result.risk_level == "low":
                print(f"\n  ✅ This domain appears to be safe.")
            else:
                print(f"\n  ❓ Unable to determine risk level.")
            
        except Exception as e:
            print(f"  ERROR: {e}")
        
        print()
    
    print("=" * 80)
    print("Example complete!")
    print()
    print("Notes:")
    print("  - WHOIS and SSL checks work without API keys")
    print("  - VirusTotal and Safe Browsing require API keys (optional)")
    print("  - Results are cached for 7 days in Redis")
    print("  - All checks run in parallel for fast results")
    print("=" * 80)


if __name__ == "__main__":
    asyncio.run(main())

