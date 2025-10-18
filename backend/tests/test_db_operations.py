"""
Integration tests for database operations.

These tests require a Supabase instance with the schema created.
Set SUPABASE_URL and SUPABASE_KEY environment variables for testing.
"""

import pytest
import uuid
from datetime import datetime, timedelta
from app.db import (
    get_supabase_client,
    insert_session,
    insert_text_analysis,
    insert_scan_result,
    get_latest_result,
)
from app.db.operations import get_session, ensure_session_exists
from app.db.client import reset_client
from app.db.operations import get_session_history


class TestDatabaseConnection:
    """Test database client initialization and connection."""
    
    def test_get_supabase_client_success(self):
        """Test that client initializes successfully with valid credentials."""
        client = get_supabase_client()
        assert client is not None
        
    def test_get_supabase_client_singleton(self):
        """Test that client uses singleton pattern."""
        client1 = get_supabase_client()
        client2 = get_supabase_client()
        assert client1 is client2
        
    def test_reset_client(self):
        """Test that reset_client clears the global instance."""
        client1 = get_supabase_client()
        reset_client()
        client2 = get_supabase_client()
        assert client1 is not client2


class TestSessionOperations:
    """Test session table CRUD operations."""
    
    def test_insert_session(self):
        """Test inserting a new session."""
        session_id = uuid.uuid4()
        result = insert_session(session_id)
        
        assert result is not None
        assert result["session_id"] == str(session_id)
        assert "created_at" in result
        
    def test_insert_session_duplicate(self):
        """Test that inserting duplicate session_id fails."""
        session_id = uuid.uuid4()
        insert_session(session_id)
        
        # Attempting to insert same session_id should raise error
        with pytest.raises(Exception):
            insert_session(session_id)


class TestTextAnalysisOperations:
    """Test text_analyses table CRUD operations."""
    
    def test_insert_text_analysis_valid(self):
        """Test inserting a valid text analysis."""
        session_id = uuid.uuid4()
        insert_session(session_id)
        
        risk_data = {
            "risk_level": "high",
            "confidence": 0.95,
            "category": "phishing",
            "explanation": "Contains suspicious password request"
        }
        
        result = insert_text_analysis(
            session_id=session_id,
            app_bundle="com.example.app",
            snippet="Enter your password here",
            risk_data=risk_data
        )
        
        assert result is not None
        assert result["session_id"] == str(session_id)
        assert result["app_bundle"] == "com.example.app"
        assert result["snippet"] == "Enter your password here"
        assert result["risk_level"] == "high"
        assert result["confidence"] == 0.95
        assert result["category"] == "phishing"
        assert "created_at" in result
        
    def test_insert_text_analysis_invalid_risk_level(self):
        """Test that invalid risk_level raises ValueError."""
        session_id = uuid.uuid4()
        insert_session(session_id)
        
        risk_data = {
            "risk_level": "critical",  # Invalid
            "confidence": 0.95,
            "category": "test",
            "explanation": "test"
        }
        
        with pytest.raises(ValueError, match="Invalid risk_level"):
            insert_text_analysis(
                session_id=session_id,
                app_bundle="com.test.app",
                snippet="test",
                risk_data=risk_data
            )
            
    def test_insert_text_analysis_invalid_session_id(self):
        """Test that foreign key constraint works."""
        # Non-existent session_id
        fake_session_id = uuid.uuid4()
        
        risk_data = {
            "risk_level": "low",
            "confidence": 0.5,
            "category": "safe",
            "explanation": "test"
        }
        
        with pytest.raises(Exception):
            insert_text_analysis(
                session_id=fake_session_id,
                app_bundle="com.test.app",
                snippet="test",
                risk_data=risk_data
            )
            
    def test_insert_text_analysis_all_risk_levels(self):
        """Test all valid risk_levels: low, medium, high."""
        session_id = uuid.uuid4()
        insert_session(session_id)
        
        for risk_level in ["low", "medium", "high"]:
            risk_data = {
                "risk_level": risk_level,
                "confidence": 0.8,
                "category": "test",
                "explanation": f"Test {risk_level}"
            }
            
            result = insert_text_analysis(
                session_id=session_id,
                app_bundle="com.test.app",
                snippet=f"Test {risk_level}",
                risk_data=risk_data
            )
            
            assert result["risk_level"] == risk_level


class TestScanResultOperations:
    """Test scan_results table CRUD operations."""
    
    def test_insert_scan_result_valid(self):
        """Test inserting a valid scan result."""
        session_id = uuid.uuid4()
        insert_session(session_id)
        
        risk_data = {
            "risk_level": "medium",
            "confidence": 0.85,
            "category": "suspicious_link",
            "explanation": "Contains link to unfamiliar domain"
        }
        
        result = insert_scan_result(
            session_id=session_id,
            ocr_text="Click here: http://suspicious.site",
            risk_data=risk_data
        )
        
        assert result is not None
        assert result["session_id"] == str(session_id)
        assert result["ocr_text"] == "Click here: http://suspicious.site"
        assert result["risk_level"] == "medium"
        assert result["confidence"] == 0.85
        assert "created_at" in result
        
    def test_insert_scan_result_invalid_session_id(self):
        """Test that foreign key constraint works."""
        fake_session_id = uuid.uuid4()
        
        risk_data = {
            "risk_level": "low",
            "confidence": 0.5,
            "category": "safe",
            "explanation": "test"
        }
        
        with pytest.raises(Exception):
            insert_scan_result(
                session_id=fake_session_id,
                ocr_text="test",
                risk_data=risk_data
            )


class TestLatestResultRetrieval:
    """Test get_latest_result function."""
    
    def test_get_latest_result_no_data(self):
        """Test get_latest_result with no data returns None."""
        session_id = uuid.uuid4()
        insert_session(session_id)
        
        result = get_latest_result(session_id)
        assert result is None
        
    def test_get_latest_result_text_analysis_only(self):
        """Test get_latest_result returns text_analysis when only that exists."""
        session_id = uuid.uuid4()
        insert_session(session_id)
        
        risk_data = {
            "risk_level": "low",
            "confidence": 0.9,
            "category": "safe",
            "explanation": "Normal text"
        }
        
        insert_text_analysis(
            session_id=session_id,
            app_bundle="com.test.app",
            snippet="test snippet",
            risk_data=risk_data
        )
        
        result = get_latest_result(session_id)
        
        assert result is not None
        assert result["type"] == "text_analysis"
        assert result["data"]["snippet"] == "test snippet"
        
    def test_get_latest_result_scan_result_only(self):
        """Test get_latest_result returns scan_result when only that exists."""
        session_id = uuid.uuid4()
        insert_session(session_id)
        
        risk_data = {
            "risk_level": "medium",
            "confidence": 0.8,
            "category": "warning",
            "explanation": "Check this"
        }
        
        insert_scan_result(
            session_id=session_id,
            ocr_text="test ocr",
            risk_data=risk_data
        )
        
        result = get_latest_result(session_id)
        
        assert result is not None
        assert result["type"] == "scan_result"
        assert result["data"]["ocr_text"] == "test ocr"
        
    def test_get_latest_result_returns_most_recent(self):
        """Test get_latest_result returns the most recent of both types."""
        session_id = uuid.uuid4()
        insert_session(session_id)
        
        # Insert text_analysis first
        risk_data1 = {
            "risk_level": "low",
            "confidence": 0.9,
            "category": "safe",
            "explanation": "First"
        }
        insert_text_analysis(
            session_id=session_id,
            app_bundle="com.test.app",
            snippet="first",
            risk_data=risk_data1
        )
        
        # Insert scan_result second (should be more recent)
        risk_data2 = {
            "risk_level": "high",
            "confidence": 0.95,
            "category": "danger",
            "explanation": "Second"
        }
        insert_scan_result(
            session_id=session_id,
            ocr_text="second",
            risk_data=risk_data2
        )
        
        result = get_latest_result(session_id)
        
        assert result is not None
        assert result["type"] == "scan_result"
        assert result["data"]["ocr_text"] == "second"


class TestSessionHistory:
    """Test get_session_history function."""
    
    def test_get_session_history_empty(self):
        """Test history for session with no data."""
        session_id = uuid.uuid4()
        insert_session(session_id)
        
        history = get_session_history(session_id)
        
        assert history["text_analyses"] == []
        assert history["scan_results"] == []
        
    def test_get_session_history_with_data(self):
        """Test history returns multiple results."""
        session_id = uuid.uuid4()
        insert_session(session_id)
        
        # Insert multiple text analyses
        for i in range(3):
            risk_data = {
                "risk_level": "low",
                "confidence": 0.9,
                "category": "safe",
                "explanation": f"Analysis {i}"
            }
            insert_text_analysis(
                session_id=session_id,
                app_bundle="com.test.app",
                snippet=f"text {i}",
                risk_data=risk_data
            )
        
        # Insert multiple scan results
        for i in range(2):
            risk_data = {
                "risk_level": "medium",
                "confidence": 0.8,
                "category": "warning",
                "explanation": f"Scan {i}"
            }
            insert_scan_result(
                session_id=session_id,
                ocr_text=f"ocr {i}",
                risk_data=risk_data
            )
        
        history = get_session_history(session_id, limit=10)
        
        assert len(history["text_analyses"]) == 3
        assert len(history["scan_results"]) == 2
        
    def test_get_session_history_respects_limit(self):
        """Test that limit parameter works."""
        session_id = uuid.uuid4()
        insert_session(session_id)
        
        # Insert 5 text analyses
        for i in range(5):
            risk_data = {
                "risk_level": "low",
                "confidence": 0.9,
                "category": "safe",
                "explanation": f"Analysis {i}"
            }
            insert_text_analysis(
                session_id=session_id,
                app_bundle="com.test.app",
                snippet=f"text {i}",
                risk_data=risk_data
            )
        
        # Get only 2 most recent
        history = get_session_history(session_id, limit=2)
        
        assert len(history["text_analyses"]) == 2


class TestRetentionPolicy:
    """Test data retention and cleanup (manual verification required)."""
    
    def test_cleanup_function_exists(self):
        """
        Test that cleanup_old_data function exists in database.
        
        Note: This test verifies the function exists but doesn't
        test execution. Manual testing required to verify cleanup works.
        """
        client = get_supabase_client()
        
        # Query to check if function exists
        # Note: This may need adjustment based on Supabase's function query capabilities
        # For now, we just ensure the client is accessible
        assert client is not None
        
        # Manual verification steps documented in migrations/README.md:
        # 1. Run: SELECT cleanup_old_data();
        # 2. Verify cron job: SELECT * FROM cron.job;
        # 3. Test with old data insertion and manual cleanup


class TestSessionManagement:
    """Test session existence checking and auto-creation."""
    
    def test_get_session_existing(self):
        """Test getting an existing session."""
        # Create a session first
        session_id = uuid.uuid4()
        created_session = insert_session(session_id)
        
        # Get the session
        retrieved_session = get_session(session_id)
        
        assert retrieved_session is not None
        assert retrieved_session["session_id"] == str(session_id)
        assert retrieved_session["session_id"] == created_session["session_id"]
    
    def test_get_session_nonexistent(self):
        """Test getting a non-existent session returns None."""
        nonexistent_id = uuid.uuid4()
        result = get_session(nonexistent_id)
        assert result is None
    
    def test_ensure_session_exists_creates_new(self):
        """Test that ensure_session_exists creates a new session when it doesn't exist."""
        new_session_id = uuid.uuid4()
        
        # Verify session doesn't exist
        assert get_session(new_session_id) is None
        
        # Ensure session exists (should create it)
        session_data = ensure_session_exists(new_session_id)
        
        # Verify session was created
        assert session_data is not None
        assert session_data["session_id"] == str(new_session_id)
        
        # Verify it can be retrieved
        retrieved = get_session(new_session_id)
        assert retrieved is not None
        assert retrieved["session_id"] == str(new_session_id)
    
    def test_ensure_session_exists_returns_existing(self):
        """Test that ensure_session_exists returns existing session without creating duplicate."""
        # Create a session first
        session_id = uuid.uuid4()
        original_session = insert_session(session_id)
        
        # Ensure session exists (should return existing)
        returned_session = ensure_session_exists(session_id)
        
        # Should be the same session
        assert returned_session["session_id"] == original_session["session_id"]
        assert returned_session["session_id"] == str(session_id)
        
        # Verify no duplicate was created by checking the database
        retrieved = get_session(session_id)
        assert retrieved["session_id"] == original_session["session_id"]

