//
//  MemoryFootprintTests.swift
//  TypeSafeTests
//
//  Story 10.3: Performance Regression Testing
//  Tests memory usage, leak detection, and memory pressure handling
//

import XCTest
@testable import TypeSafeKeyboard

class MemoryFootprintTests: PerformanceTestBase {
    
    // MARK: - Memory Usage Tests
    
    /// Test baseline memory usage at keyboard initialization
    func testBaselineMemoryUsage() {
        let memoryBefore = PerformanceMonitor.getMemoryUsageMB()
        
        // Simulate keyboard initialization
        let manager = TextSnippetManager()
        _ = manager.getCurrentSnippet()
        
        let memoryAfter = PerformanceMonitor.getMemoryUsageMB()
        let memoryUsed = memoryAfter - memoryBefore
        
        print("📊 Baseline Memory Usage:")
        print("   Before: \(String(format: "%.2f", memoryBefore))MB")
        print("   After: \(String(format: "%.2f", memoryAfter))MB")
        print("   Used: \(String(format: "%.2f", memoryUsed))MB")
        
        // Assert against baseline
        assertPerformance("memory_startup", measured: memoryUsed)
        
        // Assert absolute threshold (< 10MB for initialization)
        assertAbsoluteThreshold("memory_startup", measured: memoryUsed, maxAllowed: 10.0)
    }
    
    /// Test memory usage during normal operation (typing session)
    func testNormalOperationMemory() {
        let memoryBefore = PerformanceMonitor.getMemoryUsageMB()
        
        let manager = TextSnippetManager()
        
        // Simulate normal typing (500 characters)
        for i in 0..<500 {
            let char = String(UnicodeScalar(97 + (i % 26))!)
            _ = manager.append(char)
        }
        
        let memoryAfter = PerformanceMonitor.getMemoryUsageMB()
        let memoryUsed = memoryAfter - memoryBefore
        
        print("📊 Normal Operation Memory (500 chars):")
        print("   Before: \(String(format: "%.2f", memoryBefore))MB")
        print("   After: \(String(format: "%.2f", memoryAfter))MB")
        print("   Used: \(String(format: "%.2f", memoryUsed))MB")
        
        // Assert against baseline
        assertPerformance("memory_after500chars", measured: memoryUsed)
        
        // Assert absolute threshold (< 2MB for 500 chars)
        assertAbsoluteThreshold("memory_after500chars", measured: memoryUsed, maxAllowed: 2.0)
    }
    
    /// Test memory usage during extended typing session
    func testExtendedSessionMemory() {
        let manager = TextSnippetManager()
        var memoryReadings: [Double] = []
        
        let initialMemory = PerformanceMonitor.getMemoryUsageMB()
        memoryReadings.append(0) // Baseline
        
        print("📊 Extended Session Memory (1000 chars):")
        print("   Initial: \(String(format: "%.2f", initialMemory))MB")
        
        // Type 1000 characters in chunks of 100, measuring after each chunk
        for chunk in 0..<10 {
            for i in 0..<100 {
                let char = String(UnicodeScalar(97 + (i % 26))!)
                _ = manager.append(char)
            }
            
            let currentMemory = PerformanceMonitor.getMemoryUsageMB()
            let delta = currentMemory - initialMemory
            memoryReadings.append(delta)
            
            print("   After \((chunk + 1) * 100) chars: +\(String(format: "%.2f", delta))MB")
        }
        
        let finalMemory = PerformanceMonitor.getMemoryUsageMB()
        let totalDelta = finalMemory - initialMemory
        
        print("   Final: +\(String(format: "%.2f", totalDelta))MB")
        
        // Memory should not continuously grow (linear growth is ok, but no leaks)
        // Check if growth rate is reasonable
        let avgGrowthPer100Chars = totalDelta / 10.0
        print("   Avg growth per 100 chars: \(String(format: "%.3f", avgGrowthPer100Chars))MB")
        
        // Should be minimal growth per chunk
        XCTAssertLessThan(avgGrowthPer100Chars, 0.2, "Memory growth per 100 chars should be < 0.2MB")
        
        // Total memory increase should be reasonable
        XCTAssertLessThan(totalDelta, 3.0, "Total memory increase for 1000 chars should be < 3MB")
    }
    
    // MARK: - Memory Leak Detection
    
    /// Test for memory leaks by creating and destroying components multiple times
    func testMemoryLeakDetection() {
        let initialMemory = PerformanceMonitor.getMemoryUsageMB()
        var managers: [TextSnippetManager] = []
        
        print("📊 Memory Leak Detection (10 create/destroy cycles):")
        print("   Initial: \(String(format: "%.2f", initialMemory))MB")
        
        // Create and destroy managers 10 times
        for cycle in 0..<10 {
            // Create manager and use it
            let manager = TextSnippetManager()
            for i in 0..<100 {
                let char = String(UnicodeScalar(97 + (i % 26))!)
                _ = manager.append(char)
            }
            
            // Store temporarily to prevent immediate deallocation
            managers.append(manager)
            
            // Clear previous managers to trigger deallocation
            if managers.count > 3 {
                managers.removeFirst()
            }
            
            let currentMemory = PerformanceMonitor.getMemoryUsageMB()
            let delta = currentMemory - initialMemory
            print("   After cycle \(cycle + 1): +\(String(format: "%.2f", delta))MB")
        }
        
        // Clear all managers
        managers.removeAll()
        
        // Force collection
        Thread.sleep(forTimeInterval: 0.1)
        
        let finalMemory = PerformanceMonitor.getMemoryUsageMB()
        let memoryLeak = finalMemory - initialMemory
        
        print("   Final: +\(String(format: "%.2f", memoryLeak))MB")
        
        // Memory leak should be minimal (< 1MB after cleanup)
        XCTAssertLessThan(memoryLeak, 1.0, "Memory leak after 10 cycles should be < 1MB")
    }
    
    /// Test memory cleanup on explicit clear
    func testMemoryCleanupEffectiveness() {
        let manager = TextSnippetManager()
        
        let memoryBefore = PerformanceMonitor.getMemoryUsageMB()
        
        // Fill with data
        for i in 0..<1000 {
            let char = String(UnicodeScalar(97 + (i % 26))!)
            _ = manager.append(char)
        }
        
        let memoryAfterFill = PerformanceMonitor.getMemoryUsageMB()
        let memoryUsed = memoryAfterFill - memoryBefore
        
        print("📊 Memory Cleanup Effectiveness:")
        print("   Before fill: \(String(format: "%.2f", memoryBefore))MB")
        print("   After fill (1000 chars): \(String(format: "%.2f", memoryAfterFill))MB (+\(String(format: "%.2f", memoryUsed))MB)")
        
        // Clear memory
        manager.clearAndReleaseMemory()
        
        // Give system time to reclaim
        Thread.sleep(forTimeInterval: 0.1)
        
        let memoryAfterClear = PerformanceMonitor.getMemoryUsageMB()
        let memoryRecovered = memoryAfterFill - memoryAfterClear
        let recoveryPercent = (memoryRecovered / memoryUsed) * 100.0
        
        print("   After clear: \(String(format: "%.2f", memoryAfterClear))MB (-\(String(format: "%.2f", memoryRecovered))MB)")
        print("   Recovery: \(String(format: "%.1f", recoveryPercent))%")
        
        // Should recover at least 50% of memory (some overhead is acceptable)
        XCTAssertGreaterThan(recoveryPercent, 50.0, "Should recover at least 50% of memory")
    }
    
    // MARK: - Memory Pressure Handling
    
    /// Test memory behavior under simulated pressure
    func testMemoryPressureHandling() {
        let manager = TextSnippetManager()
        
        print("📊 Memory Pressure Handling:")
        
        let memoryBefore = PerformanceMonitor.getMemoryUsageMB()
        print("   Before: \(String(format: "%.2f", memoryBefore))MB")
        
        // Fill with data
        for i in 0..<500 {
            let char = String(UnicodeScalar(97 + (i % 26))!)
            _ = manager.append(char)
        }
        
        let memoryAfterFill = PerformanceMonitor.getMemoryUsageMB()
        print("   After fill: \(String(format: "%.2f", memoryAfterFill))MB")
        
        // Simulate memory warning response
        manager.clearAndReleaseMemory()
        
        // Give system time
        Thread.sleep(forTimeInterval: 0.1)
        
        let memoryAfterCleanup = PerformanceMonitor.getMemoryUsageMB()
        let memoryReduction = memoryAfterFill - memoryAfterCleanup
        
        print("   After cleanup: \(String(format: "%.2f", memoryAfterCleanup))MB")
        print("   Reduction: \(String(format: "%.2f", memoryReduction))MB")
        
        // Should reduce memory usage
        XCTAssertGreaterThan(memoryReduction, 0, "Memory cleanup should reduce usage")
        
        // Should be able to continue working after cleanup
        _ = manager.append("a")
        XCTAssertTrue(manager.getCurrentSnippet().contains("a"), "Should work after cleanup")
    }
    
    // MARK: - Memory Usage Patterns
    
    /// Test memory usage with XCTest's built-in memory metrics
    func testMemoryUsage_XCTest() {
        let options = XCTMeasureOptions()
        options.iterationCount = 10
        
        measure(metrics: [XCTMemoryMetric()], options: options) {
            let manager = TextSnippetManager()
            
            // Simulate typing session
            for i in 0..<500 {
                let char = String(UnicodeScalar(97 + (i % 26))!)
                _ = manager.append(char)
            }
            
            // Clean up
            manager.clearAndReleaseMemory()
        }
    }
    
    /// Test snippet manager's memory estimation accuracy
    func testMemoryEstimationAccuracy() {
        let manager = TextSnippetManager()
        
        let actualBefore = PerformanceMonitor.getMemoryUsage()
        let estimateBefore = manager.getMemoryUsageEstimate()
        
        // Add significant data
        for i in 0..<1000 {
            let char = String(UnicodeScalar(97 + (i % 26))!)
            _ = manager.append(char)
        }
        
        let actualAfter = PerformanceMonitor.getMemoryUsage()
        let estimateAfter = manager.getMemoryUsageEstimate()
        
        let actualDelta = actualAfter - actualBefore
        let estimateDelta = estimateAfter - estimateBefore
        
        print("📊 Memory Estimation Accuracy:")
        print("   Actual delta: \(String(format: "%.2f", Double(actualDelta) / 1024.0))KB")
        print("   Estimate delta: \(String(format: "%.2f", Double(estimateDelta) / 1024.0))KB")
        
        // Estimate should be in the right ballpark (within 2x of actual)
        let ratio = Double(estimateDelta) / Double(actualDelta)
        print("   Ratio: \(String(format: "%.2f", ratio))x")
        
        XCTAssertGreaterThan(ratio, 0.5, "Estimate should be at least 50% of actual")
        XCTAssertLessThan(ratio, 2.0, "Estimate should be at most 200% of actual")
    }
    
    // MARK: - Performance Under Memory Constraints
    
    /// Test that performance remains acceptable under memory constraints
    func testPerformanceUnderMemoryConstraints() {
        let manager = TextSnippetManager()
        var latencies: [Double] = []
        
        print("📊 Performance Under Memory Constraints:")
        
        // Fill memory significantly
        for i in 0..<800 {
            let char = String(UnicodeScalar(97 + (i % 26))!)
            _ = manager.append(char)
        }
        
        // Now measure performance with filled memory
        for i in 0..<50 {
            let char = String(UnicodeScalar(97 + (i % 26))!)
            let latency = PerformanceMonitor.measureTime {
                _ = manager.append(char)
            }
            latencies.append(latency)
        }
        
        let p95 = percentile(latencies, 0.95)
        let avg = mean(latencies)
        
        print("   Average latency: \(String(format: "%.3f", avg))ms")
        print("   P95 latency: \(String(format: "%.3f", p95))ms")
        
        // Should still be performant even with memory filled
        XCTAssertLessThan(p95, 2.0, "P95 latency should remain < 2ms even with filled memory")
    }
}

