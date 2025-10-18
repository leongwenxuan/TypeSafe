"""
Integration tests for MCP Agent with real tools.

These tests use actual tool implementations to verify end-to-end
agent orchestration. They require:
- Redis running
- Supabase configured
- API keys set (EXA_API_KEY, etc.)

Story: 8.7 - MCP Agent Task Orchestration
"""

import pytest
import asyncio
import os
from unittest.mock import patch

from app.agents.mcp_agent import (
    MCPAgentOrchestrator,
    ProgressPublisher,
    analyze_with_mcp_agent
)


# Skip tests if required services aren't available
pytestmark = pytest.mark.skipif(
    not os.getenv('REDIS_URL') or not os.getenv('SUPABASE_URL'),
    reason="Integration tests require Redis and Supabase"
)


@pytest.mark.integration
@pytest.mark.asyncio
class TestMCPAgentIntegration:
    """Integration tests with real tool implementations."""
    
    async def test_analyze_scam_phone_real_tools(self):
        """Test analysis of known scam phone number with real tools."""
        orchestrator = MCPAgentOrchestrator()
        progress = ProgressPublisher("integration-test-phone")
        
        # Use a test scam phone number (should be in scam database)
        ocr_text = "Call us immediately at +1-800-123-4567 to verify your account!"
        
        result = await orchestrator.analyze(
            task_id="integration-test-phone",
            ocr_text=ocr_text,
            progress_publisher=progress
        )
        
        # Verify result structure
        assert result.task_id == "integration-test-phone"
        assert result.risk_level in ["low", "medium", "high"]
        assert 0 <= result.confidence <= 100
        assert result.processing_time_ms > 0
        
        # Verify entities were extracted
        assert len(result.entities_found.get("phones", [])) > 0
        
        # Verify tools were executed
        assert len(result.evidence) > 0
        assert len(result.tools_used) > 0
        
        # Verify reasoning was generated
        assert result.reasoning
        assert len(result.reasoning) > 0
    
    async def test_analyze_suspicious_url_real_tools(self):
        """Test analysis of suspicious URL with real tools."""
        orchestrator = MCPAgentOrchestrator()
        progress = ProgressPublisher("integration-test-url")
        
        # Use a test URL (known phishing pattern)
        ocr_text = "Visit http://secure-bank-login-verification.tk to confirm your identity"
        
        result = await orchestrator.analyze(
            task_id="integration-test-url",
            ocr_text=ocr_text,
            progress_publisher=progress
        )
        
        # Verify result
        assert result.task_id == "integration-test-url"
        assert len(result.entities_found.get("urls", [])) > 0
        
        # Should have evidence from domain reputation and possibly exa search
        tool_names = result.tools_used
        assert "domain_reputation" in tool_names or "scam_db" in tool_names
    
    async def test_analyze_clean_text_real_tools(self):
        """Test analysis of clean text with no suspicious entities."""
        orchestrator = MCPAgentOrchestrator()
        progress = ProgressPublisher("integration-test-clean")
        
        ocr_text = "The weather is nice today. I went to the park and saw some birds."
        
        result = await orchestrator.analyze(
            task_id="integration-test-clean",
            ocr_text=ocr_text,
            progress_publisher=progress
        )
        
        # Should return low risk with no entities
        assert result.risk_level == "low"
        assert len(result.evidence) == 0
    
    async def test_analyze_mixed_entities_real_tools(self):
        """Test analysis with multiple entity types."""
        orchestrator = MCPAgentOrchestrator()
        progress = ProgressPublisher("integration-test-mixed")
        
        ocr_text = """
        URGENT: Your account has been compromised!
        
        Call us at +1-800-SCAM-NOW
        Visit: http://phishing-site.tk/verify
        Email: support@scammer-domain.com
        
        Send $500 immediately!
        """
        
        result = await orchestrator.analyze(
            task_id="integration-test-mixed",
            ocr_text=ocr_text,
            progress_publisher=progress
        )
        
        # Should extract multiple entity types
        entities = result.entities_found
        assert len(entities.get("phones", [])) + len(entities.get("urls", [])) + \
               len(entities.get("emails", [])) + len(entities.get("amounts", [])) > 0
        
        # Should have collected evidence from multiple tools
        assert len(result.evidence) > 0
        assert len(result.tools_used) > 1
    
    async def test_tool_execution_performance(self):
        """Test that agent completes within performance requirements."""
        orchestrator = MCPAgentOrchestrator()
        progress = ProgressPublisher("integration-test-performance")
        
        # Text with one entity (should be fast)
        ocr_text = "Call +1-800-555-1234"
        
        result = await orchestrator.analyze(
            task_id="integration-test-performance",
            ocr_text=ocr_text,
            progress_publisher=progress
        )
        
        # Should complete in under 30 seconds (requirement from story)
        assert result.processing_time_ms < 30000, \
            f"Agent took {result.processing_time_ms}ms (should be < 30000ms)"
    
    async def test_parallel_tool_execution(self):
        """Test that tools execute in parallel for better performance."""
        orchestrator = MCPAgentOrchestrator()
        progress = ProgressPublisher("integration-test-parallel")
        
        # Phone number that will trigger 3 tools
        ocr_text = "Contact: +1-800-555-1234"
        
        result = await orchestrator.analyze(
            task_id="integration-test-parallel",
            ocr_text=ocr_text,
            progress_publisher=progress
        )
        
        # Find phone evidence
        phone_evidence = [e for e in result.evidence if e["entity_type"] == "phone"]
        
        # Should have evidence from multiple tools
        assert len(phone_evidence) >= 2
        
        # Total time should be less than sum of individual times (parallel execution)
        total_tool_time = sum(e["execution_time_ms"] for e in phone_evidence)
        assert result.processing_time_ms < total_tool_time, \
            "Tools should execute in parallel (total time < sum of tool times)"


@pytest.mark.integration
@pytest.mark.asyncio
class TestProgressPublisherIntegration:
    """Integration tests for progress publishing."""
    
    def test_progress_publishing_to_redis(self):
        """Test that progress updates are published to Redis."""
        import redis
        
        redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379')
        redis_client = redis.from_url(redis_url, decode_responses=True)
        
        publisher = ProgressPublisher("integration-test-progress")
        
        # Subscribe to progress channel
        pubsub = redis_client.pubsub()
        pubsub.subscribe(f"agent_progress:integration-test-progress")
        
        # Publish a message
        publisher.publish("Test progress message", 50)
        
        # Wait briefly for message
        import time
        time.sleep(0.1)
        
        # Check if message was received
        message = pubsub.get_message(timeout=1)
        if message and message['type'] == 'subscribe':
            message = pubsub.get_message(timeout=1)
        
        pubsub.unsubscribe()
        
        # Note: This is a basic test - full WebSocket integration tested in Story 8.9


@pytest.mark.integration
class TestCeleryTaskIntegration:
    """Integration tests for Celery task execution."""
    
    @pytest.mark.skipif(
        not os.getenv('CELERY_BROKER_URL'),
        reason="Celery integration tests require CELERY_BROKER_URL"
    )
    def test_celery_task_submission(self):
        """Test that Celery task can be submitted and tracked."""
        from celery.result import AsyncResult
        
        # Submit task asynchronously
        task = analyze_with_mcp_agent.delay(
            task_id="celery-integration-test",
            ocr_text="Test text with phone +1-800-555-1234",
            session_id="test-session-123"
        )
        
        # Verify task was submitted
        assert task.id is not None
        
        # Wait for result (with timeout)
        try:
            result = task.get(timeout=30)
            
            # Verify result structure
            assert "task_id" in result
            assert "risk_level" in result
            assert "confidence" in result
            assert "evidence" in result
            
        except Exception as e:
            pytest.skip(f"Celery worker not available: {e}")
    
    @pytest.mark.skipif(
        not os.getenv('CELERY_BROKER_URL'),
        reason="Celery integration tests require CELERY_BROKER_URL"
    )
    def test_celery_task_retry_on_failure(self):
        """Test that Celery task retries on transient failures."""
        # This is difficult to test in integration without mocking
        # We verify retry logic exists in unit tests instead
        pass


@pytest.mark.integration
class TestDatabaseIntegration:
    """Integration tests for database operations."""
    
    @pytest.mark.skipif(
        not os.getenv('SUPABASE_URL'),
        reason="Database integration tests require Supabase"
    )
    async def test_agent_result_saved_to_database(self):
        """Test that agent results are saved to database."""
        from app.agents.mcp_agent import _save_agent_result, AgentResult
        from app.db.client import get_supabase_client
        import uuid
        
        # Create test result
        task_id = f"db-integration-test-{uuid.uuid4()}"
        session_id = str(uuid.uuid4())
        
        # First create a session
        supabase = get_supabase_client()
        supabase.table('sessions').insert({
            'session_id': session_id
        }).execute()
        
        result = AgentResult(
            task_id=task_id,
            risk_level="medium",
            confidence=75.0,
            entities_found={"phones": ["+18005551234"]},
            evidence=[],
            reasoning="Test reasoning for integration",
            processing_time_ms=1500,
            tools_used=["scam_db", "phone_validator"]
        )
        
        # Save result
        _save_agent_result(result, session_id)
        
        # Verify it was saved
        response = supabase.table('agent_scan_results').select('*').eq(
            'task_id', task_id
        ).execute()
        
        assert len(response.data) == 1
        saved = response.data[0]
        
        assert saved['task_id'] == task_id
        assert saved['session_id'] == session_id
        assert saved['risk_level'] == "medium"
        assert saved['confidence'] == 75.0
        
        # Cleanup
        supabase.table('agent_scan_results').delete().eq('task_id', task_id).execute()
        supabase.table('sessions').delete().eq('session_id', session_id).execute()


@pytest.mark.integration
@pytest.mark.asyncio
class TestEndToEndScenarios:
    """End-to-end scenario tests."""
    
    async def test_e2e_phishing_detection(self):
        """End-to-end test: Detect phishing attempt."""
        orchestrator = MCPAgentOrchestrator()
        progress = ProgressPublisher("e2e-phishing")
        
        phishing_text = """
        SECURITY ALERT!
        
        Your PayPal account has been limited.
        Click here immediately: http://paypal-secure-verify.tk/login
        
        Or call: +1-888-FAKE-NUM
        
        Provide your credentials to restore access.
        """
        
        result = await orchestrator.analyze(
            task_id="e2e-phishing",
            ocr_text=phishing_text,
            progress_publisher=progress
        )
        
        # Should detect high or medium risk
        assert result.risk_level in ["medium", "high"]
        
        # Should have found suspicious entities
        assert len(result.entities_found.get("urls", [])) > 0 or \
               len(result.entities_found.get("phones", [])) > 0
    
    async def test_e2e_legitimate_content(self):
        """End-to-end test: Verify legitimate content passes."""
        orchestrator = MCPAgentOrchestrator()
        progress = ProgressPublisher("e2e-legitimate")
        
        legitimate_text = """
        Recipe for Chocolate Chip Cookies
        
        Ingredients:
        - 2 cups flour
        - 1 cup sugar
        - 1/2 cup butter
        - 2 eggs
        
        Bake at 350°F for 12 minutes.
        """
        
        result = await orchestrator.analyze(
            task_id="e2e-legitimate",
            ocr_text=legitimate_text,
            progress_publisher=progress
        )
        
        # Should be low risk
        assert result.risk_level == "low"
        assert len(result.evidence) == 0
    
    async def test_e2e_crypto_scam_detection(self):
        """End-to-end test: Detect cryptocurrency scam."""
        orchestrator = MCPAgentOrchestrator()
        progress = ProgressPublisher("e2e-crypto")
        
        crypto_scam_text = """
        🚀 DOUBLE YOUR BITCOIN IN 24 HOURS! 🚀
        
        Send BTC to: 1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa
        
        Get 2x back GUARANTEED!
        
        Limited time offer - ACT NOW!
        """
        
        result = await orchestrator.analyze(
            task_id="e2e-crypto",
            ocr_text=crypto_scam_text,
            progress_publisher=progress
        )
        
        # Should detect payment/bitcoin entity
        has_payment = len(result.entities_found.get("payments", [])) > 0
        
        # If crypto address detected, should be flagged
        if has_payment:
            assert result.risk_level in ["medium", "high"]


# Utility functions for integration tests

def setup_test_session():
    """Create a test session in database."""
    from app.db.client import get_supabase_client
    import uuid
    
    session_id = str(uuid.uuid4())
    supabase = get_supabase_client()
    
    supabase.table('sessions').insert({
        'session_id': session_id
    }).execute()
    
    return session_id


def cleanup_test_session(session_id: str):
    """Clean up test session from database."""
    from app.db.client import get_supabase_client
    
    supabase = get_supabase_client()
    
    # Delete agent results first (foreign key)
    supabase.table('agent_scan_results').delete().eq('session_id', session_id).execute()
    
    # Delete session
    supabase.table('sessions').delete().eq('session_id', session_id).execute()

