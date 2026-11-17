---
name: design-state-review
description: Use when checking built UI against a design reference - Figma frames, mockups, ticket images, screenshots, or a reference site/app - "compare to the design", "does this match the mockup", "compare to Figma", "walk me through it vs the design", "go through each change", or reviewing visual states, hover/animation frames, or placement rules. Runs unattended and ends with one report of every update.
---

# Design State Review

Review the built UI against the design **without stopping**: list every big change, then for each one capture, compare, fix, recapture, test, and commit. Send **one report at the end** covering every change. Do NOT message the user between changes, and do NOT ask for a go-ahead, a yes/no, or an A/B pick mid-run.

Why unattended: the user wants to judge finished results, not approve each step. What keeps that safe is one commit per change (any single change can be reverted alone) and a final report that shows every image and every choice you made on the user's behalf.

## Rules for the whole run

- **Fix only real gaps.** A real gap is a visual difference between design and built that the ticket, the branch's commits, or an earlier user decision does not explain. Explained differences are "Different on purpose" and stay as they are.
- **When a fix has two reasonable options, pick the one you would have recommended** and record it as a judgment call with the option you passed over. Never stop to ask.
- **Park, don't ask.** A change you cannot or should not finish alone goes on the "Needs you" list (below) and the run continues with the next change.
- **One change, one commit.** Touch only the files that change needs. Run the relevant tests before each commit.
- **Before the first edit, run `git status` and `git diff`.** If a file a fix needs already has uncommitted changes you did not make, park that change.

### Park a change on "Needs you" when

| Situation | What to record |
|---|---|
| The design has it but it isn't built `(not built)` | What is missing. Building it is a new feature, not a fix. |
| Built but the design doesn't show it `(no design)` | Which state needs a reference. |
| Two references disagree and the ticket doesn't say which wins | Both versions, and which one you would pick. |
| The fix would edit a shared component, design token, or style used outside the reviewed UI, or add a dependency | The fix you would make and what else it would affect. |
| Still differs after 3 fix-and-recapture attempts | What you tried and the remaining gap, with the latest sheet. |
| The capture harness or the tests still fail after 2 attempts | The exact error. Undo your own uncommitted edits for that change first. |
| The file has someone else's uncommitted changes | The file name. |

### Stop the whole run and ask only when

- No design reference can be opened at all (see below), or
- The app or renderer cannot be started for capture after 2 attempts.

## The design reference

Whatever the user treats as the target: Figma exports, mockups, images in the ticket (`mcp__linear__extract_images`), screenshots, or a live reference site or app.
- Live site or app: capture it the same way as the build. If it needs the user's login, drive their own browser (the Chrome plugin via `node_repl`).
- A link you can't open: park the changes that depend on it. If that leaves no usable reference, stop and ask for a screenshot or export.
- More than one reference: give each its own labelled row (`Design (mockup)`, `Reference (Stripe)`).
- Save each crop as `.context/screens/<ticket-or-slug>-<change>-design.png`.

## Step 1: inventory

List the big changes in review order, one line each, numbered (e.g. `1. Glow levels  2. Hover pill  3. Call card  4. Tooltip placement  5. Fold animation`). Mark `(not built)` and `(no design)` items. Track the list in the task list and work through it top to bottom. Animations are their own change: capture a frame strip (e.g. every 40-80ms after the trigger).

## Step 2: one round per change

**Capture the real renderer** with its real CSS and fake state. Never use a mockup or a hand-drawn copy.
- Web: Playwright against the local app or a Vite page that mounts the real component with a fake API.
- Electron: a `BrowserWindow` loads the renderer's dev-server URL, a preload fakes the bridge (`window.<api>`), the main process sends states over IPC, and `webContents.capturePage()` saves a PNG per state. Synthetic hover needs `mouseEnter` + `mouseMove`, repeated at a few delays.
- Write the capture as a re-runnable script under `.context/` so every fix can be recaptured in one command.

**Check the capture before trusting it.** Open the PNG and confirm the state actually rendered: hover expanded, card not clipped, the right timer text. If the capture is wrong, fix the harness first. A harness problem is never reported as an app gap.

**Match the design's scale.** Crop the built shot around the element and zoom it (lanczos) to the size of the design crop. When placement is what's being checked, keep the screen edge in the crop.

**Compose one sheet** with the design on top and built underneath, each row labelled. Save the first one as `.context/screens/<ticket-or-slug>-<change>-before.png` and the one after your fix as `...-<change>-compare.png`.

```js
import sharp from 'sharp';
const W = 528, L = 44;
const label = (t) => Buffer.from(`<svg width="${W}" height="${L}"><text x="12" y="30" font-size="22" font-family="Helvetica">${t}</text></svg>`);
const fit = (p, crop) => sharp(p).extract(crop).resize(W, null, { kernel: 'lanczos3' }).png().toBuffer();
const design = await fit('design.png', { left: 120, top: 40, width: 400, height: 160 });
const built = await fit('built.png', { left: 388, top: 56, width: 176, height: 72 });
const h = async (b) => (await sharp(b).metadata()).height;
const [dh, bh] = [await h(design), await h(built)];
await sharp({ create: { width: W, height: 2 * L + dh + bh, channels: 4, background: '#f4f4f6' } })
  .composite([
    { input: label('Design'), left: 0, top: 0 }, { input: design, left: 0, top: L },
    { input: label('Built (real renderer)'), left: 0, top: L + dh }, { input: built, left: 0, top: 2 * L + dh },
  ]).png().toFile('compare.png');
```

**Sort the differences.** Check the branch's commits, the ticket (if any), and any copy changes the user pointed to. Differences those explain are "Different on purpose". The rest are real gaps.

**Fix, recapture, commit.**
1. No real gaps: record `matches` and go to the next change.
2. Otherwise apply the fix, recapture with the same script, recompose. Repeat up to 3 attempts, then park it.
3. Run the relevant tests, commit this change on its own, and note the hash.
4. Record for the report: before and after sheets, what changed (real values), differences on purpose, judgment calls.

Then start the next change immediately.

## Step 3: the final report (one message, fill every slot, in this order)

```
**TL;DR:** <N> changes reviewed: <a> already matched, <b> fixed, <c> need you.

| # | Change | Result | Commit |
|---|---|---|---|
| 1 | <name> | matched / fixed / needs you | <hash or -> |

## <#>. <Change> - <result>
![<Change>: design vs built](</abs/path/compare.png>)
- **What changed:** <real values: 160ms, 44→148pt, #7a24c8, file + function names> (or "Nothing, already matched")
- **Different on purpose:** <difference and what explains it> (or "None")
- **Judgment call:** <what you picked, what you passed over, why> (omit if none)

<repeat for every change, in inventory order>

## Needs you
- <#>. <Change>: <the situation from the park table, and the one thing you need from the user>

## To undo a change
`git revert <hash>` for that row. Each change is its own commit.
```

For a fixed change, also link the `-before.png` sheet under the image. Write "None" under "Needs you" if nothing was parked.

If the user later rejects a change that's already pushed, revert it with a new commit. Never rewrite history.

## Common mistakes

| Mistake | Fix |
|---|---|
| Pausing after a change to ask "go?" or "yes or no?" | Keep going. The only stops are the two in "Stop the whole run". |
| Asking the user to pick A or B | Pick the recommended one, log it as a judgment call. |
| Building a `(not built)` feature to close the gap | Park it under "Needs you". |
| Fixing several changes in one commit | One change, one commit, so each can be reverted alone. |
| Looping on a stubborn gap | 3 attempts, then park it with the latest sheet. |
| Leaving a choice out of the report | Every judgment call and every parked change is listed. |
| Calling a ticket- or copy-driven difference a gap | Check commits/ticket first, then use "Different on purpose". |
| Mismatched scale (design frames are often zoomed in) | Crop + zoom the built shot to the design crop's size. |
| Trusting a capture where hover/state didn't take | Open the PNG, check it, fix the harness first. |
