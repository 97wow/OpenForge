#!/usr/bin/env bash
# OpenForge third-party asset bootstrap verifier.
#
# Asset packs (~830MB) are gitignored — see tools/setup/ASSET_MANIFEST.md.
# This script reports which expected paths are missing on the current machine.
# It does NOT download — re-fetch manually from the sources in the manifest.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
missing=0

check() {
  local path="$1"; local hint="$2"
  if [[ ! -d "$ROOT/$path" ]] || [[ -z "$(ls -A "$ROOT/$path" 2>/dev/null)" ]]; then
    printf 'MISSING  %-38s  %s\n' "$path" "$hint"
    missing=$((missing + 1))
  else
    local count
    count=$(find "$ROOT/$path" -type f 2>/dev/null | wc -l | tr -d ' ')
    printf 'OK       %-38s  %s files\n' "$path" "$count"
  fi
}

echo "OpenForge asset bootstrap check"
echo "==============================="

check "assets/models/characters"        "KayKit low-poly heroes"
check "assets/models/enemies"           "KayKit skeletons"
check "assets/models/monsters"          "Monster mesh pack"
check "assets/models/dungeon"           "KayKit Dungeon"
check "assets/models/fantasy_rts"       "Kenney Fantasy RTS"
check "assets/models/nature"            "Nature pack"
check "assets/sprites/icons/game_icons" "game-icons.net SVG library"
check "assets/sprites/ui"               "Kenney UI atlases"
check "assets/fonts"                    "MedievalSharp + Kenney fonts"
check "addons/gdUnit4"                  "Godot unit testing framework"

echo
if (( missing > 0 )); then
  echo "$missing path(s) missing. See tools/setup/ASSET_MANIFEST.md for sources."
  exit 1
fi
echo "All third-party asset packs present."
