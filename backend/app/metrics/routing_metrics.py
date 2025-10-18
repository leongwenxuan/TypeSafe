"""
Metrics tracking for smart routing (Story 8.10).

Tracks routing decisions, latency, and performance metrics for monitoring
and alerting on routing behavior.
"""

import logging
from typing import Dict, Any
from datetime import datetime, timezone
from dataclasses import dataclass, asdict
import json

logger = logging.getLogger(__name__)


@dataclass
class RoutingMetric:
    """Represents a single routing decision metric."""
    timestamp: str
    route_type: str  # 'fast_path' or 'agent_path'
    has_entities: bool
    entity_count: int
    routing_time_ms: float
    total_time_ms: float | None = None
    session_id: str | None = None
    request_id: str | None = None
    fallback_reason: str | None = None  # 'worker_unavailable', 'agent_disabled', None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for serialization."""
        return asdict(self)
    
    def to_json(self) -> str:
        """Convert to JSON string."""
        return json.dumps(self.to_dict())


class RoutingMetricsTracker:
    """
    Tracks and aggregates routing metrics.
    
    This class provides methods to track routing decisions and compute
    statistics for monitoring and alerting.
    
    Metrics tracked:
    - % of scans routed to agent path vs fast path
    - Entity extraction latency
    - Fast path latency (p50, p95, p99)
    - Agent path latency (p50, p95, p99)
    - Fallback rates (worker unavailable, agent disabled)
    """
    
    def __init__(self):
        """Initialize metrics tracker."""
        self.metrics: list[RoutingMetric] = []
        logger.info("RoutingMetricsTracker initialized")
    
    def record_routing_decision(
        self,
        route_type: str,
        has_entities: bool,
        entity_count: int,
        routing_time_ms: float,
        total_time_ms: float | None = None,
        session_id: str | None = None,
        request_id: str | None = None,
        fallback_reason: str | None = None
    ):
        """
        Record a routing decision.
        
        Args:
            route_type: 'fast_path' or 'agent_path'
            has_entities: Whether entities were found
            entity_count: Number of entities found
            routing_time_ms: Time taken for routing decision (entity extraction)
            total_time_ms: Optional total time for complete request
            session_id: Optional session ID
            request_id: Optional request ID
            fallback_reason: Optional reason for fallback to fast path
        """
        metric = RoutingMetric(
            timestamp=datetime.now(timezone.utc).isoformat(),
            route_type=route_type,
            has_entities=has_entities,
            entity_count=entity_count,
            routing_time_ms=routing_time_ms,
            total_time_ms=total_time_ms,
            session_id=session_id,
            request_id=request_id,
            fallback_reason=fallback_reason
        )
        
        self.metrics.append(metric)
        
        # Log metric for monitoring
        logger.info(
            f"Routing metric: route={route_type} entities={entity_count} "
            f"routing_ms={routing_time_ms:.2f} fallback={fallback_reason} "
            f"request_id={request_id}"
        )
    
    def get_routing_stats(self, window_minutes: int = 60) -> Dict[str, Any]:
        """
        Get routing statistics for the last N minutes.
        
        Args:
            window_minutes: Time window for statistics (default 60 minutes)
        
        Returns:
            Dictionary with routing statistics
        """
        if not self.metrics:
            return {
                "total_scans": 0,
                "agent_path_count": 0,
                "fast_path_count": 0,
                "agent_path_percentage": 0.0,
                "fast_path_percentage": 0.0,
                "fallback_count": 0,
                "avg_routing_time_ms": 0.0,
                "window_minutes": window_minutes
            }
        
        # Filter metrics within time window
        from datetime import timedelta
        cutoff_time = datetime.now(timezone.utc) - timedelta(minutes=window_minutes)
        
        recent_metrics = [
            m for m in self.metrics
            if datetime.fromisoformat(m.timestamp) >= cutoff_time
        ]
        
        if not recent_metrics:
            return {
                "total_scans": 0,
                "agent_path_count": 0,
                "fast_path_count": 0,
                "agent_path_percentage": 0.0,
                "fast_path_percentage": 0.0,
                "fallback_count": 0,
                "avg_routing_time_ms": 0.0,
                "window_minutes": window_minutes
            }
        
        # Compute statistics
        total_scans = len(recent_metrics)
        agent_path_count = len([m for m in recent_metrics if m.route_type == 'agent_path'])
        fast_path_count = len([m for m in recent_metrics if m.route_type == 'fast_path'])
        fallback_count = len([m for m in recent_metrics if m.fallback_reason is not None])
        
        avg_routing_time = sum(m.routing_time_ms for m in recent_metrics) / total_scans
        
        return {
            "total_scans": total_scans,
            "agent_path_count": agent_path_count,
            "fast_path_count": fast_path_count,
            "agent_path_percentage": (agent_path_count / total_scans * 100) if total_scans > 0 else 0.0,
            "fast_path_percentage": (fast_path_count / total_scans * 100) if total_scans > 0 else 0.0,
            "fallback_count": fallback_count,
            "fallback_percentage": (fallback_count / total_scans * 100) if total_scans > 0 else 0.0,
            "avg_routing_time_ms": avg_routing_time,
            "window_minutes": window_minutes,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
    
    def get_latency_stats(
        self, 
        route_type: str | None = None,
        window_minutes: int = 60
    ) -> Dict[str, Any]:
        """
        Get latency statistics for fast path or agent path.
        
        Args:
            route_type: Optional filter by route type ('fast_path' or 'agent_path')
            window_minutes: Time window for statistics (default 60 minutes)
        
        Returns:
            Dictionary with latency statistics (p50, p95, p99)
        """
        from datetime import timedelta
        cutoff_time = datetime.now(timezone.utc) - timedelta(minutes=window_minutes)
        
        # Filter metrics
        filtered_metrics = [
            m for m in self.metrics
            if datetime.fromisoformat(m.timestamp) >= cutoff_time
            and m.total_time_ms is not None
            and (route_type is None or m.route_type == route_type)
        ]
        
        if not filtered_metrics:
            return {
                "route_type": route_type or "all",
                "count": 0,
                "p50": 0.0,
                "p95": 0.0,
                "p99": 0.0,
                "min": 0.0,
                "max": 0.0,
                "avg": 0.0
            }
        
        # Sort by latency
        latencies = sorted([m.total_time_ms for m in filtered_metrics])
        count = len(latencies)
        
        # Calculate percentiles
        def percentile(data, p):
            k = (len(data) - 1) * p / 100
            f = int(k)
            c = f + 1 if c < len(data) else f
            if f == c:
                return data[f]
            return data[f] + (k - f) * (data[c] - data[f])
        
        return {
            "route_type": route_type or "all",
            "count": count,
            "p50": percentile(latencies, 50),
            "p95": percentile(latencies, 95),
            "p99": percentile(latencies, 99),
            "min": min(latencies),
            "max": max(latencies),
            "avg": sum(latencies) / count
        }
    
    def check_alert_conditions(self) -> list[str]:
        """
        Check for alert conditions.
        
        Returns:
            List of alert messages (empty if no alerts)
        """
        alerts = []
        
        # Get recent stats (last 60 minutes)
        stats = self.get_routing_stats(window_minutes=60)
        
        # Alert: Agent path > 50% of scans (potential issue)
        if stats['total_scans'] >= 10 and stats['agent_path_percentage'] > 50:
            alerts.append(
                f"ALERT: Agent path usage is {stats['agent_path_percentage']:.1f}% "
                f"(>{50}% threshold) over last 60 minutes"
            )
        
        # Alert: High fallback rate (> 20%)
        if stats['total_scans'] >= 10 and stats.get('fallback_percentage', 0) > 20:
            alerts.append(
                f"ALERT: Fallback rate is {stats['fallback_percentage']:.1f}% "
                f"(>20% threshold) - possible worker issues"
            )
        
        # Alert: Slow routing decisions (> 150ms average)
        if stats['total_scans'] >= 10 and stats['avg_routing_time_ms'] > 150:
            alerts.append(
                f"ALERT: Average routing time is {stats['avg_routing_time_ms']:.1f}ms "
                f"(>150ms threshold) - entity extraction may be slow"
            )
        
        return alerts
    
    def clear_old_metrics(self, hours: int = 24):
        """
        Clear metrics older than N hours.
        
        Args:
            hours: Number of hours to keep (default 24)
        """
        from datetime import timedelta
        cutoff_time = datetime.now(timezone.utc) - timedelta(hours=hours)
        
        before_count = len(self.metrics)
        self.metrics = [
            m for m in self.metrics
            if datetime.fromisoformat(m.timestamp) >= cutoff_time
        ]
        after_count = len(self.metrics)
        
        cleared = before_count - after_count
        if cleared > 0:
            logger.info(f"Cleared {cleared} old metrics (kept {after_count})")


# Singleton instance
_metrics_tracker: RoutingMetricsTracker | None = None


def get_metrics_tracker() -> RoutingMetricsTracker:
    """Get singleton RoutingMetricsTracker instance."""
    global _metrics_tracker
    if _metrics_tracker is None:
        _metrics_tracker = RoutingMetricsTracker()
    return _metrics_tracker

