---
name: PropertyVisit
description: Residential Index — photo-led property comparison and practical viewing workflows.
colors:
  accent: "#1D63C6"
  header: "#163E71"
  accent-soft: "#E9F0FB"
  background: "#F2F5F9"
  surface: "#FFFFFF"
  ink: "#172B42"
  ink-muted: "#53667C"
  border: "#DCE4EE"
  pending: "#835510"
  pending-soft: "#FFF1D7"
  confirmed: "#246449"
  confirmed-soft: "#E4F3EB"
  cancelled: "#9C383A"
  cancelled-soft: "#FBE9E9"
  dark-primary: "#A8C8FF"
  dark-on-primary: "#102E55"
  dark-background: "#101824"
  dark-surface: "#151F2D"
  dark-ink: "#E5EDF7"
  dark-ink-muted: "#B3C2D5"
  dark-border: "#35455A"
  dark-primary-container: "#233F61"
  dark-on-primary-container: "#D9E7FF"
typography:
  headline-large:
    fontSize: "32px"
    fontWeight: 700
    letterSpacing: "-0.8px"
  headline-medium:
    fontSize: "28px"
    fontWeight: 700
    letterSpacing: "-0.6px"
  listing-price:
    fontSize: "24px"
    fontWeight: 700
    letterSpacing: "-0.5px"
  title-large:
    fontSize: "22px"
    fontWeight: 700
  title-medium:
    fontSize: "16px"
    fontWeight: 600
  body-large:
    fontSize: "16px"
    fontWeight: 400
  body-medium:
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
  body-small:
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.45
  button:
    fontSize: "16px"
    fontWeight: 600
  status:
    fontSize: "12px"
    fontWeight: 600
rounded:
  photo-filter: "8px"
  control-container: "10px"
  status-pill: "999px"
spacing:
  micro: "4px"
  compact: "8px"
  control-gap: "12px"
  standard: "16px"
  card-inset: "20px"
  page: "24px"
  section: "28px"
  large: "32px"
  hero-gap: "48px"
components:
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.surface}"
    typography: "{typography.button}"
    rounded: "{rounded.control-container}"
    padding: "14px 20px"
  button-primary-dark:
    backgroundColor: "{colors.dark-primary}"
    textColor: "{colors.dark-on-primary}"
    typography: "{typography.button}"
    rounded: "{rounded.control-container}"
    padding: "14px 20px"
  button-outlined:
    textColor: "{colors.accent}"
    rounded: "{rounded.control-container}"
    padding: "14px 20px"
  button-text:
    textColor: "{colors.accent}"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control-container}"
    padding: "16px"
  filter:
    textColor: "{colors.ink}"
    rounded: "{rounded.photo-filter}"
    padding: "10px 12px"
  listing:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
  viewing-card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.control-container}"
    padding: "20px"
  status-pending:
    backgroundColor: "{colors.pending-soft}"
    textColor: "{colors.pending}"
    typography: "{typography.status}"
    rounded: "{rounded.status-pill}"
    padding: "5px 10px"
  navigation-material:
    backgroundColor: "{colors.surface}"
    height: "72px"
---

# Design System: PropertyVisit

## Overview

**Creative North Star: "Residential Index"**

Residential Index is a practical, buyer-first property interface: useful photographs, price-first facts and a direct path to a viewing. The approved direction uses a deep-blue search region, white listing surfaces and quiet dividers rather than promotional heroes or decorative dashboards. The palette is described plainly; no additional branding story is implied.

This records the implemented Flutter application, including its dark counterpart and manager workflows, not a web mock or future redesign. Shared controls remain Material 3; selected platform-adaptive behaviors are described below. Preserve Russian copy and the PropertyVisit name.

**Key Characteristics:**
- Photo-led, price-first comparison rows.
- Deep-blue search region and restrained blue selection.
- Platform-resolved typography with shared Material 3 controls.
- Bounded content and two-destination navigation.
- Explicit illustrative-photo disclosure.

Evidence: `propertyvisit/lib/core/theme/app_theme.dart`, shared widgets and shell, and buyer/manager screen implementations. The approved sketch at `.impeccable/mocks/decision/residential-index.html` establishes direction, not production CSS tokens. `.impeccable/review/*-widget.png` captures are widget tests with Segoe substituted for native fonts, not iPhone/Android simulator captures. Native device verification is unavailable; neither native correctness nor release readiness is claimed. No web-style detector pass applies to this native Flutter artifact.

## Colors

Deep blue contains search, cobalt marks action, and cool blue-gray neutrals keep photographs and facts legible.

### Primary
- **Deep blue** (`header`): catalog app bar and search background, with white foreground, unchanged in dark mode.
- **Cobalt** (`accent`): light-mode primary actions and selection; **pale blue** (`accent-soft`) is the light primary container with deep-blue foreground.
- **Light blue** (`dark-primary`): dark-mode primary actions; pair with `dark-on-primary`. Dark selection uses `dark-primary-container` with `dark-on-primary-container`.

### Neutral
- `background` is the cool page ground; `surface` is the white field, listing and control surface. `ink`, `ink-muted` and `border` carry primary facts, supporting facts and quiet separators.
- Dark counterparts are `dark-background`, `dark-surface`, `dark-ink`, `dark-ink-muted` and `dark-border`; use the theme's semantic roles rather than applying light colors directly.

### Functional states
- Amber `pending` on `pending-soft`, green `confirmed` on `confirmed-soft`, and red `cancelled` on `cancelled-soft` accompany explicit Russian status labels. These status pairs currently stay the same in both themes.
- Validation and buyer cancellation use the generated Material `ColorScheme.error`, not an invented fixed error hex. Unoverridden Material roles and disabled-state overlays remain framework-derived.

**The Semantic Pairing Rule.** Use foreground/background pairs from the active ColorScheme; reserve the fixed deep-blue header and explicit status pairs for their implemented roles.

## Typography

**Display and body font:** Manrope via the `google_fonts` package, as requested by the user. `GoogleFonts.manropeTextTheme` is applied to both regular and primary text themes in light and dark mode. Material 3's role sizes, existing weights, line heights and text scaling are preserved. No downloaded font files or local font declarations are maintained in the application; Google Fonts handles fetching and caching. The first uncached font load requires internet access. The sidecar preview is not the app's font declaration.

### Hierarchy
- **Headline large:** login headline, bold with slightly tightened tracking.
- **Headline medium:** catalog title, details price and booking success heading.
- **Listing price:** bold `headlineSmall` override; price leads the listing caption.
- **Title large / medium:** app bars, property names, dates and section labels.
- **Body large / medium / small:** descriptions, facts and muted supporting information. Details description alone increases line height to 1.6; do not make that a global body token.
- **Button / status:** primary action labels and compact status text. Outlined and text buttons otherwise retain Material label defaults; not all buttons use the primary label override.

Numbers in frontmatter are Flutter logical-pixel sizes encoded as portable `px`; they are not CSS sizing instructions for the app. Unspecified line heights, tracking and families remain Material defaults. Respect text scaling; the date strip scales its height and fact/action groups wrap where implemented.

**The Facts First Rule.** Preserve price, title, location and room/area hierarchy; do not replace it with ornamental display lettering or uppercase kickers.

## Layout

Buyer content generally uses page insets (24dp) and a centered `ContentWidth` bound (760dp). The login form instead has a 420dp maximum width inside its scrolling, safe-area layout. The catalog list applies its 24dp insets inside the bound; search and the details bottom action apply insets outside their bound. Do not assume identical usable widths merely because both use `ContentWidth`.

At window widths of 840dp and above, the shell switches to a labeled Material navigation rail with a vertical divider; below that it uses bottom navigation. Content remains a single bounded column, not a decorative multi-column dashboard. Manager list edges retain 16dp insets; manager booking cards use 16dp internal padding, while buyer viewing cards use 20dp.

Catalog images use a 1.85:1 crop; details use 1.3:1 and can meet the content edge. Viewing-history thumbnails are 76dp squares. Listing captions begin 16dp below the photograph; dividers separate catalog rows with 24dp vertical padding. Small gaps use the extracted spacing scale, not a universal strict eight-point grid.

Shared text and icon buttons have minimum 48dp targets; filled and outlined buttons have minimum 48dp width and 52dp height. Filters enforce 48dp minimum height. These are source constraints, not a claim that every framework-owned menu, tab or chip has been measured on a device. Safe-area handling exists at screen/action-bar boundaries but native insets and keyboard ergonomics remain unverified.

## Elevation & Depth

Resting app bars and themed cards have zero elevation and transparent surface tint. Listing rows are unboxed on the surface; dividers and tonal page grounds create separation. Buyer history and manager booking cards still exist as useful task containers: the dashboard rejection does not ban all cards. Material dialogs, menus, floating snackbars, the manager add FAB and interactive ink/state overlays retain framework behavior; do not claim a universal no-shadow system or invent custom shadow/motion tokens.

**The Quiet Separation Rule.** Prefer existing dividers and surface contrast over adding shadows to property comparison rows.

## Shapes

Photographs, listing ink bounds and filter controls use modest corners (8dp). Shared fields, filled/outlined buttons, cards and themed dialogs use slightly softer corners (10dp). Status labels are genuine pills (999dp radius), an intentional exception. Choice chips and the extended FAB retain Material component shapes; do not normalize every control to the photo radius.

## Components

### Buttons
Clear, bounded actions. Filled buttons use the active primary/onPrimary pair, themed padding and minimum size; outlined buttons use an outline-variant border. Text and icon buttons preserve lighter Material treatments. Disabled/submitting states use framework styling and replace key action labels with progress indicators where implemented. Hover, focus and press use Material state/ink behavior rather than custom animation.

### Inputs / Fields
Filled surfaces with outline-variant strokes and 10dp corners. Focus uses a 2dp primary border. Labels remain visible, errors use validation messages and theme error color. Email/phone keyboard hints, password visibility and autofill are implemented where relevant; actual platform keyboard behavior is not verified.

### Filters and chips
Catalog filters are Material popup menus with checked entries, outlined 8dp triggers and explicit labels. They are not Cupertino pickers. Booking dates and slots are `ChoiceChip` controls with primary-container selection; unavailable/submitting slots disable interaction. Status pills are noninteractive labeled badges, not action targets; their current colors do not change with brightness.

### Property comparison rows
`PropertyCard` is a shared name, not a raised card treatment: surface-backed Material/InkWell, clipped photograph, then price, title, location, room count and area. Buyer rows navigate to details; manager reuse currently has no tap handler. Bundled demo assets add an illustrative-photo disclosure. `PropertyPhoto` supplies image semantics and a readable unavailable-photo fallback; user-created listings do not receive fabricated photography.

### Viewing cards and booking actions
Buyer history groups status and viewing time above a divider, thumbnail and property details, with adaptive cancellation confirmation. Booking keeps the selected time and primary action below the scrolling form. Details have a bordered, safe-area-aware bottom booking action. Success explicitly shows pending status rather than implying manager confirmation.

### Iconography

App-authored icons use the regular Lucide family from `lucide_icons_flutter`
(`lucide_icons.dart`), not a mixture of filled Material and outline glyphs.
Catalog: `building2`; buyer viewings: `calendarCheck`; admin properties: `house`;
admin bookings: `clipboardList`. Selected destinations keep the same outline
glyph; the existing indicator/tint and visible labels convey selection.
Search, sorting, logout, missing photos, account/contact, password visibility,
admin add and booking success use matching Lucide glyphs. Preserve existing sizes
and minimum touch targets. Framework-owned chip/menu checkmarks and progress
indicators remain native components, not a new custom icon implementation.
`ActionIconThemeData` supplies directional Lucide back and close glyphs while
retaining Flutter's `BackButton`, navigation behavior, semantics and gestures.
There is no standalone profile screen to redesign; existing account/person icons
are covered. Launcher PNG requirements and missing source artwork are documented
in `propertyvisit/assets/launcher_icons/README.md`.

### Navigation
Two labeled destinations per role: buyer catalog/history and manager properties/bookings. Below the rail breakpoint, iOS uses Flutter's `CupertinoTabBar` with Lucide destination icons; other platforms use a Material `NavigationBar` (72dp themed height). Wide layouts use a Material rail on all platforms. Shared fields, chips, menus and manager create dialog remain Material on iOS. Adaptive confirmation dialogs, buyer progress indicators and buyer pull-to-refresh selectively adapt; manager progress/refresh are Material. Do not describe this hybrid as an entirely Cupertino application.

### Photography
Six bundled Unsplash photographs are illustrative, not verified photos of fictional properties. Attribution and source URLs live in `propertyvisit/assets/properties/SOURCES.md`; embedded provenance is recorded for all six assets (6/6). Preserve source records, embedded metadata, visible demo disclosures and semantic labels. No generated imagery or real-owner/address implication is part of this system.

## Do's and Don'ts

### Do:
- **Do** keep photographs and price-first facts as the comparison landmarks.
- **Do** use the active theme's foreground/background pairs and preserve text labels for status.
- **Do** retain bounded content, the implemented rail breakpoint and shared minimum target sizes.
- **Do** preserve Russian copy, illustrative-photo disclosures and photo provenance.
- **Do** distinguish widget-render evidence from native-device verification.

### Don't:
- **Don't** add decorative dashboards or promotional catalog heroes.
- **Don't** claim a custom font, an all-Cupertino interface or native verification from substituted-font widget tests.
- **Don't** treat reference-preview CSS, synthesized color ramps or mock-only lettering as app tokens.
- **Don't** promote hard-coded light-role manager colors or incomplete native verification into design-system invariants.

Not canonized or repaired here: manager empty/contact text and cancellation controls still use some fixed light palette roles, and the add FAB keeps fixed cobalt/white in dark mode. These are implementation drift, not dark-theme guidance. The finish review in `.impeccable/critique/residential-index.md` records the functional fix scope; room normalization is now patched in source, but its latest test result belongs to the implementation pass, not this documentation. Native fonts, insets, gestures, keyboard behavior, accessibility services and performance remain unverified.
