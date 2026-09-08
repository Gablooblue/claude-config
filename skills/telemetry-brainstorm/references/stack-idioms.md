# Stack Idioms

What each known repo actually uses to emit. Observed 2026-09-08 — if a path below does not exist, the repo moved on: re-discover with the grep in SKILL.md Step 2 and update this file.

For any repo not listed here, discover first. Never assume.

---

## mutiny (Rails monolith)

**Metrics** — global `$statsd` (Datadog dogstatsd), dot-namespaced lowercase names:

```ruby
$statsd.increment('app.external_api.success')
$statsd.increment('graphql.access_denied', tags: ["contract:#{name}"])
$statsd.timing(name, duration_ms, tags: tags)
```

Existing names to match, not replace: `app.external_api.count`, `graphql.access_denied`, `contract.pending_delete_but_executed`. Jobs use a `STATS_KEY` constant with `.success` / `.failure` suffixes — follow that when the change is in a job.

Tags are an array of `"key:value"` strings, or a hash routed through `DatadogHelper.tags_hash_to_array`.

**Errors** — `lib/datadog_helper.rb`:

```ruby
DatadogHelper.set_error(SomeError.new, tags: statsd_tags, tags_prefix: nil)
```

**Timing a block** — `DatadogHelper.timing(name, tags) { ... }` (`lib/datadog_helper.rb:64`). Emits `$statsd.timing` in milliseconds and returns the block's value.

**Spans** — `Datadog::Tracing.trace("Class#method") do |span| ... end`. See `app/transactions/observe_step_adapter.rb:9` for the pattern used around transaction steps.

**Logs** — `Rails.logger.info / warn / error`. Logs are for context during an investigation; they are not a substitute for a counter.

**Proving the emit fires** — `spec/support/statsd_helpers.rb` provides block-syntax matchers:

```ruby
expect { call }.to push_statsd_metrics([{ type: :increment, stat: 'app.thing.failure', tags: [...] }])
expect { call }.not_to push_statsd_metric(...)
```

`allow($statsd).to receive(:increment)` also appears (e.g. `spec/api/web_client/tracking_spec.rb:95`). Prefer the matcher — it asserts the stat name, so a typo fails the test.

---

## mutiny-frontend (React browser + Node services in `apps/`)

**Browser RUM** — `@datadog/browser-rum`:

```ts
datadogRum.addAction('name', metadata)
datadogRum.addError(error, context)
datadogRum.addTiming('name')
datadogRum.setGlobalContextProperty(key, value)
```

Go through the existing wrapper at `src/helpers/errorReporter/index.ts` rather than calling RUM directly from a component.

**Browser logs** — `@datadog/browser-logs`, `datadogLogs.logger`.

**Node service metrics and spans** — `dd-trace`:

```ts
tracer.trace('LinkedinAdsClient.listAdAccounts', async () => { ... })
tracer.startSpan(...)
tracer.dogstatsd.increment(...)   // see apps/analytics-collector/src/telemetry/tracer.ts:55
```

Span names follow `ClassName.methodName`.

**Product events** — Segment:

- Browser: `window.analytics.track('Event Name', { ...props })`
- Node: `analytics.track('Event Name', { ... })` via `AnalyticsBuilder` (`apps/champaign/src/serviceContainer.ts`)

Event names are Title Case, optionally with a bracketed area prefix: `'[Rec Email] Page Recommendation Opened'`, `'[Meta Agent] Agent Turn Complete'`. Match the surrounding area's prefix.

**Feature flags** — OpenFeature. React: the `useFeatureFlag` hook. Node: `OpenFeature.getClient()` (`apps/champaign/src/shared/featureFlags.ts`). This is where the variant tag for Step 6 comes from.

**Proving the emit fires** — vitest. Mock the RUM or analytics module and assert the call, including the event/metric name string.

---

## Cross-cutting notes for both repos

- Everything lands in Datadog, so a metric emitted in Rails and a RUM action in the browser can appear on one dashboard — say so in the plan when a failure spans both sides.
- Tenant identity is `company.slug` in the backend (`"company:#{company.slug}"`). Bounded enough for a metric tag at current customer count; state the count in the plan if you use it. `user_id` is not.
- Both repos already have far more `tracer.trace` / `Datadog::Tracing.trace` coverage than metric coverage. Adding an attribute to an existing span is usually cheaper than a new custom metric — check for a surrounding span before proposing one.
