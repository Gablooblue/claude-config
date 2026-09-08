# Telemetry Plan: <feature name>

**Mode:** PLAN | AUDIT (`<the git command and what it returned>`)
**Ticket:** <ABC-1234 or "none">
**Date:** <YYYY-MM-DD>

## The claim

> This works if **<observable thing>** changes. It has failed if **<observable thing>**.

## Failure points

| # | What breaks | How you'd find out today | Signal that catches it | Alert condition |
|---|---|---|---|---|
| 1 | <boundary/branch/invariant, at `file:line`> | <honest answer — "a customer tells us" is allowed> | <signal name> | <e.g. rate > 1% over 10m> |

## Signals

| # | Signal | Type | Emit site | Tags | Tier | Question it answers | Status |
|---|---|---|---|---|---|---|---|
| 1 | `metric.name` | counter | `file:line` | `outcome`, `company` | dashboard | <one question> | MISSING |

Status is AUDIT mode only: EXISTS / MISSING / WRONG.

## Absence checks

Anything scheduled, queued, consumed, or webhook-driven. One row each, or "none — nothing in this change runs unattended".

| What should keep happening | Signal | Alert when |
|---|---|---|
| <e.g. the nightly sync job completes> | `job.x.success` | no success in 26h |

## Rollout comparison

**Flag:** `<flag name>` (`file:line`) — or "none, shipped unflagged".
**Variant tag:** `<tag>` on signals <#, #, #>.
**Baseline:** <existing metric that shows the pre-change behavior, or "none — first N days are the baseline">.

## Cardinality budget

| Signal | Tags | Values per tag | Time series |
|---|---|---|---|
| `metric.name` | `outcome` x `company` | 4 x <n companies> | <product> |

Total new time series: **<n>**.

## Proving the emits fire (AUDIT mode)

| Signal | Assertion | File | Result |
|---|---|---|---|
| `metric.name` | `expect { ... }.to push_statsd_metrics(...)` | `spec/...` | not yet run / PASS / FAIL |

## Deliberately not instrumented

Not optional. What was proposed and cut, and which gate cut it.

| Considered | Why not | Gate |
|---|---|---|
| <signal> | <reason> | 3am / cardinality / tier / who-looks |

## Open questions

1. <question that needs a human decision, with the two options>
