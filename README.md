# HighlightSwift

UIKit syntax highlighting for iOS 16 and later. HighlightSwift converts source code to an immutable `NSAttributedString` with highlight.js token colors and emphasis attributes. It intentionally contains no SwiftUI views or view-related state.

## Usage

```swift
import HighlightSwift

let highlighter = Highlight()
let source = "print(\"Hello, world!\")\n"

let explicit = try await highlighter.attributedText(
    source,
    language: .swift,
    colors: .light(.github)
)

let automatic = try await highlighter.request(
    source,
    mode: .automatic,
    colors: .dark(.github)
)

print(automatic.language ?? "unknown")
```

`HighlightResult` also exposes relevance, illegal-match, unknown-language and theme-background metadata. The returned attributed string preserves the input's UTF-16 content exactly, including indentation, blank lines, trailing newlines, CRLF and emoji.

For a custom theme, pass CSS and an optional explicit background color:

```swift
let colors = HighlightColors.custom(
    css: ".hljs { color: #24292e; background: #ffffff; }",
    background: UIColor.systemBackground
)
```

HighlightSwift preserves token foreground colors and bold/italic emphasis. The caller owns typography such as font family, size, kerning and paragraph style.

## Bundled highlight.js resources

Runtime resources are generated from the sibling local `highlight.js` checkout and committed to this package. HighlightSwift does not access that checkout at runtime and does not declare it as a SwiftPM dependency.

The currently bundled source is recorded in `Sources/HighlightSwift/HighlightJS/VERSION.txt`. To regenerate it:

```sh
Scripts/sync-highlightjs.sh ../highlight.js
```

An alternate checkout can be supplied as the first argument. The script verifies `package.json`, `package-lock.json`, the Git revision and a clean tracked working tree. When dependencies are absent it uses `npm ci`, builds the browser common-language bundle, then copies the JavaScript, all 30 light/dark theme pairs and the highlight.js license. Running the command repeatedly with the same source checkout is deterministic.

The `.github` theme is sourced specifically from `src/styles/github.css` and `src/styles/github-dark.css`, not the similarly named Base16 theme.

## License

This package is derived from [appstefan/HighlightSwift](https://github.com/appstefan/HighlightSwift) and is available under the MIT license in `LICENSE.md`. The bundled highlight.js JavaScript and styles are available under its BSD 3-Clause license in `Sources/HighlightSwift/HighlightJS/LICENSE.md`.
