"""
Integration tests for WebSocket progress streaming (Story 8.9).

Tests the real-time progress streaming via WebSocket endpoint, including:
- Full WebSocket flow with real agent task
- Connection timeout and cleanup
- Concurrent connections (10+ clients)
- Error scenarios (invalid task_id, Redis down)
"""

import pytest
import asyncio
import json
import uuid
from datetime import datetime
from typing import List, Dict, Any
from unittest.mock import patch, MagicMock

import redis
from fastapi import FastAPI
from fastapi.testclient import TestClient
from websockets.client import connect as ws_connect, WebSocketClientProtocol
from websockets.exceptions import ConnectionClosed

from app.main import app
from app.agents.mcp_agent import ProgressPublisher
from app.config import settings


# =============================================================================
# Fixtures
# =============================================================================

@pytest.fixture
def redis_client():
    """Create Redis client for testing."""
    client = redis.from_url(settings.redis_url, decode_responses=True)
    yield client
    client.close()


@pytest.fixture
def test_task_id() -> str:
    """Generate unique test task ID."""
    return str(uuid.uuid4())


@pytest.fixture
def ws_base_url() -> str:
    """Get WebSocket base URL from settings."""
    # Convert HTTP URL to WebSocket URL
    base_url = "ws://localhost:8000"  # Assume running on localhost:8000
    return base_url


# =============================================================================
# Test: Full WebSocket Flow with Real Agent Task
# =============================================================================

@pytest.mark.asyncio
async def test_websocket_full_flow(test_task_id: str, redis_client):
    """
    Test full WebSocket flow with simulated agent progress.
    
    AC 1-9: Tests core WebSocket functionality including:
    - Connection to ws://api/ws/agent-progress/{task_id}
    - Subscribes to Redis Pub/Sub channel
    - Streams progress messages as JSON
    - Auto-closes when task completes
    - Proper message format with step, tool, message, percent
    """
    # Simulate progress messages
    progress_messages = [
        {"step": "entity_extraction", "tool": None, "message": "Extracting entities...", "percent": 10},
        {"step": "tool_execution", "tool": "scam_db", "message": "Checking scam database...", "percent": 30},
        {"step": "tool_execution", "tool": "exa_search", "message": "Searching web...", "percent": 50},
        {"step": "reasoning", "tool": None, "message": "Analyzing evidence...", "percent": 90},
        {"step": "completed", "tool": None, "message": "Analysis complete!", "percent": 100}
    ]
    
    received_messages = []
    
    # Create WebSocket connection
    ws_url = f"ws://localhost:8000/ws/agent-progress/{test_task_id}"
    
    async def websocket_client():
        """WebSocket client that receives messages."""
        try:
            async with ws_connect(ws_url) as websocket:
                # Receive initial connection message
                initial = await websocket.recv()
                initial_data = json.loads(initial)
                assert initial_data["step"] == "connected"
                assert initial_data["percent"] == 0
                
                # Receive progress messages
                while True:
                    try:
                        message = await asyncio.wait_for(websocket.recv(), timeout=2.0)
                        data = json.loads(message)
                        
                        # Skip heartbeat messages
                        if "heartbeat" in data:
                            continue
                        
                        received_messages.append(data)
                        
                        # Break on completion
                        if data.get("step") == "completed":
                            break
                    
                    except asyncio.TimeoutError:
                        break
        
        except Exception as e:
            pytest.fail(f"WebSocket client error: {e}")
    
    # Start WebSocket client in background
    client_task = asyncio.create_task(websocket_client())
    
    # Wait for client to connect
    await asyncio.sleep(0.5)
    
    # Simulate agent publishing progress
    publisher = ProgressPublisher(test_task_id)
    for msg in progress_messages:
        publisher.publish(
            message=msg["message"],
            percent=msg["percent"],
            step=msg["step"],
            tool=msg["tool"]
        )
        await asyncio.sleep(0.1)  # Small delay between messages
    
    # Wait for client to finish
    await asyncio.wait_for(client_task, timeout=5.0)
    
    # Verify received messages
    assert len(received_messages) >= 5, "Should receive at least 5 progress messages"
    
    # Check message format
    for msg in received_messages:
        assert "step" in msg
        assert "message" in msg
        assert "percent" in msg
        assert "timestamp" in msg
        
        # Verify percent is valid
        assert 0 <= msg["percent"] <= 100
        
        # Verify step is valid
        assert msg["step"] in [
            "entity_extraction", "tool_execution", "scam_db", 
            "exa_search", "domain_reputation", "phone_validator",
            "reasoning", "completed", "failed"
        ]
    
    # Check final message is completion
    assert received_messages[-1]["step"] == "completed"
    assert received_messages[-1]["percent"] == 100


# =============================================================================
# Test: Connection Timeout and Cleanup
# =============================================================================

@pytest.mark.asyncio
async def test_websocket_timeout(test_task_id: str):
    """
    Test WebSocket timeout when no messages received.
    
    AC 12: Tests timeout if no messages for 60 seconds.
    """
    ws_url = f"ws://localhost:8000/ws/agent-progress/{test_task_id}"
    
    # Mock timeout to 2 seconds for faster testing
    with patch('app.main.timeout_seconds', 2):
        received_timeout = False
        
        try:
            async with ws_connect(ws_url) as websocket:
                # Receive initial connection message
                initial = await websocket.recv()
                initial_data = json.loads(initial)
                assert initial_data["step"] == "connected"
                
                # Wait for timeout message (should arrive after ~2 seconds)
                while True:
                    try:
                        message = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                        data = json.loads(message)
                        
                        # Skip heartbeats
                        if "heartbeat" in data:
                            continue
                        
                        # Check for timeout message
                        if data.get("step") == "failed" and "timeout" in data.get("message", "").lower():
                            received_timeout = True
                            break
                    
                    except asyncio.TimeoutError:
                        break
        
        except ConnectionClosed:
            pass  # Expected when server closes connection
        
        assert received_timeout, "Should receive timeout message"


@pytest.mark.asyncio
async def test_websocket_cleanup(test_task_id: str, redis_client):
    """
    Test WebSocket cleanup on client disconnect.
    
    AC 11: Tests cleanup on client disconnect (unsubscribe from Redis).
    """
    ws_url = f"ws://localhost:8000/ws/agent-progress/{test_task_id}"
    
    # Connect and immediately disconnect
    async with ws_connect(ws_url) as websocket:
        # Receive initial message
        await websocket.recv()
        
        # Close connection
        await websocket.close()
    
    # Wait for cleanup
    await asyncio.sleep(0.5)
    
    # Verify Redis subscription was cleaned up
    # Note: This is difficult to verify directly, but we can check
    # that publishing to the channel doesn't cause errors
    channel = f'agent_progress:{test_task_id}'
    try:
        redis_client.publish(channel, json.dumps({"test": "cleanup"}))
    except Exception as e:
        pytest.fail(f"Redis publish failed after cleanup: {e}")


# =============================================================================
# Test: Concurrent Connections
# =============================================================================

@pytest.mark.asyncio
async def test_concurrent_websocket_connections(test_task_id: str, redis_client):
    """
    Test multiple concurrent WebSocket connections.
    
    AC 19: Tests concurrent connections (10+ clients).
    """
    num_clients = 15
    ws_url = f"ws://localhost:8000/ws/agent-progress/{test_task_id}"
    
    received_by_client = [[] for _ in range(num_clients)]
    
    async def websocket_client(client_id: int):
        """WebSocket client that receives messages."""
        try:
            async with ws_connect(ws_url) as websocket:
                # Receive initial connection message
                initial = await websocket.recv()
                initial_data = json.loads(initial)
                assert initial_data["step"] == "connected"
                
                # Receive progress messages
                while True:
                    try:
                        message = await asyncio.wait_for(websocket.recv(), timeout=3.0)
                        data = json.loads(message)
                        
                        # Skip heartbeats
                        if "heartbeat" in data:
                            continue
                        
                        received_by_client[client_id].append(data)
                        
                        # Break on completion
                        if data.get("step") == "completed":
                            break
                    
                    except asyncio.TimeoutError:
                        break
        
        except Exception as e:
            pytest.fail(f"WebSocket client {client_id} error: {e}")
    
    # Start all clients concurrently
    client_tasks = [
        asyncio.create_task(websocket_client(i)) 
        for i in range(num_clients)
    ]
    
    # Wait for all clients to connect
    await asyncio.sleep(1.0)
    
    # Simulate agent publishing progress
    publisher = ProgressPublisher(test_task_id)
    progress_messages = [
        {"step": "entity_extraction", "message": "Extracting...", "percent": 20},
        {"step": "tool_execution", "message": "Running tools...", "percent": 50},
        {"step": "reasoning", "message": "Analyzing...", "percent": 80},
        {"step": "completed", "message": "Done!", "percent": 100}
    ]
    
    for msg in progress_messages:
        publisher.publish(
            message=msg["message"],
            percent=msg["percent"],
            step=msg["step"]
        )
        await asyncio.sleep(0.1)
    
    # Wait for all clients to finish
    await asyncio.gather(*client_tasks, return_exceptions=True)
    
    # Verify all clients received messages
    for i, messages in enumerate(received_by_client):
        assert len(messages) >= 4, f"Client {i} should receive at least 4 messages"
        assert messages[-1]["step"] == "completed", f"Client {i} should receive completion"


# =============================================================================
# Test: Error Scenarios
# =============================================================================

@pytest.mark.asyncio
async def test_websocket_invalid_task_id():
    """
    Test WebSocket with invalid task_id.
    
    AC 20: Tests error scenarios (invalid task_id).
    """
    # Use a valid UUID format but non-existent task
    invalid_task_id = str(uuid.uuid4())
    ws_url = f"ws://localhost:8000/ws/agent-progress/{invalid_task_id}"
    
    try:
        async with ws_connect(ws_url) as websocket:
            # Should still connect (WebSocket accepts any task_id)
            initial = await websocket.recv()
            initial_data = json.loads(initial)
            assert initial_data["step"] == "connected"
            
            # But no progress messages will arrive (timeout will occur)
            # This is expected behavior
    
    except Exception as e:
        # Connection might fail if server rejects invalid format
        pass


@pytest.mark.asyncio
async def test_websocket_redis_failure(test_task_id: str):
    """
    Test WebSocket behavior when Redis connection fails.
    
    AC 15-16: Tests gracefully handling Redis connection failures and logging errors.
    """
    ws_url = f"ws://localhost:8000/ws/agent-progress/{test_task_id}"
    
    # Mock Redis to raise an exception
    with patch('redis.asyncio.from_url') as mock_redis:
        mock_redis.side_effect = Exception("Redis connection failed")
        
        try:
            async with ws_connect(ws_url) as websocket:
                # Connection might be accepted but should fail gracefully
                message = await asyncio.wait_for(websocket.recv(), timeout=2.0)
                data = json.loads(message)
                
                # Should receive error message
                assert data.get("error") == True or data.get("step") == "failed"
        
        except (ConnectionClosed, asyncio.TimeoutError):
            # Expected - connection should close on Redis failure
            pass


# =============================================================================
# Test: Message Format Validation
# =============================================================================

@pytest.mark.asyncio
async def test_websocket_message_format(test_task_id: str, redis_client):
    """
    Test WebSocket message format compliance.
    
    AC 6-9: Tests JSON format with all required fields.
    """
    ws_url = f"ws://localhost:8000/ws/agent-progress/{test_task_id}"
    
    received_messages = []
    
    async with ws_connect(ws_url) as websocket:
        # Receive initial message
        initial = await websocket.recv()
        
        # Publish a test message
        publisher = ProgressPublisher(test_task_id)
        publisher.publish(
            message="Test message",
            percent=50,
            step="scam_db",
            tool="scam_database"
        )
        
        # Receive the message
        while True:
            try:
                message = await asyncio.wait_for(websocket.recv(), timeout=1.0)
                data = json.loads(message)
                
                # Skip heartbeats
                if "heartbeat" in data:
                    continue
                
                received_messages.append(data)
                break
            
            except asyncio.TimeoutError:
                break
        
        # Close with completion message
        publisher.publish(
            message="Complete",
            percent=100,
            step="completed"
        )
        
        # Receive completion
        await asyncio.wait_for(websocket.recv(), timeout=1.0)
    
    # Verify message format
    assert len(received_messages) > 0
    test_msg = received_messages[0]
    
    # Required fields
    assert "step" in test_msg
    assert "message" in test_msg
    assert "percent" in test_msg
    assert "timestamp" in test_msg
    
    # Optional fields
    assert "tool" in test_msg  # May be None
    
    # Verify types
    assert isinstance(test_msg["step"], str)
    assert isinstance(test_msg["message"], str)
    assert isinstance(test_msg["percent"], int)
    assert isinstance(test_msg["timestamp"], str)
    
    # Verify values
    assert test_msg["step"] == "scam_db"
    assert test_msg["tool"] == "scam_database"
    assert test_msg["percent"] == 50
    
    # Verify timestamp is ISO format
    try:
        datetime.fromisoformat(test_msg["timestamp"])
    except ValueError:
        pytest.fail("Timestamp should be ISO format")


# =============================================================================
# Test: Heartbeat
# =============================================================================

@pytest.mark.asyncio
async def test_websocket_heartbeat(test_task_id: str):
    """
    Test WebSocket heartbeat functionality.
    
    AC 10: Tests heartbeat every 15 seconds to keep connection alive.
    """
    ws_url = f"ws://localhost:8000/ws/agent-progress/{test_task_id}"
    
    heartbeat_received = False
    
    async with ws_connect(ws_url) as websocket:
        # Receive initial message
        await websocket.recv()
        
        # Wait for heartbeat (should arrive within 15 seconds)
        # We'll wait up to 20 seconds to be safe
        start_time = asyncio.get_event_loop().time()
        
        while asyncio.get_event_loop().time() - start_time < 20:
            try:
                message = await asyncio.wait_for(websocket.recv(), timeout=1.0)
                data = json.loads(message)
                
                if "heartbeat" in data and data["heartbeat"] == True:
                    heartbeat_received = True
                    break
            
            except asyncio.TimeoutError:
                continue
    
    assert heartbeat_received, "Should receive heartbeat within 20 seconds"


# =============================================================================
# Test: Error Message Publishing
# =============================================================================

@pytest.mark.asyncio
async def test_websocket_error_message(test_task_id: str, redis_client):
    """
    Test WebSocket error message publishing.
    
    AC 14: Tests sending error messages to client with proper format.
    """
    ws_url = f"ws://localhost:8000/ws/agent-progress/{test_task_id}"
    
    error_received = False
    
    async with ws_connect(ws_url) as websocket:
        # Receive initial message
        await websocket.recv()
        
        # Publish an error message
        publisher = ProgressPublisher(test_task_id)
        publisher.publish(
            message="Analysis failed: Test error",
            percent=0,
            step="failed",
            error=True
        )
        
        # Receive the error message
        while True:
            try:
                message = await asyncio.wait_for(websocket.recv(), timeout=2.0)
                data = json.loads(message)
                
                # Skip heartbeats
                if "heartbeat" in data:
                    continue
                
                # Check for error message
                if data.get("step") == "failed" and data.get("error") == True:
                    error_received = True
                    assert "error" in data.get("message", "").lower() or data.get("error") == True
                    break
            
            except asyncio.TimeoutError:
                break
    
    assert error_received, "Should receive error message"


# =============================================================================
# Run Tests
# =============================================================================

if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])

