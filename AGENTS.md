# AGENTS.md

This file is for AI agents working on this project. Read it end to end before writing any code.

**`CONTRIBUTING.md` is the companion to this file and is binding for coding rules.** This file explains what the project is, how it is set up and which pitfalls exist; the folder structure, the Page/PageModel split, widget extraction and constant usage rules described there apply as written.

---

## Project

**Koala** — a mobile app for finding **daily / short-term work**. Written in Flutter; targets iOS and Android (there is no `web/` folder, the project is not built for web).

The app serves **two audiences from a single codebase**:

- **Employee** (`lib/employee/`) — the job seeker. Discovers nearby jobs on a map or a list, applies, tracks their applications, chats with the employer, reviews the job afterwards.
- **Business** (`lib/business/`) — the employer. Posts jobs, reviews applicants, chats with them.

Which side a user sees is decided by the `user_type` value in `SharedPreferences` and enforced by the `redirect` guard in the router. Files on the business side are prefixed `b_` (`b_home_page.dart`, `BJobsProvider`, `BNavItem` ...) — keep that prefix.

Flutter 3.47.1 (stable), Dart SDK `^3.8.1`. The font is Poppins.

---

## Communication and ways of working

**Write in Turkish.** The user writes in Turkish and expects Turkish answers. In-code comments, `///` doc comments and all user-facing strings are Turkish. Variable and class names stay English — that is the pattern of the existing codebase.

**Work through feature branches and pull requests.** Create focused commits, push the feature branch and open a pull request. Never push directly to `main`; keep unrelated changes out of each commit and report every commit hash. Merging remains a separate release decision.

**Verify on this Mac; do not wait for the GitHub queue.** After a change, run `flutter analyze --no-pub` and the flavored `flutter test` here. The Mac is not an org GitHub Actions runner. GitHub does not run quality or iOS jobs on PRs or `main` pushes. Hetzner `self-hosted` and hosted `macos-latest` stay for explicit `workflow_dispatch`; store builds stay on `mobile-v*` via `mobile-release.yml`.

**Visual verification is done by the user.** They are the one who runs the app, sends screenshots and asks for fixes. A green `flutter analyze` plus a green `flutter build` mean "it compiles", never "it looks right" — do not conflate the two. If you made a visual change, say explicitly that you did not verify it on screen and point out what to look at.

**Do not add dependencies or invent new patterns.** Reuse what is already in `lib/product/constants` and `lib/product/widgets` first. If a value is missing from a constant file, add it there with a meaningful name instead of hard-coding it. The one kind of addition that does not need asking is a package an existing dependency already requires — `cupertino_icons` is in `pubspec.yaml` for exactly that reason; say so when you add one.

> `image_picker` and `url_launcher` were added on the user's explicit approval, both from `flutter/packages`. The first picks a company logo from the gallery, the second opens an applicant's CV. `image_picker` brought one native change with it: `NSPhotoLibraryUsageDescription` in `ios/Runner/Info.plist` (Android needs nothing — the gallery goes through the system photo picker). `camera` was added for live TCKK MRZ preview. `firebase_core` and `firebase_messaging` were added for Android push (#141, Yusuf 2026-09-12): they are not `flutter/packages`. Native companions are `POST_NOTIFICATIONS` in the main manifest and `com.google.gms.google-services` in Gradle. `flutter_local_notifications` is not used. iOS APNs/plist/entitlements stay on the separate push issue. The installed application id is `com.iskoala.koala` (dev/staging suffixes); the Gradle **namespace** remains Flutter's default `com.example.koala` and is not the installed identity.

> `camera` was added on the user's explicit approval for the TCKK MRZ flow. The official `flutter/packages` plugin supplies a live rear-camera preview; MRZ frames stay in memory, one frame is analysed at a time, and the flow creates neither image files nor frame logs.

---

## Commands

```bash
flutter analyze --no-pub     # after every change; must stay clean
flutter test --flavor staging --dart-define-from-file=config/staging.json   # after every change to logic
dart format lib test         # before handing the work over
flutter pub get
```

### Tests

`test/` mirrors `lib/`: a test for `lib/product/router/router_manager.dart` lives at `test/product/router/router_manager_test.dart`. Test names and `group` labels are Turkish like everything else.

Coverage follows the same tree: models, services, providers, pages, widgets and the shared network/router layers all have focused tests beside their corresponding path. Inspect the matching `test/` subtree instead of relying on a feature count here; the suite grows with the product. Most tests run headless. `integration_test/live_qa_login_test.dart` is the deliberate exception: it runs on a device or simulator against the configured real API and needs `QA_WORKER_EMAIL`, `QA_WORKER_PASSWORD`, `QA_EMPLOYER_EMAIL` and `QA_EMPLOYER_PASSWORD` as compile-time defines. Supply those credentials only at invocation time; keep the live check connected to real data.

Shared helpers under `test/support/`, use them instead of rolling your own:

- **`fixtures.dart`** → `buildJob(...)`. `Job` has eight required fields; passing only the one the test cares about keeps the test readable.
- **`pump.dart`** → `pumpInApp(tester, widget, brightness: ...)`. Product widgets read their colors from `context`, so they cannot be pumped bare — they need a `MaterialApp` with the real theme. The `brightness` parameter is there so a widget can be asserted in **both** themes, which is the project's core rule.
- **`fake_api.dart`** → `FakeApi(handler: ...).client`. A fake HTTP layer plus an `ApiClient` that carries **the production interceptor chain** — `Authorization`, `X-Device-Id`, the session refresh and the retry all run in tests. That is what lets a test drive the refresh decision by handing back an envelope: `errorCategory` in the body reaches `AuthInterceptor` exactly as it would in production. Keychain and `SharedPreferences` do not exist there, so the client is fed `FakeTokenStorage` and `FakeDeviceIdentity` from the same file; pass your own `tokenStorage:` when a test needs to start with a token or read back the refreshed one, and check `sessionExpired` when it should end the session. `requests` holds the `RequestOptions` that reached the fake server — but note a retried request **mutates the options it already sent**, so capture headers inside the handler rather than reading them afterwards.
- **`finders.dart`** → semantic finders for product widgets, including `findAppIcon`. Prefer these over reaching into a package widget's private rendering shape.
- **`identity_gate_test_support.dart`** → `employerMeResponse(...)` and `stubIdentityVerificationRoute()`. The real `IdentityVerificationPage` builds its own `UserService` and goes to the network, so tests that drive an identity gate get a stand-in route with the same contract (`CurrentUser` in `extra`, pops `true` on success). **`reference_location_fixtures.dart`** → `istanbulReferenceResponse(path)`; the company form will not submit until the country/city/district lists have arrived, so any test that saves it must answer those three endpoints.

The Mac quality gate is `flutter test --flavor staging --dart-define-from-file=config/staging.json`. Optional Hetzner `workflow_dispatch` runs the same command and blocks the optional Android build behind it. The iOS workflow is dispatch-only (`macos-latest`); it does not run on PRs. Store/TestFlight stays on `mobile-v*` via `mobile-release.yml`. The dispatch test job also runs `test/product/network/api_config_test.dart` on its own first.

**Bare `flutter test` is red, and that is the design working.** `ApiConfig` refuses to build a client when no environment was selected, so a missing flavor cannot quietly fall back to the internet API — the single test the optional dispatch runs first exists to prove exactly that. Do not "fix" a red bare run by loosening `ApiConfig`; pass the flavor and the define file, the way the Mac gate does.

> **You can build this project — do it.** `flutter doctor` is green (Xcode installed and `xcode-select` pointed at it, Android SDK 37, JDK 17), so both of these work and are the real check that a change compiles end to end:
>
> ```bash
> flutter build apk --debug        # ya da --release
> flutter build ios --no-codesign
> ```
>
> `flutter analyze` alone only proves the Dart typechecks — it says nothing about the Gradle or Xcode side. After touching anything under `android/` or `ios/`, run the matching build.
>
> What you still **cannot** do is judge how it looks: that is the user's job (see *Visual verification* above). Running the app on a device or simulator is also theirs.

> ⚠️ **`pod install` / `pod update` are denied in `.claude/settings.json`.** `flutter build ios` triggers pod resolution itself and rewrites the tracked `ios/Podfile.lock`, so ask the user before the first iOS build of a session that changes dependencies.

> Each flavor xcconfig optionally includes its gitignored `Secrets.<flavor>.xcconfig`, so a fresh checkout and the no-codesign CI build do not need a placeholder. A real map acceptance still needs `MAPS_API_KEY`; production release writes `Secrets.production.xcconfig` from GitHub secrets.

> Running the app needs the Google Maps key to be in place — see *Secrets* below. Without it the map tab renders a blank grey area, which is a configuration problem, not a code bug.

---

## Architecture

### Folder layout

```
lib/
├── main.dart                     # MultiProvider registrations + runApp
├── product/                      # shared by both apps (employee + business)
│   ├── app.dart                  # MaterialApp.router, theme, deep link listener
│   ├── constants/                # AppColors, AppPadding, AppRadius, AppSizes,
│   │                             # AppAssets + app_icon_data.dart (AppIconData)
│   ├── extensions/               # context_extensions.dart (theme colors, sizes,
│   │                             # paddings) + num_extensions.dart (`asPrice`)
│   ├── router/                   # router_manager.dart (single GoRouter)
│   ├── theme/                    # theme.dart (light/dark), theme_provider.dart
│   └── widgets/                  # MyButton, MyTextfield, MyAppbar, MyListTile,
│                                 # NavbarItem, ButtonNavbar, AppBottomSheet,
│                                 # ThemeModeSheet, EmptyState
├── employee/
│   ├── core/widgets/             # shared across employee features only
│   └── features/<name>/
│       ├── models/               # plain data classes, no `Model` suffix
│       ├── services/             # where the data comes from (see Backend)
│       └── presentation/{pages,widgets,providers}
│                                 # pages come in `_page.dart` + `_pagemodel.dart`
│                                 # pairs wherever the page carries state
└── business/
    ├── core/                     # b_shell_page.dart + widgets/
    └── features/<name>/
        ├── models/
        ├── services/
        └── presentation/{pages,widgets,providers}
```

Employee features: `auth`, `home` (explore), `jobs`, `chat`, `notifications`, `profile`, `company_detail`, `settings`.
Business features: `home`, `chat`.

A feature has at most three top-level folders: **`models/`** (plain data classes), **`services/`** (where the data comes from) and **`presentation/`**. There is no `data/` or `domain/` wrapper — a model sits directly under `models/`. Create only the folders a feature actually needs; `auth` and `settings`, for example, now carry their own models and services as well as presentation.

**Where does shared code go?** Used by both apps → `lib/product/`. Used by several features on one side only → that side's `core/`. Used by a single feature → that feature's own folder. Do not push employee-only code into `product/`.

> `auth` lives under `employee/` even though it serves both sides (registration asks whether you are a business). That is historical; do not move it without being asked, but be aware the business flow runs through employee files.

> The same applies to chat: `business/features/chat` imports `ChatAvatar`, `ChatAppBar`, `MessageBubble` and `MessageTextField` from `employee/features/chat/presentation/widgets/`, because the `Conversation` and `Message` models live on the employee side. Strictly the shared parts belong in `product/`, but moving them would drag the domain models along; the existing convention is to reuse the employee widgets.

### State management

`provider`. Seventeen `ChangeNotifierProvider`s are registered in `main.dart`, in this order:

| Provider | Responsibility |
|---|---|
| `ThemeProvider` | Light/dark/system theme, persisted in `SharedPreferences` |
| `UserProvider` | The session owner off `/users/me` — read by both apps |
| `AvailabilityProvider` | The worker's weekly availability draft (`PUT` replaces all slots) |
| `JobCategoryProvider` | The server's job categories, fetched once and cached app-wide |
| `JobSearchProvider` | Explore's server-side search: the `JobSearchQuery`, the pages and the infinite scroll |
| `PageProvider` | Employee shell: which tab, and the explore map/list toggle |
| `SavedJobsProvider` | Saved jobs |
| `JobAlertsProvider` | The job alerts screen's server state |
| `TimesheetQueueProvider` | The offline timesheet event queue — **`lazy: false`**, it has to drain on start |
| `ReviewProvider` | The review form state |
| `NotificationProvider` | The notification feed and the unread count |
| `ApplyProvider` | The application form state |
| `SearchProvider` | The explore search query |
| `BPageProvider` | Business shell tab |
| `BJobsProvider` | Business job posts |
| `BCompanyProvider` | The employer's company and its stats |
| `BJobTemplatesProvider` | The employer's job templates |

> ⚠️ **`BPageProvider` is registered twice.** `main.dart` creates a global one, and `business/core/b_shell_page.dart` creates a second one with its own `ChangeNotifierProvider`. Pages inside the shell read the shell's instance, anything outside reads the global one — writing to one does not move the other. If you touch business tab state, know which instance you are on.

### Routing

`go_router`. A single `GoRouter` inside `product/router/router_manager.dart`, `initialLocation: '/'` — the splash screen.

**The `redirect` guard** is **synchronous**. It reads the session off `SessionManager`, which caches the flags in memory once `SplashPage` has called `load()`, and enforces five rules: session not read yet → `/`; not logged in → `/onboarding` if the intro has not been seen, otherwise `/auth`; logged in but on an auth route (`/`, `/auth`, `/onboarding`) → the home of your type; business user on an employee route → `/business/home`; employee user on a business route → `/explore`.

> ⚠️ **Never make the guard `async` again.** An awaiting `redirect` makes go_router place the pushed page outside the frame, and every page transition outside the shell silently stops animating. That is also why `main()` stays synchronous and the session is read on the splash screen instead.

> ⚠️ **Every route must declare its own `pageBuilder`.** Left on `builder:`, go_router picks the page type by sniffing the app and — in this go_router/Flutter pair — falls through to `NoTransitionPage`, so the page opens with no animation and nothing warns you. Top-level routes go through `RouterManager._page` (a `MaterialPage`, i.e. the platform's own transition); the shell tabs keep theirs. `test/product/router/router_pages_test.dart` guards this.

The decision itself lives in `RouterManager.resolveRedirect(initialized:, loggedIn:, userType:, seenOnboarding:, location:)`, a pure static function — the `redirect` callback only feeds it what `SessionManager` already holds. Change the rules there and cover them in `test/product/router/router_manager_test.dart`; this is the one piece of logic that keeps the two apps apart.

**Two `ShellRoute`s**, one per app:

- Business shell (`BShellPage`): `/business/home`, `/business/posts`, `/business/chat`, `/business/profile` — fade transitions.
- Employee shell (`ShellPage`): `/explore`, `/jobs`, `/chat`, `/profile` — no transition.

Everything else (`/apply`, `/review`, `/company-detail`, `/chat-detail`, `/settings`, `/business/create`, `/business/job-detail` ...) is **top level**, so it opens full screen above the navbar. If you add a page that must cover the navbar, put it at top level — a route nested inside the shell stays underneath it.

> ⚠️ **The employee `ShellPage` ignores go_router's `child`.** It keeps a static `PageView` of the four pages and only uses the matched location to pick an index (`didChangeDependencies`). So the route drives the index, not the content — the pages are constructed once and kept alive. Anything you expect to rebuild on navigation will not. `BShellPage` does the opposite: it renders `child` normally.

**Passing data between routes** is done with `state.extra` and an unchecked cast (`state.extra as Job`). Navigating to those routes without the right `extra` throws. There is no `pageKey`/`ValueKey` on them.

### Deep links

`app_links` listens in `app.dart`; the subscription is cancelled in `dispose`. `AppLinkDestination` accepts the running flavor's exact native scheme (`koala-dev`, `koala-staging`, `koala`) and its verified HTTPS host: production owns `iskoala.com`/`www.iskoala.com`, staging owns `staging.iskoala.com`, development owns no public HTTPS host. The canonical host/path contract lives in `docs/deep-links.md`; unknown extra query parameters are ignored, while duplicate or missing required parameters remain invalid. Registration opens `/auth/register-type/register/creating-password`, password reset opens `/reset-password`, e-mail verification opens its token handoff page, and payment return opens `/payment-result`. Existing custom-scheme aliases remain accepted; HTTPS uses canonical paths only.

Cold-start links can arrive before `SplashPage` finishes loading the session. `AppLinkCoordinator` holds the last valid link until `SessionManager.isInitialized`, then opens it once; navigating earlier makes the synchronous router guard send it back to splash.

### Backend

**All runtime data services are wired to the real backend.** Fakes live only in tests; production pages must not invent sessions or domain data locally.

The API is a Spring Boot service in the private `is-koala/koala-backend` repository: layered `webAPI → business → dataAccess`, Postgres + Liquibase, RabbitMQ for mail/SMS/push, S3-compatible storage for files, and Iyzico for payments. Every response comes wrapped in the same envelope — `{success, message, httpStatus, path, timeStamp, requestId, data}`. Messages are localized; the app sends `Accept-Language: tr`.

**The base envelope keeps its nulls; the error envelope drops them.** `Result` and `DataResult` carry **no** `@JsonInclude`, so a success response spells out `"data": null` and `"message": null` rather than omitting the fields — a `SuccessResult` endpoint still sends a `data` key. `ErrorResult` is annotated `@JsonInclude(NON_NULL)`, so on the error side every field below can simply be **absent**. Treat a missing one as "not sent", never as a malformed response.

An error adds **five** fields on top of the base envelope, and **all five are conditional**:

| Field | When it appears |
|---|---|
| `errorCode` | Always in practice — `ErrorResult` falls back to `errorCategory.name()` when the exception carries no code of its own. It is close to free text (a `KoalaException` derives it from the message key: `{jwt.expired}` → `JWT_EXPIRED`), so it identifies *this* error, not its class. |
| `errorCategory` | Whenever the response comes from `GlobalExceptionHandler` or `MinimumAppVersionFilter`. A closed set of 17 values (`ErrorCategory.java`) — **this is the field to `switch` on.** |
| `resource` / `resourceId` | Only when `RequestResourceResolver` can name the record the request was about; both are null on endpoints that address no single record. |
| `details` | Only on field-level validation errors; `withDetails` stores `null` for an empty list, so an error with no field errors omits the key rather than sending `[]`. |

**`ApiErrorType` is derived from `errorCategory`, and the HTTP status code is only the fallback.** The whole rule is one pure function — `ApiErrorType.classify(errorCategory:, statusCode:)`, which tries `fromCategory` and falls back to the library-private `_fromStatusCode`. The status code loses information the app needs: the server distinguishes `AUTHENTICATION_REQUIRED` / `INVALID_CREDENTIALS` / `TOKEN_EXPIRED` from `ACCESS_DENIED`, and `BUSINESS_RULE_VIOLATION` from `DATA_CONFLICT`, while `401`/`403` and `409` collapse each pair into one type (is-koala/koala#82). The first split is the one users feel — a dead session sends them back to the login screen, a permission refusal must not.

> ⚠️ **`classify` has two callers on two different layers, and that is the point.** `ApiClient` calls it after unwrapping the envelope, to build the `ApiException` a page will read; `AuthInterceptor` calls it *before* that, on dio's raw `Response`, to decide whether to refresh the session. Refreshing used to gate on `statusCode == 401` instead, which meant `unauthenticated` had **no reader at all** — the tie between the type and the behaviour rested entirely on "the server sends these categories with a 401", and a server that moved `TOKEN_EXPIRED` to another status would have disabled refreshing silently (is-koala/koala#86). Do not give either caller its own copy of the rule: two copies drift, and the drift shows up as the refresh path and the user-visible error type disagreeing about the same response.

> ⚠️ **Keeping the rule in one place is not enough — the road to it has to be one too.** `_fromStatusCode` is library-private, so nothing outside `api_exception.dart` can ask the status code on its own; a caller that genuinely has no category says so in the rule's own words, `classify(errorCategory: null, statusCode: …)`, which is what `ApiClient` does for a response with no envelope. While the fallback table was public, `ApiClient` used it directly and any page or provider could have done the same — classifying by status code alone is precisely the defect #86 fixed, and neither the analyzer nor a test would have reported it. Making the table public again re-opens that door (is-koala/koala#99).

> ⚠️ **The category set is closed but it can grow.** `fromCategory` returns `null` for a value it does not know, and the client falls back to the status code — it must never throw, or a server-side enum addition would crash the app. Completeness is not a second Dart list: `test/product/network/api_client_error_category_test.dart` compares `fromCategory` keys to the backend `ErrorCategory` source through `BackendContractRoot` (OpenAPI via `KOALA_OPENAPI_PATH`, otherwise `ErrorCategory.java` from `KOALA_BACKEND_ROOT` / `KOALA_BACKEND_PATH` or a sibling `koala-backend` checkout). Fixture tests pass `from:` and do not walk into a real checkout. The unknown-value path is still pinned.

> ⚠️ **`errorCode` routing is the same trap with a different source.** Codes are derived from message keys (`{job.alert.too.many}` → `JOB_ALERT_TOO_MANY`). A Dart constant and its test fixture can be misspelled together and stay green (is-koala/koala#89). `test/support/backend_error_codes_test.dart` reads `messages_tr.properties` and checks every routing code in the listed lib files against that catalog.

> ⚠️ **The app assumes the server never sends `ACCESS_DENIED` with a `401`, and nothing in the app enforces that.** `SessionManager.end` has exactly two callers: `api_client.dart:27`, which fires only when `AuthInterceptor._shouldRefresh` said yes **and** the refresh then failed, and `auth_service.dart:161`, the user's own logout. A `401` carrying `ACCESS_DENIED` therefore classifies as `forbidden`, refreshing is never attempted, and **nothing drops the user to the login screen**: the token is dead, every screen says "you are not allowed", and there is no way out of the app.
>
> **Measured, and it cannot happen today.** In `is-koala/koala-backend` that category has exactly two producers and both are bound to `HttpStatus.FORBIDDEN` — `GlobalExceptionHandler.java:91` builds it with `FORBIDDEN` directly, and `:151` maps `case FORBIDDEN -> ErrorCategory.ACCESS_DENIED` for every `KoalaException` that goes through `categoryOf`. `grep -rn ACCESS_DENIED src/main/` finds nothing else. So the client code is right and needs no change; what was missing was the assumption being written down. If a third producer ever pairs `ACCESS_DENIED` with a `401`, this paragraph is what says which screen breaks and why (is-koala/koala#99).

**The network layer lives in `lib/product/network/`** and is shared by both apps:

| File | Responsibility |
|---|---|
| `api_config.dart` | Flavor, base URL, app-link scheme and timeouts. Both `--flavor` and `--dart-define=API_BASE_URL=...` are mandatory; an invalid or missing environment fails closed before networking starts. |
| `api_paths.dart` | Endpoint paths, plus the set of paths that need no token. |
| `api_client.dart` | The application-facing request facade: unwraps the envelope and turns `DioException` into `ApiException`. Multipart entry points encode the HTTP and response contract: `postFile` is POST + one file + data, `putFile` is PUT + one file + data, `putFileWithoutData` is PUT + one file + no data, and `postMultipartJson` is POST + a JSON part + an optional file + data. All force `multipart/form-data`, because the base options say `application/json`. |
| `api_exception.dart` | `ApiException` / `ApiErrorType` — the single error type services and pages see. It also owns the classification: `fromCategory` is the `errorCategory` → type mapping, `_fromStatusCode` the **library-private** fallback table, and `classify` the "category first, status second" rule both `ApiClient` and `AuthInterceptor` call — and the only way in. `serverStateMoved` is there for callers that mean exactly that — reload, because the record changed — regardless of which of the two conflict categories arrived. **A caller that needs to know *which* error arrived reads `errorCode`, not the category**: the category names a class of error, the code names the error itself (`ReviewProvider`, `JobAlertsProvider`). |
| `api_response.dart` | The envelope. `errorCategoryOf` reads the category out of a **raw** body for the one caller that has no parsed envelope yet (`AuthInterceptor`); `fromJson` goes through it too, so the field has a single reader. |
| `auth_interceptor.dart` | Attaches the bearer token, reads the raw envelope with `ApiResponse.errorCategoryOf`, and on an error that `ApiErrorType.classify` identifies as `unauthenticated` refreshes once and retries. The gate is the category, not the status code — `401` survives only as `classify`'s fallback, which is what keeps an old server, a hand-written filter envelope or a non-JSON error page behaving as before. |
| `token_storage.dart` | Access/refresh tokens in Keychain/Keystore (`flutter_secure_storage`). |
| `session_manager.dart` | Opens and closes the session: tokens plus the `is_logged_in` / `user_type` flags the router reads. |
| `device_identity.dart` | The per-install id sent as `X-Device-Id`, and the descriptive `User-Agent`. The backend binds sessions to the device, so the id must survive app updates — it lives in `SharedPreferences` and is **not** cleared on logout. |
| `device_interceptor.dart` | Puts `X-Device-Id` on every request, signed in or not. |

Authentication and legal flows use `auth_service.dart` (registration in three steps, login, logout, forgot/reset password, `/users/me`) and `legal_service.dart` (agreements, consents, account deletion). Both live under `employee/features/auth/services/`, because registration is where consents are collected; the rest of the app's real services sit with their own features.

**Registration needs consents.** `/auth/complete-registration` rejects the request unless every mandatory agreement is granted, so the password screen first calls `GET /legal/agreements` (public) and sends `consents: [{agreementVersionId, granted}]` along with the password. Today the server seeds three mandatory agreements (terms, privacy, explicit consent) and one optional (commercial messages).

**Job categories come from the server.** `JobCategory` is no longer an enum — it is a plain class carrying `id`, `name`, `code` and `requiresInsurance`, fetched from `GET /reference/job-categories` by `employee/features/home/services/job_category_service.dart` and cached app-wide in `JobCategoryProvider` (registered in `main.dart`, read by both the employee explore filter and the business create-job picker).

The icon, colour and map pin are *presentation*, resolved from `code` by the `JobCategoryStyle` extension, with a fallback for codes the app has no artwork for. **A code mismatch does not throw** — the category silently renders with the default icon, brand green and the waiter pin. That has already happened once, when the server migrated the codes from Turkish slugs to English, so `JobCategoryCodes` is guarded by a test in `test/employee/features/home/models/job_test.dart` that fails if any known code falls through to the fallback. The five seeded codes are `PHOTOGRAPHY`, `WAITER`, `PET_CARE`, `DESIGN`, `BARISTA` (`27-10-job-category-seed.xml`).

`JobCategorySeeds` exists only so the tests can build a `Job` without a live category list; its ids are deliberately `seed-` prefixed rather than UUIDs so they can never match a real record. Nothing in `lib/` reads it — keep it that way.

> There is no neutral map pin for an unknown category — the waiter pin is reused, recoloured. Marked `TODO(tasarım)` in `job.dart`.

The employer flag is spelled **`isEmployer`** everywhere — the server pins it with `@JsonProperty("isEmployer")` on `AuthStartRegistrationDto`, `AuthSetPasswordDto` and `UserMeResponseDto`, and the request field is `@NotNull`. Read it through `CurrentUser.readEmployerFlag` so the two models that carry it stay in step.

Refreshing works with an expired access token: the server skips its session filter on `/auth/refresh-token` and reads the session id out of the expired JWT's claims. The call still has to carry the `Authorization` header, which is why that path is deliberately not in `ApiPaths.publicPaths`.

**Chat is on the real endpoints.** `employee/features/chat/services/chat_service.dart` wraps the whole surface and **both apps use it** — `GET /conversations` returns the session owner's conversations regardless of whether they are the employer or the worker, so `b_chat_list_page` and `b_chat_page` call the same service. The business side has no chat service of its own; `business/features/chat/` is `presentation/` only.

Every call takes a `currentUserId`, because the server does not say who the counterpart is or who sent a message: both are derived by checking which of the two participants is the session owner. The pages read it from `UserProvider` and load the user first if it is not there yet.

Three things worth knowing:

- **A conversation always belongs to a job**, opened with `POST /jobs/{jobId}/conversation` (the employer passes `?workerId=` to pick the applicant). There is no company-level conversation and none is offered on company detail — the misleading Mesaj At action was removed rather than left as a toast-only primary button (is-koala/koala#138).
- **The server returns newest-first**; `MessagePage.fromJson` sorts ascending because the UI draws oldest to newest.
- **Presence is a separate call.** `ConversationDto` carries no online flag; the list fetches it in one batch (`POST /presence/lookup`) and merges it in with `copyWith`. That call failing does not block the list — a missing green dot must not hide the conversations.

**Live updates run over STOMP.** `product/network/realtime_client.dart` holds one shared connection to `/ws` (`stomp_dart_client`, plain WebSocket — the server does not enable SockJS). Authentication is the `Authorization: Bearer` **native STOMP header on the CONNECT frame**, not a handshake header; `StompAuthChannelInterceptor` reads it there. The client reconnects on its own and re-subscribes, because STOMP subscriptions die with the connection.

Three destinations, and **the server authorises every SUBSCRIBE**:

| Destination | Who may subscribe |
|---|---|
| `/topic/conversations/{id}` | participants of that conversation |
| `/user/queue/messages` | always — Spring routes it to the session owner |
| `/topic/presence/{userId}` | yourself, or someone you share a conversation with |

Anything else is `403`. **A STOMP error frame tears down the whole connection**, so never subscribe speculatively — only to conversations you are in and to counterparts already in your conversation list. There is no global presence topic; watching a stranger's online/offline transitions would be a behaviour-tracking channel, which is why it was removed.

Typing is published back to `/app/conversations/{id}/typing`, throttled to one frame every two seconds.

> ⚠️ **`RealtimeClient.disconnect()` must snapshot its maps before closing anything.** Each destination's `StreamController` has `onCancel: () => _releaseIfUnused(destination)`, and `close()` cancels the listeners — so closing while iterating `_controllers.values` re-enters and removes from the map being walked. That threw `ConcurrentModificationError` on logout and left the user signed in, because the exception landed before `AuthService().logout()`. Copy the values, clear the maps, *then* close; a re-entrant `_releaseIfUnused` then finds nothing. `test/product/network/realtime_client_test.dart` guards it.

> Both logout paths (`settings_page` and `b_settings_page`) call `disconnect()` **before** `AuthService().logout()` — the connection is tied to the session, and tearing down after the token is gone leaves the client reconnecting with a dead session.

Two controllers own all of this, and **both apps share them**:

- **`ChatThreadController`** — one conversation: messages, sending, typing, read receipts.
- **`ChatListController`** — the list: conversations, the personal message queue, and one presence subscription per counterpart, kept in sync as the list changes.

The same message arrives on **two channels** — the conversation topic and `/user/queue/messages` — and the server sends the copy to *both* participants, so your own message comes back to you too (that is deliberate: it keeps a second device's list current). Dedupe by `message.id`, and never count your own message as unread.

> **The connection is optional.** If it cannot be established the app keeps working over REST — only updates stop being instant. Never let a realtime failure block a screen.

> **Read receipts clear the badge across devices.** `RealtimePublisher.conversationRead` publishes to `/topic/conversations/{id}` **and** to every participant's `/user/queue/messages`, and `ChatListController._onUserEvent` now dispatches on the event type instead of dropping everything that is not a message. Only **your own** read clears the count — the counterpart reading is a receipt on messages you sent, which the list does not show, so treating it the same would zero a badge that still has unread messages behind it.

**The employer's job flow is real too.** `business/features/home/services/employer_job_service.dart` owns it: `GET /users/me/jobs` (own posts, individual and company alike — the server filters by `creatorId`), `POST /users/me/jobs` / `POST /companies/{id}/jobs` (open a post), `POST /jobs/{jobId}/close`, `GET /jobs/{jobId}/applications` and `POST /job-applications/{id}/respond`. `BJobsProvider` merges the first and the fourth into one list; `b_job_detail_page` fetches the richer `GET /jobs/{id}` itself.

Things worth knowing:

- **The count is free, the people are not.** `JobSummaryDto.applicationCount` arrives with the list (the server fills it in the same pass as the cover images), so no screen fetches applicants just to show a number. Who actually applied comes from `GET /jobs/{id}/applications` and is fetched **per job, on demand**, through `BJobsProvider.ensureApplicants` — the detail screen for its own job, the home screen for the three posts its preview shows, and the posts list only for past posts, whose footer names the person who took the job. Never load them for the whole list; that was the old N+1.
- **Insurance is a company-only concept, deliberately.** `CreateIndividualJobDto` has no `insuranceRequired`, the server forces it to `false`, and it rejects an individual job in any category whose `requiresInsurance` is set (`400`) — reporting SGK is the employer's legal duty and a one-day individual employer is not expected to carry it. So the create screen hides the switch for an individual employer, replaces it with a line saying why, **and filters those categories out of the picker** rather than letting the form fail on submit. Which endpoint is used comes from `CurrentUser.activeCompany` — the first **approved** membership.

  The company side of the same rule is enforced too: a company job in a `requiresInsurance` category is rejected with `400` unless `insuranceRequired` is `true`, so the switch is **forced on and disabled** while such a category is selected, with a line saying why. The value is **derived** (`_insuranceLocked` / `_insuranceRequired` in `b_create_pagemodel.dart`), never a field synced on category selection — the field version was the bug: every path that changes the category (the picker, a template) had to remember to update it, and one that forgot dropped the rule silently.
- **There is no endpoint that deletes a job, and there should not be.** The post menu offers two things instead: *İlanı Kapat* (`POST /jobs/{id}/close`) stops new applications and leaves the post valid, *İlanı İptal Et* (`POST /jobs/{id}/cancel`) invalidates it and notifies the applicants. Cancel asks for confirmation first because the two read alike but are not, and it refuses with `409` while a live assignment exists (`PENDING_CONFIRMATION` / `CONFIRMED` / `IN_PROGRESS`) — cancelling there would route around the escrow and the cancellation policy, and the assignment's own cancel flow must be used instead. Neither one deletes anything; the record and the application history stay.
- **Accepting an application does not close the job.** The server opens an assignment in `PENDING_CONFIRMATION` and waits for the worker; the post stays in "Aktif" until its `JobStatus` says otherwise. Active vs. past is decided by `JobStatus` (`OPEN` → active; `CLOSED`/`CANCELLED` → past; dropped `IN_PROGRESS`/`COMPLETED` job statuses map closed), never by a local flag.

> `JobApplicantDto` carries `jobTitle` and `cvUrl` **on itself**, not inside its `SafeUserDto` — that DTO is reused across ten responses and the profession does not belong in all of them. `cvUrl` is only filled for the job's employer, and the download route checks ownership again, so a leaked link still cannot be fetched.

**The candidate profile** (`b_user_profile_page`) paints twice: the `JobApplicant` handed in through `state.extra` gives the name, photo, cover letter and date immediately, then `GET /users/{userId}` → `PublicProfile` fills in the profession, the "hakkında" text, the location and the CV. That endpoint deliberately returns **no full address** — city and district only — and it is open to signed-in users, not anonymous ones. If it fails the screen does not blank: a strip at the top offers *Tekrar dene* and the application data stays on screen. The CV opens in the external browser through `url_launcher`, because the URL is a redirect to a short-lived signed address rather than the file itself.

**The employer's profile is real too.** Shared `CompanyService` reads `GET /companies/{id}`; `business/features/home/services/b_company_service.dart` creates and updates companies, manages logos and galleries, and reads `GET /users/{userId}/employer-stats`. `BCompanyProvider` (registered in `main.dart`) holds the company and its stats for the profile, settings and company-info screens.

- **The profile has two valid shapes.** An employer with a company membership sees the **company**; one without sees **themselves** — name, e-mail, phone and address off `/users/me`. Being company-less is not a gap: `POST /users/me/jobs` posts individual jobs. `b_profile_page` renders both from the same widgets.
- **Two different "company" getters on `CurrentUser`.** `activeCompany` is the first **approved** membership and decides which create-job endpoint is used; `primaryCompany` is the first membership regardless of approval and is what the profile shows — otherwise someone who just registered a company would never see it and would think they were an individual employer.
- **`PATCH /companies/{id}` accepts five fields only** — name, e-mail, phone, website, description (`UpdateCompanyRequestDto`), and only from the company's `ADMIN`. Tax number, address, type and logo are fixed at creation, so the company-info screen keeps those fields visible but `enabled: false` with a note saying why. Fields left blank are omitted from the body rather than sent as `""`, which would clear them.
- **The approval flag is spelled `approved`, not `isApproved`** — the same name `/users/me` → `CompanyMembershipDto.approved` uses, so the concept has one name across the API. `BCompany` parses `approved`; the Dart field stays `isApproved` because that is how a flag reads. `BCompanyProvider` still overwrites it from the membership after a fetch, which is now belt-and-braces rather than the only source.
- **Employer stats are per person, not per company** (`StatisticsManager` counts by `creatorId`), so two admins of the same company see different numbers. Zero reviews come back as `averageRating: 0`; `EmployerStats.hasRating` separates that from an actual bad score so the card shows "—" instead of "0.0".

- **The logo is editable, the rest of the fixed fields are not.** `PUT /companies/{id}/logo` (multipart, part name `logo`, `ADMIN` only) and `DELETE` on the same path both return the company, so no second read is needed. The company-info screen picks from the gallery and checks extension and size **client-side** against the server's own limits (`png/jpg/jpeg/webp`, 10 MB, from `UploadProperties`) so the user is not left waiting for a rejection. The file is sent **unmodified** — re-encoding it would flatten a transparent PNG, which is visible on a logo.

> **Company creation has an identity gate, and the app enforces it before the request too.** `POST /companies` rejects an unverified user with `USER_MUST_VERIFY_IDENTITY` (`CompanyManager.addCompany`, `400`), which used to reach the user as a raw toast on the company form (is-koala/koala#134). `CompanyIdentityGate` (`employee/features/auth/presentation/`) now sits in front of the form at both entry points — the post-registration type choice and *Firma Bilgileri* for a company-less employer (its empty state carries *Firma Kaydı Oluştur*) — and pushes `/identity-verification` first, refreshing `/users/me` when it returns. The form keeps a second check on submit, keyed on `errorCode`, and that path (`startVerification`) deliberately ignores the local `identityVerified` flag: the server's refusal is the last word, and a stale `/users/me` copy must not leave the user on a form with no way out. A successful create refreshes `UserProvider` and force-loads `BCompanyProvider`, then pops back when the form was pushed (Settings) or goes to `/business/home` (registration). Nothing about the policy moved — the server check and `IDENTITY_PASSIVE_AUTH_ENABLED` are untouched.

> Company creation is wired through multipart `POST /companies`, and the company-info screen manages `/companies/{id}/images` as a reorderable gallery. The contact list and invitations (`/contacts`, `/contact-invitations`) still have no app surface. `Company.followerCount` is parsed and adjusted after follow/unfollow but is not rendered on the company-detail screen; the followed-companies list renders its own `FollowedCompanyDto.followerCount` summary.

**The worker's side of the assignment is on the real endpoints too.** `employee/features/jobs/services/assignment_service.dart` owns them: `GET /users/me/assignments` (moved off `JobApplicationService`, which now carries applications only) and `POST /job-assignments/{id}/respond`.

Accepting an application does not start the job — the server opens the assignment in `PENDING_CONFIRMATION` and **waits for the worker**. `MyJobStatus.awaitingApproval` is that state, and "İşlerim" shows it in its own section above everything else, with Kabul Et / Reddet. Rejecting asks for confirmation first; the answer is given once and `REJECTED` moves to "Geçmiş" so the decision remains visible. Answering a second time is `409`; the screen shows the server's message and reloads, because a `409` means the local list is stale.

> `MyJob.assignmentId` is `null` on rows that came from an application and carries the id on rows that came from an assignment. It duplicates `MyJob.id` on purpose — the assignment endpoints need an id that is definitely an assignment's.

**The timesheet is wired on both sides.** `AssignmentService` gained `checkIn` / `checkOut` / `fetchWorkSessions`, and `EmployerJobService` gained `fetchMyAssignments` (with `asEmployer: true`) and `completeAssignment`.

Things worth knowing:

- **Check-in and check-out are worker-only; complete is employer-only.** The server returns `403` for the wrong party, so the two live on opposite sides of the app on purpose. `fetchWorkSessions` is the exception — both parties may read it, so `b_job_detail_page` calls the employee-side `AssignmentService` for it, the same way both apps share `chat_service.dart`.
- **The money gates the timesheet.** The server refuses a check-in unless `paymentStatus` is `HELD_IN_ESCROW`. `MyJob.isPaymentSecured` carries that, and the approved tile replaces the button with a line saying why rather than letting the user earn a `409`.
- **`IN_PROGRESS` is now its own screen state.** `MyJobStatus.inProgress` sits at the very top of "İşlerim" in its own teal section (`AppColors.progress`, the only hue the other four sections had not taken), because a worker mid-shift wants the check-out button first. Open sessions are fetched **only** for in-progress assignments — nobody has two shifts running at once, so this is not the N+1 that applicant loading used to be.
- **The elapsed time ticks.** `WorkSession.elapsed` computes from `DateTime.now()` on an open session, so `my_jobs_pagemodel` runs a one-minute `Timer` while any session is open and cancels it when none is. Without it the screen would show a frozen duration, which on a timesheet is worse than showing nothing.

> There is no endpoint that returns the assignment for a given job — `JobDetailDto` does not carry one — so `b_job_detail_page` fetches the employer's assignment page and filters by `job.id`. If a per-job endpoint ever lands, that is the one call to replace.

**Cancellation and disputes are wired on both sides.** `AssignmentService` owns `cancel`, `fetchCancellation`, `openDispute` and `fetchDisputes` — all four are open to **both** parties, so the business side calls the employee-side service for them, as it already does for work sessions.

Things worth knowing:

- **The fee is shown before the decision.** `GET /{id}/cancellation-preview` computes what would be deducted without creating anything, for the caller's own side; both dialogs fetch it on open and write the real figure. It is **not binding** — the deduction depends on how long is left before the job starts, and the server recomputes on cancel — so the text says so. If the preview call fails the flow continues with the rule stated in words: not knowing the fee must not remove the right to cancel.
- **`cancellableNow` replaces an error.** On an assignment that can no longer be cancelled the endpoint returns the flag rather than a `409`, so the screen closes the door before the dialog opens. `CancellationPreview` defaults it to `false`: if the answer is unknown, do not assume cancelling is allowed.
- **A reason is mandatory on both endpoints.** `ReasonDialog` (`product/widgets/`) keeps its confirm button disabled until the field is non-empty, so nobody spends a round trip to learn that. Both apps use it.
- **Disputes need money in escrow.** The server refuses otherwise, and one open dispute blocks a second. `MyJob.isPaymentSecured` and the fetched dispute list gate the buttons on both sides. An open dispute freezes the escrow — it does **not** speed a payout up — and both dialogs say so, because a worker reading "bildir" could easily assume the opposite.
- **Cancelled and rejected assignments are back in the list.** `MyJob.fromAssignment` used to return `null` for them and they vanished; now `MyJobStatus.cancelled` / `.rejected` put them in "Geçmiş" with a red marker and the status text in place of the amount — no money was earned, so showing the green figure would have been a lie. `fromAssignment` is non-nullable as a result.

**Applying has a gate, and it is enforced in production.** `POST /jobs/{id}/applications` now checks three things in order — identity, address, primary IBAN — and rejects with `APPLICANT_IDENTITY_NOT_VERIFIED`, `APPLICANT_ADDRESS_REQUIRED` or `APPLICANT_BANK_ACCOUNT_REQUIRED`. The order is the worker's repair order, and the same three conditions gate the İyzico sub-merchant record, so a mismatch would blow up at acceptance instead.

- **The check happens twice, on purpose.** `/users/me` already carries `identityVerified`, `address` and `maskedIban`, so `ApplicationReadiness` shows what is missing **before** the form is filled in and disables the submit button. The server's `errorCode` is still handled on submit — the user may have changed something on another device. `ApiException.errorCode` is what routing keys off, never the message text.
- **Three screens exist for it now:** `identity_verification_page.dart` (`POST /users/me/identity-verification`, NVİ-checked, and it locks first/last name afterwards), `address_page.dart` (`PUT /users/me/address`) and an IBAN field on `account_info_page`. IBAN has **no endpoint of its own** — it rides on `PATCH /users/me` and comes back masked, which is why the field opens empty and an empty field is never sent.
- **The address endpoint demands coordinates.** There is no geocoding endpoint, so the user picks them on the map. `BLocationPickerPage` is reused through a second route, `/pick-location`; the page still lives under `business/` and should move when someone touches it next.
- **`ReferenceLocationService` and `ReferenceLocation` moved to `product/`** (`product/services/`, `product/models/`) — both apps need country/city/district lists now, and leaving them in `business/` would have made the employee app depend on the employer app.

**Company detail is on the real endpoint, and the last fake service is gone.** `employee/features/company_detail/services/company_service.dart` now reads `GET /companies/{id}` and writes `POST|DELETE /companies/{id}/follow`.

- **The two `Company` models merged.** The old fake one is deleted and `BCompany` moved to `employee/features/company_detail/models/company.dart` as `Company` — the shared domain model lives on the employee side and the business app imports it, the same arrangement chat already uses. `b_company_service.dart` keeps only the employer's **write** endpoints (create, update, logo and gallery) plus stats; reading a company is one endpoint for both apps, so `BCompanyProvider` takes a `CompanyService` too.
- **One request, not three.** `CompanyDto` carries `images`, `followerCount` and `following` inline, so the screen never calls `/companies/{id}/images` or asks whether the user follows the company. The gallery endpoint stays in `ApiPaths` for managing a gallery, not for reading one.
- **The page takes an id, not a `Company`.** It is reached from a job, a past job or a chat, and none of those hold the full record. Following is optimistic — the button flips immediately and rolls back if the request fails, because both endpoints are idempotent and the outcome is predictable.

> Company jobs are read with `GET /jobs?companyId=...` and every result page is collected, so equal company names and the first-page boundary cannot alter the list. Company-level chat is not a product surface: company detail has no message action, and a conversation still always belongs to a job.

**Experiences are editable.** `employee/features/profile/services/experience_service.dart` writes `POST|PUT|DELETE /users/me/experiences[/{id}]`; the list itself still arrives inside `/users/me`, so every change refreshes `UserProvider` rather than patching the local list. `PUT` replaces the whole record — a field left blank in the sheet is cleared on the server, which is why the form opens pre-filled. Dates go as `yyyy-MM-dd`: `toIso8601String` writes a time component and the server's `LocalDate` parser rejects it.

**Reviews are on the real endpoints.** `employee/features/jobs/services/review_service.dart` owns all three: `POST /job-assignments/{id}/reviews` (write), `GET /users/{id}/reviews` and `GET /users/{id}/rating-summary` (read). Writing goes through the **assignment**, reading through the **person** — a review is left on a job but written about the counterpart. `profile_page` shows both through `ProfileReviews`, which fetches its own data and fails on its own strip rather than blanking the profile.

Three things worth knowing:

- **Anonymous reviews are supported and the toggle is back.** `CreateReviewDto` takes `anonymous`, and `ReviewDto` carries the flag with `author` omitted when set. The hiding happens **only in the response layer** — `author_id` stays populated in the database, so the one-review-per-party rule and abuse review still work. `Review.author` is therefore nullable and `authorLabel` falls back to "Anonim"; no placeholder user is invented. The choice cannot be changed afterwards, and the review screen says plainly that an employer may still infer who wrote it from the job — an assignment has only two sides.
- **Nothing on the server says "did I review this".** The second review is a `409`, and that is the whole API. `ReviewProvider` therefore keeps the reviewed assignment ids in `SharedPreferences` (`reviewed_assignments`) so the "Değerlendirildi" badge survives a restart. It is cleared on logout alongside the other providers.

  **A rejection only marks the id when `errorCode` is `REVIEW_ALREADY_REVIEWED`, and the category is not enough to decide that.** `ReviewManager.leaveReview` refuses two different situations with the same `ConflictException` — the assignment is not `COMPLETED` yet (`{review.work.not.completed}`), and the review already exists (`{review.already.reviewed}`) — so both arrive as `409` + `DATA_CONFLICT`. Marking the first one writes the id to disk and leaves that assignment permanently unreviewable, long after the work is finished. The only field that separates them is `errorCode`, which `KoalaException` derives from the message key. When no code arrives, or a code the app does not know, nothing is marked: the cache is a convenience, so it may only fail in the direction that shows one extra button.
- **A review is allowed the moment the assignment is `COMPLETED`,** not when the money moves. So "Değerlendir" sits in **both** the "Ödeme Bekleniyor" and the "Geçmiş" section; if it were only in the first, an employer who pays quickly could never be reviewed.

> `RatingSummary` is `null`, not zeroed, for someone with no reviews — the endpoint returns `data: null` and `hasRating` keeps "no rating" apart from "rated 0.0", the same distinction `EmployerStats.hasRating` makes.

**There are no fake services left.** Every `services/` class in the app talks to the real API. (`home/services/location_service.dart` is not a data service — it is the device's own location permission flow.)

Employer payment is wired through `POST /job-assignments/{id}/payment-session`. The hosted Iyzico checkout opens in the platform's in-app browser (`SFSafariViewController` on iOS, Custom Tabs on Android), never as an unrestricted embedded WebView. The return link only triggers a refresh; the app shows success from the backend assignment/payment state, not from query parameters.

Endpoints that exist on the server and have no app surface yet: the employer talent pool (`/users/me/talent-pool`). Push-token registration (`/users/me/devices/push-token`) is wired on Android through FCM (`FirebaseMessagingPushTokenSource`); iOS APNs is a separate issue. Blocks, reports and job templates have shared or business-facing pages and routes.

> The orphaned fakes were deleted once the employer's job flow landed: `profile/services/fake_user.dart` and its `profile/models/user.dart`, `jobs/services/my_jobs_service.dart`, `business/features/chat/services/b_chat_service.dart`. A feature carries `models/` and `services/` only when it has data of its own.
- **Explore searches on the server.** `JobSearchQuery` (`employee/features/home/models/`) mirrors `JobSearchCriteriaDto` field for field — no invented fields — and `JobService.search` takes it, with `page`/`size` kept separate because they belong to pagination. `JobSortOption` carries only the four fields in the server's `SORTABLE_FIELDS`; an unlisted field is a `400` (`PAGE_SORT_FIELD_NOT_ALLOWED`), not an empty list, so sort strings are never written by hand. The default `createdAt,desc` sends no `sort` at all, since that is what the server already does.

  These consequences are easy to get wrong:

  - **The query cannot be read backwards.** It holds a `categoryId`, not a name, and a bounding box, not the kilometres the user picked. `JobFilterSelection` is the UI's side of it and converts one way; the filter chips in the bar are drawn from the selection, never from the query.
  - **The category filter goes by id.** `code` stays what the icon, colour and map pin resolve from — the server pins that contract in `ReferenceDataController` — but the filter is `categoryId`. Comparing against `code` was the old bug.
  - **The list and the map share the query model, not the state.** `JobSearchProvider` (registered in `main.dart`) owns the list's pages and infinite scroll; `MapExploreController` is created by the map page and owns the map's own. Merging the two is the right direction and a separate job — what must not diverge is the query.

  - **Both sides carry a request token, and neither may drop a query instead.** `JobSearchProvider.applyQuery` used to write the new criteria into `_query` and then let `load` return at `if (_isFetching)`, so the request was **silently discarded**: the model held the user's new filter while the screen kept showing the old results, and nothing anywhere reported the loss (is-koala/koala#31). A token is the fix in both directions — the newest query always goes out, and a late response, error included, is dropped when it no longer matches. `loadMore`'s page is tokened too: once a new filter has been applied, an in-flight page belongs to the previous query and appending it would mix two result sets. **Do not "fix" a concurrent request by refusing to send it.**

- **The map sends its visible region.** `onCameraIdle` → `getVisibleRegion()` → `JobMapBounds` → the same four bounding-box fields. Three guards sit in front of the request and each one is load-bearing: a 500 ms debounce so a fast pan is one request; a containment check that skips the call when the new region is inside the last one **and** that result was not cropped; and a request token so a slow earlier response cannot overwrite newer pins. The map asks for `size: 100` (the server's `PageableSanitizer` ceiling) and, when the answer comes back `last: false`, says there are more jobs than fit rather than dropping pins silently. Markers are cached so an idle camera does not regenerate artwork that has not changed, and **the cache key is not the job id** — it is id + `addressPrecision` + coordinate, owned by `JobMarkerCache` (`home/presentation/widgets/`). The same job comes back with the same id but a rounded coordinate and an `APPROXIMATE` flag once an assignment ends, so an id-keyed cache kept the old **exact** pin on screen — that is the acceptance item "a cached full address is not shown after authorisation ends" (is-koala/koala#10) failing silently. The page holds a `JobMarkerCache`, never a `Map<String, Marker>` of its own; `test/employee/features/home/presentation/pages/explore_pages/map_explore_page_test.dart` drives the real page and goes red if the map keeps the exact pin.

  **What the map says out loud lives in `MapExploreOverlay`** (`home/presentation/widgets/`), not in the page's `Stack`. It alone decides which card sits on top — loading, error + *Tekrar Dene*, the crop warning, "no results", the search result list — and the page just positions it. The split exists because the overlay's decision is worth asserting on its own, and that gap is exactly how the original defect survived: the whole status card was drawn under `if (!isSearching)`, so a `500` arriving while the search bar was open showed the user *"Sonuç bulunamadı"* and no way to retry. Error and crop warning are **not** search-conditional; the crop warning stacks **above** the result list rather than replacing it.

  > **The page *can* be widget-tested, and it is** — this file used to say it could not. `GoogleMap` pumps fine in `flutter test`; what it does not do is create a platform view, so `onMapCreated` never fires and `_mapController` stays null. Everything else works: `MapExplorePage` takes a `controller`, the two device plugins are answered with `setMockMethodCallHandler` (`flutter.baseflow.com/permissions/methods` and `.../geolocator` — leave them unanswered and the loading spinner turns forever, so `pumpAndSettle` never returns), the camera box is fed by calling `MapExploreController.onCameraIdle` directly, and the pins are read off the `GoogleMap` widget's own `markers` / `circles`. One real trap: the pin artwork is loaded from an SVG asset and encoded to PNG on the **real** event loop, which the test's fake clock does not advance — warm it once inside `tester.runAsync` (`JobMarkerGenerator` caches icons statically) or the first assertion sees an empty marker set.
- Sessions are no longer faked: `SessionManager` writes `is_logged_in` / `user_type` **and** the tokens together. Do not write those prefs keys by hand; a flag without a token is a user who looks logged in and gets 401s.

> A service class is named after its file: `job_service.dart` → `JobService`. There is no `*Repository` naming in the codebase.

When you add anything data-shaped, keep it behind the existing repository classes so the swap to a real API stays a one-file change.

### Secrets

The Google Maps key is **not** in the repo. Flavor builds read it from:

- Android: `MAPS_API_KEY_DEV`, `MAPS_API_KEY_STAGING` or `MAPS_API_KEY_PRODUCTION` in `android/local.properties`. Staging and production may instead receive their matching `KOALA_ANDROID_MAPS_API_KEY_*` environment variable in CI.
- iOS: `MAPS_API_KEY` inside `ios/Flutter/Secrets.dev.xcconfig`, `Secrets.staging.xcconfig` or `Secrets.production.xcconfig`; each flavor configuration includes only its matching file.

These files are gitignored, as is `.env`. Never print a key value into an answer, a comment or a committed file.

### Platform toolchain

The native side sits at Flutter 3.47.1's own baseline; **the plugins pin most of it, so do not lower any of these**.

**Android** (`android/settings.gradle.kts`, `gradle/wrapper/`, `app/build.gradle.kts`) — Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0, Java 17. Below AGP 8.11.1 / Gradle 8.14 / KGP 2.2.20 the Flutter Gradle plugin fails the build outright, so this is a floor, not a preference.

- The base **application id** is `com.iskoala.koala`; dev and staging append `.dev` and `.staging`, while production keeps the base id. The Gradle **namespace** is the distinct, still-default `com.example.koala`. Do not report the namespace as the installed app's identity, and do not change it as part of an application-id task.
- `compileSdk = 37` is **hardcoded on purpose**: `permission_handler_android` 14 compiles against 37 while `flutter.compileSdkVersion` is still 36. Do not "restore" it to the Flutter default.
- Kotlin comes from the **Kotlin Gradle plugin**, not AGP's built-in Kotlin: `android.builtInKotlin=false` and `app/build.gradle.kts` applies `kotlin-android`. This reverses an earlier decision and the reason is written in `android/gradle.properties`: `flutter_nfc_kit` — the NFC transport the identity-card chip read depends on — still applies `kotlin-android` in every published version, and with built-in Kotlin on, any module that does fails the build outright. **Do not set the flag back to `true` until `flutter_nfc_kit` migrates**; the flag and the plugin line move together. The jvmTarget stays in the top-level `kotlin { compilerOptions { … } }` block, which is valid under KGP too. `settings.gradle.kts` still declares the KGP version because the plugin modules resolve it from there — leave it.
- `android.newDsl=false` is still set; that migration has not happened yet.

**iOS** — deployment target 15.5. Dependencies are a **hybrid**: `app_links`, `geolocator_apple`, `package_info_plus`, `permission_handler_apple` and `shared_preferences_foundation` come through **Swift Package Manager** (on by default in Flutter 3.47), and CocoaPods is still there for one reason only — `google_maps_flutter_ios` ships no `Package.swift`. `ios/Podfile` exists solely for it and can be deleted outright the day that plugin adopts SPM. The build prints a "does not support Swift Package Manager" warning about it every time; that is expected, not something to fix.

- The app uses the **UIScene lifecycle**. Plugins are registered in `didInitializeImplicitFlutterEngine`, *not* in `didFinishLaunchingWithOptions` — putting them back would break plugin registration. `Info.plist` carries the matching `UIApplicationSceneManifest`, pointing at Flutter's own `FlutterSceneDelegate` (there is no `SceneDelegate.swift`, and adding one means editing `project.pbxproj`).
- `GMSServices.provideAPIKey` stays in `didFinishLaunchingWithOptions`: it is an app-level service, unrelated to the engine.

---

## Theme and color

The app defines a light and a dark theme. Colors are split across **two sources** and mixing them silently breaks one of the two themes.

**Colors that change with the theme are read from `context`** (`product/extensions/context_extensions.dart`):

`backgroundColor` · `tileColor` · `elevatedColor` · `textPrimary` · `textSecondary` · `textTertiary` · `dividerColor` · `accentColor` · `onAccentColor`

**Theme-independent colors stay in `AppColors`:** the brand green (`primaryColor`), status colors, content on a saturated surface (`onAccent`), and content on a surface that is light in *both* themes (`onLightSurface` — the auth screen's map backdrop).

> **Surfaces that swap direction.** In the light theme a page can be grey with white cards on it; in the dark theme the page is the darkest tone and cards sit *above* it. That is the one case a single `ColorScheme` role cannot express, so it is handled by two accessors: **`context.recessedColor`** (the page) and **`context.raisedColor`** (a card on it). Use them together or not at all — the explore list is the screen that needs them. `context.isDarkTheme` exists for the same reason; reach for it only when the two themes genuinely disagree about direction, never to pick a color that the scheme already handles.
>
> The tinted status sections on *İşlerim* work the same way: `context.pendingSurface` and `context.payoutSurface` each have a light and a dark value.

```dart
// ❌ breaks in one of the two themes
color: Colors.white
color: Colors.grey[600]
color: AppColors.darkTextPrimary

// ✅
color: context.backgroundColor
color: context.textSecondary
color: AppColors.primaryColor   // brand color
```

The `dark*` / `light*` constants inside `AppColors` **only** feed the `ColorScheme`s in `theme.dart`; they are not used directly in widgets.

A color coming from `context` is not a compile-time constant, so that widget cannot be `const` — remove the `const`. This is the compile error you will hit most often while refactoring.

Typography comes from the theme too: `fontFamily: 'Poppins'` is set **once** in `theme.dart` and applies to every scale. Do not repeat it in a `TextStyle`, and prefer `context.textTheme.titleMedium` over a hard-coded `fontSize`.

The typography scale is defined in `theme.dart` (`_textTheme`) from the sizes the app actually uses, not Material's defaults. Reach for a slot (`titleMedium`, `bodySmall` ...) instead of a `fontSize:`; the table in that file says which slot is which size.

> The whole codebase has been converted to this system — there are no hard-coded colors, paddings, radii or font sizes left outside the constant files. A `Colors.white` or a bare `fontSize:` appearing in a diff is a regression, not the existing style.

Empty lists go through **`EmptyState`** (`product/widgets/`), which owns the icon size and the vertical position. Each tab used to build its own, and they sat at visibly different heights — switching tabs made the content jump. It is a `ListView`, so a wrapping `RefreshIndicator` still works on an empty screen.

> An empty list and a failed load must not look the same. Every list screen distinguishes three states: loading, error (message + *Tekrar Dene*), and genuinely empty. The explore list goes further and separates "no jobs at all" from "nothing matched this filter" — telling a user their filter is too narrow when the database is simply empty sends them chasing the wrong thing.

Bottom sheets go through **`AppBottomSheet`** (`product/widgets/`), which owns the background, the top corners, the title row and the bottom safe-area inset. If the sheet has its own state, wrap `AppBottomSheet` in a `StatefulBuilder` inside the builder — the shell itself is stateless. A switch inside a sheet goes through **`SheetSwitchRow`** (`product/widgets/`).

Confirmations go through **`ConfirmDialog`** (`product/widgets/`): title, message, an action label that names the verb, and `isDestructive` (default `true`) for the red button. It returns `bool?`, so callers test `!= true` and treat "cancelled" and "dismissed" alike.

> ⚠️ **Do not put a `ListTile` inside `AppBottomSheet`.** The shell's background is a `DecoratedBox` and `ListTile` paints its own background and ink splashes onto the nearest `Material` **above** that box, so both are hidden; Flutter reports it at runtime as *"ListTile background color or ink splashes may be invisible"*. Every tappable row in this codebase is `Material` + `InkWell` + `Padding` for exactly this reason — see `MyListTile`, `ThemeModeSheet._option` and `OptionSheet._option`, and copy one of them. `test/product/widgets/option_sheet_test.dart` fails if a `ListTile` comes back.
>
> **This catches the widgets that build a `ListTile` for you, too** — and that is the version that actually shipped twice. `SwitchListTile`, `CheckboxListTile` and `RadioListTile` all construct a `ListTile` internally, so the assertion fires with no `ListTile` anywhere in the file and `grep ListTile` finds nothing. Use **`SheetSwitchRow`** (`product/widgets/`) for a switch in a sheet; it keeps the tap-the-label behaviour that `SwitchListTile` gave for free. And do not "fix" this by wrapping `AppBottomSheet`'s content in a transparent `Material` — that silences the assertion by overriding the convention this whole section exists to enforce.

Single-choice lists go through **`OptionSheet`** (`product/widgets/`): a generic sheet driven by a label getter, with optional per-item icon and colour. It used to be `BOptionSheet` under `business/`; the employee explore filter picks its province and district with the same sheet now, and `b_` means "employer side only". The matching field on the employer side is **`BSelectionField`**, which wears `MyTextfield`'s frame so a "tap to choose" field and a typed field sit on the same grid. Job category, country, province and district all use the pair — the category used to be a chip row, but the list comes from the server and can grow.

The pills inside a filter sheet go through **`FilterPill`** (`product/widgets/`). It is not called `FilterChip` because Flutter owns that name. Explore's filter sheet, its sort sheet and the active-filter summary in the bar all draw the same pill; `onRemove` adds the cross that clears one field.

> ⚠️ **Two footguns that cost compile errors and silent bugs:**
> - `context.size` is **not** the `SizeExtension` getter — `BuildContext` has its own nullable `size`, and the instance member wins. Use `MediaQuery.sizeOf(context)`. `context.width` / `context.height` are fine.
> - Every `textTheme` slot carries a color. On a colored surface (a green button, a tinted card) you must pass the foreground explicitly with `copyWith(color: ...)`, or set `textStyle:` in the button's `styleFrom` and let `foregroundColor` win. `copyWith(color: null)` does **not** clear a color.

---

## Icons

UI icons come from **`reicon_flutter`**, and pages never touch the package directly. Two pieces stand between them:

- **`AppIcons`** (`product/constants/app_icons.dart`) is the catalogue — a name per icon, `static const String home = 'home';`. Nothing outside it may invent a name.
- **`AppIcon`** (`product/widgets/app_icon.dart`) is the widget that draws one: `AppIcon(AppIcons.home)`, with optional `size`, `color` and `filled`.

Map pins are separate and unchanged: **`flutter_svg`** over `assets/map_pins/`, through `employee/features/home/presentation/widgets/job_marker_generator.dart`.

Material **`Icons`** still appears in older files. Do not add new ones; when you touch such a file, moving it to `AppIcon` is welcome but not mandatory.

> ⚠️ **A Reicon icon is not an `IconData`.** It is raw SVG path data resolved by name, so it does **not** go into `Icon(...)`, `IconButton(icon: Icon(...))` or any other `IconData` slot. Use `AppIcon`.
>
> ```dart
> // ❌ derlenmez
> Icon(AppIcons.arrowLeft, size: AppSizes.icon)
>
> // ✅
> AppIcon(AppIcons.arrowLeft, color: context.textPrimary)
> ```
>
> When you need to **type** one — a widget field, a helper parameter, an enum getter — use **`AppIconData`** from `product/constants/app_icon_data.dart`. It is a `typedef` for `String`, and it exists so that swapping the icon package again touches `AppIcon` and the catalogue rather than every page. Helpers that still carry a Material `Icons.` value keep `IconData`; the two are not interchangeable.

**Adding an icon means adding a name, and the name must exist in the package.** `AppIcon` resolves it at build time against `Reicon.outline` / `Reicon.filled`; an unknown name trips an `assert` in debug and draws an empty box in release. Check with `Reicon.outline.names` before adding to `AppIcons`, and `test/support/finders.dart`'s `findAppIcon` lets a test pin the name.

**Filled icons exist**: `AppIcon(AppIcons.home, filled: true)` resolves `Reicon.filled`. Colour follows the surrounding `IconTheme` when `color` is omitted, falling back to `context.textPrimary`; size defaults to `AppSizes.icon`.


> **`cupertino_icons` looks unused — do not remove it.** No file imports it. It is there because go_router 18 renders iOS page chrome through `cupertino_ui`, which draws `CupertinoIcons.back` from that font. Without the package the build warns about a missing font family and the glyph renders as an empty box. It costs 734 bytes in a release APK (the font is tree-shaken from 257 KB down to 848 bytes), and it cannot be replaced through the app's `AppIcon`/Reicon catalogue because `cupertino_ui` hardcodes its own font.

---

## The shells

**Employee (`employee/features/home/presentation/pages/shell_page.dart`)** — a floating navbar over a `PageView`. Two tabs have a second behaviour when you tap them while already selected: **Explore** toggles map ↔ list, **Jobs** toggles its own sub-view. That toggle lives in `PageProvider`, not in the page. Below the navbar there is a fade gradient drawn in a `Positioned`/`IgnorePointer`.

**Business (`business/core/b_shell_page.dart`)** — a solid navbar filled with `AppColors.primaryColor`, five `BNavItem`s in a `Row`, and the bottom safe-area inset added as padding.

Both shells use `extendBody: true` and `extendBodyBehindAppBar: true`, so page content runs under the bars. Lists need bottom padding of their own or the last item hides behind the navbar.

---

## The worker lifecycle (sign-up → first application)

This is the product pipeline and how much of it the server actually enforces today. A ✗ marks something the server does **not** do yet; where a change has been requested from the backend developer, it says so — do not code against the requested shape until it lands.

> **Read this first.** NVİ closed the KPS service, and the backend has since removed it entirely — `core/utilities/kps/` is gone and nothing references it (verified against commit `a10856c`). Verification succeeds again, so the apply chain is not broken.
>
> **What replaced it is built but not switched on yet, deliberately.** Chip verification shipped behind `IDENTITY_PASSIVE_AUTH_ENABLED`, which defaults to `false` — the backend developer left it off on purpose, because turning it on before any client sends chip evidence would lock everyone out. With the flag off, `verifyChipEvidence` returns immediately and the server writes what the request contains, so a hand-typed TCKN becomes `identityVerified`; uniqueness (`TC_IDENTITY_NUMBER_ALREADY_IN_USE`, `409`) is the only guard in the meantime. Both sides know this and the flag flips once the app sends `sod`/`dg1`.
>
> **The NFC client and live MRZ capture are implemented.** The identity-chip page reads the TCKK back through a framed live camera stream, requires a stable valid TD1 result, then opens the NFC session. The server flag `IDENTITY_PASSIVE_AUTH_ENABLED` still defaults to `false`; enabling that production gate remains a separate cutover decision after real-device evidence is accepted.
>
> **Once the chip is read, the form is the chip.** `IdentityChipResult.parse` is the only way to build a chip result, and it derives a `ChipHolder` — name, surname, TCKN, birth date, document number — from the very base64 `dg1`/`dg11` strings that go into the request (name from DG11 when present, otherwise DG1's ASCII form **as is**; never "unfolded" by guessing). The form's declaration is a sealed `IdentityDeclaration`: `ManualDeclaration` reads the text fields, `ChipDeclaration` has no field inputs at all and reads the holder, so a declaration that disagrees with the evidence cannot be compiled, let alone typed (is-koala/koala#136). All five fields render read-only from the holder; the **only** way back to editing is dropping `chip` — the user's *Okumayı Kaldır* on the card, or the server rejecting the evidence with `IDENTITY_CHALLENGE_INVALID` (a spent challenge makes the signed evidence unacceptable for good, so the page clears it and the toast says to read the card again; no other `IDENTITY_*` code does this) — and evidence and derived values are one object, so there is no state where one survives the other. `test/employee/features/settings/presentation/pages/identity_verification_page_test.dart` pins the request body to what the screen shows.

1. **Sign-up is deliberately thin.** `POST /auth/start-registration` takes only `firstName`, `lastName`, `email`, `isEmployer`. The emailed token goes to `POST /auth/verify-registration-token`, then `POST /auth/complete-registration` sets the password and records the legal consents. No identity, no address, no IBAN. ✓
2. **Browsing needs no account at all.** `GET /jobs`, `GET /jobs/{jobId}` and the job/company image endpoints are `permitAll` in `SecurityConfig`, so search works before login. Nothing about discovery has to sit behind sign-up. ✓
3. **Completeness prompts are a client-side computation.** `GET /users/me` returns `jobTitle`, `about`, `qualifications`, `interests`, `experiences`, `educations`, `badges`, `address`, `maskedIban`, `cvUrl`, `phoneVerified` and `identityVerified` — everything a "complete your profile" meter needs. There is no server-side profile score and none is required. ✓ *(no UI for this yet)*
4. **The gate is at apply time, not at sign-up.** `JobApplicationManager.assertReadyToWork` runs on every application and checks, in this order: identity → address → primary IBAN. It is modelled in `employee/features/jobs/models/application_readiness.dart`; each condition carries its own `errorCode`, so the app routes straight to the screen that fixes it instead of matching on message text. ✓ **This is deliberate and stays as it is** — identity is required for *every* application, insured or not. It was considered and rejected to tier the gate by `insuranceRequired`; do not "simplify" it back out.
5. **The three requirements are filled from three different places.** Identity: `POST /users/me/identity-verification`. Address: `PUT /users/me/address`. IBAN: the `iban` field of `PATCH /users/me` — there is **no** separate bank-account endpoint, and `maskedIban` is the only way it comes back. ✓
6. **Verification freezes the name.** After it succeeds, `PATCH /users/me` rejects `firstName`, `lastName` and `birthdate` with `IDENTITY_VERIFIED_CANNOT_CHANGE_*`. Gender is deliberately *not* frozen — that check is commented out server-side. ✓

### Identity verification now happens on the device

KPS is gone, so there is no server-side authority left to ask. Verification moves into the app as three layers, and the server's job shrinks to recording the result:

1. **NFC + OCR** — the card's chip is read over ICAO 9303 (BAC/PACE secure channel, then DG1). This is what establishes that the card is genuine. Name, surname, birth date, TCKN and document number all come off the chip, so the user types nothing.
2. **Face match** — the card belongs to the person holding it.
3. **Liveness** — the person is live, not a photo or a video.

This is *more* than KPS did: KPS only answered "are these five fields consistent", it never knew who was holding the card.

**The server verifies layer 1's evidence.** It chains the SOD signature up to a CSCA root, compares DG hashes, and matches the TCKN, birth date and name against the MRZ. It also closes the replay hole, which is worth understanding: `sod` and `dg1` are *constant for a given card*, so anyone who reads them once could resend them forever. Active Authentication fixes that — the server issues a single-use challenge, the chip signs it with a private key that never leaves the chip. Two consequences for us:

- **Order matters.** Fetch the challenge from `POST /users/me/identity-verification/challenge` *before* opening the card session — it is what gets signed. Valid for 10 minutes, single use.
- **We must send `INTERNAL AUTHENTICATE`,** not just read data groups. Whichever NFC library we pick has to support it. If the card has no `DG15`, the step is skipped and the flow still works.

Data groups: `SOD` and `DG1` are required; `DG15` (chip public key) and `DG11` should be sent when present; `DG2` is deliberately **not** sent — face matching stays on the device. `DG11` matters more than it looks: the MRZ is folded to ASCII, so a card reading **ÇAĞRI** carries **CAGRI** in `DG1`, truncated at 30 characters. Taking the name from `DG1` would corrupt it. `DG11` is hashed in the SOD too, so it is no less trustworthy — just correct.

#### Android Latin OCR modeli Play Services üzerinden gelir

`google_mlkit_text_recognition 0.17.1` Latin modelini
`com.google.mlkit:text-recognition:16.0.1` ile APK'ya gömüyor. Koala Android'de
yalnız bu modülü Gradle dependency substitution ile
`com.google.android.gms:play-services-mlkit-text-recognition:19.0.1` sürümüne
çevirir; diğer alfabe modüllerine dokunmaz. `AndroidManifest.xml` içindeki
`com.google.mlkit.vision.DEPENDENCIES=ocr` metadata'sı modelin kurulum sırasında
hazırlanmasını ister.

Karar tahmine değil aynı production all-ABI release build'lerinin ölçümüne
dayanır: paketli APK **130.210.232 bayt**, Play Services varyantı
**99.325.146 bayt**; kazanç **30.885.086 bayt (%23,72)**. Google Play hedefi
için bu kazanç, Play Services bulunmayan ya da modeli çevrimdışı indiremeyen
Android cihazlarda MRZ'nin elle girilmesi karşılığında kabul edildi. Kimlik
ekranı ilk taramada internet gerekebileceğini önceden söyler; ML Kit çağrısı
30 saniyede tamamlanmazsa kullanıcıyı sonsuz yüklemede bırakmaz ve açıkça elle
girişe yönlendirir. Eklenti doğrudan paket seçimi sunarsa substitution
kaldırılıp resmi seçenek kullanılmalı. Ölçüm ve kaynaklar
`docs/research/ml-kit-unbundled-text-recognition.md` dosyasındadır.

Everything new is optional and both flags are off, so a request without the evidence still behaves the old way. Error codes all return `400` except `TC_IDENTITY_NUMBER_ALREADY_IN_USE`, which is `409`; `IDENTITY_CHALLENGE_INVALID` means fetch a fresh challenge and start over.

The trust boundary moves with it, and that is the part to keep in mind while building. Layers 1–3 defend against a user cheating with someone else's card or a photo — the common case, and they defend it well. They do **not** defend against someone repackaging the app, because that attacker skips the checks entirely and posts the result straight to the endpoint; the server sees no evidence either way. The fix is not to move all three layers server-side: sending layer 1's evidence (`sod` + `dg1`) is enough, because producing that signature requires physically touching a real chip. Face match and liveness stay on device. This has been requested; see `KIMLIK_DOGRULAMA_RAPORU.md` at the repo root for the whole analysis.

### Requested from the backend, not yet delivered

Do not build against these until the backend developer confirms they shipped.

- ✗ **Nothing forces an individual employer to verify** *(server side; the app now gates it itself)*. Creating a *company* requires `identityVerified` (`CompanyManager`), creating an individual job does not, and the escrow call sends `buyer.identityNumber = job.getCreator().getTcIdentityNumber()` with no guard. An unverified individual employer therefore gets an opaque Iyzico failure at the worst possible moment — right after they accept an applicant, with a worker on the other side who thinks they got the job. The worker side handles this properly (`WORKER_IDENTITY_NOT_VERIFIED`); the employer side has no equivalent. Requested at both points — job creation and payment — with a new `INDIVIDUAL_EMPLOYER_IDENTITY_NOT_VERIFIED` code. **The app gates it at job creation already**: `b_create_page` shows a warning strip and `_createJob` refuses with a dialog that routes to `/identity-verification`. Company jobs are exempt — founding a company already required verification, and the İyzico buyer identity there is the company's tax number.
- ✗ **`/users/me` returns `tcIdentityNumber` unmasked** while the IBAN comes back as `maskedIban`. Masking has been requested; the app only ever needs to know whether it is set, so do not build anything that depends on the full value.

> Delivered since: TCKN uniqueness now exists as `TC_IDENTITY_NUMBER_ALREADY_IN_USE` (`409`).

### Things that are true regardless

- **"SGK-required" is `insuranceRequired`**, derived from `JobCategory.requiresInsurance`. Individual employers are hard-blocked from those categories (`INDIVIDUAL_JOB_CANNOT_REQUIRE_INSURANCE`), so insurance jobs are company jobs by definition.
- **Badges are not a ranking.** `BadgeRuleType` has only `COMPLETED_ASSIGNMENTS`, `AVERAGE_RATING_WITH_MINIMUM_REVIEWS` and `IDENTITY_VERIFIED`, and nothing sorts applicants by how full their profile is. "Adding experience improves your chances" is honest as *the employer sees more of you*, never as a percentage — do not write copy that implies an algorithm.

---

## State of the world you should know

**There are no demo-login shortcuts in the runtime UI.** A logged-in state is created only from backend-issued access and refresh tokens; role selection alone never opens a session.

**Wired and working:**

- Both settings pages expose account/company editing, sessions, **Görünüm**, **Hesabı Sil** and logout. Account deletion asks for explicit destructive confirmation, posts the optional reason through `LegalService`, and shows the queued state without pretending anonymization is immediate. Read `docs/release.md` when changing version/tag, signing, store upload or `APP_MINIMUM_VERSION`; read `docs/store-privacy-inventory.md` when a data flow or SDK changes.
- The theme picker: Settings → **Görünüm** opens `ThemeModeSheet` (system / light / dark), applied immediately and persisted. The default is `ThemeMode.system`, so the app follows the device.

**Notifications are live in both apps.** `GET /users/me/notifications` returns a page plus an `unreadCount`, and `POST /users/me/notifications/read` marks everything read. The whole thing is shared: `product/models/app_notification.dart`, `product/services/notification_service.dart`, `product/providers/notification_provider.dart`, and `product/widgets/notification_view.dart` — the two pages are just a `Scaffold` and an app bar around the same body. `NotificationBell` (also shared) is the entry point, and there is **one per app**: the worker's *İşlerim* app bar and the employer's home header. It briefly sat on the worker profile as well — two bells for one screen is clutter, and the profile app bar already carries two other actions. Keep these rules together when touching it:

- **`unreadCount` is not derived from the page.** The server counts separately, so the badge can be non-zero while the first page shows nothing unread. Never compute it from the list.
- **`NotificationProvider` keeps two flags on purpose.** `_isFetching` says a first-page request is in flight; `_isLoading` only says whether to draw the spinner. Folding them into one left the silent path (`load(silent: true)`, which the bell uses) unguarded, so the bell's fetch and the screen's could rebuild the list at the same time.
- **`isRead` comes from `readAt`, not `status`.** `OPENED` is the dispatch pipeline's state, not the user's.
- **The feed is the `IN_APP` channel only.** The server writes an e-mail and a push record for the same event, but the list, the unread count and mark-all-read are all scoped to `IN_APP`, so one event is one row. Do not add client-side channel filtering on top.
- **Tapping a row marks it read and goes to the target's *list*, not the record.** `targetType`/`targetId` name the record, but no screen in this app opens by id — `/chat-detail` wants a `Conversation`, the job sheet wants a `Job`. So an assignment sends the user to *İşlerim* (`/business/posts` for an employer), a conversation to the chat list, a user to the profile. Deliberate: the lists are short and grouped, and id-based routes were more work than the landing accuracy was worth. A notification with no target is not tappable at all — a row that does nothing when pressed reads as broken.
- **The bell shows the count, not a dot.** It can, now that the feed is one row per event; before the `IN_APP` channel existed the number would have been inflated. Over `99` it reads `99+`.
- **`markRead` updates the list in place, `markAllRead` refetches.** The first happens while the user is walking away from the screen, so a reload would only make them wait; the second changes every row anyway. A failed `markRead` leaves the row unread — showing an unread item as read is the wrong direction to fail in.
- **Android push is FCM.** `Firebase.initializeApp` runs in `SplashPage._initialize`, never in `main`. Init failure logs and leaves push off. The production token source is `FirebaseMessagingPushTokenSource`; tests keep `FakePushTokenSource`. Permission is **not** asked at launch — `NotificationView` asks on first inbox open via `FirebaseMessaging.requestPermission`, not `permission_handler`. Denied or not-yet-asked status yields no token (`isPushDeliveryAllowed`); a later denial also `clearQuietly`. Foreground `onMessage` refreshes the feed and does not draw a local notification. A tap (`onMessageOpenedApp` / `getInitialMessage`) opens `/notifications` or `/business/notifications` and marks `data.notificationId` read. The same id is ignored for seven days (`PushNotificationDedupe`). iOS APNs is out of this wiring.

**Sessions are live in both apps.** `GET /users/me/sessions` lists the devices logged into the account, `DELETE /users/me/sessions/{id}` closes one and `DELETE /users/me/sessions` closes every one *except the caller's*, returning how many it closed. Everything shared sits in `product/`: `models/user_session.dart`, `services/session_service.dart` and `widgets/session_view.dart`. The two pages (`/sessions`, `/business/sessions`) are a `Scaffold` and an app bar around that view — the same arrangement notifications use. "Diğer Cihazlardan Çık" lives inside the view rather than the app bar, because the state it depends on is there. Do not confuse `UserSession` with `WorkSession`: one is a login, the other is a shift.

The server marks the calling session with `current`. That row gets a "Bu cihaz" badge and **no close button** — closing your own session is logging out, and that already has a row in Settings which also clears the local providers and the realtime connection. Revoking never edits the list in place; it refetches, because closing one session can drop others.

**The profile is fully wired, including the CV.** Education is the newest piece: `/users/me/educations` CRUD through `profile/services/education_service.dart`, with the university → faculty → department chain coming from `product/services/academic_reference_service.dart` (`/reference/universities`, `.../{id}/faculties`, `/reference/faculties/{id}/departments`). Those three endpoints need no auth and their lists barely change, so the service caches them per parent id for the session. Things worth knowing before editing that form:

- **The three pickers are a chain, not three independent fields.** Changing the university clears the faculty *and* the department; changing the faculty clears the department. Leaving a stale child selected would post another school's faculty id.
- **A long list needs search, not a dropdown.** There are 200+ universities, so `AcademicPickerSheet` is a searchable sheet whose filter folds Turkish characters — typing "bogazici" has to find "Boğaziçi".
- `gpa` is a non-nullable `double` server-side, so "not given" travels as `0`, and the profile hides the figure when it is `0` — rendering "0.00" would read as a bad grade.

`ExperienceCard` became **`TimelineCard`** when education reused it; the parameters are neutral now (`subtitle`, `subtitleIcon`) because the same row renders a company for experience and a school for education.

`qualifications` and `interests` are editable in *Hesabı Düzenle* and shown on the profile — but only when filled, unlike *Hakkımda* which always draws with a placeholder. Three empty headings in a row read as an unfinished profile.

**CV upload** uses `file_picker` for document selection. `PUT /users/me/cv` sends multipart with the form field name **`file`** (not `image`), and `DELETE /users/me/cv` removes it. Upload and removal state stays in `UserProvider` so the card always reflects the server response.

**Experience editing** uses `POST|PUT|DELETE /users/me/experiences`; the *Tecrübe* section supports add, edit and delete.

**Worker availability is a weekly replacement, not a per-day patch.** The shared models and `AvailabilityService` live in `product/` because both employee and business profiles consume them; `AvailabilityProvider` owns the employee's seven-day editing draft. Every save sends all slots to `PUT /users/me/availability`, so a day editor must never issue its own request. Date exceptions use their separate PUT/DELETE endpoints. The shared read-only `AvailabilityView` appears on both the worker's own profile and an employer's candidate profile, where an empty schedule says “Müsaitlik bilgisi paylaşılmamış.”

**Followed companies** live at `/followed-companies` (paged), reached from the profile app bar. `FollowedCompanyDto` is a trimmed summary whose id field is `companyId`, not `id`, so it has its own model rather than reusing `Company`. You cannot unfollow from that list on purpose — unfollowing belongs to the company screen, and two sources of truth for one flag invites drift.

**Client version gate.** Every request carries `X-App-Version` (`ApiConfig.appVersionHeader`) sourced from `AppInfo.version`. The server's `MinimumAppVersionFilter` compares it and answers `426` with `errorCode: UPGRADE_REQUIRED`, mapped to `ApiErrorType.upgradeRequired`. Two traps: the filter **passes any request that omits the header**, so dropping it silently disables forced updates entirely; and `AppInfo.version` is kept in sync with `pubspec.yaml` **by hand** — bump both together. Reading it from the package would need `package_info_plus` (present in `pubspec.lock` only via `geolocator_linux`, a platform we do not build), so it is a real new dependency and needs asking.

A `426` is handled **once, globally**: `ApiClient` closes `AppUpdateGate` and `MaterialApp.router`'s `builder` swaps the whole app for `UpdateRequiredView`. It is deliberately not a route — the gate can trip on any request from any screen, and there is nowhere to navigate back to. The gate is one-way; nothing reopens it, because the version cannot change while the app is running.

**The store button is per platform, and there is no fallback between the two stores.** `UpdateRequiredView.storeUriFor` reads `iosAppStoreId` on iOS and `androidPackageId` on Android; the platform whose own id is empty gets `null`, never the other store's link. The button is drawn from the same `Uri?` it opens rather than from a separate "do we have any id" flag — one value, so the two cannot drift apart. Where there is no link the screen keeps a line saying what to do instead (update from wherever the app was installed, and an address to write to): a missing button answers nothing on its own. `androidPackageId` is set (`com.iskoala.koala`, matching `applicationId` in `android/app/build.gradle.kts`, ADR-0006) while `iosAppStoreId` is still empty — Apple hands the numeric id out at registration — so today an iPhone user on the gate sees that line and no button. All four platform/id combinations are covered in `test/product/widgets/update_required_view_test.dart`, at both levels: the pure `storeUriFor` and the rendered screen, the latter under each `TargetPlatformVariant` and in both themes.

> ⚠️ **How that broke is worth more than the fix: nobody broke it.** The old code fell through to the Play Store URL whenever the iOS branch failed, and while **both** ids were empty that was correct — neither branch could produce a link, the button stayed hidden, and the comment above it (*"a button that goes nowhere is worse than no button"*) described a real decision. Filling in **only** the Android id, in `85e5f84`, a commit that never opened `update_required_view.dart`, turned the same fallback into a wrong link: iOS failed its own branch, fell into Android's, and an iPhone user who tripped the `426` gate was shown a working button to Google Play (`is-koala/koala#77`). No commit introduced the defect; a value added somewhere else invalidated code that was already right, and nothing anywhere reported the loss. **This is the shape defects take in this codebase.** When you fill in a constant, a flag or a config value that used to be empty, go and read every branch that tests it for emptiness — that is where the meaning just changed.

Supported iOS flavors have explicit bundle identifiers: `com.iskoala.koala.dev`, `com.iskoala.koala.staging` and `com.iskoala.koala`. `project.pbxproj` still contains legacy unflavored build configurations with `com.example.koala`; the supported flavor schemes do not use them. When adding a scheme or configuration, bind it to the matching explicit identifier instead of inheriting that legacy default.

**Known parked UI:**

- `business/features/home/presentation/pages/b_home_page.dart` has a `_quickActionsSection` that nothing calls. It carries an `// ignore: unused_element` so analyze stays clean — it is a parked section, not dead code to delete without asking.


**Onboarding** is shown once — `seen_onboarding`, owned by `SessionManager` and read by the redirect guard. `SplashPage` (`/`) is the app's single startup point: it reads the session, and the guard sends the user on from there. There is no `AuthGate` any more.

---

## Working habits

- Run `flutter analyze --no-pub` after every change and leave it clean. If the change touched `android/` or `ios/`, run the matching `flutter build` too — analyze does not see the native side.
- Run `flutter test --flavor staging --dart-define-from-file=config/staging.json` after every change to logic, and add a test with it. The bare command is red on purpose (see above). If a bug got through, the fix and the test that would have caught it belong in the same change.
- **Filling in a constant is a behaviour change.** A value that used to be empty is read by branches written for the empty case, and those branches change meaning without anyone editing them — see the store button under *Client version gate*. Grep for the constant, read every `isEmpty` / `isNotEmpty` on it, and leave a test pinned to the real value so the next fill-in is caught.
- When adding values to the constant files, give them meaningful names and a `///` comment saying *why* that value, not what it is.
- Before deleting anything, verify it is committed, and report what was deleted along with the command to undo it.
- When the user sends a screenshot, do not guess the problem; trace it from the code and explain the cause. Most layout problems come from constraints — a missing `Center`/`Expanded`/`stretch` and the like.
- When the task is done, give a summary and stop. Keep every commit focused, report its hash and leave merging as a separate release decision.
