# Lessons

Project conventions live in `CLAUDE.md`. Add here only lessons learned that apply across features.

- Before a commit, run a check on the commit content itself when commits are split: untracked work-in-progress
  files can hide a missing file.
- Flutter web runs one thread: no isolates, so heavy work (solvers, generators) belongs in offline tools, not in the app.
