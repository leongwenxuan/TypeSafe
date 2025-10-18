"""
MCP Agent Tools Package.

This package contains specialized tools used by the MCP agent for scam detection:
- ScamDatabaseTool: Query known scam database
- PhoneValidatorTool: Validate phone numbers and detect suspicious patterns
- (Future) ExaSearchTool: Web search for scam reports
- (Future) DomainReputationTool: Check domain reputation
"""

from .scam_database import ScamDatabaseTool, ScamLookupResult, get_scam_database_tool
from .phone_validator import PhoneValidatorTool, PhoneValidationResult, get_phone_validator_tool

__all__ = [
    'ScamDatabaseTool',
    'ScamLookupResult',
    'get_scam_database_tool',
    'PhoneValidatorTool',
    'PhoneValidationResult',
    'get_phone_validator_tool',
]

