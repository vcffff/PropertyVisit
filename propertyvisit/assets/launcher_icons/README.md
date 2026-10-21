# PropertyVisit launcher artwork

User-supplied source artwork, used as provided (not generated or downloaded).
Do not overwrite these originals with resized native output files.

| Source | Verified properties | Used for |
|---|---|---|
| `app_icon.png` | Square 1024 × 1024 PNG, opaque blue house/location artwork | Android legacy launcher and iOS AppIcon |
| `app_icon_foreground.png` | Square 1024 × 1024 PNG, transparent background, white symbol | Android adaptive foreground |

Android uses the existing deep-blue brand token `#163E71` as the separate solid
adaptive background. The full icon is **not** used as that background: doing so
would draw the house/location symbol twice.

## Safe-area treatment

The supplied foreground already has about 25% transparent padding on either side.
Its visible artwork spans approximately x=273–782, y=306–769 on the 1024px canvas.
The furthest significant visible pixel is about 30.9% of the canvas width from
the center. Android's central 66dp safe circle on a 108dp canvas permits a 30.6%
radius. The configured **4% foreground inset on each side** reduces the artwork's
maximum radius to about 28.4%, leaving additional mask/motion safety margin
without adding another large padding band. Existing square/circle masking is
handled by the OS, not baked into the adaptive foreground.

The full icon source has rounded-square artwork on an opaque square canvas. It
is used unchanged per the supplied design; iOS still applies its own icon mask.
If exact full-bleed corner matching is needed for App Store submission, provide
an unrounded, edge-to-edge square export from the same source design.

## Regenerate

From the Flutter application directory:

```sh
flutter pub get
dart run flutter_launcher_icons
```

`flutter_launcher_icons.yaml` targets Android and iOS only. The generator writes
Android legacy mipmaps, adaptive foreground/background resources, and the iOS
AppIcon set. iOS alpha removal is enabled. No assets are missing for those targets.
Android monochrome/themed icon artwork is optional and is not configured because
no approved monochrome export was supplied. Windows/macOS/web launcher assets are
outside this change's scope.

Reinstall the application to see a native launcher-icon change; hot reload is not
enough. iOS generation works on Windows, but iOS build/device verification still
requires macOS/Xcode. Native mask/launcher verification is left to the user's
emulator/device walkthrough.
