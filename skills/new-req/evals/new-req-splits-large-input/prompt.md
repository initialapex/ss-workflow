---
tags: [skill-creator, new-req]
max_turns: 60
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Write, Edit, Bash]
---

SSLib 有三件事要處理：(1) build.sh 在 version.txt 缺少時會直接當掉而且沒有任何訊息，客戶已經卡住，一定要先修；(2) 想順便把 build.sh 重新整理成每個步驟一個函式；(3) 另外想在 bin/ 底下多產生 version.out，內容就是 version.txt 的內容，還要把 SSLib 的 README 補上這個說明

Input files: ws/ (the root checkout of the ss-workflow workspace; run from there)
