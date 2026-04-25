# OpenForge Asset Manifest

Third-party asset packs are gitignored due to size (~830MB). When checking out
this repo on a fresh machine, populate the directories below and run
`tools/setup/download_assets.sh` to verify the layout.

URLs are intentionally not embedded — re-fetch from the original sources by
searching the pack names on each provider. All listed packs are CC0, CC-BY, or
OFL-licensed and free.

## assets/models/ (~790 MB)

| Path | Files | Pack / Style anchor | Typical source |
|---|---|---|---|
| `characters/` | 20 | KayKit-style low-poly heroes (Barbarian / Knight / Mage / Rogue_Hooded `.glb` + textures) | kaylousberg.itch.io |
| `enemies/` | 16 | KayKit-style skeletons (Skeleton_{Mage,Minion,Rogue,Warrior}) | kaylousberg.itch.io |
| `monsters/` | 573 | Monster mesh pack | (re-check provenance) |
| `dungeon/` | 1887 | KayKit Dungeon environment | kaylousberg.itch.io |
| `fantasy_rts/` | 1431 | Kenney Fantasy RTS Pack (Farm / Rock / Temple / TownCenter / Houses) | kenney.nl |
| `nature/` | 1068 | Nature / foliage pack | kenney.nl |
| `adventures/` | 228 | Adventure-themed meshes | (re-check provenance) |
| `skeletons/` | 118 | Animation skeleton rigs | (re-check provenance) |
| `props/` | 0 | Reserved for future custom props | n/a |

## assets/sprites/ (~37 MB)

| Path | Files | Notes |
|---|---|---|
| `icons/game_icons/` | 7302 | game-icons.net SVG library (CC-BY 3.0) — game-icons.net |
| `ui/kenney/`, `ui/kenney_rpg/` | 1910 | Kenney UI Pack atlases — kenney.nl |
| `effects/` `enemies/` `environment/` `heroes/` `towers/` | 0 | Empty placeholders for future custom 2D art |

## assets/fonts/ (232 KB)

- `MedievalSharp.ttf` — Google Fonts (OFL)
- `Kenney Future.ttf`, `Kenney Future Narrow.ttf` — kenney.nl

## assets/shaders/ (16 KB)

Custom shader code. Not gitignored individually — but parent `assets/shaders/`
is in `.gitignore`. **If you author new shaders that should ship with the
project, add an explicit `!` un-ignore line** (e.g., `!assets/shaders/your_shader.gdshader`).

## addons/ (5.2 MB)

- `gdUnit4` — Godot 4 unit testing framework. Install via Godot AssetLib or
  GitHub: github.com/MikeSchulze/gdUnit4

## Bootstrap

```bash
tools/setup/download_assets.sh
```

Reports each expected path as `OK <count> files` or `MISSING <path>  <hint>`,
and exits non-zero if anything is missing.
