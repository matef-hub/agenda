---
name: Juris Modern
colors:
  surface: '#f2fcf3'
  surface-dim: '#d2ddd4'
  surface-bright: '#f2fcf3'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#ecf6ee'
  surface-container: '#e6f0e8'
  surface-container-high: '#e1ebe2'
  surface-container-highest: '#dbe5dd'
  on-surface: '#151d19'
  on-surface-variant: '#424843'
  inverse-surface: '#29322d'
  inverse-on-surface: '#e9f3eb'
  outline: '#727973'
  outline-variant: '#c1c8c1'
  surface-tint: '#446652'
  primary: '#062919'
  on-primary: '#ffffff'
  primary-container: '#1e3f2e'
  on-primary-container: '#87aa94'
  inverse-primary: '#aacfb8'
  secondary: '#7b581e'
  on-secondary: '#ffffff'
  secondary-container: '#fdcc87'
  on-secondary-container: '#78551b'
  tertiary: '#002918'
  on-tertiary: '#ffffff'
  tertiary-container: '#15402b'
  on-tertiary-container: '#7fac91'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#c6ebd3'
  primary-fixed-dim: '#aacfb8'
  on-primary-fixed: '#002112'
  on-primary-fixed-variant: '#2c4d3c'
  secondary-fixed: '#ffddb1'
  secondary-fixed-dim: '#eebe7b'
  on-secondary-fixed: '#291800'
  on-secondary-fixed-variant: '#614006'
  tertiary-fixed: '#bfedd0'
  tertiary-fixed-dim: '#a3d1b4'
  on-tertiary-fixed: '#002112'
  on-tertiary-fixed-variant: '#254f39'
  background: '#f2fcf3'
  on-background: '#151d19'
  surface-variant: '#dbe5dd'
typography:
  headline-lg:
    fontFamily: IBM Plex Sans
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 38px
  headline-md:
    fontFamily: IBM Plex Sans
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 30px
  headline-sm:
    fontFamily: IBM Plex Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 26px
  title-md:
    fontFamily: IBM Plex Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  title-sm:
    fontFamily: IBM Plex Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  body-lg:
    fontFamily: IBM Plex Sans
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: IBM Plex Sans
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: IBM Plex Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-md:
    fontFamily: IBM Plex Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.2px
  label-sm:
    fontFamily: IBM Plex Sans
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.1px
  numeric-code:
    fontFamily: IBM Plex Sans
    fontSize: 13px
    fontWeight: '600'
    lineHeight: 16px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 0.75rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

This design system is engineered specifically for attorneys, legal counsels, and law offices operating in fast-paced judicial and advisory environments. The aesthetic pairs the authoritative gravitas of legal heritage with the frictionless utility of high-end modern productivity tools.

Key brand attributes:
- **Judicious & Authoritative**: Grounded, sober, and exact. It inspires instant institutional confidence without feeling bureaucratic.
- **Cognitive Clarity**: High-density case calendars, power-of-attorney tracking, and docket registries are presented with zero visual clutter.
- **Refined Prestige**: Warm sand accents and deep forest green establish a bespoke, executive tone suited for senior partners and client-facing legal proceedings.

The design movement combines **Contemporary Editorial Polish** with **High-Density Utility**. It relies on crisp spatial cadences, subtle tonal borders, deliberate structural cards, and native right-to-left (RTL) reading patterns.

## Colors

The palette is tuned for long sessions of reading legal briefs and schedules under varied lighting conditions, steering away from stark clinical grays into a natural, dignified spectrum.

### Roles & Semantic Mapping
- **Primary (`#1E3F2E`)**: Deep Forest Olive Green. Applied to structural headers, primary calls-to-action, bottom navigation anchors, and authoritative legal statuses.
- **Primary Hover / Active (`#2A543E`)**: High-touch state for active button depressions, selected navigation pills, and focused interactive surfaces.
- **Primary Tonal Backgrounds (`#E8EFEA`, `#D6E4DB`)**: Sage green tints for soft badges, active filters, selected list tiles, and high-priority date markers.
- **Secondary / Accent (`#C69A5A`)**: Warm Sand / Dull Gold. Reserved for executive actions, verification seals, retained retainer accounts, and critical alert highlights.
- **Canvas (`#F7F9F7`)**: Warm off-white slate that reduces retinal strain during prolonged contract and docket reviews.
- **Surface (`#FFFFFF`)**: Pure white containers flanked by subtle bounding lines (`#E3E8E4`).
- **Text & Content**:
  - Headings & Primary Copy: `#1A231E` (Deep charcoal green-black)
  - Subheads & Metadata: `#65756C` (Muted olive-slate)
- **Status & Legal Workflow**:
  - *Postponed / In-Review (Amber)*: Foreground `#E67E22` on Container `#FEF5E7`
  - *Resolved / Validated (Green)*: Foreground `#27AE60` on Container `#E8F8F0`
  - *Urgent / Dismissed / Danger (Crimson)*: Foreground `#E74C3C` on Container `#FDF2E9`

## Typography

The type system is powered by IBM Plex Sans (with seamless Arabic glyph support via IBM Plex Sans Arabic). It offers clear tabular discernment for alphanumeric case filings, power of attorney (PoA) serial numbers, court session times, and monetary retainers.

### Principles & Scale
- **RTL Legibility**: Baseline metrics and line-heights are relaxed by 8–12% relative to Latin-only scales to accommodate calligraphic Arabic ascenders and descenders comfortably.
- **Monospaced Numerics (`numeric-code`)**: Case citations (e.g., `CAS-2024-8849/C`), court circuit codes, and dates must use proportional lining or monospaced figure settings (`tnum`) to maintain vertical alignment inside schedules and ledger rows.
- **Hierarchy Strategy**:
  - Case and client titles use `title-md` (`16px / 600`) to maximize scanability without dominating cards.
  - Secondary tags, hearing locations, and filing authorities use `body-md` and `body-sm` (`#65756C`).

## Layout & Spacing

A compact, fluid layout architecture optimized for hand-held mobile execution and high-density legal workloads.

### Layout Mechanics
- **Grid Structure**: 4-column fluid mobile grid with 12px (`0.75rem`) gutters and a strict 16px (`1rem`) lateral canvas margin.
- **RTL Flow Orientation**:
  - Horizontal axes lead right-to-left. Primary visual anchors (case numbers, client initials, status chips) sit on the right margin.
  - Temporal flows (session time, chevron navigation, dismiss triggers) sit on the opposing left margin.
- **Vertical Rhythm**: A strict 4px / 8px incremental scale handles compact spatial efficiency. Information density must remain high while maintaining minimum touch targets of 44×44px for accessibility during transit between courtrooms.

## Elevation & Depth

Visual hierarchy uses **low-contrast micro-outlines paired with diffused organic ambient shadows**. Heavy, dramatic drop shadows are avoided to maintain an understated, professional demeanor.

### Depth System
1. **Level 0 (Canvas Base)**: `#F7F9F7` flat baseline.
2. **Level 1 (Card & Row Surfaces)**: `#FFFFFF` bounded by a 1px continuous hairline outline in `#E3E8E4`. Soft atmospheric shadow: `0 1px 3px rgba(30, 63, 46, 0.04)`.
3. **Level 2 (Active Controls, Segmented Pickers, Dropdowns)**: `#FFFFFF` elevation with a tinted shadow: `0 3px 8px rgba(30, 63, 46, 0.08)`, border `#D6E4DB`.
4. **Level 3 (Floating Action Button & Bottom Navigation)**:
   - Primary FAB: `#1E3F2E` with glow shadow `0 6px 16px rgba(30, 63, 46, 0.24)`.
   - Bottom Nav Bar: Grounded `#FFFFFF` with top edge stroke `#E3E8E4` and inverted ambient elevation `0 -4px 16px rgba(26, 35, 30, 0.05)`.
5. **Level 4 (Modals, Sheet Drawers)**: Surface `#FFFFFF` bordered top with `0 -8px 24px rgba(26, 35, 30, 0.12)`.

## Shapes

The design system adopts a **soft (`roundedness: 1`)** architectural silhouette. Subtle curvature conveys modern ergonomics while preserving the crisp, orderly feel required for legal records.

- **Base Radius (0.25rem / 4px)**: Checkboxes, table pill indicators, legal tag chips.
- **Large Radius (0.5rem / 8px)**: Input fields, compact case cards, segmented pill segments, context sheets.
- **Extra Large Radius (0.75rem / 12px)**: Modal overlays, prominent dashboard action widgets.
- **Full Pill (`9999px`)**: The Floating Action Button (FAB), quick filter pills, and badge counters.

## Components

### Buttons
- **Primary Action**: Solid `#1E3F2E` fill, `#FFFFFF` text, 44px min height, 8px corner radius. Press state shifts to `#2A543E`.
- **Secondary Action**: Bordered 1px `#1E3F2E`, transparent surface, `#1E3F2E` text.
- **Subtle / Ghost**: Transparent fill, `#1E3F2E` text, active hover `#E8EFEA`.
- **Floating Action Button (FAB)**: 56×56px circle or 48px height extended pill with a gold or white `+` icon, anchored 16px above the navigation bar on the start (right) or center-trailing side.

### Legal Case & Docket Cards
- **Structure**: Surface `#FFFFFF`, border 1px `#E3E8E4`, radius 8px, padding 12px 14px.
- **Header Line (RTL)**: Leading right with Case Type Tag (e.g., "استئناف مدني") in `#E8EFEA` container (`#1E3F2E` text) alongside the bold case code. Leading left shows the court session time or status badge.
- **Body**: Client name in `title-md`, opposing counsel or court circuit in `body-sm` (`#65756C`).
- **Footer**: Integrated key-value pair for Next Hearing Date and Power of Attorney Number (`numeric-code`), visually separated by a 1px dashed divider `#E3E8E4`.

### Search & Quick Filters
- **Search Bar**: 40px height, inset surface `#FFFFFF`, 1px border `#E3E8E4`, with search icon aligned to the right margin. Placeholder text in `#65756C`.
- **Quick Filter Row**: Horizontally scrollable row of 28px height chips. Unselected: `#FFFFFF` border `#E3E8E4` text `#65756C`. Selected: `#1E3F2E` background with `#FFFFFF` text, no border.

### Segmented Controls
- **Track**: `#E8EFEA` fill, 36px total height, 8px radius, 3px inner padding.
- **Active Segment**: `#FFFFFF` card, 6px radius, elevation level 2, text `#1E3F2E` (`title-sm`).
- **Inactive Segment**: Transparent, text `#65756C` (`body-md`).

### Form Elements & Checkboxes
- **Input Fields**: 44px height, `#FFFFFF` surface, 1px border `#E3E8E4`, focus state `#1E3F2E` 1.5px border with `#E8EFEA` subtle halo. RTL label aligned right with optional PoA/Civil ID indicator.
- **Checkboxes & Radios**: 18×18px, 4px corner radius for checkboxes. Unchecked border `#65756C`. Checked `#1E3F2E` fill with sharp white mark.

### Bottom Navigation Bar
- **Dimensions & Style**: Fixed 64px height + device safe bottom inset. Background `#FFFFFF`, border-top 1px `#E3E8E4`.
- **Tabs**: 4 to 5 core items (e.g., جلسات اليوم / Sessions, القضايا / Cases, الوكالات / PoA, العملاء / Clients, المزيد / More).
- **Tab State**: Active item uses `#1E3F2E` icon and text with an 8px vertical indicator dot or subtle `#E8EFEA` rounded background pad. Inactive uses `#65756C`.