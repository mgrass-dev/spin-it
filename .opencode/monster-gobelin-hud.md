## Goal
- Integrate enemy portrait HUD (`monster_gobelin_hud.png`, 96×72 px) into combat UI and make it render with pixel-perfect sharpness like all other pixel-art assets.

## Constraints & Preferences
- Do NOT modify the source PNG asset
- Do NOT change game resolution or viewport stretch settings
- Do NOT build a generic enemy portrait system — only the single goblin portrait
- Make it render identically to working pixel-art assets (roulette slots, ball, backgrounds)

## Progress
### ✅ Done
- Added `monster_gobelin_hud.png` (uid://86andjp6nfn7) as `ExtResource("13_hud")` in combat.tscn
- Added `EnemyPortrait` Sprite2D child of `UILayer` (CanvasLayer, layer=5), position (120,80), scale (3,3)
- Import file now **identical** to all working assets: `compress/mode=0` (Lossless), `mipmaps/generate=false`, `fix_alpha_border=true`, `vram_texture=false`
- `texture_filter = 1` on EnemyPortrait node, UILayer (parent CanvasLayer), and test scene — **matching the exact pattern** from working assets (`roulette_slot.tscn` uses `texture_filter = 1`, `roulette_wheel.tscn` uses `texture_filter = 1`)
- Project default: `rendering/textures/default_filters/texture_filter=0` (NEAREST) so any inherited value also resolves to NEAREST
- Created standalone test scene `scenes/test_portrait.tscn` for isolated testing
- All three import settings now verified: portrait matches inclinecase.png, soclebleu.png, and cercle.png exactly (line-by-line identical)

### ❌ Still Broken
- Portrait is reported as blurry despite all above fixes

### 🕵️ Remaining Unchecked
1. **Source PNG anti-aliased edges** — pixel analysis found 8 semi-transparent pixels and 377 unique colors in a 96×72 asset. At 3× NEAREST upscale, semi-transparent edge pixels become visible 3×3 blocks with 50% alpha, which the user may perceive as "fuzzy/blurry" edges. User stated "source PNG is not the issue" but this is the only technical difference vs downscaled working assets.
2. **Stale texture cache** — the `.ctex` file at `res://.godot/imported/monster_gobelin_hud.png-1d62b4ec691b5e93e80de3096942ae36.ctex` may have been generated with a prior wrong `fix_alpha_border=false` setting. Try deleting it and letting Godot reimport.
3. **Viewport stretch mode** — `stretch/mode="viewport"`, `aspect="keep"`, `scale_mode=1` was set earlier. User said to stop investigating this, but if window size doesn't match 1280×720 exactly, the viewport blit could add final-stage filtering. Noted for reference.

## Key Decisions
- Sprite2D (not TextureRect/Control) to match all other game sprites
- `texture_filter = 1` (matching roulette_slot.tscn pattern exactly) — the value `0` is now replaced
- Portrait under UILayer CanvasLayer so it renders above combat backgrounds alongside HP bars/launch button
- All three import files now line-by-line identical to working assets

## Relevant Files
- `scenes/combat/combat.tscn` lines 47, 61–65 — UILayer and EnemyPortrait nodes
- `project.godot` lines 27–29, 44 — stretch mode + default texture filter
- `sprites/hud/monster_gobelin_hud.png.import` — now identical to working asset imports
- `scenes/test_portrait.tscn` — standalone debug scene
- `scripts/roulette/roulette_wheel.gd` line 286 — reference: `_ball_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST`
