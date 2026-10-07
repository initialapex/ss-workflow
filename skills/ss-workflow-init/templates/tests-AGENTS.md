# tests/

Test projects for the projects in `src/`.

<!-- ss-workflow:managed id=tests-rules -->
## Rules

- One test project per source project. Name it `<SourceProject>.Tests`, for example
  `tests/MyLib.Tests/` for `src/MyLib/`.
- Mirror the source project's folder and namespace structure, so that each test is easy
  to find.
- A request that changes behavior in `src/` adds or updates tests here in the same
  branch.
- Tests must not depend on machine-specific paths, network access, or execution
  order.
- Add every test project to `{{SOLUTION_FILE}}`.
- Run: `{{TEST_COMMAND}}`. Tests run during Verify, in the root checkout. In a
  worktree, write the tests but do not run them.
<!-- /ss-workflow:managed -->
