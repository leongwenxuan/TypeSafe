"""Agent Reasoning with LLM.

This module implements the core reasoning component of the MCP agent that analyzes
collected evidence and produces intelligent verdicts using an LLM.

Story: 8.8 - Agent Reasoning with LLM
"""

import os
import json
import logging
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, asdict
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
        return asdict(self)


class AgentReasoner:
    """
    Agent reasoning component using LLM.
    
    Analyzes collected evidence and produces intelligent verdicts with natural
    language explanations. The reasoner weighs conflicting evidence, provides
    clear justifications, and handles edge cases gracefully.
    
    Features:
    - LLM-based reasoning (Gemini or GPT-4)
    - Structured evidence formatting
    - 5-second timeout with fallback
    - Heuristic fallback when LLM unavailable
    - Evidence reliability hierarchy
    """
    
    # System prompt for LLM
    SYSTEM_PROMPT = """You are an expert scam detection agent. Your role is to analyze evidence collected from multiple tools and determine if content is a scam.

Evidence Reliability Hierarchy (most to least reliable):
1. Scam Database - Known scams reported multiple times (highest weight)
2. VirusTotal/Domain Reputation - Security engines flagging malicious content
3. Web Search (Exa) - User complaints and reports online
4. Phone Validator - Pattern-based suspicious indicators

Guidelines:
- Multiple weak signals can indicate a scam even without strong signals
- Recent evidence is more reliable than old evidence
- Higher report counts increase confidence
- Explain your reasoning clearly and cite specific evidence
- Be cautious with conflicting evidence (explain the conflict)
- Consider the quantity and quality of evidence from each tool

Risk Levels:
- HIGH: Strong evidence from reliable sources (Scam DB, Domain Reputation), or multiple medium signals
- MEDIUM: Some concerning evidence but not conclusive, conflicting signals
- LOW: No significant scam indicators, or evidence suggests legitimate

Output Format (JSON):
{
  "risk_level": "low" | "medium" | "high",
  "confidence": 0-100,
  "explanation": "Detailed explanation citing specific evidence",
  "evidence_used": ["list", "of", "tool", "names"]
}

IMPORTANT: Always output valid JSON in the exact format above. Do not include markdown code blocks or additional text."""
    
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
            if not self.api_key:
                raise ValueError("GEMINI_API_KEY not configured")
            
            # Import Gemini service
            from app.services.gemini_service import get_model
            self.llm_model = get_model()
            
        elif model == "gpt4" or model == "gpt4o-mini":
            self.api_key = api_key or os.getenv('OPENAI_API_KEY')
            if not self.api_key:
                raise ValueError("OPENAI_API_KEY not configured")
            
            # Use OpenAI
            from openai import AsyncOpenAI
            self.openai_client = AsyncOpenAI(api_key=self.api_key)
            self.openai_model = "gpt-4o-mini" if model == "gpt4o-mini" else "gpt-4o"
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
            
            # Query LLM with timeout
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
                # Retry once if parsing failed
                logger.warning("LLM response parsing failed, retrying once...")
                try:
                    response = await asyncio.wait_for(
                        self._query_llm(prompt),
                        timeout=5.0
                    )
                    result = self._parse_llm_response(response)
                    if result:
                        return result
                except Exception as e:
                    logger.warning(f"Retry failed: {e}")
                
                # Fall back to heuristic
                logger.warning("Falling back to heuristic after retry failure")
                return self._heuristic_fallback(evidence)
        
        except asyncio.TimeoutError:
            logger.warning("LLM reasoning timeout (>5s), falling back to heuristic")
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
        
        # Truncate OCR text to avoid exceeding token limits
        ocr_preview = ocr_text[:500] if ocr_text else "No OCR text available"
        
        prompt = f"""{self.SYSTEM_PROMPT}

---

OCR Text from Screenshot:
\"\"\"{ocr_preview}\"\"\"

Entities Extracted:
{entities_text}

Evidence Collected:
{evidence_text}

---

Based on the evidence above, determine:
1. Risk level (low, medium, or high)
2. Confidence score (0-100)
3. Detailed explanation citing specific evidence

Output your analysis in JSON format as specified above."""
        
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
                    report_count = result.get("report_count", 0)
                    risk_score = result.get("risk_score", 0)
                    verified = result.get("verified", False)
                    verified_text = " (VERIFIED)" if verified else ""
                    formatted.append(
                        f"{i}. Tool: Scam Database | Entity: {entity_type}:{entity_value} | "
                        f"FOUND{verified_text} - {report_count} reports, risk score {risk_score}"
                    )
                else:
                    formatted.append(f"{i}. Tool: Scam Database | Entity: {entity_type}:{entity_value} | NOT FOUND")
            
            elif tool_name == "exa_search":
                result_count = len(result.get("results", []))
                if result_count > 0:
                    # Include sample titles from results
                    sample_titles = []
                    for res in result.get("results", [])[:2]:  # First 2 results
                        title = res.get("title", "")
                        if title:
                            sample_titles.append(title[:60])
                    
                    titles_preview = " | Examples: " + "; ".join(sample_titles) if sample_titles else ""
                    formatted.append(
                        f"{i}. Tool: Web Search | Entity: {entity_type}:{entity_value} | "
                        f"FOUND {result_count} web complaints/reports{titles_preview}"
                    )
                else:
                    formatted.append(f"{i}. Tool: Web Search | Entity: {entity_type}:{entity_value} | No results")
            
            elif tool_name == "domain_reputation":
                risk_level = result.get("risk_level", "unknown")
                vt_score = result.get("virustotal_malicious", 0)
                age_days = result.get("age_days")
                age_text = f"{age_days} days" if age_days is not None else "unknown"
                formatted.append(
                    f"{i}. Tool: Domain Reputation | Entity: {entity_type}:{entity_value} | "
                    f"Risk: {risk_level}, VirusTotal: {vt_score} engines flagged, Age: {age_text}"
                )
            
            elif tool_name == "phone_validator":
                if result.get("suspicious"):
                    formatted.append(
                        f"{i}. Tool: Phone Validator | Entity: {entity_type}:{entity_value} | "
                        f"SUSPICIOUS - {result.get('suspicious_reason', 'Unknown reason')}"
                    )
                else:
                    number_type = result.get("number_type", "unknown")
                    formatted.append(
                        f"{i}. Tool: Phone Validator | Entity: {entity_type}:{entity_value} | "
                        f"Valid {number_type} number"
                    )
            else:
                # Generic formatting for unknown tools
                formatted.append(
                    f"{i}. Tool: {tool_name} | Entity: {entity_type}:{entity_value} | "
                    f"Result: {str(result)[:100]}"
                )
        
        return "\n".join(formatted)
    
    def _format_entities(self, entities_found: Dict[str, List[str]]) -> str:
        """Format entities for prompt."""
        parts = []
        for entity_type, values in entities_found.items():
            if values:
                # Limit to 3 per type to keep prompt concise
                values_preview = values[:3]
                count_text = f" (+{len(values) - 3} more)" if len(values) > 3 else ""
                parts.append(f"- {entity_type}: {', '.join(values_preview)}{count_text}")
        
        return "\n".join(parts) if parts else "No entities found"
    
    async def _query_llm(self, prompt: str) -> str:
        """Query LLM with prompt."""
        if self.model == "gemini":
            # Use Gemini generate_content
            response = await asyncio.to_thread(
                self.llm_model.generate_content,
                prompt,
                generation_config={'temperature': 0.2}  # Low temperature for consistent reasoning
            )
            
            if not response or not response.text:
                raise ValueError("Empty response from Gemini")
            
            return response.text
        
        elif self.model in ["gpt4", "gpt4o-mini"]:
            # Use OpenAI ChatCompletion
            response = await self.openai_client.chat.completions.create(
                model=self.openai_model,
                messages=[
                    {"role": "system", "content": "You are a scam detection expert analyzing evidence."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.2,  # Low temperature for consistent reasoning
                response_format={"type": "json_object"}  # Force JSON output
            )
            
            if not response.choices or not response.choices[0].message.content:
                raise ValueError("Empty response from OpenAI")
            
            return response.choices[0].message.content
        
        else:
            raise NotImplementedError(f"LLM model {self.model} not implemented")
    
    def _parse_llm_response(self, response: str) -> Optional[ReasoningResult]:
        """Parse LLM response into ReasoningResult."""
        try:
            # Extract JSON from response (handle markdown code blocks)
            json_str = response.strip()
            
            # Remove markdown code blocks if present
            if "```json" in json_str:
                json_str = json_str.split("```json")[1].split("```")[0].strip()
            elif "```" in json_str:
                # Try to extract content between first ``` pair
                parts = json_str.split("```")
                if len(parts) >= 3:
                    json_str = parts[1].strip()
            
            # Try to find JSON object in text
            start_idx = json_str.find("{")
            end_idx = json_str.rfind("}")
            if start_idx != -1 and end_idx != -1:
                json_str = json_str[start_idx:end_idx + 1]
            
            data = json.loads(json_str)
            
            # Validate fields
            risk_level = data.get("risk_level", "").lower()
            if risk_level not in ["low", "medium", "high"]:
                logger.warning(f"Invalid risk_level from LLM: {risk_level}")
                return None
            
            confidence = float(data.get("confidence", 50))
            if not 0 <= confidence <= 100:
                logger.warning(f"Invalid confidence from LLM: {confidence}, clamping to 0-100")
                confidence = max(0, min(100, confidence))
            
            explanation = data.get("explanation", "")
            if not explanation or len(explanation.strip()) < 10:
                logger.warning("Empty or too short explanation from LLM")
                return None
            
            evidence_used = data.get("evidence_used", [])
            if not isinstance(evidence_used, list):
                evidence_used = []
            
            return ReasoningResult(
                risk_level=risk_level,
                confidence=confidence,
                explanation=explanation,
                evidence_used=evidence_used,
                reasoning_method="llm"
            )
        
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse LLM response as JSON: {e}")
            logger.debug(f"LLM response: {response[:500]}")
            return None
        
        except (ValueError, KeyError) as e:
            logger.error(f"Error parsing LLM response: {e}")
            return None
    
    def _heuristic_fallback(self, evidence: List[Dict[str, Any]]) -> ReasoningResult:
        """
        Fallback heuristic reasoning when LLM unavailable.
        
        This is the same heuristic logic from Story 8.7, used as a reliable
        fallback when LLM fails, times out, or returns invalid output.
        """
        score = 0.0
        reasons = []
        
        for e in evidence:
            if not e.get("success"):
                continue
            
            result = e.get("result", {})
            tool_name = e.get("tool_name")
            
            # Scam DB findings (highest weight - authoritative source)
            if tool_name == "scam_db" and result.get("found"):
                report_count = result.get("report_count", 0)
                risk_score = result.get("risk_score", 0)
                
                # Higher weight for verified reports
                if result.get("verified"):
                    score += min(risk_score * 0.6, 50)  # Max 50 points for verified
                    reasons.append(f"Verified scam in database ({report_count} reports)")
                else:
                    score += min(report_count * 5, 40)  # Max 40 points
                    reasons.append(f"Found in scam database ({report_count} reports)")
            
            # Exa search results (web complaints and reports)
            if tool_name == "exa_search":
                results_list = result.get("results", [])
                if results_list:
                    result_count = len(results_list)
                    score += min(result_count * 2, 20)  # Max 20 points
                    reasons.append(f"Found {result_count} web complaints/reports")
            
            # Domain reputation (for URLs)
            if tool_name == "domain_reputation":
                risk_level = result.get("risk_level")
                if risk_level == "high":
                    score += 30
                    reasons.append("Domain flagged as high risk")
                elif risk_level == "medium":
                    score += 15
                    reasons.append("Domain flagged as medium risk")
                
                # Add points for young domain
                age_days = result.get("age_days")
                if age_days is not None and age_days < 30:
                    score += 10
                    reasons.append(f"Very new domain ({age_days} days old)")
            
            # Phone validator suspicious patterns
            if tool_name == "phone_validator" and result.get("suspicious"):
                score += 25
                suspicious_reason = result.get("suspicious_reason", "Unknown")
                reasons.append(f"Suspicious phone pattern: {suspicious_reason}")
        
        # Determine risk level based on score
        if score >= 70:
            risk_level = "high"
            confidence = min(score, 100)
        elif score >= 40:
            risk_level = "medium"
            confidence = min(score, 100)
        else:
            risk_level = "low"
            confidence = max(100 - score, 50)  # At least 50% confidence for low risk
        
        # Build explanation
        if reasons:
            explanation = "Heuristic analysis detected: " + "; ".join(reasons) + "."
        else:
            explanation = "No strong scam indicators found. Heuristic analysis suggests low risk."
        
        return ReasoningResult(
            risk_level=risk_level,
            confidence=confidence,
            explanation=explanation,
            evidence_used=[r.split(":")[0].strip() for r in reasons] if reasons else [],
            reasoning_method="heuristic"
        )


# Singleton instance
_reasoner_instance = None


def get_agent_reasoner(model: str = "gpt4o-mini") -> AgentReasoner:
    """
    Get singleton AgentReasoner instance.
    
    Args:
        model: LLM model to use (gpt4o-mini, gpt4, or gemini)
    
    Returns:
        AgentReasoner instance
    """
    global _reasoner_instance
    if _reasoner_instance is None:
        _reasoner_instance = AgentReasoner(model=model)
    return _reasoner_instance

