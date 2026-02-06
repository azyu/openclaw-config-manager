import Foundation

/// Dynamic JSON value representation that preserves structure
enum JSONValue: Codable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    // Subscript for object access
    subscript(key: String) -> JSONValue? {
        guard case let .object(object) = self else {
            return nil
        }

        return object[key]
    }

    // Subscript for array access
    subscript(index: Int) -> JSONValue? {
        guard case let .array(array) = self else {
            return nil
        }

        guard array.indices.contains(index) else {
            return nil
        }

        return array[index]
    }

    // Convenience getters
    var stringValue: String? {
        guard case let .string(value) = self else {
            return nil
        }

        return value
    }

    var arrayValue: [JSONValue]? {
        guard case let .array(value) = self else {
            return nil
        }

        return value
    }

    var objectValue: [String: JSONValue]? {
        guard case let .object(value) = self else {
            return nil
        }

        return value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }
}
