---
type: llm
focus: trace
weight: 1
---

Each request has its own branch '<type>/REQ-<id>-<slug>' (fix/REQ-0007-..., and refactor/... and feat/... for the other two), each created from develop, not from the branch of another part, and each holding only its own request file in reqs/.
