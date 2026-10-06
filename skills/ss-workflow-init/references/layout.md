# Target layout and templates

All templates are in `${CLAUDE_PLUGIN_ROOT}/skills/ss-workflow-init/templates/`.

```
repo/
├─ AGENTS.md                  ← root-AGENTS.md
├─ CLAUDE.md                  ← CLAUDE.md
├─ README.md                  ← README.md
├─ README-zh-TW.md            ← README-zh-TW.md          (when zh-TW is in {{README_LANGS}})
├─ .gitignore                 ← dotnet new gitignore / gitignore.template, plus the ss-workflow block
├─ Directory.Build.props      ← Directory.Build.props    (.NET only)
├─ {{SOLUTION_FILE}}          (.NET only; existing, or created with dotnet new sln on approval)
├─ .claude/settings.json      (Step 8, written by `claude plugin ... --scope project`)
├─ src/
│   ├── AGENTS.md             ← src-AGENTS.md
│   ├── CLAUDE.md             ← CLAUDE.md
│   └── <project>/README.md   ← project-README.md        (for each project without a README)
├─ reqs/
│   ├── AGENTS.md             ← reqs-AGENTS.md
│   ├── CLAUDE.md             ← CLAUDE.md
│   └── done/.gitkeep
├─ docs/
│   └── {{PROJECT_SLUG}}-spec.md ← project-spec.md
├─ external/.gitkeep
├─ tests/                     (when {{HAS_TESTS}})
│   ├── AGENTS.md             ← tests-AGENTS.md
│   └── CLAUDE.md             ← CLAUDE.md
└─ samples/                   (when {{HAS_SAMPLES}})
    ├── AGENTS.md             ← samples-AGENTS.md
    └── CLAUDE.md             ← CLAUDE.md
```

## Rules

- Every `CLAUDE.md` comes from the same template. It imports the sibling `AGENTS.md`
  and adds nothing else unless the developer asks for Claude-specific rules.
- Language: AGENTS.md and CLAUDE.md files use `{{AGENT_DOC_LANG}}`, and the templates
  are written in English. If `{{AGENT_DOC_LANG}}` is not English, translate the prose,
  but keep headings that other skills look up (for example `## Branching model`,
  `## Commit convention`, `## Request file format`) in English.
- Write `README.md` in English and `README-zh-TW.md` in Traditional Chinese. Each one
  links to the other at the top.
- `docs/{{PROJECT_SLUG}}-spec.md` uses `{{DOCS_LANG}}`.
- For a non-.NET project, drop the `.sln`-specific and `Directory.Build.props`-specific
  lines from the AGENTS templates, and point "Versioning" at `{{VERSION_SOURCE}}`.
- Empty folders get a `.gitkeep`, so git keeps them.
- Remove the lines that mention opted-out parts: the `samples/` link when there is no
  `samples/`, and the `{{TEST_COMMAND}}` line when there is no `tests/`. In root
  `AGENTS.md`, remove the matching rows of the layout table.
- Ownership:
  - Files with `<!-- ss-workflow:managed -->` blocks (every AGENTS.md) are partly
    maintained by upgrades.
  - All other generated files (READMEs, spec, `Directory.Build.props`, `CLAUDE.md`)
    belong to the developer after init, and upgrades never touch them.
