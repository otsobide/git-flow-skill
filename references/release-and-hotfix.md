# Releases and hotfixes in depth

Read the section you need; `SKILL.md` has the overall sequence.

## Contents

1. Choosing the version
2. Where the version lives
3. Changelog and release notes
4. Release automation already in the repository
5. Tags
6. Release candidates
7. Back-merges and conflicts
8. Support branches
9. Checklist

## 1. Choosing the version

Semantic Versioning, `MAJOR.MINOR.PATCH`:

- **MAJOR** — an incompatible change to the public API or behaviour (`feat!:` / `fix!:` or a `BREAKING CHANGE:` footer in Conventional Commits).
- **MINOR** — new, backwards-compatible functionality (`feat:`).
- **PATCH** — backwards-compatible fixes only (`fix:`, `perf:`). Hotfixes are almost always patch releases.
- Before `1.0.0`, many projects ship breaking changes as minor bumps; follow the project's history.

Finding the current version and what a release would contain:

```bash
git tag --list --sort=-v:refname | head -5     # latest tags
git describe --tags --abbrev=0 origin/<prod>    # latest tag reachable from production
git log --oneline <last-tag>..origin/develop    # commits the release would ship
```

If there are no tags yet, use the version declared in the project files. If there is none, propose `0.1.0` (or `1.0.0` if the project is already used in production) and confirm with the user.

If the project uses another scheme (CalVer such as `2026.11.0`, a build number, …), keep its scheme.

## 2. Where the version lives

Bump every place the project declares its own version, on the release or hotfix branch, in a single commit.

| Ecosystem | Where | How |
|---|---|---|
| Node.js | `package.json` and lockfile | `npm version X.Y.Z --no-git-tag-version` |
| Python | `pyproject.toml`, sometimes `__version__` in `__init__.py` | edit, or `uv version X.Y.Z` / `poetry version X.Y.Z` / `hatch version X.Y.Z` |
| Rust | `Cargo.toml` and `Cargo.lock` | edit `Cargo.toml`, then `cargo check` to refresh the lockfile |
| Maven | `pom.xml` | `mvn versions:set -DnewVersion=X.Y.Z -DgenerateBackupPoms=false` |
| Gradle | `build.gradle(.kts)` or `gradle.properties` | edit `version` |
| .NET | `.csproj` or `Directory.Build.props` | edit `<Version>` |
| Ruby | `lib/<gem>/version.rb` | edit `VERSION` |
| Helm | `Chart.yaml` | edit `version` (and `appVersion` if it tracks the app) |
| Go | the git tag itself | nothing to bump unless the code has a version constant |
| Anything | a `VERSION` file | edit |

Afterwards, `git grep -n "<old-version>"` catches leftovers such as install snippets in docs. Only change the ones that refer to the project's own current version, not dependency versions that happen to match.

## 3. Changelog and release notes

- If `CHANGELOG.md` exists, follow its format. With [Keep a Changelog](https://keepachangelog.com): rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD`, add a fresh empty `## [Unreleased]` above it, and update the compare links at the bottom if the file has them.
- If there is no changelog, don't create one unless the user wants it; the release notes on the hosting platform carry the information.
- Release notes are for users: group them (Added / Changed / Fixed / Removed / Security), lead with breaking changes and upgrade steps, and link the PRs. Take them from the changelog section, or let GitHub draft them from merged PRs with `gh release create vX.Y.Z --generate-notes` and then tidy them up.

## 4. Release automation already in the repository

Before bumping, tagging or publishing by hand, check whether the repository already does it:

```bash
ls .github/workflows/ 2>/dev/null
grep -rlE 'release-please|semantic-release|changesets|goreleaser|action-gh-release|gh release create|tags:' .github/workflows/ 2>/dev/null
ls .releaserc* release.config.* release-please-config.json .changeset 2>/dev/null
```

- **A workflow tags or creates the release when `<prod>` is pushed** → merge the release PR, wait for it (`wait-for-ci.sh --commit origin/<prod>`), then confirm the tag and release exist (`gh release view vX.Y.Z`). Don't create a second tag or release.
- **A workflow builds or publishes when a tag is pushed** (`on: push: tags:`) → you push the tag; the workflow publishes. Wait for it with `wait-for-ci.sh --commit vX.Y.Z`. If that workflow also creates the GitHub release, skip `gh release create`.
- **release-please, semantic-release or changesets** manage the version and changelog themselves. Don't bump or edit them by hand; let the tool do it, keep the Git Flow branch targets, and tell the user where the tool's flow and Git Flow differ.

## 5. Tags

- Match the existing style (`v1.2.3` or `1.2.3`): `git tag --list --sort=-v:refname | head`.
- Use annotated tags: `git tag -a vX.Y.Z -m "Release X.Y.Z"`. If the repository signs its tags (`git config tag.gpgSign` is `true`, or existing tags verify with `git tag -v <tag>`), use `git tag -s` instead.
- Tag the merge commit on `<prod>` after the release PR is merged, not a commit on the release branch: the tag must point at exactly what is in production. Release candidates (section 6) are the exception.
- Push only that tag (`git push origin vX.Y.Z`), never `git push --tags`, which would also publish any stray local tags.
- A pushed tag may already have triggered publishing. If it turns out to be wrong, stop and ask the user rather than deleting or moving it.

## 6. Release candidates

Only if the project already uses them or the user asks. Tag the release branch head as `vX.Y.Z-rc.1`, `-rc.2`, … and publish them as pre-releases:

```bash
git tag -a vX.Y.Z-rc.1 -m "Release candidate X.Y.Z-rc.1"
git push origin vX.Y.Z-rc.1
gh release create vX.Y.Z-rc.1 --prerelease --title "vX.Y.Z-rc.1" --notes-file <notes.md>
```

The final `vX.Y.Z` tag still goes on the `<prod>` merge commit.

## 7. Back-merges and conflicts

After a release or hotfix is merged into `<prod>`, `develop` needs the same changes (version bump, changelog, fixes made on the release branch). Open a PR from the release or hotfix branch into `develop`, wait for CI, and merge it with a merge commit — never a squash, for the reason given in `SKILL.md` Step 6.

If a hotfix ships while a release branch is open, PR the hotfix into that release branch instead; the release's own back-merge carries it to `develop`. If `develop` needs the fix sooner than the release will ship, ask the user whether to also back-merge it into `develop` directly.

Back-merge PRs often conflict in version files and the changelog, because `develop` has moved on. `develop` is protected, so resolve on the release (or hotfix) branch:

```bash
git switch release/X.Y.Z && git pull --ff-only
git merge origin/develop
# Resolve: keep develop's newer work, plus the release's changelog entry and version.
# If develop already carries a higher pre-release version (e.g. X.Y+1.0-dev), keep develop's.
git commit
git push
```

The PR into `<prod>` is already merged, so pushing to the release branch only updates the back-merge PR. Wait for its CI again before merging.

## 8. Support branches

Only for projects that maintain an older major version alongside the current one, and only when the user asks for it:

```bash
git switch -c support/1.x v1.9.3
git push -u origin support/1.x
```

Hotfixes for that line branch off `support/1.x` (e.g. `hotfix/1.9.4`), go back into `support/1.x` through a PR, and are tagged there. They are not merged into `<prod>`; if the fix also applies to the current version, port it with its own `hotfix/` or `bugfix/` branch.

## 9. Checklist

Release:

- [ ] Version chosen (and confirmed with the user if it wasn't obvious)
- [ ] `release/X.Y.Z` created from an up-to-date `develop`
- [ ] Version bumped everywhere, changelog updated, branch pushed
- [ ] PR into `<prod>` opened; every CI check finished and passed
- [ ] Merged with a merge commit, required approvals respected
- [ ] Tag `vX.Y.Z` on the merge commit (or created by the repository's automation)
- [ ] Release published with notes
- [ ] Pipelines triggered by the merge and the tag finished and passed
- [ ] Back-merge PR into `develop` opened, CI finished and passed, merged
- [ ] Release branch deleted locally and on the remote
- [ ] User told the version, tag, release URL, PR links and pipeline results

A hotfix follows the same list, starting from `<prod>` with a patch version and back-merging as described in section 7.
