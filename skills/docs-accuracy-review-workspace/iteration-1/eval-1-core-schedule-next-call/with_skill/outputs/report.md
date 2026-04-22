# Docs Accuracy Review: PR #310 — Schedule next call relative to last user message

**PR:** feat(ON-2043): Schedule next call relative to last user message
**Repo:** onprofit-core
**Files changed:** 4

## Key Changes Summary

1. **`_cadence_next_contact_at`** gained a new `anchor_time=None` keyword parameter, used as an alternative starting point instead of `datetime.now()`.
2. **`schedule_next_contact`** now computes an `anchor_time` from `call_info` using a fallback chain: `last_user_message_at` -> `end_ts` -> `start_ts` -> `None` (which causes `_cadence_next_contact_at` to fall back to `datetime.now()`).
3. **`get_last_user_message_at`** is a new method on `PostCallActions` that fetches `transcript_v2` from the campaign manager API and computes the wall-clock time of the last Human message.
4. **`execute` in `post_call.py`** now conditionally skips ElevenLabs transcript reprocessing for non-phone modalities, and injects `last_user_message_at` into `call_info` before scheduling.

---

## Findings

### Critical -- Docs that are factually wrong

**1. `schedule_next_contact` docstring `:return:` type is wrong**
- **File:** `packages/onprofit-integrations/src/onprofit/integrations/core.py` (line ~488 in current main)
- **Issue:** The docstring says `:return: datetime or None` but the method signature and actual return type is `Optional[NextContactSchedulerResponse]`. This is a pre-existing bug, but the PR touches this method's body and should fix it.
- **Severity:** Critical -- the documented return type does not match the actual return type.

**2. `schedule_next_contact` docstring does not mention the new anchor time behavior**
- **File:** `packages/onprofit-integrations/src/onprofit/integrations/core.py` (line ~479-489)
- **Issue:** The docstring still says "Default: call in 5 minutes from insertion" as the only description of cadence behavior. The PR adds a significant new behavior: the lockout duration is now anchored to the last user message time (or end_ts/start_ts) rather than `datetime.now()`. This new behavior is the entire point of the PR but is not reflected in the docstring at all.
- **Severity:** Critical -- the docstring describes behavior that is now different from what the code does.

### Stale -- Docs that are outdated but not completely wrong

**3. `_cadence_next_contact_at` docstring description is stale**
- **File:** `packages/onprofit-integrations/src/onprofit/integrations/core.py` (line ~570-581 in current main, lines ~595-612 in PR branch)
- **Issue:** The PR adds `:param anchor_time: optional datetime to use as the start point instead of now()` which is correct. However, the method description still says only "Calculate the next contact time based on the lead's data and the cadence steps." It should mention that when `anchor_time` is provided, the lockout period is measured from that anchor rather than the current time. The new `:param` line is accurate but the overall description is incomplete.
- **Severity:** Stale -- the param doc is added but the behavior description doesn't fully capture the change.

**4. `execute` method inline comment "PARALLEL PHASE 1" is stale on the PR branch**
- **File:** `packages/onprofit-tasks/src/onprofit/tasks/post_call.py` (around line ~410)
- **Issue:** The PR changes the comment from "PARALLEL PHASE 1: Transcript reprocessing / This needs to complete before we can use reprocessed_transcript" to "PARALLEL PHASE 1: Transcript reprocessing (phone calls only) / Audio re-transcription via ElevenLabs only makes sense for phone calls." This is correctly updated in the diff. No action needed -- the PR handles this well.
- **Severity:** N/A -- already fixed in the PR.

### Missing -- New public API surface with no documentation

**5. `get_last_user_message_at` docstring is present and adequate**
- **File:** `packages/onprofit-tasks/src/onprofit/tasks/post_call.py` (line ~798 in PR branch)
- **Issue:** The new method has a docstring with Args and Returns sections. It is accurate. No issue.
- **Severity:** N/A -- already handled.

---

## Outside-the-diff search results

- No markdown docs (`README.md`, `docs/`, `CONTRIBUTING.md`, `ARCHITECTURE.md`, `CHANGELOG.md`) reference `schedule_next_contact`, `_cadence_next_contact_at`, or `get_last_user_message_at`.
- No OpenAPI/Swagger specs or other API docs reference these methods.
- The `analysis_orchestrator.py` calls `integration.schedule_next_contact(call_info, lead_info)` -- no signature change needed since `call_info` and `lead_info` are the same dict params; the new `last_user_message_at` key is simply added to `call_info` before the call. No doc update needed there.

---

## Summary

| # | Severity | Location | Issue |
|---|----------|----------|-------|
| 1 | Critical | `core.py` `schedule_next_contact` docstring | `:return: datetime or None` should be `:return: NextContactSchedulerResponse or None` |
| 2 | Critical | `core.py` `schedule_next_contact` docstring | Missing description of anchor time behavior (the whole point of this PR) |
| 3 | Stale    | `core.py` `_cadence_next_contact_at` docstring | Description doesn't mention anchor_time behavior, though the `:param` line is present |
