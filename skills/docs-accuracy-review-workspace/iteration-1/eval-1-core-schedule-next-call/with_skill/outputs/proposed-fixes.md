# Proposed Fixes: PR #310 — Docs Accuracy

## Fix 1: `schedule_next_contact` docstring (Critical)

**File:** `packages/onprofit-integrations/src/onprofit/integrations/core.py`

```diff
     def schedule_next_contact(self, call_info, lead_info) -> Optional[NextContactSchedulerResponse]:
         """
-        Schedule a next contact time, or return None to decline to schedule
+        Schedule a next contact time, or return None to decline to schedule.

-        If initial_call_time is provided, return that time as the next_contact_at and the expires_at 15 minutes from that time.
+        If initial_call_time is provided, return that time as the next_contact_at
+        and the expires_at 15 minutes from that time.

-        Default: call in 5 minutes from insertion
+        For cadence-based scheduling, the lockout duration is anchored to the last
+        user message time from the call transcript. Fallback chain when that is not
+        available: call end_ts -> call start_ts -> datetime.now().
+
+        Default (no cadence): call in 5 minutes from insertion.

         :param call_info: onprofit.orm.call_registry.Call.to_dict(with_variables=True)
         :param lead_info: onprofit.orm.call_registry.CampaignLead.to_dict()
-        :return: datetime or None
+        :return: NextContactSchedulerResponse or None
         """
```

## Fix 2: `_cadence_next_contact_at` docstring (Stale)

**File:** `packages/onprofit-integrations/src/onprofit/integrations/core.py`

```diff
     def _cadence_next_contact_at(self, timezone, lockout_duration_min, active_from, active_to, active_days, anchor_time=None):
         """
-        Calculate the next contact time based on the lead's data and the cadence steps.
+        Calculate the next contact time by applying the lockout duration from a
+        starting point and snapping to active hours/days.

-        Chooses the earliest available time within the active days and hours.
+        When ``anchor_time`` is provided, the lockout period is measured from that
+        timestamp instead of the current wall-clock time.  This avoids inflating the
+        delay when the call had a long idle timeout before disconnecting.

         :param timezone: the timezone of the lead
         :param lockout_duration_min: the lockout duration in minutes
         :param active_from: the active from time
         :param active_to: the active to time
         :param active_days: the active days (using Monday=0, Tuesday=1, etc.)
-        :param anchor_time: optional datetime to use as the start point instead of now()
+        :param anchor_time: optional datetime to use as the start point instead of
+            now().  Naive datetimes are treated as UTC.
         :return: the next contact time
         """
```
