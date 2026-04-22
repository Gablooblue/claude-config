# Proposed Fixes: PR #310 Docs Accuracy

## Fix 1: Update `schedule_next_contact` docstring

**File:** `packages/onprofit-integrations/src/onprofit/integrations/core.py`

```diff
     def schedule_next_contact(self, call_info, lead_info) -> Optional[NextContactSchedulerResponse]:
         """
-        Schedule a next contact time, or return None to decline to schedule
+        Schedule a next contact time, or return None to decline to schedule.

-        If initial_call_time is provided, return that time as the next_contact_at and the expires_at 15 minutes from that time.
+        If initial_call_time is provided (attempt 0), return that time as the next_contact_at
+        with expiration derived from the cadence.

-        Default: call in 5 minutes from insertion
+        For cadence-based scheduling, the lockout duration is added to an anchor time
+        determined by the following fallback chain:
+            last_user_message_at -> end_ts -> start_ts -> datetime.now()
+        This ensures a long idle timeout at the end of a call does not push the next
+        contact further into the future (ON-2043).

         :param call_info: onprofit.orm.call_registry.Call.to_dict(with_variables=True)
         :param lead_info: onprofit.orm.call_registry.CampaignLead.to_dict()
         :return: datetime or None
         """
```

---

## Fix 2: Improve `_cadence_next_contact_at` docstring

**File:** `packages/onprofit-integrations/src/onprofit/integrations/core.py`

```diff
     def _cadence_next_contact_at(self, timezone, lockout_duration_min, active_from, active_to, active_days, anchor_time=None):
         """
-        Calculate the next contact time based on the lead's data and the cadence steps.
+        Calculate the next contact time by adding lockout_duration_min to a base time
+        and finding the soonest slot within the configured active hours and days.

-        Chooses the earliest available time within the active days and hours.
+        The base time is anchor_time if provided, otherwise datetime.now() in the
+        lead's timezone. When anchor_time is naive, it is treated as UTC.

         :param timezone: the timezone of the lead
         :param lockout_duration_min: the lockout duration in minutes
         :param active_from: the active from time
         :param active_to: the active to time
         :param active_days: the active days (using Monday=0, Tuesday=1, etc.)
-        :param anchor_time: optional datetime to use as the start point instead of now()
+        :param anchor_time: optional datetime to use as the base instead of now().
+            If naive (no tzinfo), treated as UTC.
         :return: the next contact time
         """
```

---

## Fix 3: Enhance `get_last_user_message_at` docstring

**File:** `packages/onprofit-tasks/src/onprofit/tasks/post_call.py`

```diff
     def get_last_user_message_at(self, call_start_ts):
-        """Fetch the wall-clock time of the last Human message from transcript_v2.
+        """Fetch the wall-clock time of the last Human message from transcript_v2
+        via the campaign manager API (GET /conversations/{call_uuid}).
+
+        Computes the absolute timestamp by adding the message's time_in_call_ms
+        and duration_ms offsets to call_start_ts.

         Args:
-            call_start_ts: Call start timestamp as a datetime.
+            call_start_ts: Call start timestamp as a datetime, used as the base
+                for computing absolute message times from relative offsets.

         Returns:
             The datetime of the last Human message end, or None if unavailable.
         """
```
