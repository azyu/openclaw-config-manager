import Foundation
import XCTest

@testable import OpenClawConfigManager

final class JSONValueTests: XCTestCase {
    private func decodeJSON5(_ string: String) throws -> JSONValue {
        let data = Data(string.utf8)
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        return try decoder.decode(JSONValue.self, from: data)
    }

    func testParsesJSON5WithComments() throws {
        let json5 = #"""
        {
          // This is a comment
          "name": "test"
        }
        """#

        let value = try decodeJSON5(json5)
        XCTAssertEqual(value["name"]?.stringValue, "test")
    }

    func testParsesJSON5WithTrailingCommas() throws {
        let json5 = #"""
        {
          items: [1, 2, 3,],
        }
        """#

        let value = try decodeJSON5(json5)
        let items = value["items"]?.arrayValue
        XCTAssertEqual(items?.count, 3)
    }

    func testParsesJSON5WithUnquotedKeys() throws {
        let json5 = #"""
        {
          foo: "bar",
          nested: { value: 1 }
        }
        """#

        let value = try decodeJSON5(json5)
        XCTAssertEqual(value["foo"]?.stringValue, "bar")
        XCTAssertEqual(value["nested"]?["value"], .number(1))
    }

    func testParsesJSON5WithSingleQuotedStrings() throws {
        let json5 = #"""
        {
          title: 'hello'
        }
        """#

        let value = try decodeJSON5(json5)
        XCTAssertEqual(value["title"]?.stringValue, "hello")
    }

    func testRoundTripJSON5DecodeAndJSONEncode() throws {
        let json5 = #"""
        {
          // comment
          foo: 'bar',
          numbers: [1, 2, 3,],
          nested: { value: 4 }
        }
        """#

        let original = try decodeJSON5(json5)
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testSubscriptAccessForNestedObjects() throws {
        let json5 = #"""
        {
          agents: {
            defaults: {
              model: {
                primary: "anthropic/claude-sonnet-4-20250514"
              }
            }
          }
        }
        """#

        let root = try decodeJSON5(json5)
        let primary = root["agents"]?["defaults"]?["model"]?["primary"]?.stringValue
        XCTAssertEqual(primary, "anthropic/claude-sonnet-4-20250514")
    }
}
