# Git Flow

An [Agent Skill](https://agentskills.io) that makes coding agents such as Claude Code follow **Git Flow** whenever they work with branches, pull requests or releases.

## What it does

- Creates `main`/`master` and `develop` if they don't exist.
- Names branches with the standard prefixes: `feature/`, `bugfix/`, `release/`, `hotfix/`, `support/`.
- Opens PRs into `develop` for features and fixes, and into `main` for releases and hotfixes.
- Waits for all CI/CD checks to finish after opening a PR, and fixes failures.
- Cuts releases: version bump, changelog, tag, release notes and back-merge into `develop`.

## Installation

Clone the repository into your skills directory as `git-flow`:

```bash
git clone https://github.com/otsobide/git-flow-skill.git ~/.claude/skills/git-flow
```

To install it for a single project, clone it into `.claude/skills/git-flow` inside that project instead.

Requires `git` and the [GitHub CLI](https://cli.github.com) (`gh`), logged in with `gh auth login`.
