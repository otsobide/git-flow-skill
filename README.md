# git-flow skill

An [Agent Skill](https://agentskills.io) that teaches coding agents (Claude Code and other `SKILL.md`-compatible agents) to work with **Git Flow**:

- Creates `main`/`master` and `develop` when they don't exist yet.
- Uses the standard Git Flow branch prefixes: `feature/`, `bugfix/`, `release/`, `hotfix/`, `support/`.
- Opens a pull request into `develop` when a feature or fix is finished, and into `main` for releases and hotfixes.
- Waits for every CI/CD check to finish after opening a PR — and fixes failures — before reporting the work as done.
- Cuts releases end to end: version bump, changelog, release PR, tag, release notes, back-merge into `develop`.

## Layout

```
skills/git-flow/
├── SKILL.md                      # the workflow the agent follows
├── references/
│   ├── release-and-hotfix.md     # versioning, changelog, tags, release automation, back-merges
│   └── platforms.md              # GitLab, Azure DevOps, Bitbucket, no-CLI fallback
└── scripts/
    └── wait-for-ci.sh            # waits for PR checks or post-merge/tag pipelines to finish
```

## Installation

### Claude Code

For all your projects:

```bash
git clone https://github.com/otsobide/git-flow-skill.git
mkdir -p ~/.claude/skills
cp -r git-flow-skill/skills/git-flow ~/.claude/skills/
```

For a single project, copy `skills/git-flow` to `.claude/skills/git-flow` inside that repository and commit it, so everyone working on the project gets the same workflow.

### Other agents

Copy `skills/git-flow` into the skills directory of any agent that supports the Agent Skills (`SKILL.md`) format.

## Requirements

- `git`
- [GitHub CLI](https://cli.github.com) (`gh`), authenticated with `gh auth login`, to open pull requests, watch checks and publish releases on GitHub. For other platforms see [`references/platforms.md`](skills/git-flow/references/platforms.md).

## Usage

The skill activates on its own when you ask the agent for branch, pull request or release work. In Claude Code you can also invoke it explicitly with `/git-flow`.

| You say | The agent does |
|---|---|
| "Add a password reset endpoint" | `feature/password-reset` from `develop` → PR into `develop` → waits for CI |
| "The cart total rounds wrong on develop, fix it" | `bugfix/cart-total-rounding` from `develop` → PR into `develop` → waits for CI |
| "Release 2.3.0" | `release/2.3.0` → PR into `main` → waits for CI → merge → tag `v2.3.0` → GitHub release → back-merge PR into `develop` |
| "Checkout is broken in production, hotfix it" | `hotfix/2.3.1` from `main` → PR into `main` → waits for CI → merge → tag → release → back-merge |

### `wait-for-ci.sh`

The bundled script can also be used on its own:

```bash
skills/git-flow/scripts/wait-for-ci.sh --pr 42            # all checks on PR #42
skills/git-flow/scripts/wait-for-ci.sh --commit v2.3.0    # pipelines triggered by a merge or tag
skills/git-flow/scripts/wait-for-ci.sh --help
```

Exit codes: `0` all passed, `1` something failed, `2` no checks found, `3` timed out, `4` usage error.
