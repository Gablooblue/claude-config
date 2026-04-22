# Documentation Accuracy Review: PR #321 (ON-1413)
## feat(ON-1413): Add warm transfer data to post-call webhook payload

**Date**: 2026-04-01
**Reviewer**: Claude (automated)
**PR**: onprofit-services-api #321
**Branch**: ON-1413

---

## Executive Summary

PR #321 adds `WarmTransferWebhook` and `WarmTransferTargetWebhook` Pydantic models and includes `warm_transfers` as a new optional field on the `CallWebhook` schema. It also adds `selectinload(Call.warm_transfers)` to the `get_lead_calls_with_vars()` query.

**The PR does NOT update any documentation files.** The webhook docs at `docs/webhooks/webhook-examples.md` and `docs/webhooks/webhook-integration-guide.md` are not modified by this PR.

---

## Findings

### FINDING 1 (Medium) -- Webhook Integration Guide does not mention `warm_transfers` field

**File**: `docs/webhooks/webhook-integration-guide.md`

The integration guide describes the webhook schema evolution policy (lines 278-280):
> "New optional fields may be added without notice"

While this policy technically covers the addition of `warm_transfers`, the guide includes no documentation of the call webhook payload schema at all. The guide references sub-documents (`webhooks-overview.md`, `lead-webhooks.md`, `twilio-webhooks.md`) that do not exist in the repository. This means there is no single place where a consumer can discover the `warm_transfers` field.

**Impact**: Customers receiving post-call webhooks will see `warm_transfers` appear in payloads with no documentation explaining the field structure or status mapping logic.

**Recommendation**: Add a "Call Webhook Payload" section to the integration guide or create a new `call-webhooks.md` document that describes the full `CallWebhook` schema including `warm_transfers`.

---

### FINDING 2 (Medium) -- Webhook Examples doc has no call webhook payload example

**File**: `docs/webhooks/webhook-examples.md`

The examples doc shows how to create leads and handle lead-updated webhooks, but contains zero examples of a **post-call webhook payload**. The database integration example (lines 784-804) references `call_data['uuid']`, `call_data['status']`, `call_data.get('duration_seconds')`, and `call_data.get('call_result')` but does not show how `warm_transfers` would appear in the payload or how to handle it.

**Impact**: Customers building integrations will not know how to parse or process the `warm_transfers` array.

**Recommendation**: Add a "Post-Call Webhook Payload" example section showing the full JSON structure, including the `warm_transfers` array as shown in the PR description.

---

### FINDING 3 (Low) -- Docstring on `WarmTransferWebhook.status` says "see status values in spec" but no spec exists

**File**: `src/onprofit/services_api/schemas/webhooks/call_webhook.py` (PR diff, line adding `WarmTransferWebhook`)

The `status` field description reads: `"Status of the transfer (see status values in spec)"`. There is no spec document in the repository. The only documentation of the status mapping is in the PR description body and the `from_warm_transfer()` method code.

**Impact**: The docstring references a non-existent document.

**Recommendation**: Either:
- (a) Replace the description with the actual values: `"Status of the transfer: successful, not_started, started, target_declined, target_no_answer, system_error, etc."`, or
- (b) Create the referenced spec document and link to it properly.

---

### FINDING 4 (Low) -- `from_warm_transfer()` docstring is minimal and does not document fallback behavior

**File**: `src/onprofit/services_api/schemas/webhooks/call_webhook.py` (PR diff)

The `from_warm_transfer()` classmethod docstring says:
```
Create a webhook representation from a WarmTransfer ORM object.

Maps ORM status + result fields to spec status values.
```

It does not document:
- The fallback to `"system_error"` for unknown status values
- That `failed` status maps to the `result` field value
- The full set of possible status values

**Impact**: Future developers maintaining this code will need to read the implementation to understand the mapping logic.

**Recommendation**: Expand the docstring to document the status mapping table explicitly.

---

### FINDING 5 (Medium) -- `get_lead_calls_with_vars()` docstring not updated to mention warm transfer eager loading

**File**: `src/onprofit/services_api/services/call_service.py` (PR diff, line adding `selectinload`)

The PR adds `.options(selectinload(Call.warm_transfers))` to the query in `get_lead_calls_with_vars()`, but neither the function name nor its existing docstring (if any) is updated to indicate that warm transfers are now eager-loaded. The function is also called by `get_lead_calls_with_vars_and_results()` which is the entry point for the trigger endpoint. The current docstring on `get_lead_calls_with_vars_and_results()` (lines 391-404) does not mention warm transfers.

**Impact**: Developers may not realize warm transfers are loaded or may accidentally remove the selectinload, breaking the warm_transfers serialization.

**Recommendation**: Update the docstring for `get_lead_calls_with_vars()` and `get_lead_calls_with_vars_and_results()` to mention that warm transfers are now eager-loaded.

---

### FINDING 6 (High) -- `get_lead_calls_with_vars_and_results()` does NOT have the `selectinload` -- only `get_lead_calls_with_vars()` does

**File**: `src/onprofit/services_api/services/call_service.py`

The PR adds `selectinload(Call.warm_transfers)` to `get_lead_calls_with_vars()` (line 377 in the diff). However, the trigger webhook endpoint at `lead_webhook.py:116` calls `get_lead_calls_with_vars_and_results()`, which internally calls `get_lead_calls_with_vars()`. The chain works because `get_lead_calls_with_vars_and_results()` delegates to `get_lead_calls_with_vars()`.

However, examining the code on `main`, `get_lead_calls_with_vars()` already has the `selectinload` on the PR branch but not on main. The PR correctly adds it. **This is not a documentation bug, but worth noting for completeness**: the warm transfer data will flow through correctly because `get_lead_calls_with_vars_and_results()` calls `get_lead_calls_with_vars()`.

**No action needed** -- code is correct.

---

### FINDING 7 (Medium) -- PR description example payload does not match code exactly

**File**: PR description body vs `src/onprofit/services_api/schemas/webhooks/call_webhook.py`

The PR description shows the example payload with `warm_transfers` at the top level of the call object:
```json
{
  "uuid": "call-uuid-123",
  ...
  "warm_transfers": [...]
}
```

This is accurate -- the `warm_transfers` field IS on `CallWebhook`. However, in the actual webhook delivery, the `CallWebhook` is nested inside `LeadUpdateData.calls[]`. So the real payload structure is:
```json
{
  "event_type": "lead_updated",
  "data": {
    "lead": {...},
    "campaign": {...},
    "calls": [
      {
        "uuid": "call-uuid-123",
        "warm_transfers": [...]
      }
    ]
  }
}
```

The PR description shows the call object in isolation, which could mislead readers about the nesting level.

**Impact**: Low -- PR descriptions are not customer-facing, but this could confuse code reviewers.

**Recommendation**: Clarify in the PR description that the example shows a single call object, not the full webhook payload.

---

### FINDING 8 (Info) -- Referenced documentation files do not exist

**File**: `docs/webhooks/webhook-integration-guide.md`

The integration guide references these sub-documents that do not exist in the repo:
- `./webhooks-overview.md`
- `./lead-webhooks.md`
- `./twilio-webhooks.md`
- `./webhook-authentication.md`

This is a pre-existing issue, not introduced by this PR, but it means there is no detailed webhook payload schema documentation anywhere in the repo.

---

## Summary Table

| # | Severity | Category | Description |
|---|----------|----------|-------------|
| 1 | Medium | Missing docs | Integration guide has no call webhook payload documentation |
| 2 | Medium | Missing docs | Examples doc has no post-call webhook example with warm_transfers |
| 3 | Low | Incorrect docstring | `WarmTransferWebhook.status` references non-existent "spec" |
| 4 | Low | Incomplete docstring | `from_warm_transfer()` docstring does not document mapping logic |
| 5 | Medium | Missing docstring update | `get_lead_calls_with_vars()` docstring not updated for eager loading |
| 6 | Info | Code correctness | Warm transfer data flow is correct through the call chain |
| 7 | Medium | PR description | Example payload shows isolated call, not full webhook envelope |
| 8 | Info | Pre-existing | Referenced sub-documents in integration guide do not exist |

## Overall Assessment

The code changes are functionally correct. The primary documentation gap is that **no documentation was updated or created to describe the new `warm_transfers` field** in the post-call webhook payload. This means customers will discover the field only through raw payload inspection. The docstrings in the new code are minimal and reference a non-existent spec. The existing webhook documentation files do not cover call webhook payloads at all (a pre-existing gap that this PR makes more acute).

**Recommended actions before merge**:
1. Fix the `WarmTransferWebhook.status` field description to list actual values instead of referencing a non-existent spec (Finding 3)
2. Add a docstring to `get_lead_calls_with_vars()` mentioning warm transfer eager loading (Finding 5)
3. Expand the `from_warm_transfer()` docstring with the status mapping table (Finding 4)
4. (Optional but recommended) Add a post-call webhook payload example to `docs/webhooks/webhook-examples.md` (Findings 1, 2)
