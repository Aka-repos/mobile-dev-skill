#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# build.sh — Empaquetar mobile-dev-skill → .skill
# Uso: ./build.sh
# ─────────────────────────────────────────────

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/mobile-dev-skill"
OUT="$ROOT/output/mobile-dev-skill.skill"

# Validar que existan los archivos fuente
REQUIRED=(
  "$SRC/SKILL.md"
  "$SRC/references/kotlin-android.md"
  "$SRC/references/swift-ios.md"
  "$SRC/references/react-native.md"
  "$SRC/references/flutter.md"
  "$SRC/references/firebase-mobile.md"
  "$SRC/references/rest-mobile.md"
)

echo "🔍 Validando archivos fuente..."
for f in "${REQUIRED[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "❌ Falta: $f"
    exit 1
  fi
done

# Crear output/ si no existe
mkdir -p "$ROOT/output"

# Empaquetar
echo "📦 Empaquetando → output/mobile-dev-skill.skill"
cd "$ROOT"
zip -r "$OUT" mobile-dev-skill/ --quiet

echo "✅ Listo: $OUT ($(du -sh "$OUT" | cut -f1))"
