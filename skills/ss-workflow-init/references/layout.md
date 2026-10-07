# Target layout and templates

All templates are in the `templates/` folder of this skill. `SKILL.md` gives its full
path under "Ground rules".

The workflow needs the files marked **(workflow)**. Everything else follows the
answers from the questionnaire, because it depends on the project type.

```
repo/
├─ AGENTS.md                  ← root-AGENTS.md           (workflow)
├─ CLAUDE.md                  ← CLAUDE.md                (workflow)
├─ README.md                  ← README.md
├─ README-zh-TW.md            ← README-zh-TW.md          (when zh-TW is in {{README_LANGS}})
├─ .gitignore                 ← gitignore.template       (workflow: the ss-workflow block)
├─ .claude/settings.json      (Step 8, written by `claude plugin ... --scope project`)
├─ reqs/                      (workflow)
│   ├── AGENTS.md             ← reqs-AGENTS.md
│   ├── CLAUDE.md             ← CLAUDE.md
│   └── done/.gitkeep
├─ docs/                      (workflow)
│   └── {{PROJECT_SLUG}}-spec.md ← project-spec.md
├─ {{SOURCE_DIR}}/            (default: src/)
│   ├── AGENTS.md             ← src-AGENTS.md
│   ├── CLAUDE.md             ← CLAUDE.md
│   ├── <main project file>   ({{PROJECT_FILE}}, if the project has one)
│   └── <project>/README.md   ← project-README.md        (for each project or module without a README)
├─ external/.gitkeep          (when {{HAS_EXTERNAL}})
├─ tests/                     (when {{HAS_TESTS}})
│   ├── AGENTS.md             ← tests-AGENTS.md
│   └── CLAUDE.md             ← CLAUDE.md
└─ samples/                   (when {{HAS_SAMPLES}})
    ├── AGENTS.md             ← samples-AGENTS.md
    └── CLAUDE.md             ← CLAUDE.md
```

Other top-level folders that the toolchain needs (from the questionnaire) stay where
they are. Init only lists them in the "Repository layout" table of root `AGENTS.md`.

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
- Init does not create project files, build files, or version files. If the project
  has no main project file yet, it is created by the developer or by the first
  request. By default the main project file lives in the source folder, for example
  `src/MyApp.sln`.
- `.gitignore`: if the repository already has one, keep it, and add the ss-workflow
  block and the missing `{{IGNORE_PATTERNS}}`. Otherwise, create it from the template.
- Empty folders get a `.gitkeep`, so git keeps them.
- Remove the lines that mention parts the project does not use: the `samples/` link
  when there is no `samples/`, an empty build or test command in the README, and the
  matching rows of the layout table in root `AGENTS.md`.
- When a free-text answer (`{{TOOLCHAIN_NOTES}}`, `{{PROJECT_RULES}}`,
  `{{IGNORE_PATTERNS}}`) is empty, write a one-line note that nothing is recorded yet,
  so that the section is not left blank.
- Ownership:
  - Text inside `<!-- ss-workflow:managed -->` blocks is maintained by upgrades.
  - Everything else belongs to the developer after init, and upgrades never touch it:
    the "Workflow settings" values, "Toolchain", "Repository layout", and "Project
    rules" sections, the READMEs, the spec, and `CLAUDE.md`.
