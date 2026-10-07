# tests/

Automated tests for the code in `{{SOURCE_DIR}}/`.

<!-- ss-workflow:managed id=tests-rules -->
## Rules

- Keep the tests of one project or module together, in a folder named after it, so
  that each test is easy to find.
- A request that changes behavior in `{{SOURCE_DIR}}/` adds or updates tests here in
  the same branch.
- Tests must not depend on machine-specific paths, network access, or execution
  order.
- Register new tests with the build in the way that the "Project rules" in
  `{{SOURCE_DIR}}/AGENTS.md` describe.
- Run the tests with `test-command` from the root `AGENTS.md`. Tests run during
  Verify, in the root checkout. In a worktree, write the tests but do not run them.
<!-- /ss-workflow:managed -->
