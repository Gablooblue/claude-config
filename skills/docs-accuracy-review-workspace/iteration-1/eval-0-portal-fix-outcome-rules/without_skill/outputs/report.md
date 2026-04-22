# Docs & Docstrings Accuracy Review: PR #366

**PR:** fix(ON-2078): restore outcome rules alongside scripts
**Files changed:**
- `apps/frontend/src/app/pages/dashboard/campaigns/script-manager/ConversationManager.tsx`
- `apps/frontend/src/app/pages/dashboard/campaigns/script-manager/contexts/OutcomeRulesContext.tsx`

## Summary

PR #366 adds a `restoreRulesFromLive()` function to `OutcomeRulesContext` and calls it alongside the existing `restoreLive()` (for scripts) inside `handleRestoreLive` in `ConversationManager.tsx`. The change ensures that clicking "Restore" restores both the script and the outcome rules from their live versions.

---

## Findings

### 1. `OutcomeRulesContextValue` interface -- missing `restoreRulesFromLive` (STALE after PR)

**File:** `apps/frontend/src/app/pages/dashboard/campaigns/script-manager/contexts/OutcomeRulesContext.tsx`
**Lines (on base branch):** 24-47

The PR adds `restoreRulesFromLive: () => Promise<void>` to the interface and to the provider's value/deps. This is correct and consistent. **No doc issue here** -- the interface is updated in the PR diff.

However, the interface has a JSDoc comment on `hasSavedRuleDifferences` (line 34) but **no JSDoc on any of the action methods** (`saveRules`, `discardChanges`, `refetch`, `restoreRulesFromLive`). While the existing actions were already undocumented, adding a new public context method without a JSDoc comment is a missed opportunity. This is a **minor gap** -- the new `restoreRulesFromLive` should have a brief JSDoc like the `hasSavedRuleDifferences` field does.

**Severity:** Low (consistency gap)

---

### 2. `RestoreLiveModal` -- UI text says "discard all unsaved changes" but behavior now also overwrites saved draft rules

**File:** `apps/frontend/src/app/pages/dashboard/campaigns/script-manager/RestoreLiveModal.tsx`
**Lines:** 72-75

The modal's warning text reads:
> "Restoring the live version will discard all unsaved changes in your current draft."

After the PR, "Restore" now also overwrites **saved** outcome rules (it creates a new draft version from live rules via `restoreRulesFromLive`). This means the modal text is **slightly inaccurate** -- it only mentions "unsaved changes in your current draft" but the restore operation now also replaces saved draft rules with live rules. The text should reflect that the restore replaces the entire draft (both script and rules) with the live version, not just unsaved changes.

Additionally, the "View Details" section (lines 38-49) only lists script section changes (Objectives, Topics, Transitions, etc.) but does **not** list outcome rules as a section that will be affected. After this PR, outcome rules are also restored, but the modal does not inform the user about rule changes being discarded.

**Severity:** Medium (user-facing text is misleading after the behavioral change)

---

### 3. `RestoreLiveModal` props JSDoc -- references only script versions

**File:** `apps/frontend/src/app/pages/dashboard/campaigns/script-manager/RestoreLiveModal.tsx`
**Lines:** 15-18

```typescript
/** Current draft version to show what will be discarded */
draftVersion?: ScriptVersionResponse | null;
/** Current live version for comparison */
liveVersion?: ScriptVersionResponse | null;
```

These JSDoc comments describe only **script** versions. Now that restore also affects outcome rules, the comments are still technically accurate (the modal only receives script versions as props), but the component's stated purpose -- showing the user what will be discarded -- is now **incomplete**. The modal does not receive outcome rule data and cannot display rule-level differences in the "View Details" section.

**Severity:** Low (the component's props are correct for what it receives, but the component's responsibility has a gap relative to the new behavior)

---

### 4. `handleRestoreLive` in `ConversationManager.tsx` -- inline comment is now stale

**File:** `apps/frontend/src/app/pages/dashboard/campaigns/script-manager/ConversationManager.tsx`
**Line (PR branch):** ~309

After the PR change, the function body becomes:
```typescript
await Promise.all([restoreLive(), restoreRulesFromLive()]);
```

The existing inline comment on the next line reads:
```
// Stay in draft view to see the restored content
```

This comment is still accurate. **No issue.**

---

### 5. `restoreLive` in `useScriptPersistence.ts` -- no JSDoc, but function is script-only and naming could cause confusion

**File:** `apps/frontend/src/contexts/hooks/useScriptPersistence.ts`
**Lines:** 127-142

The `restoreLive` function in `useScriptPersistence` only restores the **script** from live. It has no JSDoc. Now that the caller (`handleRestoreLive`) calls both `restoreLive()` and `restoreRulesFromLive()`, the naming is clear enough -- `restoreLive` handles scripts, `restoreRulesFromLive` handles rules. However, neither function has a JSDoc comment clarifying its scope. A reader might reasonably expect `restoreLive` to restore everything.

**Severity:** Low (naming ambiguity, not a doc inaccuracy per se)

---

### 6. `ScriptManagerContextValue.restoreLive` type signature -- no JSDoc clarifying scope

**File:** `apps/frontend/src/contexts/scriptManagerTypes.ts`
**Line:** 92

```typescript
restoreLive: () => Promise<ScriptVersionResponse>;
```

No JSDoc. After this PR, `restoreLive` only restores the script portion. A JSDoc comment clarifying "Restores the script draft from the live version (does not affect outcome rules)" would prevent future confusion.

**Severity:** Low

---

### 7. No markdown documentation, README, or Confluence pages found

The repository has no project-level markdown documentation (README.md, architecture docs, etc.) outside of `node_modules`. There are no CLAUDE.md files in the repo. Therefore, there are no markdown docs to become stale from this PR.

**Severity:** N/A

---

### 8. No test file references to restore behavior that need updating

The test files (`useScriptManager.test.tsx`, `ScriptManagerContext.test.tsx`, `ConversationManagerTabs.test.tsx`) do not test restore behavior, so there are no test descriptions or comments that became inaccurate.

**Severity:** N/A

---

## Summary Table

| # | Location | Issue | Severity |
|---|----------|-------|----------|
| 1 | `OutcomeRulesContext.tsx` interface | New `restoreRulesFromLive` action lacks JSDoc | Low |
| 2 | `RestoreLiveModal.tsx` UI text | Modal text says "unsaved changes" but restore now also replaces saved draft rules; "View Details" does not list outcome rules | Medium |
| 3 | `RestoreLiveModal.tsx` props JSDoc | Props describe only script versions; component cannot show rule changes being discarded | Low |
| 5 | `useScriptPersistence.ts` | `restoreLive` has no JSDoc clarifying it is script-only | Low |
| 6 | `scriptManagerTypes.ts` | `restoreLive` type has no JSDoc clarifying scope | Low |
