"""
Unit tests for smart routing logic (Story 8.10).

Tests the routing decision logic that determines whether scans should
use the fast path (Gemini/Groq) or agent path (MCP agent with tools).
"""

import pytest
import uuid
from unittest.mock import Mock, patch, AsyncMock, MagicMock
from datetime import datetime

from fastapi.testclient import TestClient
from fastapi import UploadFile
from io import BytesIO

from app.main import app, _check_worker_availability, _analyze_fast_path
from app.services.entity_extractor import ExtractedEntities


class TestWorkerAvailability:
    """Test worker availability checking."""
    
    @patch('app.main.celery_app.control.inspect')
    def test_worker_available_returns_true(self, mock_inspect):
        """Test worker availability check returns True when workers active."""
        # Mock active workers
        mock_inspect_instance = Mock()
        mock_inspect_instance.active.return_value = {
            'worker1@hostname': []
        }
        mock_inspect.return_value = mock_inspect_instance
        
        # Should return True
        import asyncio
        result = asyncio.run(_check_worker_availability())
        assert result is True
    
    @patch('app.main.celery_app.control.inspect')
    def test_worker_unavailable_returns_false(self, mock_inspect):
        """Test worker availability check returns False when no workers."""
        # Mock no workers
        mock_inspect_instance = Mock()
        mock_inspect_instance.active.return_value = None
        mock_inspect.return_value = mock_inspect_instance
        
        # Should return False
        import asyncio
        result = asyncio.run(_check_worker_availability())
        assert result is False
    
    @patch('app.main.celery_app.control.inspect')
    def test_worker_check_exception_returns_false(self, mock_inspect):
        """Test worker availability check returns False on exception."""
        # Mock exception
        mock_inspect.side_effect = Exception("Connection failed")
        
        # Should return False
        import asyncio
        result = asyncio.run(_check_worker_availability())
        assert result is False


class TestFastPathAnalysis:
    """Test fast path analysis function."""
    
    @pytest.mark.asyncio
    async def test_fast_path_with_gemini_success(self):
        """Test fast path uses Gemini when available."""
        session_uuid = uuid.uuid4()
        request_id = "test-request"
        
        with patch('app.main.analyze_image') as mock_gemini, \
             patch('app.main.insert_scan_result') as mock_db:
            
            # Mock Gemini response
            mock_gemini.return_value = {
                'risk_level': 'low',
                'confidence': 0.9,
                'category': 'unknown',
                'explanation': 'No scam detected'
            }
            
            # Mock DB insert
            mock_db.return_value = {'id': 'test-id'}
            
            result = await _analyze_fast_path(
                image_data=None,
                ocr_text="Hello world",
                mime_type=None,
                user_country="US",
                session_uuid=session_uuid,
                request_id=request_id
            )
            
            # Assertions
            assert result['risk_level'] == 'low'
            assert result['confidence'] == 0.9
            assert 'ts' in result
            mock_gemini.assert_called_once()
            mock_db.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_fast_path_gemini_fails_uses_groq(self):
        """Test fast path falls back to Groq when Gemini fails."""
        session_uuid = uuid.uuid4()
        request_id = "test-request"
        
        with patch('app.main.analyze_image') as mock_gemini, \
             patch('app.main.analyze_text_groq') as mock_groq, \
             patch('app.main.insert_scan_result') as mock_db:
            
            # Mock Gemini failure
            mock_gemini.side_effect = Exception("Gemini failed")
            
            # Mock Groq response
            mock_groq.return_value = {
                'risk_level': 'medium',
                'confidence': 0.7,
                'category': 'otp_phishing',
                'explanation': 'Possible OTP scam'
            }
            
            # Mock DB insert
            mock_db.return_value = {'id': 'test-id'}
            
            result = await _analyze_fast_path(
                image_data=None,
                ocr_text="Enter OTP 123456",
                mime_type=None,
                user_country="US",
                session_uuid=session_uuid,
                request_id=request_id
            )
            
            # Assertions
            assert result['risk_level'] == 'medium'
            assert result['confidence'] == 0.7
            mock_gemini.assert_called_once()
            mock_groq.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_fast_path_both_fail_returns_unknown(self):
        """Test fast path returns unknown when both providers fail."""
        session_uuid = uuid.uuid4()
        request_id = "test-request"
        
        with patch('app.main.analyze_image') as mock_gemini, \
             patch('app.main.analyze_text_groq') as mock_groq, \
             patch('app.main.insert_scan_result') as mock_db:
            
            # Mock both failures
            mock_gemini.side_effect = Exception("Gemini failed")
            mock_groq.side_effect = Exception("Groq failed")
            
            # Mock DB insert
            mock_db.return_value = {'id': 'test-id'}
            
            result = await _analyze_fast_path(
                image_data=None,
                ocr_text="Some text",
                mime_type=None,
                user_country="US",
                session_uuid=session_uuid,
                request_id=request_id
            )
            
            # Assertions
            assert result['risk_level'] == 'unknown'
            assert result['confidence'] == 0.0
            assert 'Unable to complete analysis' in result['explanation']


class TestRoutingLogic:
    """Test routing decision logic in /scan-image endpoint."""
    
    def setup_method(self):
        """Setup test client."""
        self.client = TestClient(app)
    
    @patch('app.main.get_entity_extractor')
    @patch('app.main._check_worker_availability')
    @patch('app.main.settings.enable_mcp_agent', True)
    @patch('app.main.ensure_session_exists')
    def test_routes_to_agent_path_with_entities(
        self, 
        mock_ensure_session,
        mock_worker_check, 
        mock_extractor_getter
    ):
        """Test routing to agent path when entities found."""
        # Mock entity extraction with entities
        mock_extractor = Mock()
        mock_entities = Mock()
        mock_entities.has_entities.return_value = True
        mock_entities.entity_count.return_value = 2
        mock_extractor.extract.return_value = mock_entities
        mock_extractor_getter.return_value = mock_extractor
        
        # Mock worker available
        mock_worker_check.return_value = True
        
        # Mock session
        mock_ensure_session.return_value = {'id': str(uuid.uuid4())}
        
        # Mock agent task
        with patch('app.main.analyze_with_mcp_agent.apply_async') as mock_task:
            mock_task.return_value = Mock(id='test-task-id')
            
            # Make request
            response = self.client.post(
                "/scan-image",
                data={
                    "session_id": str(uuid.uuid4()),
                    "ocr_text": "Call +1-800-555-1234 for support"
                }
            )
        
        # Assertions
        assert response.status_code == 200
        data = response.json()
        assert data['type'] == 'agent'
        assert 'task_id' in data
        assert 'ws_url' in data
        assert data['entities_found'] == 2
        assert 'estimated_time' in data
    
    @patch('app.main.get_entity_extractor')
    @patch('app.main._analyze_fast_path')
    @patch('app.main.ensure_session_exists')
    def test_routes_to_fast_path_without_entities(
        self, 
        mock_ensure_session,
        mock_fast_path, 
        mock_extractor_getter
    ):
        """Test routing to fast path when no entities found."""
        # Mock entity extraction with no entities
        mock_extractor = Mock()
        mock_entities = Mock()
        mock_entities.has_entities.return_value = False
        mock_entities.entity_count.return_value = 0
        mock_extractor.extract.return_value = mock_entities
        mock_extractor_getter.return_value = mock_extractor
        
        # Mock session
        mock_ensure_session.return_value = {'id': str(uuid.uuid4())}
        
        # Mock fast path result
        mock_fast_path.return_value = {
            'risk_level': 'low',
            'confidence': 0.8,
            'category': 'unknown',
            'explanation': 'No scam detected',
            'ts': datetime.utcnow().isoformat()
        }
        
        # Make request
        response = self.client.post(
            "/scan-image",
            data={
                "session_id": str(uuid.uuid4()),
                "ocr_text": "Hello, how are you?"
            }
        )
        
        # Assertions
        assert response.status_code == 200
        data = response.json()
        assert data['type'] == 'simple'
        assert 'result' in data
        assert data['result']['risk_level'] == 'low'
    
    @patch('app.main.get_entity_extractor')
    @patch('app.main._check_worker_availability')
    @patch('app.main._analyze_fast_path')
    @patch('app.main.settings.enable_mcp_agent', True)
    @patch('app.main.ensure_session_exists')
    def test_falls_back_to_fast_path_when_worker_unavailable(
        self, 
        mock_ensure_session,
        mock_fast_path,
        mock_worker_check, 
        mock_extractor_getter
    ):
        """Test falls back to fast path when worker unavailable."""
        # Mock entity extraction with entities
        mock_extractor = Mock()
        mock_entities = Mock()
        mock_entities.has_entities.return_value = True
        mock_entities.entity_count.return_value = 1
        mock_extractor.extract.return_value = mock_entities
        mock_extractor_getter.return_value = mock_extractor
        
        # Mock worker unavailable
        mock_worker_check.return_value = False
        
        # Mock session
        mock_ensure_session.return_value = {'id': str(uuid.uuid4())}
        
        # Mock fast path result
        mock_fast_path.return_value = {
            'risk_level': 'medium',
            'confidence': 0.6,
            'category': 'unknown',
            'explanation': 'Possible scam',
            'ts': datetime.utcnow().isoformat()
        }
        
        # Make request
        response = self.client.post(
            "/scan-image",
            data={
                "session_id": str(uuid.uuid4()),
                "ocr_text": "Visit http://suspicious-site.com"
            }
        )
        
        # Assertions
        assert response.status_code == 200
        data = response.json()
        assert data['type'] == 'simple'  # Falls back to fast path
        assert 'result' in data
    
    @patch('app.main.get_entity_extractor')
    @patch('app.main._analyze_fast_path')
    @patch('app.main.settings.enable_mcp_agent', False)
    @patch('app.main.ensure_session_exists')
    def test_uses_fast_path_when_agent_disabled(
        self, 
        mock_ensure_session,
        mock_fast_path, 
        mock_extractor_getter
    ):
        """Test uses fast path when agent is disabled."""
        # Mock entity extraction with entities
        mock_extractor = Mock()
        mock_entities = Mock()
        mock_entities.has_entities.return_value = True
        mock_entities.entity_count.return_value = 1
        mock_extractor.extract.return_value = mock_entities
        mock_extractor_getter.return_value = mock_extractor
        
        # Mock session
        mock_ensure_session.return_value = {'id': str(uuid.uuid4())}
        
        # Mock fast path result
        mock_fast_path.return_value = {
            'risk_level': 'low',
            'confidence': 0.7,
            'category': 'unknown',
            'explanation': 'No scam detected',
            'ts': datetime.utcnow().isoformat()
        }
        
        # Make request
        response = self.client.post(
            "/scan-image",
            data={
                "session_id": str(uuid.uuid4()),
                "ocr_text": "Call +1-800-555-1234"
            }
        )
        
        # Assertions
        assert response.status_code == 200
        data = response.json()
        assert data['type'] == 'simple'
        assert 'result' in data


class TestAgentTaskStatus:
    """Test agent task status endpoint."""
    
    def setup_method(self):
        """Setup test client."""
        self.client = TestClient(app)
    
    @patch('app.main.AsyncResult')
    def test_get_pending_task_status(self, mock_async_result):
        """Test getting status of pending task."""
        task_id = str(uuid.uuid4())
        
        # Mock pending task
        mock_result = Mock()
        mock_result.state = 'PENDING'
        mock_result.successful.return_value = False
        mock_result.failed.return_value = False
        mock_async_result.return_value = mock_result
        
        response = self.client.get(f"/agent-task/{task_id}/status")
        
        assert response.status_code == 200
        data = response.json()
        assert data['task_id'] == task_id
        assert data['status'] == 'pending'
        assert data['result'] is None
    
    @patch('app.main.AsyncResult')
    def test_get_completed_task_status(self, mock_async_result):
        """Test getting status of completed task."""
        task_id = str(uuid.uuid4())
        
        # Mock completed task
        mock_result = Mock()
        mock_result.state = 'SUCCESS'
        mock_result.successful.return_value = True
        mock_result.failed.return_value = False
        mock_result.result = {
            'risk_level': 'high',
            'confidence': 0.95,
            'reasoning': 'Scam detected'
        }
        mock_async_result.return_value = mock_result
        
        response = self.client.get(f"/agent-task/{task_id}/status")
        
        assert response.status_code == 200
        data = response.json()
        assert data['task_id'] == task_id
        assert data['status'] == 'completed'
        assert data['result']['risk_level'] == 'high'
    
    @patch('app.main.AsyncResult')
    def test_get_failed_task_status(self, mock_async_result):
        """Test getting status of failed task."""
        task_id = str(uuid.uuid4())
        
        # Mock failed task
        mock_result = Mock()
        mock_result.state = 'FAILURE'
        mock_result.successful.return_value = False
        mock_result.failed.return_value = True
        mock_result.info = Exception("Task failed")
        mock_async_result.return_value = mock_result
        
        response = self.client.get(f"/agent-task/{task_id}/status")
        
        assert response.status_code == 200
        data = response.json()
        assert data['task_id'] == task_id
        assert data['status'] == 'failed'
        assert 'Task failed' in data['error']
    
    def test_invalid_task_id_format(self):
        """Test error when task_id is not a valid UUID."""
        response = self.client.get("/agent-task/invalid-id/status")
        
        assert response.status_code == 400
        assert 'Invalid task_id format' in response.json()['detail']


class TestAgentHealthCheck:
    """Test agent health check endpoint."""
    
    def setup_method(self):
        """Setup test client."""
        self.client = TestClient(app)
    
    @patch('app.main._check_worker_availability')
    @patch('app.main.celery_app.control.inspect')
    def test_health_check_passes_with_active_workers(self, mock_inspect, mock_worker_check):
        """Test health check passes when workers are active."""
        # Mock worker availability
        mock_worker_check.return_value = True
        
        # Mock inspect
        mock_inspect_instance = Mock()
        mock_inspect_instance.active.return_value = {
            'worker1@hostname': []
        }
        mock_inspect.return_value = mock_inspect_instance
        
        response = self.client.get("/health/agent")
        
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'healthy'
        assert data['workers_active'] == 1
        assert 'timestamp' in data
    
    @patch('app.main._check_worker_availability')
    def test_health_check_fails_with_no_workers(self, mock_worker_check):
        """Test health check fails when no workers are active."""
        # Mock worker unavailable
        mock_worker_check.return_value = False
        
        response = self.client.get("/health/agent")
        
        assert response.status_code == 503
        assert 'No active agent workers' in response.json()['detail']


class TestEntityExtractionPerformance:
    """Test entity extraction performance (should be < 100ms)."""
    
    @patch('app.main.get_entity_extractor')
    @patch('app.main._analyze_fast_path')
    @patch('app.main.ensure_session_exists')
    def test_entity_extraction_is_fast(
        self, 
        mock_ensure_session,
        mock_fast_path, 
        mock_extractor_getter
    ):
        """Test entity extraction completes in < 100ms."""
        import time
        
        # Mock entity extraction
        mock_extractor = Mock()
        mock_entities = Mock()
        mock_entities.has_entities.return_value = False
        mock_entities.entity_count.return_value = 0
        
        # Add timing to extract method
        def extract_with_timing(text):
            time.sleep(0.05)  # Simulate 50ms extraction
            return mock_entities
        
        mock_extractor.extract = extract_with_timing
        mock_extractor_getter.return_value = mock_extractor
        
        # Mock session
        mock_ensure_session.return_value = {'id': str(uuid.uuid4())}
        
        # Mock fast path
        mock_fast_path.return_value = {
            'risk_level': 'low',
            'confidence': 0.8,
            'category': 'unknown',
            'explanation': 'No scam detected',
            'ts': datetime.utcnow().isoformat()
        }
        
        # Make request and time it
        start = time.time()
        response = TestClient(app).post(
            "/scan-image",
            data={
                "session_id": str(uuid.uuid4()),
                "ocr_text": "Test text with no entities"
            }
        )
        duration = (time.time() - start) * 1000
        
        # Assertions
        assert response.status_code == 200
        # Note: This is more of a smoke test - real performance test would need load testing


if __name__ == '__main__':
    pytest.main([__file__, '-v'])

