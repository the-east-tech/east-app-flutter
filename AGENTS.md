# EastApp Frontend Rules

- Fetch the latest `main` from both repositories and state the exact independent frontend/backend versions.
- GitHub `main` is the only source of truth. Do not use old ZIPs or previous-chat memory.
- Ask before coding if anything is unclear. Work only on the requested scope.
- Follow the existing architecture, reuse existing code, and use lazy/on-demand loading with caching.
- Run `flutter analyze` once and only relevant tests. Do not run the app, emulator, or full build. Do not retry environment failures.
- Never force the frontend version to match the backend version.
- Release ZIP name: `east_app_vNNN_lib.zip`.
- ZIP contents:
  - First select only the top-level folders and root files required by the requested change. Do not create or package auxiliary tests, docs, generated files, caches, or lock-file changes unless required or explicitly requested.
  - If any file inside a selected top-level folder changes, include that entire resulting folder. This applies equally to `lib/`, `android/`, `ios/`, `assets/`, and every other folder. Never package a partial folder because the user replaces folders wholesale in macOS Finder.
  - Include each required changed root file individually. Omit every unchanged or unnecessary top-level folder and root file.
  - Before delivery, verify every included folder's complete file/path set against GitHub `main` plus intended additions/deletions, verify the exact root-file allowlist, test ZIP integrity, and reject any ZIP with an extra or missing file.
  - Create every delivered ZIP under a new unique path. Never reuse an earlier linked path because the old download may be cached.
- Efficiency: use focused searches, bounded reads, concise updates, and no huge outputs.
- Do not commit or push unless explicitly requested.
