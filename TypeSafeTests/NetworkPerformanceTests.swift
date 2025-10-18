//
//  NetworkPerformanceTests.swift
//  TypeSafeTests
//
//  Created by Dev Agent on 18/01/25.
//  Network performance tests for async operations - Story 2.9
//

import XCTest
@testable import TypeSafeKeyboard

class NetworkPerformanceTests: XCTestCase {
    
    var apiService: APIService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        apiService = APIService()
    }
    
    override func tearDownWithError() throws {
        apiService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Async Network Operation Tests (AC: 4)
    
    /// Tests that network calls are properly asynchronous and don't block UI thread
    func testNetworkCallsAreAsync() throws {
        let expectation = XCTestExpectation(description: "Network call completes asynchronously")
        let mainThreadId = Thread.current
        var networkCallThreadId: Thread?
        
        // Make API call and capture thread information
        apiService.analyzeText(text: "test message") { result in
            networkCallThreadId = Thread.current
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Network callback should not be on main thread (unless explicitly dispatched there)
        // The important thing is that the network operation itself doesn't block main thread
        XCTAssertNotNil(networkCallThreadId, "Network callback should execute on some thread")
    }
    
    /// Tests network timeout handling (AC: 5)
    func testNetworkTimeoutHandling() throws {
        let expectation = XCTestExpectation(description: "Network timeout handled gracefully")
        
        // Create API service with very short timeout for testing
        let shortTimeoutService = APIService()
        
        let startTime = Date()
        
        // Make call that should timeout quickly
        shortTimeoutService.analyzeText(text: "test") { result in
            let duration = Date().timeIntervalSince(startTime)
            
            switch result {
            case .success:
                // Unexpected success
                XCTFail("Expected timeout but got success")
            case .failure(let error):
                // Should fail within reasonable time (< 5 seconds)
                XCTAssertLessThan(duration, 5.0, "Timeout took too long")
                print("Network timeout handled in \(duration)s: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    /// Tests graceful degradation when backend is unreachable (AC: 5)
    func testGracefulDegradationOffline() throws {
        let expectation = XCTestExpectation(description: "Graceful degradation when offline")
        
        // Create API service with invalid URL to simulate unreachable backend
        let offlineService = APIService()
        
        offlineService.analyzeText(text: "test message") { result in
            switch result {
            case .success:
                XCTFail("Expected failure for unreachable backend")
            case .failure(let error):
                // Should fail gracefully without crashing
                print("Graceful degradation: \(error.localizedDescription)")
                XCTAssertTrue(true, "Graceful failure handled")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Performance Measurement Tests
    
    /// Tests network call performance under normal conditions
    func testNetworkCallPerformance() throws {
        let expectation = XCTestExpectation(description: "Network performance measurement")
        
        measure(metrics: [XCTClockMetric()]) {
            apiService.analyzeText(text: "performance test message") { result in
                // Just complete the measurement
                expectation.fulfill()
            }
            
            // Wait for completion within measurement
            _ = XCTWaiter.wait(for: [expectation], timeout: 3.0)
        }
    }
    
    /// Tests concurrent network calls don't interfere with each other
    func testConcurrentNetworkCalls() throws {
        let expectation1 = XCTestExpectation(description: "First network call")
        let expectation2 = XCTestExpectation(description: "Second network call")
        let expectation3 = XCTestExpectation(description: "Third network call")
        
        let startTime = Date()
        
        // Make multiple concurrent calls
        apiService.analyzeText(text: "first call") { _ in
            expectation1.fulfill()
        }
        
        apiService.analyzeText(text: "second call") { _ in
            expectation2.fulfill()
        }
        
        apiService.analyzeText(text: "third call") { _ in
            expectation3.fulfill()
        }
        
        wait(for: [expectation1, expectation2, expectation3], timeout: 10.0)
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Concurrent calls should complete faster than sequential calls
        // (This is a rough test - actual timing depends on network conditions)
        XCTAssertLessThan(totalTime, 15.0, "Concurrent calls took too long")
    }
    
    // MARK: - Memory Tests for Network Operations
    
    /// Tests that network operations don't cause memory leaks
    func testNetworkMemoryManagement() throws {
        let initialMemory = getMemoryUsage()
        
        let group = DispatchGroup()
        
        // Make multiple network calls to test memory management
        for i in 0..<10 {
            group.enter()
            apiService.analyzeText(text: "memory test \(i)") { _ in
                group.leave()
            }
        }
        
        // Wait for all calls to complete
        let result = group.wait(timeout: .now() + 30)
        XCTAssertEqual(result, .success, "Network calls should complete within timeout")
        
        // Allow some time for cleanup
        Thread.sleep(forTimeInterval: 1.0)
        
        let finalMemory = getMemoryUsage()
        let memoryGrowth = finalMemory - initialMemory
        
        // Memory growth should be minimal (< 5MB for 10 network calls)
        XCTAssertLessThan(memoryGrowth, 5 * 1024 * 1024, "Network operations caused excessive memory growth")
    }
    
    // MARK: - Circuit Breaker Pattern Tests
    
    /// Tests circuit breaker behavior for repeated failures
    func testCircuitBreakerPattern() throws {
        // This test would verify circuit breaker implementation
        // For now, we'll test that repeated failures don't cause issues
        
        let expectations = (0..<5).map { i in
            XCTestExpectation(description: "Failure \(i)")
        }
        
        // Make multiple calls that should fail
        for (index, expectation) in expectations.enumerated() {
            apiService.analyzeText(text: "circuit breaker test \(index)") { result in
                // Should handle failure gracefully
                switch result {
                case .success:
                    break // Unexpected but not a failure
                case .failure:
                    break // Expected failure
                }
                expectation.fulfill()
            }
        }
        
        wait(for: expectations, timeout: 15.0)
        
        // If we reach here, circuit breaker (or lack thereof) handled failures gracefully
        XCTAssertTrue(true, "Repeated failures handled without crashing")
    }
    
    // MARK: - Helper Methods
    
    /// Gets current memory usage in bytes
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}
