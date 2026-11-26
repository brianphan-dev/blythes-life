# App icon

Chosen direction: 1a Monogram (the wordmark's B on a ruled line).

## Use in Xcode

Drag `assets/AppIcon.appiconset` into `Assets.xcassets`, replacing the empty AppIcon set. It holds one 1024 × 1024 image per appearance and a `Contents.json` that maps them:

- `AppIcon-Light.png` — default. Ink on honey.
- `AppIcon-Dark.png` — dark appearance. Honey on black.
- `AppIcon-Tinted.png` — tinted appearance. Greyscale on black; iOS applies the user's tint.

All three are square, full-bleed, sRGB, 8-bit RGB with no alpha channel. iOS applies the corner mask; do not round them.

## Layer for Icon Composer

`AppIcon-Foreground.png` is the B and rule alone on a transparent background, 1024 × 1024. Use it as the foreground layer over a solid honey fill if you build a layered icon.

## Regenerating

Open `brand/App Icon Export.html`. It draws each variant to a 1024 px canvas from the same CSS as the chosen option.
