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

> `image_picker` and `url_launcher` were added on the user's explicit approval, both from `flutter/packages`. The first picks a company logo from the gallery, the second opens an applicant's CV. `image_picker` brought one native change with it: `NSPhotoLibraryUsageDescription` in `ios/Runner/Info.plist` (Android needs nothing — the gallery goes through the system photo picker).

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
| `api_client.dart` | The only place `dio` is touched: unwraps the envelope, turns `DioException` into `ApiException`. `putFile` is the multipart upload path — it builds the `FormData` and forces the content type, because the base options say `application/json`. |
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

> ⚠️ **`RealtimeClient.disconnect()` must snapshot its maps before closing anything.** Each destination's `StreamController` has `onCancel: () => _releaseIfUnused(destination)`, and `close()` cancels the listeners — so closing while iterating `_controllers.values` re-enters and removes from the map being walked. That threw `ConcurrentModificationError` on logout and left the user signed in, because the exception landed before `AuthService().logout()`. Copy the values, clear the maps, *then* close; a re-entrant `_releaseIfUnused` then finds nothing. `test/product/network/realtime_client_test.dart` guards it.

> Both logout paths (`settings_page` and `b_settings_page`) call `disconnect()` **before** `AuthService().logout()` — the connection is tied to the session, and tearing down after the token is gone leaves the client reconnecting with a dead session.

Two controllers own all of this, and **both apps share them**:

- **`ChatThreadController`** — one conversation: messages, sending, typing, read receipts.
- **`ChatListController`** — the list: conversations, the personal message queue, and one presence subscription per counterpart, kept in sync as the list changes.

The same message arrives on **two channels** — the conversation topic and `/user/queue/messages` — and the server sends the copy to *both* participants, so your own message comes back to you too (that is deliberate: it keeps a second device's list current). Dedupe by `message.id`, and never count your own message as unread.

> **The connection is optional.** If it cannot be established the app keeps working over REST — only updates stop being instant. Never let a realtime failure block a screen.

> ⚠️ **Read receipts reach the personal queue, but the app drops them.** `RealtimePublisher.conversationRead` now publishes to `/topic/conversations/{id}` **and** to every participant's `/user/queue/messages` — the server side is done. `ChatListController` still returns early on anything that is not a `message` event, so reading a chat on your phone does not clear the unread badge in your tablet's list. The remaining fix is on our side, not the backend's.

**Still fake:**

**The employer's job flow is real too.** `business/features/home/services/employer_job_service.dart` owns it: `GET /users/me/jobs` (own posts, individual and company alike — the server filters by `creatorId`), `POST /users/me/jobs` / `POST /companies/{id}/jobs` (open a post), `POST /jobs/{jobId}/close`, `GET /jobs/{jobId}/applications` and `POST /job-applications/{id}/respond`. `BJobsProvider` merges the first and the fourth into one list; `b_job_detail_page` fetches the richer `GET /jobs/{id}` itself.

Four things worth knowing:

- **The count is free, the people are not.** `JobSummaryDto.applicationCount` arrives with the list (the server fills it in the same pass as the cover images), so no screen fetches applicants just to show a number. Who actually applied comes from `GET /jobs/{id}/applications` and is fetched **per job, on demand**, through `BJobsProvider.ensureApplicants` — the detail screen for its own job, the home screen for the three posts its preview shows, and the posts list only for past posts, whose footer names the person who took the job. Never load them for the whole list; that was the old N+1.
- **Insurance is a company-only concept, deliberately.** `CreateIndividualJobDto` has no `insuranceRequired`, the server forces it to `false`, and it rejects an individual job in any category whose `requiresInsurance` is set (`400`) — reporting SGK is the employer's legal duty and a one-day individual employer is not expected to carry it. So the create screen hides the switch for an individual employer, replaces it with a line saying why, **and filters those categories out of the picker** rather than letting the form fail on submit. Which endpoint is used comes from `CurrentUser.activeCompany` — the first **approved** membership.
- **There is no endpoint that deletes a job, and there should not be.** The post menu offers two things instead: *İlanı Kapat* (`POST /jobs/{id}/close`) stops new applications and leaves the post valid, *İlanı İptal Et* (`POST /jobs/{id}/cancel`) invalidates it and notifies the applicants. Cancel asks for confirmation first because the two read alike but are not, and it refuses with `409` while a live assignment exists (`PENDING_CONFIRMATION` / `CONFIRMED` / `IN_PROGRESS`) — cancelling there would route around the escrow and the cancellation policy, and the assignment's own cancel flow must be used instead. Neither one deletes anything; the record and the application history stay.
- **Accepting an application does not close the job.** The server opens an assignment in `PENDING_CONFIRMATION` and waits for the worker; the post stays in "Aktif" until its `JobStatus` says otherwise. Active vs. past is decided by `JobStatus` (`OPEN`/`IN_PROGRESS` → active), never by a local flag.

> `JobApplicantDto` carries `jobTitle` and `cvUrl` **on itself**, not inside its `SafeUserDto` — that DTO is reused across ten responses and the profession does not belong in all of them. `cvUrl` is only filled for the job's employer, and the download route checks ownership again, so a leaked link still cannot be fetched.

**The candidate profile** (`b_user_profile_page`) paints twice: the `JobApplicant` handed in through `state.extra` gives the name, photo, cover letter and date immediately, then `GET /users/{userId}` → `PublicProfile` fills in the profession, the "hakkında" text, the location and the CV. That endpoint deliberately returns **no full address** — city and district only — and it is open to signed-in users, not anonymous ones. If it fails the screen does not blank: a strip at the top offers *Tekrar dene* and the application data stays on screen. The CV opens in the external browser through `url_launcher`, because the URL is a redirect to a short-lived signed address rather than the file itself.

**The employer's profile is real too.** `business/features/home/services/b_company_service.dart` reads `GET /companies/{id}`, writes `PATCH /companies/{id}` and reads `GET /users/{userId}/employer-stats`; `BCompanyProvider` (registered in `main.dart`) holds both for the profile, settings and company-info screens.

- **The profile has two valid shapes.** An employer with a company membership sees the **company**; one without sees **themselves** — name, e-mail, phone and address off `/users/me`. Being company-less is not a gap: `POST /users/me/jobs` posts individual jobs. `b_profile_page` renders both from the same widgets.
- **Two different "company" getters on `CurrentUser`.** `activeCompany` is the first **approved** membership and decides which create-job endpoint is used; `primaryCompany` is the first membership regardless of approval and is what the profile shows — otherwise someone who just registered a company would never see it and would think they were an individual employer.
- **`PATCH /companies/{id}` accepts five fields only** — name, e-mail, phone, website, description (`UpdateCompanyRequestDto`), and only from the company's `ADMIN`. Tax number, address, type and logo are fixed at creation, so the company-info screen keeps those fields visible but `enabled: false` with a note saying why. Fields left blank are omitted from the body rather than sent as `""`, which would clear them.
- **The approval flag is spelled `approved`, not `isApproved`** — the same name `/users/me` → `CompanyMembershipDto.approved` uses, so the concept has one name across the API. `BCompany` parses `approved`; the Dart field stays `isApproved` because that is how a flag reads. `BCompanyProvider` still overwrites it from the membership after a fetch, which is now belt-and-braces rather than the only source.
- **`BCompany` is the real `CompanyDto`;** `employee/features/company_detail/models/company.dart` is the fake one and its fields do not match the server (`logo` ↔ `logoUrl`, `address.city` ↔ `address.cityName`, and a two-value `CompanyType` where the server has eight). The `b_` prefix exists only to keep the two apart until company detail is wired.
- **Employer stats are per person, not per company** (`StatisticsManager` counts by `creatorId`), so two admins of the same company see different numbers. Zero reviews come back as `averageRating: 0`; `EmployerStats.hasRating` separates that from an actual bad score so the card shows "—" instead of "0.0".

- **The logo is editable, the rest of the fixed fields are not.** `PUT /companies/{id}/logo` (multipart, part name `logo`, `ADMIN` only) and `DELETE` on the same path both return the company, so no second read is needed. The company-info screen picks from the gallery and checks extension and size **client-side** against the server's own limits (`png/jpg/jpeg/webp`, 10 MB, from `UploadProperties`) so the user is not left waiting for a rejection. The file is sent **unmodified** — re-encoding it would flatten a transparent PNG, which is visible on a logo.

> Endpoints the profile could use but does not: the company gallery (`/companies/{id}/images`), the contact list and invitations (`/contacts`, `/contact-invitations`) and `followerCount` (parsed, not shown). Creating a company (`POST /companies`) is missing entirely — multipart with a logo, plus an identity-verification precondition; the company-info screen explains this instead of offering it (`TODO(backend)`).

**The worker's side of the assignment is on the real endpoints too.** `employee/features/jobs/services/assignment_service.dart` owns them: `GET /users/me/assignments` (moved off `JobApplicationService`, which now carries applications only) and `POST /job-assignments/{id}/respond`.

Accepting an application does not start the job — the server opens the assignment in `PENDING_CONFIRMATION` and **waits for the worker**. `MyJobStatus.awaitingApproval` is that state, and "İşlerim" shows it in its own section above everything else, with Kabul Et / Reddet. Rejecting asks for confirmation first: the answer is given once and `REJECTED` drops the row out of the list entirely (`MyJob.fromAssignment` returns `null` for it). Answering a second time is `409`; the screen shows the server's message and reloads, because a `409` means the local list is stale.

> `MyJob.assignmentId` is `null` on rows that came from an application and carries the id on rows that came from an assignment. It duplicates `MyJob.id` on purpose — the assignment endpoints need an id that is definitely an assignment's.

**The timesheet is wired on both sides.** `AssignmentService` gained `checkIn` / `checkOut` / `fetchWorkSessions`, and `EmployerJobService` gained `fetchMyAssignments` (with `asEmployer: true`) and `completeAssignment`.

Four things worth knowing:

- **Check-in and check-out are worker-only; complete is employer-only.** The server returns `403` for the wrong party, so the two live on opposite sides of the app on purpose. `fetchWorkSessions` is the exception — both parties may read it, so `b_job_detail_page` calls the employee-side `AssignmentService` for it, the same way both apps share `chat_service.dart`.
- **The money gates the timesheet.** The server refuses a check-in unless `paymentStatus` is `HELD_IN_ESCROW`. `MyJob.isPaymentSecured` carries that, and the approved tile replaces the button with a line saying why rather than letting the user earn a `409`.
- **`IN_PROGRESS` is now its own screen state.** `MyJobStatus.inProgress` sits at the very top of "İşlerim" in its own teal section (`AppColors.progress`, the only hue the other four sections had not taken), because a worker mid-shift wants the check-out button first. Open sessions are fetched **only** for in-progress assignments — nobody has two shifts running at once, so this is not the N+1 that applicant loading used to be.
- **The elapsed time ticks.** `WorkSession.elapsed` computes from `DateTime.now()` on an open session, so `my_jobs_pagemodel` runs a one-minute `Timer` while any session is open and cancels it when none is. Without it the screen would show a frozen duration, which on a timesheet is worse than showing nothing.

> There is no endpoint that returns the assignment for a given job — `JobDetailDto` does not carry one — so `b_job_detail_page` fetches the employer's assignment page and filters by `job.id`. If a per-job endpoint ever lands, that is the one call to replace.

**Cancellation and disputes are wired on both sides.** `AssignmentService` owns `cancel`, `fetchCancellation`, `openDispute` and `fetchDisputes` — all four are open to **both** parties, so the business side calls the employee-side service for them, as it already does for work sessions.

Four things worth knowing:

- **There is no fee preview, and this is the one real gap.** `GET /{id}/cancellation` returns the record that cancelling *creates*; the rates live behind `/admin/settings`, which the app cannot read. So the confirmation dialog states the **rule** in words (worker cancels → no fee; employer cancels inside the free window → no fee, outside it → late fee, after the job starts → no refund) and the actual figure is reported afterwards from the returned `CancellationDto`. A preview endpoint would let us show the number before the decision — worth asking for.
- **A reason is mandatory on both endpoints.** `ReasonDialog` (`product/widgets/`) keeps its confirm button disabled until the field is non-empty, so nobody spends a round trip to learn that. Both apps use it.
- **Disputes need money in escrow.** The server refuses otherwise, and one open dispute blocks a second. `MyJob.isPaymentSecured` and the fetched dispute list gate the buttons on both sides. An open dispute freezes the escrow — it does **not** speed a payout up — and both dialogs say so, because a worker reading "bildir" could easily assume the opposite.
- **Cancelled and rejected assignments are back in the list.** `MyJob.fromAssignment` used to return `null` for them and they vanished; now `MyJobStatus.cancelled` / `.rejected` put them in "Geçmiş" with a red marker and the status text in place of the amount — no money was earned, so showing the green figure would have been a lie. `fromAssignment` is non-nullable as a result.

**Applying has a gate, and it is enforced in production.** `POST /jobs/{id}/applications` now checks three things in order — identity, address, primary IBAN — and rejects with `APPLICANT_IDENTITY_NOT_VERIFIED`, `APPLICANT_ADDRESS_REQUIRED` or `APPLICANT_BANK_ACCOUNT_REQUIRED`. The order is the worker's repair order, and the same three conditions gate the İyzico sub-merchant record, so a mismatch would blow up at acceptance instead.

- **The check happens twice, on purpose.** `/users/me` already carries `identityVerified`, `address` and `maskedIban`, so `ApplicationReadiness` shows what is missing **before** the form is filled in and disables the submit button. The server's `errorCode` is still handled on submit — the user may have changed something on another device. `ApiException.errorCode` is what routing keys off, never the message text.
- **Three screens exist for it now:** `identity_verification_page.dart` (`POST /users/me/identity-verification`, NVİ-checked, and it locks first/last name afterwards), `address_page.dart` (`PUT /users/me/address`) and an IBAN field on `account_info_page`. IBAN has **no endpoint of its own** — it rides on `PATCH /users/me` and comes back masked, which is why the field opens empty and an empty field is never sent.
- **The address endpoint demands coordinates.** There is no geocoding endpoint, so the user picks them on the map. `BLocationPickerPage` is reused through a second route, `/pick-location`; the page still lives under `business/` and should move when someone touches it next.
- **`ReferenceLocationService` and `ReferenceLocation` moved to `product/`** (`product/services/`, `product/models/`) — both apps need country/city/district lists now, and leaving them in `business/` would have made the employee app depend on the employer app.

**Company detail is on the real endpoint, and the last fake service is gone.** `employee/features/company_detail/services/company_service.dart` now reads `GET /companies/{id}` and writes `POST|DELETE /companies/{id}/follow`.

- **The two `Company` models merged.** The old fake one is deleted and `BCompany` moved to `employee/features/company_detail/models/company.dart` as `Company` — the shared domain model lives on the employee side and the business app imports it, the same arrangement chat already uses. `b_company_service.dart` keeps only the employer's **write** endpoints (update, logo) plus stats; reading a company is one endpoint for both apps, so `BCompanyProvider` takes a `CompanyService` too.
- **One request, not three.** `CompanyDto` carries `images`, `followerCount` and `following` inline, so the screen never calls `/companies/{id}/images` or asks whether the user follows the company. The gallery endpoint stays in `ApiPaths` for managing a gallery, not for reading one.
- **The page takes an id, not a `Company`.** It is reached from a job, a past job or a chat, and none of those hold the full record. Following is optimistic — the button flips immediately and rolls back if the request fails, because both endpoints are idempotent and the outcome is predictable.

> Two things on that screen are still not real. Company jobs are filtered from `GET /jobs` **by company name** because no endpoint filters by company id, and messaging a company has no endpoint at all (a conversation always belongs to a job). Both are marked `TODO(backend)`.

**Experiences are editable.** `employee/features/profile/services/experience_service.dart` writes `POST|PUT|DELETE /users/me/experiences[/{id}]`; the list itself still arrives inside `/users/me`, so every change refreshes `UserProvider` rather than patching the local list. `PUT` replaces the whole record — a field left blank in the sheet is cleared on the server, which is why the form opens pre-filled. Dates go as `yyyy-MM-dd`: `toIso8601String` writes a time component and the server's `LocalDate` parser rejects it.

**Reviews are on the real endpoints.** `employee/features/jobs/services/review_service.dart` owns all three: `POST /job-assignments/{id}/reviews` (write), `GET /users/{id}/reviews` and `GET /users/{id}/rating-summary` (read). Writing goes through the **assignment**, reading through the **person** — a review is left on a job but written about the counterpart. `profile_page` shows both through `ProfileReviews`, which fetches its own data and fails on its own strip rather than blanking the profile.

Three things worth knowing:

- **There is no anonymous review, and the toggle came out.** `CreateReviewDto` carries `rating` and `comment` only, and `ReviewDto` always names its author — the screen used to offer "Anonim Yayınla", which the server would never have honoured. Do not put it back without an endpoint that supports it.
- **Nothing on the server says "did I review this".** The second review is a `409`, and that is the whole API. `ReviewProvider` therefore keeps the reviewed assignment ids in `SharedPreferences` (`reviewed_assignments`) so the "Değerlendirildi" badge survives a restart, and marks an id on a `409` too — the cache is a convenience, not a source of truth, and it self-heals. It is cleared on logout alongside the other providers.
- **A review is allowed the moment the assignment is `COMPLETED`,** not when the money moves. So "Değerlendir" sits in **both** the "Ödeme Bekleniyor" and the "Geçmiş" section; if it were only in the first, an employer who pays quickly could never be reviewed.

> `RatingSummary` is `null`, not zeroed, for someone with no reviews — the endpoint returns `data: null` and `hasRating` keeps "no rating" apart from "rated 0.0", the same distinction `EmployerStats.hasRating` makes.

**There are no fake services left.** Every `services/` class in the app talks to the real API. (`home/services/location_service.dart` is not a data service — it is the device's own location permission flow.)

Endpoints that exist on the server and have no app surface yet: payments (`POST /job-assignments/{id}/payment-session`, `GET /users/me/payouts`) — **this blocks the timesheet, since check-in needs escrow**; notifications and push tokens (`/users/me/notifications`, `/users/me/devices/push-token`); sessions (`/users/me/sessions`); education CRUD (`/users/me/educations`, needs the university/faculty/department pickers off `/reference/**`); availability and job alerts (`/users/me/availability`, `/users/me/job-alerts`); blocks and reports (`/users/me/blocks`, `/reports`); company creation (`POST /companies` plus identity verification); employer tools (`/users/me/talent-pool`, `/users/me/job-templates`).

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
- The applicant CV download and the "follow company" action render but write nowhere. (The business profile's stat numbers are real now — `GET /users/{id}/employer-stats`.)
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
