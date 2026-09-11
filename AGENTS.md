# EastApp Frontend Rules

## Execution

- Answer, review, explain and diagnose requests are read-only. Do not create a branch, commit or PR unless code/file changes are requested.
- A request to fix, change or implement authorises the complete delivery workflow; do not pause for separate push approval:
  **fetch latest `main` → inspect only what is needed → create or reuse one task branch → make the smallest complete change → review the focused diff → bump the version once → commit once → push → open or update the PR → stop**.
- “All above” means only the requested items in the current conversation. It does not authorise a repository-wide review or unrelated improvements.
- Do not run tests, `flutter analyze`, builds, the app, simulators or emulators unless explicitly requested. Do not retry unavailable tooling.
- Do not create plans, subagents, ZIPs, documentation or other artefacts unless required or explicitly requested.
- Ask only when missing information would materially change behaviour. Otherwise complete obvious details without extra confirmation.

## Branch and PR control

- GitHub `main` is the source of truth. Fetch it before editing and never use an old ZIP, stale branch, previous-chat code or memory as code truth.
- Check the existing PR state before creating a branch.
- If an open PR already covers the same unfinished task, continue that branch and PR. Do not create another branch, PR or version bump.
- If that PR is merged or closed, always create a new branch from the latest `main` and open a new PR. Never reuse its old branch.
- A different task gets one new branch and one PR. Never create branches or commits per file, attempt or minor correction.
- Default delivery is a feature branch plus PR. Never push directly to `main`, merge or deploy unless explicitly requested.

## Scope

- Change only requested frontend files. Preserve unrelated user changes.
- Do not inspect the backend unless the API contract requires it or cross-repository work is requested.
- Use focused searches and bounded reads. Avoid unrelated refactors, reformatting, modernisation and optimisation.
- Follow the existing architecture and reuse existing components, services, localisation, loading, caching and error handling.
- Keep backend calls lazy/on-demand and do not add unrelated API calls.
- Frontend and backend versions are independent.

## Version, commit and PR

- Every new PR, including a documentation-only PR, increments the build number in `pubspec.yaml` exactly once.
- Select one above the highest frontend build number on latest `main` or any open frontend PR, whichever is higher.
- Further changes to the same open PR do not increment the version again.
- Finish and review the requested change before committing. Prefer one commit; do not commit each file or attempt separately.
- Commit and PR title: `frontend vNNN: concise description`. Keep it one line and at most 72 characters.
- Keep the PR body short: requested changes plus whether checks were run. Do not add long narratives or code dumps.
- The title version must match the `pubspec.yaml` build number.
- Use the configured assistant/service Git identity, never the user’s personal identity.
- Final response: PR link, branch, version, brief changes and checks not run.

## ZIP delivery — explicit fallback only

- Git/PR is the default. Create a ZIP only when explicitly requested; do not provide both unless requested.
- ZIP delivery does not create a branch, commit or PR unless explicitly requested.
- Name it `east_app_vNNN_lib.zip`.
- Include a changed top-level folder as its complete final tree. Include required changed root files individually.
- Omit unchanged root files, generated files, caches and unrelated content.
- Use a unique output path and verify archive paths and integrity once.
