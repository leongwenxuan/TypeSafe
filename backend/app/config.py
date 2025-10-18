"""
Configuration management using environment variables.

Loads configuration from .env file and validates required settings.
"""
import os
from typing import List

from pydantic_settings import BaseSettings
from pydantic import Field, ConfigDict


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
    
    # CORS settings
    cors_origins: List[str] = Field(
        default=["*"],
        description="Allowed CORS origins"
    )
    
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

