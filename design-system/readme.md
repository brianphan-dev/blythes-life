# Blythe's Life Design System

Blythe's Life is a private, offline-first baby-tracking app for one family. It has two jobs:

1. **Log daily care in under three seconds, one-handed.** Sleep, bottles, diapers, meals, baths, meds and notes, synced across the parents' iPhones and a nursery iPad.
2. **Turn Grandma's paper log into entries.** Blythe's weekday caregiver writes on paper sheets whose layout changes as Blythe grows. A parent photographs the sheet, a vision model extracts events, and the parent reviews and confirms every entry before anything is saved.

There is one product surface: a universal Apple app (iPhone, iPhone Duo, and iPad) focused entirely on family baby-care tracking.

## Sources

- GitHub: [brianphan-dev/blythes-life](https://github.com/brianphan-dev/blythes-life) (branch `main`). At the time of writing the repo holds only `README.md`, a PRD and technical architecture. There is no app code, no design file, no logo and no fonts. If you have access, read that PRD in full before designing; it carries the feature rules (wake windows, scan deduplication, data model) this system is built around.
- Everything visual here was authored from that PRD. Nothing was copied from an existing UI, because none exists yet.

## Product decisions made here (and where they depart from the PRD)

The PRD prescribes some UI. These are the places this system took a different route, and why.

- **Sleep left the quick grid.** The PRD lists a "6-action grid" but names seven actions. Sleep is a running timer with shared state, not a one-shot log, so it became the hero `NapCard` at the top of Today. The grid holds the one-shot events: Bottle, Nursing, Pump, Diaper, Meal, Bath, Meds, Note. Past sleep is entered from the card's "Add a past sleep" button with start and end times; while a nap runs, the same button changes its start time.
- **Glance strip and nap predictor merged.** "Awake" from the glance strip and the Mini SweetSpot countdown describe the same thing, so they share one card: elapsed awake time, a rail toward the sweet spot, and the nap button. Last feed and Last diaper remain as two `GlanceStat`s, and tapping one opens that log sheet.
- **Quick grid docks at the bottom.** The tiles sit directly above the tab bar, in thumb reach, rather than under the summary.
- **Every entry is editable.** Tapping a row in Today's timeline reopens its log sheet with the saved values, a time field and a delete button. Edits and deletes show the same Undo toast.
- **Undo instead of confirm.** Logging closes the sheet and shows a toast with Undo. Sheets open prefilled, so a repeat entry is two taps.
- **Relative time first, exact time beside it.** Every log sheet shows the entry's clock time in a `TimeField` next to Now / 5m ago / 15m ago chips. Tap the time to set it exactly.
- **Nursing and pumping were added.** The PRD covers bottles only. Nursing is a feeding with `method: "breast"` plus minutes and side, which the data model already allows. It is logged with a live `NursingTimer` (tap a side to start, the other side to switch, the same side to pause) or by entering minutes afterwards. A running session shows as a banner on Today. Pumping is not in the data model; it needs a new `pump` event type (amount, side).
- **Scan has a home.** A `Sheets` tab lists every scanned sheet with its review status. A sheet waiting for review also shows as a banner on Today.
- **Review cannot save past an open question.** The save button is disabled until each amber ambiguity is resolved or its entry is unchecked. Duplicates arrive unchecked. A "+ VIT D" label becomes an unchecked suggestion.
- **Night mode is a first-class theme**, not a dimmed day theme: true black, warm low-blue text, dimmed honey.

## Content fundamentals

- **Voice:** plain, specific, calm. Written for a tired parent at 3 AM. No exclamation marks, no cheerleading, no emoji.
- **Person:** the app does not say "I" or "we". It addresses the parent as "you" only when needed ("Nothing is saved until you confirm each entry."). Blythe is "Blythe" or "she". The caregiver is "Grandma".
- **Casing:** sentence case for everything. The one exception is the small form label (`.bl-label`): uppercase, tracked, like the printed headings on the paper log ("AWAKE · SINCE 10:32 AM", "PEE", "POOP").
- **Buttons say what will be logged:** "Log 3.25 oz", "Log diaper", "Start nap", "Wake up", "Save 4 entries". Never a bare "Save" or "OK".
- **Durations:** `2h 22m`, `34m`. Schedule settings use the fractions written on the paper sheets: `2½h`, `3¼h`.
- **Clock times:** `10:45 AM`. Ranges use an en dash: `9:15 – 10:32 AM`.
- **Amounts:** number, space, lowercase unit: `3.25 oz`, `95 mL`, `1 drop`.
- **Separators:** a middle dot joins facts on one line: `Pee L · Poop S`, `Nap 2 sweet spot 1:47 PM · in 53m`.
- **Uncertainty is stated as a question with choices,** not a warning: "The time was written over. Which is it?" followed by `11:20 AM` and `11:30 AM`.
- **Confirmation is short and reversible:** "Bottle logged · 3.25 oz" with Undo.
- **Avoid:** technical vocabulary from the PRD in UI copy (extraction, confidence, deduplication, sync, VLM). Say "already logged", "needs a look", "on every device".

## Visual foundations

**Idea.** The app is the digital twin of a paper daily log: warm paper surfaces, hairline rules, uppercase form labels, big handwritten-size numerals. Honey is the single accent.

- **Colour.** Paper neutrals (`--paper-*`, warm greys around hue 85) for surfaces, lines and ink. Honey (`--honey-*`) for the primary action, selection and focus. Each event type owns one hue at fixed lightness steps: sleep violet, feeding apricot, diaper teal, meal green, bath blue, medicine pink, pump orchid, note neutral. Nursing shares the feeding hue. Amber is reserved for scan ambiguity; green for confirmed; red for destructive.
- **Themes.** Day is the default (`:root`). `data-theme="night"` on any container switches to OLED black with warm, dim text and a dimmed honey. Always style through the semantic tokens (`--bg-*`, `--text-*`, `--accent*`, `--ev-*`) so both themes work.
- **Type.** Newsreader (serif) for screen titles and every large numeral: timers, amounts, totals. Figtree (sans) for all UI text. Numerals use lining, tabular figures. Units after a big number step down to small Figtree.
- **Spacing.** 4pt scale. 16px screen gutter, 8px between sibling cards and tiles, 20px between fields in a sheet.
- **Corner radii.** Crisp. 6 badges, 8 chips, 12 cards / tiles / buttons, 16 hero card, 24 only on sheet tops. No pills; even the switch is squared.
- **Borders.** 1px hairlines do the structural work. Cards, tiles and rows are outlined, not shadowed. Inputs and chips use the stronger line.
- **Shadows.** Only things that float: sheets (`--shadow-sheet`) and toasts (`--shadow-float`). In night mode shadows become a 1px outline. No inner shadows.
- **Cards.** Paper surface, hairline border, 12px radius, 16px padding, no shadow. An accent-tinted card means "needs your attention". Never a coloured left border.
- **Backgrounds.** Flat colour. No gradients, textures, patterns, illustrations or photography. The only image in the product is the user's own scan photo.
- **Transparency and blur.** Not used, except the scrim behind a sheet. The tab bar and dock are opaque.
- **Motion.** Short and quiet: 120ms for presses, 200ms for switches and toasts, 360ms for a sheet sliding up on an ease-out curve. No bounce, no looping animation, no decorative motion. Honours reduced motion.
- **Press states.** Scale to .97 (.96 on tiles and chips) plus a darker or tinted fill. Quick tiles flood with their event tint. There are no hover states; this is a touch product.
- **Selection.** Honey tint fill with a honey border (chips, selected draft card, selected day). Segmented controls raise the selected segment on a paper thumb.
- **Layout.** Fixed: status bar, tab bar, the quick-log dock on Today, the save bar in review. Everything between scrolls. Primary actions sit in the bottom third of the screen.
- **Hit targets.** 44px minimum, 56px quick tiles, 60px for the commit button in a sheet and the nap button.
- **Imagery.** None shipped. The scan photo in the UI kit is an HTML stand-in.

## Iconography

- **Set:** [Lucide](https://lucide.dev), loaded as an icon font from CDN (`lucide-static@0.460.0`) via `tokens/fonts.css`. 2px stroke, round caps. Use the `Icon` component, or `<i class="icon-moon"></i>` in plain HTML.
- **This is a substitution.** The native app would normally use SF Symbols, which cannot be redistributed here. Lucide is the closest open match in weight and style.
- **Event glyphs** always sit in a tinted rounded square (`EventIcon`): moon (sleep), milk (bottle), baby (nursing), beaker (pump), droplets (diaper), utensils (meal), bath (bath), pill (meds and care), notebook-pen (note).
- **UI glyphs** are bare, in the current text colour: sun, calendar-range, scan-text, settings, check, x, chevron-right, triangle-alert, clock, image.
- **No emoji. No unicode characters as icons.** No custom SVG or PNG icons exist.
- **App icon:** a bottle with measure marks, violet on pale lavender with the marks in honey. The icon uses the sleep violet family; the in-app accent stays honey. Xcode-ready files are in `assets/AppIcon.appiconset/` (light, dark, tinted; 1024 × 1024). See `assets/app-icon/README.md`.
- **No separate logo lockup exists.** In running text and headers the name "Blythe's Life" is set in Newsreader (see the Wordmark card). Do not draw a different mark.

## Components

Core: `Icon`, `Button`, `IconButton`, `Chip`, `Badge`, `Card`, `ListRow`
Forms: `SegmentedControl`, `Switch`, `Checkbox`, `TextField`, `AmountField`, `TimeField`
Navigation and overlays: `TabBar`, `Sheet`, `Toast`
Tracking: `EventIcon`, `QuickTile`, `GlanceStat`, `EventRow`, `NapCard`, `NursingTimer`, `DraftCard`

Each has a `.jsx`, a `.d.ts` props contract and a `.prompt.md` usage note. All styling lives in `components/components.css` (class prefix `bl-`) and reads tokens only.

No source defined a component inventory, so this set was authored from the PRD's feature list. The tracking group is specific to this product; the rest is a standard set trimmed to what an iOS app needs (no Tooltip, no Select, no Tabs; `SegmentedControl` and `Sheet` cover those roles).

## Index

- `styles.css` — the one file consumers link. Imports everything below.
- `tokens/` — `fonts.css`, `colors.css` (base + semantic + night), `typography.css`, `spacing.css` (space, radius, hit targets, shadows), `motion.css`.
- `components/` — `components.css` plus `core/`, `forms/`, `navigation/`, `tracking/`. Each folder has a `*.card.html` preview.
- `ui_kits/ios/` — interactive iPhone click-through: Today, nine log sheets, Rhythm, Sheets, scan review, Settings, day and night. See its `README.md`.
- `guidelines/` — foundation specimen cards (colours, type, spacing, brand).
- `assets/AppIcon.appiconset/` — the app icon for Xcode: light, dark and tinted PNGs plus `Contents.json`. `assets/app-icon/` holds the transparent foreground layer and usage notes.
- `brand/` — `App Icon Options.html` (three rounds explored; 2a Bottle in 3d Lavender was chosen) and `App Icon Export.html` (regenerates the PNGs).
- `thumbnail.html` — project tile.
- `SKILL.md` — agent skill entry point.
- `github.md` — source repo association and sync record.

## Caveats

- Fonts load from Google Fonts. No font binaries are bundled, and both families are this system's choice, not an existing brand decision.
- Icons are a Lucide substitution for SF Symbols.
- iPad split view and the foldable's unfolded and tabletop layouts from the PRD are not built yet. `QuickTile size="lg"` exists for them.
- Lock Screen Live Activity and Control Center tiles are not designed.
