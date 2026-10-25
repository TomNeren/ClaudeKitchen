import Foundation

/// A JSON value that keeps the order of object keys when encoded. Used for request bodies whose key order matters,
/// such as a structured-output schema, where the model fills properties in the order they are listed.
public indirect enum JSONValue: Sendable, Equatable, Encodable {
    case object([(String, JSONValue)])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case integer(Int)
    case bool(Bool)
    case null

    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.object(let left), .object(let right)):
            return left.map(\.0) == right.map(\.0) && left.map(\.1) == right.map(\.1)
        case (.array(let left), .array(let right)): return left == right
        case (.string(let left), .string(let right)): return left == right
        case (.number(let left), .number(let right)): return left == right
        case (.integer(let left), .integer(let right)): return left == right
        case (.bool(let left), .bool(let right)): return left == right
        case (.null, .null): return true
        default: return false
        }
    }

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .object(let members):
            var container = encoder.container(keyedBy: Key.self)
            for (key, value) in members {
                try container.encode(value, forKey: Key(stringValue: key))
            }
        case .array(let values):
            var container = encoder.unkeyedContainer()
            for value in values {
                try container.encode(value)
            }
        case .string(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .number(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .integer(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .bool(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }

    /// The members of an object, or nil.
    public var members: [(String, JSONValue)]? {
        if case .object(let members) = self { members } else { nil }
    }
}
