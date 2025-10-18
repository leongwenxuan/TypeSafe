"""
Celery tasks for TypeSafe MCP agent.

This module contains all asynchronous tasks for agent orchestration.
"""

from app.agents.tasks.example_task import example_agent_task

__all__ = ['example_agent_task']

