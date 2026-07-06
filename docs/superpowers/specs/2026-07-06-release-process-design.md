# Automated Release Process (release-please + Conventional Commits)

**Date:** 2026-07-06
**Status:** Approved — ready for implementation plan

## Summary

Introduce an automated, Conventional-Commits-driven release process for
`gcp-ent-deploy-role` using [release-please](https://github.com/googleapis/release-please)
in manifest mode, plus a PR-title lint gate that enforces Conventional Commits on
exactly the text release-please consumes.

This is a direct adaptation of the process already designed for
[`aws-ent-deploy-role`](https://github.com/ent-security/aws-ent-deploy-role). The
core difference: `aws-ent-deploy-role` publishes a CloudFormation template to
S3/CloudFront on release, so its release workflow chains a publish job. **This repo
has no published artifact** — it is a Terraform + gcloud module that consumers
pin by git ref (`source = "git::…/gcp-ent-deploy-role//terraform?ref=vX.Y.Z"`), so
the **git tag + GitHub Release _is_ the deliverable**. The release workflow
therefore runs release-please only; there is no publish job and no `publish.yml`.

The repository is **one logical product** (the Ent GCP deploy role) expressed as a
Terraform/OpenTofu module plus an equivalent `gcloud` bootstrap script. It is
versioned with a **single repo-wide semver**.

## Motivation

- There is no release automation, no `CHANGELOG`, and **no git tags at all**, yet
  the README instructs consumers to pin `ref=v1.0.0` for production. The promised
  baseline tag does not exist.
- Commit/PR-title style is mixed (`Add …`, `Fix …`, `Grant …`), so there is no
  machine-readable signal for what changed or how to bump the version. The
  per-release "what permissions were added/removed/renamed" audit the README
  promises is done by hand today.
- The repo currently merges PRs with merge commits, so no single commit message is
  a reliable release signal.

## Goals

- One repo-wide semver, one CHANGELOG, one release PR.
- Releases driven entirely by Conventional Commits on merged PR titles.
- Enforce Conventional Commits via a required PR-title check (squash-merge makes
  the PR title *the* release commit).
- Cutting a release produces a git tag `vX.Y.Z` + GitHub Release that consumers pin
  — **no new artifact store, no new secrets** beyond the release-please GitHub App
  already used by `aws-ent-deploy-role`.
- Establish the real `v1.0.0` tag the README already references (Option B).

## Non-Goals

- No published artifact (no S3/GCS/CloudFront/registry). The git tag + release
  notes are the deliverable. (This is where the AWS design's `publish.yml` and
  chained publish job are dropped.)
- No per-language / per-directory independent versioning (single version only).
- No Terraform CI (`terraform validate`/`fmt`/policy tests). The repo has no CI
  today; adding it is a separate concern, explicitly out of scope here.
- No local commitlint / Husky hooks (squash-merge discards individual commit
  messages; only the PR title matters).

## Decisions (from brainstorming)

1. **Scope:** single repo-wide version — one tag `vX.Y.Z`, one CHANGELOG, one
   release PR.
2. **Baseline (Option B):** seed `version.txt` and the manifest at `1.0.0` anchored
   at current `main` HEAD (`8ee884bd58ca4cc9f4287df60054f50849db5706`), **and** cut
   a real `v1.0.0` tag + GitHub Release at that same SHA as an operator step. This
   makes the README's `ref=v1.0.0` real and gives release-please a clean floor.
   The next Conventional-Commit PR after this lands drives the first *managed*
   bump.
3. **Enforcement:** PR-title lint as a required check; pair with GitHub's "default
   to PR title" squash setting. No local hooks. (This repo currently uses merge
   commits and must switch to squash-merge — an operator step.)
4. **Release workflow:** release-please only. No publish job — there is nothing to
   publish. The tag/GitHub Release is the artifact.
5. **Auth:** the release workflow authenticates as a **GitHub App**, mirroring
   `aws-ent-deploy-role`, because the `ent-security` org disables "Allow GitHub
   Actions to create and approve pull requests" (that org policy governs only the
   automatic `GITHUB_TOKEN`, not an App identity).

## Release flow

```
PR merged to main (squash; PR title = Conventional Commit)
        │
        ▼
release-please.yml (on: push to main)
   └─ opens/updates a "release PR": bumps version.txt + manifest,
      regenerates CHANGELOG.md from the conventional commits
        │
   maintainer merges the release PR
        │
        ▼
release-please creates tag vX.Y.Z + GitHub Release
        │
        ▼
   consumers pin  source = "…/gcp-ent-deploy-role//terraform?ref=vX.Y.Z"
```

`fix:` → patch, `feat:` → minor, `feat!:` / `BREAKING CHANGE:` → major.

## Components / files

### New: `release-please-config.json` (repo root)

`release-type: simple` (no language package — maintains `version.txt` + CHANGELOG),
single root package, plain `vX.Y.Z` tags, explicit changelog sections, and the
baseline anchor.

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "release-type": "simple",
  "include-component-in-tag": false,
  "last-release-sha": "8ee884bd58ca4cc9f4287df60054f50849db5706",
  "changelog-sections": [
    { "type": "feat", "section": "Features" },
    { "type": "fix", "section": "Bug Fixes" },
    { "type": "perf", "section": "Performance Improvements" },
    { "type": "deps", "section": "Dependencies" },
    { "type": "revert", "section": "Reverts" },
    { "type": "docs", "section": "Documentation", "hidden": true },
    { "type": "chore", "section": "Miscellaneous Chores", "hidden": true },
    { "type": "refactor", "section": "Code Refactoring", "hidden": true },
    { "type": "test", "section": "Tests", "hidden": true },
    { "type": "build", "section": "Build System", "hidden": true },
    { "type": "ci", "section": "Continuous Integration", "hidden": true },
    { "type": "style", "section": "Styles", "hidden": true }
  ],
  "packages": {
    ".": { "package-name": "gcp-ent-deploy-role" }
  }
}
```

- `include-component-in-tag: false` → tags are `v1.1.0`, not
  `gcp-ent-deploy-role-v1.1.0`. Matches the `v*` convention the README's `ref=`
  pins already assume.
- `last-release-sha` = current `main` HEAD and **the same commit the `v1.0.0` tag
  points at** (Option B). The manifest seeds `1.0.0` as already-released, so this
  is not an initial release; `last-release-sha` is the scan boundary that keeps the
  first managed CHANGELOG from ingesting all pre-existing history.

### New: `.release-please-manifest.json` (repo root)

```json
{
  ".": "1.0.0"
}
```

### New: `version.txt` (repo root)

The `simple` release type tracks the version in `version.txt`. Seed it to match the
manifest; release-please rewrites it on each release.

```
1.0.0
```

### New: `.github/workflows/release-please.yml`

Release-please only. No `outputs` block and no publish job (nothing consumes them;
there is nothing to publish).

```yaml
name: Release

on:
  push:
    branches: [main]

permissions: {}

jobs:
  release-please:
    runs-on: ubuntu-latest
    permissions:
      contents: write          # create the release commit, tag, and GitHub Release
      pull-requests: write      # open/update the release PR
    steps:
      # The org disables "Allow GitHub Actions to create and approve pull requests",
      # so the default GITHUB_TOKEN cannot open release-please's release PR. We
      # authenticate as a GitHub App instead — that restriction governs only the
      # automatic GITHUB_TOKEN, not an App identity.
      - uses: actions/create-github-app-token@v3
        id: app-token
        with:
          app-id: ${{ vars.RELEASE_PLEASE_APP_ID }}
          private-key: ${{ secrets.RELEASE_PLEASE_APP_PRIVATE_KEY }}
      - uses: googleapis/release-please-action@v4
        id: release
        with:
          token: ${{ steps.app-token.outputs.token }}
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json
```

### New: `.github/workflows/pr-title-lint.yml`

Validates every PR title against Conventional Commits — the exact text
release-please consumes under squash-merge. Posts a sticky comment on failure.
Job name `lint-pr-title` is the status-check context branch protection requires.

```yaml
name: Lint PR title

on:
  pull_request:
    types: [opened, edited, reopened, synchronize]

permissions:
  pull-requests: write       # read the PR title; write the sticky failure comment

jobs:
  lint-pr-title:
    runs-on: ubuntu-latest
    steps:
      - uses: amannn/action-semantic-pull-request@v6
        id: lint
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          types: |
            feat
            fix
            perf
            deps
            docs
            chore
            refactor
            test
            build
            ci
            style
            revert
          requireScope: false

      - if: always() && steps.lint.outputs.error_message != ''
        uses: marocchino/sticky-pull-request-comment@v2
        with:
          header: pr-title-lint
          message: |
            ## ⚠ This PR title is not a valid Conventional Commit

            ```
            ${{ steps.lint.outputs.error_message }}
            ```

            Use `type(optional-scope): summary`, e.g. `fix(terraform): correct IAM condition`.
            Allowed types: feat, fix, perf, deps, docs, chore, refactor, test, build, ci, style, revert.
            See CONTRIBUTING.md.

      - if: steps.lint.outputs.error_message == ''
        uses: marocchino/sticky-pull-request-comment@v2
        with:
          header: pr-title-lint
          delete: true
```

`amannn/action-semantic-pull-request` is pinned at **v6** (current major). It sets
a check status that branch protection can require.

### New: `CONTRIBUTING.md`

Documents:

- Conventional Commits format: `type(optional-scope): summary`.
- **Squash-merge → the PR title is the release commit.** Write PR titles as
  Conventional Commits; individual commit messages on the branch don't matter.
- Allowed types table (mirrors `changelog-sections`): `feat`, `fix`, `perf`,
  `deps`, `revert` are visible in the changelog; `feat!`/`BREAKING CHANGE:` →
  major; `docs`/`chore`/`refactor`/`test`/`build`/`ci`/`style` are allowed but
  hidden.
- Recommended (optional, free-form) scopes mapped to this repo's layout:
  `terraform`, `gcloud`, `roles`, `apis`, `docs`, `ci`.
- How releases work: merge feature PRs → release-please maintains a release PR →
  merge the release PR → tag + GitHub Release; consumers pin `ref=vX.Y.Z`. No
  publish step.

## Conventional Commit types

| Type | Changelog section | Version bump |
|------|-------------------|--------------|
| `feat` | Features | minor |
| `fix` | Bug Fixes | patch |
| `perf` | Performance Improvements | patch |
| `deps` | Dependencies | patch |
| `revert` | Reverts | patch |
| `docs`, `chore`, `refactor`, `test`, `build`, `ci`, `style` | hidden | none |
| `feat!` / `fix!` / `BREAKING CHANGE:` footer | ⚠ Breaking (under its type) | major |

Scopes are validated only for *format*, not against a fixed list
(`requireScope: false`).

## Manual repository settings (cannot be set in code — implementation checklist)

Do these **after** the setup PR merges to `main`. They are required for the process
to function.

1. **GitHub App for release-please.** Install the same `RELEASE_PLEASE_APP` used by
   `aws-ent-deploy-role` (org `ent-security`) on this repo, and set repo **variable**
   `RELEASE_PLEASE_APP_ID` + **secret** `RELEASE_PLEASE_APP_PRIVATE_KEY` (App needs
   Contents + Pull requests: write). The org disables the "Allow GitHub Actions to
   create and approve pull requests" toggle, so the default `GITHUB_TOKEN` path is
   not available.
2. **Squash-merge default.** Settings → General → Pull Requests: enable "Allow
   squash merging" and set the squash-merge commit message to **"Default to pull
   request title."** This repo currently uses merge commits; this switch makes the
   squashed commit subject equal the validated PR title release-please parses.
3. **Branch protection on `main`:** require a PR before merging and mark the
   **`lint-pr-title`** status check **required** (it appears in the check search box
   once the workflow has run on a PR). If the repo uses Rulesets, do the same under
   Settings → Rules → Rulesets.
4. **Cut `v1.0.0` (Option B).** Create the tag + GitHub Release at
   `8ee884bd58ca4cc9f4287df60054f50849db5706` (current `main` HEAD, the same SHA as
   `last-release-sha`), e.g.:
   ```bash
   gh release create v1.0.0 --target 8ee884bd58ca4cc9f4287df60054f50849db5706 \
     --title "v1.0.0" --notes "Initial tagged release of the Ent GCP deploy role."
   ```
   Anchoring the tag to the same SHA as `last-release-sha` keeps release-please's
   history scan consistent.

## Behavior changes to call out

- PRs must be squash-merged with Conventional-Commit titles; the repo moves off its
  current merge-commit habit.
- The first managed release will be `v1.0.1` / `v1.1.0` / `v2.0.0` depending on the
  first Conventional-Commit PR merged after this lands. The setup PR itself is
  titled with a non-releasing type (`ci: add release-please and Conventional Commits
  release process`) so it does not, on its own, force an immediate release.

## Verification

- **Static:** both JSON config files validate against their schema (`jq empty`) and
  key values are asserted; both workflow YAML files pass `actionlint` with zero
  errors.
- **Smoke test (documented, post-merge):**
  1. Open a PR with a bad title → confirm `lint-pr-title` fails and blocks merge;
     rename to a valid `fix(...)` title → confirm it passes.
  2. Merge a `fix:`/`feat:` PR → confirm release-please opens a release PR proposing
     the expected bump and a CHANGELOG entry.
  3. Merge the release PR → confirm tag `vX.Y.Z` + GitHub Release are created.

## Risks / mitigations

- **Org policy blocks the default token from opening the release PR:** mitigated by
  the GitHub App auth (same App as `aws-ent-deploy-role`).
- **No tags exist / README promises `v1.0.0`:** mitigated by Option B — cut a real
  `v1.0.0` at the baseline SHA, aligned with `last-release-sha`.
- **Repo currently uses merge commits:** mitigated by the squash-merge operator
  step; without it, non-conventional per-commit messages would be what
  release-please parses.
- **Setup PR accidentally triggering a release:** mitigated by titling it with a
  non-releasing `ci:` type.
