"""Example Celery task for testing infrastructure."""

from app.agents.worker import celery_app
from celery import Task
from celery.exceptions import SoftTimeLimitExceeded
import time
import random
import logging

logger = logging.getLogger(__name__)

@celery_app.task(bind=True, max_retries=3, default_retry_delay=2)
def example_agent_task(self: Task, task_id: str, data: dict) -> dict:
    """
    Example task demonstrating Celery infrastructure.
    
    This task simulates a long-running agent operation with:
    - Progress tracking
    - Random failure simulation
    - Exponential backoff retry logic
    - Timeout handling
    
    Args:
        task_id: Unique identifier for this task
        data: Input data dictionary
    
    Returns:
        dict: Result dictionary with task_id, status, result, and attempts
    
    Raises:
        self.retry: If task needs to be retried
        SoftTimeLimitExceeded: If task exceeds soft time limit
    """
    try:
        logger.info(f"Processing task {task_id} with data: {data}")
        
        # Update task state to show progress
        self.update_state(
            state='PROGRESS',
            meta={'current': 0, 'total': 100, 'status': 'Starting...'}
        )
        
        # Simulate processing with progress updates
        for i in range(3):
            time.sleep(0.5)  # Simulate work
            progress = int((i + 1) / 3 * 100)
            self.update_state(
                state='PROGRESS',
                meta={'current': progress, 'total': 100, 'status': f'Processing step {i+1}/3'}
            )
        
        # Simulate random failure (10% chance) for testing retry logic
        if data.get('simulate_failure') and random.random() < 0.1:
            raise ValueError("Simulated random failure for testing")
        
        logger.info(f"Task {task_id} completed successfully")
        
        return {
            "task_id": task_id,
            "status": "completed",
            "result": "Success",
            "attempts": self.request.retries + 1,
            "data": data
        }
    
    except SoftTimeLimitExceeded:
        logger.error(f"Task {task_id} exceeded time limit")
        return {
            "task_id": task_id,
            "status": "timeout",
            "result": "Task exceeded time limit",
            "attempts": self.request.retries + 1
        }
    
    except Exception as exc:
        # Retry with exponential backoff
        logger.warning(f"Task {task_id} failed (attempt {self.request.retries + 1}/3): {exc}")
        
        # Don't retry if we've exhausted retries
        if self.request.retries >= self.max_retries:
            logger.error(f"Task {task_id} failed after {self.max_retries} retries")
            return {
                "task_id": task_id,
                "status": "failed",
                "result": str(exc),
                "attempts": self.request.retries + 1
            }
        
        # Retry with exponential backoff: 2s, 4s, 8s
        raise self.retry(exc=exc, countdown=2 ** self.request.retries)

