---
name: docs-accuracy-review
description: "Review all docstrings, JSDoc, markdown docs, README files, and API documentation in a PR to verify they still accurately describe the code after changes. Use this skill whenever the user mentions checking docs, reviewing documentation accuracy, auditing docstrings, verifying docs match code, doc drift, stale docs, or anything about making sure documentation is still correct after code changes. Also trigger when the user says things like 'check the docs', 'are the docs still right', 'review docs in this PR', 'docs audit', or 'make sure documentation is up to date'."
---

# Docs Accuracy Review

Code changes leave documentation behind — a renamed parameter, a changed return type, a removed function still mentioned in the README. This skill finds and fixes those mismatches in a PR.

## Severity framework

Every finding MUST be classified into exactly one of these three categories. This classification drives triage priority — get it right.

**Critical** — docs that are factually wrong. Wrong parameter names, incorrect return types, describes behavior the code no longer performs:
> `src/auth/login.ts:15` — JSDoc says `@param {string} token` but parameter was renamed to `sessionId` in this PR.

**Stale** — docs that are outdated but not completely wrong. Missing new parameters, incomplete descriptions, references to old flags:
> `README.md:42` — Usage example still shows the old `--verbose` flag which was replaced by `--log-level`.

**Missing** — new public API surface with no documentation:
> `src/api/handlers.ts:88` — New exported function `validateWebhook()` has no JSDoc.

## What counts as documentation

Cast a wide net — all of these can go stale:

- **Code docstrings** — Python docstrings, JSDoc/TSDoc, Javadoc, Go doc comments, Rust doc comments, Ruby YARD/RDoc
- **Markdown files** — README.md, CONTRIBUTING.md, anything in a `docs/` directory
- **Inline comments** — only the ones that describe behavior (skip noise like `// increment counter`)
- **API docs** — OpenAPI/Swagger specs, GraphQL schema descriptions
- **Type annotations with doc comments** — TypeScript interfaces, Pydantic field descriptions, Rust structs
- **Config file comments** — explanatory comments in YAML, TOML, etc.
- **Changelog entries** — if the PR adds one, verify it matches what actually changed
- **UI strings** — user-facing text in modals, tooltips, or help text that describes system behavior

## Step 1: Understand what changed

Get the full picture of the PR's code changes before judging any documentation.

```bash
# If on a feature branch with a PR
gh pr diff --name-only 2>/dev/null || git diff main --name-only

# Get the actual diff
gh pr diff 2>/dev/null || git diff main
```

Build a checklist of significant changes:
- Functions/methods added, removed, renamed, or with changed signatures
- Classes or modules with changed behavior
- Configuration options, environment variables, or CLI flags that changed
- API endpoints, request/response shapes, or error codes that changed
- Merge conflict risks — if the PR branch is behind main and the same functions were modified on both, flag it

## Step 2: Audit docs in changed files

For every file in the diff, read the **full file** — not just the diff hunks. Docstrings above unchanged functions may reference changed ones.

For each docstring/doc comment, verify:
- **Parameter names and types** match the actual signature
- **Return type/value descriptions** match what the code actually returns
- **Behavior descriptions** match what the code actually does
- **Examples** (if any) still work with the current code
- **Raises/Throws** documentation lists the actual exceptions
- **@deprecated/@since/@version** tags are accurate
- **Cross-references** to other functions/classes still point to things that exist

## Step 3: Hunt for stale docs outside the diff

This is where most doc rot hides — the PR changed a function, but the README still describes the old behavior.

For each significant change from Step 1, search the repo for references:

```bash
# Search for mentions of changed function/class/variable names
# Use both old and new names if something was renamed
rg "oldFunctionName" --type md --type txt
rg "oldFunctionName" -g "*.rst" -g "*.adoc"

# Search in code comments too — other files may reference the changed code
rg "oldFunctionName" --type-add 'code:*.{py,js,ts,java,go,rs,rb}' --type code
```

Also check these common locations:
- `README.md` at repo root and in relevant subdirectories
- `docs/` directory (if it exists)
- `CONTRIBUTING.md`, `ARCHITECTURE.md`, `CHANGELOG.md`
- OpenAPI/Swagger specs (`openapi.yaml`, `swagger.json`, etc.)
- Any `.md` files in the same directory as changed code

## Step 4: Report and fix

Present findings grouped by severity (Critical → Stale → Missing) with a summary table:

| # | Severity | Location | Issue |
|---|----------|----------|-------|
| 1 | Critical | `file:line` | Description |
| 2 | Stale | `file:line` | Description |

Each finding MUST include:
- Exact file path and line number
- What the doc currently says vs what it should say
- Why it's wrong (which code change made it inaccurate)

After the report, fix every Critical and Stale issue. For Missing docs, write new documentation that follows the conventions already established in the file/project — match the existing style.

## Step 5: Self-check

Before finishing, verify fixes are correct:

1. Re-read each file you modified — confirm the new docs match the code
2. If the project has a doc linter (`pydocstyle`, `eslint-plugin-jsdoc`, `tsc --strict`), run it
3. Confirm you didn't introduce new issues while fixing old ones (e.g., a cross-reference you added actually resolves)

## Scope boundaries

Stay focused on accuracy. Do NOT:
- Rewrite docs that are already accurate just because you'd phrase them differently
- Add documentation to private/internal APIs unless the project convention documents those
- Change doc style (e.g., converting Google-style docstrings to numpy-style)
- Fix code bugs — flag them in the report but only fix the documentation
