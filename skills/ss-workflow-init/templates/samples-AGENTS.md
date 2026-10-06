# samples/

Sample and demo projects that show how to use the library in `src/`. Samples also serve
as manual GUI tests.

<!-- ss-workflow:managed id=samples-rules -->
## Rules

- One folder per sample, with a `README.md` that describes what it demonstrates and how
  to run it.
- Reference the library through `<ProjectReference>` to `src/`, not through a
  package, so that samples always exercise the current code.
- Keep samples small and focused; one scenario per sample is better than one large demo.
- When a request adds or changes public API, update or add a sample that shows it.
- Add every sample project to `{{SOLUTION_FILE}}`.
<!-- /ss-workflow:managed -->
