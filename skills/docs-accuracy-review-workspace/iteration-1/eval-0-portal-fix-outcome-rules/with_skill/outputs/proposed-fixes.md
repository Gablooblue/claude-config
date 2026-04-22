# Proposed Fixes: PR #366 — fix(ON-2078): restore outcome rules alongside scripts

## Fix 1 (Stale): RestoreLiveModal — Add outcome rules to the changed-sections detail list

The `RestoreLiveModal` shows users which sections will be affected when restoring. After this PR, outcome rules are also restored, but the modal does not mention them. This fix would add "Outcome Rules" to the detail list when outcome rules have draft changes.

**Note**: This fix requires passing outcome rules change state into the modal, which is a small but non-trivial change involving prop threading. It may be better addressed as a follow-up ticket rather than blocking this PR.

### File: `apps/frontend/src/app/pages/dashboard/campaigns/script-manager/RestoreLiveModal.tsx`

```diff
 interface RestoreLiveModalProps {
   isOpen: boolean;
   isRestoring: boolean;
   onClose: () => void;
   onConfirm: () => void;
   /** Current draft version to show what will be discarded */
   draftVersion?: ScriptVersionResponse | null;
   /** Current live version for comparison */
   liveVersion?: ScriptVersionResponse | null;
+  /** Whether outcome rules have unsaved changes that will be discarded */
+  hasUnsavedRuleChanges?: boolean;
 }
```

```diff
   const changedSections = useMemo(() => {
     if (!sectionChanges) return [];

     const sections: string[] = [];

     if (sectionChanges.objectives) sections.push('Objectives (Goal & Background)');
     if (sectionChanges.topics) sections.push('Topics & Transitions');
     if (sectionChanges.objections) sections.push('Objection Responses');
     if (sectionChanges.questions) sections.push('User Question Responses');
     if (sectionChanges.variables) sections.push('Variables');
+    if (hasUnsavedRuleChanges) sections.push('Outcome Rules');

     return sections;
-  }, [sectionChanges]);
+  }, [sectionChanges, hasUnsavedRuleChanges]);
```

### File: `apps/frontend/src/app/pages/dashboard/campaigns/script-manager/ConversationManager.tsx`

```diff
       <RestoreLiveModal
         isOpen={isRestoreModalOpen}
         isRestoring={isRestoring}
         onClose={() => setIsRestoreModalOpen(false)}
         onConfirm={handleRestoreLive}
         draftVersion={draftVersionForDiff}
         liveVersion={live}
+        hasUnsavedRuleChanges={hasUnsavedRules}
       />
```

---

## Fix 2 (Missing, low priority): Add JSDoc to `restoreRulesFromLive` in the interface

### File: `apps/frontend/src/app/pages/dashboard/campaigns/script-manager/contexts/OutcomeRulesContext.tsx`

```diff
   saveRules: () => Promise<void>;
+  /** Restore outcome rules from the live version, creating a new draft version that matches live */
   restoreRulesFromLive: () => Promise<void>;
   discardChanges: () => void;
```

---

## Fix 3 (Missing, low priority): Add inline comment to `handleRestoreLive` explaining parallel restore

### File: `apps/frontend/src/app/pages/dashboard/campaigns/script-manager/ConversationManager.tsx`

```diff
   const handleRestoreLive = async (): Promise<void> => {
     setIsRestoring(true);

     try {
+      // Restore both script and outcome rules from live in parallel
       await Promise.all([restoreLive(), restoreRulesFromLive()]);
       setIsRestoreModalOpen(false);
       // Stay in draft view to see the restored content
```
