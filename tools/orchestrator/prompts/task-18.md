Task #18: Produce docs/ART_ASSET_PLAN.md — a concrete, prompt-ready plan for generating every missing visual asset for the rogue_survivor GamePack.

This is `SHIP_PLAN.md` priority #1 ("第一要务：美术资源生成管线"). The deliverable is a planning document that downstream image-gen tools (FLUX, Stable Diffusion, Midjourney) can consume directly.

Procedure:
1. Read `docs/ROGUE_SURVIVOR_GAPS.md` §1 in full — it enumerates the existing visual assets and the gap, broken into:
   - §1.1 Entity-by-entity (heroes, enemies, bosses, etc.)
   - §1.2 Spell / card icons
   - §1.3 Art section summary — critical shipping gaps
2. For each missing asset family, produce:
   - **Asset name** + canonical filename + intended path under `assets/` (be consistent with the existing convention you observe — verify by listing `assets/`).
   - **Style anchor** — which existing shipped asset (or external reference like KayKit, Synty, Brotato) the new piece should match.
   - **Generation prompt** — a single ≤80-word prompt suitable for FLUX or Midjourney. Tighten ruthlessly; image-gen prompts that exceed 80 words usually under-perform.
   - **Negative prompt** if applicable (1-line max), e.g. "no text, no UI, no watermark".
   - **Aspect ratio** + **resolution** target.
   - **Acceptance check** — one sentence describing what makes the output usable vs. needing a re-roll.
3. Group prompts by batch the user can run together (e.g. "all hero portraits" → 1 batch, "all card frames" → 1 batch). Order batches by criticality from §1.3.
4. Include a short §0 "Tooling" header naming which local pipeline produces what (Hunyuan3D for 3D meshes per `tools/setup/install_hunyuan3d_mac.sh`; FLUX/SD/MJ via the user's existing image-gen access for 2D). Do NOT propose installing new tooling — work within what's already documented.
5. End with §N "Open questions for designer" — anything that needs a human design call before any prompt can be authored (e.g. final palette, character canon).

Constraints:
- Do NOT generate any actual images.
- Do NOT modify game code or asset files.
- Do NOT invent style references that don't already exist in the project.
- If GAPS §1 is silent on a category, do NOT make up assets — note the silence.

Output structure (suggested):
```
# Art Asset Generation Plan
## 0. Tooling
## 1. Hero portraits & icons
## 2. Enemy & boss visuals
## 3. Card frames & rarity treatments
## 4. Spell / status icons
## 5. UI & HUD chrome
## 6. Capsule / promotional art (cross-ref STEAM_PAGE_DRAFT.md §5)
## 7. Open questions for designer
```

Rules:
- No git, no game code changes.
- Single window, no `[ROTATE]`.
- Emit `[DONE]` when the plan is saved.

Deliverable: `docs/ART_ASSET_PLAN.md`
