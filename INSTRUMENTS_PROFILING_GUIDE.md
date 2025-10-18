# Instruments Profiling Guide for TypeSafe Keyboard Extension

## Overview

This guide provides instructions for using Apple's Instruments tool to profile the TypeSafe keyboard extension for performance analysis and optimization.

## Prerequisites

- Xcode with Instruments installed
- Physical iOS device (recommended for accurate performance measurements)
- TypeSafe project configured and building successfully
- Keyboard extension installed on test device

## Profiling Setup

### 1. Configure Xcode for Profiling

1. Open TypeSafe.xcodeproj in Xcode
2. Select the TypeSafe scheme
3. Go to Product → Profile (⌘I) or use the Profile button
4. Choose your target device (physical device recommended)

### 2. Select Instruments Template

For keyboard extension performance analysis, use these templates:

#### Time Profiler (Input Latency Analysis)
- **Purpose**: Measure CPU usage and identify performance bottlenecks
- **Key Metrics**: 
  - Time spent in `keyTapped` method
  - Layout creation overhead
  - Text processing delays
- **Target**: < 16ms per key press for 60fps responsiveness

#### Allocations (Memory Usage Analysis)
- **Purpose**: Track memory allocations and identify leaks
- **Key Metrics**:
  - Total memory usage during typing sessions
  - Memory growth over time
  - Allocation patterns in TextSnippetManager
- **Target**: < 30MB total memory usage, no continuous growth

#### Leaks (Memory Leak Detection)
- **Purpose**: Identify retain cycles and memory leaks
- **Focus Areas**:
  - View controller lifecycle
  - Network request completion handlers
  - Cache management

## Profiling Procedures

### Input Latency Measurement

1. **Start Time Profiler**
   - Launch Instruments with Time Profiler template
   - Target the TypeSafe app on your device
   - Begin recording

2. **Execute Test Scenario**
   - Open any app with text input
   - Switch to TypeSafe keyboard
   - Type a long sentence repeatedly: "The quick brown fox jumps over the lazy dog"
   - Focus on consistent, rapid typing

3. **Analyze Results**
   - Look for `keyTapped` method in call tree
   - Identify methods taking > 16ms
   - Check for main thread blocking operations

### Memory Usage Measurement

1. **Start Allocations Instrument**
   - Launch Instruments with Allocations template
   - Target the TypeSafe app
   - Begin recording

2. **Execute Extended Typing Session**
   - Type continuously for 5+ minutes
   - Include various keyboard layouts (letters, numbers, symbols)
   - Trigger multiple API calls through text analysis

3. **Analyze Results**
   - Monitor total memory usage over time
   - Look for memory growth patterns
   - Identify large allocations in TextSnippetManager

### Performance Baseline Metrics

Based on our optimizations, expected performance targets:

#### Input Latency Targets
- **Key Press Response**: < 16ms (60fps target)
- **Layout Switching**: < 100ms
- **Text Insertion**: < 5ms

#### Memory Usage Targets
- **Idle State**: < 10MB
- **Active Typing**: < 20MB
- **Peak Usage**: < 30MB
- **Memory Growth**: No continuous increase over 10+ minute sessions

#### Network Performance Targets
- **API Call Latency**: < 500ms (95th percentile)
- **Circuit Breaker**: Activate after 5 consecutive failures
- **Background Queue**: All network calls off main thread

## Optimization Verification

### Implemented Optimizations to Verify

1. **Layout Caching**
   - Verify layouts are created once and reused
   - Check cache hit rates in console logs

2. **Deferred Operations**
   - Confirm non-critical operations happen after text insertion
   - Verify main thread is not blocked by snippet processing

3. **Memory Management**
   - Confirm caches are cleared on memory warnings
   - Verify TextSnippetManager buffer stays within limits

4. **Circuit Breaker**
   - Test network failure scenarios
   - Verify graceful degradation when backend is unavailable

## Troubleshooting

### Common Issues

1. **Cannot Profile on Simulator**
   - Use physical device for accurate measurements
   - Simulator performance doesn't reflect real-world usage

2. **Keyboard Extension Not Visible in Instruments**
   - Ensure keyboard is active in a text field
   - Check that extension is properly installed

3. **High Memory Usage**
   - Check for retain cycles in completion handlers
   - Verify caches are being cleared appropriately

### Performance Red Flags

- Key press latency > 50ms consistently
- Memory usage growing continuously during typing
- Main thread blocking for > 16ms
- Network calls blocking UI updates

## Continuous Monitoring

### Automated Performance Tests

The project includes automated performance tests:

- `KeyboardPerformanceTests.swift`: Input latency measurement
- `NetworkPerformanceTests.swift`: API call performance
- `StabilityTests.swift`: Extended session stability

Run these tests regularly:
```bash
xcodebuild test -scheme TypeSafe -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -only-testing:TypeSafeTests/KeyboardPerformanceTests
```

### Performance Regression Detection

Monitor these metrics in CI/CD:
- Test execution time trends
- Memory usage patterns
- Build time increases (indicating code complexity growth)

## Next Steps

1. Establish baseline measurements using this guide
2. Set up regular performance testing in CI/CD pipeline
3. Create performance budgets for key metrics
4. Implement automated alerts for performance regressions
