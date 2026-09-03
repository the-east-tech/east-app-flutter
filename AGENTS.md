# EastApp Frontend Rules

## Default execution mode

- For requests such as “fix/change/implement all above and send/give me code”, use this exact workflow: **read only what is needed → make the requested change → review the focused diff → increment the frontend version once → commit to a feature branch → open a pull request → stop**.
- “All above” means every requested item in the current conversation. It does not authorise a repository-wide audit or extra improvements.
- Make the smallest complete change. Do not inspect, refactor, clean up, modernise, optimise, or reformat unrelated code.
- Do not run tests, `flutter analyze`, builds, the app, simulators, or emulators unless the user explicitly asks. Do not retry environment failures.
- Do not create a ZIP, release bundle, report, documentation, or other artefact unless explicitly requested.
- Do not use plans, subagents, web research, or broad Git-history analysis unless required by the requested change or explicitly requested.
- If a necessary expansion would materially change scope or behaviour, ask first. Otherwise complete obvious implementation details without back-and-forth.

## Source and scope

- GitHub `main` is the source of truth. Fetch the latest `main` for the repository being changed before creating the feature branch.
- Do not use old ZIPs, previous-chat code, or memory as code truth.
- Do not fetch or inspect the backend unless the frontend change genuinely depends on its current API or the user requests cross-repository work.
- Use focused searches and bounded reads. Open only relevant files or relevant sections of large files.
- Follow the existing architecture and reuse existing components, services, localisation, loading, caching, and error-handling patterns.
- Keep backend calls lazy/on-demand where applicable. Do not introduce unrelated API calls.
- Frontend and backend versions are independent; never force them to match.

## Git, versioning and delivery

- Default delivery is **feature branch + pull request**. Never push commits directly to `main` unless the user explicitly asks for a direct `main` push.
- Avoid unnecessary intermediate or throwaway commits on `main`. Keep branch history purposeful; prefer one complete versioned commit for a finished change when practical.
- **Every pull request must increment the frontend version exactly once**, including documentation-only or process-only PRs. The frontend version source of truth is `pubspec.yaml`.
- Increment the Flutter build number by one from latest `main` for each new PR, e.g. `1.0.0+327` → `1.0.0+328`.
- Commit and PR titles must be descriptive and versioned: `frontend vNNN: concise description`, where `NNN` matches the `pubspec.yaml` build number.
- Commit only the requested changes. Preserve unrelated existing changes.
- Use the assistant/service Git identity supplied by the environment. Never configure or use the user’s personal name or email as commit author.
- Do not merge the PR or trigger deployment/release actions unless the user explicitly requests it.
- Final response: provide the PR link, branch name, version, and a brief list of requested changes; state that tests/builds were not run when they were not requested.

## ZIP rules — only when explicitly requested

- Name it `east_app_vNNN_lib.zip`.
- Include only top-level folders and root files required by the requested change.
- If any file inside a selected top-level folder changes, include that entire resulting folder. This applies to `lib/`, `android/`, `ios/`, `assets/`, and every other folder.
- Include required changed root files individually; omit unchanged or unnecessary files, generated files, caches, and lock files unless required.
- Use a new unique output path and verify the archive paths and integrity once.
