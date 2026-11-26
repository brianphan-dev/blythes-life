# iOS app UI kit

Interactive iPhone click-through of Blythe's Life. Open `index.html`.

There is no production UI to copy yet; these screens are this design system's proposal, built from the PRD in the source repo.

## Screens

- **Today** (`TodayScreen.jsx`) — NapCard with live timer, Last feed / Last diaper, pending-sheet banner, today's timeline, docked quick grid.
- **Log sheets** (`LogSheet.jsx`) — Sleep, Bottle, Nursing, Pump, Diaper, Meal, Bath, Meds & care, Note. Each takes an exact time; Sleep takes start and end. Open from the quick grid, a glance stat, or the nap card.
- **Rhythm** (`RhythmScreen.jsx`) — seven days by 24 hours; tap a day for totals. Today's column draws from the live timeline.
- **Sheets** and **scan review** (`ScanScreens.jsx`) — scan list, then photo over draft cards. Resolve the amber question to enable saving.
- **Settings** (`SettingsScreen.jsx`) — nap schedule, units, night mode, household, data.

## Try

1. Tap **Start nap**, then **Wake up**. The nap lands in the timeline and in Rhythm.
2. Tap **Bottle**, change the amount, **Log**. Then **Undo** in the toast.
3. Tap the **Grandma's sheet** banner, pick `11:30 AM`, save.
4. Tap **Add a past sleep** on the nap card and set start and end. While a nap runs, the same button changes its start time.
5. Tap **Nursing**, tap **Left** to start the timer, **Right** to switch, then log it. Close the sheet mid-session and reopen it from the banner on Today.
6. Tap any row in the timeline to edit or delete it.
7. Tap **Pump** in the quick grid.
8. Tap the moon button for night mode.

## Notes

- `BlythesLifeApp.jsx` holds all state. `KitData.jsx` holds sample events and the sample extraction.
- `kit.css` is layout for this demo only. Component styles come from `styles.css`.
- The scanned sheet is an HTML stand-in, not a photo.
- The clock starts at 12:54 PM on Wed, Nov 25 and runs in real time.
- Not built: iPad split view, foldable layouts, Live Activity, Control Center.
