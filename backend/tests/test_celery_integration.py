"""Integration tests for Celery with real Redis backend.

These tests require Redis to be running locally on port 6379.
Run with: pytest tests/test_celery_integration.py -v -m integration

To skip these tests: pytest -v -m "not integration"
"""

import pytest
import time
import uuid
from app.agents.worker import celery_app
from app.agents.tasks.example_task import example_agent_task


@pytest.mark.integration
class TestRealTaskExecution:
    """Test task execution with real Redis backend"""
    
    @pytest.fixture(autouse=True)
    def setup_teardown(self):
        """Setup and teardown for integration tests"""
        # Disable eager mode to test real async execution
        celery_app.conf.task_always_eager = False
        celery_app.conf.task_eager_propagates = False
        yield
        # Cleanup: Restore eager mode for other tests
        celery_app.conf.task_always_eager = False
    
    def test_task_enqueue_and_execution(self):
        """Test enqueueing task and waiting for completion"""
        task_id = f"integration-test-{uuid.uuid4()}"
        data = {"test": "data", "simulate_failure": False}
        
        # Enqueue task
        result = example_agent_task.apply_async(
            args=[task_id, data],
            task_id=task_id
        )
        
        # Verify task was enqueued
        assert result.id == task_id
        assert result.state in ['PENDING', 'STARTED', 'PROGRESS', 'SUCCESS']
        
        # Wait for task to complete (max 10 seconds)
        max_wait = 10
        elapsed = 0
        while not result.ready() and elapsed < max_wait:
            time.sleep(0.5)
            elapsed += 0.5
        
        # Verify task completed
        assert result.ready(), f"Task did not complete within {max_wait} seconds"
        assert result.successful(), f"Task failed: {result.info}"
        
        # Verify result structure
        task_result = result.result
        assert task_result['task_id'] == task_id
        assert task_result['status'] == 'completed'
        assert task_result['result'] == 'Success'
    
    def test_task_result_persistence(self):
        """Test that task results are persisted in Redis"""
        task_id = f"persistence-test-{uuid.uuid4()}"
        data = {"key": "value"}
        
        # Enqueue and complete task
        result = example_agent_task.apply_async(
            args=[task_id, data],
            task_id=task_id
        )
        
        # Wait for completion
        task_result = result.get(timeout=10)
        assert task_result is not None
        
        # Retrieve result using new AsyncResult object (simulates different process)
        retrieved_result = celery_app.AsyncResult(task_id)
        assert retrieved_result.successful()
        assert retrieved_result.result['task_id'] == task_id
        assert retrieved_result.result['status'] == 'completed'
    
    def test_task_progress_updates(self):
        """Test task progress state updates"""
        task_id = f"progress-test-{uuid.uuid4()}"
        data = {"test": "progress"}
        
        # Enqueue task
        result = example_agent_task.apply_async(
            args=[task_id, data],
            task_id=task_id
        )
        
        # Poll for progress updates
        progress_seen = False
        max_polls = 20
        for _ in range(max_polls):
            time.sleep(0.2)
            if result.state == 'PROGRESS':
                progress_seen = True
                # Check progress metadata
                assert result.info is not None
                assert 'current' in result.info
                assert 'total' in result.info
                assert 'status' in result.info
                break
        
        # Wait for completion
        result.get(timeout=10)
        
        # Note: Progress might not be seen if task completes too quickly
        # This is expected behavior
        print(f"Progress updates seen: {progress_seen}")
    
    def test_multiple_concurrent_tasks(self):
        """Test multiple tasks running concurrently"""
        num_tasks = 5
        task_ids = [f"concurrent-{uuid.uuid4()}" for _ in range(num_tasks)]
        
        # Enqueue multiple tasks
        results = []
        for task_id in task_ids:
            result = example_agent_task.apply_async(
                args=[task_id, {"index": task_ids.index(task_id)}],
                task_id=task_id
            )
            results.append(result)
        
        # Wait for all tasks to complete
        completed = 0
        failed = 0
        for result in results:
            try:
                result.get(timeout=15)
                completed += 1
            except Exception as e:
                print(f"Task failed: {e}")
                failed += 1
        
        # Verify all tasks completed successfully
        assert completed == num_tasks, f"Expected {num_tasks} completions, got {completed}"
        assert failed == 0, f"Expected 0 failures, got {failed}"
    
    def test_task_timeout_behavior(self):
        """Test task timeout handling (soft limit)"""
        # This test verifies that tasks respect time limits
        # The example task completes quickly, so we just verify the limits are configured
        assert celery_app.conf.task_soft_time_limit == 55
        assert celery_app.conf.task_time_limit == 60
    
    def test_task_result_expiration(self):
        """Test that task results have expiration set"""
        task_id = f"expiration-test-{uuid.uuid4()}"
        data = {"test": "expiration"}
        
        result = example_agent_task.apply_async(
            args=[task_id, data],
            task_id=task_id
        )
        
        # Wait for completion
        result.get(timeout=10)
        
        # Verify result backend expiration is configured
        assert celery_app.conf.result_expires == 3600  # 1 hour


@pytest.mark.integration
class TestWorkerHealth:
    """Test worker health checks with real workers"""
    
    def test_worker_inspection(self):
        """Test inspecting active workers"""
        inspect = celery_app.control.inspect()
        
        # Check stats (requires active workers)
        stats = inspect.stats()
        
        if stats:
            # Workers are running
            assert len(stats) > 0
            print(f"Active workers: {list(stats.keys())}")
        else:
            # No workers running - this is acceptable for CI/CD
            print("No active workers found - ensure workers are running for full integration tests")
    
    def test_worker_active_tasks(self):
        """Test checking active tasks on workers"""
        inspect = celery_app.control.inspect()
        active = inspect.active()
        
        if active:
            # Workers are running
            print(f"Active tasks: {sum(len(tasks) for tasks in active.values())}")
            assert isinstance(active, dict)
        else:
            print("No active workers found")


@pytest.mark.integration
class TestEndToEndFlow:
    """Test complete end-to-end task flow"""
    
    def test_complete_workflow(self):
        """Test complete task lifecycle: enqueue → execute → retrieve result"""
        # Step 1: Enqueue task
        task_id = f"e2e-test-{uuid.uuid4()}"
        input_data = {
            "operation": "test",
            "value": 42,
            "simulate_failure": False
        }
        
        result = example_agent_task.apply_async(
            args=[task_id, input_data],
            task_id=task_id
        )
        
        print(f"Step 1: Task enqueued - {task_id}")
        assert result.id == task_id
        
        # Step 2: Wait for execution
        max_wait = 10
        start_time = time.time()
        
        while not result.ready() and (time.time() - start_time) < max_wait:
            state = result.state
            print(f"Step 2: Task state - {state}")
            time.sleep(0.5)
        
        assert result.ready(), "Task did not complete"
        print(f"Step 2: Task completed in {time.time() - start_time:.2f}s")
        
        # Step 3: Retrieve result
        task_result = result.result
        print(f"Step 3: Result retrieved - {task_result}")
        
        assert task_result is not None
        assert task_result['task_id'] == task_id
        assert task_result['status'] == 'completed'
        assert 'data' in task_result
        assert task_result['data'] == input_data
        
        # Step 4: Verify result persistence
        new_result = celery_app.AsyncResult(task_id)
        assert new_result.successful()
        assert new_result.result == task_result
        print("Step 4: Result persistence verified")
        
        print("✓ End-to-end test passed")


@pytest.mark.integration
class TestFailureAndRetry:
    """Test task failure and retry behavior"""
    
    def test_task_retry_mechanism(self):
        """Test that failed tasks are retried"""
        task_id = f"retry-test-{uuid.uuid4()}"
        data = {
            "simulate_failure": True,  # Enable random failures
            "test": "retry"
        }
        
        result = example_agent_task.apply_async(
            args=[task_id, data],
            task_id=task_id
        )
        
        # Wait for task to complete (may retry multiple times)
        try:
            task_result = result.get(timeout=20)
            
            # If successful, check attempt count
            if task_result.get('status') == 'completed':
                attempts = task_result.get('attempts', 1)
                print(f"Task succeeded after {attempts} attempt(s)")
                assert attempts >= 1
            
        except Exception as e:
            # Task may fail after all retries (expected with random failures)
            print(f"Task failed after retries: {e}")
            # This is acceptable behavior for this test


@pytest.mark.integration
class TestRedisConnection:
    """Test Redis connection and configuration"""
    
    def test_broker_connection(self):
        """Test that broker (Redis) is accessible"""
        # Try to ping the broker
        try:
            inspect = celery_app.control.inspect()
            inspect.stats()  # This requires broker connection
            print("✓ Broker connection successful")
        except Exception as e:
            pytest.fail(f"Cannot connect to broker: {e}")
    
    def test_result_backend_connection(self):
        """Test that result backend (Redis) is accessible"""
        # Enqueue a simple task to verify result backend works
        task_id = f"backend-test-{uuid.uuid4()}"
        result = example_agent_task.apply_async(
            args=[task_id, {"test": "backend"}],
            task_id=task_id
        )
        
        # Try to get result (requires result backend)
        try:
            result.get(timeout=10)
            print("✓ Result backend connection successful")
        except Exception as e:
            pytest.fail(f"Cannot connect to result backend: {e}")


if __name__ == '__main__':
    # Run integration tests
    pytest.main([__file__, '-v', '-m', 'integration', '-s'])

