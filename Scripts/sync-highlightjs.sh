#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_root="$(cd "${script_dir}/.." && pwd)"
source_root="${1:-${package_root}/../highlight.js}"
resources_root="${package_root}/Sources/HighlightSwift/HighlightJS"

if [[ ! -f "${source_root}/package.json" || ! -f "${source_root}/package-lock.json" ]]; then
  echo "error: ${source_root} is not a highlight.js checkout with package.json and package-lock.json" >&2
  exit 1
fi

if [[ -n "$(git -C "${source_root}" status --porcelain)" ]]; then
  echo "error: highlight.js working tree is not clean" >&2
  exit 1
fi

version="$(node -p "require('${source_root}/package.json').version")"
revision="$(git -C "${source_root}" rev-parse --verify 'HEAD^{commit}')"
expected_version="11.12.0"
expected_revision="fc3f06392f189354eed922973635ab9e9268b983"

if [[ "${version}" != "${expected_version}" || "${revision}" != "${expected_revision}" ]]; then
  echo "error: expected highlight.js ${expected_version} (${expected_revision}), got ${version} (${revision})" >&2
  exit 1
fi

if [[ ! -d "${source_root}/node_modules" ]]; then
  npm --prefix "${source_root}" ci
fi

npm --prefix "${source_root}" run build-browser

if [[ ! -f "${source_root}/build/highlight.min.js" ]]; then
  echo "error: build-browser did not create build/highlight.min.js" >&2
  exit 1
fi

stage_root="$(mktemp -d "${TMPDIR:-/tmp}/highlight-swift-resources.XXXXXX")"
trap 'rm -rf "${stage_root}"' EXIT

cp "${source_root}/build/highlight.min.js" "${stage_root}/highlight.min.js"
cp "${source_root}/LICENSE" "${stage_root}/LICENSE.md"

copy_theme() {
  local resource_name="$1"
  local light_source="$2"
  local dark_source="$3"

  cp "${source_root}/src/styles/${light_source}" "${stage_root}/${resource_name}-light.css"
  cp "${source_root}/src/styles/${dark_source}" "${stage_root}/${resource_name}-dark.css"
}

copy_theme "a11y" "a11y-light.css" "a11y-dark.css"
copy_theme "atom-one" "atom-one-light.css" "atom-one-dark.css"
copy_theme "classic" "base16/classic-light.css" "base16/classic-dark.css"
copy_theme "edge" "base16/edge-light.css" "base16/edge-dark.css"
copy_theme "github" "github.css" "github-dark.css"
copy_theme "google" "base16/google-light.css" "base16/google-dark.css"
copy_theme "gradient" "gradient-light.css" "gradient-dark.css"
copy_theme "grayscale" "base16/grayscale-light.css" "base16/grayscale-dark.css"
copy_theme "harmonic16" "base16/harmonic16-light.css" "base16/harmonic16-dark.css"
copy_theme "heetch" "base16/heetch-light.css" "base16/heetch-dark.css"
copy_theme "horizon" "base16/horizon-light.css" "base16/horizon-dark.css"
copy_theme "humanoid" "base16/humanoid-light.css" "base16/humanoid-dark.css"
copy_theme "ia" "base16/ia-light.css" "base16/ia-dark.css"
copy_theme "isbl-editor" "isbl-editor-light.css" "isbl-editor-dark.css"
copy_theme "kimbie" "kimbie-light.css" "kimbie-dark.css"
copy_theme "nnfx" "nnfx-light.css" "nnfx-dark.css"
copy_theme "panda-syntax" "panda-syntax-light.css" "panda-syntax-dark.css"
copy_theme "papercolor" "base16/papercolor-light.css" "base16/papercolor-dark.css"
copy_theme "paraiso" "paraiso-light.css" "paraiso-dark.css"
copy_theme "qtcreator" "qtcreator-light.css" "qtcreator-dark.css"
copy_theme "silk" "base16/silk-light.css" "base16/silk-dark.css"
copy_theme "solar-flare" "base16/solar-flare-light.css" "base16/solar-flare.css"
copy_theme "solarized" "base16/solarized-light.css" "base16/solarized-dark.css"
copy_theme "stackoverflow" "stackoverflow-light.css" "stackoverflow-dark.css"
copy_theme "standard" "base16/default-light.css" "base16/default-dark.css"
copy_theme "summerfruit" "base16/summerfruit-light.css" "base16/summerfruit-dark.css"
copy_theme "synth-midnight-terminal" "base16/synth-midnight-terminal-light.css" "base16/synth-midnight-terminal-dark.css"
copy_theme "tokyo-night" "tokyo-night-light.css" "tokyo-night-dark.css"
copy_theme "unikitty" "base16/unikitty-light.css" "base16/unikitty-dark.css"
copy_theme "xcode" "xcode.css" "base16/xcode-dusk.css"

printf 'highlight.js %s\ngit %s\n' "${version}" "${revision}" > "${stage_root}/VERSION.txt"

mkdir -p "${resources_root}"
rsync -a --delete "${stage_root}/" "${resources_root}/"

echo "Synced highlight.js ${version} (${revision})"
