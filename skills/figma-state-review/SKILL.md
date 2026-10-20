---
name: figma-state-review
description: Use when checking built UI against Figma, design mockups, or exported design frames - "compare to Figma", "does this match the design", "walk me through it vs the design", "go through each change one by one", or reviewing visual states, hover/animation frames, or placement rules with the user.
---

# Figma State Review

Walk the user through the built UI **one big change per message**. Each message holds one labelled image (Figma vs the real renderer), what differs, and at most one decision. Then you MUST stop and wait. The user steers; you capture, fix, and recapture.

Why one at a time: the user judges visuals by eye. Five images and three questions in one message means they skim, decisions get mixed up, and fixes land untested. One change per message keeps each look, decision, and commit separate.

## Message 1: inventory + first change

1. List the big changes in review order, one line each, numbered (e.g. `1. Glow levels  2. Hover pill  3. Call card  4. Tooltip placement  5. Fold animation`).
   - Figma has it but it isn't built: list it with `(not built)`. It gets its own round with a build-or-skip decision.
   - Built but no Figma frame exists: list it with `(no frame)` and ask for an export when you reach it.
2. Then do a full round (below) for change 1 only.

## One round = one change

**Capture the real renderer** with its real CSS and fake state. Never use a mockup or a hand-drawn copy.
- Web: Playwright against the local app or a Vite page that mounts the real component with a fake API.
- Electron: a `BrowserWindow` loads the renderer's dev-server URL, a preload fakes the bridge (`window.<api>`), the main process sends states over IPC, and `webContents.capturePage()` saves a PNG per state. Synthetic hover needs `mouseEnter` + `mouseMove`, repeated at a few delays.
- Write the capture as a re-runnable script under `.context/` so every fix can be recaptured in one command.

**Check the capture before trusting it.** Open the PNG and confirm the state actually rendered: hover expanded, card not clipped, the right timer text. If the capture is wrong, fix the harness first and say "that's the harness, not the app".

**Match Figma's scale.** Crop the built shot around the element and zoom it (lanczos) to the size of the Figma crop. When placement is what's being checked, keep the screen edge in the crop.

**Compose one sheet** with Figma on top and built underneath, each row labelled. Save it as `.context/screens/<ticket>-<change>-compare.png`.

```js
import sharp from 'sharp';
const W = 528, L = 44;
const label = (t) => Buffer.from(`<svg width="${W}" height="${L}"><text x="12" y="30" font-size="22" font-family="Helvetica">${t}</text></svg>`);
const fit = (p, crop) => sharp(p).extract(crop).resize(W, null, { kernel: 'lanczos3' }).png().toBuffer();
const design = await fit('figma.png', { left: 120, top: 40, width: 400, height: 160 });
const built = await fit('built.png', { left: 388, top: 56, width: 176, height: 72 });
const h = async (b) => (await sharp(b).metadata()).height;
const [dh, bh] = [await h(design), await h(built)];
await sharp({ create: { width: W, height: 2 * L + dh + bh, channels: 4, background: '#f4f4f6' } })
  .composite([
    { input: label('Figma'), left: 0, top: 0 }, { input: design, left: 0, top: L },
    { input: label('Built (real renderer)'), left: 0, top: L + dh }, { input: built, left: 0, top: 2 * L + dh },
  ]).png().toFile('compare.png');
```

## Report template (fill every slot, in this order)

```
<One line: matches / close / differs, and the single biggest gap.>

![<Change>: Figma vs built](</abs/path/compare.png>)

**How it works now**
- <mechanism with real values: 160ms, 44→148pt, #7a24c8, file + function names>

**Where it differs from the design**
- <concrete visual difference: rim, padding, weight, size, colour>

**Different on purpose**
- <difference driven by the ticket, a copy branch, or an earlier user decision> (write "None" if empty)

<EITHER> **One decision:** A (recommended): ... / B: ... Pick A or B.
<OR>     **Fix:** <2-4 bullets naming the CSS/props to change>. Make the change and recapture? Yes or no.
```

Before you put anything under "Where it differs", check the branch's commits, the ticket, and any copy branch. Differences that come from those go under "Different on purpose".

## After the user answers

1. Apply only what the user agreed to for this change. Leave other changes' files alone. Recapture with the same script, recompose, and repeat until it matches. Don't show intermediate rounds.
2. Run the relevant tests, then commit this change on its own.
3. Report: the updated sheet, **What changed** (real values), deliberate differences that remain, the commit hash, then `Next big change: <name>. Say go.`
4. If the user rejects a change that's already pushed, revert it with a new commit. Never rewrite history.

For animations, capture a frame strip (e.g. every 40-80ms after the trigger) and treat it as its own change.

## Common mistakes

| Mistake | Fix |
|---|---|
| All changes in one message with several images | Inventory line, then one change. The rest waits for "go". |
| Two or three decisions at the end | One decision per message. Queue the others for that change's own round. |
| Listing fixes for every state up front | Offer the fix for the current change only, with yes/no. |
| Calling a ticket- or copy-driven difference a gap | Check commits/ticket first, then use "Different on purpose". |
| Mismatched scale (Figma frames are zoomed in) | Crop + zoom the built shot to the Figma crop's size. |
| Trusting a capture where hover/state didn't take | Open the PNG, check it, fix the harness first. |
| Moving to the next change yourself | End with `Next big change: X. Say go.` and stop. |
