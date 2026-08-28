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

**Never commit.** Do not run `git commit` or `git push`. When a task is done, summarize the changed files and stop; the user commits themselves. This is an absolute rule.

**Visual verification is done by the user.** They are the one who runs the app, sends screenshots and asks for fixes. A green `flutter analyze` plus a green `flutter build` mean "it compiles", never "it looks right" — do not conflate the two. If you made a visual change, say explicitly that you did not verify it on screen and point out what to look at.

**Do not add dependencies or invent new patterns.** Reuse what is already in `lib/product/constants` and `lib/product/widgets` first. If a value is missing from a constant file, add it there with a meaningful name instead of hard-coding it. The one kind of addition that does not need asking is a package an existing dependency already requires — `cupertino_icons` is in `pubspec.yaml` for exactly that reason; say so when you add one.

---

## Commands

```bash
flutter analyze --no-pub     # after every change; must stay clean
flutter test                 # after every change to logic
dart format lib test         # before handing the work over
flutter pub get
```

### Tests

`test/` mirrors `lib/`: a test for `lib/product/router/router_manager.dart` lives at `test/product/router/router_manager_test.dart`. Test names and `group` labels are Turkish like everything else.

What is covered today: the router redirect guard, the `Job` model's JSON round-trip, `asPrice`, the `SavedJobs` / `Page` / `Search` / `Apply` / `Theme` / `BJobs` providers, and `MyButton` / `MyListTile` as widget tests. There are **no integration tests** — everything runs headless, no device or emulator.

Two shared helpers under `test/support/`, use them instead of rolling your own:

- **`fixtures.dart`** → `buildJob(...)`. `Job` has eight required fields; passing only the one the test cares about keeps the test readable.
- **`pump.dart`** → `pumpInApp(tester, widget, brightness: ...)`. Product widgets read their colors from `context`, so they cannot be pumped bare — they need a `MaterialApp` with the real theme. The `brightness` parameter is there so a widget can be asserted in **both** themes, which is the project's core rule.

CI runs `flutter test` on every PR and blocks the Android and iOS build jobs behind it, so a red test stops the pipeline.

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

> ⚠️ **A fresh clone cannot build for iOS.** `ios/Flutter/Debug.xcconfig` and `Release.xcconfig` `#include "Secrets.xcconfig"` unconditionally, but that file is gitignored. Until the include is changed to the optional form (`#include?`), every new checkout — and CI — has to create the file first. The CI workflow writes an empty placeholder for exactly this reason.

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

Employee features: `auth`, `home` (explore), `jobs`, `chat`, `profile`, `company_detail`, `settings`.
Business features: `home`, `chat`.

A feature has at most three top-level folders: **`models/`** (plain data classes), **`services/`** (where the data comes from) and **`presentation/`**. There is no `data/` or `domain/` wrapper — a model sits directly under `models/`. `auth` and `settings` have no data of their own, so they only carry `presentation/`.

**Where does shared code go?** Used by both apps → `lib/product/`. Used by several features on one side only → that side's `core/`. Used by a single feature → that feature's own folder. Do not push employee-only code into `product/`.

> `auth` lives under `employee/` even though it serves both sides (registration asks whether you are a business). That is historical; do not move it without being asked, but be aware the business flow runs through employee files.

> The same applies to chat: `business/features/chat` imports `ChatAvatar`, `ChatAppBar`, `MessageBubble` and `MessageTextField` from `employee/features/chat/presentation/widgets/`, because the `Conversation` and `Message` models live on the employee side. Strictly the shared parts belong in `product/`, but moving them would drag the domain models along; the existing convention is to reuse the employee widgets.

### State management

`provider`. Eight `ChangeNotifierProvider`s are registered in `main.dart`:

| Provider | Responsibility |
|---|---|
| `ThemeProvider` | Light/dark/system theme, persisted in `SharedPreferences` |
| `PageProvider` | Employee shell: which tab, and the explore map/list toggle |
| `SavedJobsProvider` | Saved jobs |
| `ReviewProvider` | The review form state |
| `ApplyProvider` | The application form state |
| `SearchProvider` | The explore search query |
| `BPageProvider` | Business shell tab |
| `BJobsProvider` | Business job posts |

> ⚠️ **`BPageProvider` is registered twice.** `main.dart` creates a global one, and `business/core/b_shell_page.dart` creates a second one with its own `ChangeNotifierProvider`. Pages inside the shell read the shell's instance, anything outside reads the global one — writing to one does not move the other. If you touch business tab state, know which instance you are on.

### Routing

`go_router`. A single `GoRouter` inside `product/router/router_manager.dart`, `initialLocation: '/'` — the splash screen.

**The `redirect` guard** is **synchronous**. It reads the session off `SessionManager`, which caches the flags in memory once `SplashPage` has called `load()`, and enforces five rules: session not read yet → `/`; not logged in → `/onboarding` if the intro has not been seen, otherwise `/auth`; logged in but on an auth route (`/`, `/auth`, `/onboarding`) → the home of your type; business user on an employee route → `/business/home`; employee user on a business route → `/explore`.

> ⚠️ **Never make the guard `async` again.** An awaiting `redirect` makes go_router place the pushed page outside the frame, and every page transition outside the shell silently stops animating. That is also why `main()` stays synchronous and the session is read on the splash screen instead.

> ⚠️ **Every route must declare its own `pageBuilder`.** Left on `builder:`, go_router picks the page type by sniffing the app and — in this go_router/Flutter pair — falls through to `NoTransitionPage`, so the page opens with no animation and nothing warns you. Top-level routes go through `RouterManager._page` (a `MaterialPage`, i.e. the platform's own transition); the shell tabs keep theirs. `test/product/router/router_pages_test.dart` guards this.

The decision itself lives in `RouterManager.resolveRedirect(initialized:, loggedIn:, userType:, seenOnboarding:, location:)`, a pure static function — the `redirect` callback only feeds it what `SessionManager` already holds. Change the rules there and cover them in `test/product/router/router_manager_test.dart`; this is the one piece of logic that keeps the two apps apart.

> The guard is `async` and hits `SharedPreferences` on every route change. It works, but it means the redirect is not synchronous — do not assume the first frame of a route is already the final destination.

**Two `ShellRoute`s**, one per app:

- Business shell (`BShellPage`): `/business/home`, `/business/posts`, `/business/chat`, `/business/profile` — fade transitions.
- Employee shell (`ShellPage`): `/explore`, `/jobs`, `/chat`, `/profile` — no transition.

Everything else (`/apply`, `/review`, `/company-detail`, `/chat-detail`, `/settings`, `/business/create`, `/business/job-detail` ...) is **top level**, so it opens full screen above the navbar. If you add a page that must cover the navbar, put it at top level — a route nested inside the shell stays underneath it.

> ⚠️ **The employee `ShellPage` ignores go_router's `child`.** It keeps a static `PageView` of the four pages and only uses the matched location to pick an index (`didChangeDependencies`). So the route drives the index, not the content — the pages are constructed once and kept alive. Anything you expect to rebuild on navigation will not. `BShellPage` does the opposite: it renders `child` normally.

**Passing data between routes** is done with `state.extra` and an unchecked cast (`state.extra as Job`). Navigating to those routes without the right `extra` throws. There is no `pageKey`/`ValueKey` on them.

### Deep links

`app_links` listens in `app.dart`. A link carrying a `token` query parameter is routed to `/auth/register-type/register/creating-password?token=...` — this is the e-mail verification flow. The listener is registered in `initState` and is never cancelled.

### Backend

**Auth is wired to a real backend; everything else is still fake.** This is the single most important thing to know about this codebase.

The API is a Spring Boot service in a separate repository (`github.com/yustyy/koala`): layered `webAPI → business → dataAccess`, Postgres + Liquibase, RabbitMQ for mail/SMS/push, R2 for files, Iyzico for payments. Every response comes wrapped in the same envelope — `{success, message, httpStatus, path, timeStamp, correlationId, data}` — and errors add `errorCode` plus a `details` array of field errors. Messages are localized; the app sends `Accept-Language: tr`.

**The network layer lives in `lib/product/network/`** and is shared by both apps:

| File | Responsibility |
|---|---|
| `api_config.dart` | Base URL and timeouts. The URL defaults to `https://api.iskoala.com` and is overridden with `--dart-define=API_BASE_URL=...` (`http://10.0.2.2:8080` on the Android emulator). |
| `api_paths.dart` | Endpoint paths, plus the set of paths that need no token. |
| `api_client.dart` | The only place `dio` is touched: unwraps the envelope, turns `DioException` into `ApiException`. |
| `api_exception.dart` | `ApiException` / `ApiErrorType` — the single error type services and pages see. |
| `auth_interceptor.dart` | Attaches the bearer token, refreshes once on a 401 and retries. |
| `token_storage.dart` | Access/refresh tokens in Keychain/Keystore (`flutter_secure_storage`). |
| `session_manager.dart` | Opens and closes the session: tokens plus the `is_logged_in` / `user_type` flags the router reads. |
| `device_identity.dart` | The per-install id sent as `X-Device-Id`, and the descriptive `User-Agent`. The backend binds sessions to the device, so the id must survive app updates — it lives in `SharedPreferences` and is **not** cleared on logout. |
| `device_interceptor.dart` | Puts `X-Device-Id` on every request, signed in or not. |

Two feature services are on real endpoints: `auth_service.dart` (registration in three steps, login, logout, forgot/reset password, `/users/me`) and `legal_service.dart` (agreements, consents, account deletion) — both under `employee/features/auth/services/`, because registration is where consents are collected.

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

- **A conversation always belongs to a job**, opened with `POST /jobs/{jobId}/conversation` (the employer passes `?workerId=` to pick the applicant). There is still no company-level conversation, so the company detail page's message button explains that instead of navigating — `TODO(backend)` in `company_detail_pagemodel.dart`.
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

Two controllers own all of this, and **both apps share them**:

- **`ChatThreadController`** — one conversation: messages, sending, typing, read receipts.
- **`ChatListController`** — the list: conversations, the personal message queue, and one presence subscription per counterpart, kept in sync as the list changes.

The same message arrives on **two channels** — the conversation topic and `/user/queue/messages` — and the server sends the copy to *both* participants, so your own message comes back to you too (that is deliberate: it keeps a second device's list current). Dedupe by `message.id`, and never count your own message as unread.

> **The connection is optional.** If it cannot be established the app keeps working over REST — only updates stop being instant. Never let a realtime failure block a screen.

> ⚠️ **Read receipts do not reach the personal queue.** `conversationRead` publishes only to the conversation topic, so reading a chat on your phone does not clear the unread badge in your tablet's list. The server side is a one-line change if we ask for it.

**Still fake:**

**The employer's job flow is real too.** `business/features/home/services/employer_job_service.dart` owns it: `GET /users/me/jobs` (own posts, individual and company alike — the server filters by `creatorId`), `POST /users/me/jobs` / `POST /companies/{id}/jobs` (open a post), `POST /jobs/{jobId}/close`, `GET /jobs/{jobId}/applications` and `POST /job-applications/{id}/respond`. `BJobsProvider` merges the first and the fourth into one list; `b_job_detail_page` fetches the richer `GET /jobs/{id}` itself.

Four things worth knowing:

- **The list endpoint does not carry an applicant count**, so the provider fires one `GET /jobs/{id}/applications` per post in parallel — an N+1 it lives with. `BJobPost.applicantsLoaded` exists so the card says "Başvurular yükleniyor..." instead of "henüz başvuru yok" during that second pass. `TODO(backend)` asks for `applicationCount` on `JobSummaryDto`.
- **Individual and company posts differ by one field.** `CreateIndividualJobDto` has no `insuranceRequired`; `CreateJobRequest.toJson(forCompany:)` drops it, and the create screen hides the switch. Which endpoint is used comes from `CurrentUser.activeCompany` — the first **approved** membership.
- **There is no endpoint that deletes a job.** Close is all there is, so the "İlanı Sil" menu item explains that instead of acting (`TODO(backend)` in `b_posts_page.dart`).
- **Accepting an application does not close the job.** The server opens an assignment in `PENDING_CONFIRMATION` and waits for the worker; the post stays in "Aktif" until its `JobStatus` says otherwise. Active vs. past is decided by `JobStatus` (`OPEN`/`IN_PROGRESS` → active), never by a local flag.

> `JobApplicantDto` returns a `SafeUserDto`, which carries no `jobTitle` — the applicant's profession is parsed (`JobCreator.jobTitle`) but always `null` today, and every screen hides the line rather than fetching a profile per applicant. Same for the candidate profile screen's location and CV rows. Marked `TODO(backend)` at each site.

**Still fake:** everything except auth, the employee profile, the jobs flow (explore, apply, İşlerim, saved jobs), chat and the employer's job flow. Data comes from services that return hard-coded lists, one `services/` folder per feature: `employee/features/home/services/location_service.dart`, `company_detail/services/company_service.dart`, `jobs/services/review_service.dart`, `business/features/home/services/fake_business_company.dart` (the business profile and company-info screens). Avatars are generated URLs from `ui-avatars.com`.

> The orphaned fakes were deleted once the employer's job flow landed: `profile/services/fake_user.dart` and its `profile/models/user.dart`, `jobs/services/my_jobs_service.dart`, `business/features/chat/services/b_chat_service.dart`. `employee/features/profile/` and `business/features/chat/` are `presentation/` only now — a feature carries `models/` and `services/` only when it has data of its own.
- `GET /jobs` is ready to be wired: `JobSummaryDto` carries `latitude`/`longitude`, `GET /jobs/{jobId}` returns the richer `JobDetailDto` (description, duties, dress code, age range, full address, creator, company) and the search takes a bounding box (`minLatitude`/`maxLatitude`/`minLongitude`/`maxLongitude`). Only the category mapping is missing.
- Sessions are no longer faked: `SessionManager` writes `is_logged_in` / `user_type` **and** the tokens together. Do not write those prefs keys by hand; a flag without a token is a user who looks logged in and gets 401s.

> A service class is named after its file: `job_service.dart` → `JobService`. There is no `*Repository` naming in the codebase.

When you add anything data-shaped, keep it behind the existing repository classes so the swap to a real API stays a one-file change.

### Secrets

The Google Maps key is **not** in the repo. It is read from:

- Android: `MAPS_API_KEY` in `android/local.properties` (consumed in `android/app/build.gradle.kts`)
- iOS: `MAPS_API_KEY` in `ios/Flutter/Secrets.xcconfig` (read in `AppDelegate.swift`)

Both files are gitignored, as is `.env`. Never print a key value into an answer, a comment or a committed file.

### Platform toolchain

The native side sits at Flutter 3.47.1's own baseline; **the plugins pin most of it, so do not lower any of these**.

**Android** (`android/settings.gradle.kts`, `gradle/wrapper/`, `app/build.gradle.kts`) — Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0, Java 17. Below AGP 8.11.1 / Gradle 8.14 / KGP 2.2.20 the Flutter Gradle plugin fails the build outright, so this is a floor, not a preference.

- `compileSdk = 37` is **hardcoded on purpose**: `permission_handler_android` 14 compiles against 37 while `flutter.compileSdkVersion` is still 36. Do not "restore" it to the Flutter default.
- Kotlin comes from **AGP's built-in Kotlin** (`android.builtInKotlin=true`); `app/build.gradle.kts` deliberately does not apply `kotlin-android`, and the jvmTarget lives in a top-level `kotlin { compilerOptions { … } }` block, not in `kotlinOptions`. `settings.gradle.kts` still declares the KGP version because the plugin modules resolve it from there — leave it.
- `android.newDsl=false` is still set; that migration has not happened yet.

**iOS** — deployment target 15.0. Dependencies are a **hybrid**: `app_links`, `geolocator_apple`, `package_info_plus`, `permission_handler_apple` and `shared_preferences_foundation` come through **Swift Package Manager** (on by default in Flutter 3.47), and CocoaPods is still there for one reason only — `google_maps_flutter_ios` ships no `Package.swift`. `ios/Podfile` exists solely for it and can be deleted outright the day that plugin adopts SPM. The build prints a "does not support Swift Package Manager" warning about it every time; that is expected, not something to fix.

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

Bottom sheets go through **`AppBottomSheet`** (`product/widgets/`), which owns the background, the top corners, the title row and the bottom safe-area inset. If the sheet has its own state, wrap `AppBottomSheet` in a `StatefulBuilder` inside the builder — the shell itself is stateless.

> ⚠️ **Do not put a `ListTile` inside `AppBottomSheet`.** The shell's background is a `DecoratedBox` and `ListTile` paints its own background and ink splashes onto the nearest `Material` **above** that box, so both are hidden; Flutter reports it at runtime as *"ListTile background color or ink splashes may be invisible"*. Every tappable row in this codebase is `Material` + `InkWell` + `Padding` for exactly this reason — see `MyListTile`, `ThemeModeSheet._option` and `BOptionSheet._option`, and copy one of them. `test/business/.../b_option_sheet_test.dart` fails if a `ListTile` comes back.

Single-choice lists on the business side go through **`BOptionSheet`** (`business/features/home/presentation/widgets/`): a generic sheet driven by a label getter, with optional per-item icon and colour. The matching field is **`BSelectionField`**, which wears `MyTextfield`'s frame so a "tap to choose" field and a typed field sit on the same grid. Job category, country, province and district all use the pair — the category used to be a chip row, but the list comes from the server and can grow.

> ⚠️ **Two footguns that cost compile errors and silent bugs:**
> - `context.size` is **not** the `SizeExtension` getter — `BuildContext` has its own nullable `size`, and the instance member wins. Use `MediaQuery.sizeOf(context)`. `context.width` / `context.height` are fine.
> - Every `textTheme` slot carries a color. On a colored surface (a green button, a tinted card) you must pass the foreground explicitly with `copyWith(color: ...)`, or set `textStyle:` in the button's `styleFrom` and let `foregroundColor` win. `copyWith(color: null)` does **not** clear a color.

---

## Icons

Three sources, all already in use:

- **`hugeicons`** for UI icons — `HugeIcons.strokeRoundedArrowLeft01` and friends. This is the default; reach for it first.
- **`Icons`** (Material) still appears in older files. Do not add new ones; when you touch such a file, a Huge Icons equivalent is welcome but not mandatory.
- **`flutter_svg`** for the map pins in `assets/map_pins/`, drawn through `employee/features/home/presentation/widgets/job_marker_generator.dart`.

> ⚠️ **A Huge Icons icon is not an `IconData`.** Since hugeicons 1.x an icon is raw SVG path data, not a font glyph, so it does **not** go into `Icon(...)`, `IconButton(icon: Icon(...))` or any other `IconData` slot — that is a compile error, and it is the single most common mistake in this codebase.
>
> ```dart
> // ❌ derlenmez
> Icon(HugeIcons.strokeRoundedArrowLeft01, size: AppSizes.icon)
>
> // ✅
> HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, size: AppSizes.icon)
> ```
>
> The `HugeIcon` widget takes `icon`, `color`, `size` and `strokeWidth`. Two differences from `Icon` worth knowing: `size` defaults to a hard **24** instead of following the surrounding `IconTheme`, and every icon is rendered through `flutter_svg` rather than a font — so avoid putting a lot of them in one long scrolling list without checking the frame times.
>
> When you need to **type** one — a widget field, a helper parameter, an enum getter — use **`AppIconData`** from `product/constants/app_icon_data.dart`, never `IconData`. That is the project's alias for hugeicons' unreadable `List<List<dynamic>>`. `MyListTile`, `NavItem`, `BNavItem`, `JobCategory.icon` and `ThemeMode.icon` all use it. Helpers that carry a Material `Icons.` value keep `IconData` — the two are not interchangeable.

**Filled icons do not exist here.** The free hugeicons package ships stroke-rounded only; solid/duotone are behind their paid plan. If a design needs a filled icon, raise it rather than improvising.

> **`cupertino_icons` looks unused — do not remove it.** No file imports it. It is there because go_router 18 renders iOS page chrome through `cupertino_ui`, which draws `CupertinoIcons.back` from that font. Without the package the build warns about a missing font family and the glyph renders as an empty box. It costs 734 bytes in a release APK (the font is tree-shaken from 257 KB down to 848 bytes), and the icon cannot be swapped for a Huge Icons one because `cupertino_ui` hardcodes it.

---

## The shells

**Employee (`employee/features/home/presentation/pages/shell_page.dart`)** — a floating navbar over a `PageView`. Two tabs have a second behaviour when you tap them while already selected: **Explore** toggles map ↔ list, **Jobs** toggles its own sub-view. That toggle lives in `PageProvider`, not in the page. Below the navbar there is a fade gradient drawn in a `Positioned`/`IgnorePointer`.

**Business (`business/core/b_shell_page.dart`)** — a solid navbar filled with `AppColors.primaryColor`, four `BNavItem`s in a `Row`, and the bottom safe-area inset added as padding.

Both shells use `extendBody: true` and `extendBodyBehindAppBar: true`, so page content runs under the bars. Lists need bottom padding of their own or the last item hides behind the navbar.

---

## State of the world you should know

**Demo shortcuts wired into the UI** — these fake a login and must come out when the backend lands:

- `login_page.dart` has an "İş Veren Arayüzünü Gör (Demo)" text button that writes `user_type: business` and jumps to `/business/home`.
- `email_verification_pending_page.dart` has the same shortcut for both types.

Every place that needs the real backend is marked with a `// TODO(backend):` comment — `grep -rn "TODO(backend)" lib` is the shortest route to the list.

**Wired and working:**

- Both settings pages carry three real rows: edit account / company info, **Görünüm** and logout (which just clears `is_logged_in` / `user_type`). Nothing there is a placeholder.
- The theme picker: Settings → **Görünüm** opens `ThemeModeSheet` (system / light / dark), applied immediately and persisted. The default is `ThemeMode.system`, so the app follows the device.

**Not wired up:**

- `business/features/home/presentation/pages/b_home_page.dart` has a `_quickActionsSection` that nothing calls. It carries an `// ignore: unused_element` so analyze stays clean — it is a parked section, not dead code to delete without asking.
- The stat numbers on the business profile, the applicant CV download and the "follow company" action all render but write nowhere.
- **Two states the server has and the UI cannot express.** Not a backend gap — the data arrives, the design has nowhere to put it:
  - **Rejected application.** `ApplicationStatus.REJECTED` comes back with a `rejectionReason`, but `MyJobStatus` only knows pending / approved / awaiting-payment / done. A rejected application currently renders as **pending**, so the worker never learns they were turned down. Needs a new status in the design before it can be mapped.
  - **Cancelled assignment.** `AssignmentStatus.CANCELLED` (and `REJECTED`) have the same problem.

  Both are marked `TODO(backend)` at the mapping sites even though the fix is a design decision, so `grep -rn "TODO(backend)" lib` surfaces them together with the rest.
- **Server endpoints the profile could use but does not.** These were deliberately left for later, not overlooked:
  - **Education** — `CurrentUser.educations` is parsed and carried, but no screen renders it. `/users/me/educations` has full CRUD (`UserProfileController`), and the university / faculty / department pickers would come from `/reference/universities`, `/reference/universities/{id}/faculties`, `/reference/faculties/{id}/departments`.
  - **CV upload** — the profile's *Özgeçmiş* card only reports whether `cvUrl` is set. `PUT /users/me/cv` takes multipart under the form field name **`file`** (not `image`), and `DELETE /users/me/cv` removes it. Needs a file picker, which means a new dependency — ask first.
  - **Experience editing** — the *Tecrübe* section is read-only. `/users/me/experiences` has full CRUD; adding one needs a form screen with an `EmploymentType` picker and a month/year range.
  - **`qualifications`** is parsed but no longer shown anywhere. "Meslek" moved to the real `jobTitle` field; `qualifications` ("yetkinlikler") is a separate thing with no UI yet.
  - **Presence** — `GET /users/{userId}/presence` and the batch `POST /presence/lookup` exist; the chat UI still hardcodes `isOnline: false`.
- ~~`b_create_page.dart` hardcodes the coordinates of every job.~~ Fixed: `CreateAddressRequestDto` makes `countryCode`, `cityName`, `addressLine`, `latitude` and `longitude` all mandatory, and the server never geocodes free text — so the create screen now collects the province and district from `/reference/countries → cities → districts` and the coordinate from `BLocationPickerPage`, a `google_maps_flutter` screen where the employer slides the map under a fixed centre pin. No new dependency; `geocoding` was rejected because it guesses at free-text addresses.


**Onboarding** is shown once — `seen_onboarding`, owned by `SessionManager` and read by the redirect guard. `SplashPage` (`/`) is the app's single startup point: it reads the session, and the guard sends the user on from there. There is no `AuthGate` any more.

---

## Working habits

- Run `flutter analyze --no-pub` after every change and leave it clean. If the change touched `android/` or `ios/`, run the matching `flutter build` too — analyze does not see the native side.
- Run `flutter test` after every change to logic, and add a test with it. If a bug got through, the fix and the test that would have caught it belong in the same change.
- When adding values to the constant files, give them meaningful names and a `///` comment saying *why* that value, not what it is.
- Before deleting anything, verify it is committed, and report what was deleted along with the command to undo it.
- When the user sends a screenshot, do not guess the problem; trace it from the code and explain the cause. Most layout problems come from constraints — a missing `Center`/`Expanded`/`stretch` and the like.
- When the task is done, give a summary and stop. Do not commit.
