# EastApp Frontend Rules

- Fetch the latest `main` from both repositories and state the exact independent frontend/backend versions.
- GitHub `main` is the only source of truth. Do not use old ZIPs or previous-chat memory.
- Ask before coding if anything is unclear. Work only on the requested scope.
- Follow the existing architecture, reuse existing code, and use lazy/on-demand loading with caching.
- Run `flutter analyze` once and only relevant tests. Do not run the app, emulator, or full build. Do not retry environment failures.
- Never force the frontend version to match the backend version.
- Packaging rule: changed folder = include whole folder; changed root file = include that file; unchanged = omit. No huge outputs.
- Do not commit or push unless explicitly requested.
