"""Cost tracking for Exa API usage.

Tracks Exa API usage and costs to prevent runaway spending. Features:
- Daily cost tracking and budget alerts
- Per-search cost calculation
- Redis-based persistent storage
- Budget limit enforcement
- Usage analytics

Story: 8.4 - Exa Web Search Tool Integration
"""

import logging
from datetime import date
from typing import Dict, Any, Optional
import os

from app.config import settings

logger = logging.getLogger(__name__)


class ExaCostTracker:
    """
    Track Exa API usage and costs.
    
    Features:
    - Daily cost tracking
    - Budget limit enforcement
    - Usage statistics
    - Alert on budget exceeded
    
    Example:
        >>> tracker = ExaCostTracker()
        >>> tracker.track_search("phone", "+18005551234")
        >>> stats = tracker.get_daily_stats()
        >>> print(f"Today's cost: ${stats['total_cost']:.2f}")
    """
    
    # Exa pricing (as of 2025)
    COST_PER_SEARCH = 0.005  # $0.005 per search
    
    def __init__(self, daily_budget_limit: Optional[float] = None):
        """
        Initialize cost tracker.
        
        Args:
            daily_budget_limit: Daily budget limit in USD (defaults to settings)
        """
        self.daily_budget_limit = daily_budget_limit or settings.exa_daily_budget
        
        # Initialize Redis
        try:
            import redis
            self.redis = redis.from_url(
                settings.redis_url,
                decode_responses=True
            )
            logger.info(f"ExaCostTracker initialized (budget: ${self.daily_budget_limit}/day)")
        except Exception as e:
            logger.error(f"Failed to initialize ExaCostTracker: {e}")
            raise
    
    def track_search(self, entity_type: str, entity_value: str) -> Dict[str, Any]:
        """
        Track a single search API call.
        
        Args:
            entity_type: Type of entity searched (phone, url, email, etc.)
            entity_value: Entity value (for logging, not stored)
        
        Returns:
            Dict with tracking info: search_count, total_cost, budget_remaining
            
        Example:
            >>> tracker.track_search("phone", "+18005551234")
            {'search_count': 1, 'total_cost': 0.005, 'budget_remaining': 9.995}
        """
        today = date.today().isoformat()
        key = f"exa_cost:{today}"
        
        try:
            # Increment daily count
            search_count = self.redis.hincrby(key, "search_count", 1)
            
            # Calculate and store cost
            current_cost_str = self.redis.hget(key, "total_cost") or "0"
            current_cost = float(current_cost_str)
            new_cost = current_cost + self.COST_PER_SEARCH
            self.redis.hset(key, "total_cost", new_cost)
            
            # Store entity type count
            type_key = f"entity_type:{entity_type}"
            self.redis.hincrby(key, type_key, 1)
            
            # Set expiry (7 days)
            self.redis.expire(key, 604800)
            
            # Check budget limit
            budget_remaining = self.daily_budget_limit - new_cost
            if new_cost > self.daily_budget_limit:
                logger.warning(
                    f"⚠️ Daily Exa budget EXCEEDED: ${new_cost:.2f} "
                    f"(limit: ${self.daily_budget_limit:.2f})"
                )
            elif budget_remaining < 1.0:
                logger.warning(
                    f"⚠️ Daily Exa budget LOW: ${budget_remaining:.2f} remaining"
                )
            
            logger.info(
                f"Exa search tracked: {entity_type} "
                f"(daily: {search_count} searches, ${new_cost:.2f})"
            )
            
            return {
                "search_count": int(search_count),
                "total_cost": new_cost,
                "budget_remaining": max(0, budget_remaining),
                "budget_exceeded": new_cost > self.daily_budget_limit
            }
        
        except Exception as e:
            logger.error(f"Error tracking search: {e}", exc_info=True)
            # Return default values on error
            return {
                "search_count": 0,
                "total_cost": 0.0,
                "budget_remaining": self.daily_budget_limit,
                "budget_exceeded": False
            }
    
    def get_daily_stats(self, date_str: Optional[str] = None) -> Dict[str, Any]:
        """
        Get daily usage statistics.
        
        Args:
            date_str: Date in ISO format (YYYY-MM-DD), defaults to today
        
        Returns:
            Dict with stats: date, search_count, total_cost, budget_limit, etc.
            
        Example:
            >>> stats = tracker.get_daily_stats()
            >>> print(f"Searches today: {stats['search_count']}")
            >>> print(f"Cost today: ${stats['total_cost']:.2f}")
        """
        if not date_str:
            date_str = date.today().isoformat()
        
        key = f"exa_cost:{date_str}"
        
        try:
            # Get all hash fields
            data = self.redis.hgetall(key)
            
            search_count = int(data.get("search_count", 0))
            total_cost = float(data.get("total_cost", 0.0))
            
            # Extract entity type counts
            entity_counts = {}
            for field, value in data.items():
                if field.startswith("entity_type:"):
                    entity_type = field.replace("entity_type:", "")
                    entity_counts[entity_type] = int(value)
            
            return {
                "date": date_str,
                "search_count": search_count,
                "total_cost": total_cost,
                "budget_limit": self.daily_budget_limit,
                "remaining_budget": max(0, self.daily_budget_limit - total_cost),
                "budget_exceeded": total_cost > self.daily_budget_limit,
                "entity_type_counts": entity_counts
            }
        
        except Exception as e:
            logger.error(f"Error getting daily stats: {e}", exc_info=True)
            return {
                "date": date_str,
                "search_count": 0,
                "total_cost": 0.0,
                "budget_limit": self.daily_budget_limit,
                "remaining_budget": self.daily_budget_limit,
                "budget_exceeded": False,
                "entity_type_counts": {}
            }
    
    def is_budget_exceeded(self, date_str: Optional[str] = None) -> bool:
        """
        Check if daily budget is exceeded.
        
        Args:
            date_str: Date to check (defaults to today)
        
        Returns:
            True if budget exceeded, False otherwise
            
        Example:
            >>> if tracker.is_budget_exceeded():
            ...     print("Budget exceeded, skipping search")
        """
        stats = self.get_daily_stats(date_str)
        return stats["budget_exceeded"]
    
    def get_weekly_stats(self) -> Dict[str, Any]:
        """
        Get weekly aggregated statistics.
        
        Returns:
            Dict with weekly stats
            
        Example:
            >>> stats = tracker.get_weekly_stats()
            >>> print(f"Week total: ${stats['total_cost']:.2f}")
        """
        from datetime import datetime, timedelta
        
        today = date.today()
        days = []
        total_searches = 0
        total_cost = 0.0
        
        # Get last 7 days
        for i in range(7):
            day = today - timedelta(days=i)
            day_stats = self.get_daily_stats(day.isoformat())
            days.append(day_stats)
            total_searches += day_stats["search_count"]
            total_cost += day_stats["total_cost"]
        
        return {
            "period": "last_7_days",
            "start_date": (today - timedelta(days=6)).isoformat(),
            "end_date": today.isoformat(),
            "total_searches": total_searches,
            "total_cost": total_cost,
            "avg_daily_cost": total_cost / 7,
            "daily_breakdown": days
        }
    
    def reset_daily_stats(self, date_str: Optional[str] = None):
        """
        Reset daily statistics (for testing or admin purposes).
        
        Args:
            date_str: Date to reset (defaults to today)
            
        Example:
            >>> tracker.reset_daily_stats()  # Reset today's stats
        """
        if not date_str:
            date_str = date.today().isoformat()
        
        key = f"exa_cost:{date_str}"
        
        try:
            self.redis.delete(key)
            logger.info(f"Reset Exa cost stats for {date_str}")
        except Exception as e:
            logger.error(f"Error resetting stats: {e}", exc_info=True)


# =============================================================================
# Singleton Instance
# =============================================================================

_tracker_instance: Optional[ExaCostTracker] = None


def get_exa_cost_tracker() -> ExaCostTracker:
    """
    Get singleton ExaCostTracker instance.
    
    Returns:
        Singleton instance of ExaCostTracker
        
    Example:
        >>> tracker = get_exa_cost_tracker()
        >>> tracker.track_search("phone", "+18005551234")
    """
    global _tracker_instance
    if _tracker_instance is None:
        _tracker_instance = ExaCostTracker()
    return _tracker_instance

