# PropertyVisit mobile MVP

Existing Flutter application integrated with the Go API; the original repository →
Cubit → screen structure, BLoC, Dio, go_router, secure storage and Russian UI remain.
`lib/main.dart` uses only API repositories. Mock repositories are retained solely
for isolated regression tests and are not selectable in the running application.

## API source of truth

Read from `C:\Users\Magzhan\Downloads\go-demo\API_CONTRACT.md` (the backend
repository). The local `API_CONTRACT.md` is an identical reference copy.
API_URL must include `/api/v1`; trailing slashes are normalized.

The contract provides only property ID/title/address/integer price. No photos,
city, rooms, area, descriptions, buyer name or phone are returned. The live UI
does not fabricate these details. Viewing lists use cached property titles when
available, otherwise explicit property IDs; admin cards identify owners by user ID.
Buyer cancellation is intentionally unavailable: status updates are admin-only.

## Start the local Go backend (PowerShell)

The backend is not modified by this app. It requires its existing `.env` and an
accessible SSL-enabled PostgreSQL database; PostgreSQL is not in its Compose file.
See the backend README for host/container database configuration. Never commit `.env`.

```powershell
Set-Location C:\Users\Magzhan\Downloads\go-demo
docker compose up -d redis kafka
docker compose exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:29092 --create --if-not-exists --topic property.events --partitions 1 --replication-factor 1
docker compose up -d --build api
```

Use real user/admin credentials. On the login screen, choose **Создать аккаунт**
to register with email, password (minimum 6 characters) and password confirmation.
After successful registration, choose **Войти**; registration itself returns no tokens.
There are no bundled working demo accounts. Have an admin create a property if the
catalog is empty. The mobile app never calls the development role-switch endpoint.

## Run Flutter

```powershell
Set-Location C:\Users\Magzhan\Downloads\PropertyVisit\propertyvisit
flutter pub get
flutter emulators --launch Medium_Phone
flutter run -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8080/api/v1
```

Android emulator `10.0.2.2` reaches the Windows host. Android debug builds allow
local HTTP; release builds require HTTPS. For a physical Android device on USB:

```powershell
adb reverse tcp:8080 tcp:8080
flutter run -d DEVICE_ID --dart-define=API_URL=http://127.0.0.1:8080/api/v1
```

Alternatively use the computer's LAN address with port 8080 allowed through the
firewall. Do not use `localhost` on a phone to refer to the computer.
On a Mac with the backend running locally, an iOS simulator can use:

```sh
flutter run -d IOS_SIMULATOR_ID --dart-define=API_URL=http://localhost:8080/api/v1
```

iOS permits local-network access; HTTPS is required for remote deployment.
Windows builds need Visual Studio's Desktop development with C++ workload.
Browser builds are not a substitute for mobile verification and also require
backend CORS support (not changed here).

## Walkthrough

1. Log in as a real buyer → catalog → property → choose viewing time.
2. Date tabs represent **Astana UTC+05:00 calendar dates**. Slot labels and history
   timestamps are converted from server UTC to the device's local timezone.
3. Select an available server-provided slot and book. HTTP 409 explains that it
   was taken and reloads availability; no local slot generation is used.
4. Open My Viewings to see pending/confirmed/cancelled/completed. Pull to refresh.
5. Log out, log in as admin, open Bookings and confirm. Admins may also cancel or
   complete according to the documented state transitions. Terminal rows have no
   mutation actions. Repeated taps on an updating row are disabled.
6. Log back in as the buyer and refresh history to see the updated status.

**Important backend constraint:** the existing limiter permits **5 requests per
IP per minute across all routes**, including login/refresh. A rapid walkthrough
will hit 429. Wait a minute and use Retry/Refresh. The app does not automatically
repeat bookings or status writes. It reuses catalog data for details to avoid
unnecessary requests. Other clients on the same IP share the limit.

## Session behavior

- One secure-storage JSON value holds access and refresh tokens together.
- `/users/me` restores the identity/role; admin routes remain server-authorized.
- On protected 401, a single shared refresh future rotates both tokens. Delayed
  old-token 401s reuse the rotated access token; each request retries at most once.
- Auth endpoints use a separate Dio without the refresh interceptor.
- Rejected refresh or a retried 401 clears the session and routes to login.
- Offline/429/5xx refresh failure preserves the session for a later manual retry.
- Logout clears local credentials even if server revocation fails, with a warning.
- No token, password, raw Dio exception, or authentication body is logged.

## Checks

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_URL=http://10.0.2.2:8080/api/v1
```

`test/api_integration_test.dart` tests the API repositories and interceptors through
a deterministic Dio adapter, including refresh concurrency, delayed 401s, retry
limits, secure persistence, session invalidation, 403, 409, ownership-safe request
bodies and admin confirmation. `test/api_flow_widget_test.dart` exercises the real
API-wired login/catalog/details/booking/history UI with that adapter. Original
mock-backed design and state regressions remain in place.

### Opt-in live Go verification

```powershell
flutter test test/live_backend_test.dart --dart-define=LIVE_API_URL=http://localhost:8080/api/v1
```

This creates one real test user and a real pending booking on the first available
property tomorrow. It paces requests 13 seconds apart to respect the limiter;
avoid other API traffic during the run. Credentials/tokens are never printed.
Without an existing admin's credentials, live admin confirmation is explicitly
reported blocked and the pending viewing's non-secret ID is printed for cleanup.
With `PV_ADMIN_EMAIL` and `PV_ADMIN_PASSWORD` supplied securely in the environment,
it additionally confirms then cancels that booking via the actual admin endpoints.
Do not paste credentials into source files or shell command arguments.
The live test is intentionally skipped in the default offline test suite.

Verification results and remaining device/backend limitations are recorded in
`VERIFICATION.md`. A passing adapter test is not proof of a deployed backend or
native secure-storage behavior.

## Iconography and launcher branding

UI text uses **Manrope** through `google_fonts` 8.2.1 in both themes. There are no
manually downloaded font files or local font registrations. The package fetches
and caches the fonts; the first uncached load needs internet access. Existing
type sizes, role weights and text scaling remain unchanged.

App-owned icons use the regular Lucide family from `lucide_icons_flutter` 4.0.1.
Navigation, account/password visibility, search/sort, property-photo fallbacks,
booking success and admin controls share the same outline style. The theme swaps
the back/close glyphs while preserving Flutter's native navigation controls.
There is no separate profile screen; existing person/contact controls are covered.
Layouts, Cubits, repositories and API calls are unchanged by this polish pass.

User-supplied square 1024px PNGs live in `assets/launcher_icons/`. Android legacy
and adaptive icons and the iOS AppIcon set are generated using:

```sh
dart run flutter_launcher_icons
```

Configuration: `flutter_launcher_icons.yaml`. The transparent foreground already
has substantial padding, so Android adds only a 4% inset. See
`assets/launcher_icons/README.md` for provenance, safe-area measurements and the
optional unrounded/monochrome exports. No required launcher source assets are
missing. Reinstall the application to update its native launcher icon.
