import UIKit
import XCTest
@testable import HighlightSwift

final class HighlightSwiftTests: XCTestCase {
    private let highlight = Highlight()

    func testExplicitLanguagePreservesSourceAndMetadata() async throws {
        let source = "  let greeting = \"你好 👋\"\n\nprint(greeting)\n"
        let result = try await highlight.request(
            source,
            mode: .language(.swift),
            colors: .light(.github)
        )

        XCTAssertEqual(result.attributedText.string, source)
        XCTAssertEqual(result.attributedText.length, (source as NSString).length)
        XCTAssertEqual(result.language, "swift")
        XCTAssertTrue(result.languageName.hasPrefix("Swift"))
        XCTAssertFalse(result.hasIllegal)
        XCTAssertFalse(result.isUndefined)
    }

    func testAutomaticLanguageDetection() async throws {
        let source = "import Foundation\nstruct Answer { let value: Int = 42 }"
        let result = try await highlight.request(source, colors: .light(.github))

        XCTAssertEqual(result.attributedText.string, source)
        XCTAssertNotEqual(result.language, "unknown")
        XCTAssertGreaterThan(result.relevance, 0)
        XCTAssertFalse(result.isUndefined)
    }

    func testUnknownLanguageReturnsOriginalTextAndMetadata() async throws {
        let source = "  unknown syntax\r\n🙂\r\n"
        let result = try await highlight.request(
            source,
            mode: .languageAlias("definitely-not-a-language")
        )

        XCTAssertEqual(result.attributedText.string, source)
        XCTAssertEqual(result.language, "unknown")
        XCTAssertEqual(result.languageName, "Unknown")
        XCTAssertEqual(result.relevance, 0)
        XCTAssertTrue(result.isUndefined)
    }

    func testPreservesAllUTF16SourceUnits() async throws {
        let sources = [
            "",
            "   ",
            "\n\n",
            "\tlet value = \"😀\"  \n",
            "first\r\n  second\r\n",
            "first\rsecond\r"
        ]

        for source in sources {
            let result = try await highlight.request(
                source,
                mode: .language(.swift),
                colors: .dark(.github)
            )
            XCTAssertEqual(result.attributedText.string, source)
            XCTAssertEqual(result.attributedText.length, (source as NSString).length)
        }
    }

    func testCustomCSSColorsAndBackground() async throws {
        let css = """
        .hljs { color: #123456; background-color: #abcdef; }
        .hljs-keyword { color: #ff0000; font-weight: bold; }
        """
        let result = try await highlight.request(
            "let value = 1",
            mode: .language(.swift),
            colors: .custom(css: css)
        )

        XCTAssertEqual(result.backgroundColor.hexRGBA, "ABCDEFFF")
        XCTAssertTrue(result.attributedText.containsForegroundColor(hexRGBA: "FF0000FF"))
        XCTAssertTrue(result.attributedText.containsFontTrait(.traitBold))
    }

    func testExplicitCustomBackgroundOverridesCSS() async throws {
        let result = try await highlight.request(
            "let value = 1",
            mode: .language(.swift),
            colors: .custom(
                css: ".hljs { background: #ffffff; }",
                background: "#010203"
            )
        )

        XCTAssertEqual(result.backgroundColor.hexRGBA, "010203FF")
    }

    func testAllBundledThemesLoadBothAppearances() {
        XCTAssertEqual(HighlightTheme.allCases.count, 30)

        for theme in HighlightTheme.allCases {
            let light = HighlightColors.light(theme)
            let dark = HighlightColors.dark(theme)
            XCTAssertFalse(light.css.isEmpty, "Missing light CSS for \(theme)")
            XCTAssertFalse(dark.css.isEmpty, "Missing dark CSS for \(theme)")
            XCTAssertFalse(light.background.isEmpty, "Missing light background for \(theme)")
            XCTAssertFalse(dark.background.isEmpty, "Missing dark background for \(theme)")
        }
    }

    func testGitHubThemeUsesExpectedExactColors() {
        let light = HighlightColors.light(.github)
        let dark = HighlightColors.dark(.github)

        XCTAssertTrue(light.css.contains("color: #24292e"))
        XCTAssertTrue(light.css.contains("background: #ffffff"))
        XCTAssertEqual(light.background.lowercased(), "#ffffff")
        XCTAssertTrue(dark.css.contains("color: #c9d1d9"))
        XCTAssertTrue(dark.css.contains("background: #0d1117"))
        XCTAssertEqual(dark.background.lowercased(), "#0d1117")
    }

    func testBundledResourceProvenanceAndLicense() throws {
        let version = try XCTUnwrap(
            HighlightResource.string(named: "VERSION", extension: "txt")
        )
        let script = try XCTUnwrap(
            HighlightResource.string(named: "highlight.min", extension: "js")
        )
        let license = try XCTUnwrap(
            HighlightResource.string(named: "LICENSE", extension: "md")
        )

        XCTAssertEqual(
            version,
            "highlight.js 11.12.0\ngit fc3f06392f189354eed922973635ab9e9268b983\n"
        )
        XCTAssertTrue(script.hasPrefix("/*!\n  Highlight.js v11.12.0 (git: fc3f06392f)"))
        XCTAssertTrue(license.contains("BSD 3-Clause License"))
    }

    func testConcurrentRequestsRemainIsolated() async throws {
        let sources = (0 ..< 20).map { "let value\($0) = \"🙂 \($0)\"\n" }
        let results = try await withThrowingTaskGroup(
            of: (Int, String).self
        ) { group in
            for (index, source) in sources.enumerated() {
                group.addTask {
                    let value = try await self.highlight.attributedText(
                        source,
                        language: .swift,
                        colors: .light(.github)
                    )
                    return (index, value.string)
                }
            }

            var values = [String?](repeating: nil, count: sources.count)
            for try await (index, value) in group {
                values[index] = value
            }
            return values
        }

        for (source, result) in zip(sources, results) {
            XCTAssertEqual(result, source)
        }
    }
}

private extension NSAttributedString {
    func containsForegroundColor(hexRGBA: String) -> Bool {
        var found = false
        enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: length)) {
            value, _, stop in
            if (value as? UIColor)?.hexRGBA == hexRGBA {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    func containsFontTrait(_ trait: UIFontDescriptor.SymbolicTraits) -> Bool {
        var found = false
        enumerateAttribute(.font, in: NSRange(location: 0, length: length)) {
            value, _, stop in
            if let font = value as? UIFont,
               font.fontDescriptor.symbolicTraits.contains(trait) {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
}

private extension UIColor {
    var hexRGBA: String? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        return String(
            format: "%02X%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255)),
            Int(round(alpha * 255))
        )
    }
}
