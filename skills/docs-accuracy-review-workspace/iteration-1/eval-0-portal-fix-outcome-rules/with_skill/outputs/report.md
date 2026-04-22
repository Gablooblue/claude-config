# Docs Accuracy Review: PR #366 — fix(ON-2078): restore outcome rules alongside scripts

## PR Summary

This PR fixes a bug where `restoreLive()` only restored scripts, leaving outcome rules untouched. Changes:

1. **`OutcomeRulesContext.tsx`**: Added `restoreRulesFromLive()` method to `OutcomeRulesContextValue` interface and implemented it. The method creates a new rules draft version from the live rules.
2. **`ConversationManager.tsx`**: Updated `handleRestoreLive` to call both `restoreLive()` and `restoreRulesFromLive()` in parallel via `Promise.all`.

---

## Findings

### Stale

#### 1. `RestoreLiveModal.tsx` — UI text only mentions script sections, not outcome rules

**File**: `apps/frontend/src/app/pages/dashboard/campaigns/script-manager/RestoreLiveModal.tsx`
**Lines**: 71-75, 38-49

The modal's warning text says:
> "Restoring the live version will discard all unsaved changes in your current draft."

This is technically still accurate (it describes what restore does in general terms). However, the "View Details" section (lines 38-49) only lists script-related sections that will be affected: Objectives, Topics & Transitions, Objection Responses, User Question Responses, and Variables. It does **not** mention "Outcome Rules" as a section that will be restored.

After this PR, the restore action now also restores outcome rules from live, but the detail breakdown in the modal does not reflect this. A user with draft outcome rule changes who clicks "View Details" would not see that their outcome rule changes will also be discarded.

**Severity**: Stale — The modal's changed-sections list is incomplete. The general warning text is still accurate, but the granular details omit outcome rules.

#### 2. `OutcomeRulesContext.tsx` — New `restoreRulesFromLive` method has no JSDoc comment

**File**: `apps/frontend/src/app/pages/dashboard/campaigns/script-manager/contexts/OutcomeRulesContext.tsx`
**Line**: 45 (interface) and 255 (implementation)

The `OutcomeRulesContextValue` interface has JSDoc comments on some members (e.g., `/** Whether saved draft rules differ from live rules (for Review Changes) */` on `hasSavedRuleDifferences`). The new `restoreRulesFromLive: () => Promise<void>` member in the interface has no JSDoc describing what it does. The existing `saveRules` and `discardChanges` also lack JSDoc, so this is consistent with the file's conventions for action methods — only state properties have doc comments.

**Severity**: Missing (minor) — No JSDoc on the new method. Consistent with existing convention for action methods in this interface, so this is low priority.

#### 3. `ConversationManager.tsx` — Comment on `handleRestoreLive` is now incomplete

**File**: `apps/frontend/src/app/pages/dashboard/campaigns/script-manager/ConversationManager.tsx`
**Lines**: 303-314 (after PR changes applied)

The `handleRestoreLive` function has an inline comment `// Stay in draft view to see the restored content` which is still accurate. However, the overall `handleRestoreLive` function has no doc comment. The `handleSave` function below it has inline comments explaining it saves scripts and rules separately — no equivalent documentation exists for `handleRestoreLive` to explain it now restores both scripts and rules in parallel.

**Severity**: Missing (minor) — No doc comment explaining the parallel restore behavior. Low priority since the code is self-documenting (`Promise.all([restoreLive(), restoreRulesFromLive()])`).

---

### No Issues Found

- **`scriptManagerTypes.ts`**: The `restoreLive` type in `ScriptManagerContextValue` (line 92) is unchanged and still accurate — it describes restoring the *script* live version, which is correct. The outcome rules restore is handled separately via `OutcomeRulesContext`.
- **`useScriptPersistence.ts`**: The `restoreLive` implementation (line 127) is unchanged and only handles scripts. Still accurate.
- **Markdown docs**: No project-level markdown docs (`docs/`, `apps/frontend/docs/`, `README.md`) reference `restoreLive`, `handleRestoreLive`, outcome rules restore behavior, or the Conversation Manager's restore feature. No stale docs found outside the codebase.
- **OpenAPI/Swagger specs**: No API doc changes needed — this PR is frontend-only.
- **Changelog**: No changelog entry was added, and none is needed for a bugfix PR.

---

## Summary

| Severity | Count | Details |
|----------|-------|---------|
| Critical | 0 | — |
| Stale | 1 | RestoreLiveModal details section omits outcome rules from the list of affected sections |
| Missing | 2 | No JSDoc on `restoreRulesFromLive`; no doc comment on `handleRestoreLive` explaining parallel restore |

The only actionable finding is the **RestoreLiveModal** not showing outcome rules in its "View Details" breakdown. The missing JSDoc items are low priority and consistent with existing conventions.
