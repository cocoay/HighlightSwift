import UIKit

/// Converts source code into syntax-highlighted UIKit attributed strings.
public final class Highlight: Sendable {
    private let hljs = HLJS()

    public init() {}

    /// Highlights source code using automatic language detection.
    public func attributedText(
        _ text: String,
        colors: HighlightColors = .light(.xcode)
    ) async throws -> NSAttributedString {
        try await request(text, mode: .automatic, colors: colors).attributedText
    }

    /// Highlights source code using a supported language.
    public func attributedText(
        _ text: String,
        language: HighlightLanguage,
        colors: HighlightColors = .light(.xcode)
    ) async throws -> NSAttributedString {
        try await request(text, mode: .language(language), colors: colors).attributedText
    }

    /// Highlights source code using a highlight.js language alias.
    public func attributedText(
        _ text: String,
        language: String,
        colors: HighlightColors = .light(.xcode)
    ) async throws -> NSAttributedString {
        try await request(text, mode: .languageAlias(language), colors: colors).attributedText
    }

    /// Highlights source code and returns its attributed text and detection metadata.
    public func request(
        _ text: String,
        mode: HighlightMode = .automatic,
        colors: HighlightColors = .light(.xcode)
    ) async throws -> HighlightResult {
        try Task.checkCancellation()
        let hljsResult = try await hljs.highlight(text, mode: mode)
        try Task.checkCancellation()

        let isUndefined = hljsResult.value == "undefined"
        let attributedText: NSAttributedString
        if isUndefined {
            attributedText = NSAttributedString(string: text)
        } else {
            let data = htmlData(from: hljsResult.value, selectors: colors.css)
            attributedText = try Self.attributedText(from: data, preserving: text)
        }

        return HighlightResult(
            attributedText: attributedText,
            highlightJSResult: hljsResult,
            backgroundColorHex: colors.background
        )
    }

    private func htmlData(from highlightedHTML: String, selectors: String) -> Data {
        let html = "<style>\n"
            .appending(selectors)
            .appending("\n</style>")
            .appending("\n<pre><code class=\"hljs\">")
            .appending(highlightedHTML)
            .appending("</code></pre>")
        return html.data(using: .utf8) ?? Data()
    }
}

private extension Highlight {
    static func attributedText(
        from data: Data,
        preserving source: String
    ) throws -> NSAttributedString {
        let imported = try NSMutableAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
        let normalizedSource = source.normalizingHTMLLineEndings
        let normalizedLength = (normalizedSource as NSString).length
        let importedString = imported.string as NSString

        guard importedString.length >= normalizedLength,
              importedString.substring(to: normalizedLength) == normalizedSource else {
            throw HLJSError.renderedTextMismatch
        }

        let highlighted = NSMutableAttributedString(
            attributedString: imported.attributedSubstring(
                from: NSRange(location: 0, length: normalizedLength)
            )
        )
        normalizeFonts(in: highlighted)

        guard normalizedSource != source else {
            return NSAttributedString(attributedString: highlighted)
        }
        return rebasing(highlighted, onto: source)
    }

    static func normalizeFonts(in attributedString: NSMutableAttributedString) {
        guard attributedString.length > 0 else { return }

        var traitRuns: [(range: NSRange, traits: UIFontDescriptor.SymbolicTraits)] = []
        attributedString.enumerateAttribute(
            .font,
            in: NSRange(location: 0, length: attributedString.length)
        ) { value, range, _ in
            guard let font = value as? UIFont else { return }
            traitRuns.append((range, font.fontDescriptor.symbolicTraits))
        }

        attributedString.removeAttribute(
            .font,
            range: NSRange(location: 0, length: attributedString.length)
        )
        attributedString.addAttribute(
            .font,
            value: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            range: NSRange(location: 0, length: attributedString.length)
        )

        for run in traitRuns {
            let isBold = run.traits.contains(.traitBold)
            let baseFont = UIFont.monospacedSystemFont(
                ofSize: 14,
                weight: isBold ? .bold : .regular
            )
            guard run.traits.contains(.traitItalic) else {
                attributedString.addAttribute(.font, value: baseFont, range: run.range)
                continue
            }
            var traits = baseFont.fontDescriptor.symbolicTraits
            traits.insert(.traitItalic)
            let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits)
                ?? baseFont.fontDescriptor
            attributedString.addAttribute(
                .font,
                value: UIFont(descriptor: descriptor, size: 14),
                range: run.range
            )
        }
    }

    static func rebasing(
        _ normalized: NSAttributedString,
        onto source: String
    ) -> NSAttributedString {
        let boundaries = normalizedBoundaryMap(for: source)
        let result = NSMutableAttributedString(string: source)

        normalized.enumerateAttributes(
            in: NSRange(location: 0, length: normalized.length)
        ) { attributes, range, _ in
            let lowerBound = boundaries[range.location]
            let upperBound = boundaries[NSMaxRange(range)]
            result.addAttributes(
                attributes,
                range: NSRange(location: lowerBound, length: upperBound - lowerBound)
            )
        }
        return NSAttributedString(attributedString: result)
    }

    static func normalizedBoundaryMap(for source: String) -> [Int] {
        let utf16 = source as NSString
        var boundaries = [0]
        var originalOffset = 0

        while originalOffset < utf16.length {
            if utf16.character(at: originalOffset) == 0x0D {
                if originalOffset + 1 < utf16.length,
                   utf16.character(at: originalOffset + 1) == 0x0A {
                    originalOffset += 2
                } else {
                    originalOffset += 1
                }
            } else {
                originalOffset += 1
            }
            boundaries.append(originalOffset)
        }
        return boundaries
    }
}

private extension String {
    var normalizingHTMLLineEndings: String {
        replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}
