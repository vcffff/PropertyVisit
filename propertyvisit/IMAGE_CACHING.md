# Property photo caching

## Changed files (relative to `propertyvisit/`)

- `pubspec.yaml`, `pubspec.lock`
- `lib/core/widgets/property_image_widget.dart` (new), `property_photo.dart`
- `lib/features/properties/data/property_repository.dart`
- `lib/features/properties/domain/property.dart`
- `lib/features/properties/presentation/properties_cubit.dart`
- `lib/features/properties/presentation/screens/catalog_screen.dart`
- `lib/features/properties/presentation/screens/property_details_screen.dart`
- `lib/features/properties/presentation/screens/admin_properties_screen.dart`
- `test/properties_cache_test.dart`, `test/property_image_test.dart` (new)
- `lib/features/viewings/data/viewing_repository.dart`
- `test/property_images_contract_test.dart` (new)
- `test/api_integration_test.dart`, `test/api_flow_widget_test.dart`
- `IMAGE_CACHING.md` (new)

## Implementation

- `lib/core/widgets/property_image_widget.dart`: reusable `PropertyImageWidget`,
  shared `PropertyImageCache`, loading surface, fade-in (disabled for reduced
  motion), unavailable-photo fallback, clipping, stable aspect ratio and cover fit.
- `property_photo.dart` keeps the existing `PropertyPhoto` name as a compatibility
  alias, so viewing-history thumbnails use the same implementation.
- Catalog and admin cards render only `cover_image_url`. Details use the ordered
  `images` array in a lazy `PageView.builder`, with swipe navigation, previous/next
  buttons for desktop/Chrome and a page counter. Empty galleries use the cover or
  the existing fallback. Lists remain lazy (`SliverList.separated` /
  `ListView.separated`). No eager full-gallery download or prefetch was added.
- One disk manager: 7-day **unused-file cleanup**, 200 objects. Cleanup is periodic,
  not a hard byte quota. HTTP freshness is independent of cleanup: the package
  uses Cache-Control max-age/no-cache and ETag revalidation. No forced seven-day
  freshness overrides the server's positive max-age.
- DPR-aware decode widths are bucketed at 256/512/768/1024/1536 pixels, limiting
  decoded variants and avoiding original-resolution decoding on Android. Only
  width is specified to preserve source proportions. This does not shrink the
  network payload: the server still supplies the original file. No image resizing
  URLs or changing query parameters are generated.
- Cubit `load()` reuses ready state; `refresh()` explicitly requests fresh JSON.
  Concurrent list/detail requests are coalesced; refresh retains visible data and
  scroll position, including when refresh fails. Error feedback uses a snackbar.
  Existing router stacks retain the catalog when opening/popping Details.

## Backend image contract

The updated `API_CONTRACT.md` provides public Supabase Storage URLs.
`Property.fromJson` maps nullable `cover_image_url` to the existing `photoUrl`;
missing/null values retain the fallback for backward compatibility. The detail
`images` array is parsed as immutable `PropertyImage` objects (`id`, `url`,
`position`, `content_type`), preserving the order returned by the server.

Catalog summaries and full details have separate JSON caches: opening Details
requests `/properties/:id` once even when the catalog is already loaded. Reopening
reuses full details; explicit catalog refresh invalidates cached detail JSON so
the next visit discovers additions/deletions, including changes beyond the cover.
Image files are not purged during JSON refresh. Viewing-history cards reuse the
known cover without additional property requests. No Supabase SDK, credentials,
authentication headers for public images, or token caching were added. Backend
code and admin upload/delete workflows were not modified.

## URLs, updates and signed URLs

- Prefer a stable public URL returned by the backend. Use a new object path or
  explicit content version only when the actual image changes. Never append a
  timestamp on rebuild, catalog refresh, or navigation.
- A changed URL naturally loads a new cache entry. For a confirmed same-URL
  replacement, call `await PropertyImageCache.invalidate(oldUrl)` and remount
  the affected widget with a new key. This evicts its disk file and all width
  variants from Flutter memory, without purging other photos. No image-edit
  workflow currently exists to wire this into.
- Signed URLs remain intact, including signatures and expiration parameters.
  They are not canonicalized by stripping tokens (which could share private
  data or hide replacements). Different signatures therefore have different
  cache keys. Once a cached image becomes stale, an expired signature cannot
  fetch it again. The backend must return a renewed URL via an explicit data
  refresh; there is no invented client-side signing or automatic retry loop.
- This is a public-photo cache, **not** an authorization boundary. Cached bytes
  may remain available beyond a signed URL's expiration. Do not use it for
  sensitive private media requiring immediate revocation. The dependency is not
  a full RFC HTTP cache (notably `no-store`/`max-age=0` semantics); private media
  would require a separate nonpersistent policy.

## Platform limitations

- Android/iOS: files live in the app's temporary cache directory; the OS or user
  can purge them. Metadata uses SQLite. Offline reuse is best-effort, not durable
  storage. The 200-object limit does not cap total bytes or Flutter's separate
  global decoded-image cache.
- Windows/Linux/macOS: supported file-cache behavior follows package/platform
  implementations; desktop decode/scroll behavior is not Android performance
  evidence.
- Web: `cached_network_image` does not supply the native persistent disk cache;
  browser/CDN HTTP caching and CORS apply. Decode-size hints may be ignored by
  the browser renderer.

## Verification

- `flutter pub get`: passed. Added direct dependencies `cached_network_image`
  ^3.4.1 (resolved 3.4.1) and `flutter_cache_manager` ^3.4.1 (resolved 3.4.5).
  The latter is direct because the bounded seven-day policy needs custom config.
- `dart format .`: completed.
- `flutter analyze`: no issues found.
- Final `flutter test --concurrency=1`: **53 passed, 1 skipped**. The skipped live
  backend test requires opt-in `LIVE_API_URL`. The original disk-space blocker
  did not prevent this final serial run.
- Coverage includes first/concurrent loads, disk reuse, decoded-memory eviction,
  changed/same-URL replacements, missing/broken URLs, stable geometry, request
  coalescing, refresh recovery, return/reopen Details, 80-card lazy scrolling,
  backend cover/gallery parsing and lazy gallery button/swipe navigation.
- No live Supabase, Android frame-time/network profiling, native screenshot, or
  actual Chrome browser verification is claimed. Repeat verification with:

  ```text
  flutter pub get
  dart format .
  flutter analyze
  flutter test --concurrency=1
  ```

For device acceptance, test a confirmed public backend photo on a throttled
Android connection: cold load, reopen, back to catalog, long scroll, offline
reopen, missing/broken URLs, then a versioned replacement. Verify GET counts in
network tooling separately from API JSON calls; do not log signed URLs or tokens.
