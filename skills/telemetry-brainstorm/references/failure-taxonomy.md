# Failure Taxonomy

Walk every category. Each one that applies to the change produces at least one row in the Step 3 table. A category with genuinely nothing to say gets written down as "none" — silence is indistinguishable from not having looked.

---

## 1. Boundaries crossed

Any line where control or data leaves the process: HTTP call, DB query, job enqueue, job consume, cache read, queue publish, third-party SDK, feature-flag read, file/S3 access, GraphQL resolver hitting another service.

For each, four questions:

- **Times out** — is there a timeout at all? What happens when it fires: raise, retry, or silently return a default?
- **Errors** — 4xx and 5xx behave differently. A 429 is a capacity signal; a 401 is a credentials signal. Do they end up in the same counter?
- **Is slow but succeeds** — the case no error counter catches. Needs a duration distribution, not a counter.
- **Returns the wrong shape** — nulls where objects were expected, an empty array that means "none" versus "the query failed", a field that quietly changed type.

Signals: counter tagged by outcome (`success` / `timeout` / `error` / `empty`), duration distribution, span around the call.

## 2. Swallowed errors

Every `rescue`, `catch`, `try/except`, `?.`, `|| default`, `.catch(() => null)`, and `if err != nil { return fallback }` in the diff.

A fallback path that works is indistinguishable from a fallback path that never runs. Both look like success.

- Increment a counter **on the fallback branch**, tagged with the reason.
- A log line alone is not enough — logs are searched when you already suspect a problem. A counter is what shows you there is one.
- If the fallback returns data the user sees, that is a correctness failure, not just an operational one. Say so.

## 3. Branches and early returns

Every new `if`, guard clause, permission check, validation gate, and early `return`.

- A guard that skips work silently produces the same observable result as work that succeeded.
- Which branch is supposed to be the common path? If the ratio inverts in production, would anyone notice? That ratio is usually one counter with a `branch:` tag.

## 4. "This can't happen"

Every invariant the code assumes: a record that must exist, a state machine that cannot go backwards, two systems that must agree, an enum with a `default:` case the code claims is unreachable.

- Counter on the impossible branch. Tier `slack` at minimum — an invariant firing means a wrong mental model, and it will point at a real bug.
- If two systems must agree, name the reconciliation check: what would compare them, and how often.

## 5. Absence

The most-missed category. A counter sitting at zero looks exactly like no traffic.

Applies to anything on a schedule, a queue, a webhook, a consumer, a stream, or a retry backlog.

- Did it run at all in the last N minutes? Alert on the *absence* of the success signal, not on the presence of an error signal.
- Queue depth and consumer lag, not just processed count.
- For webhooks: the sender stopping and the receiver breaking look identical from inside. Say which one your signal distinguishes, or admit it does not.

## 6. Async, retries, and idempotency

- Does anything eventually reach a terminal state, or can work sit in "pending" forever? Age of the oldest unfinished item is the signal.
- Retries: count attempts separately from successes, otherwise a healthy-looking success rate hides a path that needs four tries every time.
- Idempotency: if the same input can be processed twice, count duplicate detections. Zero duplicates forever usually means the check is broken.

## 7. Data assumptions

- Empty collections, single-element collections, and unbounded ones. What is the size at p99, and what breaks at 10x that?
- N+1 queries introduced by the change — a span count per request catches this; a latency metric only catches it after it hurts.
- Nulls in newly-required fields, especially on rows written before the change shipped.
- Backfills and migrations: they distort every rate metric while running. Note which signals will look like incidents during a backfill.

## 8. Product outcome

This is the "did it do its job" half, and it comes straight from the claim in Step 1.

- The behavior change the feature was built to cause — the action taken, the funnel step completed, the support ticket not filed.
- Adoption versus success: people reaching the feature and people getting a good result from it are two different numbers. Both, or you cannot tell "nobody found it" from "it doesn't work".
- Drop-off: where in the flow do people leave? One event per step, not one event at the end.
- What is the *counter-metric* — the thing that must NOT get worse? Page latency, conversion elsewhere, support volume. A feature that wins its own metric while hurting another is not a win.

## 9. Correctness without exceptions

Bugs that throw nothing.

- Wrong values written, right shape: a price computed with the wrong currency, a date with the wrong timezone, a total that does not sum.
- Sanity assertions on outputs: a percentage outside 0-100, a negative count, an empty result for input that always has results.
- Drift between two sources of truth that should match. Count mismatches; alert on the rate, not on any single one.

## 10. Cost and noise

Run last, on the whole set:

- How many new custom metric time series does this create? Tags multiply, they do not add.
- Which of these will fire on every deploy, every backfill, every Monday morning? An alert that fires predictably gets muted, and then everything behind it is invisible.
- Which alert is the first one someone will silence? Fix or downgrade it now.
