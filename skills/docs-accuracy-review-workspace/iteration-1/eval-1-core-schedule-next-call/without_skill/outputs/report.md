# Docs Accuracy Review: PR #310

**PR:** feat(ON-2043): Schedule next call relative to last user message
**Files changed:**
- `packages/onprofit-integrations/src/onprofit/integrations/core.py`
- `packages/onprofit-integrations/test/onprofit/integrations/core/Integration_test.py`
- `packages/onprofit-tasks/src/onprofit/tasks/post_call.py`
- `packages/onprofit-tasks/tests/test_post_call.py`

---

## Findings

### Finding 1 (Medium): `schedule_next_contact` docstring not updated

**File:** `packages/onprofit-integrations/src/onprofit/integrations/core.py`, line 479

**Current docstring (unchanged by PR):**
```
Schedule a next contact time, or return None to decline to schedule

If initial_call_time is provided, return that time as the next_contact_at and the expires_at 15 minutes from that time.

Default: call in 5 minutes from insertion

:param call_info: onprofit.orm.call_registry.Call.to_dict(with_variables=True)
:param lead_info: onprofit.orm.call_registry.CampaignLead.to_dict()
:return: datetime or None
```

**Problem:** The PR adds significant new behavior -- an anchor time fallback chain (`last_user_message_at` -> `end_ts` -> `start_ts` -> `datetime.now()`) that determines the base time for cadence scheduling. The docstring does not mention this new behavior at all. The phrase "Default: call in 5 minutes from insertion" is also misleading in context of the cadence path, which is now anchored differently.

**Fix:** Update the docstring to document the anchor time fallback chain behavior for the cadence scheduling path.

---

### Finding 2 (Low): `_cadence_next_contact_at` docstring description is vague

**File:** `packages/onprofit-integrations/src/onprofit/integrations/core.py`, line 570 (pre-PR) / ~598 (post-PR)

**Post-PR docstring:**
```
Calculate the next contact time based on the lead's data and the cadence steps.

Chooses the earliest available time within the active days and hours.

:param timezone: the timezone of the lead
:param lockout_duration_min: the lockout duration in minutes
:param active_from: the active from time
:param active_to: the active to time
:param active_days: the active days (using Monday=0, Tuesday=1, etc.)
:param anchor_time: optional datetime to use as the start point instead of now()
:return: the next contact time
```

**Problem:** The PR correctly adds the `:param anchor_time:` line. However, the top-level description ("based on the lead's data and the cadence steps") is vague and doesn't reflect that the method now conditionally uses either `anchor_time` or `datetime.now()` as the base. The method does not actually receive "lead's data" -- it receives a timezone string and scheduling parameters.

**Fix:** Update description to clarify: adds `lockout_duration_min` to either the provided `anchor_time` or `datetime.now()`, then finds the soonest slot within active hours/days.

---

### Finding 3 (Low): `get_last_user_message_at` docstring could be more specific

**File:** `packages/onprofit-tasks/src/onprofit/tasks/post_call.py` (new method added by PR, around line 798)

**Docstring:**
```
Fetch the wall-clock time of the last Human message from transcript_v2.

Args:
    call_start_ts: Call start timestamp as a datetime.

Returns:
    The datetime of the last Human message end, or None if unavailable.
```

**Problem:** The docstring is accurate but omits that it fetches transcript_v2 from the campaign manager API (`CAMPAIGN_MANAGER_BASEURL/conversations/{call_uuid}`), and computes the absolute time by adding `time_in_call_ms + duration_ms` to `call_start_ts`. This context matters for debugging and understanding network dependencies.

**Fix:** Add one line mentioning the campaign manager API call and the offset calculation method.

---

### Finding 4 (Info): Inline comments are accurate

The following inline comments added by the PR are accurate and match the code:

1. **`core.py` anchor time block comment** (around line 549): "Use last user message time as anchor when available (ON-2043) so that a long call-timeout idle period doesn't push the next contact further into the future. Fallback chain: last_user_message_at -> end_ts -> start_ts -> datetime.now()" -- matches the for-loop logic.

2. **`post_call.py` PARALLEL PHASE 1 comment update** (around line 410): Updated to "(phone calls only)" with explanation that SMS/web have no audio -- matches the new `if call.modality is None or call.modality == "phone"` guard.

3. **`post_call.py` anchor time compute comment** (around line 449): "Compute last user message time for cadence scheduling (ON-2043). We anchor the next contact relative to when the user last spoke rather than call end so that a long idle timeout doesn't add extra delay." -- matches the code that calls `get_last_user_message_at` and injects result into `call_info`.

---

### Finding 5 (Info): No markdown docs reference the changed methods

Searched `*.md` and `*.rst` files across the repo. Neither `schedule_next_contact`, `_cadence_next_contact_at`, nor any cadence scheduling documentation exists in markdown form. The `packages/onprofit-tasks/README.md` only has a high-level overview that doesn't mention specific scheduling methods. No updates needed for markdown docs.

---

### Finding 6 (Info): Test docstrings are accurate

All new test method docstrings in the PR accurately describe what they test. Verified each test docstring against its implementation.

---

## Summary

| # | Severity | File | Issue |
|---|----------|------|-------|
| 1 | Medium | `core.py` | `schedule_next_contact` docstring does not mention new anchor time fallback chain |
| 2 | Low | `core.py` | `_cadence_next_contact_at` description is vague about what "lead's data" means; should mention anchor_time vs now() behavior |
| 3 | Low | `post_call.py` | `get_last_user_message_at` docstring omits campaign manager API dependency and offset calculation |
| 4 | Info | multiple | Inline comments are accurate |
| 5 | Info | N/A | No markdown docs need updating |
| 6 | Info | tests | Test docstrings are accurate |

**Verdict:** 1 medium and 2 low-severity docstring gaps. Proposed fixes in `proposed-fixes.md`.
