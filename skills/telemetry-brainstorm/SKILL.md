---
name: telemetry-brainstorm
description: Use when deciding how a feature, PR, or diff will be measured in production — "what telemetry does this need", "how will we know it works", "how would we spot this breaking", "add metrics/monitoring/alerts", "is this observable" — either before implementation or against existing changes.
---

# Telemetry Brainstorm

Produce a signal for every way this change can fail, and evidence that those signals actually fire.

Two things this exists to prevent:

- Shipping a feature where nobody can tell whether it worked.
- Shipping metrics nobody ever looks at.

Both are failures. The plan must end with fewer signals than you first thought of.

**Scope lock.** This skill reads the repo and writes exactly one file, under `.context/telemetry/`. It changes no production code, adds no dependency, and creates no dashboard or monitor. Producing the plan is the whole job.

## Step 0 — Pick the mode

Run both, stop at the first with content:

1. `git diff HEAD`
2. `git diff main...HEAD`

- Both empty → **PLAN MODE**. Work from the feature description. If the user has not described the feature, ask once for the description and the ticket, then continue.
- Either has content → **AUDIT MODE**. That diff is the subject.

State the mode and the evidence in one line: `AUDIT MODE — 7 files changed in git diff main...HEAD`. The user can override.

If the diff touches more than roughly 40 files, or spans work that is clearly several unrelated changes, STOP and ask which slice to plan telemetry for. A 60-row table covering four features is not a plan; nobody reads it.

## Step 1 — The claim

Fill this in out loud before anything else:

> This works if ______ changes. It has failed if ______.

Rules:

- Both blanks name something observable from outside the process — a rate, a count, a latency, a user action. NEVER "the code runs correctly".
- One sentence, present tense, no hedging.
- If you cannot fill it from the diff or the description, ask the user. Do not guess the purpose of a feature.

Every signal proposed later must trace back to this sentence. In Step 5 you cut the ones that cannot.

**Checkpoint: output the claim. Do not proceed without it.**

## Step 2 — Learn how this repo emits

Read `references/stack-idioms.md`. If the repo is listed there, use its primitives verbatim.

If it is not listed, discover them:

```bash
grep -rIoh --include="*.rb" --include="*.ts" --include="*.tsx" --include="*.py" --include="*.go" -E "(statsd|StatsD|Datadog|datadog|analytics\.track|addAction|addError|OpenTelemetry|tracer\.|logger\.(info|warn|error))" . --exclude-dir=node_modules --exclude-dir=.git | sort | uniq -c | sort -rn | head -20
```

Open the three most common call sites and read them. You need the real helper name, the real metric namespace, and how tags are passed.

NEVER invent a helper, a wrapper, or a metric prefix. If the repo has no telemetry primitive at all, say so explicitly in the plan and propose the smallest one that fits its stack.

## Step 3 — Enumerate failure points

Walk the changed code (audit) or the code the feature will touch (plan) against `references/failure-taxonomy.md`. Cover every category in that file; do not stop at the first few obvious ones.

One row per failure point:

```
| What breaks | How you'd find out today | Signal that catches it | Alert condition |
```

Rules:

- **"How you'd find out today" must be honest.** "A customer tells us" and "we wouldn't" are frequently the correct answers. Write them. That column is what justifies the whole plan.
- **Every `rescue` / `catch` / `?.` / `|| default` that hides an error is a row.** No exceptions. A fallback that works is indistinguishable from a fallback that never triggers.
- **Anything on a schedule, queue, or webhook gets an absence row.** A counter sitting at zero looks exactly like no traffic.
- Name a real `file:line` from this repo in every row. A row you cannot anchor to code is speculation — drop it.

**Checkpoint: output the table before proposing any signal.**

## Step 4 — Propose signals

One row per signal:

```
| Signal | Type | Emit site (file:line) | Tags | Tier | Question it answers | Status |
```

- **Type**: counter, distribution/histogram, span, structured log, product event.
- **Tags**: bounded sets only. See the cardinality gate below.
- **Tier**: `page` / `slack` / `dashboard`. Defined in Step 5.
- **Status**: audit mode only — `EXISTS` (already emitted and usable), `MISSING`, or `WRONG` (fires, but unusable: no tags, wrong tier, wrong namespace, name typo).

Naming follows the namespace already in the repo. Do not start a new convention.

Pick the cheapest type that answers the question. A counter beats a distribution; a span attribute on an existing span beats a new metric.

## Step 5 — Gates: cut ruthlessly

Run every proposed signal through all four gates. Fix or drop failures, and show what you dropped and why.

**1. The 3am test.** Someone woken by this alert must get from the alert to the cause without reading source. If they can't, the signal is missing context — usually a tag naming the tenant/company, the flag variant, the endpoint, or the failure reason.

**2. Cardinality.** Metric tags must be bounded sets that you can enumerate. `user_id`, `session_id`, `request_id`, raw URLs, and error messages as metric tags are a billing incident, not observability. High-cardinality identifiers belong on spans and structured logs, which are indexed differently. State the expected number of tag combinations for any signal with more than two tags.

**3. Tier.** Every signal is exactly one of:
   - `page` — a human must act now, and there is something they can do. User-visible breakage only.
   - `slack` — degradation worth looking at tomorrow.
   - `dashboard` — context for debugging, no alert.
   A signal that cannot justify `page` is not an alert. Most signals are `dashboard`.

**4. Who looks.** Name the person or moment that consumes this signal: "the on-call during an incident", "us, in the week after rollout", "the weekly funnel review". Cannot name one → cut it.

If more than 12 signals survive all four gates, the gates were not applied. Go back and cut, or state in the plan why this change genuinely needs more.

The plan records the cuts under **Deliberately not instrumented**. That section is not optional; it is the evidence you applied the gates.

## Step 6 — Rollout comparison

If the change sits behind a feature flag, find the flag in the diff (`useFeatureFlag`, OpenFeature, or whatever the repo uses) and name it in the plan.

Every new signal carries the variant tag while the flag is live. Without it you cannot separate "the new path is broken" from "this was always noisy", and the first week of rollout is guesswork.

If there is no flag, say so and name what the pre-change baseline is instead — an existing metric, or nothing.

## Step 7 — Prove the emit fires (audit mode)

Untested telemetry is silently broken telemetry. A typo'd metric name never fires and nobody notices for months.

For each `MISSING` or `WRONG` signal, propose the assertion that would fail if the emit did not happen — a `$statsd` spy in RSpec, a mocked `datadogRum.addAction` in vitest, whatever the repo's test setup supports. One assertion per signal, named against a real spec file path.

If instrumentation already exists this session and you can run the test, run it. Report binary: `PASS` with the assertion output, or `FAIL` with what it printed. NEVER "should fire".

## Step 8 — Write the plan

Fill `templates/telemetry-plan.md` and write it to `<repo root>/.context/telemetry/<slug>-telemetry.md`, creating the directory. `.context/` is the repo's uncommitted scratch area.

Then output to the terminal only:

```
📊 TELEMETRY PLAN — <slug> (<mode>)

Claim: <the one sentence>

Failure points found: <n>   Already covered: <n>   Gaps: <n>
Signals proposed: <n>       Cut by gates: <n>

Top 3 gaps, worst first:
1. <failure> → <signal> (<file:line>)
2. ...
3. ...

Alerts that would page: <n> — <names, or "none">
Plan: .context/telemetry/<slug>-telemetry.md
Open questions: <n> — answer them in the file or here
```

Then STOP. Do not start implementing instrumentation unless the user asks.

If they do ask, instrument from the plan's own rows: the emit site, the tags, and the assertion are already decided, so the implementation pass adds those lines and nothing else. Do not redesign the telemetry while writing it.

## Forbidden actions

- NEVER edit production code in this skill. It produces a plan; instrumenting is a separate, explicit request.
- NEVER `git add` anything under `.context/`, and NEVER edit `.gitignore`.
- NEVER propose a signal without a real `file:line` emit site from this repo.
- NEVER propose a metric tag whose value set you cannot enumerate.
- NEVER claim a signal `EXISTS` without having read the line that emits it.
- NEVER skip **Deliberately not instrumented**. A plan that cuts nothing has not been thought about.
