---
type: llm
focus: trace
weight: 1
---

On release/v0.2.0 there is a separate commit 'docs: update the changelog for v0.2.0-rc1' (no REQ-, no Refs:) that adds only CHANGELOG.md to SSLib, made before the tag v0.2.0-rc1. The file starts with '# CHANGELOG' and has a section '## v0.2.0-rc1' with a '### feature' entry for the greeting text file and a '### bugfix' entry for keeping the notes file in the build output, and a '### contribution' list whose entries have the form '<name> (<email>)'. Because SSLib had no CHANGELOG.md, the file also has a '## v0.1.0' section made from the git history, below it. No entry names a request id or the workspace.
