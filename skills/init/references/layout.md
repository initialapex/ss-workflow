# Target layout and templates

All templates are in the `templates/` folder of this skill. `SKILL.md` gives its full
path under "Ground rules".

The workspace is the only layout that ss-workflow supports. It holds the files below.
The projects are git submodules in `src/`, and init writes nothing into them.

```
workspace/
├─ AGENTS.md                  ← root-AGENTS.md           ({{PROJECTS}}: projects-entry.yaml per project)
├─ CLAUDE.md                  ← CLAUDE.md
├─ README.md                  ← README.md                ({{PROJECT_ROWS}})
├─ README-zh-TW.md            ← README-zh-TW.md          (when zh-TW is in {{README_LANGS}})
├─ .gitignore                 ← gitignore.template       (the ss-workflow block)
├─ .gitmodules                (written by `git submodule add`)
├─ .claude/settings.json      (Step 8, written by `claude plugin ... --scope project`)
├─ reqs/
│   ├── AGENTS.md             ← reqs-AGENTS.md
│   ├── CLAUDE.md             ← CLAUDE.md
│   └── done/.gitkeep
├─ docs/
│   └── {{PROJECT_SLUG}}-spec.md ← project-spec.md
└─ src/
    ├── AGENTS.md             ← src-AGENTS.md            ({{PROJECT_SECTIONS}}: src-AGENTS-project.md per project)
    ├── CLAUDE.md             ← CLAUDE.md
    └── <name>/               (submodule; the project's own layout, untouched)
```

There is no `tests/`, `samples/`, or `external/` folder in the workspace: each project
keeps its tests, samples, and third-party files where its toolchain puts them, in its
own repository.

## Rules

- Every `CLAUDE.md` comes from the same template. It imports the sibling `AGENTS.md`
  and adds nothing else unless the developer asks for Claude-specific rules.
- Language: AGENTS.md and CLAUDE.md files use `{{AGENT_DOC_LANG}}`, and the templates
  are written in English. If `{{AGENT_DOC_LANG}}` is not English, translate the prose,
  but keep headings that other skills look up (for example `## Branching model`,
  `## Commit convention`, `## Request file format`, `## Project: <name>`) and the keys
  of "Workflow settings" in English.
- Write `README.md` in English and `README-zh-TW.md` in Traditional Chinese. Each one
  links to the other at the top.
- The root README files keep the layout of their templates: a centered title, the
  description, then the language links, the key points, a collapsible table of
  contents, and the sections. When you fill them in:
  - Keep the table of contents in step with the sections. If you remove or add a
    section, change its entry too.
  - The workspace has no version, so it has no version badge. Do not add a badge for
    something that is not known, such as a license that the workspace does not have
    yet.
  - Tag every code block with a language. For commands, use the tag of the shell that
    they run in (`bash`, `powershell`, `bat`), and `text` when nothing fits.
  - Use GitHub alerts (`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`) for
    side notes, and not for normal text.
- `docs/{{PROJECT_SLUG}}-spec.md` uses `{{DOCS_LANG}}`.
- Init does not create project files, build files, or version files, and does not
  write into the project repositories. If a project has no main project file yet, it
  is created by the developer or by the first request, in that project's repository.
- `.gitignore`: if the workspace already has one, keep it, and add the ss-workflow
  block. Build output is ignored by each project's own `.gitignore`.
- Empty folders get a `.gitkeep`, so git keeps them.
- When a free-text answer (`{{ENTRY_TOOLCHAIN_NOTES}}`, `{{ENTRY_PROJECT_RULES}}`) is
  empty, write a one-line note that nothing is recorded yet, so that the section is
  not left blank. An empty key in a `projects` entry stays empty (`build-command:`).
- **Add project** mode appends: one entry to `projects` in root `AGENTS.md`, one
  section to `src/AGENTS.md`, and one row to the project table of each root README.
  These are outside the managed blocks, so show the change to the developer first.
- Ownership:
  - Text inside `<!-- ss-workflow:managed -->` blocks is maintained by upgrades.
  - Everything else belongs to the developer after init, and upgrades never rewrite
    it: the "Workflow settings" values (including `projects`), "Repository layout",
    the `## Project: <name>` sections, "Project notes", the READMEs, the spec, and
    `CLAUDE.md`. When a new version needs a change there, for example a new setting,
    its migration file says so, and the upgrade proposes that change to the developer.
