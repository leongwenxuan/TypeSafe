//
//  APIPerformanceTests.swift
//  TypeSafeTests
//
//  Story 10.3: Performance Regression Testing
//  Tests API performance, debouncing, async operations, and timeout handling
//

import XCTest
@testable import TypeSafeKeyboard

class APIPerformanceTests: PerformanceTestBase {
    
    // MARK: - Debounce Performance Tests
    
    /// Test debounce effectiveness with rapid triggers
    func testDebounceEffectiveness() {
        let expectation = XCTestExpectation(description: "Debounce effectiveness")
        let analyzer = DebouncedAnalyzer()
        
        analyzer.resetStatistics()
        
        print("📊 Debounce Effectiveness (10 rapid triggers):")
        
        // Simulate rapid typing
        for i in 0..<10 {
            let text = String(repeating: "a", count: i + 1)
            analyzer.analyzeText(text) { _ in }
            Thread.sleep(forTimeInterval: 0.05) // 50ms between chars (fast typing)
        }
        
        // Wait for debounce to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let stats = analyzer.getStatistics()
            
            print("   Triggered: 10")
            print("   Actual requests: \(stats.requests)")
            print("   Debounced: \(stats.debounced)")
            print("   Reduction: \(String(format: "%.1f", stats.reductionPercent))%")
            
            // Assert against baseline
            self.assertPerformance("apiDebounce_reductionPercent", measured: stats.reductionPercent)
            
            // Should achieve at least 70% reduction
            XCTAssertGreaterThanOrEqual(
                stats.reductionPercent,
                70.0,
                "Should achieve >= 70% request reduction"
            )
            
            // Should make very few actual requests
            XCTAssertLessThanOrEqual(
                stats.requests,
                3,
                "Should make <= 3 actual requests from 10 triggers"
            )
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    /// Test debounce with varied typing speeds
    func testDebounceWithVariedSpeed() {
        let expectation = XCTestExpectation(description: "Varied speed debounce")
        let analyzer = DebouncedAnalyzer()
        
        analyzer.resetStatistics()
        
        print("📊 Debounce with Varied Typing Speed:")
        
        var triggerCount = 0
        
        // Fast burst (5 chars, 50ms apart)
        for i in 0..<5 {
            let text = String(repeating: "a", count: triggerCount + 1)
            analyzer.analyzeText(text) { _ in }
            triggerCount += 1
            Thread.sleep(forTimeInterval: 0.05)
        }
        
        // Short pause (300ms)
        Thread.sleep(forTimeInterval: 0.3)
        
        // Slow typing (5 chars, 600ms apart - should trigger analysis each time)
        for i in 0..<5 {
            let text = String(repeating: "a", count: triggerCount + 1)
            analyzer.analyzeText(text) { _ in }
            triggerCount += 1
            Thread.sleep(forTimeInterval: 0.6)
        }
        
        // Wait for final debounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let stats = analyzer.getStatistics()
            
            print("   Total triggers: \(triggerCount)")
            print("   Actual requests: \(stats.requests)")
            print("   Reduction: \(String(format: "%.1f", stats.reductionPercent))%")
            
            // Fast burst should be debounced, slow typing should trigger
            // Expected: ~1 from fast burst + ~5 from slow = ~6 requests
            XCTAssertGreaterThanOrEqual(stats.requests, 5, "Slow typing should trigger multiple requests")
            XCTAssertLessThanOrEqual(stats.requests, 8, "Should still debounce fast burst")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 7.0)
    }
    
    /// Test debounce latency overhead
    func testDebounceLatencyOverhead() {
        let analyzer = DebouncedAnalyzer()
        var latencies: [Double] = []
        
        print("📊 Debounce Latency Overhead:")
        
        for i in 0..<20 {
            let latency = PerformanceMonitor.measureTime {
                let text = "test\(i)"
                analyzer.analyzeText(text) { _ in }
            }
            latencies.append(latency)
        }
        
        let avgLatency = mean(latencies)
        let p95Latency = percentile(latencies, 0.95)
        
        print("   Average: \(String(format: "%.3f", avgLatency))ms")
        print("   P95: \(String(format: "%.3f", p95Latency))ms")
        
        // Debounce triggering should be fast (< 5ms)
        assertAbsoluteThreshold("debounce_triggerLatency_P95", measured: p95Latency, maxAllowed: 5.0)
    }
    
    // MARK: - Request Cancellation Tests
    
    /// Test request cancellation effectiveness
    func testRequestCancellation() {
        let expectation = XCTestExpectation(description: "Request cancellation")
        let analyzer = DebouncedAnalyzer()
        
        print("📊 Request Cancellation:")
        
        analyzer.resetStatistics()
        
        // Trigger multiple requests
        for i in 0..<5 {
            let text = String(repeating: "a", count: i + 1)
            analyzer.analyzeText(text) { _ in }
            Thread.sleep(forTimeInterval: 0.05)
        }
        
        // Cancel immediately
        let cancelTime = PerformanceMonitor.measureTime {
            analyzer.cancelPending()
        }
        
        print("   Cancellation time: \(String(format: "%.3f", cancelTime))ms")
        
        // Cancellation should be fast
        XCTAssertLessThan(cancelTime, 1.0, "Cancellation should be < 1ms")
        
        // Wait to ensure no requests complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let stats = analyzer.getStatistics()
            
            print("   Requests after cancel: \(stats.requests)")
            
            // Should have cancelled all pending requests
            XCTAssertLessThanOrEqual(stats.requests, 1, "Should cancel most requests")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    /// Test multiple cancel operations
    func testMultipleCancellations() {
        let analyzer = DebouncedAnalyzer()
        var cancelLatencies: [Double] = []
        
        print("📊 Multiple Cancellations (20 cycles):")
        
        for _ in 0..<20 {
            // Trigger request
            analyzer.analyzeText("test") { _ in }
            
            // Cancel immediately
            let latency = PerformanceMonitor.measureTime {
                analyzer.cancelPending()
            }
            cancelLatencies.append(latency)
            
            Thread.sleep(forTimeInterval: 0.05)
        }
        
        let avgLatency = mean(cancelLatencies)
        let maxLatency = cancelLatencies.max() ?? 0
        
        print("   Average cancel time: \(String(format: "%.3f", avgLatency))ms")
        print("   Max cancel time: \(String(format: "%.3f", maxLatency))ms")
        
        // All cancellations should be fast
        XCTAssertLessThan(avgLatency, 1.0, "Average cancellation should be < 1ms")
        XCTAssertLessThan(maxLatency, 2.0, "Max cancellation should be < 2ms")
    }
    
    // MARK: - Async Execution Tests
    
    /// Test that API calls don't block
    func testNonBlockingExecution() {
        let analyzer = DebouncedAnalyzer()
        
        print("📊 Non-Blocking Execution:")
        
        // Measure time to trigger API call
        let triggerTime = PerformanceMonitor.measureTime {
            analyzer.analyzeText("test") { _ in
                // Completion not important for this test
            }
        }
        
        print("   Trigger time: \(String(format: "%.3f", triggerTime))ms")
        
        // Triggering should be nearly instant (not waiting for response)
        XCTAssertLessThan(triggerTime, 5.0, "API trigger should be non-blocking (< 5ms)")
    }
    
    /// Test concurrent API operations
    func testConcurrentOperations() {
        let expectation = XCTestExpectation(description: "Concurrent operations")
        let analyzer = DebouncedAnalyzer()
        
        print("📊 Concurrent Operations:")
        
        analyzer.resetStatistics()
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Trigger multiple operations concurrently
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        
        for i in 0..<10 {
            group.enter()
            queue.async {
                let text = "test\(i)"
                analyzer.analyzeText(text) { _ in
                    group.leave()
                }
            }
        }
        
        // Wait for all to trigger
        group.notify(queue: .main) {
            let triggerDuration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            
            print("   Triggered 10 operations in: \(String(format: "%.2f", triggerDuration))ms")
            
            // Should be able to trigger all quickly
            XCTAssertLessThan(triggerDuration, 50.0, "Should trigger 10 operations in < 50ms")
            
            // Wait for debounce
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let stats = analyzer.getStatistics()
                print("   Actual requests: \(stats.requests)")
                
                // Should debounce concurrent triggers
                XCTAssertLessThanOrEqual(stats.requests, 3, "Should debounce concurrent requests")
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    // MARK: - Request Coalescing Tests
    
    /// Test that identical requests are coalesced
    func testRequestCoalescing() {
        let expectation = XCTestExpectation(description: "Request coalescing")
        let analyzer = DebouncedAnalyzer()
        
        print("📊 Request Coalescing:")
        
        analyzer.resetStatistics()
        
        // Trigger same text multiple times rapidly
        let identicalText = "test text"
        for _ in 0..<10 {
            analyzer.analyzeText(identicalText) { _ in }
            Thread.sleep(forTimeInterval: 0.05)
        }
        
        // Wait for debounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let stats = analyzer.getStatistics()
            
            print("   Identical triggers: 10")
            print("   Actual requests: \(stats.requests)")
            
            // Should coalesce into 1-2 requests
            XCTAssertLessThanOrEqual(stats.requests, 2, "Should coalesce identical requests")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Performance Under Load
    
    /// Test performance with high frequency triggers
    func testHighFrequencyTriggers() {
        let expectation = XCTestExpectation(description: "High frequency")
        let analyzer = DebouncedAnalyzer()
        
        print("📊 High Frequency Triggers (100 in 1 second):")
        
        analyzer.resetStatistics()
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Trigger 100 times very rapidly
        for i in 0..<100 {
            let text = String(repeating: "a", count: i + 1)
            analyzer.analyzeText(text) { _ in }
            Thread.sleep(forTimeInterval: 0.01) // 10ms apart
        }
        
        let triggerDuration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        print("   Trigger duration: \(String(format: "%.2f", triggerDuration))ms")
        
        // Wait for debounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let stats = analyzer.getStatistics()
            
            print("   Triggers: 100")
            print("   Actual requests: \(stats.requests)")
            print("   Reduction: \(String(format: "%.1f", stats.reductionPercent))%")
            
            // Should handle high frequency well
            XCTAssertGreaterThanOrEqual(stats.reductionPercent, 90.0, "High frequency should achieve >= 90% reduction")
            XCTAssertLessThanOrEqual(stats.requests, 5, "Should make <= 5 requests from 100 triggers")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    /// Test memory usage during extended API operations
    func testAPIMemoryUsage() {
        let analyzer = DebouncedAnalyzer()
        
        print("📊 API Memory Usage:")
        
        let memoryBefore = PerformanceMonitor.getMemoryUsageMB()
        
        // Trigger many operations
        for i in 0..<100 {
            let text = String(repeating: "a", count: (i % 50) + 1)
            analyzer.analyzeText(text) { _ in }
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        // Wait for operations to settle
        Thread.sleep(forTimeInterval: 1.0)
        
        let memoryAfter = PerformanceMonitor.getMemoryUsageMB()
        let memoryDelta = memoryAfter - memoryBefore
        
        print("   Memory before: \(String(format: "%.2f", memoryBefore))MB")
        print("   Memory after: \(String(format: "%.2f", memoryAfter))MB")
        print("   Delta: \(String(format: "%.2f", memoryDelta))MB")
        
        // Memory growth should be minimal
        XCTAssertLessThan(memoryDelta, 2.0, "API operations should use < 2MB memory")
    }
    
    // MARK: - Statistics Tracking
    
    /// Test statistics accuracy
    func testStatisticsAccuracy() {
        let expectation = XCTestExpectation(description: "Statistics accuracy")
        let analyzer = DebouncedAnalyzer()
        
        print("📊 Statistics Accuracy:")
        
        analyzer.resetStatistics()
        
        let expectedTriggers = 20
        
        // Trigger known number of requests
        for i in 0..<expectedTriggers {
            let text = String(repeating: "a", count: i + 1)
            analyzer.analyzeText(text) { _ in }
            Thread.sleep(forTimeInterval: 0.05)
        }
        
        // Wait for debounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let stats = analyzer.getStatistics()
            
            print("   Triggers: \(expectedTriggers)")
            print("   Requests: \(stats.requests)")
            print("   Debounced: \(stats.debounced)")
            print("   Total: \(stats.requests + stats.debounced)")
            
            // Statistics should be accurate
            let total = stats.requests + stats.debounced
            XCTAssertEqual(total, expectedTriggers, "Statistics should account for all triggers")
            
            // Reduction percent should be calculated correctly
            let expectedPercent = (Double(stats.debounced) / Double(expectedTriggers)) * 100.0
            XCTAssertEqual(
                stats.reductionPercent,
                expectedPercent,
                accuracy: 0.1,
                "Reduction percent should be accurate"
            )
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    /// Test statistics reset
    func testStatisticsReset() {
        let analyzer = DebouncedAnalyzer()
        
        print("📊 Statistics Reset:")
        
        // Generate some statistics
        for i in 0..<5 {
            analyzer.analyzeText("test\(i)") { _ in }
        }
        
        Thread.sleep(forTimeInterval: 0.3)
        
        let statsBefore = analyzer.getStatistics()
        print("   Before reset - Requests: \(statsBefore.requests), Debounced: \(statsBefore.debounced)")
        
        // Reset
        analyzer.resetStatistics()
        
        let statsAfter = analyzer.getStatistics()
        print("   After reset - Requests: \(statsAfter.requests), Debounced: \(statsAfter.debounced)")
        
        // Should be zeroed
        XCTAssertEqual(statsAfter.requests, 0, "Requests should be reset to 0")
        XCTAssertEqual(statsAfter.debounced, 0, "Debounced should be reset to 0")
        XCTAssertEqual(statsAfter.reductionPercent, 0.0, "Reduction percent should be 0")
    }
}

