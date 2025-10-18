"""MCP Agent - Multi-Tool Orchestration for Scam Detection.

This module implements the core MCP agent orchestration logic that coordinates
multiple tools to investigate potential scams. The agent follows a methodical
workflow to extract entities, route to appropriate tools, collect evidence,
and reason over the results.

Story: 8.7 - MCP Agent Task Orchestration
"""

import os
import asyncio
import logging
from typing import Dict, List, Any, Optional
from datetime import datetime
import json
from dataclasses import dataclass, asdict, field

from celery import Task
from app.agents.worker import celery_app
from app.services.entity_extractor import get_entity_extractor, ExtractedEntities
from app.agents.tools.scam_database import get_scam_database_tool
from app.agents.tools.exa_search import get_exa_search_tool
from app.agents.tools.domain_reputation import get_domain_reputation_tool
from app.agents.tools.phone_validator import get_phone_validator_tool
from app.agents.tools.company_verification import get_company_verification_tool
from app.agents.reasoning import get_agent_reasoner, ReasoningResult
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
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        import copy
        import asyncio
        
        # Handle case where result itself is a coroutine
        if asyncio.iscoroutine(self.result) or asyncio.isfuture(self.result):
            safe_result = {"error": "Result was not awaited (coroutine object)"}
        elif not isinstance(self.result, dict):
            # If result is not a dict, convert to string
            safe_result = {"value": str(self.result)}
        else:
            # Create a safe copy of the result, filtering out non-serializable objects
            safe_result = {}
            for key, value in self.result.items():
                if asyncio.iscoroutine(value) or asyncio.isfuture(value):
                    # Skip coroutines and futures
                    continue
                elif callable(value):
                    # Skip callable objects
                    continue
                else:
                    try:
                        # Try to deepcopy to ensure serializability
                        safe_result[key] = copy.deepcopy(value)
                    except (TypeError, AttributeError):
                        # If deepcopy fails, convert to string representation
                        safe_result[key] = str(value)
        
        return {
            'tool_name': self.tool_name,
            'entity_type': self.entity_type,
            'entity_value': self.entity_value,
            'result': safe_result,
            'success': self.success,
            'execution_time_ms': self.execution_time_ms
        }


@dataclass
class AgentResult:
    """Final agent analysis result."""
    task_id: str
    risk_level: str  # low, medium, high
    confidence: float  # 0-100
    entities_found: Dict[str, List[Any]]
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
    
    Coordinates multiple tools to investigate potential scams. The agent:
    1. Extracts entities from OCR text
    2. Routes entities to appropriate tools
    3. Executes tools in parallel where possible
    4. Collects evidence from all tool outputs
    5. Reasons over evidence to make final verdict
    6. Publishes progress updates throughout
    
    Example workflow:
        Screenshot → Extract Entities → For Each Entity:
          ├─ Phone → [Scam DB + Exa Search + Phone Validator] (parallel)
          ├─ URL → [Scam DB + Domain Reputation + Exa Search] (parallel)
          └─ Email → [Scam DB + Exa Search] (parallel)
        → Collect All Evidence → Agent Reasoning → Final Verdict
    """
    
    def __init__(self):
        """Initialize agent orchestrator."""
        self.entity_extractor = get_entity_extractor()
        self.scam_db_tool = get_scam_database_tool()
        self.exa_tool = get_exa_search_tool()
        self.domain_tool = get_domain_reputation_tool()
        self.phone_tool = get_phone_validator_tool()
        self.company_tool = get_company_verification_tool()
        self.reasoner = get_agent_reasoner()
        
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
            progress_publisher.publish(
                "Extracting entities from text...", 
                10, 
                step="entity_extraction"
            )
            entities = self.entity_extractor.extract(ocr_text)
            
            if not entities.has_entities():
                # No entities found - return early (should use fast path instead)
                logger.info(f"Task {task_id}: No entities found, skipping agent analysis")
                progress_publisher.publish(
                    "No suspicious entities found",
                    100,
                    step="completed"
                )
                return self._create_minimal_result(task_id, start_time)
            
            progress_publisher.publish(
                f"Found {entities.entity_count()} entities: "
                f"{len(entities.phones)} phones, {len(entities.urls)} URLs, "
                f"{len(entities.emails)} emails",
                20,
                step="entity_extraction"
            )
            
            # Step 2: Run tools for each entity
            progress_publisher.publish(
                "Investigating entities with tools...", 
                30, 
                step="tool_execution"
            )
            evidence = await self._run_tools_for_entities(entities, progress_publisher)
            
            # Step 3: Collect tool names
            tools_used = list(set(e.tool_name for e in evidence))
            
            progress_publisher.publish(
                f"Collected {len(evidence)} pieces of evidence from {len(tools_used)} tools",
                80,
                step="tool_execution"
            )
            
            # Step 4: Agent reasoning with LLM (Story 8.8)
            progress_publisher.publish(
                "Agent analyzing evidence...", 
                90, 
                step="reasoning"
            )
            reasoning_result = await self._agent_reasoning(
                evidence, 
                ocr_text, 
                entities
            )
            
            # Calculate processing time
            processing_time = int((datetime.now() - start_time).total_seconds() * 1000)
            
            progress_publisher.publish(
                "Analysis complete!", 
                100, 
                step="completed"
            )
            
            return AgentResult(
                task_id=task_id,
                risk_level=reasoning_result.risk_level,
                confidence=reasoning_result.confidence,
                entities_found={
                    "phones": [p["value"] for p in entities.phones],
                    "urls": [u["value"] for u in entities.urls],
                    "emails": [e["value"] for e in entities.emails],
                    "payments": [p["value"] for p in entities.payments],
                    "amounts": [a["amount"] for a in entities.amounts]
                },
                evidence=[e.to_dict() for e in evidence],
                reasoning=reasoning_result.explanation,
                processing_time_ms=processing_time,
                tools_used=tools_used
            )
        
        except Exception as e:
            logger.error(f"Agent analysis failed for task {task_id}: {e}", exc_info=True)
            progress_publisher.publish(
                f"Analysis failed: {str(e)}",
                0,
                step="failed",
                error=True
            )
            raise
    
    async def _run_tools_for_entities(
        self,
        entities: ExtractedEntities,
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
            progress_percent = 30 + int((processed / total_entities) * 40)
            
            progress_publisher.publish(
                f"Checking phone: {phone}", 
                progress_percent,
                step="tool_execution",
                tool="phone_check"
            )
            
            phone_evidence = await self._check_phone(phone, progress_publisher, progress_percent)
            evidence.extend(phone_evidence)
            
            processed += 1
        
        # Process URLs
        for url_data in entities.urls:
            url = url_data["value"]
            progress_percent = 30 + int((processed / total_entities) * 40)
            
            progress_publisher.publish(
                f"Checking URL: {url}", 
                progress_percent,
                step="tool_execution",
                tool="url_check"
            )
            
            url_evidence = await self._check_url(url, progress_publisher, progress_percent)
            evidence.extend(url_evidence)
            
            processed += 1
        
        # Process emails
        for email_data in entities.emails:
            email = email_data["value"]
            progress_percent = 30 + int((processed / total_entities) * 40)
            
            progress_publisher.publish(
                f"Checking email: {email}", 
                progress_percent,
                step="tool_execution",
                tool="email_check"
            )
            
            email_evidence = await self._check_email(email, progress_publisher, progress_percent)
            evidence.extend(email_evidence)
            
            processed += 1
        
        # Process companies
        for company_data in entities.companies:
            company = company_data["value"]
            normalized = company_data.get("normalized", company)
            category = company_data.get("category", "registered")
            progress_percent = 30 + int((processed / total_entities) * 40)
            
            progress_publisher.publish(
                f"Checking company: {normalized}", 
                progress_percent,
                step="tool_execution",
                tool="company_check"
            )
            
            # Determine country code (default to US, could be enhanced with user location)
            country = "US"  # TODO: Get from user profile or detect from text
            
            company_evidence = await self._check_company(
                company, normalized, country, category, progress_publisher, progress_percent
            )
            evidence.extend(company_evidence)
            
            processed += 1
        
        return evidence
    
    async def _check_phone(
        self, 
        phone: str, 
        progress_publisher: 'ProgressPublisher',
        base_percent: int
    ) -> List[AgentEvidence]:
        """Run tools for phone number."""
        evidence = []
        
        # Run tools in parallel
        tasks = [
            self._run_tool(
                "scam_db", 
                "phone", 
                phone, 
                lambda: self.scam_db_tool.check_phone(phone),
                progress_publisher,
                base_percent
            ),
            self._run_tool(
                "phone_validator", 
                "phone", 
                phone, 
                lambda: self.phone_tool.validate(phone),
                progress_publisher,
                base_percent
            ),
            self._run_tool(
                "exa_search", 
                "phone", 
                phone, 
                lambda: self.exa_tool.search_scam_reports(phone, "phone"),
                progress_publisher,
                base_percent
            )
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        for result in results:
            if isinstance(result, AgentEvidence):
                evidence.append(result)
            elif isinstance(result, Exception):
                logger.error(f"Tool execution failed for phone {phone}: {result}")
        
        return evidence
    
    async def _check_url(
        self, 
        url: str, 
        progress_publisher: 'ProgressPublisher',
        base_percent: int
    ) -> List[AgentEvidence]:
        """Run tools for URL."""
        evidence = []
        
        tasks = [
            self._run_tool(
                "scam_db", 
                "url", 
                url, 
                lambda: self.scam_db_tool.check_url(url),
                progress_publisher,
                base_percent
            ),
            self._run_tool(
                "domain_reputation", 
                "url", 
                url, 
                lambda: self.domain_tool.check_domain(url),
                progress_publisher,
                base_percent
            ),
            self._run_tool(
                "exa_search", 
                "url", 
                url, 
                lambda: self.exa_tool.search_scam_reports(url, "url"),
                progress_publisher,
                base_percent
            )
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        for result in results:
            if isinstance(result, AgentEvidence):
                evidence.append(result)
            elif isinstance(result, Exception):
                logger.error(f"Tool execution failed for URL {url}: {result}")
        
        return evidence
    
    async def _check_email(
        self, 
        email: str, 
        progress_publisher: 'ProgressPublisher',
        base_percent: int
    ) -> List[AgentEvidence]:
        """Run tools for email."""
        evidence = []
        
        tasks = [
            self._run_tool(
                "scam_db", 
                "email", 
                email, 
                lambda: self.scam_db_tool.check_email(email),
                progress_publisher,
                base_percent
            ),
            self._run_tool(
                "exa_search", 
                "email", 
                email, 
                lambda: self.exa_tool.search_scam_reports(email, "email"),
                progress_publisher,
                base_percent
            )
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        for result in results:
            if isinstance(result, AgentEvidence):
                evidence.append(result)
            elif isinstance(result, Exception):
                logger.error(f"Tool execution failed for email {email}: {result}")
        
        return evidence
    
    async def _check_company(
        self, 
        company: str,
        normalized: str,
        country: str,
        category: str,
        progress_publisher: 'ProgressPublisher',
        base_percent: int
    ) -> List[AgentEvidence]:
        """
        Run tools for company name.
        
        Args:
            company: Full company name with suffix
            normalized: Normalized company name
            country: Country code (SG, US, GB, etc.)
            category: Company category (registered or department)
            progress_publisher: Progress publisher
            base_percent: Base percentage for progress
        
        Returns:
            List of AgentEvidence from tools
        """
        evidence = []
        
        # Run tools in parallel
        tasks = [
            self._run_tool(
                "company_verification",
                "company",
                company,
                lambda: self.company_tool.verify_company(normalized, country),
                progress_publisher,
                base_percent
            ),
            self._run_tool(
                "scam_db",
                "company",
                company,
                lambda: self.scam_db_tool.check_entity(company, "company"),
                progress_publisher,
                base_percent
            ),
            # Optional: Search for company scam reports
            self._run_tool(
                "exa_search",
                "company",
                company,
                lambda: self.exa_tool.search_scam_reports(f"{company} scam fake", "company"),
                progress_publisher,
                base_percent
            )
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        for result in results:
            if isinstance(result, AgentEvidence):
                evidence.append(result)
            elif isinstance(result, Exception):
                logger.error(f"Tool execution failed for company {company}: {result}")
        
        return evidence
    
    async def _run_tool(
        self,
        tool_name: str,
        entity_type: str,
        entity_value: str,
        tool_func,
        progress_publisher: 'ProgressPublisher',
        base_percent: int
    ) -> AgentEvidence:
        """
        Run a single tool and return evidence.
        
        Args:
            tool_name: Name of the tool
            entity_type: Type of entity
            entity_value: Entity value
            tool_func: Callable (sync or async) that returns tool result
            progress_publisher: Progress publisher
            base_percent: Base percentage for progress
        
        Returns:
            AgentEvidence object
        """
        start_time = datetime.now()
        
        # Map tool names to step names
        step_map = {
            "scam_db": "scam_db",
            "exa_search": "exa_search",
            "domain_reputation": "domain_reputation",
            "phone_validator": "phone_validator"
        }
        step = step_map.get(tool_name, "tool_execution")
        
        try:
            # Publish start of tool execution
            progress_publisher.publish(
                f"Running {tool_name} for {entity_type}...",
                base_percent,
                step=step,
                tool=tool_name
            )
            
            # Run tool (handle both sync and async)
            # First call the function to get the result or coroutine
            result = tool_func()
            
            # If the result is a coroutine, await it
            if asyncio.iscoroutine(result):
                result = await result
            # If tool_func was a sync callable that returned a value, we already have it
            # No need to run in executor since tool_func() already executed
            
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
    
    async def _agent_reasoning(
        self,
        evidence: List[AgentEvidence],
        ocr_text: str,
        entities: ExtractedEntities
    ) -> ReasoningResult:
        """
        Agent reasoning using LLM (Story 8.8).
        
        Analyzes evidence from all tools using an LLM to produce intelligent
        verdicts with natural language explanations. Falls back to heuristic
        reasoning if LLM fails or times out.
        
        Args:
            evidence: List of AgentEvidence from tool executions
            ocr_text: Original OCR text
            entities: Extracted entities
        
        Returns:
            ReasoningResult with risk level, confidence, and explanation
        """
        # Convert evidence to dict format for reasoner
        evidence_dicts = [e.to_dict() for e in evidence]
        
        # Format entities for reasoner
        entities_dict = {
            "phones": [p["value"] for p in entities.phones],
            "urls": [u["value"] for u in entities.urls],
            "emails": [e["value"] for e in entities.emails],
            "payments": [p["value"] for p in entities.payments],
            "amounts": [str(a["amount"]) for a in entities.amounts]
        }
        
        # Call reasoner
        reasoning_result = await self.reasoner.reason(
            evidence=evidence_dicts,
            ocr_text=ocr_text,
            entities_found=entities_dict
        )
        
        return reasoning_result
    
    def _create_minimal_result(self, task_id: str, start_time: datetime) -> AgentResult:
        """Create minimal result when no entities found."""
        processing_time = int((datetime.now() - start_time).total_seconds() * 1000)
        
        return AgentResult(
            task_id=task_id,
            risk_level="low",
            confidence=50.0,
            entities_found={
                "phones": [],
                "urls": [],
                "emails": [],
                "payments": [],
                "amounts": []
            },
            evidence=[],
            reasoning="No suspicious entities found in text",
            processing_time_ms=processing_time,
            tools_used=[]
        )


class ProgressPublisher:
    """
    Publishes progress updates to Redis Pub/Sub.
    
    Allows real-time tracking of agent progress through WebSocket
    subscriptions (Story 8.9).
    
    Message format:
        {
            "step": "entity_extraction" | "scam_db" | "exa_search" | "domain_reputation" | 
                    "phone_validator" | "reasoning" | "completed" | "failed",
            "tool": Optional tool name for UI mapping,
            "message": Human-readable progress message,
            "percent": Completion percentage (0-100),
            "timestamp": ISO timestamp
        }
    """
    
    def __init__(self, task_id: str):
        """
        Initialize progress publisher.
        
        Args:
            task_id: Unique task identifier
        """
        self.task_id = task_id
        self.channel = f"agent_progress:{task_id}"
        
        try:
            import redis
            redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
            self.redis = redis.from_url(redis_url, decode_responses=True)
            self.enabled = True
            logger.debug(f"Progress publisher initialized for task {task_id}")
        except Exception as e:
            logger.warning(f"Failed to initialize progress publisher: {e}")
            self.redis = None
            self.enabled = False
    
    def publish(
        self, 
        message: str, 
        percent: int = 0, 
        step: str = "processing",
        tool: Optional[str] = None,
        error: bool = False
    ):
        """
        Publish progress update.
        
        Args:
            message: Progress message
            percent: Completion percentage (0-100)
            step: Step name (entity_extraction, scam_db, exa_search, etc.)
            tool: Optional tool name for UI mapping
            error: Whether this is an error message
        """
        if not self.enabled or not self.redis:
            logger.debug(f"Progress (not published): {message} ({percent}%)")
            return
        
        try:
            data = json.dumps({
                "step": step,
                "tool": tool,
                "message": message,
                "percent": percent,
                "timestamp": datetime.now().isoformat(),
                "error": error
            })
            
            self.redis.publish(self.channel, data)
            logger.debug(f"Progress published: step={step} tool={tool} message={message} ({percent}%)")
        
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
    
    This task orchestrates the entire agent workflow:
    1. Extract entities from OCR text
    2. Run appropriate tools for each entity
    3. Collect and analyze evidence
    4. Generate risk assessment
    5. Save results to database
    6. Publish progress updates
    
    Args:
        task_id: Unique task identifier
        ocr_text: Text extracted from screenshot
        session_id: User session ID
        user_metadata: Optional metadata (user country, etc.)
    
    Returns:
        AgentResult dictionary
        
    Raises:
        Exception: On unrecoverable errors (will retry up to 3 times)
    """
    logger.info(f"Starting MCP agent analysis: task_id={task_id}, session_id={session_id}")
    
    try:
        # Initialize components
        orchestrator = MCPAgentOrchestrator()
        progress = ProgressPublisher(task_id)
        
        # Run analysis (async)
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            result = loop.run_until_complete(
                orchestrator.analyze(task_id, ocr_text, progress)
            )
        finally:
            loop.close()
        
        # Save to database
        _save_agent_result(result, session_id)
        
        logger.info(
            f"Agent analysis complete: task_id={task_id}, "
            f"risk={result.risk_level}, confidence={result.confidence:.1f}"
        )
        
        return result.to_dict()
    
    except Exception as exc:
        logger.error(f"Agent analysis failed: {exc}", exc_info=True)
        
        # Retry with exponential backoff
        if self.request.retries < self.max_retries:
            countdown = 2 ** self.request.retries
            logger.info(f"Retrying in {countdown} seconds (attempt {self.request.retries + 1}/{self.max_retries})")
            raise self.retry(exc=exc, countdown=countdown)
        else:
            # Max retries reached - return error result
            logger.error(f"Max retries reached for task {task_id}, giving up")
            raise


def _save_agent_result(result: AgentResult, session_id: str):
    """
    Save agent result to database.
    
    Args:
        result: AgentResult to save
        session_id: Session ID to link to
    """
    try:
        supabase = get_supabase_client()
        
        # Prepare evidence summary
        evidence_summary = {
            "tools_used": result.tools_used,
            "evidence_count": len(result.evidence),
            "entity_counts": {
                "phones": len(result.entities_found.get("phones", [])),
                "urls": len(result.entities_found.get("urls", [])),
                "emails": len(result.entities_found.get("emails", [])),
                "payments": len(result.entities_found.get("payments", [])),
                "amounts": len(result.entities_found.get("amounts", []))
            }
        }
        
        # Insert result
        supabase.table('agent_scan_results').insert({
            'task_id': result.task_id,
            'session_id': session_id,
            'entities_found': result.entities_found,
            'tool_results': result.evidence,
            'agent_reasoning': result.reasoning,
            'risk_level': result.risk_level,
            'confidence': result.confidence,
            'evidence_summary': evidence_summary,
            'processing_time_ms': result.processing_time_ms
        }).execute()
        
        logger.info(f"Agent result saved to database: {result.task_id}")
    
    except Exception as e:
        logger.error(f"Failed to save agent result: {e}", exc_info=True)
        # Don't raise - we still want to return the result even if DB save fails


# =============================================================================
# Convenience Functions
# =============================================================================

def get_mcp_agent_orchestrator() -> MCPAgentOrchestrator:
    """
    Get MCPAgentOrchestrator instance.
    
    Returns:
        MCPAgentOrchestrator instance
    """
    return MCPAgentOrchestrator()

