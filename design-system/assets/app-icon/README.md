# App icon

Chosen direction: 2a Bottle in the 3d Lavender colourway. A bottle with measure marks: violet on pale lavender, with the marks in honey.

## Use in Xcode

Drag `assets/AppIcon.appiconset` into `Assets.xcassets`, replacing the existing AppIcon set. It holds one 1024 × 1024 image per appearance and a `Contents.json` that maps them:

- `AppIcon-Light.png` — default. Violet bottle, honey marks, lavender ground.
- `AppIcon-Dark.png` — dark appearance. Light violet bottle on black.
- `AppIcon-Tinted.png` — tinted appearance. Greyscale on black; iOS applies the user's tint.

All three are square, full-bleed, sRGB, 8-bit RGB with no alpha channel. iOS applies the corner mask; do not round them.

## Layer for Icon Composer

`AppIcon-Foreground.png` is the bottle alone on a transparent background, 1024 × 1024. Use it as the foreground layer over a solid lavender fill (`--sleep-100`) if you build a layered icon.

## Regenerating

Open `brand/App Icon Export.html`. It draws each variant to a 1024 px canvas from the geometry of option 2a in `brand/App Icon Options.html`.
