# Proposed Fixes for PR #366 Docs Accuracy Issues

## Fix 1: Add JSDoc to `restoreRulesFromLive` in the interface

**File:** `apps/frontend/src/app/pages/dashboard/campaigns/script-manager/contexts/OutcomeRulesContext.tsx`

```diff
   saveRules: () => Promise<void>;
+  /** Creates a new draft version of outcome rules from the current live rules */
   restoreRulesFromLive: () => Promise<void>;
   discardChanges: () => void;
```

---

## Fix 2: Update RestoreLiveModal warning text to reflect full restore scope

**File:** `apps/frontend/src/app/pages/dashboard/campaigns/script-manager/RestoreLiveModal.tsx`

```diff
           <div className="rounded-lg bg-error/10 border border-error/20 p-4 space-y-2">
             <p className="font-medium text-error">This action cannot be undone</p>
             <p className="text-sm text-base-content/70">
-              Restoring the live version will discard all unsaved changes in your current draft.
+              Restoring the live version will replace your current draft with the live version,
+              including both the script and outcome rules. Any draft changes will be lost.
             </p>
           </div>
```

---

## Fix 3: Add "Outcome Rules" to the changed sections list in RestoreLiveModal

**File:** `apps/frontend/src/app/pages/dashboard/campaigns/script-manager/RestoreLiveModal.tsx`

This fix requires passing outcome rule state into the modal. A minimal approach would be to add a prop:

```diff
 interface RestoreLiveModalProps {
   isOpen: boolean;
   isRestoring: boolean;
   onClose: () => void;
   onConfirm: () => void;
   /** Current draft version to show what will be discarded */
   draftVersion?: ScriptVersionResponse | null;
-  /** Current live version for comparison */
+  /** Current live script version for comparison */
   liveVersion?: ScriptVersionResponse | null;
+  /** Whether outcome rules have differences that will be overwritten */
+  hasRuleDifferences?: boolean;
 }
```

And in the `changedSections` memo:

```diff
   const changedSections = useMemo(() => {
     if (!sectionChanges) return [];

     const sections: string[] = [];

     if (sectionChanges.objectives) sections.push('Objectives (Goal & Background)');
     if (sectionChanges.topics) sections.push('Topics & Transitions');
     if (sectionChanges.objections) sections.push('Objection Responses');
     if (sectionChanges.questions) sections.push('User Question Responses');
     if (sectionChanges.variables) sections.push('Variables');
+    if (hasRuleDifferences) sections.push('Outcome Rules');

     return sections;
-  }, [sectionChanges]);
+  }, [sectionChanges, hasRuleDifferences]);
```

And in `ConversationManager.tsx`, pass the prop:

```diff
       <RestoreLiveModal
         isOpen={isRestoreModalOpen}
         isRestoring={isRestoring}
         onClose={() => setIsRestoreModalOpen(false)}
         onConfirm={handleRestoreLive}
         draftVersion={draftVersionForDiff}
         liveVersion={live}
+        hasRuleDifferences={hasSavedRuleDifferences}
       />
```

**Note:** This is a functional change beyond pure docs, so it may warrant its own consideration. The simpler docs-only fix is Fix 2 above.

---

## Fix 4: Add JSDoc to `restoreLive` in `scriptManagerTypes.ts`

**File:** `apps/frontend/src/contexts/scriptManagerTypes.ts`

```diff
+  /** Restores the script draft from the live version. Does not affect outcome rules. */
   restoreLive: () => Promise<ScriptVersionResponse>;
```

---

## Fix 5: Add JSDoc to `restoreLive` in `useScriptPersistence.ts`

**File:** `apps/frontend/src/contexts/hooks/useScriptPersistence.ts`

```diff
+  /** Restores the script draft by creating a new draft version from the live script. */
   const restoreLive = useCallback(async () => {
```
