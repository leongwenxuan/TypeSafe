//
//  AgentProgress.swift
//  TypeSafe
//
//  Story 8.11: iOS App Agent Progress Display
//  Data models for agent progress tracking via WebSocket
//

import Foundation

// MARK: - WebSocket Progress Message

/// Progress message received from agent WebSocket stream
struct ProgressMessage: Codable {
    /// Current step in agent workflow
    let step: String?
    
    /// Optional tool name for UI mapping
    let tool: String?
    
    /// Human-readable progress message
    let message: String
    
    /// Completion percentage (0-100)
    let percent: Int
    
    /// ISO-8601 timestamp
    let timestamp: String?
    
    /// Error indicator
    let error: Bool?
    
    /// Heartbeat indicator (for keep-alive)
    let heartbeat: Bool?
}

// MARK: - Agent Analysis Result

/// Final result from agent analysis with full evidence breakdown
struct AgentAnalysisResult: Codable {
    /// Unique task identifier
    let taskId: String
    
    /// Risk level: "low", "medium", "high"
    let riskLevel: String
    
    /// Confidence score (0-100)
    let confidence: Double
    
    /// Entities found during extraction
    let entitiesFound: EntitiesFound?
    
    /// Evidence collected from tools
    let evidence: [ToolEvidence]
    
    /// Agent reasoning/explanation
    let reasoning: String
    
    /// Processing time in milliseconds
    let processingTimeMs: Int?
    
    /// List of tools used
    let toolsUsed: [String]
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case riskLevel = "risk_level"
        case confidence
        case entitiesFound = "entities_found"
        case evidence
        case reasoning
        case processingTimeMs = "processing_time_ms"
        case toolsUsed = "tools_used"
    }
}

/// Entities found during extraction
struct EntitiesFound: Codable {
    let phones: [String]
    let urls: [String]
    let emails: [String]
}

/// Evidence collected from a tool execution
struct ToolEvidence: Codable, Identifiable {
    var id: String { "\(toolName)_\(entityValue)_\(UUID().uuidString)" }
    
    /// Name of the tool that collected evidence
    let toolName: String
    
    /// Type of entity investigated
    let entityType: String
    
    /// Value of the entity
    let entityValue: String
    
    /// Tool execution result
    let result: ToolResult
    
    /// Whether tool executed successfully
    let success: Bool
    
    /// Execution time in milliseconds
    let executionTimeMs: Double?
    
    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case entityType = "entity_type"
        case entityValue = "entity_value"
        case result
        case success
        case executionTimeMs = "execution_time_ms"
    }
}

/// Generic tool result structure
struct ToolResult: Codable {
    // Dynamic fields - can contain different data depending on tool
    let data: [String: AnyCodable]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: AnyCodable].self)
        self.data = dict
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
}

// MARK: - UI Display Models

/// Tool result for display in UI
struct ToolResultDisplay: Identifiable {
    let id = UUID()
    let toolName: String
    let entityValue: String
    let summary: String
    let icon: String
    let isSuccess: Bool
    let timestamp: Date
}

/// Progress step for UI display
struct ProgressStep: Identifiable {
    let id = UUID()
    let step: String
    let message: String
    let timestamp: Date
    let isComplete: Bool
}

// MARK: - Helper for Dynamic JSON

/// Wrapper for any codable value (handles dynamic JSON structures)
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Extensions

extension AgentAnalysisResult {
    /// User-friendly risk level title
    var riskTitle: String {
        switch riskLevel.lowercased() {
        case "high":
            return "High Risk Detected"
        case "medium":
            return "Medium Risk Detected"
        case "low":
            return "Low Risk - Looks Safe"
        default:
            return "Analysis Complete"
        }
    }
    
    /// Risk level color
    var riskColor: String {
        switch riskLevel.lowercased() {
        case "high":
            return "red"
        case "medium":
            return "orange"
        case "low":
            return "green"
        default:
            return "gray"
        }
    }
    
    /// Count of entities found
    var totalEntitiesFound: Int {
        guard let entities = entitiesFound else { return 0 }
        return entities.phones.count + entities.urls.count + entities.emails.count
    }
}

extension ProgressMessage {
    /// Whether this message indicates completion
    var isCompleted: Bool {
        return step == "completed"
    }
    
    /// Whether this message indicates failure
    var isFailed: Bool {
        return step == "failed" || error == true
    }
    
    /// Whether this is a heartbeat message
    var isHeartbeat: Bool {
        return heartbeat == true
    }
}

