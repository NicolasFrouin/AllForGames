# Lessons

Project conventions live in `CLAUDE.md`. Add here only lessons learned that apply across features.

- Before a commit, run a check on the commit content itself when commits are split: untracked work-in-progress
  files can hide a missing file.
- Flutter web runs one thread: no isolates, so heavy work (solvers, generators) belongs in offline tools, not in the app.
- Seeding browser storage for a manual check: `SharedPreferencesAsync` keys on web have no `flutter.` prefix and
  values are JSON-encoded. Leave the game screen first: a game saves itself when the page hides (reload) and
  would overwrite the seeded save.
- `timeDilation` set in a test must be reset inside the test body (try/finally): flutter_test checks it before the
  tear-down callbacks run.
- The dev shell is zsh: `$VAR` holding several paths is not split into words. Use bash arrays (`bash -c`) for
  multi-file commands, and check a chain stopped where you think before going on.
- An Android release build fails with "package dev.flutter.plugins.integration_test does not exist" when the plugin
  registrant was written by a debug-mode flutter command (pub get, test) during the build or after it: with
  `--no-pub`, or in a working tree shared with other running flutter commands. Build in an isolated copy then.
