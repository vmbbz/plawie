#!/usr/bin/env bash
set -euo pipefail
# Package bundled asset directories into signed dependency pack zips for
# remote hosting. Run AFTER compiling binaries (build-*.sh scripts).
#
# Usage:
#   ./package-dependency-packs.sh [--sign-key <path>]
#
# Output: build/dependency-packs/*.zip + SHA256SUMS

OUT="$(dirname "$0")/../build/dependency-packs"
ASSETS="$(dirname "$0")/../assets/openclaw"
SIGN_KEY="${1:-}"

mkdir -p "$OUT"

# Generate SHA256
sha() { sha256sum "$1" | cut -d' ' -f1; }

# Package a single pack
pack() {
  local id="$1"    # e.g. android-whisper-runtime
  local dir="$2"   # e.g. whisper-runtime
  local version="$3"
  local outfile="$OUT/$id-$version.zip"

  if [ ! -d "$ASSETS/$dir" ]; then
    echo "SKIP $id: no assets at $ASSETS/$dir"
    return
  fi

  # Count non-.gitkeep files
  local files=$(find "$ASSETS/$dir" -type f ! -name '.gitkeep' | wc -l)
  if [ "$files" -eq 0 ]; then
    echo "SKIP $id: only .gitkeep files in $ASSETS/$dir"
    return
  fi

  echo "PACK  $id ($version) — $files files"
  cd "$ASSETS/$dir"
  zip -r "$outfile" . -x '.gitkeep' >/dev/null
  cd - >/dev/null

  local hash=$(sha "$outfile")
  local size=$(stat -c%s "$outfile")

  echo "      size=$size bytes sha256=$hash"
  echo "$hash  $(basename $outfile)" >> "$OUT/SHA256SUMS"

  # Generate manifest entry
  cat >> "$OUT/manifest.json.new" <<MANIFEST
    {
      "id": "$id",
      "version": "$version",
      "source": "remote",
      "url": "https://clawhub.ai/api/v1/dependency-packs/$(basename $outfile)",
      "abis": ["arm64-v8a"],
      "sizeBytes": $size,
      "sha256": "$hash",
      "signature": { "type": "ed25519", "value": "", "keyId": "" },
      "archiveType": "zip",
      "installPath": "dependencies/packs/$id",
      "files": [
MANIFEST
  # Add file entries
  find "$ASSETS/$dir" -type f ! -name '.gitkeep' | while read f; do
    local rel="${f#$ASSETS/$dir/}"
    local fhash=$(sha "$f")
    local fsize=$(stat -c%s "$f")
    local is_exec=$([ -x "$f" ] && echo 'true' || echo 'false')
    cat >> "$OUT/manifest.json.new" <<MANIFEST
        { "path": "$rel", "sha256": "$fhash", "sizeBytes": $fsize, "executable": $is_exec },
MANIFEST
  done
  sed -i '$ s/,$//' "$OUT/manifest.json.new"  # remove trailing comma on last file entry
  cat >> "$OUT/manifest.json.new" <<MANIFEST
      ],
      "smokeCommand": { "command": "${id##android-}", "args": ["--version"] },
      "rollback": { "strategy": "remove_install_path" },
      "provides": { "bins": ["${id##android-}"] }
    },
MANIFEST
}

echo "=== Packaging dependency packs ==="
rm -f "$OUT/SHA256SUMS" "$OUT/manifest.json.new"

pack "android-whisper-runtime"    "whisper-runtime"    "whisper-cpp-v1-2026"
pack "android-tts-runtime"        "tts-runtime"        "sherpa-onnx-v1-2026"
pack "android-node-executable-pack" "node-executable-pack" "node-v20-apk-v1"
pack "android-agent-cli-pack"     "agent-cli-pack"     "agent-cli-v1-apk-v1"

# Finalize manifest
if [ -f "$OUT/manifest.json.new" ]; then
  sed -i '$ s/,$//' "$OUT/manifest.json.new"  # remove comma after last pack
  cat > "$OUT/android-arm64-v8a.json" <<JSON
{
  "packs": [
$(cat "$OUT/manifest.json.new")
  ]
}
JSON
  rm "$OUT/manifest.json.new"
  echo ""
  echo "=== Remote manifest: $OUT/android-arm64-v8a.json ==="
  cat "$OUT/android-arm64-v8a.json"
fi

echo ""
echo "=== Hosting instructions ==="
echo "1. Upload *.zip files to https://clawhub.ai/api/v1/dependency-packs/"
echo "2. Update manifest URLs to match actual hosting location"
echo "3. Sign manifest entries with ed25519 key"
echo "4. Upload android-arm64-v8a.json to same path"
echo ""
echo "All artifacts in: $OUT/"
ls -lh "$OUT/"*.zip 2>/dev/null || echo "(no zip files created — compile binaries first)"
