"""
Configuration management using environment variables.

Loads configuration from .env file and validates required settings.
"""
import os
from typing import List

from pydantic_settings import BaseSettings
from pydantic import Field, ConfigDict, field_validator


class Settings(BaseSettings):
    """
    Application settings loaded from environment variables.
    
    Required variables:
    - GROQ_API_KEY: Groq API key for text analysis
    - GEMINI_API_KEY: Google Gemini API key for multimodal analysis
    - SUPABASE_URL: Supabase project URL
    - SUPABASE_KEY: Supabase API key
    - BACKEND_API_KEY: API key for iOS app authentication
    """
    
    model_config = ConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="allow"  # Allow extra fields for testing
    )
    
    # Environment
    environment: str = Field(default="local", alias="ENVIRONMENT")
    
    # API Keys
    groq_api_key: str = Field(default="", alias="GROQ_API_KEY")
    gemini_api_key: str = Field(default="", alias="GEMINI_API_KEY")
    supabase_url: str = Field(default="", alias="SUPABASE_URL")
    supabase_key: str = Field(default="", alias="SUPABASE_KEY")
    backend_api_key: str = Field(default="", alias="BACKEND_API_KEY")
    
    # MCP Agent Tool API Keys
    exa_api_key: str = Field(
        default="",
        alias="EXA_API_KEY",
        description="Exa API key for web search (Story 8.4)"
    )
    
    # CORS settings
    cors_origins: List[str] = Field(
        default=["*"],
        description="Allowed CORS origins"
    )
    
    # Redis & Celery settings
    redis_url: str = Field(
        default="redis://localhost:6379",
        alias="REDIS_URL",
        description="Redis server URL"
    )
    celery_broker_url: str = Field(
        default="redis://localhost:6379/0",
        alias="CELERY_BROKER_URL",
        description="Celery broker URL (Redis database 0)"
    )
    celery_result_backend: str = Field(
        default="redis://localhost:6379/1",
        alias="CELERY_RESULT_BACKEND",
        description="Celery result backend URL (Redis database 1)"
    )
    
    # Domain Reputation Tool API Keys (Story 8.5)
    virustotal_api_key: str = Field(
        default="",
        alias="VIRUSTOTAL_API_KEY",
        description="VirusTotal API key for domain scanning (optional)"
    )
    safe_browsing_api_key: str = Field(
        default="",
        alias="SAFE_BROWSING_API_KEY",
        description="Google Safe Browsing API key (optional)"
    )
    
    # MCP Agent settings
    enable_mcp_agent: bool = Field(
        default=True,
        alias="ENABLE_MCP_AGENT",
        description="Enable MCP agent for complex scans (Story 8.10)"
    )
    exa_cache_ttl: int = Field(
        default=86400,
        alias="EXA_CACHE_TTL",
        description="Exa search cache TTL in seconds (default 24 hours)"
    )
    exa_max_results: int = Field(
        default=10,
        alias="EXA_MAX_RESULTS",
        description="Maximum number of Exa search results per query"
    )
    exa_daily_budget: float = Field(
        default=10.0,
        alias="EXA_DAILY_BUDGET",
        description="Daily budget limit for Exa API in USD"
    )

    # Feature Flags (Story 12.1)
    enable_analyse_text: bool = Field(
        default=False,
        alias="ENABLE_ANALYSE_TEXT",
        description="Controls availability of text analysis feature (Story 12.1)"
    )

    @field_validator("enable_analyse_text", mode="before")
    @classmethod
    def validate_enable_analyse_text(cls, v):
        """Validate ENABLE_ANALYSE_TEXT strictly accepts only 'true' or 'false' strings"""
        if isinstance(v, bool):
            return v
        if isinstance(v, str):
            return v.lower() == "true"
        return False

    def validate_required_keys(self) -> None:
        """
        Validate that all required API keys are present.
        
        Raises:
            ValueError: If any required key is missing
        """
        required_keys = {
            "GROQ_API_KEY": self.groq_api_key,
            "GEMINI_API_KEY": self.gemini_api_key,
            "SUPABASE_URL": self.supabase_url,
            "SUPABASE_KEY": self.supabase_key,
            "BACKEND_API_KEY": self.backend_api_key,
        }
        
        missing_keys = [
            key for key, value in required_keys.items() 
            if not value or value == ""
        ]
        
        if missing_keys:
            raise ValueError(
                f"Missing required environment variables: {', '.join(missing_keys)}. "
                f"Please check your .env file."
            )


# Global settings instance
settings = Settings()

