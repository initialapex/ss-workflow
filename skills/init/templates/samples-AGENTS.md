# samples/

Sample and demo projects that show how to use the code in `{{SOURCE_DIR}}/`. Samples
also serve as manual tests during Review.

<!-- ss-workflow:managed id=samples-rules -->
## Rules

- One folder per sample, with a `README.md` that describes what it demonstrates and how
  to run it.
- A sample uses the current code in `{{SOURCE_DIR}}/`, not a released or packaged
  copy, so that it always exercises the latest changes.
- Keep samples small and focused; one scenario per sample is better than one large demo.
- When a request adds or changes the public interface, update or add a sample that
  shows it.
- Register new samples with the build in the way that the "Project rules" in
  `{{SOURCE_DIR}}/AGENTS.md` describe.
- Samples are run during Review, in the root checkout. Do not run them in a worktree.
<!-- /ss-workflow:managed -->
