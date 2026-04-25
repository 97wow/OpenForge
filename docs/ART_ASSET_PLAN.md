# Art Asset Generation Plan — rogue_survivor GamePack

> Source of truth: `docs/ROGUE_SURVIVOR_GAPS.md` §1 (audit 2026-04-24).
> Cross-references: `docs/STEAM_PAGE_DRAFT.md` §5 (capsule prompts already
> authored), `tools/setup/README_HUNYUAN3D.md` (local 3D pipeline).
> This is a planning document. No images are generated here.

**Scope rule:** every asset listed below is one that GAPS §1 explicitly calls
out as missing or wrong-subject. Where GAPS is silent on a category (2D hero
portraits, card frames, UI chrome, status-effect icons, environment art) the
silence is preserved — see §7 *Open questions for designer*.

**Style anchors that already exist in-tree (do not invent new ones):**

- Synty-style low-poly fantasy meshes — `assets/models/characters/{Barbarian,Knight,Mage,Rogue_Hooded}.glb`
- Synty-style enemy meshes — `assets/models/enemies/Skeleton_{Mage,Minion,Rogue,Warrior}.glb`
- Kenney UI atlas — `assets/sprites/ui/{kenney,kenney_rpg}/`
- game-icons.net SVG library — `assets/sprites/icons/game_icons/` (3,534 SVGs)
- Capsule/key-art style brief — `docs/STEAM_PAGE_DRAFT.md` §5 (Brotato + Thronefall + Rogue Tower; dusk-purple + amber + arcane-cyan + enemy-red)

---

## 0. Tooling

| Output | Pipeline | Notes |
|---|---|---|
| `.glb` 3D meshes (enemies, bosses, props) | **Hunyuan3D-2mini** local MPS via `tools/setup/install_hunyuan3d_mac.sh` → `hunyuan3d-gen --prompt … --out X.glb` (shape-only on Mac; texture pass needs Replicate fallback per the README). | Default for any mesh in §2. Use `--steps 30 --seed 1234` first pass. Texture via Replicate `tencent/hunyuan3d-2` if local C++ ext failed to build. |
| 2D billboard sprites / particle textures (projectiles, fountain volumes, FX trails) | **FLUX** or **Stable Diffusion XL** via the user's existing image-gen access. Transparent PNG output, square aspect. | §1 batch. |
| 2D spell/card icons (only those with no suitable SVG match in the in-tree library) | **FLUX** preferred for clean iconography; fallback SD XL with an icon LoRA. | §4 batch. **Default to mapping the existing 3,534-SVG library first** — generation is only for orphan spells. |
| Capsule / key art / header / small capsule | **FLUX** or **Midjourney** as authored in `docs/STEAM_PAGE_DRAFT.md` §5. | Prompts already exist; do not re-author. |

No new tooling is being introduced. Hunyuan3D and the user's existing
image-gen access are the only sources.

---

## 1. Projectile & Fountain Sprites (P0 — §1.3 critical gap #1)

GAPS §1.1 lists six solid-colour primitives. `training_dummy` is intentional
and excluded; the other five ship-blockers are batched here. These render as
2D billboards in a 3D scene — square transparent PNG, soft glow on alpha.

Convention: 2D effect sprites belong under `assets/sprites/effects/` (the
directory exists, currently empty per §1).

### Batch 1 — Projectiles & fountains (run as one MJ/FLUX session)

| # | Asset | Path | Style anchor | Aspect / Res |
|---|---|---|---|---|
| 1.1 | Arrow billboard | `assets/sprites/effects/arrow.png` | Brotato projectile silhouettes; replaces `#ffee58` sphere | 1:1 / 256² |
| 1.2 | Fireball billboard | `assets/sprites/effects/fireball.png` | Thronefall fire VFX; replaces `#ff7043` sphere | 1:1 / 256² |
| 1.3 | Heavy bolt billboard | `assets/sprites/effects/heavy_bolt.png` | Match Synty crossbow-bolt material; replaces `#ffffff` sphere | 1:1 / 256² |
| 1.4 | Enemy fountain volume | `assets/sprites/effects/enemy_fountain.png` | Damaging hazard; replaces `#d32f2f` cylinder | 1:1 / 512² |
| 1.5 | Life fountain volume | `assets/sprites/effects/life_fountain.png` | Healing hazard; replaces `#ce93d8` cylinder | 1:1 / 512² |

**Negative prompt (apply to whole batch):** `no text, no watermark, no UI border, no shadow on ground, no character, no background scenery`

#### Generation prompts

1.1 **arrow.png** — *"Low-poly fantasy arrow projectile billboard, side-on profile, amber wooden shaft with steel arrowhead, faint cyan magic streak trailing behind, transparent background, clean Brotato/Thronefall silhouette readable at 32px, soft glow on alpha, square 1:1."*

1.2 **fireball.png** — *"Stylized fireball projectile, viewed from camera, orange-amber core with red outer flame and ember sparks, low-poly painterly shading not photorealistic, faint dark-purple smoke wake, transparent background, square 1:1, must read as a projectile not an explosion."*

1.3 **heavy_bolt.png** — *"Heavy crossbow bolt projectile billboard, side profile, dark steel head with heavy iron-banded shaft, arcane-cyan rim light along the leading edge, motion blur trail, low-poly Synty material feel, transparent background, square 1:1."*

1.4 **enemy_fountain.png** — *"Top-down view of a hostile blood-red ground geyser, low-poly painterly, vertical column of dark red mist rising from a cracked stone disk, faint heat-haze ring, dusk-purple shadow on the disk, transparent background, square 1:1, must tile-loop visually."*

1.5 **life_fountain.png** — *"Top-down view of a benign arcane healing fountain, low-poly painterly, soft pink-violet light column rising from a runed stone disk, gentle ember-petal particles, cyan rim glow, transparent background, square 1:1, must read as friendly not hostile."*

**Acceptance check:** at 64×64 in-game scale, the silhouette is unambiguous
(arrow vs bolt vs fireball; red-fountain reads "hostile", purple reads
"friendly"); alpha edges are clean with no white/black halo.

---

## 2. Enemy & Boss Mesh Replacements (P0 — §1.3 critical gap #2)

§1.1 enumerates 8 wrong-subject reuses. Three are bosses (top of the queue);
five are minions. Pipeline: **Hunyuan3D-2mini** locally on MPS for shape,
texture via Replicate if local texgen ext failed to build (per
`README_HUNYUAN3D.md`).

Convention: meshes go under `assets/models/enemies/<name>.glb`; texture PNG
goes alongside as `<name>_<material>_texture.png` (matches existing Synty
shipped naming).

### Batch 2A — Three boss meshes (P0, ship-blocker)

| # | Asset | Path | Style anchor | Output |
|---|---|---|---|---|
| 2.1 | Bone Dragon boss | `assets/models/enemies/Bone_Dragon.glb` | Synty `Skeleton_Warrior` material vocabulary, scaled to dragon proportions | `.glb` low-poly |
| 2.2 | Shadow Lord boss | `assets/models/enemies/Shadow_Lord.glb` | Synty `Skeleton_Mage` robe silhouette + corrupted-purple palette | `.glb` low-poly |
| 2.3 | Void Titan boss | `assets/models/enemies/Void_Titan.glb` | Synty bulk; entirely new colossal humanoid form | `.glb` low-poly |

#### Generation prompts (Hunyuan3D `--prompt`)

2.1 **Bone_Dragon.glb** — *"Low-poly skeletal four-legged dragon, Synty Polygon Fantasy style, exposed rib cage, tattered membrane wings half-furled, long bone tail with spikes, weathered ivory-white bone with deep shadow recesses, A-pose for rigging, single-mesh GLB, no base, fits in a 4-meter cube, matches Skeleton_Warrior material vocabulary."*

2.2 **Shadow_Lord.glb** — *"Low-poly hooded sorcerer-king, Synty Polygon Fantasy style, dark robe trailing into smoke wisps at the hem, no visible face under the cowl, two cyan-glowing eye points inside the hood, ornate broken crown, gnarled staff with a violet crystal, T-pose for rigging, single-mesh GLB, fits in a 2-meter cube."*

2.3 **Void_Titan.glb** — *"Low-poly colossal void humanoid, Synty Polygon Fantasy style but oversized, hulking armored shoulders, segmented obsidian plates with cyan rune cracks across the chest, no head — only a swirling cyan-purple void at the neck, balled fists, T-pose for rigging, single-mesh GLB, fits in a 5-meter cube, reads as a final-encounter boss at thumbnail size."*

**Aspect / Res:** Hunyuan3D output is GLB; aim for ≤ 8 k tris per mesh.

**Acceptance check:** silhouette differs unambiguously from any
`Skeleton_*` mesh at a 0.5 m on-screen height; rig pose imports cleanly into
Godot 4.6 (`AnimationPlayer` not required, but mesh must be a single
`MeshInstance3D` with one material slot).

### Batch 2B — Five non-skeleton minion meshes (P1)

| # | Asset | Path | Replaces (per §1.1) | Style anchor |
|---|---|---|---|---|
| 2.4 | Living Archer | `assets/models/enemies/Archer.glb` | `Skeleton_Rogue` reused | Synty Polygon Fantasy living humanoid, leather + cloth |
| 2.5 | Goblin | `assets/models/enemies/Goblin.glb` | `Skeleton_Minion` @ 0.7× | Synty Polygon Fantasy small humanoid, green skin |
| 2.6 | Shaman | `assets/models/enemies/Shaman.glb` | `Skeleton_Mage` reused | Synty Polygon Fantasy tribal caster |
| 2.7 | Shadow Wraith | `assets/models/enemies/Shadow.glb` | `Skeleton_Rogue` @ 0.9× | Incorporeal, dark smoke + cyan eyes |
| 2.8 | Stone Golem | `assets/models/enemies/Golem.glb` | `Skeleton_Warrior` @ 1.6× | Synty rock-construct, no skeletal cues |

#### Generation prompts

2.4 **Archer.glb** — *"Low-poly living human archer, Synty Polygon Fantasy style, leather chest piece, hooded brown cloak (different silhouette from Rogue_Hooded — broader shoulders, exposed face), longbow slung across back, simple quiver at hip, T-pose for rigging, single-mesh GLB, fits in a 2-meter cube."*

2.5 **Goblin.glb** — *"Low-poly fantasy goblin, Synty Polygon Fantasy style, hunched short humanoid, green skin, oversized pointed ears, ragged loincloth and patched leather vest, rusty cleaver in one hand, slightly bent forward stance, T-pose for rigging, single-mesh GLB, fits in a 1-meter cube."*

2.6 **Shaman.glb** — *"Low-poly fantasy tribal shaman, Synty Polygon Fantasy style, living humanoid (not a skeleton), bone-and-feather mask, fur shoulder mantle, painted-clay torso markings, gnarled wooden staff topped with a hanging skull totem, T-pose for rigging, single-mesh GLB, fits in a 2-meter cube."*

2.7 **Shadow.glb** — *"Low-poly incorporeal wraith, Synty Polygon Fantasy style, vaguely humanoid silhouette dissolving into dark smoke at the legs, two glowing cyan eyes the only feature, tattered floating shroud, no weapon, hovering pose for rigging, single-mesh GLB, fits in a 2-meter cube."*

2.8 **Golem.glb** — *"Low-poly stone golem, Synty Polygon Fantasy style, blocky chunked rock body with moss in the joints, no skeletal cues, oversized fists, glowing amber rune cracks across the chest and shoulders, slow-heavy T-pose for rigging, single-mesh GLB, fits in a 3-meter cube."*

**Acceptance check:** mesh imports into Godot, faces toward +Z by default,
silhouette at 1 m on-screen height is distinct from all four shipped
`Skeleton_*` meshes and from every other entry in this batch.

---

## 3. Card Frames & Rarity Treatments (silence in §1 — designer call)

GAPS §1.2 / §1.3 #3 reports that `rogue_card_ui.gd` draws cards
**procedurally** with `Label` + `ColorRect` + `StyleBoxFlat` tinted by
rarity. Custom card-frame artwork is **not enumerated as a gap**. The
shipping fix in §1.3 is "wire the existing icon library + edit JSON"; the
procedural frame is acceptable in that fix.

**No prompts are authored in this section.** If the designer later decides
the procedural frame is not shippable, that becomes a new asset family with
five rarity tints (common/uncommon/rare/epic/legendary, palette already in
`rogue_card_ui.gd`). See §7.

---

## 4. Spell / Status Icons (P1 — §1.3 critical gap #3)

GAPS §1.2 reports **143 spell JSONs in `gamepacks/rogue_survivor/spells/`,
zero with an `icon` / `icon_path` / `texture` field**, while
`assets/sprites/icons/game_icons/` already contains **3,534 unused SVGs**.

This is **overwhelmingly a mapping problem, not a generation problem.**
Following the rule "do not invent assets where existing assets cover the
gap," the §1.3 #3 fix in priority order is:

1. **Map** existing `game_icons/` SVGs to each spell (designer task; ≤ 1 day
   per §1.3 #3 estimate). Filename hints: `chain-lightning.svg`,
   `flame-tongue.svg`, `frostfire.svg`, `poison-cloud.svg`,
   `crowned-skull.svg`, etc. all already on disk.
2. **Generate** only those spells where no SVG in the 3,534-file library is
   a defensible match.

Until the mapping pass is done, the orphan list is unknown. Do **not**
pre-author prompts for icons that may be redundant. The mapping pass is
prerequisite to this batch.

### Batch 4 — Custom spell icons (deferred until mapping pass identifies orphans)

When the designer's mapping pass produces a list of orphan spells, each
orphan icon should follow this template (one prompt per orphan, run as a
single FLUX/MJ batch):

> *"Single-subject fantasy ability icon, [SPELL_CONCEPT], game-icons.net
> visual vocabulary — flat black silhouette on solid white circular
> background, no gradient, no text, centered, instantly readable at 32×32,
> suitable for tinting at runtime, square 1:1."*

**Path convention:** `assets/sprites/icons/custom/<spell_id>.svg` (or
`.png` if FLUX cannot produce SVG; document the format choice with the
designer — game-icons.net are SVG so SVG is preferred for tint-friendliness).

**Aspect / Res:** 1:1 / 256² PNG (if raster); native SVG (if vector).

**Negative prompt:** `no text, no watermark, no color background, no UI border, no character, no scenery`

**Acceptance check:** at 32×32 in the skill bar, the icon reads as the
named ability for a player who has never seen it before; silhouette is
flat-tintable (no anti-aliased grey grades at the silhouette's edge that
would block the rarity-tint path that game-icons SVGs already satisfy).

---

## 5. UI & HUD Chrome (silence in §1)

GAPS §1 does not list any missing UI/HUD chrome. Kenney UI atlases are
already wired for panels and bars (`rogue_card_ui.gd`,
`rogue_hud_skillbar.gd` per §1.2 only critique the *contents* — labels and
strips — not the panels themselves). **No prompts are authored in this
section.** Treat this category as out of scope until the designer files a
specific chrome gap.

---

## 6. Capsule / Promotional Art (cross-ref `STEAM_PAGE_DRAFT.md` §5)

Already authored. Do **not** re-author. The single source of truth is
`docs/STEAM_PAGE_DRAFT.md` §5, which contains:

| Group | Count | Aspect | Path the artist should write to |
|---|---|---|---|
| Grand Key Art / Store Page Hero | 5 candidate prompts | 16:9 (entries 1-4); 2:3 (entry 5) | `assets/store/key_art_*.png` |
| Main Capsule | 4 candidate prompts | 616:353 | `assets/store/capsule_main_*.png` |
| Small Capsule | 3 candidate prompts | 462:174 | `assets/store/capsule_small_*.png` |
| Header Capsule | 3 candidate prompts | 460:215 | `assets/store/capsule_header_*.png` |

**Negative prompt (applies to whole §5 batch, per §5 style brief):** `no
text, no watermark, no UI, no Warcraft iconography, no Frostmourne, no
realism-painted style, no thumbnail-illegible busy splash`.

**Acceptance check:** per-entry guidance is already encoded in §5
("readable at 231×87 thumbnail", "logo-safe band left third", "must crop to
292×136 without losing the hero", etc.).

---

## 7. Open Questions for Designer

The following decisions are **not derivable from the audit** and block
prompt authoring or asset selection. Each needs a single human design call
before the corresponding batch can run.

1. **Class-specific hero on spawn.** §1.3 #4 notes `hero.json` ships only
   the Barbarian even though Knight / Mage / Rogue_Hooded GLBs exist.
   *Decision:* is this a wiring task (already in scope; no asset gen needed)
   or does each class need a *new* signature mesh distinct from the four
   shipped Synty meshes? GAPS leans toward wiring; confirm before any new
   hero mesh is commissioned.

2. **2D character-select portraits.** `assets/sprites/heroes/` is empty per
   §1; the directory exists but GAPS does not list 2D portraits as a gap.
   *Decision:* does `character_select.tscn` need 2D portrait art, or is the
   3D model preview sufficient? If portraits are wanted, this becomes a new
   batch (3 portraits at minimum, one per class, plus Barbarian).

3. **Card frame art vs. procedural.** §3 above. *Decision:* is the
   procedural `StyleBoxFlat` rarity-tint shippable, or do we commission
   five rarity-tinted frame PNGs (common/uncommon/rare/epic/legendary)?

4. **Status / debuff icons.** GAPS §1.2 audits *spell* icons but does not
   separately audit the buff/debuff icon family used by `AuraManager`.
   *Decision:* are buff/debuff icons in the same mapping-from-SVG bucket as
   spell icons (likely yes — game-icons.net has hundreds of buff motifs),
   or do they need their own dedicated icon family?

5. **Holy-school visual identity.** Audio §2.4 notes `hit_holy.wav` is
   missing despite Holy being one of six damage schools. The art parallel:
   no Holy-tinted projectile is enumerated in §1.1 (`fireball` is Fire,
   `heavy_bolt` reads as Physical, `arrow` is Physical). *Decision:* does
   Holy need its own dedicated projectile billboard, or is school-tinting
   an existing billboard at runtime acceptable?

6. **Final palette lock.** STEAM_PAGE_DRAFT §5 names the palette
   (purple-dusk + amber + arcane-cyan + enemy-red); GAPS §1 does not
   reaffirm it. *Decision:* lock these four hex values explicitly so
   Hunyuan3D texture passes and FLUX prompts can be rewritten with concrete
   hex codes (e.g. cyan `#21d4fd`) rather than "arcane-cyan" prose.

7. **Boss mesh canon.** §1.1 names three bosses (`bone_dragon`,
   `shadow_lord`, `void_titan`) but the design brief does not specify their
   in-fiction lore. *Decision:* are the prompts in §2A (skeletal dragon /
   hooded sorcerer-king / faceless void giant) directionally correct, or is
   there an existing design pillar that should reframe them?

8. **Hunyuan3D vs. external commissioning.** §1.3 #2 estimates "3–5 days
   sourcing or commissioning 5+ low-poly models." *Decision:* is local
   Hunyuan3D output acceptable for shipping, or is a commissioned-Synty-pack
   purchase the preferred route? This determines whether §2A and §2B run
   through the local pipeline at all.

---

*Plan authored 2026-04-25. Bound to GAPS audit dated 2026-04-24. Re-derive
if `gamepacks/rogue_survivor/` adds new entities or `assets/` adds new
shipping art before generation begins.*
