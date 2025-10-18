//
//  TextSnippetManager.swift
//  TypeSafeKeyboard
//
//  Manages text snippet capture with a sliding window buffer.
//  Triggers analysis based on typing patterns (spaces, punctuation, character thresholds).
//

import Foundation

/// Represents a captured text snippet ready for analysis
struct TextSnippet {
    let content: String
    let timestamp: Date
    let shouldAnalyze: Bool
    let triggerReason: TriggerReason
}

/// Reasons why snippet analysis was triggered
enum TriggerReason {
    case significantPause    // Space or punctuation detected
    case characterThreshold  // Every 30 characters
    case manualTrigger      // Explicit user action (future use)
}

/// Manages text snippet capture with sliding window and trigger detection
class TextSnippetManager {
    
    // MARK: - Properties
    
    /// Current text buffer (sliding window) - using StringBuilder for efficiency (Story 2.9)
    private var buffer: String = ""
    
    /// Count of characters typed since last analysis trigger
    private var charactersSinceLastTrigger: Int = 0
    
    /// Maximum buffer size (characters) - optimized for memory efficiency (Story 2.9)
    private let maxBufferSize: Int = 120  // Reduced from 150 for better memory usage
    
    /// Character threshold for automatic trigger - optimized for performance (Story 2.9)
    private let triggerThreshold: Int = 25  // Reduced from 30 for more frequent analysis
    
    /// Minimum characters required before triggering analysis
    private let minCharactersForAnalysis: Int = 5
    
    /// Characters that trigger analysis (space and common punctuation)
    private let triggerCharacters: Set<Character> = [" ", ".", "!", "?", ","]
    
    // Performance optimization properties (Story 2.9)
    private var bufferCapacity: Int = 150  // Reserve capacity to avoid frequent reallocations
    
    // MARK: - Public Methods
    
    /// Appends a character to the buffer and checks if analysis should be triggered
    /// - Parameter character: The character to append
    /// - Returns: TextSnippet if analysis should be triggered, nil otherwise
    func append(_ character: String) -> TextSnippet? {
        // Performance optimization: Reserve capacity if buffer is empty (Story 2.9)
        if buffer.isEmpty {
            buffer.reserveCapacity(bufferCapacity)
        }
        
        // Append to buffer
        buffer.append(character)
        charactersSinceLastTrigger += 1
        
        // Performance optimization: More efficient sliding window (Story 2.9)
        if buffer.count > maxBufferSize {
            // Calculate how much to remove (remove in chunks for efficiency)
            let excessCount = buffer.count - maxBufferSize
            let removeCount = max(excessCount, maxBufferSize / 4) // Remove at least 25% when trimming
            
            // Use more efficient string manipulation
            let startIndex = buffer.index(buffer.startIndex, offsetBy: removeCount)
            buffer = String(buffer[startIndex...])
        }
        
        // Check if we should trigger analysis
        if let triggerReason = checkTriggerCondition(for: character) {
            return createSnippet(triggerReason: triggerReason)
        }
        
        return nil
    }
    
    /// Removes the last character from the buffer (backspace handling)
    /// - Returns: true if buffer was modified, false if buffer was empty
    func deleteLastCharacter() -> Bool {
        guard !buffer.isEmpty else { return false }
        
        buffer.removeLast()
        
        // Decrement counter but don't go negative
        if charactersSinceLastTrigger > 0 {
            charactersSinceLastTrigger -= 1
        }
        
        return true
    }
    
    /// Checks if a character should trigger analysis
    /// - Parameter character: The character to check
    /// - Returns: true if character triggers analysis
    func shouldTriggerAnalysis(_ character: String) -> Bool {
        return checkTriggerCondition(for: character) != nil
    }
    
    /// Returns the current buffer content
    /// - Returns: Current text in buffer (up to 150 characters)
    func getCurrentSnippet() -> String {
        return buffer
    }
    
    /// Clears the buffer and resets counters
    func clear() {
        buffer = ""
        charactersSinceLastTrigger = 0
    }
    
    /// Performance optimization: Clears buffer and releases memory (Story 2.9)
    func clearAndReleaseMemory() {
        buffer.removeAll(keepingCapacity: false)  // Release memory
        charactersSinceLastTrigger = 0
    }
    
    /// Performance optimization: Returns current memory usage estimate (Story 2.9)
    func getMemoryUsageEstimate() -> Int {
        return buffer.utf8.count + MemoryLayout<Int>.size * 2  // Buffer + counters
    }
    
    // MARK: - Private Methods
    
    /// Checks trigger conditions and returns trigger reason if met
    /// - Parameter character: The character that was just typed
    /// - Returns: TriggerReason if conditions are met, nil otherwise
    private func checkTriggerCondition(for character: String) -> TriggerReason? {
        // Don't trigger if buffer is too small
        guard buffer.count >= minCharactersForAnalysis else { return nil }
        
        // Check for significant pause (space or punctuation)
        if character.count == 1, let char = character.first, triggerCharacters.contains(char) {
            charactersSinceLastTrigger = 0
            return .significantPause
        }
        
        // Check for character threshold
        if charactersSinceLastTrigger >= triggerThreshold {
            charactersSinceLastTrigger = 0
            return .characterThreshold
        }
        
        return nil
    }
    
    /// Creates a TextSnippet from current buffer
    /// - Parameter triggerReason: The reason why snippet was created
    /// - Returns: TextSnippet ready for analysis
    private func createSnippet(triggerReason: TriggerReason) -> TextSnippet {
        return TextSnippet(
            content: buffer,
            timestamp: Date(),
            shouldAnalyze: true,
            triggerReason: triggerReason
        )
    }
}

