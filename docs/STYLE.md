# Style sheet

The visual contract for every asset (DESIGN §13, Visual direction and Asset &
tool pipeline). Built before any illustration; every illustrated asset is
checked against it.

## 1. The look in one paragraph

Premium modern painterly fantasy: rich, saturated colour, soft light, layered
illustrated scenes. The era feel comes from the subject matter (banners,
stone, lanterns, arched doors, a hand-drawn-feeling map), rendered to today's
standard. Not pixel art. Not flat corporate vector. Not a cartoon clone of
any existing game. The interface should feel expensive, not busy.

## 2. Palette

| Role | Name | Hex |
|---|---|---|
| Deepest background | Forest Night | `#0C2620` |
| App background | Forest Deep | `#12352C` |
| Primary green | Forest | `#1D4C3F` |
| Lively green | Moss | `#3B7C60` |
| Soft green | Sage | `#9FC2AB` |
| Mist | Mist | `#D7E4DE` |
| Warm gold | Gold | `#D9A441` |
| Highlight gold | Gold Bright | `#F5D27A` |
| Shadow gold | Gold Deep | `#9A6A21` |
| Fire / warmth | Ember | `#E27A3B` |
| Dawn sky | Dawn Peach `#F6C08F`, Dawn Rose `#E59A86` | |
| Upper sky | Sky Deep `#1B3550`, Sky Mid `#3D6480` | |
| Card | Parchment | `#F8F0DE` |
| Card shade / edge | Parchment Shade `#EDDFC2`, Parchment Edge `#D7C39B` | |
| Text | Slate `#24303A`, Slate Soft `#566570` | |
| Text on dark | `#F3ECDB`, soft `#B9CEC3` | |
| Companion accent | Terracotta `#C5653C`, deep `#8E4425`, tint `#FCEBDB` | |
| The Still | Still Grey | `#9BA7A8` |

Attributes: Vitality `#C2573F`, Care `#D08A3E`, Craft `#7B5EA7`,
Mind `#3C78A8`, Adventure `#3B8A68`, Order `#5F7482`.
Materials: Timber `#9A6B3F`, Stone `#7F8C92`, Star Shards `#6C7FD0`.

**Asleep vs awake.** Anything under the Still is the same picture drained to
about 20% saturation and lifted slightly toward grey. Restoration brings the
full palette back. Nothing is ever darkened into menace.

## 3. Brush and line treatment

- Soft, visible brushwork, like gouache or oil sketch. Edges are painted, not
  inked: **no hard black outlines**.
- Large simple shapes first, then two or three passes of smaller strokes.
- Texture comes from brush direction and a light canvas grain, not from noise
  or photographic detail.
- Silhouettes read clearly at thumbnail size.

## 4. Lighting

- One key light: **low, warm, from the upper left** (dawn), colour near
  Gold Bright.
- Cool slate-blue shadows; a thin warm rim light on the shadow side.
- Morning mist between depth layers, lighter toward the horizon.
- Lanterns and windows are the only strong point lights.

## 5. Type and interface

- Headings: **Fraunces** (display serif), SemiBold and Bold.
- Body: **Figtree** (clean sans), Regular to Bold.
- Both bundled under the SIL Open Font License 1.1.
- Cards are parchment with a fine gold or parchment edge, 18–26dp corners,
  one soft shadow. Generous spacing; touch targets 44dp or larger.
- Icons: one original line-icon set on a 24-unit grid, 1.8-unit round
  strokes, drawn in code.

## 6. Style prompt (reuse verbatim for every illustrated asset)

> Original painterly fantasy illustration, modern digital gouache with soft
> visible brushwork and no hard outlines. Rich saturated colour built on deep
> forest greens and warm gold light, with parchment-cream highlights and cool
> slate-blue shadows. Low warm dawn light from the upper left, a thin warm rim
> light, light morning mist between layered depths. Subject matter from an
> old pastoral valley: banners, weathered stone, glass lanterns, arched wooden
> doors, hand-built timber. Warm, welcoming and calm; nothing frightening.
> Clear readable silhouette, simple uncluttered background, generous negative
> space. High modern rendering standard. Not pixel art, not flat vector, not
> cartoon, not photorealistic. No text, no lettering, no logos, no watermark,
> no border.

Each asset adds one line after it, starting `Subject:` (listed per asset in
ASSETS.md). Nothing else in the prompt changes. Never add "in the style of"
any artist, studio or game.

## 7. Reference board

The first three approved illustrated assets become the reference board that
all later ones are checked against (palette match, brush treatment, light
direction, mood).

| Slot | Asset | Status |
|---|---|---|
| 1 | Companion portrait: Hound | not yet generated |
| 2 | Hero portrait: Wayfarer | not yet generated |
| 3 | Discovery card: The Listening Stone | not yet generated |

Until these exist, Phase 1 uses code-drawn stand-ins that follow sections 2–5
(see ASSETS.md for exactly which).

## 8. IP guardrails (DESIGN §13)

All art is original. No Nintendo or other third-party names, characters,
items, maps, fonts, sounds or copied designs. No traced work. No photos.
