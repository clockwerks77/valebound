#!/usr/bin/env bash
# Publishes build logs and rendered screenshots to the `ci-results` branch so
# they can be read with plain git. Called from .github/workflows/build.yml.
set -uo pipefail

STAGE="${1:-final}"
BRANCH="${RESULTS_BRANCH:-ci-results}"
OUT="$(mktemp -d)"
mkdir -p "$OUT/logs" "$OUT/screenshots"

cp -r ci_out/. "$OUT/logs/" 2>/dev/null || true
cp test/golden/goldens/*.png "$OUT/screenshots/" 2>/dev/null || true
cp device_shots/*.png "$OUT/screenshots/" 2>/dev/null || true

APK="build/app/outputs/flutter-apk/app-debug.apk"
APK_BYTES=0
APK_SHA256=""
if [ -f "$APK" ]; then
  APK_BYTES=$(stat -c %s "$APK")
  APK_SHA256=$(sha256sum "$APK" | cut -d' ' -f1)
fi

cat > "$OUT/status.json" <<EOF
{
  "sha": "${GITHUB_SHA:-}",
  "ref": "${GITHUB_REF_NAME:-}",
  "run_id": "${GITHUB_RUN_ID:-}",
  "stage": "${STAGE}",
  "pub_get": "${S_PUB:-}",
  "codegen": "${S_CODEGEN:-}",
  "analyze": "${S_ANALYZE:-}",
  "test": "${S_TEST:-}",
  "apk": "${S_APK:-}",
  "device": "${S_DEVICE:-}",
  "apk_path": "${APK}",
  "apk_bytes": ${APK_BYTES},
  "apk_sha256": "${APK_SHA256}",
  "time": "$(date -u +%FT%TZ)"
}
EOF

cd "$OUT" || exit 0
git init -q -b "$BRANCH"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -A
git commit -qm "CI results for ${GITHUB_SHA:-unknown} (${STAGE})"
git push -qf "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "$BRANCH" \
  || echo "Could not publish results (non-fatal)."
