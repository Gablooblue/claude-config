# Proposed Fixes for PR #321 Documentation Issues

## Fix 1: Update `WarmTransferWebhook.status` field description

**File**: `src/onprofit/services_api/schemas/webhooks/call_webhook.py`

```diff
 class WarmTransferWebhook(BaseModel):
     """Webhook representation of a warm transfer attempt"""
-    status: str = Field(..., description="Status of the transfer (see status values in spec)")
+    status: str = Field(..., description="Status of the transfer. Values: successful, not_started, started, target_declined, target_no_answer, system_error, or other result-specific values from failed transfers")
     transfer_url: Optional[str] = Field(None, description="URL of the transfer resource")
     transfer_target: WarmTransferTargetWebhook = Field(..., description="Transfer target information")
     started_at: Optional[str] = Field(None, description="When the transfer process began (ISO 8601)")
     attempted_at: Optional[str] = Field(None, description="When the outbound call was initiated (ISO 8601)")
     result_at: Optional[str] = Field(None, description="When the final outcome was determined (ISO 8601)")
     ended_at: Optional[str] = Field(None, description="When the transfer fully ended (ISO 8601)")
```

---

## Fix 2: Expand `from_warm_transfer()` docstring

**File**: `src/onprofit/services_api/schemas/webhooks/call_webhook.py`

```diff
     @classmethod
     def from_warm_transfer(cls, wt: WarmTransfer) -> WarmTransferWebhook:
         """
         Create a webhook representation from a WarmTransfer ORM object.

-        Maps ORM status + result fields to spec status values.
+        Maps ORM status + result fields to webhook status values:
+        - status == "successful"  -> "successful"
+        - status == "not_started" -> "not_started"
+        - status == "started"     -> "started"
+        - status == "failed"      -> uses result value (e.g. "target_declined", "target_no_answer")
+        - status == "failed" with no result -> "system_error"
+        - unknown status          -> "system_error"
         """
```

---

## Fix 3: Add docstring to `get_lead_calls_with_vars()` mentioning warm transfer loading

**File**: `src/onprofit/services_api/services/call_service.py`

```diff
 async def get_lead_calls_with_vars(db: AsyncSession, campaign_lead_uuid: str, include_outcome: bool = False) -> List[Tuple[Call, CallVars]]:
+    """
+    Get all calls for a lead with their variables.
+
+    Eager-loads Call.warm_transfers via selectinload so that warm transfer
+    data is available for webhook serialization without additional queries.
+
+    Args:
+        db: Database session
+        campaign_lead_uuid: UUID of the campaign lead
+        include_outcome: Whether to eager-load outcome_rule -> outcome relationships
+
+    Returns:
+        List of tuples containing (Call, CallVars)
+
+    Raises:
+        ValueError: If retrieval fails
+    """
     try:
         stmt = (
             select(Call, CallVars)
```

---

## Fix 4 (Optional): Add post-call webhook payload example to docs

**File**: `docs/webhooks/webhook-examples.md`

Add the following section before the "## Integration Patterns" heading (after line 202):

```diff
+## Post-Call Webhook Payload
+
+When a post-call webhook is triggered, the payload includes call data with optional warm transfer information. Here is the full structure:
+
+```json
+{
+  "event_type": "lead_updated",
+  "timestamp": 1705233600.0,
+  "webhook_id": "abc123-def456",
+  "data": {
+    "lead": {
+      "uuid": "lead-uuid-789",
+      "campaign_uuid": "campaign-uuid-456",
+      "first_name": "John",
+      "last_name": "Doe",
+      "full_name": "John Doe",
+      "main_phone_number": "+15551234567",
+      "status": "contacted",
+      "calling_status": "completed"
+    },
+    "campaign": {
+      "uuid": "campaign-uuid-456",
+      "name": "Q1 Outreach",
+      "org_uuid": "org-uuid-001",
+      "status": "active"
+    },
+    "calls": [
+      {
+        "uuid": "call-uuid-123",
+        "campaign_uuid": "campaign-uuid-456",
+        "lead_uuid": "lead-uuid-789",
+        "call_from": "+1234567890",
+        "call_to": "+0987654321",
+        "status": "completed",
+        "start_ts": "2026-01-14T10:00:00+00:00",
+        "end_ts": "2026-01-14T10:05:00+00:00",
+        "duration_seconds": 300,
+        "direction": "outbound",
+        "warm_transfers": [
+          {
+            "status": "successful",
+            "transfer_url": "https://api.example.com/transfers/wt_123",
+            "transfer_target": {
+              "id": "agent_456",
+              "name": "John Smith",
+              "phone_number": "+15551234567"
+            },
+            "started_at": "2026-01-14T10:01:00+00:00",
+            "attempted_at": "2026-01-14T10:01:05+00:00",
+            "result_at": "2026-01-14T10:01:45+00:00",
+            "ended_at": "2026-01-14T10:02:22+00:00"
+          }
+        ]
+      }
+    ]
+  }
+}
+```
+
+### Warm Transfer Status Values
+
+The `status` field in each warm transfer object can have the following values:
+
+| Status | Description |
+|--------|-------------|
+| `successful` | Transfer completed successfully |
+| `not_started` | Transfer has not yet begun |
+| `started` | Transfer is in progress |
+| `target_declined` | Target agent declined the transfer |
+| `target_no_answer` | Target agent did not answer |
+| `system_error` | Transfer failed due to a system error |
+
+When no warm transfers occurred during a call, the `warm_transfers` field will be `null`.
+
 ## Integration Patterns
```

---

## Fix 5 (Optional): Update `get_lead_calls_with_vars_and_results()` docstring

**File**: `src/onprofit/services_api/services/call_service.py`

```diff
 async def get_lead_calls_with_vars_and_results(
     db: AsyncSession, campaign_lead_uuid: str, include_outcome: bool = False
 ) -> List[Tuple[Call, CallVars, Optional[CallResult]]]:
     """
     Get all calls for a lead with their variables and most recent call result.
+
+    Note: Warm transfers are eager-loaded on each Call object via the underlying
+    get_lead_calls_with_vars() query, making them available for webhook serialization.

     Args:
         db: Database session
         campaign_lead_uuid: UUID of the campaign lead
         include_outcome: Whether to eager-load outcome_rule -> outcome relationships

     Returns:
         List of tuples containing (Call, CallVars, CallResult) where CallResult is the most recent one

     Raises:
         ValueError: If retrieval fails
     """
```
