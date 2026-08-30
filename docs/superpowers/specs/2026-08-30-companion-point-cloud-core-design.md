# LIVELVL Companion Point-Cloud Core Design

**Date:** 2026-08-30  
**Status:** Approved design  
**Scope:** Today growth card artwork and its collapsed center state

## Goal

When the Today growth card is expanded, it shows artwork for the active companion's current stage. When the card is collapsed, its shell docks below the Today title while the artwork appears to dissolve into a restrained point-cloud core inside the six-dimension field.

The result must feel premium, minimal, futuristic, and motion-led without obscuring the six official points, projected points, labels, polygon edges, or hit targets.

## Product Decisions

- Every companion owns four black-and-white source images, one for each `CompanionStage`: `juvenile`, `stageTwo`, `stageThree`, and `mature`.
- The pilot artwork uses the supplied files in numeric order:
  - `3-1_68df21d88fc73eb3e08e67e2be62e3d9-拆分组1.jpg` → `juvenile`
  - `3-2_68df21d88fc73eb3e08e67e2be62e3d9-拆分组1.jpg` → `stageTwo`
  - `3-3_68df21d88fc73eb3e08e67e2be62e3d9-拆分组1.jpg` → `stageThree`
  - `3-4_68df21d88fc73eb3e08e67e2be62e3d9-拆分组1.jpg` → `mature`
- The pilot set is temporarily bound to `ordinary.sprout`; no progression thresholds, collection rules, or companion ordering change.
- This phase builds the renderer, stable resource contract, and pilot mapping only. Bulk import and artwork-management UI are separate future work.
- The collapsed point cloud is tappable and expands the full growth card. VoiceOver exposes the docked growth bar as the single accessible expansion control, avoiding duplicate announcements.

## Artwork Resource Contract

Artwork is addressed by a stable compound identity:

```text
CompanionArtworkID {
  collectibleID
  stage
}
```

A bundled manifest maps each identity to a resource filename. Runtime code depends on an artwork-provider boundary rather than reading filenames directly. The initial provider reads bundled local resources; a future Application Support provider can use the same identity without changing Today rendering.

No SwiftData migration, network access, account state, or cloud synchronization is introduced in this phase. Missing, unreadable, or malformed artwork falls back to the existing generic point-cloud orb so Today always remains usable.

## Image Processing

Each source image is decoded off the main actor and converted into a deterministic normalized point descriptor:

- Ignore the shallow outer border region so the pale rounded card frame never becomes artwork.
- Convert pixels to luminance and alpha-weighted ink intensity; discard near-white JPEG noise.
- Preserve full-canvas coordinates and each stage's relative scale. Do not normalize every stage to the same subject bounds; the pilot galaxy must visibly grow from a small core into a large mature system.
- Use deterministic weighted sampling so the same image always produces the same point positions.
- Keep a bounded canonical descriptor and select a smaller visible subset for the collapsed core.
- Cache descriptors in memory by artwork identity, content fingerprint, and renderer-version value. Only the active stage and optional next-stage ghost are retained; hundreds of future assets do not load together.

Processing thresholds and point budgets are calibrated against all four pilot images, including the dense mature image and the faint juvenile orbit.

## Visual Composition

### Expanded card

- Replace the generic card orb with the current stage's processed artwork.
- Preserve the existing rounded iOS card shell, XP content, sizing, and collapse control.
- Render enough points to preserve the source image's orbit structure at card scale.

### Collapsed state

- Keep the approved translucent dock below the Today title.
- Render the stage artwork as a roughly 100–110pt transparent point cloud centered on `LifeFieldLayout.visualCore`.
- Place it above the ambient background dots but below the official polygon, flowing edge particles, projected markers, official nodes, labels, and hit targets.
- Do not add an opaque center surface, permanent radial connectors, extra text, or a second progress card.
- The center hit area is at least 44×44pt; the visible artwork remains non-opaque so field geometry stays legible.

## Motion and Growth Meaning

- Collapsing separates the two visual roles: the white card shell moves and fades into the top dock, while the stage artwork remains spatially anchored, scales down, scatters briefly, and resolves into the center point cloud.
- Expanding reverses the sequence: the center points converge into the full-card artwork while the shell returns.
- Ambient motion uses slow opposing orbital drift, very small per-point displacement, and a long breathing cycle. It must read as alive rather than busy.
- XP progress controls stability and resolution, not arbitrary color:
  - the current stage stays dominant;
  - near the end of a non-mature stage, a low-opacity subset of the next stage may appear as ghost particles;
  - the next stage never replaces the official current stage before progression actually occurs.
- A task reward produces one short, restrained density/scale pulse in the core. It does not recreate center-to-dimension radial lines.
- A real stage change disperses the old descriptor and converges the new descriptor. A companion switch uses the same transition with the new companion identity.
- With Reduce Motion enabled, orbital drift, scattering, convergence, and breathing freeze. State changes use a short opacity crossfade only.

## Performance and Lifecycle

- Use SwiftUI `Canvas` with a paused `TimelineView` when the scene is inactive, the view is off-screen, or Reduce Motion is enabled.
- Image decoding and descriptor generation never run in `body` and never block the main actor.
- Point counts are bounded independently for expanded and collapsed presentations.
- Rapid fold/unfold or companion changes cancel obsolete processing and animation work; stale descriptors cannot overwrite the current artwork.
- Corrupt artwork reports no modal error in Today; the generic fallback renders immediately.

## Accessibility

- The docked bar retains the companion, stage, level, XP value, hint, and stable accessibility identifier.
- The center point cloud is visually tappable but hidden from the accessibility tree because it duplicates the dock's expansion action.
- Dynamic Type does not resize the point cloud into labels or nodes; the existing enlarged field and dock spacing remain authoritative.
- Increase Contrast strengthens official field geometry, not the decorative point cloud.

## Verification

Strict TDD covers:

- stable four-stage artwork identity and manifest lookup;
- correct pilot stage ordering and `ordinary.sprout` mapping;
- border/noise rejection and preservation of relative stage scale;
- deterministic point output, bounded counts, and valid normalized coordinates;
- cache hits, cancellation, missing/corrupt fallback, and current-stage isolation;
- next-stage ghosts never becoming official early;
- collapsed layer ordering and minimum hit area;
- normal motion changes samples while Reduce Motion freezes them;
- companion/stage changes select the new descriptor without stale overwrite.

Simulator acceptance on iPhone 17 Pro covers all four stages, fold/unfold continuity, task-reward pulse, field readability, repeated rapid toggles, Dynamic Type, VoiceOver, Reduce Motion, cold launch, and memory stability while cycling the four pilot images.

## Out of Scope

- Bulk import, batch naming, editing, deletion, and library management.
- New companion progression rules or collection-domain changes.
- Archive, Rewards, or You redesign.
- Network, account, cloud, or payment behavior.
