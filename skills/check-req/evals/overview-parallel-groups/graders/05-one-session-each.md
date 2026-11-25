---
type: llm
focus: trace
weight: 1
---

The agent says that one session implements one request, so that REQ-0002 gets a session of its own when REQ-0001 is started here (or the reverse), and that it will start that session when it can, or gives the developer the line '/ss-workflow:check-req REQ-0002' to run in a new session in the root checkout.
