"""
Story 12.1: Feature Flag System Tests
Tests for backend feature flag configuration
"""

import os
import pytest
from app import config


class TestFeatureFlagConfig:
    """Test feature flag configuration parsing"""

    def test_enable_analyse_text_default(self, monkeypatch):
        """Test ENABLE_ANALYSE_TEXT defaults to False when not set"""
        # Remove environment variable if set
        monkeypatch.delenv("ENABLE_ANALYSE_TEXT", raising=False)

        # Re-import config to get fresh value
        import importlib
        importlib.reload(config)

        assert config.settings.enable_analyse_text is False

    def test_enable_analyse_text_true(self, monkeypatch):
        """Test ENABLE_ANALYSE_TEXT when set to 'true'"""
        monkeypatch.setenv("ENABLE_ANALYSE_TEXT", "true")

        # Re-import config
        import importlib
        importlib.reload(config)

        assert config.settings.enable_analyse_text is True

    def test_enable_analyse_text_false_explicit(self, monkeypatch):
        """Test ENABLE_ANALYSE_TEXT when explicitly set to 'false'"""
        monkeypatch.setenv("ENABLE_ANALYSE_TEXT", "false")

        # Re-import config
        import importlib
        importlib.reload(config)

        assert config.settings.enable_analyse_text is False

    def test_enable_analyse_text_case_insensitive(self, monkeypatch):
        """Test ENABLE_ANALYSE_TEXT parsing is case-insensitive"""
        test_cases = [
            ("TRUE", True),
            ("True", True),
            ("tRuE", True),
            ("FALSE", False),
            ("False", False),
            ("fAlSe", False),
        ]

        for env_value, expected in test_cases:
            monkeypatch.setenv("ENABLE_ANALYSE_TEXT", env_value)

            # Re-import config
            import importlib
            importlib.reload(config)

            assert config.settings.enable_analyse_text is expected, \
                f"Failed for env value: {env_value}"

    def test_enable_analyse_text_invalid_values(self, monkeypatch):
        """Test ENABLE_ANALYSE_TEXT with invalid values defaults to False"""
        invalid_values = ["yes", "no", "1", "0", "enabled", "disabled", ""]

        for invalid_value in invalid_values:
            monkeypatch.setenv("ENABLE_ANALYSE_TEXT", invalid_value)

            # Re-import config
            import importlib
            importlib.reload(config)

            assert config.settings.enable_analyse_text is False, \
                f"Invalid value '{invalid_value}' should default to False"
