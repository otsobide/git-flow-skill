# Other hosting platforms

The Git Flow branch model, naming and order of steps are the same everywhere; only the commands for pull requests, CI and releases change. Detect the platform from `git remote get-url origin`.

`scripts/wait-for-ci.sh` only works with GitHub. On other platforms, use the platform's own way of watching pipelines below — the rule of waiting for every check to finish before reporting the work as done still applies.

## GitLab (`glab`)

GitLab calls pull requests *merge requests* (MRs).

| Step | Command |
|---|---|
| Check authentication | `glab auth status` |
| Find an existing MR for the branch | `glab mr list --source-branch feature/x` |
| Open an MR | `glab mr create --source-branch feature/x --target-branch develop --title "..." --description "..."` (add `--draft` if needed) |
| Watch the pipeline until it finishes | `glab ci status --branch feature/x --live` |
| Read a failed job's log | `glab ci trace <job-id>` |
| Retry a failed job | `glab ci retry <job-id>` |
| Merge a release or hotfix MR | `glab mr merge <id> --yes` (no `--squash`, so it creates a merge commit) |
| Publish a release | `glab release create vX.Y.Z --name "vX.Y.Z" --notes-file notes.md` |

Protected branches in GitLab play the role of GitHub branch protection: don't unprotect them to get a merge through.

## Azure DevOps (`az repos`, `az pipelines`)

| Step | Command |
|---|---|
| Open a PR | `az repos pr create --source-branch feature/x --target-branch develop --title "..." --description "..."` |
| Check build validation and other policies | `az repos pr policy list --id <pr-id> --output table` |
| List pipeline runs for the branch | `az pipelines runs list --branch feature/x --output table` |
| Complete (merge) a PR | `az repos pr update --id <pr-id> --status completed` |

For release and hotfix PRs, make sure squash merging is off so a merge commit is created.

## Bitbucket Cloud

There is no official CLI.

- Push the branch; `git push` prints a link to create the pull request. Give that link to the user together with the destination branch (`develop` or `<prod>`).
- Bitbucket Pipelines status is visible on the PR page. If API credentials are available in the environment, `GET https://api.bitbucket.org/2.0/repositories/<workspace>/<repo>/commit/<sha>/statuses` returns the build statuses for a commit. Otherwise ask the user to confirm when the pipeline has finished.

## No CLI available, or not authenticated

1. Push the branch as usual.
2. Give the user a link that opens the PR with the right base:
   - GitHub: `https://github.com/<owner>/<repo>/compare/<base>...<branch>?expand=1`
   - GitLab: `https://gitlab.com/<group>/<project>/-/merge_requests/new?merge_request[source_branch]=<branch>&merge_request[target_branch]=<base>`
   - Bitbucket and Azure DevOps: the link printed by `git push`, or the repository's "Create pull request" page.
3. Say plainly that you could not open the PR or watch CI and why (for example "`gh` is not authenticated; run `gh auth login`"), so the user knows that waiting for CI is now their step. Don't claim that a PR was created or that CI passed.
