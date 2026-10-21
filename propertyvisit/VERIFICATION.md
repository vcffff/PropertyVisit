# Verification and iconography change report

## Google Fonts follow-up

Manrope is now applied through `google_fonts` 8.2.1 using
`GoogleFonts.manropeTextTheme` for regular and primary text themes. The temporary
local TTF implementation and its pubspec font/asset declarations were removed at
the user's request. No manual font assets remain. The first uncached load needs
network access; subsequent use relies on the package's caching.

Dependency resolution, `dart format .` and `flutter analyze` passed (no analyzer
issues). A targeted widget-test rerun was blocked before
tests loaded by the host Dart compiler's **out-of-memory** failure. The 40 passing
tests below describe the earlier iconography version, not this font follow-up.

## Latest iconography / launcher pass

- `flutter pub get`: passed.
- `dart run flutter_launcher_icons`: passed; Android legacy/adaptive and iOS
  launcher resources generated from the two user-supplied PNGs.
- `dart format .`: passed.
- `flutter analyze`: passed, no issues.
- `flutter test --concurrency=1`: **40 passed, 1 intentionally skipped**.
  The opt-in live backend test is skipped to avoid creating real records during
  ordinary UI checks. Serial execution avoids the memory exhaustion encountered
  when compiling multiple test suites alongside the Android emulator.
- Additional API-wired UI capture run: both widget tests passed. Reviewed catalog,
  details, booking and registration captures under `../.impeccable/review/`.
  These are adapter-backed widget renders using locally substituted Segoe text
  fonts and the actual Lucide icon font, not native device screenshots.

Icon changes retain existing layouts, labels, controls, Cubits, repositories,
routes and API integration. All app-authored Material icon constants were replaced
with the regular Lucide family; Flutter-owned chip/menu checkmarks and progress
indicators remain framework controls. BackButton behavior, accessibility tooltip
and minimum touch target are tested in both themes. Independent password
visibility controls and the registration/booking flows remain covered.

There is no standalone profile screen in the current application. Existing
account/person/contact icons were updated rather than adding an unrelated page.

## Launcher assets

- `assets/launcher_icons/app_icon.png`: square 1024px source for Android legacy
  and iOS icons, used unchanged.
- `assets/launcher_icons/app_icon_foreground.png`: square 1024px transparent
  source for adaptive icons, used unchanged.
- Android adaptive foreground has a **4% inset** in generated XML, in addition to
  the source's existing transparent padding. The separate background uses the
  existing brand color `#163E71`.
- Automated tests check PNG signatures, source dimensions, alpha-capable Android
  foregrounds, all five Android legacy sizes, adaptive resource references/inset,
  and every iOS catalog image's size and absence of an alpha channel.
- **No required Android/iOS launcher assets are missing.** Optional monochrome
  Android artwork is not configured. An unrounded full-bleed export would improve
  exact iOS corner matching if desired; the supplied full icon has baked-in
  rounded-square artwork and is intentionally preserved.

The latest iconography version has not been installed or walked through on a
device; emulator/device testing is left to the user as requested. Reinstall or
run the app again to update native launcher resources; hot reload is insufficient.
iOS native build/verification requires macOS/Xcode, unavailable on this Windows
host. Windows native builds require Visual Studio's C++ workload, also unavailable.
The Android debug APK built and launched earlier in the session, before this
latest iconography change; that is not claimed as a build of the current artwork.

## Files modified or added in the iconography / branding pass

Paths below are relative to this Flutter application unless explicitly noted.

### Dependencies and configuration
- `pubspec.yaml`
- `pubspec.lock`
- `flutter_launcher_icons.yaml` (new)

### Flutter icon replacements (no layout or integration changes)
- `lib/core/theme/app_theme.dart`
- `lib/core/router/home_shell.dart`
- `lib/core/widgets/logout_button.dart`
- `lib/core/widgets/property_photo.dart`
- `lib/features/auth/presentation/screens/login_screen.dart`
- `lib/features/properties/presentation/screens/catalog_screen.dart`
- `lib/features/properties/presentation/screens/admin_properties_screen.dart`
- `lib/features/viewings/presentation/screens/booking_screen.dart`
- `lib/features/viewings/presentation/screens/admin_bookings_screen.dart`

Property-detail back icons are updated through the shared action-icon theme,
without replacing the native BackButton or editing the details layout.

### Native labels and generated resources
- `android/app/src/main/AndroidManifest.xml` (PropertyVisit display-name casing)
- `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`
- `android/app/src/main/res/drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher_foreground.png` (new)
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` (new)
- `android/app/src/main/res/values/colors.xml` (new)
- `ios/Runner/Info.plist` (PropertyVisit display-name casing)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png` (all declared launcher sizes)

### Tests, documentation and review artifacts
- `test/iconography_test.dart` (new)
- `test/launcher_icons_test.dart` (new)
- `test/api_flow_widget_test.dart` (Lucide assertions and capture font)
- `test/redesign_test.dart` (capture font)
- `assets/launcher_icons/README.md` (new; supplied artwork and safe-area notes)
- `README.md`
- `VERIFICATION.md` (this report)
- `../DESIGN.md` (narrow iconography/navigation documentation)
- `../.impeccable/review/api-mvp-*-widget.png` (updated review captures)

The two source PNGs were supplied by the user and were not edited. A temporary
missing-artwork README under `assets/branding/` was removed after the supplied
assets became available; no existing user artwork was removed.

## Earlier API integration verification (separate from this polish pass)

The existing architecture was retained and startup switched to real API
repositories using the backend's actual `API_CONTRACT.md`. Before the user asked
to leave emulator testing to them, a paced live Go test passed registration,
login, properties, slots, booking, ownership list, duplicate-slot 409,
availability refresh, token rotation, identity restoration and logout.

Live admin confirmation remains **unverified: no existing admin credentials were
supplied**. Its documented request and response behavior is covered through the
Dio contract adapter, not falsely described as a successful live admin test.
No backend source or role-switch configuration was modified.

The successful live test left pending viewing **5** on property **2**, created
under a dedicated test user. An admin can cancel it. An earlier timed-out live
run may also have left test records; no backend records were deleted to hide
test side effects. No additional live backend tests were run after the user
requested UI-only verification.

The backend's shared **5 requests/IP/minute** limit still applies. Retry/refresh
after waiting a minute when the app displays 429. Exact local backend and Flutter
run commands are in `README.md`.
