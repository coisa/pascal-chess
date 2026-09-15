# The college-project AI challenge

Find an old project that you are allowed to share. Keep its defining constraint
and ask your AI to make the strongest useful version it can actually implement
and verify today. For this project, that constraint was Pascal.

Copy this prompt and replace the brackets:

```text
This repository began as my university project: [what it did].
Its original constraint was [language, platform, hardware or assignment rule].
Keep that constraint meaningful: [what must remain in that language/system].

I am giving you a simple challenge: make the best version of this project you
can implement and verify today. Inspect the original first. Fix the underlying
behavior, then make the experience feel finished: clear interaction, thoughtful
visuals, animation where it helps, accessibility controls and graceful errors.
Choose features that serve the project instead of adding decoration alone.

Write the source, UI and documentation in English. Explain that this was a
college project revisited through a simple AI prompt. Do not invent my course,
institution, grade or a claim that your model is objectively the best.

Preserve the original in Git. Work on an isolated branch. Provide a reproducible
build, meaningful tests and evidence from the actual running application.
Document what changed, what you tested and what remains limited. Include a
reusable version of this prompt so others can try their own projects.

Do the implementation, not just a proposal. Ask only when missing information
or a material decision blocks progress. Do not copy credentials or publish,
merge, deploy or change external settings unless I authorize that delivery step.
Finish with the runnable result, its evidence and the comparison to the original.
```

If you want the same release workflow, add your own explicit instruction to
preserve the current default-branch commit as `0.1.0`, create an issue and PR,
verify checks/review, merge and publish `1.0.0`. Choose different versions when
the repository already has releases. Unarchiving, Wiki automation, credentials
and deployment are separate, concrete decisions.

## Judge the result

Run the original and the new version, where possible. Try an ordinary task,
an invalid input and a boundary case. Look for correct behavior before counting
features. Inspect the rendered application instead of trusting a mockup. Check
that the original constraint still owns the important logic, and read the
test output rather than accepting an unsupported claim that everything passed.

For chess, pretty pieces are only the beginning: try a pinned en-passant pawn,
castling through check, underpromotion, undo and a drawn ending. For another
project, find the equivalent hard cases. Publish limitations as plainly as
the improvements. That makes comparisons between AI tools useful and fair.
