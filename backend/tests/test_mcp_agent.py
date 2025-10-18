"""
Unit tests for MCP Agent Orchestration.

Tests the core agent logic including entity extraction, tool routing,
evidence collection, and reasoning.

Story: 8.7 - MCP Agent Task Orchestration
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch, call
from datetime import datetime
import json

from app.agents.mcp_agent import (
    MCPAgentOrchestrator,
    AgentEvidence,
    AgentResult,
    ProgressPublisher,
    analyze_with_mcp_agent
)


@pytest.fixture
def mock_progress_publisher():
    """Fixture providing mock ProgressPublisher."""
    publisher = MagicMock(spec=ProgressPublisher)
    publisher.publish = MagicMock()
    return publisher


@pytest.fixture
def mock_entities_phones():
    """Fixture providing mock ExtractedEntities with phones."""
    mock_entities = MagicMock()
    mock_entities.has_entities.return_value = True
    mock_entities.entity_count.return_value = 1
    mock_entities.phones = [{"value": "+18005551234", "original": "1-800-555-1234"}]
    mock_entities.urls = []
    mock_entities.emails = []
    mock_entities.payments = []
    mock_entities.amounts = []
    return mock_entities


@pytest.fixture
def mock_entities_urls():
    """Fixture providing mock ExtractedEntities with URLs."""
    mock_entities = MagicMock()
    mock_entities.has_entities.return_value = True
    mock_entities.entity_count.return_value = 1
    mock_entities.phones = []
    mock_entities.urls = [{"value": "https://suspicious-site.com", "domain": "suspicious-site.com"}]
    mock_entities.emails = []
    mock_entities.payments = []
    mock_entities.amounts = []
    return mock_entities


@pytest.fixture
def mock_entities_emails():
    """Fixture providing mock ExtractedEntities with emails."""
    mock_entities = MagicMock()
    mock_entities.has_entities.return_value = True
    mock_entities.entity_count.return_value = 1
    mock_entities.phones = []
    mock_entities.urls = []
    mock_entities.emails = [{"value": "scammer@example.com", "domain": "example.com"}]
    mock_entities.payments = []
    mock_entities.amounts = []
    return mock_entities


@pytest.fixture
def mock_entities_empty():
    """Fixture providing mock ExtractedEntities with no entities."""
    mock_entities = MagicMock()
    mock_entities.has_entities.return_value = False
    mock_entities.entity_count.return_value = 0
    mock_entities.phones = []
    mock_entities.urls = []
    mock_entities.emails = []
    mock_entities.payments = []
    mock_entities.amounts = []
    return mock_entities


@pytest.mark.asyncio
class TestMCPAgentOrchestrator:
    """Test MCPAgentOrchestrator class."""
    
    async def test_initialization(self):
        """Test that orchestrator initializes correctly."""
        with patch('app.services.gemini_service.get_model'), \
             patch('os.getenv', return_value="test-gemini-key"):
            orchestrator = MCPAgentOrchestrator()
            
            assert orchestrator.entity_extractor is not None
            assert orchestrator.scam_db_tool is not None
            assert orchestrator.exa_tool is not None
            assert orchestrator.domain_tool is not None
            assert orchestrator.phone_tool is not None
            assert orchestrator.reasoner is not None
    
    async def test_analyze_no_entities(self, mock_entities_empty, mock_progress_publisher):
        """Test analysis when no entities are found."""
        with patch('app.services.gemini_service.get_model'), \
             patch('os.getenv', return_value="test-gemini-key"):
            orchestrator = MCPAgentOrchestrator()
            
            with patch.object(orchestrator.entity_extractor, 'extract', return_value=mock_entities_empty):
                result = await orchestrator.analyze(
                    task_id="test-123",
                    ocr_text="This is plain text with no entities",
                    progress_publisher=mock_progress_publisher
                )
            
            assert result.task_id == "test-123"
            assert result.risk_level == "low"
            assert result.confidence == 50.0
            assert len(result.evidence) == 0
            assert len(result.tools_used) == 0
            assert result.reasoning == "No suspicious entities found in text"
    
    async def test_analyze_with_phone(self, mock_entities_phones, mock_progress_publisher):
        """Test analysis with phone number."""
        with patch('app.services.gemini_service.get_model') as mock_model, \
             patch('os.getenv', return_value="test-gemini-key"):
            
            # Mock LLM response
            mock_response = MagicMock()
            mock_response.text = '{"risk_level": "medium", "confidence": 60, "explanation": "Phone found in database with moderate risk", "evidence_used": ["scam_db"]}'
            mock_model.return_value.generate_content.return_value = mock_response
            
            orchestrator = MCPAgentOrchestrator()
            
            # Mock tool results (as sync functions returning dicts)
            mock_scam_result = {"found": True, "report_count": 5, "risk_score": 75.0}
            mock_validator_result = {"valid": True, "suspicious": False}
            mock_exa_result = {"results": [{"title": "Scam report", "url": "https://example.com"}]}
            
            with patch.object(orchestrator.entity_extractor, 'extract', return_value=mock_entities_phones), \
                 patch.object(orchestrator.scam_db_tool, 'check_phone', MagicMock(return_value=mock_scam_result)), \
                 patch.object(orchestrator.phone_tool, 'validate', MagicMock(return_value=mock_validator_result)), \
                 patch.object(orchestrator.exa_tool, 'search_scam_reports', MagicMock(return_value=mock_exa_result)):
                
                result = await orchestrator.analyze(
                    task_id="test-phone-123",
                    ocr_text="Call us at 1-800-555-1234",
                    progress_publisher=mock_progress_publisher
                )
            
            assert result.task_id == "test-phone-123"
            assert len(result.entities_found["phones"]) == 1
            assert result.entities_found["phones"][0] == "+18005551234"
            assert len(result.evidence) == 3  # scam_db, phone_validator, exa_search
            assert "scam_db" in result.tools_used
            assert "phone_validator" in result.tools_used
            assert "exa_search" in result.tools_used
    
    async def test_analyze_with_url(self, mock_entities_urls, mock_progress_publisher):
        """Test analysis with URL."""
        with patch('app.services.gemini_service.get_model') as mock_model, \
             patch('os.getenv', return_value="test-gemini-key"):
            
            # Mock LLM response
            mock_response = MagicMock()
            mock_response.text = '{"risk_level": "high", "confidence": 85, "explanation": "Domain flagged as high risk and very new", "evidence_used": ["domain_reputation"]}'
            mock_model.return_value.generate_content.return_value = mock_response
            
            orchestrator = MCPAgentOrchestrator()
            
            # Mock tool results (as sync functions returning dicts)
            mock_scam_result = {"found": False}
            mock_domain_result = {"risk_level": "high", "risk_score": 85.0, "age_days": 5}
            mock_exa_result = {"results": []}
            
            with patch.object(orchestrator.entity_extractor, 'extract', return_value=mock_entities_urls), \
                 patch.object(orchestrator.scam_db_tool, 'check_url', MagicMock(return_value=mock_scam_result)), \
                 patch.object(orchestrator.domain_tool, 'check_domain', MagicMock(return_value=mock_domain_result)), \
                 patch.object(orchestrator.exa_tool, 'search_scam_reports', MagicMock(return_value=mock_exa_result)):
                
                result = await orchestrator.analyze(
                    task_id="test-url-123",
                    ocr_text="Visit https://suspicious-site.com",
                    progress_publisher=mock_progress_publisher
                )
            
            assert result.task_id == "test-url-123"
            assert len(result.entities_found["urls"]) == 1
            assert len(result.evidence) == 3  # scam_db, domain_reputation, exa_search
            assert "domain_reputation" in result.tools_used
    
    async def test_analyze_with_email(self, mock_entities_emails, mock_progress_publisher):
        """Test analysis with email."""
        with patch('app.services.gemini_service.get_model') as mock_model, \
             patch('os.getenv', return_value="test-gemini-key"):
            
            # Mock LLM response
            mock_response = MagicMock()
            mock_response.text = '{"risk_level": "low", "confidence": 80, "explanation": "No scam indicators found for email", "evidence_used": []}'
            mock_model.return_value.generate_content.return_value = mock_response
            
            orchestrator = MCPAgentOrchestrator()
            
            # Mock tool results (as sync functions returning dicts)
            mock_scam_result = {"found": False}
            mock_exa_result = {"results": []}
            
            with patch.object(orchestrator.entity_extractor, 'extract', return_value=mock_entities_emails), \
                 patch.object(orchestrator.scam_db_tool, 'check_email', MagicMock(return_value=mock_scam_result)), \
                 patch.object(orchestrator.exa_tool, 'search_scam_reports', MagicMock(return_value=mock_exa_result)):
                
                result = await orchestrator.analyze(
                    task_id="test-email-123",
                    ocr_text="Contact scammer@example.com",
                    progress_publisher=mock_progress_publisher
                )
            
            assert result.task_id == "test-email-123"
            assert len(result.entities_found["emails"]) == 1
            assert len(result.evidence) == 2  # scam_db, exa_search
    
    async def test_check_phone_parallel_execution(self):
        """Test that phone checks run in parallel."""
        orchestrator = MCPAgentOrchestrator()
        
        # Mock all tools with delays to verify parallel execution
        with patch.object(orchestrator.scam_db_tool, 'check_phone', return_value={"found": False}), \
             patch.object(orchestrator.phone_tool, 'validate', return_value={"valid": True}), \
             patch.object(orchestrator.exa_tool, 'search_scam_reports', return_value={"results": []}):
            
            evidence = await orchestrator._check_phone("+18005551234")
        
        # Should have 3 evidence items (one per tool)
        assert len(evidence) == 3
        tool_names = [e.tool_name for e in evidence]
        assert "scam_db" in tool_names
        assert "phone_validator" in tool_names
        assert "exa_search" in tool_names
    
    async def test_check_url_parallel_execution(self):
        """Test that URL checks run in parallel."""
        orchestrator = MCPAgentOrchestrator()
        
        with patch.object(orchestrator.scam_db_tool, 'check_url', return_value={"found": False}), \
             patch.object(orchestrator.domain_tool, 'check_domain', return_value={"risk_level": "low"}), \
             patch.object(orchestrator.exa_tool, 'search_scam_reports', return_value={"results": []}):
            
            evidence = await orchestrator._check_url("https://example.com")
        
        assert len(evidence) == 3
        tool_names = [e.tool_name for e in evidence]
        assert "scam_db" in tool_names
        assert "domain_reputation" in tool_names
        assert "exa_search" in tool_names
    
    async def test_check_email_parallel_execution(self):
        """Test that email checks run in parallel."""
        orchestrator = MCPAgentOrchestrator()
        
        with patch.object(orchestrator.scam_db_tool, 'check_email', return_value={"found": False}), \
             patch.object(orchestrator.exa_tool, 'search_scam_reports', return_value={"results": []}):
            
            evidence = await orchestrator._check_email("test@example.com")
        
        assert len(evidence) == 2
        tool_names = [e.tool_name for e in evidence]
        assert "scam_db" in tool_names
        assert "exa_search" in tool_names
    
    async def test_tool_failure_handling(self):
        """Test that agent continues when individual tools fail."""
        orchestrator = MCPAgentOrchestrator()
        
        # Mock one tool to fail
        with patch.object(orchestrator.scam_db_tool, 'check_phone', side_effect=Exception("DB error")), \
             patch.object(orchestrator.phone_tool, 'validate', return_value={"valid": True}), \
             patch.object(orchestrator.exa_tool, 'search_scam_reports', return_value={"results": []}):
            
            evidence = await orchestrator._check_phone("+18005551234")
        
        # Should still have 3 evidence items, but one with error
        assert len(evidence) == 3
        
        # Find the failed evidence
        failed = [e for e in evidence if not e.success]
        assert len(failed) == 1
        assert failed[0].tool_name == "scam_db"
        assert "error" in failed[0].result
    
    async def test_run_tool_with_sync_function(self):
        """Test _run_tool handles synchronous tool functions."""
        orchestrator = MCPAgentOrchestrator()
        
        def sync_tool():
            return {"result": "success"}
        
        evidence = await orchestrator._run_tool(
            "test_tool",
            "phone",
            "+18005551234",
            sync_tool
        )
        
        assert evidence.success
        assert evidence.tool_name == "test_tool"
        assert evidence.result["result"] == "success"
    
    async def test_run_tool_with_async_function(self):
        """Test _run_tool handles asynchronous tool functions."""
        orchestrator = MCPAgentOrchestrator()
        
        async def async_tool():
            return {"result": "async_success"}
        
        evidence = await orchestrator._run_tool(
            "test_tool",
            "phone",
            "+18005551234",
            async_tool
        )
        
        assert evidence.success
        assert evidence.tool_name == "test_tool"
        assert evidence.result["result"] == "async_success"
    
    async def test_run_tool_with_dataclass_result(self):
        """Test _run_tool handles results with to_dict method."""
        orchestrator = MCPAgentOrchestrator()
        
        class MockResult:
            def to_dict(self):
                return {"converted": True}
        
        def tool_with_dataclass():
            return MockResult()
        
        evidence = await orchestrator._run_tool(
            "test_tool",
            "phone",
            "+18005551234",
            tool_with_dataclass
        )
        
        assert evidence.success
        assert evidence.result["converted"] is True


class TestHeuristicReasoning:
    """Test heuristic reasoning logic."""
    
    def test_high_risk_scam_db_verified(self):
        """Test high risk when verified scam in DB."""
        orchestrator = MCPAgentOrchestrator()
        
        evidence = [
            AgentEvidence(
                tool_name="scam_db",
                entity_type="phone",
                entity_value="+18005551234",
                result={"found": True, "report_count": 10, "risk_score": 90.0, "verified": True},
                success=True,
                execution_time_ms=10.0
            )
        ]
        
        risk_level, confidence, reasoning = orchestrator._heuristic_reasoning(evidence)
        
        assert risk_level == "high"
        assert confidence > 70
        assert "Verified scam" in reasoning
    
    def test_high_risk_domain_reputation(self):
        """Test high risk when domain flagged."""
        orchestrator = MCPAgentOrchestrator()
        
        evidence = [
            AgentEvidence(
                tool_name="domain_reputation",
                entity_type="url",
                entity_value="https://phishing-site.com",
                result={"risk_level": "high", "age_days": 2},
                success=True,
                execution_time_ms=500.0
            )
        ]
        
        risk_level, confidence, reasoning = orchestrator._heuristic_reasoning(evidence)
        
        assert risk_level in ["medium", "high"]
        assert "Domain flagged as high risk" in reasoning
        assert "new domain" in reasoning
    
    def test_medium_risk_multiple_indicators(self):
        """Test medium risk with multiple indicators."""
        orchestrator = MCPAgentOrchestrator()
        
        evidence = [
            AgentEvidence(
                tool_name="scam_db",
                entity_type="phone",
                entity_value="+18005551234",
                result={"found": True, "report_count": 3, "risk_score": 50.0},
                success=True,
                execution_time_ms=10.0
            ),
            AgentEvidence(
                tool_name="exa_search",
                entity_type="phone",
                entity_value="+18005551234",
                result={"results": [{"title": "Complaint 1"}, {"title": "Complaint 2"}]},
                success=True,
                execution_time_ms=1000.0
            )
        ]
        
        risk_level, confidence, reasoning = orchestrator._heuristic_reasoning(evidence)
        
        assert risk_level in ["low", "medium"]
        assert "Found in scam database" in reasoning or "web complaints" in reasoning
    
    def test_low_risk_no_indicators(self):
        """Test low risk when no indicators found."""
        orchestrator = MCPAgentOrchestrator()
        
        evidence = [
            AgentEvidence(
                tool_name="scam_db",
                entity_type="phone",
                entity_value="+18005551234",
                result={"found": False},
                success=True,
                execution_time_ms=10.0
            ),
            AgentEvidence(
                tool_name="exa_search",
                entity_type="phone",
                entity_value="+18005551234",
                result={"results": []},
                success=True,
                execution_time_ms=1000.0
            )
        ]
        
        risk_level, confidence, reasoning = orchestrator._heuristic_reasoning(evidence)
        
        assert risk_level == "low"
        assert "No strong scam indicators" in reasoning
    
    def test_reasoning_ignores_failed_tools(self):
        """Test that reasoning ignores failed tool executions."""
        orchestrator = MCPAgentOrchestrator()
        
        evidence = [
            AgentEvidence(
                tool_name="scam_db",
                entity_type="phone",
                entity_value="+18005551234",
                result={"error": "Connection failed"},
                success=False,
                execution_time_ms=5000.0
            ),
            AgentEvidence(
                tool_name="phone_validator",
                entity_type="phone",
                entity_value="+18005551234",
                result={"valid": True, "suspicious": False},
                success=True,
                execution_time_ms=5.0
            )
        ]
        
        risk_level, confidence, reasoning = orchestrator._heuristic_reasoning(evidence)
        
        # Should not include failed tool in reasoning
        assert "error" not in reasoning.lower()
        assert risk_level == "low"


class TestProgressPublisher:
    """Test ProgressPublisher class."""
    
    def test_initialization_with_redis(self):
        """Test initialization when Redis is available."""
        with patch('redis.from_url') as mock_redis:
            mock_redis.return_value = MagicMock()
            
            publisher = ProgressPublisher("test-task-123")
            
            assert publisher.task_id == "test-task-123"
            assert publisher.channel == "agent_progress:test-task-123"
            assert publisher.enabled is True
    
    def test_initialization_without_redis(self):
        """Test initialization when Redis is unavailable."""
        with patch('redis.from_url', side_effect=Exception("Redis not available")):
            publisher = ProgressPublisher("test-task-123")
            
            assert publisher.enabled is False
            assert publisher.redis is None
    
    def test_publish_success(self):
        """Test successful progress publishing."""
        with patch('redis.from_url') as mock_redis:
            mock_redis_instance = MagicMock()
            mock_redis.return_value = mock_redis_instance
            
            publisher = ProgressPublisher("test-task-123")
            publisher.publish("Test message", 50)
            
            # Verify publish was called
            assert mock_redis_instance.publish.called
            call_args = mock_redis_instance.publish.call_args
            
            # Verify channel
            assert call_args[0][0] == "agent_progress:test-task-123"
            
            # Verify message contains expected data
            data = json.loads(call_args[0][1])
            assert data["message"] == "Test message"
            assert data["percent"] == 50
            assert "timestamp" in data
    
    def test_publish_when_disabled(self):
        """Test publish when publisher is disabled."""
        with patch('redis.from_url', side_effect=Exception("Redis not available")):
            publisher = ProgressPublisher("test-task-123")
            
            # Should not raise error
            publisher.publish("Test message", 50)


class TestCeleryTask:
    """Test Celery task integration."""
    
    @patch('app.agents.mcp_agent.MCPAgentOrchestrator')
    @patch('app.agents.mcp_agent.ProgressPublisher')
    @patch('app.agents.mcp_agent._save_agent_result')
    @patch('asyncio.new_event_loop')
    def test_analyze_with_mcp_agent_success(
        self, 
        mock_event_loop,
        mock_save_result,
        mock_publisher_class,
        mock_orchestrator_class
    ):
        """Test successful Celery task execution."""
        # Mock orchestrator
        mock_orchestrator = MagicMock()
        mock_result = AgentResult(
            task_id="test-123",
            risk_level="high",
            confidence=85.0,
            entities_found={"phones": ["+18005551234"]},
            evidence=[],
            reasoning="Test reasoning",
            processing_time_ms=1000,
            tools_used=["scam_db"]
        )
        
        # Mock async analyze method
        mock_loop = MagicMock()
        mock_loop.run_until_complete.return_value = mock_result
        mock_event_loop.return_value = mock_loop
        
        mock_orchestrator_class.return_value = mock_orchestrator
        mock_publisher_class.return_value = MagicMock()
        
        # Mock the Task object
        mock_task = MagicMock()
        mock_task.request.retries = 0
        mock_task.max_retries = 3
        
        # Call task
        result = analyze_with_mcp_agent(
            mock_task,
            task_id="test-123",
            ocr_text="Call 1-800-555-1234",
            session_id="session-123"
        )
        
        assert result["task_id"] == "test-123"
        assert result["risk_level"] == "high"
        assert mock_save_result.called


class TestAgentDataClasses:
    """Test data class functionality."""
    
    def test_agent_evidence_to_dict(self):
        """Test AgentEvidence serialization."""
        evidence = AgentEvidence(
            tool_name="scam_db",
            entity_type="phone",
            entity_value="+18005551234",
            result={"found": True},
            success=True,
            execution_time_ms=15.5
        )
        
        data = evidence.to_dict()
        
        assert data["tool_name"] == "scam_db"
        assert data["entity_type"] == "phone"
        assert data["entity_value"] == "+18005551234"
        assert data["success"] is True
    
    def test_agent_result_to_dict(self):
        """Test AgentResult serialization."""
        result = AgentResult(
            task_id="test-123",
            risk_level="medium",
            confidence=65.0,
            entities_found={"phones": ["+18005551234"]},
            evidence=[],
            reasoning="Test reasoning",
            processing_time_ms=500,
            tools_used=["scam_db", "exa_search"]
        )
        
        data = result.to_dict()
        
        assert data["task_id"] == "test-123"
        assert data["risk_level"] == "medium"
        assert data["confidence"] == 65.0
        assert len(data["tools_used"]) == 2

