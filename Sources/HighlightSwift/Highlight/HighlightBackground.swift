import Foundation

enum HighlightBackground {
    static func color(in css: String) -> String? {
        let blockPattern = #"(?s)(?:^|[},\s])\.hljs\s*\{([^}]*)\}"#
        guard let blockExpression = try? NSRegularExpression(pattern: blockPattern),
              let blockMatch = blockExpression.firstMatch(
                  in: css,
                  range: NSRange(css.startIndex..., in: css)
              ),
              let declarationsRange = Range(blockMatch.range(at: 1), in: css) else {
            return nil
        }

        let declarations = String(css[declarationsRange])
        let commentExpression = try? NSRegularExpression(pattern: #"(?s)/\*.*?\*/"#)
        let uncommented = commentExpression?.stringByReplacingMatches(
            in: declarations,
            range: NSRange(declarations.startIndex..., in: declarations),
            withTemplate: ""
        ) ?? declarations
        let propertyPattern = #"(?i)(?:^|;)\s*background(?:-color)?\s*:\s*([^;}]*)"#
        guard let propertyExpression = try? NSRegularExpression(pattern: propertyPattern),
              let propertyMatch = propertyExpression.firstMatch(
                  in: uncommented,
                  range: NSRange(uncommented.startIndex..., in: uncommented)
              ),
              let valueRange = Range(propertyMatch.range(at: 1), in: uncommented) else {
            return nil
        }

        let value = uncommented[valueRange].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
