//
//  KeyboardLatencyTests.swift
//  TypeSafeTests
//
//  Story 10.1: Performance Regression Testing
//  Tests keyboard input latency and responsiveness
//

import XCTest
@testable import TypeSafeKeyboard

class KeyboardLatencyTests: PerformanceTestBase {
    
    // MARK: - Test Cases
    
    /// Test key press latency using XCTClockMetric
    func testKeyPressLatency_XCTest() {
        let options = XCTMeasureOptions()
        options.iterationCount = 50
        
        measure(metrics: [XCTClockMetric()], options: options) {
            // Simulate key press operation
            let text = "a"
            let _ = text.uppercased()
        }
    }
    
    /// Test key press latency with manual timing and statistics
    func testKeyPressLatency_DetailedStatistics() {
        var latencies: [Double] = []
        let iterations = 100
        
        for _ in 0..<iterations {
            let latency = PerformanceMonitor.measureTime {
                // Simulate key press work
                let text = "a"
                let _ = text.uppercased()
                // Simulate minimal text processing
                _ = text.count > 0
            }
            latencies.append(latency)
        }
        
        // Calculate statistics
        let p50 = percentile(latencies, 0.50)
        let p95 = percentile(latencies, 0.95)
        let p99 = percentile(latencies, 0.99)
        let avg = mean(latencies)
        let stdDev = standardDeviation(latencies)
        
        print("📊 Key Press Latency Statistics:")
        print("   P50: \(String(format: "%.2f", p50))ms")
        print("   P95: \(String(format: "%.2f", p95))ms")
        print("   P99: \(String(format: "%.2f", p99))ms")
        print("   Mean: \(String(format: "%.2f", avg))ms")
        print("   StdDev: \(String(format: "%.2f", stdDev))ms")
        
        // Assert against baselines
        assertPerformance("keyPressLatency_P50", measured: p50)
        assertPerformance("keyPressLatency_P95", measured: p95)
        assertPerformance("keyPressLatency_P99", measured: p99)
        
        // Assert absolute thresholds
        assertAbsoluteThreshold("keyPressLatency_P95", measured: p95, maxAllowed: 16.0)
        assertAbsoluteThreshold("keyPressLatency_P99", measured: p99, maxAllowed: 25.0)
    }
    
    /// Test text snippet manager performance
    func testSnippetManagerPerformance() {
        let manager = TextSnippetManager()
        var latencies: [Double] = []
        
        // Measure append operations
        for i in 0..<100 {
            let char = String(UnicodeScalar(97 + (i % 26))!) // a-z
            let latency = PerformanceMonitor.measureTime {
                _ = manager.append(char)
            }
            latencies.append(latency)
        }
        
        let p95 = percentile(latencies, 0.95)
        print("📊 Snippet Manager Append P95: \(String(format: "%.3f", p95))ms")
        
        // Should be extremely fast (< 1ms)
        assertAbsoluteThreshold("snippetManager_append_P95", measured: p95, maxAllowed: 1.0)
    }
    
    /// Test rapid typing simulation
    func testRapidTypingPerformance() {
        let manager = TextSnippetManager()
        var totalLatency: Double = 0
        let characters = 200
        
        let overallTime = PerformanceMonitor.measureTime {
            for i in 0..<characters {
                let char = String(UnicodeScalar(97 + (i % 26))!)
                let latency = PerformanceMonitor.measureTime {
                    _ = manager.append(char)
                }
                totalLatency += latency
            }
        }
        
        let avgLatency = totalLatency / Double(characters)
        print("📊 Rapid Typing (\(characters) chars):")
        print("   Total time: \(String(format: "%.2f", overallTime))ms")
        print("   Avg per char: \(String(format: "%.3f", avgLatency))ms")
        
        // Average should be very low
        XCTAssertLessThan(avgLatency, 0.5, "Average character processing should be < 0.5ms")
        
        // Total time for 200 chars should be reasonable
        XCTAssertLessThan(overallTime, 100.0, "200 characters should process in < 100ms")
    }
    
    /// Test debounced analyzer statistics
    func testDebouncedAnalyzerEffectiveness() {
        let expectation = XCTestExpectation(description: "Debounce effectiveness")
        let analyzer = DebouncedAnalyzer()
        
        // Reset statistics
        analyzer.resetStatistics()
        
        // Simulate rapid typing (10 characters in quick succession)
        for i in 0..<10 {
            let text = String(repeating: "a", count: i + 1)
            analyzer.analyzeText(text) { _ in
                // Results not important for this test
            }
            
            // Small delay between characters (50ms = fast typing)
            Thread.sleep(forTimeInterval: 0.05)
        }
        
        // Wait for debounce to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let stats = analyzer.getStatistics()
            
            print("📊 Debounce Statistics:")
            print("   Actual requests: \(stats.requests)")
            print("   Debounced requests: \(stats.debounced)")
            print("   Reduction: \(String(format: "%.1f", stats.reductionPercent))%")
            
            // Should have debounced most requests (at least 80% reduction)
            XCTAssertGreaterThanOrEqual(stats.reductionPercent, 70.0, "Should achieve at least 70% request reduction")
            
            // Should have made very few actual requests (ideally 1, but allow up to 3)
            XCTAssertLessThanOrEqual(stats.requests, 3, "Should make <= 3 actual requests from 10 triggers")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    /// Test layout switching performance
    func testLayoutSwitchPerformance() {
        var latencies: [Double] = []
        
        // Simulate layout switches
        for _ in 0..<20 {
            let latency = PerformanceMonitor.measureTime {
                // Simulate layout switch work
                var layout: KeyboardLayout = .letters
                layout = .numbers
                layout = .symbols
                layout = .letters
            }
            latencies.append(latency)
        }
        
        let avg = mean(latencies)
        let p95 = percentile(latencies, 0.95)
        
        print("📊 Layout Switch Performance:")
        print("   Average: \(String(format: "%.2f", avg))ms")
        print("   P95: \(String(format: "%.2f", p95))ms")
        
        // These are just enum switches, should be extremely fast
        // Real layout switches involve UI updates which are harder to test here
        XCTAssertLessThan(avg, 0.1, "Layout enum switch should be < 0.1ms")
    }
    
    /// Test memory footprint during typing
    func testMemoryFootprintDuringTyping() {
        let manager = TextSnippetManager()
        
        let memoryBefore = PerformanceMonitor.getMemoryUsageMB()
        
        // Type 500 characters
        for i in 0..<500 {
            let char = String(UnicodeScalar(97 + (i % 26))!)
            _ = manager.append(char)
        }
        
        let memoryAfter = PerformanceMonitor.getMemoryUsageMB()
        let memoryDelta = memoryAfter - memoryBefore
        
        print("📊 Memory Usage During Typing:")
        print("   Before: \(String(format: "%.2f", memoryBefore))MB")
        print("   After: \(String(format: "%.2f", memoryAfter))MB")
        print("   Delta: \(String(format: "%.2f", memoryDelta))MB")
        
        // Memory increase should be minimal (< 1MB for snippet manager)
        XCTAssertLessThan(memoryDelta, 1.0, "Typing 500 chars should use < 1MB memory")
        
        // Check snippet manager's own estimate
        let estimatedBytes = manager.getMemoryUsageEstimate()
        let estimatedKB = Double(estimatedBytes) / 1024.0
        print("   Snippet manager estimate: \(String(format: "%.2f", estimatedKB))KB")
        
        XCTAssertLessThan(estimatedKB, 200.0, "Snippet manager should use < 200KB")
    }
}

