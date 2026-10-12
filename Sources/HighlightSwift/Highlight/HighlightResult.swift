import UIKit

/// The result of a syntax-highlight request.
public struct HighlightResult: Equatable, @unchecked Sendable {
    /// The immutable syntax-highlighted source text.
    public let attributedText: NSAttributedString

    /// Whether highlight.js could not produce a highlighted value.
    public let isUndefined: Bool

    /// Whether highlight.js found illegal matches.
    public let hasIllegal: Bool

    /// The resolved highlight.js language identifier.
    public let language: String

    /// The language relevance score.
    public let relevance: Int

    /// The display name for the resolved language.
    public let languageName: String

    /// The theme background color.
    public let backgroundColor: UIColor

    init(
        attributedText: NSAttributedString,
        highlightJSResult: HLJSResult,
        backgroundColorHex: String
    ) {
        self.attributedText = NSAttributedString(attributedString: attributedText)
        hasIllegal = highlightJSResult.illegal
        language = highlightJSResult.language == "undefined"
            ? "unknown"
            : highlightJSResult.language
        relevance = Int(highlightJSResult.relevance)
        isUndefined = highlightJSResult.value == "undefined"
        languageName = Self.languageName(highlightJSResult)
        backgroundColor = UIColor(cssHex: backgroundColorHex) ?? .clear
    }

    private static func languageName(_ result: HLJSResult) -> String {
        let name: String
        switch result.language {
        case "undefined": return "Unknown"
        case "xml": name = "HTML"
        case "cpp": name = "C++"
        case "csharp": name = "C#"
        case "graphql": name = "GraphQL"
        case "pgsql": name = "PostgreSQL"
        case "javascript": name = "JavaScript"
        case "typescript": name = "TypeScript"
        case "objectivec": name = "Objective-C"
        case "vbnet": name = "Visual Basic .NET"
        case "php-template": name = "PHP Template"
        case "css", "sql", "json", "php", "scss", "toml", "yaml", "wasm":
            name = result.language.uppercased()
        default:
            name = result.language.capitalized
        }
        return name + (result.relevance <= 5 ? "?" : "")
    }
}

private extension UIColor {
    convenience init?(cssHex: String) {
        let value = cssHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("#") else { return nil }
        let digits = String(value.dropFirst())
        guard [3, 4, 6, 8].contains(digits.count),
              let integer = UInt64(digits, radix: 16) else {
            return nil
        }

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        let alpha: UInt64
        switch digits.count {
        case 3:
            red = (integer >> 8) * 17
            green = ((integer >> 4) & 0xF) * 17
            blue = (integer & 0xF) * 17
            alpha = 255
        case 4:
            red = (integer >> 12) * 17
            green = ((integer >> 8) & 0xF) * 17
            blue = ((integer >> 4) & 0xF) * 17
            alpha = (integer & 0xF) * 17
        case 6:
            red = integer >> 16
            green = (integer >> 8) & 0xFF
            blue = integer & 0xFF
            alpha = 255
        case 8:
            red = integer >> 24
            green = (integer >> 16) & 0xFF
            blue = (integer >> 8) & 0xFF
            alpha = integer & 0xFF
        default:
            return nil
        }

        self.init(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: CGFloat(alpha) / 255
        )
    }
}
