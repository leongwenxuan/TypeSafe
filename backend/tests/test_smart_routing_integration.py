"""
Integration tests for smart routing (Story 8.10).

Tests the full integration between routing logic, entity extraction,
fast path analysis, and agent orchestration.
"""

import pytest
import uuid
from unittest.mock import Mock, patch, AsyncMock
from datetime import datetime

from fastapi.testclient import TestClient

from app.main import app
from app.services.entity_extractor import ExtractedEntities


class TestFastPathIntegration:
    """Integration tests for fast path routing."""
    
    def setup_method(self):
        """Setup test client."""
        self.client = TestClient(app)
    
    @patch('app.main.get_entity_extractor')
    @patch('app.main.analyze_image')
    @patch('app.main.insert_scan_result')
    @patch('app.main.ensure_session_exists')
    def test_fast_path_end_to_end_no_entities(
        self,
        mock_ensure_session,
        mock_db,
        mock_gemini,
        mock_extractor_getter
    ):
        """Test complete fast path flow with no entities."""
        # Setup
        session_id = str(uuid.uuid4())
        
        # Mock entity extraction - no entities
        mock_extractor = Mock()
        mock_entities = ExtractedEntities(
            phones=[],
            urls=[],
            emails=[],
            payments=[],
            amounts=[]
        )
        mock_extractor.extract.return_value = mock_entities
        mock_extractor_getter.return_value = mock_extractor
        
        # Mock Gemini response
        mock_gemini.return_value = {
            'risk_level': 'low',
            'confidence': 0.85,
            'category': 'unknown',
            'explanation': 'Generic message, no scam indicators'
        }
        
        # Mock DB
        mock_ensure_session.return_value = {'id': session_id}
        mock_db.return_value = {'id': 'result-id'}
        
        # Execute
        response = self.client.post(
            "/scan-image",
            data={
                "session_id": session_id,
                "ocr_text": "Hello, how are you today?"
            }
        )
        
        # Verify
        assert response.status_code == 200
        data = response.json()
        
        # Should be simple response
        assert data['type'] == 'simple'
        assert 'result' in data
        
        # Result should have correct structure
        result = data['result']
        assert result['risk_level'] == 'low'
        assert result['confidence'] == 0.85
        assert result['category'] == 'unknown'
        assert 'ts' in result
        
        # Verify entity extraction was called
        mock_extractor.extract.assert_called_once()
        
        # Verify Gemini was called
        mock_gemini.assert_called_once()
        
        # Verify DB was called
        mock_db.assert_called_once()
    
    @patch('app.main.get_entity_extractor')
    @patch('app.main.analyze_image')
    @patch('app.main.analyze_text_groq')
    @patch('app.main.aggregate_results')
    @patch('app.main.insert_scan_result')
    @patch('app.main.ensure_session_exists')
    def test_fast_path_with_gemini_and_groq_aggregation(
        self,
        mock_ensure_session,
        mock_db,
        mock_aggregate,
        mock_groq,
        mock_gemini,
        mock_extractor_getter
    ):
        """Test fast path aggregates Gemini and Groq results."""
        # Setup
        session_id = str(uuid.uuid4())
        
        # Mock entity extraction - no entities
        mock_extractor = Mock()
        mock_entities = ExtractedEntities(
            phones=[],
            urls=[],
            emails=[],
            payments=[],
            amounts=[]
        )
        mock_extractor.extract.return_value = mock_entities
        mock_extractor_getter.return_value = mock_extractor
        
        # Mock Gemini response
        gemini_result = {
            'risk_level': 'medium',
            'confidence': 0.7,
            'category': 'otp_phishing',
            'explanation': 'Possible OTP request'
        }
        mock_gemini.return_value = gemini_result
        
        # Mock Groq response (should not be called since Gemini succeeded)
        groq_result = {
            'risk_level': 'low',
            'confidence': 0.6,
            'category': 'unknown',
            'explanation': 'No clear scam'
        }
        mock_groq.return_value = groq_result
        
        # Mock aggregation
        mock_aggregate.return_value = {
            'risk_level': 'medium',
            'confidence': 0.65,
            'category': 'otp_phishing',
            'explanation': 'Possible OTP phishing attempt'
        }
        
        # Mock DB
        mock_ensure_session.return_value = {'id': session_id}
        mock_db.return_value = {'id': 'result-id'}
        
        # Execute
        response = self.client.post(
            "/scan-image",
            data={
                "session_id": session_id,
                "ocr_text": "Please enter verification code 123456"
            }
        )
        
        # Verify
        assert response.status_code == 200
        data = response.json()
        assert data['type'] == 'simple'
        
        # Gemini should be called but Groq should not (since Gemini succeeded)
        mock_gemini.assert_called_once()
        # Groq is NOT called when Gemini returns valid result
        mock_groq.assert_not_called()


class TestAgentPathIntegration:
    """Integration tests for agent path routing."""
    
    def setup_method(self):
        """Setup test client."""
        self.client = TestClient(app)
    
    @patch('app.main.get_entity_extractor')
    @patch('app.main._check_worker_availability')
    @patch('app.main.analyze_with_mcp_agent')
    @patch('app.main.ensure_session_exists')
    @patch('app.main.settings.enable_mcp_agent', True)
    def test_agent_path_end_to_end_with_entities(
        self,
        mock_ensure_session,
        mock_agent_task,
        mock_worker_check,
        mock_extractor_getter
    ):
        """Test complete agent path flow with entities."""
        # Setup
        session_id = str(uuid.uuid4())
        
        # Mock entity extraction - with entities
        mock_extractor = Mock()
        mock_entities = ExtractedEntities(
            phones=[
                {
                    'value': '+18005551234',
                    'original': '1-800-555-1234',
                    'type': 'toll_free',
                    'country': 'US',
                    'valid': True,
                    'is_possible': True
                }
            ],
            urls=[
                {
                    'value': 'https://suspicious-site.com',
                    'original': 'suspicious-site.com',
                    'domain': 'suspicious-site.com',
                    'is_shortened': False
                }
            ],
            emails=[],
            payments=[],
            amounts=[]
        )
        mock_extractor.extract.return_value = mock_entities
        mock_extractor_getter.return_value = mock_extractor
        
        # Mock worker available
        mock_worker_check.return_value = True
        
        # Mock session
        mock_ensure_session.return_value = {'id': session_id}
        
        # Mock agent task
        mock_task_result = Mock()
        mock_task_result.id = 'agent-task-123'
        mock_agent_task.apply_async.return_value = mock_task_result
        
        # Execute
        response = self.client.post(
            "/scan-image",
            data={
                "session_id": session_id,
                "ocr_text": "Call 1-800-555-1234 or visit suspicious-site.com"
            }
        )
        
        # Verify
        assert response.status_code == 200
        data = response.json()
        
        # Should be agent response
        assert data['type'] == 'agent'
        assert 'task_id' in data
        assert 'ws_url' in data
        assert 'estimated_time' in data
        assert data['entities_found'] == 2  # 1 phone + 1 URL
        
        # Verify entity extraction was called
        mock_extractor.extract.assert_called_once()
        
        # Verify worker check was called
        assert mock_worker_check.called
        
        # Verify agent task was enqueued
        mock_agent_task.apply_async.assert_called_once()
    
    @patch('app.main.get_entity_extractor')
    @patch('app.main._check_worker_availability')
    @patch('app.main.analyze_image')
    @patch('app.main.insert_scan_result')
    @patch('app.main.ensure_session_exists')
    @patch('app.main.settings.enable_mcp_agent', True)
    def test_fallback_to_fast_path_when_worker_down(
        self,
        mock_ensure_session,
        mock_db,
        mock_gemini,
        mock_worker_check,
        mock_extractor_getter
    ):
        """Test fallback to fast path when worker is down."""
        # Setup
        session_id = str(uuid.uuid4())
        
        # Mock entity extraction - with entities (should trigger agent)
        mock_extractor = Mock()
        mock_entities = ExtractedEntities(
            phones=[
                {
                    'value': '+18005551234',
                    'original': '1-800-555-1234',
                    'type': 'toll_free',
                    'country': 'US',
                    'valid': True,
                    'is_possible': True
                }
            ],
            urls=[],
            emails=[],
            payments=[],
            amounts=[]
        )
        mock_extractor.extract.return_value = mock_entities
        mock_extractor_getter.return_value = mock_extractor
        
        # Mock worker unavailable (triggers fallback)
        mock_worker_check.return_value = False
        
        # Mock Gemini response (fast path)
        mock_gemini.return_value = {
            'risk_level': 'medium',
            'confidence': 0.7,
            'category': 'unknown',
            'explanation': 'Contains phone number'
        }
        
        # Mock DB
        mock_ensure_session.return_value = {'id': session_id}
        mock_db.return_value = {'id': 'result-id'}
        
        # Execute
        response = self.client.post(
            "/scan-image",
            data={
                "session_id": session_id,
                "ocr_text": "Call 1-800-555-1234 for support"
            }
        )
        
        # Verify
        assert response.status_code == 200
        data = response.json()
        
        # Should fall back to simple response
        assert data['type'] == 'simple'
        assert 'result' in data
        
        # Verify Gemini was called (fast path)
        mock_gemini.assert_called_once()


class TestMixedScenarios:
    """Test mixed scenarios and edge cases."""
    
    def setup_method(self):
        """Setup test client."""
        self.client = TestClient(app)
    
    @patch('app.main.get_entity_extractor')
    @patch('app.main.analyze_image')
    @patch('app.main.insert_scan_result')
    @patch('app.main.ensure_session_exists')
    def test_large_ocr_text_fast_path(
        self,
        mock_ensure_session,
        mock_db,
        mock_gemini,
        mock_extractor_getter
    ):
        """Test fast path with large OCR text (close to 5000 char limit)."""
        # Setup
        session_id = str(uuid.uuid4())
        large_text = "Generic text. " * 300  # ~4500 chars
        
        # Mock entity extraction - no entities
        mock_extractor = Mock()
        mock_entities = ExtractedEntities(
            phones=[],
            urls=[],
            emails=[],
            payments=[],
            amounts=[]
        )
        mock_extractor.extract.return_value = mock_entities
        mock_extractor_getter.return_value = mock_extractor
        
        # Mock Gemini response
        mock_gemini.return_value = {
            'risk_level': 'low',
            'confidence': 0.8,
            'category': 'unknown',
            'explanation': 'No scam detected'
        }
        
        # Mock DB
        mock_ensure_session.return_value = {'id': session_id}
        mock_db.return_value = {'id': 'result-id'}
        
        # Execute
        response = self.client.post(
            "/scan-image",
            data={
                "session_id": session_id,
                "ocr_text": large_text
            }
        )
        
        # Verify
        assert response.status_code == 200
        data = response.json()
        assert data['type'] == 'simple'
    
    @patch('app.main.get_entity_extractor')
    @patch('app.main._check_worker_availability')
    @patch('app.main.analyze_with_mcp_agent')
    @patch('app.main.ensure_session_exists')
    @patch('app.main.settings.enable_mcp_agent', True)
    def test_multiple_entity_types_agent_path(
        self,
        mock_ensure_session,
        mock_agent_task,
        mock_worker_check,
        mock_extractor_getter
    ):
        """Test agent path with multiple entity types."""
        # Setup
        session_id = str(uuid.uuid4())
        
        # Mock entity extraction - multiple entity types
        mock_extractor = Mock()
        mock_entities = ExtractedEntities(
            phones=[
                {
                    'value': '+18005551234',
                    'original': '1-800-555-1234',
                    'type': 'toll_free',
                    'country': 'US',
                    'valid': True,
                    'is_possible': True
                }
            ],
            urls=[
                {
                    'value': 'https://scam-site.com',
                    'original': 'scam-site.com',
                    'domain': 'scam-site.com',
                    'is_shortened': False
                }
            ],
            emails=[
                {
                    'value': 'support@scam-site.com',
                    'original': 'support@scam-site.com',
                    'domain': 'scam-site.com'
                }
            ],
            payments=[
                {
                    'type': 'bitcoin',
                    'value': '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa',
                    'context': 'Send Bitcoin to 1A1zP1...'
                }
            ],
            amounts=[
                {
                    'amount': '5000',
                    'amount_numeric': 5000.0,
                    'currency': 'USD',
                    'original': '$5000'
                }
            ]
        )
        mock_extractor.extract.return_value = mock_entities
        mock_extractor_getter.return_value = mock_extractor
        
        # Mock worker available
        mock_worker_check.return_value = True
        
        # Mock session
        mock_ensure_session.return_value = {'id': session_id}
        
        # Mock agent task
        mock_task_result = Mock()
        mock_task_result.id = 'complex-task-456'
        mock_agent_task.apply_async.return_value = mock_task_result
        
        # Execute
        response = self.client.post(
            "/scan-image",
            data={
                "session_id": session_id,
                "ocr_text": (
                    "Contact us at support@scam-site.com or call 1-800-555-1234. "
                    "Visit scam-site.com and send $5000 to Bitcoin address "
                    "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
                )
            }
        )
        
        # Verify
        assert response.status_code == 200
        data = response.json()
        
        # Should route to agent due to entities
        assert data['type'] == 'agent'
        assert data['entities_found'] == 5  # 1 phone + 1 URL + 1 email + 1 payment + 1 amount
        
        # Verify agent task was enqueued with correct data
        call_args = mock_agent_task.apply_async.call_args
        assert call_args is not None


class TestPerformanceMetrics:
    """Test performance-related scenarios."""
    
    def setup_method(self):
        """Setup test client."""
        self.client = TestClient(app)
    
    @patch('app.main.get_entity_extractor')
    @patch('app.main.analyze_image')
    @patch('app.main.insert_scan_result')
    @patch('app.main.ensure_session_exists')
    def test_entity_extraction_logs_timing(
        self,
        mock_ensure_session,
        mock_db,
        mock_gemini,
        mock_extractor_getter
    ):
        """Test that entity extraction timing is logged."""
        import logging
        from unittest.mock import MagicMock
        
        # Setup
        session_id = str(uuid.uuid4())
        
        # Mock entity extraction
        mock_extractor = Mock()
        mock_entities = ExtractedEntities(
            phones=[],
            urls=[],
            emails=[],
            payments=[],
            amounts=[]
        )
        mock_extractor.extract.return_value = mock_entities
        mock_extractor_getter.return_value = mock_extractor
        
        # Mock Gemini
        mock_gemini.return_value = {
            'risk_level': 'low',
            'confidence': 0.8,
            'category': 'unknown',
            'explanation': 'No scam'
        }
        
        # Mock DB
        mock_ensure_session.return_value = {'id': session_id}
        mock_db.return_value = {'id': 'result-id'}
        
        # Capture logs
        with patch('app.main.logger') as mock_logger:
            # Execute
            response = self.client.post(
                "/scan-image",
                data={
                    "session_id": session_id,
                    "ocr_text": "Test text"
                }
            )
            
            # Verify
            assert response.status_code == 200
            
            # Check that timing was logged
            log_calls = [str(call) for call in mock_logger.info.call_args_list]
            timing_logged = any('time_ms=' in call for call in log_calls)
            assert timing_logged, "Entity extraction timing should be logged"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])

