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

**Visual verification is done by the user.** They are the one who runs the app, sends screenshots and asks for fixes. A clean `flutter analyze` means "it compiles", not "it looks right" — do not conflate the two. If you made a visual change, say explicitly that you did not verify it on screen and point out what to look at.

**Do not add dependencies or invent new patterns.** Reuse what is already in `lib/product/constants` and `lib/product/widgets` first. If a value is missing from a constant file, add it there with a meaningful name instead of hard-coding it.

---

## Commands

```bash
flutter analyze --no-pub     # after every change; must stay clean
dart format lib/             # before handing the work over
flutter pub get
```

The project has **no tests** (there is no `test/` folder). Do not write tests unless asked.

> **The iOS simulator is unavailable on this machine:** `xcode-select` is not pointed at Xcode. The fix needs sudo (`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`), so an agent cannot run it — ask the user. There is no Android emulator booted either, and the project has no `macos/` or `web/` target, so **an agent generally cannot run this app at all**. `flutter analyze` is the only verification available to you; the user runs it.

> ⚠️ **A fresh clone cannot build for iOS.** `ios/Flutter/Debug.xcconfig` and `Release.xcconfig` `#include "Secrets.xcconfig"` unconditionally, but that file is gitignored. Until the include is changed to the optional form (`#include?`), every new checkout — and CI — has to create the file first. The CI workflow writes an empty placeholder for exactly this reason.

> Running the app needs the Google Maps key to be in place — see *Secrets* below. Without it the map tab renders a blank grey area, which is a configuration problem, not a code bug.

---

## Architecture

### Folder layout

```
lib/
├── main.dart                     # MultiProvider registrations + runApp
├── product/                      # shared by both apps (employee + business)
│   ├── my_app.dart               # MaterialApp.router, theme, deep link listener
│   ├── constants/                # AppColors, AppPadding, AppRadius, AppSizes, AppAssets
│   ├── extensions/               # context_extensions.dart (theme colors, sizes,
│   │                             # paddings) + num_extensions.dart (`asPrice`)
│   ├── router/                   # router_manager.dart (single GoRouter)
│   ├── theme/                    # theme.dart (light/dark), theme_provider.dart
│   └── widgets/                  # MyButton, MyTextfield, MyAppbar, MyListTile,
│                                 # NavbarItem, ButtonNavbar, AppBottomSheet,
│                                 # ThemeModeSheet
├── employee/
│   ├── core/widgets/             # shared across employee features only
│   └── features/<name>/
│       ├── models/               # plain data classes, no `Model` suffix
│       ├── services/             # the fake data sources (see Backend)
│       └── presentation/{pages,widgets,providers}
│                                 # pages come in `_page.dart` + `_pagemodel.dart`
│                                 # pairs wherever the page carries state
└── business/
    ├── core/                     # b_shell_page.dart + widgets/
    └── features/<name>/
        ├── models/
        ├── services/
        └── presentation/{pages,providers}
```

Employee features: `auth`, `home` (explore), `jobs`, `chat`, `profile`, `company_detail`, `settings`.
Business features: `home`, `chat`.

A feature has at most three top-level folders: **`models/`** (plain data classes), **`services/`** (where the data comes from) and **`presentation/`**. There is no `data/` or `domain/` wrapper — a model sits directly under `models/`. `auth` and `settings` have no data of their own, so they only carry `presentation/`.

**Where does shared code go?** Used by both apps → `lib/product/`. Used by several features on one side only → that side's `core/`. Used by a single feature → that feature's own folder. Do not push employee-only code into `product/`.

> `auth` lives under `employee/` even though it serves both sides (registration asks whether you are a business). That is historical; do not move it without being asked, but be aware the business flow runs through employee files.

> The same applies to chat: `business/features/chat` imports `ChatAvatar`, `ChatAppBar`, `MessageBubble` and `MessageTextField` from `employee/features/chat/presentation/widgets/`, because the `Chat` and `Message` models live on the employee side. Strictly the shared parts belong in `product/`, but moving them would drag the domain models along; the existing convention is to reuse the employee widgets.

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

`go_router`. A single `GoRouter` inside `product/router/router_manager.dart`, `initialLocation: '/explore'`.

**The `redirect` guard** reads `is_logged_in` and `user_type` from `SharedPreferences` on **every** navigation and enforces four rules: not logged in → `/authgate`; logged in but on an auth route → the home of your type; business user on an employee route → `/business/home`; employee user on a business route → `/explore`.

> The guard is `async` and hits `SharedPreferences` on every route change. It works, but it means the redirect is not synchronous — do not assume the first frame of a route is already the final destination.

**Two `ShellRoute`s**, one per app:

- Business shell (`BShellPage`): `/business/home`, `/business/posts`, `/business/chat`, `/business/profile` — fade transitions.
- Employee shell (`ShellPage`): `/explore`, `/jobs`, `/chat`, `/profile` — no transition.

Everything else (`/apply`, `/review`, `/company-detail`, `/chat-detail`, `/settings`, `/business/create`, `/business/job-detail` ...) is **top level**, so it opens full screen above the navbar. If you add a page that must cover the navbar, put it at top level — a route nested inside the shell stays underneath it.

> ⚠️ **The employee `ShellPage` ignores go_router's `child`.** It keeps a static `PageView` of the four pages and only uses the matched location to pick an index (`didChangeDependencies`). So the route drives the index, not the content — the pages are constructed once and kept alive. Anything you expect to rebuild on navigation will not. `BShellPage` does the opposite: it renders `child` normally.

**Passing data between routes** is done with `state.extra` and an unchecked cast (`state.extra as Job`). Navigating to those routes without the right `extra` throws. There is no `pageKey`/`ValueKey` on them.

### Deep links

`app_links` listens in `my_app.dart`. A link carrying a `token` query parameter is routed to `/auth/register-type/register/creating-password?token=...` — this is the e-mail verification flow. The listener is registered in `initState` and is never cancelled.

### Backend

**There is none yet.** This is the single most important thing to know about this codebase.

- No HTTP client is in `pubspec.yaml` — no `http`, `dio`, `firebase` or `supabase`.
- All data comes from fake services that return hard-coded lists, one `services/` folder per feature: `employee/features/home/services/` (`job_service.dart` with Ankara coordinates, `location_service.dart`), `company_detail/services/company_service.dart`, `chat/services/chat_service.dart`, `jobs/services/` (`my_jobs_service.dart`, `review_service.dart`), `profile/services/fake_user.dart`, `business/features/chat/services/b_chat_service.dart` and `business/features/home/services/fake_business_company.dart`. Avatars are generated URLs from `ui-avatars.com`.
- "Authentication" is `SharedPreferences.setBool('is_logged_in', true)` plus a `user_type` string. There is no token, no session, no server. `auth` has no `services/` folder at all — the login and register pages write to `SharedPreferences` directly, so that is where the real client will have to be introduced.

> A service class is named after its file: `job_service.dart` → `JobService`. There is no `*Repository` naming in the codebase.

When you add anything data-shaped, keep it behind the existing repository classes so the swap to a real API stays a one-file change.

### Secrets

The Google Maps key is **not** in the repo. It is read from:

- Android: `MAPS_API_KEY` in `android/local.properties` (consumed in `android/app/build.gradle.kts`)
- iOS: `MAPS_API_KEY` in `ios/Flutter/Secrets.xcconfig` (read in `AppDelegate.swift`)

Both files are gitignored, as is `.env`. Never print a key value into an answer, a comment or a committed file.

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

Bottom sheets go through **`AppBottomSheet`** (`product/widgets/`), which owns the background, the top corners, the title row and the bottom safe-area inset. If the sheet has its own state, wrap `AppBottomSheet` in a `StatefulBuilder` inside the builder — the shell itself is stateless.

> ⚠️ **Two footguns that cost compile errors and silent bugs:**
> - `context.size` is **not** the `SizeExtension` getter — `BuildContext` has its own nullable `size`, and the instance member wins. Use `MediaQuery.sizeOf(context)`. `context.width` / `context.height` are fine.
> - Every `textTheme` slot carries a color. On a colored surface (a green button, a tinted card) you must pass the foreground explicitly with `copyWith(color: ...)`, or set `textStyle:` in the button's `styleFrom` and let `foregroundColor` win. `copyWith(color: null)` does **not** clear a color.

---

## Icons

Two sources, both already in use:

- **`hugeicons`** for UI icons — `HugeIcons.strokeRoundedArrowLeft01` and friends. This is the default; reach for it first.
- **`Icons`** (Material) still appears in older files. Do not add new ones; when you touch such a file, a Huge Icons equivalent is welcome but not mandatory.
- **`flutter_svg`** for the map pins in `assets/map_pins/`, drawn through `employee/features/home/presentation/widgets/job_marker_generator.dart`.

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

- `auth` has no service layer; the pages talk to `SharedPreferences` directly.
- `business/features/home/presentation/pages/b_home_page.dart` has a `_quickActionsSection` that nothing calls. It carries an `// ignore: unused_element` so analyze stays clean — it is a parked section, not dead code to delete without asking.
- The stat numbers on the business profile, the applicant CV download and the "follow company" action all render but write nowhere.


**Onboarding** is shown once — `seen_onboarding` in `SharedPreferences`, checked by `AuthGate`.

---

## Working habits

- Run `flutter analyze --no-pub` after every change and leave it clean.
- When adding values to the constant files, give them meaningful names and a `///` comment saying *why* that value, not what it is.
- Before deleting anything, verify it is committed, and report what was deleted along with the command to undo it.
- When the user sends a screenshot, do not guess the problem; trace it from the code and explain the cause. Most layout problems come from constraints — a missing `Center`/`Expanded`/`stretch` and the like.
- When the task is done, give a summary and stop. Do not commit.
