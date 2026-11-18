---
type: llm
focus: trace
weight: 1
---

The spec describes the change to build.sh by what can be observed: bin/version.out is created from version.txt, where it happens relative to the existing steps, what happens when the file already exists, and what happens (exit status, message) when the copy fails; it contains no script command and no changed script line.
