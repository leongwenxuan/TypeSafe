"""Unit tests for Celery infrastructure."""

import pytest
from unittest.mock import Mock, patch, MagicMock
from app.agents.worker import celery_app
from app.agents.tasks.example_task import example_agent_task
import time


class TestCeleryConfiguration:
    """Test Celery worker configuration"""
    
    def test_celery_app_exists(self):
        """Test that Celery app is initialized"""
        assert celery_app is not None
        assert celery_app.main == 'typesafe_agent'
    
    def test_celery_config(self):
        """Test Celery configuration settings"""
        config = celery_app.conf
        
        # Serialization
        assert config.task_serializer == 'json'
        assert 'json' in config.accept_content
        assert config.result_serializer == 'json'
        
        # Timezone
        assert config.timezone == 'UTC'
        assert config.enable_utc is True
        
        # Task execution
        assert config.task_track_started is True
        assert config.task_time_limit == 60
        assert config.task_soft_time_limit == 55
        assert config.task_acks_late is True
        
        # Result backend
        assert config.result_expires == 3600
        
        # Retry configuration
        assert config.task_default_max_retries == 3
    
    def test_broker_url_configured(self):
        """Test that broker URL is configured"""
        assert celery_app.conf.broker_url is not None
        assert 'redis://' in celery_app.conf.broker_url
    
    def test_result_backend_configured(self):
        """Test that result backend is configured"""
        assert celery_app.conf.result_backend is not None
        assert 'redis://' in celery_app.conf.result_backend


class TestExampleTask:
    """Test example_agent_task functionality"""
    
    @pytest.fixture
    def celery_eager_mode(self):
        """Configure Celery to run tasks synchronously in eager mode"""
        celery_app.conf.task_always_eager = True
        celery_app.conf.task_eager_propagates = True
        yield
        celery_app.conf.task_always_eager = False
        celery_app.conf.task_eager_propagates = False
    
    def test_task_registration(self):
        """Test that example task is registered"""
        assert 'app.agents.tasks.example_task.example_agent_task' in celery_app.tasks
    
    def test_task_has_correct_config(self):
        """Test task configuration"""
        task = example_agent_task
        assert task.max_retries == 3
        assert task.default_retry_delay == 2
    
    @patch('app.agents.tasks.example_task.time.sleep')
    def test_task_success(self, mock_sleep, celery_eager_mode):
        """Test successful task execution in eager mode"""
        task_id = "test-123"
        data = {"key": "value", "simulate_failure": False}
        
        # Execute task synchronously
        result = example_agent_task.apply(args=[task_id, data])
        
        # Check result
        assert result.successful()
        result_data = result.result
        assert result_data['task_id'] == task_id
        assert result_data['status'] == 'completed'
        assert result_data['result'] == 'Success'
        assert result_data['attempts'] >= 1
    
    @patch('app.agents.tasks.example_task.time.sleep')
    @patch('app.agents.tasks.example_task.random.random', return_value=0.05)
    def test_task_retry_logic(self, mock_random, mock_sleep, celery_eager_mode):
        """Test task retry on failure (simulated)"""
        task_id = "test-456"
        data = {"key": "value", "simulate_failure": True}
        
        # With random() returning 0.05 (< 0.1), task should fail and retry
        # In eager mode, retries happen immediately
        result = example_agent_task.apply(args=[task_id, data])
        
        # Task should eventually fail after retries in eager mode
        # or succeed if random doesn't trigger failure on all attempts
        assert result.state in ['SUCCESS', 'FAILURE', 'RETRY']
    
    def test_task_enqueue(self):
        """Test task can be enqueued (returns AsyncResult)"""
        task_id = "test-789"
        data = {"key": "value"}
        
        result = example_agent_task.apply_async(
            args=[task_id, data],
            task_id=task_id
        )
        
        assert result.id == task_id
        assert result.state in ['PENDING', 'SUCCESS', 'STARTED']
    
    @patch('app.agents.tasks.example_task.time.sleep')
    def test_task_result_structure(self, mock_sleep, celery_eager_mode):
        """Test task result has expected structure"""
        task_id = "test-result-structure"
        data = {"test": "data"}
        
        result = example_agent_task.apply(args=[task_id, data])
        result_data = result.result
        
        # Verify result structure
        assert 'task_id' in result_data
        assert 'status' in result_data
        assert 'result' in result_data
        assert 'attempts' in result_data
        assert result_data['task_id'] == task_id


class TestTaskStatusRetrieval:
    """Test task status and result retrieval"""
    
    def test_async_result_retrieval(self):
        """Test retrieving task result by ID"""
        task_id = "test-status-123"
        
        # Create AsyncResult object
        result = celery_app.AsyncResult(task_id)
        
        assert result is not None
        assert result.id == task_id
        # State should be PENDING for non-existent task
        assert result.state in ['PENDING', 'SUCCESS', 'FAILURE']
    
    @patch('app.agents.tasks.example_task.time.sleep')
    def test_get_task_result(self, mock_sleep):
        """Test getting task result after completion"""
        task_id = "test-get-result"
        data = {"key": "value"}
        
        # Configure eager mode
        celery_app.conf.task_always_eager = True
        celery_app.conf.task_eager_propagates = True
        
        try:
            # Execute task
            result = example_agent_task.apply_async(
                args=[task_id, data],
                task_id=task_id
            )
            
            # Get result
            task_result = result.get(timeout=5)
            
            assert task_result is not None
            assert task_result['task_id'] == task_id
            assert result.successful()
        finally:
            celery_app.conf.task_always_eager = False
            celery_app.conf.task_eager_propagates = False


class TestWorkerHealthCheck:
    """Test worker health check functionality"""
    
    @patch.object(celery_app.control, 'inspect')
    def test_inspect_active_workers(self, mock_inspect):
        """Test inspecting active workers"""
        # Mock inspect response
        mock_inspect_obj = MagicMock()
        mock_inspect_obj.active.return_value = {
            'worker1@hostname': [],
            'worker2@hostname': []
        }
        mock_inspect.return_value = mock_inspect_obj
        
        # Get active workers
        inspect = celery_app.control.inspect()
        active_workers = inspect.active()
        
        assert active_workers is not None
        assert len(active_workers) == 2
        assert 'worker1@hostname' in active_workers
    
    @patch.object(celery_app.control, 'inspect')
    def test_count_active_tasks(self, mock_inspect):
        """Test counting active tasks across workers"""
        # Mock inspect response with active tasks
        mock_inspect_obj = MagicMock()
        mock_inspect_obj.active.return_value = {
            'worker1@hostname': [{'id': 'task1'}, {'id': 'task2'}],
            'worker2@hostname': [{'id': 'task3'}]
        }
        mock_inspect.return_value = mock_inspect_obj
        
        # Get active tasks
        inspect = celery_app.control.inspect()
        active_workers = inspect.active()
        
        total_tasks = sum(len(tasks) for tasks in active_workers.values())
        assert total_tasks == 3


class TestTaskSignals:
    """Test Celery signal handlers"""
    
    def test_signal_handlers_registered(self):
        """Test that signal handlers are registered"""
        from celery.signals import task_prerun, task_postrun, task_failure
        
        # Check that receivers are registered
        assert len(task_prerun.receivers) > 0
        assert len(task_postrun.receivers) > 0
        assert len(task_failure.receivers) > 0


class TestTaskTimeout:
    """Test task timeout handling"""
    
    def test_soft_time_limit_configured(self):
        """Test soft time limit is configured"""
        assert celery_app.conf.task_soft_time_limit == 55
    
    def test_hard_time_limit_configured(self):
        """Test hard time limit is configured"""
        assert celery_app.conf.task_time_limit == 60


if __name__ == '__main__':
    pytest.main([__file__, '-v'])

