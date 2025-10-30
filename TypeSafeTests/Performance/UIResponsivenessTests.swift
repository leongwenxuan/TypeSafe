//
//  UIResponsivenessTests.swift
//  TypeSafeTests
//
//  Story 10.3: Performance Regression Testing
//  Tests UI performance, frame rate, and animation smoothness
//

import XCTest
@testable import TypeSafeKeyboard

class UIResponsivenessTests: PerformanceTestBase {
    
    // MARK: - Layout Performance Tests
    
    /// Test layout switching performance
    func testLayoutSwitchTiming() {
        var latencies: [Double] = []
        
        print("📊 Layout Switch Timing (60 switches):")
        
        // Test layout enum switching (lightweight operation)
        for _ in 0..<20 {
            let latency = PerformanceMonitor.measureTime {
                var layout: KeyboardLayout = .letters
                layout = .numbers
                layout = .symbols
                layout = .letters
            }
            latencies.append(latency)
        }
        
        let avg = mean(latencies)
        let p95 = percentile(latencies, 0.95)
        let p99 = percentile(latencies, 0.99)
        
        print("   Average: \(String(format: "%.3f", avg))ms")
        print("   P95: \(String(format: "%.3f", p95))ms")
        print("   P99: \(String(format: "%.3f", p99))ms")
        
        // Assert against baseline
        assertPerformance("layoutSwitch_time", measured: p95)
        
        // Layout enum switch should be nearly instant (< 0.1ms)
        assertAbsoluteThreshold("layoutSwitch_enum", measured: p95, maxAllowed: 0.1)
    }
    
    /// Test UI update frequency during rapid operations
    func testRapidOperationUIResponsiveness() {
        let manager = TextSnippetManager()
        var operationLatencies: [Double] = []
        
        print("📊 Rapid Operation UI Responsiveness (100 operations):")
        
        // Simulate 100 rapid operations
        let totalTime = PerformanceMonitor.measureTime {
            for i in 0..<100 {
                let opLatency = PerformanceMonitor.measureTime {
                    let char = String(UnicodeScalar(97 + (i % 26))!)
                    _ = manager.append(char)
                    // Simulate minimal UI update check
                    _ = manager.getCurrentSnippet().count > 0
                }
                operationLatencies.append(opLatency)
            }
        }
        
        let avgLatency = mean(operationLatencies)
        let p95Latency = percentile(operationLatencies, 0.95)
        
        print("   Total time: \(String(format: "%.2f", totalTime))ms")
        print("   Average per op: \(String(format: "%.3f", avgLatency))ms")
        print("   P95 per op: \(String(format: "%.3f", p95Latency))ms")
        
        // Each operation should be fast enough to maintain 60 FPS (< 16ms)
        XCTAssertLessThan(p95Latency, 16.0, "Operations should be < 16ms to maintain 60 FPS")
        
        // Average should be much lower
        XCTAssertLessThan(avgLatency, 1.0, "Average operation time should be < 1ms")
    }
    
    // MARK: - Frame Rate Tests
    
    /// Test sustained operation rate (simulating frame rate)
    func testSustainedOperationRate() {
        let manager = TextSnippetManager()
        let targetFPS = 60.0
        let frameTime = 1000.0 / targetFPS // ~16.67ms
        var frames: [Double] = []
        
        print("📊 Sustained Operation Rate (60 frames):")
        print("   Target frame time: \(String(format: "%.2f", frameTime))ms")
        
        // Simulate 60 frames of work
        for i in 0..<60 {
            let frameLatency = PerformanceMonitor.measureTime {
                // Simulate frame work
                let char = String(UnicodeScalar(97 + (i % 26))!)
                _ = manager.append(char)
                _ = manager.getCurrentSnippet()
            }
            frames.append(frameLatency)
        }
        
        let avgFrameTime = mean(frames)
        let p95FrameTime = percentile(frames, 0.95)
        let maxFrameTime = frames.max() ?? 0
        
        // Count frame drops (frames that exceeded 16.67ms)
        let droppedFrames = frames.filter { $0 > frameTime }.count
        let dropRate = Double(droppedFrames) / Double(frames.count) * 100.0
        
        print("   Average frame time: \(String(format: "%.2f", avgFrameTime))ms")
        print("   P95 frame time: \(String(format: "%.2f", p95FrameTime))ms")
        print("   Max frame time: \(String(format: "%.2f", maxFrameTime))ms")
        print("   Frame drops: \(droppedFrames)/60 (\(String(format: "%.1f", dropRate))%)")
        
        // Assert against baseline
        assertPerformance("frameRate_avgFPS", measured: 1000.0 / avgFrameTime)
        
        // Should maintain 60 FPS (< 5% frame drops)
        XCTAssertLessThan(dropRate, 5.0, "Frame drop rate should be < 5%")
        
        // P95 should be under frame budget
        XCTAssertLessThan(p95FrameTime, frameTime, "P95 frame time should be < 16.67ms")
    }
    
    /// Test frame stability (low variance)
    func testFrameStability() {
        let manager = TextSnippetManager()
        var frameLatencies: [Double] = []
        
        // Measure frame consistency
        for i in 0..<100 {
            let latency = PerformanceMonitor.measureTime {
                let char = String(UnicodeScalar(97 + (i % 26))!)
                _ = manager.append(char)
            }
            frameLatencies.append(latency)
        }
        
        let avg = mean(frameLatencies)
        let stdDev = standardDeviation(frameLatencies)
        let coefficientOfVariation = (stdDev / avg) * 100.0
        
        print("📊 Frame Stability:")
        print("   Average: \(String(format: "%.3f", avg))ms")
        print("   Std Dev: \(String(format: "%.3f", stdDev))ms")
        print("   Coefficient of Variation: \(String(format: "%.1f", coefficientOfVariation))%")
        
        // Low variance indicates stable performance
        // CoV < 50% is considered stable
        XCTAssertLessThan(coefficientOfVariation, 50.0, "Frame timing should be stable (CoV < 50%)")
    }
    
    // MARK: - Main Thread Performance
    
    /// Test that operations don't block main thread
    func testMainThreadUtilization() {
        print("📊 Main Thread Utilization Test:")
        print("   (Note: This is a simplified simulation)")
        
        let manager = TextSnippetManager()
        var mainThreadWork: [Double] = []
        
        // Simulate operations and measure time
        for i in 0..<50 {
            let workTime = PerformanceMonitor.measureTime {
                // Synchronous work that would happen on main thread
                let char = String(UnicodeScalar(97 + (i % 26))!)
                _ = manager.append(char)
                _ = manager.getCurrentSnippet()
            }
            mainThreadWork.append(workTime)
        }
        
        let totalWork = mainThreadWork.reduce(0, +)
        let avgWork = mean(mainThreadWork)
        let maxWork = mainThreadWork.max() ?? 0
        
        print("   Total work: \(String(format: "%.2f", totalWork))ms")
        print("   Avg per operation: \(String(format: "%.3f", avgWork))ms")
        print("   Max operation: \(String(format: "%.3f", maxWork))ms")
        
        // Each operation should be minimal
        XCTAssertLessThan(avgWork, 1.0, "Average main thread work should be < 1ms")
        XCTAssertLessThan(maxWork, 5.0, "Max main thread work should be < 5ms")
    }
    
    // MARK: - UI Element Performance
    
    /// Test performance of UI-related operations
    func testUIOperationPerformance() {
        var operations: [String: Double] = [:]
        
        print("📊 UI Operation Performance:")
        
        // Test string operations (common in UI)
        let stringOpTime = PerformanceMonitor.measureTime {
            var text = ""
            for i in 0..<100 {
                text += String(UnicodeScalar(97 + (i % 26))!)
            }
            _ = text.count
        }
        operations["stringOps"] = stringOpTime
        print("   String operations (100 appends): \(String(format: "%.2f", stringOpTime))ms")
        
        // Test array operations
        let arrayOpTime = PerformanceMonitor.measureTime {
            var array: [String] = []
            for i in 0..<100 {
                array.append(String(UnicodeScalar(97 + (i % 26))!))
            }
            _ = array.count
        }
        operations["arrayOps"] = arrayOpTime
        print("   Array operations (100 appends): \(String(format: "%.2f", arrayOpTime))ms")
        
        // Test dictionary operations
        let dictOpTime = PerformanceMonitor.measureTime {
            var dict: [String: Int] = [:]
            for i in 0..<100 {
                let key = String(UnicodeScalar(97 + (i % 26))!)
                dict[key] = i
            }
            _ = dict.count
        }
        operations["dictOps"] = dictOpTime
        print("   Dictionary operations (100 inserts): \(String(format: "%.2f", dictOpTime))ms")
        
        // All operations should be fast
        for (name, time) in operations {
            XCTAssertLessThan(time, 10.0, "\(name) should complete in < 10ms")
        }
    }
    
    // MARK: - Animation Performance
    
    /// Test simulated animation timing
    func testAnimationTiming() {
        print("📊 Animation Timing (simulated):")
        
        var frames: [Double] = []
        let animationDuration = 0.3 // 300ms animation
        let fps = 60.0
        let expectedFrames = Int(animationDuration * fps) // ~18 frames
        
        // Simulate animation frames
        for i in 0..<expectedFrames {
            let frameWork = PerformanceMonitor.measureTime {
                // Simulate frame calculation
                let progress = Double(i) / Double(expectedFrames)
                let eased = 1.0 - pow(1.0 - progress, 3.0) // Ease-out cubic
                _ = eased
            }
            frames.append(frameWork)
        }
        
        let avgFrameTime = mean(frames)
        let maxFrameTime = frames.max() ?? 0
        let targetFrameTime = 1000.0 / fps
        
        print("   Frames: \(frames.count)")
        print("   Avg frame time: \(String(format: "%.3f", avgFrameTime))ms")
        print("   Max frame time: \(String(format: "%.3f", maxFrameTime))ms")
        print("   Target: < \(String(format: "%.2f", targetFrameTime))ms")
        
        // Animation frames should be smooth
        XCTAssertLessThan(maxFrameTime, targetFrameTime, "Animation frames should be < 16.67ms")
    }
    
    // MARK: - Responsive Gesture Handling
    
    /// Test rapid input handling (simulating fast typing)
    func testRapidInputHandling() {
        let manager = TextSnippetManager()
        var inputLatencies: [Double] = []
        
        print("📊 Rapid Input Handling (200 inputs at 200 CPM):")
        
        let overallTime = PerformanceMonitor.measureTime {
            // Simulate 200 CPM (characters per minute) = 3.33 CPS
            // That's ~300ms between characters, which is fast typing
            for i in 0..<200 {
                let inputLatency = PerformanceMonitor.measureTime {
                    let char = String(UnicodeScalar(97 + (i % 26))!)
                    _ = manager.append(char)
                }
                inputLatencies.append(inputLatency)
            }
        }
        
        let avgLatency = mean(inputLatencies)
        let p95Latency = percentile(inputLatencies, 0.95)
        let p99Latency = percentile(inputLatencies, 0.99)
        
        print("   Total time: \(String(format: "%.2f", overallTime))ms")
        print("   Avg latency: \(String(format: "%.3f", avgLatency))ms")
        print("   P95 latency: \(String(format: "%.3f", p95Latency))ms")
        print("   P99 latency: \(String(format: "%.3f", p99Latency))ms")
        
        // Should handle rapid input smoothly
        assertAbsoluteThreshold("rapidInput_P95", measured: p95Latency, maxAllowed: 2.0)
        
        // Total time should be reasonable (mostly overhead, not actual work)
        XCTAssertLessThan(overallTime, 200.0, "200 inputs should complete in < 200ms")
    }
    
    // MARK: - UI Update Batching
    
    /// Test performance with batched updates
    func testBatchedUpdatePerformance() {
        let manager = TextSnippetManager()
        
        print("📊 Batched Update Performance:")
        
        // Single update timing
        let singleTime = PerformanceMonitor.measureTime {
            _ = manager.append("a")
            _ = manager.getCurrentSnippet()
        }
        print("   Single update: \(String(format: "%.3f", singleTime))ms")
        
        // Batched update timing
        let batchTime = PerformanceMonitor.measureTime {
            for i in 0..<10 {
                let char = String(UnicodeScalar(97 + (i % 26))!)
                _ = manager.append(char)
            }
            _ = manager.getCurrentSnippet() // Single read at end
        }
        print("   Batch of 10: \(String(format: "%.3f", batchTime))ms")
        print("   Per operation: \(String(format: "%.3f", batchTime / 10.0))ms")
        
        // Batched should be more efficient than 10x single
        let expectedUnbatched = singleTime * 10.0
        let efficiency = (expectedUnbatched - batchTime) / expectedUnbatched * 100.0
        print("   Efficiency gain: \(String(format: "%.1f", efficiency))%")
        
        XCTAssertGreaterThan(efficiency, 0, "Batching should provide some efficiency gain")
    }
}

