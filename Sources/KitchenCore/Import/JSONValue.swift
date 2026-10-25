import Foundation

/// A JSON value that keeps the order of object keys when encoded with `encoded()`. Used for request bodies whose key order matters,
/// such as a structured-output schema, where the model fills properties in the order they are listed.
public indirect enum JSONValue: Sendable, Equatable {
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

    /// The value as JSON text, with object keys in the order they were given.
    /// `JSONEncoder` stores objects in a dictionary and loses that order, so containers are written here
    /// and only scalars go through the encoder, which takes care of escaping and number format.
    public func encoded() throws -> Data {
        var data = Data()
        try write(to: &data)
        return data
    }

    private func write(to data: inout Data) throws {
        switch self {
        case .object(let members):
            data.append(UInt8(ascii: "{"))
            for (index, (key, value)) in members.enumerated() {
                if index > 0 { data.append(UInt8(ascii: ",")) }
                try data.append(JSONEncoder().encode(key))
                data.append(UInt8(ascii: ":"))
                try value.write(to: &data)
            }
            data.append(UInt8(ascii: "}"))
        case .array(let values):
            data.append(UInt8(ascii: "["))
            for (index, value) in values.enumerated() {
                if index > 0 { data.append(UInt8(ascii: ",")) }
                try value.write(to: &data)
            }
            data.append(UInt8(ascii: "]"))
        case .string(let value): try data.append(JSONEncoder().encode(value))
        case .number(let value): try data.append(JSONEncoder().encode(value))
        case .integer(let value): try data.append(JSONEncoder().encode(value))
        case .bool(let value): data.append(contentsOf: Array((value ? "true" : "false").utf8))
        case .null: data.append(contentsOf: Array("null".utf8))
        }
    }

    /// The members of an object, or nil.
    public var members: [(String, JSONValue)]? {
        if case .object(let members) = self { members } else { nil }
    }
}
