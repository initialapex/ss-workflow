---
type: llm
focus: trace
weight: 1
---

The run ends in the manual check, one item at a time: it shows the plan of the manual check once, then only the first item (what to do or start, what the agent observes itself, and the expected result) and waits for the developer, instead of handing over the whole list to check and report at once; the agent does not choose 'Review passed' or 'Rework needed' itself, and the request status is still review.
