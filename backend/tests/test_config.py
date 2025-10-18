"""
Tests for configuration management.

Tests configuration loading, validation, and error handling.
"""
import os
import pytest
from unittest.mock import patch

from app.config import Settings


class TestSettings:
    """Test suite for Settings configuration class"""
    
    def test_settings_loads_from_env(self):
        """Test that settings loads values from environment variables"""
        with patch.dict(os.environ, {
            'ENVIRONMENT': 'test',
            'OPENAI_API_KEY': 'test-openai-key',
            'GEMINI_API_KEY': 'test-gemini-key',
            'SUPABASE_URL': 'https://test.supabase.co',
            'SUPABASE_KEY': 'test-supabase-key',
            'BACKEND_API_KEY': 'test-backend-key',
        }):
            settings = Settings()
            
            assert settings.environment == 'test'
            assert settings.openai_api_key == 'test-openai-key'
            assert settings.gemini_api_key == 'test-gemini-key'
            assert settings.supabase_url == 'https://test.supabase.co'
            assert settings.supabase_key == 'test-supabase-key'
            assert settings.backend_api_key == 'test-backend-key'
    
    def test_settings_default_environment(self):
        """Test that environment defaults to 'local' when not set"""
        with patch.dict(os.environ, {
            'OPENAI_API_KEY': 'test-key',
            'GEMINI_API_KEY': 'test-key',
            'SUPABASE_URL': 'https://test.supabase.co',
            'SUPABASE_KEY': 'test-key',
            'BACKEND_API_KEY': 'test-key',
        }, clear=True):
            # Remove ENVIRONMENT if it exists
            os.environ.pop('ENVIRONMENT', None)
            settings = Settings()
            
            assert settings.environment == 'local'
    
    def test_validate_required_keys_success(self):
        """Test validation passes with all required keys present"""
        with patch.dict(os.environ, {
            'OPENAI_API_KEY': 'test-openai-key',
            'GEMINI_API_KEY': 'test-gemini-key',
            'SUPABASE_URL': 'https://test.supabase.co',
            'SUPABASE_KEY': 'test-supabase-key',
            'BACKEND_API_KEY': 'test-backend-key',
        }):
            settings = Settings()
            
            # Should not raise any exception
            settings.validate_required_keys()
    
    def test_validate_required_keys_missing_openai(self):
        """Test validation fails when OPENAI_API_KEY is missing"""
        with patch.dict(os.environ, {
            'ENVIRONMENT': 'test',
            'OPENAI_API_KEY': '',  # Empty/missing
            'GEMINI_API_KEY': 'test-gemini-key',
            'SUPABASE_URL': 'https://test.supabase.co',
            'SUPABASE_KEY': 'test-supabase-key',
            'BACKEND_API_KEY': 'test-backend-key',
        }, clear=True):
            settings = Settings()
            
            with pytest.raises(ValueError) as exc_info:
                settings.validate_required_keys()
            
            assert 'OPENAI_API_KEY' in str(exc_info.value)
    
    def test_validate_required_keys_missing_multiple(self):
        """Test validation fails with multiple missing keys"""
        with patch.dict(os.environ, {
            'ENVIRONMENT': 'test',
            'OPENAI_API_KEY': 'test-key',
            'GEMINI_API_KEY': '',  # Empty/missing
            'SUPABASE_URL': '',  # Empty/missing
            'SUPABASE_KEY': '',  # Empty/missing
            'BACKEND_API_KEY': '',  # Empty/missing
        }, clear=True):
            settings = Settings()
            
            with pytest.raises(ValueError) as exc_info:
                settings.validate_required_keys()
            
            error_message = str(exc_info.value)
            assert 'GEMINI_API_KEY' in error_message
            assert 'SUPABASE_URL' in error_message
            assert 'SUPABASE_KEY' in error_message
            assert 'BACKEND_API_KEY' in error_message
    
    def test_validate_required_keys_empty_string(self):
        """Test validation fails when keys are empty strings"""
        with patch.dict(os.environ, {
            'OPENAI_API_KEY': '',
            'GEMINI_API_KEY': 'test-key',
            'SUPABASE_URL': 'https://test.supabase.co',
            'SUPABASE_KEY': 'test-key',
            'BACKEND_API_KEY': 'test-key',
        }):
            settings = Settings()
            
            with pytest.raises(ValueError) as exc_info:
                settings.validate_required_keys()
            
            assert 'OPENAI_API_KEY' in str(exc_info.value)
    
    def test_cors_origins_default(self):
        """Test CORS origins defaults to allow all"""
        with patch.dict(os.environ, {
            'OPENAI_API_KEY': 'test-key',
            'GEMINI_API_KEY': 'test-key',
            'SUPABASE_URL': 'https://test.supabase.co',
            'SUPABASE_KEY': 'test-key',
            'BACKEND_API_KEY': 'test-key',
        }):
            settings = Settings()
            
            assert settings.cors_origins == ['*']

