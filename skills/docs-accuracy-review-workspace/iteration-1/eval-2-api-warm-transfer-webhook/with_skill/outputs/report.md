# Documentation Accuracy Review: PR #321 — Add warm transfer data to post-call webhook payload

**PR**: feat(ON-1413): Add warm transfer data to post-call webhook payload
**Branch**: ON-1413
**Date**: 2026-04-01

---

## Summary of Code Changes

PR #321 adds warm transfer data to the post-call webhook payload. The key changes are:

1. **New schema models** in `src/onprofit/services_api/schemas/webhooks/call_webhook.py`:
   - `WarmTransferTargetWebhook` — Pydantic model for transfer target (id, name, phone_number)
   - `WarmTransferWebhook` — Pydantic model for a warm transfer attempt (status, transfer_url, transfer_target, started_at, attempted_at, result_at, ended_at)
   - `WarmTransferWebhook.from_warm_transfer()` — factory classmethod that maps ORM status+result to webhook status values

2. **New field on `CallWebhook`**:
   - `warm_transfers: Optional[List[WarmTransferWebhook]]` added to the `CallWebhook` model
   - `CallWebhook.from_call()` now extracts warm transfers from the call object

3. **Eager loading** in `src/onprofit/services_api/services/call_service.py`:
   - `get_lead_calls_with_vars()` now includes `.options(selectinload(Call.warm_transfers))`

4. **Tests** in `tests/schemas/test_call_webhook.py`:
   - 11 new tests covering `WarmTransferWebhook` creation, status mapping, and integration with `CallWebhook`

---

## Findings

### Critical Issues

**None found.** The PR's code changes are internally consistent: docstrings, field descriptions, and type annotations in the new schema classes match the actual implementation.

### Stale Issues

#### S1: `CallWebhook.from_call()` docstring/signature mismatch between PR branch and main branch

**Severity**: Stale (medium)
**File**: `src/onprofit/services_api/schemas/webhooks/call_webhook.py`
**Details**: On the current `main` branch, `CallWebhook.from_call()` has the signature `from_call(cls, call, include_outcome_fields: bool = False)`, which includes outcome-related fields (`progression`, `follow_up_request`, `gatekeepers`, `outcome`) and a `model_serializer` that conditionally excludes them. The PR diff shows a simpler `from_call(cls, call)` signature **without** the `include_outcome_fields` parameter, suggesting the PR was branched before the outcome fields feature was added. This is a **merge conflict** that will need resolution, not a documentation issue per se, but it affects the accuracy of the PR's code relative to `main`.

**Impact**: When this PR is merged, if it doesn't rebase onto the current main, it will regress the `include_outcome_fields` parameter and the outcome-related fields. The call site at `src/onprofit/services_api/api/v2/webhooks/lead_webhook.py:121` calls `CallWebhook.from_call(call, include_outcome_fields=include_outcome_fields)`, which would break.

#### S2: Webhook documentation does not document the post-call webhook payload schema at all

**Severity**: Stale (pre-existing, worsened by this PR)
**Files**: `docs/webhooks/webhook-integration-guide.md`, `docs/webhooks/webhook-examples.md`
**Details**: The existing webhook documentation focuses entirely on lead creation webhooks and Twilio voice webhooks. There is **no documentation** of the post-call webhook payload schema (`CallWebhook`, `LeadUpdatedWebhookPayload`, etc.) anywhere in the markdown docs. The PR adds `warm_transfers` to this payload but there is no existing doc to update. The webhook integration guide references several docs that don't exist (`webhooks-overview.md`, `lead-webhooks.md`, `twilio-webhooks.md`, `webhook-authentication.md`).

This is a pre-existing gap, but the PR widens it by adding a new significant payload component (`warm_transfers`) without any accompanying documentation.

### Missing Documentation

#### M1: No markdown documentation for the new `warm_transfers` webhook payload field

**Severity**: Missing (high)
**Files**: No file exists for this
**Details**: The `warm_transfers` array added to the `CallWebhook` payload is customer-facing data sent via post-call webhooks. External integrators need to know:
- That `warm_transfers` is a new optional field on call objects in the webhook payload
- The schema of each warm transfer object (status, transfer_url, transfer_target, timestamps)
- The status mapping logic (how ORM status+result maps to the webhook status string)
- Possible status values: `successful`, `not_started`, `started`, `target_declined`, `target_no_answer`, `target_busy`, `target_call_failed`, `target_early_disconnect`, `customer_disconnected`, `timeout`, `system_error`

Currently this information only exists in the PR description and the Pydantic field descriptions in the code.

#### M2: `WarmTransferWebhook.from_warm_transfer()` docstring is minimal

**Severity**: Missing (low)
**File**: `src/onprofit/services_api/schemas/webhooks/call_webhook.py` (PR branch)
**Details**: The `from_warm_transfer` classmethod has a docstring that says "Maps ORM status + result fields to spec status values" but does not document:
- The `wt` parameter type and what attributes it expects
- The return type
- The status mapping rules
- What happens for unknown status values (fallback to `system_error`)

The existing codebase convention (see `call_service.py`) uses Args/Returns/Raises docstring format for public methods. The new method should follow suit.

#### M3: `CallWebhook.from_call()` has no docstring at all

**Severity**: Missing (pre-existing, low)
**File**: `src/onprofit/services_api/schemas/webhooks/call_webhook.py`
**Details**: The `from_call` classmethod on `CallWebhook` has no docstring on either `main` or the PR branch. This is a pre-existing gap, but with the addition of warm transfer handling, the method's behavior is more complex and a docstring documenting the extraction logic would be helpful.

---

## Code-Level Docstring & Field Description Audit

### `WarmTransferTargetWebhook` fields -- PASS
- `id: Optional[str]` — description "Target identifier" -- accurate
- `name: Optional[str]` — description "Target's name" -- accurate
- `phone_number: Optional[str]` — description "Target's phone number (E.164 format)" -- accurate (maps from `wt.target_phone_number`)

### `WarmTransferWebhook` fields -- PASS
- `status: str` — description "Status of the transfer (see status values in spec)" -- accurate, though "spec" is vague since there's no external spec doc
- `transfer_url: Optional[str]` — description "URL of the transfer resource" -- accurate
- `transfer_target: WarmTransferTargetWebhook` — description "Transfer target information" -- accurate
- `started_at: Optional[str]` — description "When the transfer process began (ISO 8601)" -- accurate
- `attempted_at: Optional[str]` — description "When the outbound call was initiated (ISO 8601)" -- accurate
- `result_at: Optional[str]` — description "When the final outcome was determined (ISO 8601)" -- accurate
- `ended_at: Optional[str]` — description "When the transfer fully ended (ISO 8601)" -- accurate

### `CallWebhook.warm_transfers` field -- PASS
- `warm_transfers: Optional[List[WarmTransferWebhook]]` — description "Warm transfer attempts for this call" -- accurate

### Status mapping logic in `from_warm_transfer()` -- PASS
The status mapping matches the PR description:
- `status == "successful"` -> `"successful"`
- `status == "not_started"` -> `"not_started"`
- `status == "started"` -> `"started"`
- `status == "failed"` -> uses `result` value, or `"system_error"` if `result` is None
- Unknown status -> `"system_error"` (undocumented fallback, but correct)

### ORM field coverage -- PASS
The `WarmTransfer` ORM model has these fields that are intentionally excluded from the webhook representation (internal/infrastructure fields):
- `id` (DB primary key)
- `op_warm_transfer_id` (internal tracking)
- `conversation_id` (DB foreign key)
- `order_index` (internal ordering)
- `lead_intro_audio_uri` (internal audio)
- `transfer_intro_audio_uri` (internal audio)
- `conference_audio_uri` (internal audio)
- `created_at` / `updated_at` (DB timestamps)

This is appropriate -- the webhook exposes only customer-relevant fields.

---

## Conclusion

The PR's code-level documentation (Pydantic field descriptions, docstrings) is **accurate** and matches the implementation. The two actionable findings are:

1. **Merge conflict risk (S1)**: The PR branch's `CallWebhook.from_call()` is missing the `include_outcome_fields` parameter that exists on `main`. This will cause a runtime error when merged if not rebased.

2. **No markdown documentation for warm transfers (M1/M2)**: There is no customer-facing documentation explaining the new `warm_transfers` field in the post-call webhook payload. This is partly a pre-existing gap (no post-call webhook payload docs exist at all), but adding at least a section or file documenting the warm transfer schema and status values would be important for integrators.
