# Git Flow

An [Agent Skill](https://agentskills.io) that makes coding agents such as Claude Code follow **Git Flow** whenever they work with branches, pull requests or releases.

## What it does

- Creates `main`/`master` and `develop` if they don't exist.
- Names branches with the standard prefixes: `feature/`, `bugfix/`, `release/`, `hotfix/`, `support/`.
- Opens PRs into `develop` for features and fixes, and into `main` for releases and hotfixes.
- Waits for all CI/CD checks to finish after opening a PR, and fixes failures.
- Cuts releases: version bump, changelog, tag, release notes and back-merge into `develop`.

## Installation

The skill lives in [`skills/git-flow`](skills/git-flow). Copy that folder into your skills directory:

```bash
git clone https://github.com/otsobide/git-flow-skill.git
cp -r git-flow-skill/skills/git-flow ~/.claude/skills/
```

To install it for a single project, copy it into `.claude/skills/` inside that project instead.

Requires `git` and the [GitHub CLI](https://cli.github.com) (`gh`), logged in with `gh auth login`.
