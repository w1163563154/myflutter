# Local Issue automation setup

Runner directory: `D:\actions-runner`, label `codex-myflutter`.
Workflow responds only to repository owner `w1163563154`, to Issue opened/edited/reopened and Issue comments created/edited. PR comments are excluded. One dedicated runner executes one job at a time. Runs use Actions checkout under runner `_work`, not the interactive development folder.

Before activation:
1. As the Windows user who runs the runner, execute `codex login`, then `codex login status`.
2. Ensure Git, Node, Flutter and Codex are on that user's PATH. Jobs use Windows PowerShell, no PowerShell 7 install required.
3. Register runner with label `codex-myflutter`, then run `run.cmd` under that user. Do not run as LocalSystem: Codex login belongs to the current user.
4. Put workflow and script on the repository DEFAULT branch, currently `issue-1-flutter-starter`.
5. In Settings > Actions > General > Workflow permissions, allow GitHub Actions to create/approve pull requests if needed. Script requests contents and pull-requests write permission; repository policies still apply.
6. Run workflow_dispatch with an existing open Issue number for smoke validation.

Worker reads current Issue plus all owner comments. Existing `codex/issue-N` branch is reused for updates. Commits and pushes only that branch, creates draft PR; never merges or closes Issue. Run summaries carry the Codex result. The worker independently runs analysis, app/package tests and Web build before publishing. Clarification-only tasks return no code changes.

Codex runs with workspace-write sandbox and no interactive approvals. Missing sandbox setup or credentials fail the run rather than bypassing isolation. File-selector or package downloads may require allowed network access in the local Codex configuration.

Do not add another runner with this dedicated label if strict serial execution is required. Keep runner folder outside the app repo. This registration runs under a logged-in Windows account; persistent startup/service setup is separate.
