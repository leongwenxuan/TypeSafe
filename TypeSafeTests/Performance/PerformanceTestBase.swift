//
//  PerformanceTestBase.swift
//  TypeSafeTests
//
//  Story 10.1: Performance Regression Testing
//  Base class for performance tests with baseline comparison
//

import XCTest

class PerformanceTestBase: XCTestCase {
    
    // MARK: - Properties
    
    /// Baseline performance metrics loaded from JSON
    var baselines: [String: Double] = [:]
    
    /// Default regression threshold (20% slower is considered regression)
    let defaultThreshold: Double = 1.2
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        loadBaselines()
    }
    
    // MARK: - Baseline Management
    
    /// Loads baseline metrics from PerformanceBaselines.json
    private func loadBaselines() {
        guard let url = Bundle(for: type(of: self)).url(forResource: "PerformanceBaselines", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONDecoder().decode([String: Double].self, from: data) else {
            print("⚠️ PerformanceTestBase: Could not load baselines - running without baseline comparison")
            return
        }
        baselines = json
        print("✅ PerformanceTestBase: Loaded \(baselines.count) baseline metrics")
    }
    
    // MARK: - Assertion Helpers
    
    /// Asserts that measured performance meets baseline expectations
    /// - Parameters:
    ///   - metricName: Name of the metric being measured
    ///   - measured: Measured value (in ms or MB depending on metric)
    ///   - threshold: Regression threshold (default: 1.2 = 20% slower allowed)
    func assertPerformance(
        _ metricName: String,
        measured: Double,
        threshold: Double? = nil
    ) {
        let effectiveThreshold = threshold ?? defaultThreshold
        
        guard let baseline = baselines[metricName] else {
            // No baseline exists - record the measured value for future comparison
            print("📊 \(metricName): \(String(format: "%.2f", measured)) (no baseline)")
            return
        }
        
        let ratio = measured / baseline
        let percentChange = (ratio - 1.0) * 100.0
        
        print("📊 \(metricName): \(String(format: "%.2f", measured)) vs baseline \(String(format: "%.2f", baseline)) (\(String(format: "%+.1f", percentChange))%)")
        
        XCTAssertLessThan(
            ratio,
            effectiveThreshold,
            "❌ Performance regression detected: \(metricName) is \(String(format: "%.1f", ratio))x baseline (measured: \(String(format: "%.2f", measured)), baseline: \(String(format: "%.2f", baseline)))"
        )
        
        // Bonus: warn if significantly faster (might indicate measurement error)
        if ratio < 0.5 {
            print("⚠️ Warning: \(metricName) is significantly faster than baseline - verify measurement")
        }
    }
    
    /// Asserts absolute threshold (not baseline-relative)
    /// - Parameters:
    ///   - metricName: Name of the metric
    ///   - measured: Measured value
    ///   - maxAllowed: Maximum allowed value
    func assertAbsoluteThreshold(
        _ metricName: String,
        measured: Double,
        maxAllowed: Double
    ) {
        print("📊 \(metricName): \(String(format: "%.2f", measured)) (max: \(String(format: "%.2f", maxAllowed)))")
        
        XCTAssertLessThanOrEqual(
            measured,
            maxAllowed,
            "❌ Absolute threshold exceeded: \(metricName) is \(String(format: "%.2f", measured)) (max allowed: \(String(format: "%.2f", maxAllowed)))"
        )
    }
    
    // MARK: - Statistical Helpers
    
    /// Calculates percentile from sorted array
    /// - Parameters:
    ///   - values: Sorted array of values
    ///   - percentile: Percentile to calculate (0.0 - 1.0)
    /// - Returns: Value at the specified percentile
    func percentile(_ values: [Double], _ percentile: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = Int(Double(sorted.count) * percentile)
        return sorted[min(index, sorted.count - 1)]
    }
    
    /// Calculates mean of array
    func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
    
    /// Calculates standard deviation
    func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let avg = mean(values)
        let variance = values.map { pow($0 - avg, 2) }.reduce(0, +) / Double(values.count - 1)
        return sqrt(variance)
    }
    
    /// Calculates median (P50)
    func median(_ values: [Double]) -> Double {
        return percentile(values, 0.5)
    }
    
    /// Calculates min, max, and range
    func range(_ values: [Double]) -> (min: Double, max: Double, range: Double) {
        guard !values.isEmpty else { return (0, 0, 0) }
        let min = values.min() ?? 0
        let max = values.max() ?? 0
        return (min, max, max - min)
    }
    
    // MARK: - Reporting Helpers
    
    /// Generates a performance report summary
    /// - Parameters:
    ///   - name: Test name
    ///   - values: Measured values
    ///   - unit: Unit of measurement (e.g., "ms", "MB", "%")
    /// - Returns: Formatted report string
    func generateReport(_ name: String, values: [Double], unit: String = "ms") -> String {
        let p50 = percentile(values, 0.50)
        let p95 = percentile(values, 0.95)
        let p99 = percentile(values, 0.99)
        let avg = mean(values)
        let stdDev = standardDeviation(values)
        let (min, max, range) = self.range(values)
        
        var report = "📊 \(name) Performance Report\n"
        report += "   Samples: \(values.count)\n"
        report += "   Min: \(String(format: "%.2f", min))\(unit)\n"
        report += "   P50: \(String(format: "%.2f", p50))\(unit)\n"
        report += "   P95: \(String(format: "%.2f", p95))\(unit)\n"
        report += "   P99: \(String(format: "%.2f", p99))\(unit)\n"
        report += "   Max: \(String(format: "%.2f", max))\(unit)\n"
        report += "   Mean: \(String(format: "%.2f", avg))\(unit)\n"
        report += "   Std Dev: \(String(format: "%.2f", stdDev))\(unit)\n"
        report += "   Range: \(String(format: "%.2f", range))\(unit)\n"
        
        return report
    }
    
    /// Logs detailed statistics for a metric
    /// - Parameters:
    ///   - name: Metric name
    ///   - values: Measured values
    ///   - unit: Unit of measurement
    func logDetailedStats(_ name: String, values: [Double], unit: String = "ms") {
        print(generateReport(name, values: values, unit: unit))
    }
    
    // MARK: - Regression Detection Helpers
    
    /// Checks for regression against baseline
    /// - Parameters:
    ///   - metricName: Metric to check
    ///   - measured: Measured value
    ///   - threshold: Regression threshold (default 20%)
    /// - Returns: True if regression detected
    func hasRegression(_ metricName: String, measured: Double, threshold: Double? = nil) -> Bool {
        let effectiveThreshold = threshold ?? defaultThreshold
        
        guard let baseline = baselines[metricName] else {
            return false // No baseline to compare against
        }
        
        let ratio = measured / baseline
        return ratio >= effectiveThreshold
    }
    
    /// Generates regression report comparing to baseline
    /// - Parameters:
    ///   - metricName: Metric name
    ///   - measured: Measured value
    /// - Returns: Regression report string
    func regressionReport(_ metricName: String, measured: Double) -> String {
        guard let baseline = baselines[metricName] else {
            return "No baseline for \(metricName)"
        }
        
        let ratio = measured / baseline
        let percentChange = (ratio - 1.0) * 100.0
        let status = ratio < 1.0 ? "✅ Improved" : ratio < defaultThreshold ? "✅ Within threshold" : "❌ Regression"
        
        var report = "Metric: \(metricName)\n"
        report += "  Measured: \(String(format: "%.2f", measured))\n"
        report += "  Baseline: \(String(format: "%.2f", baseline))\n"
        report += "  Change: \(String(format: "%+.1f", percentChange))%\n"
        report += "  Status: \(status)\n"
        
        return report
    }
    
    // MARK: - Comparison Helpers
    
    /// Compares two sets of measurements
    /// - Parameters:
    ///   - name1: Name of first set
    ///   - values1: First set of values
    ///   - name2: Name of second set
    ///   - values2: Second set of values
    ///   - unit: Unit of measurement
    func comparePerformance(
        _ name1: String,
        _ values1: [Double],
        _ name2: String,
        _ values2: [Double],
        unit: String = "ms"
    ) {
        let avg1 = mean(values1)
        let avg2 = mean(values2)
        let p95_1 = percentile(values1, 0.95)
        let p95_2 = percentile(values2, 0.95)
        
        let avgDiff = avg2 - avg1
        let p95Diff = p95_2 - p95_1
        let avgPercent = (avgDiff / avg1) * 100.0
        
        print("📊 Performance Comparison:")
        print("   \(name1):")
        print("     Avg: \(String(format: "%.2f", avg1))\(unit)")
        print("     P95: \(String(format: "%.2f", p95_1))\(unit)")
        print("   \(name2):")
        print("     Avg: \(String(format: "%.2f", avg2))\(unit)")
        print("     P95: \(String(format: "%.2f", p95_2))\(unit)")
        print("   Difference:")
        print("     Avg: \(String(format: "%+.2f", avgDiff))\(unit) (\(String(format: "%+.1f", avgPercent))%)")
        print("     P95: \(String(format: "%+.2f", p95Diff))\(unit)")
    }
}

// MARK: - Performance Utilities

/// Utilities for measuring performance
class PerformanceMonitor {
    
    /// Measures execution time of a block
    /// - Parameter block: Code to measure
    /// - Returns: Execution time in milliseconds
    static func measureTime(_ block: () -> Void) -> TimeInterval {
        let start = CFAbsoluteTimeGetCurrent()
        block()
        let end = CFAbsoluteTimeGetCurrent()
        return (end - start) * 1000.0 // Convert to ms
    }
    
    /// Measures memory usage of a block
    /// - Parameter block: Code to measure
    /// - Returns: Memory delta in MB
    static func measureMemory(_ block: () -> Void) -> Double {
        let before = getMemoryUsage()
        block()
        let after = getMemoryUsage()
        let deltaBytes = Int64(after) - Int64(before)
        return Double(deltaBytes) / (1024.0 * 1024.0) // Convert to MB
    }
    
    /// Gets current memory usage
    /// - Returns: Memory usage in bytes
    static func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    /// Gets current memory usage in MB
    static func getMemoryUsageMB() -> Double {
        return Double(getMemoryUsage()) / (1024.0 * 1024.0)
    }
}

