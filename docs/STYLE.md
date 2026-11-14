# Style sheet

The visual contract for every asset (DESIGN §13, Visual direction and Asset &
tool pipeline). Built before any illustration; every illustrated asset is
checked against it.

## 1. The look in one paragraph

Premium cel-shaded fantasy, like a still from a modern hand-drawn animated
feature: clean ink lines, flat rich colour, two or three hard-edged tones of
shading, layered scenes with morning mist. The era feel comes from the
subject matter (banners, stone, lanterns, arched doors, a hand-drawn-feeling
map). Not pixel art. Not flat corporate vector. Not a copy of any existing
game, film or studio's look. The interface should feel expensive, not busy.

**Changed on 14 November 2026, by Adam.** The look was "modern painterly"
with no outlines (DESIGN §13 as written). After seeing a painterly trial he
asked for an animation feel instead, compared a cel-shaded pair with a retro
animation pair, and chose cel-shaded. See DECISIONS.md D-48. Palette,
lighting, mood, type and the interface are unchanged.

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

## 3. Line and shading treatment

- **Clean, confident ink outlines** of varying weight: heavier on the
  silhouette, lighter inside the form.
- **Flat colour fills** with two or three hard-edged tones of shading. No
  soft airbrushing and no photographic detail.
- Large simple shapes; detail is drawn with line, not rendered.
- Backgrounds are simpler and softer than the subject, so it reads first.
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

> Original cel-shaded fantasy animation still, in the manner of a modern
> hand-drawn animated feature. Clean confident ink outlines of varying
> weight, flat colour fills with two or three hard-edged tones of shading, no
> soft airbrushing. Rich saturated colour built on deep forest greens and
> warm gold light, with parchment-cream highlights and cool slate-blue
> shadows. Low warm dawn light from the upper left with a crisp warm rim
> light, light morning mist between layered depths. Subject matter from an
> old pastoral valley: banners, weathered stone, glass lanterns, arched
> wooden doors, hand-built timber. Warm, welcoming and calm; nothing
> frightening. Clear readable silhouette, bold simple shapes, simple
> uncluttered background, generous negative space. Not pixel art, not
> photorealistic, not a 3D render, not an oil painting. No text, no
> lettering, no logos, no watermark, no border.

Each asset adds one line after it, starting `Subject:` (listed per asset in
ASSETS.md). Nothing else in the prompt changes. Never add "in the style of"
any artist, studio or game.

Notes from the first pieces, for writing Subject lines:

- Say "shown from the chest up" for a character; the word "portrait" pulls
  the result toward oil portraiture.
- Name coat and clothing colours outright (the palette words otherwise leak
  into fur: the first hound came out green).
- For companions, name a bright setting ("simple sunlit green meadow
  background at dawn"); left open, the background drifts dark and moody.

**How the pieces are made.** Adobe Firefly on the web, model **Firefly
Image 5** (Adobe's own model), 1K, 1:1 for characters and 4:3 for scenes,
one generation per piece, in Adam's Adobe account. The Adobe connector in
Claude cannot generate; it finds the generations and can crop, resize and
grade them. Every piece and its Subject line is recorded in ASSETS.md.

## 7. Reference board

The first three approved illustrated assets are the reference board that all
later ones are checked against (line weight, flat shading, palette, light
direction, mood).

| Slot | Asset | Status |
|---|---|---|
| 1 | Companion: Hound | generated 14 Nov 2026; look approved by Adam |
| 2 | Hero: Wayfarer | generated 14 Nov 2026; approved by Adam |
| 3 | Discovery card: the standing stone | generated 14 Nov 2026; look approved by Adam |

The superseded painterly trial (three pieces) and the retro animation pair
stay in Adam's Firefly history and are not used.

## 8. IP guardrails (DESIGN §13)

All art is original. No Nintendo or other third-party names, characters,
items, maps, fonts, sounds or copied designs. No traced work. No photos.
