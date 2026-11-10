---
name: git-flow
description: "Git Flow branching and release workflow. Bootstraps the long-lived `main`/`master` and `develop` branches when they are missing, names branches with the standard feature/, bugfix/, release/, hotfix/ and support/ prefixes, opens pull requests against the correct base (develop for features and fixes, main for releases and hotfixes), waits for every CI/CD check to finish before calling the work done, and cuts versioned releases with tags, release notes and back-merges. Use this skill whenever you create a branch, finish a feature, open or merge a pull request, bump a version, prepare a release, ship a hotfix or tag a version, and whenever the user mentions git flow, gitflow, a develop branch, feature/release/hotfix branches, PRs, CI checks or shipping a release, even if they do not say 'Git Flow' explicitly."
---

# Git Flow

Git Flow organises work around two permanent branches and a few kinds of short-lived ones:

- `main` (or `master` in older repositories) holds production code. Every commit on it is a released version and carries a tag.
- `develop` is the integration branch: finished work lands there and waits for the next release.
- Everything else happens on a short-lived branch with a fixed prefix, and reaches `main` or `develop` only through a pull request whose CI/CD has finished green.

Following this consistently means `main` is always releasable, `develop` always shows what is coming next, and every change has been reviewed and tested before it lands. The rest of this skill is how to do that step by step.

Throughout this document `<prod>` means the repository's production branch (`main` or `master`, see Step 1).

## Branch model

| Branch | Purpose | Created from | PR target | Lifetime |
|---|---|---|---|---|
| `<prod>` | Released, production-ready code | — | — | Permanent |
| `develop` | Integration of work for the next release | `<prod>` | — | Permanent |
| `feature/<name>` | New functionality | `develop` | `develop` | Until merged |
| `bugfix/<name>` | Non-urgent fix for unreleased code | `develop` | `develop` | Until merged |
| `release/<X.Y.Z>` | Stabilise and prepare a release | `develop` | `<prod>`, then back-merge into `develop` | Until released |
| `hotfix/<X.Y.Z>` | Urgent fix for production | `<prod>` | `<prod>`, then back-merge into `develop` | Until released |
| `support/<X.x>` | Maintenance of an old major version (rare) | a release tag | receives hotfixes | Long-lived |

Picking the branch type:

- New behaviour, a refactor, docs, tooling → `feature/`. Git Flow has no separate prefix for chores or docs; they are features unless the repository documents extra prefixes of its own.
- A bug in code that has not been released yet (it only exists on `develop`) → `bugfix/`.
- A bug in production that cannot wait for the next release → `hotfix/`.
- "Release", "ship", "cut a version", "bump to X.Y.Z" → `release/`.
- Already on a suitable branch for this work? Keep working on it instead of creating another.

## Branch naming

- `<prefix>/<short-description>` in lowercase kebab-case: `feature/oauth-login`, `bugfix/cart-total-rounding`. Not `Feature/OAuthLogin`, `feature/oauth_login` or `oauth-login`.
- If there is an issue or ticket, put its key first, keeping the tracker's format: `feature/PROJ-142-oauth-login`, `bugfix/87-cart-total-rounding`.
- Keep it short (2–5 words) and describe the change, not the person or the date.
- Release and hotfix branches are named after the exact version they will produce, without a `v`: `release/1.4.0`, `hotfix/1.4.1`. The tag is `v1.4.0` unless the repository's existing tags use another style — match them.
- If the repository customises prefixes (`git config --get-regexp '^gitflow\.prefix\.'`) or documents its own conventions in `CONTRIBUTING.md`, follow the repository.

## Step 1 — Inspect the repository

Start every Git Flow task by looking at the current state, so you build on what exists instead of guessing:

```bash
git status --short --branch
git fetch --all --prune --tags
git branch --all
git config --get-regexp '^gitflow\.' || true   # existing git-flow configuration, if any
git remote get-url origin                      # which hosting platform
gh auth status                                 # can we open PRs on GitHub?
```

From this, work out:

- **Production branch (`<prod>`)**: the value of `gitflow.branch.master` if configured; otherwise `main` if it exists locally or on the remote; otherwise `master`. If neither exists it will be `main` (Step 2). If both `main` and `master` exist and nothing says which one is production, ask the user.
- **Develop branch**: `gitflow.branch.develop` if configured, otherwise `develop`. Note whether it exists locally, only on the remote, or not at all.
- **Platform**: GitHub remotes use `gh` as shown in this file. For GitLab, Bitbucket, Azure DevOps, or when no CLI is authenticated, read `references/platforms.md`.
- **Uncommitted changes**: never discard them. `git switch -c <new-branch>` carries them onto the new branch. If switching would conflict with them, `git stash push -u`, switch, then `git stash pop`.

## Step 2 — Bootstrap missing long-lived branches

Both `<prod>` and `develop` must exist locally and on the remote before any other branch is created, because every other branch starts from one of them. Create them only when they are missing. Never recreate, reset or rename existing ones — in particular, don't rename `master` to `main` on your own, since that breaks other people's clones and CI configuration.

**Empty repository (no commits yet).** A branch needs a commit to point at, so create an empty root commit on `main`:

```bash
git symbolic-ref HEAD refs/heads/main
git rm -r -q --cached . 2>/dev/null || true    # unstage anything; files stay on disk
git commit --allow-empty -m "chore: initial commit"
git push -u origin main
```

This is the only time a commit goes straight onto `<prod>`. Any files already in the working tree stay uncommitted and go onto a feature branch afterwards, through a PR like any other work.

**`<prod>` exists, `develop` is missing:**

```bash
git switch <prod>
git pull --ff-only
git switch -c develop
git push -u origin develop
```

**`develop` exists only on the remote:** `git switch develop` creates a local tracking branch.

**`develop` exists but `<prod>` doesn't (unusual):** which commit counts as "production" is a judgment call, so don't guess. If there are release tags, propose creating `main` from the latest one; otherwise ask the user.

After bootstrapping, suggest (don't apply — they affect the whole team) two repository settings: make `develop` the default branch so new PRs target it automatically, and protect `<prod>` and `develop` so they only change through PRs with passing checks.

**The `git flow` CLI.** If it is installed you may use `git flow init -d` and `git flow <type> start`, but never `git flow <type> finish`: it merges locally and pushes straight to `<prod>`/`develop`, skipping review and CI. Every branch is finished through a pull request as described below.

## Step 3 — Do the work on a branch

```bash
git switch develop && git pull --ff-only   # for a hotfix, switch to <prod> instead
git switch -c feature/<name>
```

- Make small, logical commits. Follow the repository's commit message convention (look at `git log --oneline -20`; if it uses Conventional Commits, so do you).
- Push early with `git push -u origin HEAD` so the work is backed up and visible.
- To pick up new changes from `develop`, merge it in: `git fetch origin && git merge origin/develop`. Rebase only while the branch has not been pushed; after that, rewriting history forces collaborators to repair their clones. If you must rewrite a branch only you use, push with `--force-with-lease`, never `--force`, and never on `<prod>`, `develop`, `release/*` or `hotfix/*`.
- Run the project's tests and linters locally before opening the PR — it is faster than waiting for CI to tell you.

## Step 4 — Open the pull request

When a feature or fix is complete, opening the PR is part of finishing the task — do it without waiting to be asked. Choose the base from the branch model: `feature/*` and `bugfix/*` → `develop`; `release/*` and `hotfix/*` → `<prod>`. A feature or bugfix branch never targets `<prod>`, because that would ship unreleased work outside a release.

```bash
git push -u origin HEAD
gh pr view --json url,state 2>/dev/null        # does a PR for this branch already exist?
gh pr create --base develop --title "<title>" --body-file <body.md>
```

- If a PR already exists for the branch, push to it instead of opening a duplicate.
- **Title**: short and imperative, following the repository's convention (e.g. `feat: add OAuth login` with Conventional Commits). Release PRs are titled `Release X.Y.Z`, hotfix PRs `Hotfix X.Y.Z`.
- **Body**: if the repository has a PR template (`.github/pull_request_template.md` or `.github/PULL_REQUEST_TEMPLATE/`), fill it in. Otherwise include what changed and why, the notable changes, how it was tested, and linked issues (`Closes #87`).
- Use `--draft` when the user wants CI feedback before the work is ready for review.

## Step 5 — Wait for CI/CD to finish

A PR is not done when it is opened; it is done when its CI/CD has finished. Reporting success while checks are still running — or failing — hands broken work to reviewers and hides problems from the user. So after opening a PR, and after every push to it, wait until every check has completed.

Use the bundled script, located in `scripts/` next to this file:

```bash
<skill-dir>/scripts/wait-for-ci.sh --pr <number|url|branch>
```

It waits for checks to be registered (they can take a little while to appear after a push), polls until all of them have finished, prints a summary, and exits with `0` when everything passed, `1` when something failed or was cancelled, `2` when no checks appeared, and `3` on timeout. Run it with `--help` for the options. Without the script, `gh pr checks <pr> --watch --interval 30` also works, but right after a push it may report "no checks" before CI has started — wait a little and retry before concluding there is no CI.

Pipelines can be long. If your shell tool has a time limit shorter than the pipeline, run the script in the background or rerun it until it returns; it is safe to rerun. Don't stop waiting because it is slow. If the script hits its own timeout, tell the user what is still running and give them the link.

**If a check fails:**

1. Find out why: `gh pr checks <pr>` lists the checks with links; for GitHub Actions, `gh run view <run-id> --log-failed` shows the failing log.
2. Fix the root cause on the same branch. Don't skip, disable or weaken tests or checks to get to green, and don't use `[skip ci]` or `--no-verify`.
3. Commit, push, and wait again.
4. If the failure is unrelated to the change (flaky test, infrastructure outage, missing secret), tell the user and show the evidence. Re-running once with `gh run rerun <run-id> --failed` is reasonable for an obvious flake.

**If no checks appear (exit `2`):** look for CI configuration (`.github/workflows/`, `.gitlab-ci.yml`, …) and tell the user plainly that the PR has no CI, rather than calling it green.

Then report: the PR URL, head → base, and the final state of every check.

## Step 6 — Merging

- **Feature and bugfix PRs**: stop once CI is green and report back. Merging is the reviewers' call unless the user asked you to merge. When asked, use the repository's preferred method (`gh repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed`), e.g. `gh pr merge <pr> --squash --delete-branch`.
- **Release and hotfix PRs into `<prod>`, and their back-merges into `develop`**: merge with a merge commit (`gh pr merge <pr> --merge`). Squash or rebase would create new commits that the other long-lived branch never receives, so `<prod>` and `develop` drift apart and every later release conflicts. If the repository only allows squash merges, explain this to the user before going ahead.
- Don't bypass protections: no `gh pr merge --admin`, no merging with failing or pending checks, no working around required reviews. If a merge is blocked, report what is blocking it.
- Merging into `<prod>` or `develop` often triggers more pipelines (deployments, publishing). Wait for those too:

  ```bash
  git fetch origin
  <skill-dir>/scripts/wait-for-ci.sh --commit origin/<branch>
  ```

## Step 7 — Cutting a release

When the user asks for a release, run the whole sequence. Read `references/release-and-hotfix.md` for the details behind each step (version files per ecosystem, changelog, existing release automation, tag style, back-merge conflicts).

1. **Pick the version.** Look at the latest tags (`git tag --list --sort=-v:refname | head -5`) and what changed since (`git log --oneline <last-tag>..origin/develop`). Apply Semantic Versioning: breaking changes → major, new features → minor, only fixes → patch. If the user didn't give a version and the bump isn't obvious, propose one and confirm it — a pushed tag is hard to take back.
2. **Branch:** `git switch develop && git pull --ff-only && git switch -c release/X.Y.Z`.
3. **Prepare:** bump the version wherever the project declares it, update the changelog, commit (`chore(release): X.Y.Z`) and push. From now on only release fixes go on this branch; new features keep going to `develop` for the next release.
4. **PR into `<prod>`** titled `Release X.Y.Z`, with the release notes as the body. Wait for CI (Step 5) and fix any failure on the release branch.
5. **Merge** with a merge commit once checks are green and required approvals are in. Keep the release branch — the back-merge still needs it.
6. **Tag and publish**, unless the repository's automation already does this (check first):

   ```bash
   git switch <prod> && git pull --ff-only
   git tag -a vX.Y.Z -m "Release X.Y.Z"
   git push origin vX.Y.Z
   gh release create vX.Y.Z --title "vX.Y.Z" --notes-file <notes.md>
   ```

7. **Wait for the release pipelines** triggered by the merge and the tag: `<skill-dir>/scripts/wait-for-ci.sh --commit vX.Y.Z`.
8. **Back-merge:** open a PR `release/X.Y.Z` → `develop` so the version bump, changelog and release fixes reach `develop`. Wait for CI and merge it with a merge commit.
9. **Clean up:** once both PRs are merged, delete `release/X.Y.Z` locally and on the remote (`git branch -d release/X.Y.Z && git push origin --delete release/X.Y.Z`).

## Step 8 — Hotfixes

Same shape as a release, but starting from production:

1. `git switch <prod> && git pull --ff-only && git switch -c hotfix/X.Y.Z`, where `X.Y.Z` is a patch bump of the latest release.
2. Fix the bug, add a regression test, bump the version and update the changelog.
3. PR into `<prod>` titled `Hotfix X.Y.Z`, wait for CI, merge with a merge commit, then tag, publish and wait for pipelines exactly as in Step 7.
4. Back-merge: if a `release/*` branch is open, PR the hotfix into that release branch (it reaches `develop` when the release finishes); otherwise PR `hotfix/X.Y.Z` → `develop`. Wait for CI, merge, and delete the hotfix branch.

## Guardrails

These protect the team's shared history, so hold to them even when a shortcut looks harmless:

- `<prod>` and `develop` change only through merged pull requests. The bootstrap commit of an empty repository is the only exception.
- Never force-push `<prod>`, `develop`, `release/*` or `hotfix/*`. Never delete or move a pushed tag without the user's explicit approval — people and pipelines may already have consumed it.
- Don't bypass CI or branch protection: no `--admin` merges, `--no-verify`, `[skip ci]` or disabled tests.
- Don't change repository settings (default branch, branch protection, allowed merge methods) without asking.
- Don't delete branches you didn't create, or that still have open PRs.
- Don't lose uncommitted work when switching branches.

## Reporting back

After each phase, tell the user concretely what happened: the branch created, the PR URL with head → base, the CI result (naming any failing checks), and for releases the version, tag, release URL and back-merge PR. If something is still pending — waiting for review, CI still running — say so instead of implying it is finished.

## Bundled resources

- `scripts/wait-for-ci.sh` — waits for every check on a pull request (`--pr`) or every GitHub Actions run for a commit or tag (`--commit`).
- `references/release-and-hotfix.md` — read when cutting a release or hotfix: versioning, version files per ecosystem, changelog, release automation, tags, release candidates, back-merge conflicts, support branches, checklist.
- `references/platforms.md` — read when the remote is not GitHub or `gh` is unavailable: GitLab, Bitbucket, Azure DevOps and the no-CLI fallback.
