# Migrations

One file per plugin version that needs more than new template text when a repository
is upgraded. `references/upgrade.md` applies them in version order, between the
version recorded in the repository and the installed plugin version.

## When a version needs a file

Re-rendering the managed blocks (`<!-- ss-workflow:managed -->`) already carries new
rule text into a repository. A version needs a migration file when it changes
anything that this cannot carry:

- a key of the "Workflow settings" block is added, renamed, or removed, or its
  allowed values change
- the request file format changes: the frontmatter, a section, or its order
- a generated file is added, renamed, moved, or removed, or text outside the managed
  blocks has to change (`.gitignore`, a README, a section that the developer owns)
- a skill is renamed, or a step moves from one skill to another, so that text which
  the developer wrote may point to the old name
- the workflow behaves differently in a way that the developer has to know before the
  next request, even when no file changes

A version that only rewords rules inside managed blocks needs no file.

`tests/migrations.sh` in the plugin repository fails when the templates changed since
the last release tag and no migration file for a newer version exists.

## Format

The file name is the plugin version that introduces the change: `0.5.0.md`.

```markdown
# Migration to <version>

## What changes

<How the workflow behaves differently after this upgrade, in plain words, one item
per change: what an agent did before, and what it does now. The upgrade shows this
part to the developer before it changes anything.>

## Steps

<Numbered steps. Each one says which file it changes, what it changes, the value
that keeps the old behavior, and whether it needs the developer's answer. A step must
be safe to run a second time: say how to tell that it is already done.>

## Check

<What must hold afterwards, as commands or as facts that can be looked up.>
```

Rules for the steps:

- Never rewrite text that the developer owns without showing the change and getting
  an answer.
- Never edit an `## Original` section, and never change a `## Q&A` entry that has an
  answer.
- Request files of claimed requests live on their request branch. A migration does
  not check out request branches. If a format change has to reach those files, the
  skills that write them make it the next time they change the file, and the
  migration says so.
- Prefer a default that keeps the behavior of the old version. A change of behavior
  is the developer's choice.
