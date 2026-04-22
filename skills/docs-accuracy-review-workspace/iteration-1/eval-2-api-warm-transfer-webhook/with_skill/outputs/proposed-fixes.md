# Proposed Fixes for PR #321 Documentation Issues

---

## Fix 1: Add docstring to `WarmTransferWebhook.from_warm_transfer()` (M2)

**File**: `src/onprofit/services_api/schemas/webhooks/call_webhook.py` (PR branch)

```diff
     @classmethod
     def from_warm_transfer(cls, wt: WarmTransfer) -> WarmTransferWebhook:
-        """
-        Create a webhook representation from a WarmTransfer ORM object.
-
-        Maps ORM status + result fields to spec status values.
-        """
+        """
+        Create a webhook representation from a WarmTransfer ORM object.
+
+        Maps ORM status + result fields to webhook status values:
+        - "successful" -> "successful"
+        - "not_started" -> "not_started"
+        - "started" -> "started"
+        - "failed" -> uses the result value (e.g. "target_declined", "target_no_answer"),
+          or "system_error" if result is None
+        - Any unknown status -> "system_error"
+
+        Args:
+            wt: WarmTransfer ORM object with status, result, transfer_url,
+                target_id, target_name, target_phone_number, and timestamp fields.
+
+        Returns:
+            WarmTransferWebhook with mapped status and ISO 8601 formatted timestamps.
+        """
```

---

## Fix 2: Add docstring to `CallWebhook.from_call()` (M3)

**File**: `src/onprofit/services_api/schemas/webhooks/call_webhook.py` (PR branch)

```diff
     @classmethod
     def from_call(cls, call) -> "CallWebhook":
+        """
+        Create a webhook payload from a Call ORM object.
+
+        Extracts call details, associated variables, result data, and warm
+        transfer attempts into a serializable webhook representation.
+
+        Args:
+            call: Call ORM object, optionally with call_vars, result, and
+                warm_transfers relationships loaded.
+
+        Returns:
+            CallWebhook instance ready for serialization.
+        """
         # Extract vars from CallVars if available
```

Note: On the current `main` branch, `from_call` has `include_outcome_fields: bool = False` parameter. The PR will need to be rebased to incorporate that. The docstring above should be updated during rebase to mention the `include_outcome_fields` parameter.

---

## Fix 3: Clarify vague "spec" reference in `WarmTransferWebhook.status` field description (minor)

**File**: `src/onprofit/services_api/schemas/webhooks/call_webhook.py` (PR branch)

```diff
-    status: str = Field(..., description="Status of the transfer (see status values in spec)")
+    status: str = Field(..., description="Transfer status: successful, not_started, started, or a failure reason (e.g. target_declined, target_no_answer, system_error)")
```

The current description says "see status values in spec" but there is no external spec document. Making the field description self-contained is better for consumers who inspect the schema.

---

## Fix 4: Rebase to resolve `from_call()` signature conflict (S1)

**File**: `src/onprofit/services_api/schemas/webhooks/call_webhook.py`

This is not a documentation fix but a code merge issue. The PR branch's `CallWebhook` class is missing these features from `main`:

1. The `include_outcome_fields` parameter on `from_call()`
2. The `progression`, `follow_up_request`, `gatekeepers`, `outcome` fields
3. The `OUTCOME_FIELDS` set and `_include_outcome_fields` private attribute
4. The `model_serializer` that conditionally strips outcome fields
5. The `_resolve_outcome` static method

The PR should be rebased onto `main` and the warm transfer additions should be merged with the outcome fields code. The merged `from_call()` should look like:

```diff
     @classmethod
-    def from_call(cls, call) -> "CallWebhook":
+    def from_call(cls, call, include_outcome_fields: bool = False) -> "CallWebhook":
         # Extract vars from CallVars if available
         vars_data = None
         if hasattr(call, 'call_vars') and call.call_vars:
             vars_data = call.call_vars.data if hasattr(call.call_vars, 'data') else None

         result_data = None
         if hasattr(call, 'result') and call.result:
             result_data = call.result

         # Extract warm transfers if available
         warm_transfers_data = None
         if hasattr(call, 'warm_transfers') and call.warm_transfers:
             warm_transfers_data = [
                 WarmTransferWebhook.from_warm_transfer(wt)
                 for wt in call.warm_transfers
             ]

-        return cls(
+        instance = cls(
             uuid=str(call.uuid),
             campaign_uuid=str(call.campaign_uuid),
             campaign_lead_uuid=str(call.campaign_lead_uuid) if call.campaign_lead_uuid else None,
             channel_from=call.channel_from,
             channel_to=call.channel_to,
             status=call.status,
             start_ts=str(call.start_ts),
             end_ts=str(call.end_ts),
             duration_seconds=call.duration,
             call_result=getattr(call, 'call_result', None),
             data=call.data,
             created_at=str(getattr(call, 'created_at', None)),
             updated_at=str(getattr(call, 'updated_at', None)),
             recording_uri=cls.resolve_recording_uri(call),
             direction= "inbound" if getattr(call, 'inbound', None) else "outbound",
             vars=vars_data,
             disposition=getattr(result_data, 'disposition', None),
-            warm_transfers=warm_transfers_data
+            warm_transfers=warm_transfers_data,
+            progression=getattr(call, 'progression', None),
+            follow_up_request=getattr(call, 'follow_up_request', None),
+            gatekeepers=getattr(call, 'gatekeepers', None),
+            outcome=cls._resolve_outcome(call) if include_outcome_fields else None,
         )
+        instance._include_outcome_fields = include_outcome_fields
+        return instance
```

---

## Fix 5 (Optional): Add post-call webhook payload documentation (M1)

If the team decides to document the post-call webhook payload, a new file such as `docs/webhooks/post-call-webhook.md` should be created covering:

1. The `LeadUpdatedWebhookPayload` envelope (event_type, timestamp, webhook_id, data)
2. The `LeadUpdateData` structure (lead, campaign, calls)
3. The `CallWebhook` schema and all its fields
4. The new `warm_transfers` array and `WarmTransferWebhook` schema
5. Status mapping table for warm transfer statuses
6. Example payload (already in the PR description, could be moved to docs)

This is a larger effort and may warrant its own ticket rather than being part of this PR.
