"""Celery worker configuration for TypeSafe MCP agent."""

import os
from pathlib import Path
from celery import Celery
from celery.signals import task_prerun, task_postrun, task_failure
import logging
from dotenv import load_dotenv

# Load environment variables from .env file
env_path = Path(__file__).parent.parent.parent / '.env'
load_dotenv(env_path)

# Configure logging
logger = logging.getLogger(__name__)

# Initialize Celery app
celery_app = Celery(
    'typesafe_agent',
    broker=os.getenv('CELERY_BROKER_URL', 'redis://localhost:6379/0'),
    backend=os.getenv('CELERY_RESULT_BACKEND', 'redis://localhost:6379/1'),
    include=['app.agents.tasks']
)

# Celery configuration
celery_app.conf.update(
    # Serialization
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    
    # Timezone
    timezone='UTC',
    enable_utc=True,
    
    # Task execution
    task_track_started=True,
    task_time_limit=60,  # 60 second hard limit
    task_soft_time_limit=55,  # 55 second soft limit (raises exception)
    task_acks_late=True,  # Acknowledge after task completes (prevents loss on crash)
    worker_prefetch_multiplier=1,  # Disable prefetching for better task distribution
    
    # Result backend
    result_expires=3600,  # Results expire after 1 hour
    result_extended=True,  # Store additional metadata
    
    # Retry configuration
    task_default_max_retries=3,
    task_default_retry_delay=2,  # 2 seconds base delay
    
    # Worker configuration
    worker_max_tasks_per_child=1000,  # Restart worker after 1000 tasks (prevent memory leaks)
    worker_disable_rate_limits=False,
    
    # Broker configuration
    broker_connection_retry_on_startup=True,
    broker_connection_retry=True,
    broker_connection_max_retries=10,
    
    # Task imports
    imports=['app.agents.mcp_agent', 'app.agents.tasks'],
)

# Signal handlers for logging
@task_prerun.connect
def task_prerun_handler(sender=None, task_id=None, task=None, args=None, kwargs=None, **extra):
    """Log when task starts."""
    logger.info(f"Task starting: {task.name} [id={task_id}]")

@task_postrun.connect
def task_postrun_handler(sender=None, task_id=None, task=None, retval=None, state=None, **extra):
    """Log when task completes."""
    logger.info(f"Task completed: {task.name} [id={task_id}] [state={state}]")

@task_failure.connect
def task_failure_handler(sender=None, task_id=None, exception=None, traceback=None, **extra):
    """Log when task fails."""
    logger.error(f"Task failed: {sender.name} [id={task_id}] [error={str(exception)}]", 
                 exc_info=True)

# Auto-discover tasks
celery_app.autodiscover_tasks(['app.agents.tasks'])

