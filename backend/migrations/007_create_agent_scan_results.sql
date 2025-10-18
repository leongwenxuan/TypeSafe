-- Migration 007: Create agent_scan_results table
-- Story: 8.7 - MCP Agent Task Orchestration
-- Description: Table to store MCP agent analysis results with evidence and reasoning

-- ============================================================================
-- agent_scan_results table
-- ============================================================================
-- Stores the complete output from MCP agent analysis including:
-- - Entities found (phones, URLs, emails, payments, amounts)
-- - Tool execution results (evidence)
-- - Agent reasoning and risk assessment
-- - Performance metrics

CREATE TABLE IF NOT EXISTS agent_scan_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Task and session linkage
    task_id TEXT UNIQUE NOT NULL,
    session_id UUID NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
    
    -- Extracted entities
    entities_found JSONB DEFAULT '{}'::jsonb,
    -- Structure: {
    --   "phones": ["+18005551234", ...],
    --   "urls": ["https://example.com", ...],
    --   "emails": ["user@example.com", ...],
    --   "payments": ["bitcoin:1A1zP1...", ...],
    --   "amounts": [{"amount": "500", "currency": "USD"}, ...]
    -- }
    
    -- Tool execution results (evidence)
    tool_results JSONB DEFAULT '[]'::jsonb,
    -- Structure: [
    --   {
    --     "tool_name": "scam_db",
    --     "entity_type": "phone",
    --     "entity_value": "+18005551234",
    --     "result": {...},
    --     "success": true,
    --     "execution_time_ms": 45.2
    --   }, ...
    -- ]
    
    -- Agent reasoning and verdict
    agent_reasoning TEXT,
    risk_level TEXT NOT NULL CHECK (risk_level IN ('low', 'medium', 'high')),
    confidence FLOAT NOT NULL CHECK (confidence >= 0 AND confidence <= 100),
    
    -- Evidence summary
    evidence_summary JSONB DEFAULT '{}'::jsonb,
    -- Structure: {
    --   "tools_used": ["scam_db", "exa_search", "domain_reputation"],
    --   "evidence_count": 5,
    --   "high_risk_indicators": ["found_in_scam_db", "domain_flagged"],
    --   "entity_counts": {"phones": 1, "urls": 2, "emails": 0}
    -- }
    
    -- Performance metrics
    processing_time_ms INTEGER NOT NULL,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- Indexes
-- ============================================================================

-- Primary lookup: Find results by task_id
CREATE INDEX idx_agent_results_task_id ON agent_scan_results(task_id);

-- Find all results for a session
CREATE INDEX idx_agent_results_session_id ON agent_scan_results(session_id);

-- Query by risk level
CREATE INDEX idx_agent_results_risk_level ON agent_scan_results(risk_level);

-- Recent results (for monitoring)
CREATE INDEX idx_agent_results_created_at ON agent_scan_results(created_at DESC);

-- GIN index for JSONB queries on entities and tool results
CREATE INDEX idx_agent_results_entities_gin ON agent_scan_results USING GIN (entities_found);
CREATE INDEX idx_agent_results_tools_gin ON agent_scan_results USING GIN (tool_results);

-- ============================================================================
-- RLS (Row Level Security)
-- ============================================================================

-- Enable RLS
ALTER TABLE agent_scan_results ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own session's results
CREATE POLICY agent_results_select_policy ON agent_scan_results
    FOR SELECT
    USING (
        session_id IN (
            SELECT id FROM sessions WHERE id = agent_scan_results.session_id
        )
    );

-- Policy: Backend service can insert (authenticated via service role)
CREATE POLICY agent_results_insert_policy ON agent_scan_results
    FOR INSERT
    WITH CHECK (true);

-- Policy: Backend service can update (for reprocessing)
CREATE POLICY agent_results_update_policy ON agent_scan_results
    FOR UPDATE
    USING (true);

-- ============================================================================
-- Triggers
-- ============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_agent_results_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER agent_results_updated_at_trigger
    BEFORE UPDATE ON agent_scan_results
    FOR EACH ROW
    EXECUTE FUNCTION update_agent_results_updated_at();

-- ============================================================================
-- Helper functions
-- ============================================================================

-- Function: Get agent result by task_id
CREATE OR REPLACE FUNCTION get_agent_result_by_task(p_task_id TEXT)
RETURNS TABLE (
    id UUID,
    task_id TEXT,
    session_id UUID,
    entities_found JSONB,
    tool_results JSONB,
    agent_reasoning TEXT,
    risk_level TEXT,
    confidence FLOAT,
    evidence_summary JSONB,
    processing_time_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ar.id,
        ar.task_id,
        ar.session_id,
        ar.entities_found,
        ar.tool_results,
        ar.agent_reasoning,
        ar.risk_level,
        ar.confidence,
        ar.evidence_summary,
        ar.processing_time_ms,
        ar.created_at
    FROM agent_scan_results ar
    WHERE ar.task_id = p_task_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Get all agent results for a session
CREATE OR REPLACE FUNCTION get_agent_results_by_session(p_session_id UUID)
RETURNS TABLE (
    id UUID,
    task_id TEXT,
    entities_found JSONB,
    tool_results JSONB,
    agent_reasoning TEXT,
    risk_level TEXT,
    confidence FLOAT,
    processing_time_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ar.id,
        ar.task_id,
        ar.entities_found,
        ar.tool_results,
        ar.agent_reasoning,
        ar.risk_level,
        ar.confidence,
        ar.processing_time_ms,
        ar.created_at
    FROM agent_scan_results ar
    WHERE ar.session_id = p_session_id
    ORDER BY ar.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function: Get high-risk agent results
CREATE OR REPLACE FUNCTION get_high_risk_agent_results(
    p_limit INTEGER DEFAULT 100,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    task_id TEXT,
    session_id UUID,
    entities_found JSONB,
    risk_level TEXT,
    confidence FLOAT,
    agent_reasoning TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ar.id,
        ar.task_id,
        ar.session_id,
        ar.entities_found,
        ar.risk_level,
        ar.confidence,
        ar.agent_reasoning,
        ar.created_at
    FROM agent_scan_results ar
    WHERE ar.risk_level = 'high'
    ORDER BY ar.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Statistics view
-- ============================================================================

-- View: Agent performance statistics
CREATE OR REPLACE VIEW agent_performance_stats AS
SELECT
    COUNT(*) as total_analyses,
    COUNT(CASE WHEN risk_level = 'high' THEN 1 END) as high_risk_count,
    COUNT(CASE WHEN risk_level = 'medium' THEN 1 END) as medium_risk_count,
    COUNT(CASE WHEN risk_level = 'low' THEN 1 END) as low_risk_count,
    AVG(confidence) as avg_confidence,
    AVG(processing_time_ms) as avg_processing_time_ms,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY processing_time_ms) as median_processing_time_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY processing_time_ms) as p95_processing_time_ms,
    MIN(created_at) as first_analysis,
    MAX(created_at) as last_analysis
FROM agent_scan_results;

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON TABLE agent_scan_results IS 'MCP agent analysis results with evidence and reasoning (Story 8.7)';
COMMENT ON COLUMN agent_scan_results.task_id IS 'Unique task identifier from Celery';
COMMENT ON COLUMN agent_scan_results.session_id IS 'User session that triggered the analysis';
COMMENT ON COLUMN agent_scan_results.entities_found IS 'Entities extracted from OCR text (phones, URLs, emails, payments)';
COMMENT ON COLUMN agent_scan_results.tool_results IS 'Array of tool execution results (evidence)';
COMMENT ON COLUMN agent_scan_results.agent_reasoning IS 'LLM-generated reasoning for risk assessment';
COMMENT ON COLUMN agent_scan_results.risk_level IS 'Overall risk assessment: low, medium, high';
COMMENT ON COLUMN agent_scan_results.confidence IS 'Confidence score 0-100';
COMMENT ON COLUMN agent_scan_results.evidence_summary IS 'Summary of evidence collected';
COMMENT ON COLUMN agent_scan_results.processing_time_ms IS 'Total processing time in milliseconds';

