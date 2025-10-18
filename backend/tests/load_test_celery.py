"""Load test for Celery infrastructure.

This script tests the Celery infrastructure under load by:
1. Enqueueing multiple concurrent tasks
2. Measuring task completion time and throughput
3. Tracking success/failure rates
4. Reporting performance metrics

Usage:
    python tests/load_test_celery.py [--tasks NUM] [--concurrent NUM]

Requirements:
    - Redis must be running
    - At least one Celery worker must be active
"""

import argparse
import time
import sys
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed
from collections import defaultdict
from datetime import datetime

# Add parent directory to path for imports
sys.path.insert(0, '.')

from app.agents.worker import celery_app
from app.agents.tasks.example_task import example_agent_task


class LoadTestRunner:
    """Load test runner for Celery tasks"""
    
    def __init__(self, num_tasks=100, concurrency=10):
        """
        Initialize load test runner.
        
        Args:
            num_tasks: Total number of tasks to enqueue
            concurrency: Number of concurrent enqueue operations
        """
        self.num_tasks = num_tasks
        self.concurrency = concurrency
        self.results = []
        self.metrics = defaultdict(int)
        self.start_time = None
        self.end_time = None
    
    def enqueue_task(self, task_index):
        """
        Enqueue a single task.
        
        Args:
            task_index: Index of the task (0 to num_tasks-1)
        
        Returns:
            dict: Task metadata including task_id, enqueue_time, etc.
        """
        task_id = f"load-test-{uuid.uuid4()}"
        data = {
            "index": task_index,
            "timestamp": datetime.now().isoformat(),
            "simulate_failure": False  # Disable random failures for load test
        }
        
        try:
            enqueue_start = time.time()
            result = example_agent_task.apply_async(
                args=[task_id, data],
                task_id=task_id
            )
            enqueue_time = time.time() - enqueue_start
            
            return {
                "task_id": result.id,
                "index": task_index,
                "enqueue_time": enqueue_time,
                "status": "enqueued",
                "result_obj": result
            }
        except Exception as e:
            return {
                "task_id": None,
                "index": task_index,
                "enqueue_time": 0,
                "status": "enqueue_failed",
                "error": str(e)
            }
    
    def run_enqueue_phase(self):
        """
        Enqueue all tasks concurrently.
        
        Returns:
            list: List of task metadata dictionaries
        """
        print(f"\n{'='*60}")
        print(f"PHASE 1: Enqueueing {self.num_tasks} tasks")
        print(f"Concurrency: {self.concurrency} threads")
        print(f"{'='*60}\n")
        
        enqueue_start = time.time()
        tasks = []
        
        with ThreadPoolExecutor(max_workers=self.concurrency) as executor:
            futures = [
                executor.submit(self.enqueue_task, i)
                for i in range(self.num_tasks)
            ]
            
            for future in as_completed(futures):
                task_info = future.result()
                tasks.append(task_info)
                
                if task_info['status'] == 'enqueued':
                    self.metrics['enqueued'] += 1
                    print(f"✓ Enqueued task {task_info['index']}/{self.num_tasks} "
                          f"(time: {task_info['enqueue_time']:.3f}s)", end='\r')
                else:
                    self.metrics['enqueue_failed'] += 1
                    print(f"✗ Failed to enqueue task {task_info['index']}")
        
        enqueue_duration = time.time() - enqueue_start
        
        print(f"\n\nEnqueue Phase Complete:")
        print(f"  Enqueued: {self.metrics['enqueued']}/{self.num_tasks}")
        print(f"  Failed: {self.metrics['enqueue_failed']}/{self.num_tasks}")
        print(f"  Duration: {enqueue_duration:.2f}s")
        print(f"  Throughput: {self.num_tasks/enqueue_duration:.2f} tasks/sec")
        
        return tasks
    
    def run_completion_phase(self, tasks):
        """
        Wait for all tasks to complete and collect results.
        
        Args:
            tasks: List of task metadata from enqueue phase
        """
        print(f"\n{'='*60}")
        print(f"PHASE 2: Waiting for task completion")
        print(f"{'='*60}\n")
        
        completion_start = time.time()
        timeout = 60  # 60 second timeout per task
        
        for i, task_info in enumerate(tasks):
            if task_info['status'] != 'enqueued':
                continue
            
            result_obj = task_info['result_obj']
            task_start = time.time()
            
            try:
                # Wait for task completion
                task_result = result_obj.get(timeout=timeout)
                task_duration = time.time() - task_start
                
                task_info['status'] = 'completed'
                task_info['duration'] = task_duration
                task_info['result'] = task_result
                
                self.metrics['completed'] += 1
                self.metrics['total_duration'] += task_duration
                
                print(f"✓ Task {i+1}/{self.num_tasks} completed "
                      f"(duration: {task_duration:.2f}s)", end='\r')
                
            except Exception as e:
                task_duration = time.time() - task_start
                
                task_info['status'] = 'failed'
                task_info['duration'] = task_duration
                task_info['error'] = str(e)
                
                self.metrics['failed'] += 1
                print(f"✗ Task {i+1}/{self.num_tasks} failed: {e}")
        
        completion_duration = time.time() - completion_start
        
        print(f"\n\nCompletion Phase Complete:")
        print(f"  Completed: {self.metrics['completed']}/{self.num_tasks}")
        print(f"  Failed: {self.metrics['failed']}/{self.num_tasks}")
        print(f"  Duration: {completion_duration:.2f}s")
    
    def print_summary(self, tasks):
        """
        Print final test summary and metrics.
        
        Args:
            tasks: List of task metadata
        """
        total_duration = self.end_time - self.start_time
        completed_tasks = [t for t in tasks if t.get('status') == 'completed']
        
        print(f"\n{'='*60}")
        print(f"LOAD TEST SUMMARY")
        print(f"{'='*60}\n")
        
        print(f"Configuration:")
        print(f"  Total tasks: {self.num_tasks}")
        print(f"  Concurrency: {self.concurrency}")
        print(f"  Total duration: {total_duration:.2f}s")
        print()
        
        print(f"Results:")
        print(f"  Enqueued: {self.metrics['enqueued']} ({self.metrics['enqueued']/self.num_tasks*100:.1f}%)")
        print(f"  Completed: {self.metrics['completed']} ({self.metrics['completed']/self.num_tasks*100:.1f}%)")
        print(f"  Failed: {self.metrics['failed']} ({self.metrics['failed']/self.num_tasks*100:.1f}%)")
        print()
        
        print(f"Performance:")
        print(f"  Overall throughput: {self.num_tasks/total_duration:.2f} tasks/sec")
        
        if completed_tasks:
            durations = [t['duration'] for t in completed_tasks]
            avg_duration = sum(durations) / len(durations)
            min_duration = min(durations)
            max_duration = max(durations)
            
            print(f"  Average task duration: {avg_duration:.2f}s")
            print(f"  Min task duration: {min_duration:.2f}s")
            print(f"  Max task duration: {max_duration:.2f}s")
        
        print()
        
        # Success criteria
        success_rate = self.metrics['completed'] / self.num_tasks
        if success_rate >= 0.95:
            print(f"✓ PASS: Success rate {success_rate*100:.1f}% >= 95%")
        else:
            print(f"✗ FAIL: Success rate {success_rate*100:.1f}% < 95%")
        
        print(f"\n{'='*60}\n")
    
    def run(self):
        """Run the complete load test"""
        print(f"\n{'='*60}")
        print(f"CELERY LOAD TEST")
        print(f"{'='*60}")
        print(f"Start time: {datetime.now().isoformat()}")
        
        self.start_time = time.time()
        
        try:
            # Phase 1: Enqueue tasks
            tasks = self.run_enqueue_phase()
            
            # Phase 2: Wait for completion
            self.run_completion_phase(tasks)
            
            self.end_time = time.time()
            
            # Print summary
            self.print_summary(tasks)
            
            # Return success status
            success_rate = self.metrics['completed'] / self.num_tasks
            return success_rate >= 0.95
            
        except KeyboardInterrupt:
            print("\n\nLoad test interrupted by user")
            return False
        except Exception as e:
            print(f"\n\nLoad test failed with error: {e}")
            import traceback
            traceback.print_exc()
            return False


def check_prerequisites():
    """
    Check that prerequisites are met before running load test.
    
    Returns:
        bool: True if prerequisites are met, False otherwise
    """
    print("Checking prerequisites...")
    
    # Check Redis connection
    try:
        inspect = celery_app.control.inspect()
        stats = inspect.stats()
        
        if not stats:
            print("✗ No active Celery workers found")
            print("  Start a worker with: celery -A app.agents.worker worker --loglevel=info")
            return False
        
        print(f"✓ Found {len(stats)} active worker(s)")
        for worker_name in stats.keys():
            print(f"  - {worker_name}")
        
        return True
        
    except Exception as e:
        print(f"✗ Cannot connect to Redis/Celery: {e}")
        print("  Ensure Redis is running: docker-compose up redis -d")
        return False


def main():
    """Main entry point for load test"""
    parser = argparse.ArgumentParser(
        description='Load test for Celery infrastructure',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        '--tasks',
        type=int,
        default=100,
        help='Number of tasks to enqueue (default: 100)'
    )
    parser.add_argument(
        '--concurrent',
        type=int,
        default=10,
        help='Number of concurrent enqueue operations (default: 10)'
    )
    parser.add_argument(
        '--skip-checks',
        action='store_true',
        help='Skip prerequisite checks'
    )
    
    args = parser.parse_args()
    
    # Check prerequisites
    if not args.skip_checks:
        if not check_prerequisites():
            sys.exit(1)
        print()
    
    # Run load test
    runner = LoadTestRunner(
        num_tasks=args.tasks,
        concurrency=args.concurrent
    )
    
    success = runner.run()
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

