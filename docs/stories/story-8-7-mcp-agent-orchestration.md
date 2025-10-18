# Story 8.7: MCP Agent Task Orchestration

**Story ID:** 8.7  
**Epic:** Epic 8 - MCP Agent with Multi-Tool Orchestration  
**Priority:** P0 (Core Agent Logic)  
**Effort:** 24 hours  
**Assignee:** Backend Developer  
**Status:** 📝 Ready for Development

---

## User Story

**As an** MCP agent worker,  
**I want** to orchestrate multiple tools in a logical sequence,  
**so that** I can build comprehensive evidence for scam detection.

---

## Description

This is the **heart of the MCP agent system** - the orchestration layer that coordinates all tools to investigate potential scams. The agent follows a methodical workflow:

1. **Extract entities** from OCR text
2. **Route to appropriate tools** based on entity types
3. **Execute tools in parallel** where possible
4. **Collect evidence** from all tool outputs
5. **Reason over evidence** to make final verdict
6. **Publish progress** updates throughout

**Agent Workflow:**
```
Screenshot → Extract Entities → For Each Entity:
  ├─ Phone → [Scam DB + Exa Search + Phone Validator] (parallel)
  ├─ URL → [Scam DB + Domain Reputation + Exa Search] (parallel)
  └─ Email → [Scam DB + Exa Search] (parallel)
→ Collect All Evidence → Agent Reasoning (LLM) → Final Verdict
```

---

## Acceptance Criteria

### Core Orchestration
- [ ] 1. `MCPAgent` class created in `app/agents/mcp_agent.py`
- [ ] 2. Celery task: `analyze_with_mcp_agent` for async execution
- [ ] 3. Task accepts: `task_id`, `image_data`, `ocr_text`, `session_id`, `user_metadata`
- [ ] 4. Returns structured result: `{"risk_level": str, "confidence": float, "evidence": list, "reasoning": str}`

### Entity-Based Tool Routing
- [ ] 5. For **phone numbers**: Run Scam DB + Exa Search + Phone Validator (parallel)
- [ ] 6. For **URLs**: Run Scam DB + Domain Reputation + Exa Search (parallel)
- [ ] 7. For **emails**: Run Scam DB + Exa Search (parallel)
- [ ] 8. For **payments**: Run Scam DB + Exa Search (parallel)
- [ ] 9. Skips tools if entity extraction finds nothing (fallback to fast path)

### Progress Publishing
- [ ] 10. Publish progress at each major step using Redis Pub/Sub
- [ ] 11. Progress messages: "Extracting entities...", "Checking scam database...", "Searching web...", etc.
- [ ] 12. Include percentage completion (0-100%)
- [ ] 13. Publish tool results as they complete

### Error Handling
- [ ] 14. Continue if individual tools fail (don't fail entire agent run)
- [ ] 15. Log tool failures but proceed with available evidence
- [ ] 16. Timeout: Max 60 seconds total (configurable)
- [ ] 17. Retry logic: 3 retries with exponential backoff for transient failures
- [ ] 18. Graceful degradation: Return results even if only partial tools succeeded

### Evidence Collection
- [ ] 19. Collect all tool outputs into structured evidence object
- [ ] 20. Evidence format: `[{"tool": "scam_db", "entity": "+18005551234", "result": {...}}, ...]`
- [ ] 21. Deduplicate evidence (same entity, same tool)
- [ ] 22. Rank evidence by reliability (DB > Domain Reputation > Exa > Phone Validator)

### Result Storage
- [ ] 23. Save result to `agent_scan_results` table (Supabase)
- [ ] 24. Link to session via `session_id`
- [ ] 25. Store all evidence and tool outputs (JSONB)
- [ ] 26. Track processing time (metrics)

### Testing
- [ ] 27. Unit tests with mocked tools
- [ ] 28. Integration tests with real tools (staging)
- [ ] 29. End-to-end test: Screenshot → Entities → Tools → Verdict
- [ ] 30. Performance test: Concurrent agent tasks

---

## Technical Implementation

**`app/agents/mcp_agent.py`:**

```python
"""MCP Agent - Multi-Tool Orchestration for Scam Detection."""

import os
import asyncio
import logging
from typing import Dict, List, Any, Optional
from datetime import datetime
import json
from dataclasses import dataclass, asdict

from celery import Task
from app.agents.worker import celery_app
from app.services.entity_extractor import get_entity_extractor
from app.agents.tools.scam_database import get_scam_database_tool
from app.agents.tools.exa_search import get_exa_search_tool
from app.agents.tools.domain_reputation import get_domain_reputation_tool
from app.agents.tools.phone_validator import get_phone_validator_tool
from app.db.client import get_supabase_client

logger = logging.getLogger(__name__)


@dataclass
class AgentEvidence:
    """Evidence collected by agent from tools."""
    tool_name: str
    entity_type: str
    entity_value: str
    result: Dict[str, Any]
    success: bool
    execution_time_ms: float


@dataclass
class AgentResult:
    """Final agent analysis result."""
    task_id: str
    risk_level: str  # low, medium, high
    confidence: float  # 0-100
    entities_found: Dict[str, List[str]]
    evidence: List[Dict[str, Any]]
    reasoning: str
    processing_time_ms: int
    tools_used: List[str]
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return asdict(self)


class MCPAgentOrchestrator:
    """
    MCP Agent Orchestrator.
    
    Coordinates multiple tools to investigate potential scams.
    """
    
    def __init__(self):
        """Initialize agent orchestrator."""
        self.entity_extractor = get_entity_extractor()
        self.scam_db_tool = get_scam_database_tool()
        self.exa_tool = get_exa_search_tool()
        self.domain_tool = get_domain_reputation_tool()
        self.phone_tool = get_phone_validator_tool()
        
        logger.info("MCPAgentOrchestrator initialized")
    
    async def analyze(
        self,
        task_id: str,
        ocr_text: str,
        progress_publisher: 'ProgressPublisher'
    ) -> AgentResult:
        """
        Run full agent analysis workflow.
        
        Args:
            task_id: Unique task identifier
            ocr_text: Text extracted from screenshot
            progress_publisher: Publisher for progress updates
        
        Returns:
            AgentResult with verdict and evidence
        """
        start_time = datetime.now()
        
        try:
            # Step 1: Extract entities
            progress_publisher.publish("Extracting entities from text...", 10)
            entities = self.entity_extractor.extract(ocr_text)
            
            if not entities.has_entities():
                # No entities found - return early (should use fast path instead)
                logger.info(f"Task {task_id}: No entities found, skipping agent analysis")
                return self._create_minimal_result(task_id, start_time)
            
            progress_publisher.publish(
                f"Found {entities.entity_count()} entities: "
                f"{len(entities.phones)} phones, {len(entities.urls)} URLs, "
                f"{len(entities.emails)} emails",
                20
            )
            
            # Step 2: Run tools for each entity
            progress_publisher.publish("Investigating entities with tools...", 30)
            evidence = await self._run_tools_for_entities(entities, progress_publisher)
            
            # Step 3: Collect tool names
            tools_used = list(set(e.tool_name for e in evidence))
            
            progress_publisher.publish(
                f"Collected {len(evidence)} pieces of evidence from {len(tools_used)} tools",
                80
            )
            
            # Step 4: Agent reasoning (LLM) - handled in Story 8.8
            # For now, use heuristic scoring
            progress_publisher.publish("Agent analyzing evidence...", 90)
            risk_level, confidence, reasoning = self._heuristic_reasoning(evidence)
            
            # Calculate processing time
            processing_time = int((datetime.now() - start_time).total_seconds() * 1000)
            
            progress_publisher.publish("Analysis complete!", 100)
            
            return AgentResult(
                task_id=task_id,
                risk_level=risk_level,
                confidence=confidence,
                entities_found={
                    "phones": [p["value"] for p in entities.phones],
                    "urls": [u["value"] for u in entities.urls],
                    "emails": [e["value"] for e in entities.emails],
                    "payments": [p["value"] for p in entities.payments],
                    "amounts": [a["amount"] for a in entities.amounts]
                },
                evidence=[asdict(e) for e in evidence],
                reasoning=reasoning,
                processing_time_ms=processing_time,
                tools_used=tools_used
            )
        
        except Exception as e:
            logger.error(f"Agent analysis failed for task {task_id}: {e}", exc_info=True)
            raise
    
    async def _run_tools_for_entities(
        self,
        entities,
        progress_publisher: 'ProgressPublisher'
    ) -> List[AgentEvidence]:
        """
        Run appropriate tools for each entity type.
        
        Args:
            entities: ExtractedEntities object
            progress_publisher: Progress publisher
        
        Returns:
            List of AgentEvidence objects
        """
        evidence = []
        total_entities = entities.entity_count()
        processed = 0
        
        # Process phones
        for phone_data in entities.phones:
            phone = phone_data["value"]
            progress_publisher.publish(f"Checking phone: {phone}", 30 + (processed / total_entities * 40))
            
            phone_evidence = await self._check_phone(phone)
            evidence.extend(phone_evidence)
            
            processed += 1
        
        # Process URLs
        for url_data in entities.urls:
            url = url_data["value"]
            progress_publisher.publish(f"Checking URL: {url}", 30 + (processed / total_entities * 40))
            
            url_evidence = await self._check_url(url)
            evidence.extend(url_evidence)
            
            processed += 1
        
        # Process emails
        for email_data in entities.emails:
            email = email_data["value"]
            progress_publisher.publish(f"Checking email: {email}", 30 + (processed / total_entities * 40))
            
            email_evidence = await self._check_email(email)
            evidence.extend(email_evidence)
            
            processed += 1
        
        return evidence
    
    async def _check_phone(self, phone: str) -> List[AgentEvidence]:
        """Run tools for phone number."""
        evidence = []
        
        # Run tools in parallel
        tasks = [
            self._run_tool("scam_db", "phone", phone, lambda: self.scam_db_tool.check_phone(phone)),
            self._run_tool("phone_validator", "phone", phone, lambda: self.phone_tool.validate(phone)),
            self._run_tool("exa_search", "phone", phone, lambda: self.exa_tool.search_scam_reports(phone, "phone"))
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        for result in results:
            if isinstance(result, AgentEvidence):
                evidence.append(result)
        
        return evidence
    
    async def _check_url(self, url: str) -> List[AgentEvidence]:
        """Run tools for URL."""
        evidence = []
        
        tasks = [
            self._run_tool("scam_db", "url", url, lambda: self.scam_db_tool.check_url(url)),
            self._run_tool("domain_reputation", "url", url, lambda: self.domain_tool.check_domain(url)),
            self._run_tool("exa_search", "url", url, lambda: self.exa_tool.search_scam_reports(url, "url"))
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        for result in results:
            if isinstance(result, AgentEvidence):
                evidence.append(result)
        
        return evidence
    
    async def _check_email(self, email: str) -> List[AgentEvidence]:
        """Run tools for email."""
        evidence = []
        
        tasks = [
            self._run_tool("scam_db", "email", email, lambda: self.scam_db_tool.check_email(email)),
            self._run_tool("exa_search", "email", email, lambda: self.exa_tool.search_scam_reports(email, "email"))
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        for result in results:
            if isinstance(result, AgentEvidence):
                evidence.append(result)
        
        return evidence
    
    async def _run_tool(
        self,
        tool_name: str,
        entity_type: str,
        entity_value: str,
        tool_func
    ) -> AgentEvidence:
        """
        Run a single tool and return evidence.
        
        Args:
            tool_name: Name of the tool
            entity_type: Type of entity
            entity_value: Entity value
            tool_func: Async callable that returns tool result
        
        Returns:
            AgentEvidence object
        """
        start_time = datetime.now()
        
        try:
            # Run tool (handle both sync and async)
            if asyncio.iscoroutinefunction(tool_func):
                result = await tool_func()
            else:
                result = tool_func()
            
            # Convert result to dict if needed
            if hasattr(result, 'to_dict'):
                result = result.to_dict()
            
            execution_time = (datetime.now() - start_time).total_seconds() * 1000
            
            return AgentEvidence(
                tool_name=tool_name,
                entity_type=entity_type,
                entity_value=entity_value,
                result=result,
                success=True,
                execution_time_ms=execution_time
            )
        
        except Exception as e:
            logger.error(f"Tool {tool_name} failed for {entity_type}/{entity_value}: {e}")
            execution_time = (datetime.now() - start_time).total_seconds() * 1000
            
            return AgentEvidence(
                tool_name=tool_name,
                entity_type=entity_type,
                entity_value=entity_value,
                result={"error": str(e)},
                success=False,
                execution_time_ms=execution_time
            )
    
    def _heuristic_reasoning(
        self,
        evidence: List[AgentEvidence]
    ) -> tuple[str, float, str]:
        """
        Heuristic-based reasoning (temporary until LLM reasoning in Story 8.8).
        
        Returns:
            Tuple of (risk_level, confidence, reasoning)
        """
        score = 0.0
        reasons = []
        
        for e in evidence:
            if not e.success:
                continue
            
            result = e.result
            
            # Scam DB findings (highest weight)
            if e.tool_name == "scam_db" and result.get("found"):
                report_count = result.get("report_count", 0)
                score += min(report_count * 5, 40)  # Max 40 points
                reasons.append(f"Found in scam database ({report_count} reports)")
            
            # Exa search results
            if e.tool_name == "exa_search" and result.get("results"):
                result_count = len(result["results"])
                score += min(result_count * 2, 20)  # Max 20 points
                reasons.append(f"Found {result_count} web complaints")
            
            # Domain reputation
            if e.tool_name == "domain_reputation":
                risk_level = result.get("risk_level")
                if risk_level == "high":
                    score += 30
                    reasons.append("Domain flagged as high risk")
                elif risk_level == "medium":
                    score += 15
                    reasons.append("Domain flagged as medium risk")
            
            # Phone validator suspicious patterns
            if e.tool_name == "phone_validator" and result.get("suspicious"):
                score += 25
                reasons.append(f"Suspicious phone pattern: {result.get('suspicious_reason')}")
        
        # Determine risk level
        if score >= 70:
            risk_level = "high"
            confidence = min(score, 100)
        elif score >= 40:
            risk_level = "medium"
            confidence = min(score, 100)
        else:
            risk_level = "low"
            confidence = max(100 - score, 0)
        
        # Build reasoning text
        if reasons:
            reasoning = "Evidence collected: " + "; ".join(reasons)
        else:
            reasoning = "No strong scam indicators found in any tools"
        
        return risk_level, confidence, reasoning
    
    def _create_minimal_result(self, task_id: str, start_time: datetime) -> AgentResult:
        """Create minimal result when no entities found."""
        processing_time = int((datetime.now() - start_time).total_seconds() * 1000)
        
        return AgentResult(
            task_id=task_id,
            risk_level="low",
            confidence=50.0,
            entities_found={},
            evidence=[],
            reasoning="No suspicious entities found in text",
            processing_time_ms=processing_time,
            tools_used=[]
        )


class ProgressPublisher:
    """Publishes progress updates to Redis Pub/Sub."""
    
    def __init__(self, task_id: str):
        """Initialize progress publisher."""
        self.task_id = task_id
        
        import redis
        self.redis = redis.from_url(
            os.getenv('REDIS_URL', 'redis://localhost:6379/0')
        )
        
        self.channel = f"agent_progress:{task_id}"
    
    def publish(self, message: str, percent: int = 0):
        """Publish progress update."""
        try:
            data = json.dumps({
                "message": message,
                "percent": percent,
                "timestamp": datetime.now().isoformat()
            })
            
            self.redis.publish(self.channel, data)
            logger.debug(f"Progress: {message} ({percent}%)")
        
        except Exception as e:
            logger.error(f"Failed to publish progress: {e}")


@celery_app.task(bind=True, max_retries=3, time_limit=60)
def analyze_with_mcp_agent(
    self: Task,
    task_id: str,
    ocr_text: str,
    session_id: str,
    user_metadata: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """
    Celery task for MCP agent analysis.
    
    Args:
        task_id: Unique task identifier
        ocr_text: Text extracted from screenshot
        session_id: User session ID
        user_metadata: Optional metadata (user country, etc.)
    
    Returns:
        AgentResult dictionary
    """
    logger.info(f"Starting MCP agent analysis: task_id={task_id}, session_id={session_id}")
    
    try:
        # Initialize components
        orchestrator = MCPAgentOrchestrator()
        progress = ProgressPublisher(task_id)
        
        # Run analysis (async)
        loop = asyncio.get_event_loop()
        result = loop.run_until_complete(
            orchestrator.analyze(task_id, ocr_text, progress)
        )
        
        # Save to database
        _save_agent_result(result, session_id)
        
        logger.info(f"Agent analysis complete: task_id={task_id}, risk={result.risk_level}")
        
        return result.to_dict()
    
    except Exception as exc:
        logger.error(f"Agent analysis failed: {exc}", exc_info=True)
        
        # Retry with exponential backoff
        raise self.retry(exc=exc, countdown=2 ** self.request.retries)


def _save_agent_result(result: AgentResult, session_id: str):
    """Save agent result to database."""
    try:
        supabase = get_supabase_client()
        
        supabase.table('agent_scan_results').insert({
            'task_id': result.task_id,
            'session_id': session_id,
            'entities_found': result.entities_found,
            'tool_results': result.evidence,
            'agent_reasoning': result.reasoning,
            'risk_level': result.risk_level,
            'confidence': result.confidence,
            'evidence_summary': {
                "tools_used": result.tools_used,
                "evidence_count": len(result.evidence)
            },
            'processing_time_ms': result.processing_time_ms
        }).execute()
        
        logger.info(f"Agent result saved to database: {result.task_id}")
    
    except Exception as e:
        logger.error(f"Failed to save agent result: {e}", exc_info=True)
```

---

## Testing Strategy

```python
"""Unit tests for MCP Agent Orchestration."""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from app.agents.mcp_agent import MCPAgentOrchestrator, AgentEvidence


@pytest.fixture
def orchestrator():
    """Fixture providing MCPAgentOrchestrator."""
    return MCPAgentOrchestrator()


@pytest.mark.asyncio
class TestAgentOrchestration:
    """Test agent orchestration logic."""
    
    async def test_phone_investigation(self, orchestrator):
        """Test that phone numbers trigger correct tools."""
        # Mock entity extractor
        mock_entities = MagicMock()
        mock_entities.has_entities.return_value = True
        mock_entities.entity_count.return_value = 1
        mock_entities.phones = [{"value": "+18005551234"}]
        mock_entities.urls = []
        mock_entities.emails = []
        mock_entities.payments = []
        mock_entities.amounts = []
        
        with patch.object(orchestrator.entity_extractor, 'extract', return_value=mock_entities):
            # Mock progress publisher
            progress = MagicMock()
            
            # Run analysis
            result = await orchestrator.analyze("test-123", "Call 800-555-1234", progress)
        
        assert result.task_id == "test-123"
        assert len(result.entities_found["phones"]) == 1
    
    async def test_evidence_collection(self, orchestrator):
        """Test that evidence is collected from all tools."""
        # This test would mock all tools and verify evidence collection
        pass
```

---

## Success Criteria

- [ ] All 30 acceptance criteria met
- [ ] Agent completes analysis in < 30 seconds
- [ ] Progress updates published at each step
- [ ] Evidence collected from all tools
- [ ] All unit tests passing
- [ ] End-to-end integration test passing

---

**Estimated Effort:** 24 hours  
**Sprint:** Week 9, Days 3-5

