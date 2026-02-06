import Foundation

enum JSON5TextPatcher {
    
    struct ValueSpan {
        let range: Range<String.Index>
        let quoteStyle: QuoteStyle
    }
    
    enum QuoteStyle {
        case single
        case double
        case none
    }
    
    enum PatchError: Error {
        case pathNotFound(String)
        case invalidStructure
    }
    
    static func patchPrimary(in text: String, newValue: String) throws -> String {
        let path = ["agents", "defaults", "model", "primary"]
        guard let span = findValueSpan(in: text, path: path) else {
            throw PatchError.pathNotFound("agents.defaults.model.primary")
        }
        return replaceValue(in: text, span: span, with: newValue)
    }
    
    static func patchFallbacks(in text: String, newValues: [String]) throws -> String {
        let path = ["agents", "defaults", "model", "fallbacks"]
        guard let span = findArraySpan(in: text, path: path) else {
            throw PatchError.pathNotFound("agents.defaults.model.fallbacks")
        }
        return replaceArray(in: text, span: span, with: newValues)
    }
    
    static func findValueSpan(in text: String, path: [String]) -> ValueSpan? {
        var searchStart = text.startIndex
        
        for (index, key) in path.enumerated() {
            guard let keyRange = findKey(key, in: text, from: searchStart) else {
                return nil
            }
            
            guard let colonIndex = findColon(in: text, after: keyRange.upperBound) else {
                return nil
            }
            
            let afterColon = text.index(after: colonIndex)
            let valueStart = skipWhitespace(in: text, from: afterColon)
            
            if index == path.count - 1 {
                return extractStringValue(in: text, from: valueStart)
            } else {
                guard text[valueStart] == "{" else { return nil }
                searchStart = text.index(after: valueStart)
            }
        }
        return nil
    }
    
    static func findArraySpan(in text: String, path: [String]) -> ValueSpan? {
        var searchStart = text.startIndex
        
        for (index, key) in path.enumerated() {
            guard let keyRange = findKey(key, in: text, from: searchStart) else {
                return nil
            }
            
            guard let colonIndex = findColon(in: text, after: keyRange.upperBound) else {
                return nil
            }
            
            let afterColon = text.index(after: colonIndex)
            let valueStart = skipWhitespace(in: text, from: afterColon)
            
            if index == path.count - 1 {
                guard text[valueStart] == "[" else { return nil }
                guard let end = findMatchingBracket(in: text, from: valueStart) else { return nil }
                let range = valueStart..<text.index(after: end)
                return ValueSpan(range: range, quoteStyle: .single)
            } else {
                guard text[valueStart] == "{" else { return nil }
                searchStart = text.index(after: valueStart)
            }
        }
        return nil
    }
    
    private static func findKey(_ key: String, in text: String, from start: String.Index) -> Range<String.Index>? {
        let patterns = [
            "\"\(key)\"",
            "'\(key)'",
            key
        ]
        
        var earliest: Range<String.Index>?
        for pattern in patterns {
            if let range = text.range(of: pattern, range: start..<text.endIndex) {
                if earliest == nil || range.lowerBound < earliest!.lowerBound {
                    earliest = range
                }
            }
        }
        return earliest
    }
    
    private static func findColon(in text: String, after start: String.Index) -> String.Index? {
        var index = start
        while index < text.endIndex {
            let char = text[index]
            if char == ":" {
                return index
            } else if !char.isWhitespace {
                return nil
            }
            index = text.index(after: index)
        }
        return nil
    }
    
    private static func skipWhitespace(in text: String, from start: String.Index) -> String.Index {
        var index = start
        while index < text.endIndex && text[index].isWhitespace {
            index = text.index(after: index)
        }
        return index
    }
    
    private static func extractStringValue(in text: String, from start: String.Index) -> ValueSpan? {
        guard start < text.endIndex else { return nil }
        
        let char = text[start]
        if char == "'" || char == "\"" {
            let quote = char
            var index = text.index(after: start)
            while index < text.endIndex {
                if text[index] == quote {
                    let range = start..<text.index(after: index)
                    let style: QuoteStyle = quote == "'" ? .single : .double
                    return ValueSpan(range: range, quoteStyle: style)
                }
                index = text.index(after: index)
            }
        }
        return nil
    }
    
    private static func findMatchingBracket(in text: String, from start: String.Index) -> String.Index? {
        guard text[start] == "[" else { return nil }
        
        var depth = 1
        var index = text.index(after: start)
        var inString = false
        var stringQuote: Character = "\""
        
        while index < text.endIndex && depth > 0 {
            let char = text[index]
            
            if inString {
                if char == stringQuote {
                    inString = false
                }
            } else {
                switch char {
                case "'", "\"":
                    inString = true
                    stringQuote = char
                case "[":
                    depth += 1
                case "]":
                    depth -= 1
                default:
                    break
                }
            }
            
            if depth > 0 {
                index = text.index(after: index)
            }
        }
        
        return depth == 0 ? index : nil
    }
    
    private static func replaceValue(in text: String, span: ValueSpan, with newValue: String) -> String {
        let quote = span.quoteStyle == .single ? "'" : "\""
        let replacement = "\(quote)\(newValue)\(quote)"
        return text.replacingCharacters(in: span.range, with: replacement)
    }
    
    private static func replaceArray(in text: String, span: ValueSpan, with newValues: [String]) -> String {
        let indent = detectArrayIndent(in: text, arrayStart: span.range.lowerBound)
        let itemIndent = indent + "  "
        
        var lines = ["["]
        for value in newValues {
            lines.append("\(itemIndent)\"\(value)\",")
        }
        lines.append("\(indent)]")
        
        let replacement = lines.joined(separator: "\n")
        return text.replacingCharacters(in: span.range, with: replacement)
    }
    
    private static func detectArrayIndent(in text: String, arrayStart: String.Index) -> String {
        var lineStart = arrayStart
        while lineStart > text.startIndex {
            let prevIndex = text.index(before: lineStart)
            if text[prevIndex] == "\n" {
                break
            }
            lineStart = prevIndex
        }
        
        var indent = ""
        var index = lineStart
        while index < arrayStart && text[index].isWhitespace && text[index] != "\n" {
            indent.append(text[index])
            index = text.index(after: index)
        }
        return indent
    }
}
