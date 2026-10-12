import Foundation

/// CSS colors and an optional background used for a highlight request.
public struct HighlightColors: Hashable, Sendable {
    public let css: String
    public let background: String

    /// Returns the dark appearance colors for a bundled theme.
    public static func dark(_ theme: HighlightTheme) -> HighlightColors {
        colors(theme, appearance: "dark")
    }

    /// Returns the light appearance colors for a bundled theme.
    public static func light(_ theme: HighlightTheme) -> HighlightColors {
        colors(theme, appearance: "light")
    }

    /// Creates colors from caller-provided highlight.js CSS.
    public static func custom(css: String, background: String = "") -> HighlightColors {
        HighlightColors(
            css: css,
            background: background.isEmpty
                ? HighlightBackground.color(in: css) ?? ""
                : background
        )
    }

    private static func colors(
        _ theme: HighlightTheme,
        appearance: String
    ) -> HighlightColors {
        let resourceName = "\(theme.resourceBaseName)-\(appearance)"
        guard let css = HighlightResource.string(
            named: resourceName,
            extension: "css"
        ) else {
            preconditionFailure("Unable to read bundled highlight theme: \(resourceName).css")
        }
        return HighlightColors(
            css: css,
            background: HighlightBackground.color(in: css) ?? ""
        )
    }
}

enum HighlightResource {
    static func string(named name: String, extension fileExtension: String) -> String? {
        guard let url = Bundle.module.url(forResource: name, withExtension: fileExtension) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
