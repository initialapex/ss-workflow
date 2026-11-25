# The manual check, one item at a time

The Review (Step 6 of the skill) goes through its list one item at a time. You never
hand the developer the whole list to work through on their own and report back at
the end. For each item, you prepare what you can observe yourself, ask the developer
only for what you cannot do or see, judge the item from what both of you observed,
and record the result before you go on to the next item.

What you observe yourself (a log line with its time, the output of a command, a file
that the program wrote) is evidence that anyone can check later. What the developer
reports from memory after several steps is not as precise. So you collect every
observation that you can make yourself, and you ask the developer only for the rest.

## 1. Build the list

Collect the items that Step 6 of the skill names, in two parts.

**Part A: checks by running or looking** (the developer acts, and both of you
observe):

- every acceptance criterion that "How to verify" assigns to the Review and that is
  not ticked yet
- the "Review by hand" points of the implementation summary
- every evidence entry that the spec cites and that is still `to test` or
  `developer-stated`
- what a skill of the project asks to see or run (Step 3.5 of the skill)

Merge the items that are the same check: a criterion and the evidence entry that it
proves, or a "Review by hand" point that repeats a criterion, are one item with all
their ids.

**Part B: decisions** (the developer reads and decides; nothing runs):

- every item under `### Behavior changes`
- every other workspace file that the request changes
- every deviation of the design check that is still open
- every finding of the skill checks that is still open
- every `Assumption` in `## Notes`
- every cited evidence entry that is `failed`
- every check that Verify recorded as `failed` or `did not run`
- every problem of Part A that the developer chose to decide at the end (section 5)

## 2. Find how to observe each item of Part A

For each item, find out what you can observe yourself, and what only the developer
can see or do. Look in this order:

1. "How to verify" in `## Spec`, and the "Review by hand" points: since ss-workflow
   0.16.0 they say, for each check by hand, what the agent observes (the source and
   the expected lines or values) and what only the developer sees or does.
2. The test documents of the project that "How to verify" names (a hardware test
   plan, a manual test list), with their steps and expected results.
3. "Toolchain" and "Project rules" in the project's section of `projects/AGENTS.md`:
   the tools, the ports, the log files.
4. The code: the text of the log or status messages that the expected result
   implies, found with `git -C <path> grep`, and where the program writes them.

Sources that you can usually observe yourself: a serial port or debug console, a log
file that the program writes, the console output of a program that you start, the
output of a command or a probe tool that you run, a file or database that the
program changes, a network endpoint. What only the developer can usually see or do:
a screen or window of a program they operate, an LED, a sound, pressing a button,
plugging or unplugging a cable or a device, and powering a device.

Where you cannot find a source for an item, say so in the plan: the developer
observes that item alone, and the record says so.

## 3. Show the plan

Show the plan once, before the first item, as a numbered table: the item and its ids,
what the developer does, what you observe (the source), and what the developer
observes. Then the Part B items, as a short list.

Order Part A as the project's test document orders it, when it has a suggested
order. Otherwise, order it so that the setup changes as little as possible (one
power cycle, one reconnection, or one program start serves several items), and so
that an item that prepares the state for another one comes first.

Say which resources you will use to observe (a serial port, a log file, a program you
start), and that you will never hold one while the developer needs it.

Then start the first item in the same message. The developer can reorder, skip, or
add items at any time.

## 4. One item

Do these steps for each item of Part A. Two items may share a step when one action of
the developer serves both (one power cycle that checks a restart and the offline
indication), but never more than the developer can do and watch at once.

1. **Prepare.** Do everything that you can do yourself: run commands, send commands
   with a probe tool, start the program or the sample when the developer asked you
   to (Step 6 of the skill allows it), and start capturing the source that you
   observe.
   - Never hold a resource that the developer's step needs: a serial port that their
     program opens, a file that their program locks, a device. Stop your capture and
     release the resource before you ask them to use it, and say that you did.
   - When the event that you need happens during the developer's action (the output
     right after a power cycle or a restart), start a capture that waits for the
     source to appear, before you ask for the action, and say so. Otherwise, start
     capturing only after the developer says that they are ready, so that you do not
     act before them.
2. **Ask for the action.** One message with only this item: what to do, in exact
   steps (which button, which cable, how long), what to watch, and what the expected
   result is. Say what you do meanwhile, and ask the developer to tell you when they
   are done. Then wait for their message. Do not assume that they did it.
3. **Observe.** When the developer says that they are done, read what you captured.
   Find the lines or values that the expected result implies, with their time.
   Then ask with AskUserQuestion only what you could not observe yourself: what the
   screen showed, the LED, how long something took when no log shows it. Offer the
   expected result and the likely other outcomes as options. Do not ask what your
   capture already shows. When the developer mentions something unexpected ("it came
   back very quickly"), check it against your capture before you judge.
4. **Judge.** Give the item exactly one of `passed`, `failed` (with the reason), or
   `did not run` (with the reason), as "Report results as they are" in the skill
   says. Write a remark under the result:
   - when the procedure differed from the steps (the power was off for 19 s instead
     of 5 s)
   - when a part of the expected result was not observed by anyone (a line that was
     written before the capture started, a value that the developer did not report)
   - when the result rests on the developer's report only

   A part that nobody observed is never written as seen. When the item does not
   show what it should test (the state that it needs did not occur), it is `did not
   run`, with what happened instead. Cite the evidence: the log line and its time,
   the command and its output, and what the developer reported, each marked with who
   observed it. A cause that nothing shows yet is "inferred".
5. **Record.** Write the result into `## Notes` right away (section 6). Update the
   evidence entries that the item proves or disproves, with a history line:
   `verified` or `failed`, with what was observed as the evidence, and the project
   commit that ran. Do not tick acceptance criteria here: "Review passed" (Step 7)
   ticks them. Commit the request file with the gitlinks, as the ground rules of the
   skill describe:

   ```
   docs(reqs): record review check <item id> of REQ-0012

   Refs: REQ-0012
   ```

   Do not push after each item. Push when the review pauses or ends (Step 7), and
   before that whenever a project commit was made (section 5).
6. **Report and go on.** In one message: the result of the item with its evidence and
   remarks, then the next item, from step 2. If the developer wants to stop, follow
   "Pausing" (section 8).

## 5. When an item fails

Show the developer what failed: the expected result, what you and the developer
observed, and the cause if the evidence shows it (otherwise say "inferred", and what
would settle it). Say whether later items depend on it (a failure that leaves the
system in a state that later items need). Then ask with AskUserQuestion:

| Option | Action |
|--------|--------|
| Diagnose and fix now | Find the cause. You may add temporary diagnostics, but remove them before the fix is committed. A small fix (a localized change that changes neither the design nor the spec) is made here, on the project branch, as Step 7 "Small changes" of the skill describes: a normal commit in the project, pushed, then Verify again (Step 4) before the item is checked again. A fix that needs a large change or a spec decision means "Rework needed" (Step 7). Then check the item again, and say which items that already passed the fix may affect: check those again too. |
| Record it and continue | Record the item as `failed`, add it to Part B, and go on with the next item. The developer decides it at the end, before the outcome. |
| Stop the review | Record the item, then go to the outcome (Step 7). |

When you cannot tell whether a fix is small or large, ask the developer.

## 6. The record

The Review has one block in `## Notes`, written while it runs:

```markdown
### Review (yyyy-MM-dd, in progress)
- Plan: 14 checks by running, 6 decisions; order as in `docs/hw-test.md` "Suggested order"
- C5 Client restart (AC3, E4): passed
  - Observed: COM4, `rejoined the network: pan_id=0xAA15 channel=11` 0.5 s after the boot banner; no `no network data`
  - Developer: the Client card stayed green
  - Remark: the power was off for about 19 s, not 5 s as the step says
- D7 one-time permit join window (AC7): failed: the window closed after about 200 s, not 60 s
  - Observed: Server log, `permit_join_s` went from 40 to 180 at 05:23:48, when the Client joined; `permit join window closed` at 05:27:08
  - Cause: inferred: the joining router opened its own 180 s window
  - Decision: at the end
- D4 card of a Client that left (AC5): did not run: the Server received no Leave, so the grey card never appeared
- Left: A1, A2, B3 (Client part); decisions: D7, Behavior change `.claude/skills/x/SKILL.md`
```

- One item per check, with its ids, the result, and the lines `Observed:` (what you
  observed, with the source and the time), `Developer:` (what the developer
  reported), `Remark:`, `Cause:`, and `Decision:` where they apply.
- `Left:` always lists the items without a result, so that a paused review can
  continue.
- Decisions of Part B are written where the skill keeps them (the "Decisions" line of
  the design check, the skill review, `## Q&A`, the spec), and as a line here:
  `- Design check deviation <what>: accepted in Q<n>` or `fixed in <project> <commit>`.
- A change that the developer made by hand during the Review is recorded here, as
  "Uncommitted changes" in the skill describes.

When the outcome is "Review passed", this block becomes the Review result: Step 7
replaces `, in progress` in its heading with nothing and adds the lines that Step 7
names. "Small changes" and "Rework needed" keep the block, add their findings to it,
and replace `, in progress` with nothing.

## 7. Part B, one decision at a time

After Part A, go through Part B in the same way, one item per message:

1. Show what the developer needs to decide it: the diff of the file, the "Before" and
   "After" text of a behavior change, the spec and the code of a deviation, the
   finding and its location, the failed item and its evidence. If the text of a
   behavior change does not match the diff, correct the text first.
2. Say what you recommend, and why, with the evidence.
3. Ask with AskUserQuestion. For a deviation, a finding, a failed item, or a cited
   `failed` entry: "Fix it" (small: here, as in section 5; large: "Rework needed") or
   "Accept it" (a `## Q&A` entry with the stage `review`, and the spec updated so that
   it describes the code). For a behavior change or a workspace file: confirmed, or
   what has to change. For an assumption: still holds, or not. For an evidence entry
   that cannot be checked: accepted untested (a `## Q&A` entry), or not.
4. Record the decision right away (section 6), and commit as in section 4, step 5.

## 8. Pausing and continuing

The developer can stop after any item. Then commit what is recorded, and choose
"Still reviewing" (Step 7). The block keeps its `, in progress` heading and its
`Left:` line.

When a review continues and `## Notes` has a `### Review (…, in progress)` block,
show the items that have a result, and continue with the first item in `Left:`. A
result of Part A still counts when no project commit after it changed code that the
item covers. Otherwise, say so, and check that item again.
