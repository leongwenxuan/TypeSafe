# Story 8.8: Agent Reasoning with LLM

**Story ID:** 8.8  
**Epic:** Epic 8 - MCP Agent with Multi-Tool Orchestration  
**Priority:** P0 (Critical for Intelligent Verdicts)  
**Effort:** 12 hours  
**Assignee:** Backend Developer  
**Status:** 📝 Ready for Development

---

## User Story

**As an** MCP agent,  
**I want** to use an LLM to reason over collected evidence,  
**so that** I can generate intelligent verdicts with clear explanations.

---

## Description

The Agent Reasoning component is the **final decision-making step** where an LLM analyzes all collected evidence and produces a coherent verdict. This moves beyond simple heuristic scoring to nuanced, context-aware analysis.

**Key Capabilities:**
- Weighs conflicting evidence intelligently
- Provides natural language explanations
- Cites specific evidence in reasoning
- Handles edge cases and ambiguous signals

**Example:**
```
Evidence Collected:
- Scam DB: FOUND - 47 reports
- Exa Search: 12 web complaints
- Phone Validator: Suspicious pattern (all zeros)
- Domain Reputation: N/A (no URL)

↓ LLM Reasoning ↓

"HIGH RISK: This phone number shows multiple strong scam indicators. It appears in our scam
database with 47 previous reports, has been mentioned in 12 web complaints (Reddit, BBB),
and uses a suspicious pattern (all zeros). The combination of database evidence and web
reports provides high confidence this is a scam."

Risk: HIGH | Confidence: 95%
```

---

## Acceptance Criteria

### LLM Integration
- [ ] 1. `AgentReasoner` class created in `app/agents/reasoning.py`
- [ ] 2. Uses Gemini Pro or GPT-4 for reasoning (configurable)
- [ ] 3. Structured prompt with evidence, OCR context, and reasoning instructions
- [ ] 4. Returns: `{"risk_level": str, "confidence": float, "explanation": str, "evidence_used": list}`
- [ ] 5. Timeout: 5 seconds (fallback to heuristic if LLM unavailable)

### Prompt Engineering
- [ ] 6. System prompt defines agent role and reasoning guidelines
- [ ] 7. Evidence formatted clearly: Tool name, entity, result summary
- [ ] 8. Asks for: Risk level, confidence score, detailed explanation
- [ ] 9. Instructs to cite specific evidence in explanation
- [ ] 10. Handles cases with conflicting evidence (e.g., DB says safe, web says scam)

### Evidence Weighing
- [ ] 11. Prompt instructs reliability hierarchy: Scam DB > VirusTotal > Exa > Phone Validator
- [ ] 12. Multiple weak signals can outweigh one strong signal
- [ ] 13. Recency matters: Recent reports weighted higher
- [ ] 14. Quantity matters: 50 reports > 2 reports

### Output Parsing
- [ ] 15. Parses LLM response to extract risk_level, confidence, explanation
- [ ] 16. Validates risk_level is one of: `low`, `medium`, `high`
- [ ] 17. Validates confidence is 0-100
- [ ] 18. Handles malformed LLM responses gracefully (retry or fallback)

### Fallback Strategy
- [ ] 19. If LLM times out, use heuristic scoring (from Story 8.7)
- [ ] 20. If LLM returns invalid format, retry once then fallback
- [ ] 21. Logs all LLM failures for debugging

### Testing
- [ ] 22. Unit tests with mocked LLM responses
- [ ] 23. Real LLM tests with diverse evidence scenarios
- [ ] 24. Edge case tests: Conflicting evidence, no evidence, all tools failed
- [ ] 25. Performance tests: Reasoning latency < 5 seconds

---

## Technical Implementation

**`app/agents/reasoning.py`:**

```python
"""Agent Reasoning with LLM."""

import os
import json
import logging
from typing import Dict, Any, List, Optional, Tuple
from dataclasses import dataclass
import asyncio

logger = logging.getLogger(__name__)


@dataclass
class ReasoningResult:
    """Result from agent reasoning."""
    risk_level: str  # low, medium, high
    confidence: float  # 0-100
    explanation: str
    evidence_used: List[str]
    reasoning_method: str  # llm or heuristic
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "risk_level": self.risk_level,
            "confidence": self.confidence,
            "explanation": self.explanation,
            "evidence_used": self.evidence_used,
            "reasoning_method": self.reasoning_method
        }


class AgentReasoner:
    """
    Agent reasoning component using LLM.
    
    Analyzes collected evidence and produces intelligent verdicts.
    """
    
    # System prompt for LLM
    SYSTEM_PROMPT = """You are an expert scam detection agent. Your role is to analyze evidence collected from multiple tools and determine if content is a scam.

Evidence Reliability Hierarchy (most to least reliable):
1. Scam Database - Known scams reported multiple times
2. VirusTotal/Domain Reputation - Security engines flagging malicious content
3. Web Search (Exa) - User complaints and reports online
4. Phone Validator - Pattern-based suspicious indicators

Guidelines:
- Multiple weak signals can indicate a scam even without strong signals
- Recent evidence is more reliable than old evidence
- Higher report counts increase confidence
- Explain your reasoning clearly and cite specific evidence
- Be cautious with conflicting evidence (explain the conflict)

Output Format (JSON):
{
  "risk_level": "low" | "medium" | "high",
  "confidence": 0-100,
  "explanation": "Detailed explanation citing specific evidence",
  "evidence_used": ["list", "of", "evidence", "keys"]
}
"""
    
    def __init__(
        self,
        model: str = "gemini",  # gemini or gpt4
        api_key: Optional[str] = None
    ):
        """
        Initialize agent reasoner.
        
        Args:
            model: LLM model to use (gemini or gpt4)
            api_key: Optional API key (uses env var if not provided)
        """
        self.model = model
        
        if model == "gemini":
            self.api_key = api_key or os.getenv('GEMINI_API_KEY')
            from app.services.gemini_service import GeminiService
            self.llm_service = GeminiService()
        elif model == "gpt4":
            self.api_key = api_key or os.getenv('OPENAI_API_KEY')
            # GPT-4 integration (if needed)
            raise NotImplementedError("GPT-4 integration pending")
        else:
            raise ValueError(f"Unsupported model: {model}")
        
        logger.info(f"AgentReasoner initialized (model={model})")
    
    async def reason(
        self,
        evidence: List[Dict[str, Any]],
        ocr_text: str,
        entities_found: Dict[str, List[str]]
    ) -> ReasoningResult:
        """
        Reason over evidence to produce verdict.
        
        Args:
            evidence: List of evidence dictionaries from tools
            ocr_text: Original OCR text for context
            entities_found: Entities extracted from text
        
        Returns:
            ReasoningResult with risk level, confidence, and explanation
        """
        try:
            # Build prompt
            prompt = self._build_prompt(evidence, ocr_text, entities_found)
            
            # Query LLM
            response = await asyncio.wait_for(
                self._query_llm(prompt),
                timeout=5.0
            )
            
            # Parse response
            result = self._parse_llm_response(response)
            
            if result:
                logger.info(f"LLM reasoning: risk={result.risk_level}, confidence={result.confidence}")
                return result
            else:
                logger.warning("LLM response parsing failed, falling back to heuristic")
                return self._heuristic_fallback(evidence)
        
        except asyncio.TimeoutError:
            logger.warning("LLM reasoning timeout, falling back to heuristic")
            return self._heuristic_fallback(evidence)
        
        except Exception as e:
            logger.error(f"LLM reasoning error: {e}", exc_info=True)
            return self._heuristic_fallback(evidence)
    
    def _build_prompt(
        self,
        evidence: List[Dict[str, Any]],
        ocr_text: str,
        entities_found: Dict[str, List[str]]
    ) -> str:
        """Build prompt for LLM."""
        # Format evidence
        evidence_text = self._format_evidence(evidence)
        
        # Format entities
        entities_text = self._format_entities(entities_found)
        
        prompt = f"""{self.SYSTEM_PROMPT}

---

OCR Text from Screenshot:
\"\"\"{ocr_text[:500]}\"\"\"

Entities Extracted:
{entities_text}

Evidence Collected:
{evidence_text}

---

Based on the evidence above, determine:
1. Risk level (low, medium, or high)
2. Confidence score (0-100)
3. Detailed explanation citing specific evidence

Output your analysis in JSON format."""
        
        return prompt
    
    def _format_evidence(self, evidence: List[Dict[str, Any]]) -> str:
        """Format evidence for prompt."""
        if not evidence:
            return "No evidence collected (all tools failed or returned no results)."
        
        formatted = []
        for i, e in enumerate(evidence, 1):
            tool_name = e.get("tool_name", "unknown")
            entity_type = e.get("entity_type", "unknown")
            entity_value = e.get("entity_value", "unknown")
            result = e.get("result", {})
            success = e.get("success", False)
            
            if not success:
                formatted.append(f"{i}. Tool: {tool_name} | Entity: {entity_type}:{entity_value} | Result: FAILED")
                continue
            
            # Format based on tool type
            if tool_name == "scam_db":
                if result.get("found"):
                    formatted.append(
                        f"{i}. Tool: Scam Database | Entity: {entity_type}:{entity_value} | "
                        f"FOUND - {result.get('report_count')} reports, risk score {result.get('risk_score')}"
                    )
                else:
                    formatted.append(f"{i}. Tool: Scam Database | Entity: {entity_type}:{entity_value} | NOT FOUND")
            
            elif tool_name == "exa_search":
                result_count = len(result.get("results", []))
                if result_count > 0:
                    formatted.append(
                        f"{i}. Tool: Web Search | Entity: {entity_type}:{entity_value} | "
                        f"FOUND {result_count} web complaints/reports"
                    )
                else:
                    formatted.append(f"{i}. Tool: Web Search | Entity: {entity_type}:{entity_value} | No results")
            
            elif tool_name == "domain_reputation":
                risk_level = result.get("risk_level", "unknown")
                vt_score = result.get("virustotal_malicious", 0)
                age_days = result.get("age_days")
                formatted.append(
                    f"{i}. Tool: Domain Reputation | Entity: {entity_type}:{entity_value} | "
                    f"Risk: {risk_level}, VirusTotal: {vt_score} engines flagged, Age: {age_days} days"
                )
            
            elif tool_name == "phone_validator":
                if result.get("suspicious"):
                    formatted.append(
                        f"{i}. Tool: Phone Validator | Entity: {entity_type}:{entity_value} | "
                        f"SUSPICIOUS - {result.get('suspicious_reason')}"
                    )
                else:
                    formatted.append(
                        f"{i}. Tool: Phone Validator | Entity: {entity_type}:{entity_value} | "
                        f"Valid {result.get('number_type')} number"
                    )
        
        return "\n".join(formatted)
    
    def _format_entities(self, entities_found: Dict[str, List[str]]) -> str:
        """Format entities for prompt."""
        parts = []
        for entity_type, values in entities_found.items():
            if values:
                parts.append(f"- {entity_type}: {', '.join(values[:3])}")  # Limit to 3 per type
        
        return "\n".join(parts) if parts else "No entities found"
    
    async def _query_llm(self, prompt: str) -> str:
        """Query LLM with prompt."""
        if self.model == "gemini":
            # Use Gemini service
            response = await self.llm_service.generate_content_async(prompt)
            return response
        else:
            raise NotImplementedError(f"LLM model {self.model} not implemented")
    
    def _parse_llm_response(self, response: str) -> Optional[ReasoningResult]:
        """Parse LLM response into ReasoningResult."""
        try:
            # Extract JSON from response (handle markdown code blocks)
            json_str = response
            if "```json" in response:
                json_str = response.split("```json")[1].split("```")[0]
            elif "```" in response:
                json_str = response.split("```")[1].split("```")[0]
            
            data = json.loads(json_str.strip())
            
            # Validate fields
            risk_level = data.get("risk_level", "").lower()
            if risk_level not in ["low", "medium", "high"]:
                logger.warning(f"Invalid risk_level from LLM: {risk_level}")
                return None
            
            confidence = float(data.get("confidence", 50))
            if not 0 <= confidence <= 100:
                confidence = max(0, min(100, confidence))
            
            explanation = data.get("explanation", "")
            if not explanation:
                logger.warning("Empty explanation from LLM")
                return None
            
            evidence_used = data.get("evidence_used", [])
            
            return ReasoningResult(
                risk_level=risk_level,
                confidence=confidence,
                explanation=explanation,
                evidence_used=evidence_used,
                reasoning_method="llm"
            )
        
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse LLM response as JSON: {e}")
            logger.debug(f"LLM response: {response}")
            return None
        
        except Exception as e:
            logger.error(f"Error parsing LLM response: {e}")
            return None
    
    def _heuristic_fallback(self, evidence: List[Dict[str, Any]]) -> ReasoningResult:
        """Fallback heuristic reasoning when LLM unavailable."""
        score = 0.0
        reasons = []
        
        for e in evidence:
            if not e.get("success"):
                continue
            
            result = e.get("result", {})
            tool_name = e.get("tool_name")
            
            # Scam DB findings
            if tool_name == "scam_db" and result.get("found"):
                report_count = result.get("report_count", 0)
                score += min(report_count * 5, 40)
                reasons.append(f"Found in scam database ({report_count} reports)")
            
            # Exa search results
            if tool_name == "exa_search":
                result_count = len(result.get("results", []))
                if result_count > 0:
                    score += min(result_count * 2, 20)
                    reasons.append(f"Found {result_count} web complaints")
            
            # Domain reputation
            if tool_name == "domain_reputation":
                risk_level = result.get("risk_level")
                if risk_level == "high":
                    score += 30
                    reasons.append("Domain flagged as high risk")
                elif risk_level == "medium":
                    score += 15
                    reasons.append("Domain flagged as medium risk")
            
            # Phone validator
            if tool_name == "phone_validator" and result.get("suspicious"):
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
            confidence = max(100 - score, 50)
        
        # Build explanation
        if reasons:
            explanation = "Heuristic analysis detected: " + "; ".join(reasons)
        else:
            explanation = "No strong scam indicators found. Heuristic analysis suggests low risk."
        
        return ReasoningResult(
            risk_level=risk_level,
            confidence=confidence,
            explanation=explanation,
            evidence_used=[r.split(":")[0] for r in reasons],
            reasoning_method="heuristic"
        )


# Singleton instance
_reasoner_instance = None

def get_agent_reasoner() -> AgentReasoner:
    """Get singleton AgentReasoner instance."""
    global _reasoner_instance
    if _reasoner_instance is None:
        _reasoner_instance = AgentReasoner()
    return _reasoner_instance
```

---

## Testing Strategy

```python
"""Unit tests for Agent Reasoning."""

import pytest
from unittest.mock import AsyncMock, patch
from app.agents.reasoning import AgentReasoner, ReasoningResult


@pytest.fixture
def reasoner():
    """Fixture providing AgentReasoner."""
    return AgentReasoner(model="gemini")


@pytest.mark.asyncio
class TestLLMReasoning:
    """Test LLM reasoning."""
    
    async def test_high_risk_verdict(self, reasoner):
        """Test LLM produces high risk verdict with strong evidence."""
        evidence = [
            {
                "tool_name": "scam_db",
                "entity_type": "phone",
                "entity_value": "+18005551234",
                "result": {"found": True, "report_count": 47, "risk_score": 95},
                "success": True
            },
            {
                "tool_name": "exa_search",
                "entity_type": "phone",
                "entity_value": "+18005551234",
                "result": {"results": [{"title": "Scam alert"}] * 12},
                "success": True
            }
        ]
        
        # Mock LLM response
        mock_response = '''{
            "risk_level": "high",
            "confidence": 95,
            "explanation": "Strong evidence of scam: 47 database reports and 12 web complaints",
            "evidence_used": ["scam_db", "exa_search"]
        }'''
        
        with patch.object(reasoner, '_query_llm', new=AsyncMock(return_value=mock_response)):
            result = await reasoner.reason(evidence, "Call 800-555-1234", {"phones": ["+18005551234"]})
        
        assert result.risk_level == "high"
        assert result.confidence >= 90
        assert "scam" in result.explanation.lower()
    
    async def test_fallback_on_timeout(self, reasoner):
        """Test fallback to heuristic on LLM timeout."""
        evidence = [
            {
                "tool_name": "scam_db",
                "entity_type": "phone",
                "entity_value": "+18005551234",
                "result": {"found": True, "report_count": 10},
                "success": True
            }
        ]
        
        # Mock timeout
        with patch.object(reasoner, '_query_llm', new=AsyncMock(side_effect=asyncio.TimeoutError)):
            result = await reasoner.reason(evidence, "Test", {})
        
        assert result.reasoning_method == "heuristic"
        assert result.risk_level in ["low", "medium", "high"]
```

---

## Success Criteria

- [ ] All 25 acceptance criteria met
- [ ] LLM reasoning completes in < 5 seconds
- [ ] Fallback heuristic works when LLM fails
- [ ] All unit tests passing
- [ ] Real LLM tests with diverse scenarios

---

**Estimated Effort:** 12 hours  
**Sprint:** Week 9, Day 5

