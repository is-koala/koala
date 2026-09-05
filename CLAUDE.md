# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Read these first

- **[AGENTS.md](AGENTS.md)** — what the project is, the dual-app (employee/business) architecture, the theme/color rules and the known pitfalls. Read it end to end before writing code.
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — binding coding rules: folder structure, the Page/PageModel split, widget extraction, typography and constant usage.

Both files are the single source of truth; do not duplicate their content here.

@AGENTS.md

## Non-negotiables

- **Never run `git commit` or `git push`.** Summarize the changed files and stop; the user commits.
- **Write in Turkish.** Answers, in-code comments and user-facing strings are Turkish; identifiers stay English.
- **Run `flutter analyze --no-pub` after every change** and leave it clean. A clean analyze means "the Dart typechecks", not "it builds" and not "it looks right" — see the *Commands* section for when to build as well.
- **The user does the visual verification.** If you changed anything visual, say explicitly that you did not verify it on screen and point out what to look at — in **both** the light and the dark theme.
- **Run `flutter test` after touching logic** and leave it green. `test/` mirrors `lib/`; see the *Tests* section in AGENTS.md for the shared helpers. CI blocks the build jobs behind it.
- **Do not add new dependencies or invent new patterns** — reuse what is in `lib/product/constants` and `lib/product/widgets` first.
- **Never print a secret.** The Google Maps key lives in `android/local.properties` and `ios/Flutter/Secrets.xcconfig`, both gitignored. Do not copy a key value into an answer, a comment or a committed file.

## Permissions

`.claude/settings.json` is committed and shared by the team: it pre-approves the safe read-only commands and **denies** `git commit`, `git push`, `git reset`, `git checkout` and `pod install/update`. Personal overrides go in `.claude/settings.local.json`, which is gitignored. If a denied command is genuinely needed, ask the user to run it — do not work around the rule.

## Commands

```bash
flutter analyze --no-pub
flutter test
dart format lib test
flutter pub get

# Native tarafa dokunduysan analyze yetmez — ilgili build'i de al.
flutter build apk --debug
flutter build ios --no-codesign   # pod çözümlemesini tetikler, önce kullanıcıya sor
```

## Agent skills

### Issue tracker

Issues and specifications are tracked in GitHub Issues for `is-koala/koala`. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default triage labels are used. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repository: `CONTEXT.md` lives at the root and decisions live under `docs/adr/`. See `docs/agents/domain.md`.
