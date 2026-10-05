# Lessons

Project conventions live in `CLAUDE.md`. Add here only lessons learned that apply across features.

- Before a commit, run a check on the commit content itself when commits are split: untracked work-in-progress
  files can hide a missing file.
- Flutter web runs one thread: no isolates, so heavy work (solvers, generators) belongs in offline tools, not in the app.
- Seeding browser storage for a manual check: `SharedPreferencesAsync` keys on web have no `flutter.` prefix and
  values are JSON-encoded. Leave the game screen first: a game saves itself when the page hides (reload) and
  would overwrite the seeded save.
