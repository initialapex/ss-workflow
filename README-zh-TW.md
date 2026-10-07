[English](README.md) | 繁體中文

# ss-workflow

一個 Claude Code plugin，在 gitflow 之上為 repo 建立以 request 為核心的開發流程。每個變更都從一個 request 檔開始，在自己的 git worktree 裡實作，由 developer review，再由 skill 依照固定的規則 merge 和 release。

> **狀態：0.1.0，早期版本。** 五個 skill 都已寫完，plugin manifest 也通過驗證，但整套流程還沒有在實際專案上完整跑過一次。

## Skills

| Skill | 使用時機 | 做什麼 |
|-------|----------|--------|
| `/ss-workflow-init` | 每個 repo 一次，plugin 更新後再跑一次 | 建立檔案結構、git branch、`AGENTS.md` / `CLAUDE.md` 和 README。也能轉換既有專案，或升級由舊版建立的 repo。 |
| `/ss-workflow-new-req` | 有新功能、修正或其他變更 | 在 `reqs/` 建立 request 檔，跟你討論規格，你確認後標為 `ready`。 |
| `/ss-workflow-check-req` | 想看有哪些待辦，或要開始、繼續實作 | 列出未完成的 request、修復異常狀態、把一個 `ready` 的 request 認領到自己的 worktree 並實作。在 request worktree 裡執行時，會接續實作或詢問 review 結果。 |
| `/ss-workflow-merge` | request 已 review，或 release / hotfix 準備好了 | 依 branch 種類 merge，為 release 和 hotfix 建立 tag，並刪除 worktree 和 branch。 |
| `/ss-workflow-release` | 要釋出新版本 | 推薦版本號、建立 release branch、檢查未完成的工作、設定版本號，然後交給 release merge。 |

每個 skill 都屬於 `ss-workflow` plugin，完整名稱是 `/ss-workflow:ss-workflow-init`，其餘類推。沒有其他 skill 使用相同名稱時，Claude Code 也接受上表的短名稱。

## Request 的流程

```mermaid
flowchart LR
    draft -->|你確認規格| ready
    ready -->|在 develop 上認領| in-progress
    in-progress -->|實作並驗證完成| review
    review -->|要求修改| in-progress
    review -->|merge 進 develop| done
```

| Status | 意義 | 由誰設定 |
|--------|------|----------|
| `draft` | 規格討論中 | `/ss-workflow-new-req` |
| `ready` | 你已確認規格，等待認領 | `/ss-workflow-new-req` |
| `in-progress` | 已認領，在 worktree 實作中 | `/ss-workflow-check-req` |
| `review` | 實作完成，等待你 review | `/ss-workflow-check-req` |
| `done` | 已關閉，檔案在 `reqs/done/` | `/ss-workflow-merge` |

一個 request 就是一個 Markdown 檔，例如 `reqs/REQ-0012-20260907-gui-button.md`。狀態只記錄在它的 YAML frontmatter 裡，你原始提供的內容會原封不動保留在 `## Original` 區段。

## Branching model

| Branch | 從哪裡開 | Merge 到哪裡 | 範例 |
|--------|----------|--------------|------|
| Request | `develop` | `develop` | `feat/REQ-0012-gui-button` |
| Release | `develop` | `master` 和 `develop`，並建立 tag | `release/v1.0.0-beta1` |
| Hotfix | `master` | `master` 和 `develop`，並建立 tag | `hotfix/v1.0.1` |

- `master`（或 `main`）只接收 release 和 hotfix。v1.0.0 之前，也允許把 `develop` 直接 merge 進來。
- Request 和 hotfix branch 都在 `.claude/worktrees/` 底下的 git worktree 實作，所以多個 session 可以平行處理多個 request。
- 所有 merge 都用 `--no-ff`。可以在 local merge，也可以透過 GitHub 或 GitLab 的 merge request。

## Init 之後的檔案結構

```
repo/
├─ AGENTS.md, CLAUDE.md      給 agent 看的流程規則（CLAUDE.md 只 import AGENTS.md）
├─ README.md, README-zh-TW.md
├─ Directory.Build.props     唯一的版本來源（.NET 專案）
├─ src/                      原始碼專案，一個專案一個資料夾，各有 README.md
├─ reqs/                     未完成的 request；完成的在 reqs/done/
├─ docs/                     專案規格、developer 文件、知識庫
├─ external/                 submodule 和第三方 binary
├─ tests/                    測試專案（可選）
└─ samples/                  sample / demo 專案（可選）
```

這個結構以 Visual Studio / .NET 專案為主。其他類型的專案，init 會問你要保留哪些部分。

## 需求

- [Claude Code](https://code.claude.com/docs)
- git
- 選用：`gh` 或 `glab` CLI，用來在 GitHub 或 GitLab 發 merge request
- 選用：.NET SDK，用於 .NET 專案

## 安裝

把這個 repo 加為 plugin marketplace，再安裝 plugin。在 Claude Code session 裡執行：

```
/plugin marketplace add <owner>/ss-workflow
/plugin install ss-workflow@ss-workflow
```

把 `<owner>/ss-workflow` 換成 GitHub repo；其他平台請用完整的 git URL。

想讓專案的所有成員都取得這個 plugin，可以讓 `/ss-workflow-init` 把 marketplace 註冊到專案的 `.claude/settings.json`。

## 快速開始

```
/ss-workflow-init                      設定 repo（回答問題）
/ss-workflow-new-req 加入深色主題      建立 request 並確認規格
/ss-workflow-check-req                 認領並在 worktree 實作
/ss-workflow-merge                     你 review 完之後，merge 進 develop
/ss-workflow-release                   釋出新版本
```

## 更新

Marketplace 會拿 `.claude-plugin/plugin.json` 的 `version` 跟已安裝的版本比對。

```
/plugin marketplace update ss-workflow
```

Plugin 更新不會改動 init 在你專案裡產生的檔案。更新之後，請在專案裡再執行一次 `/ss-workflow-init`。它會比對 root `AGENTS.md` 記錄的 `ss-workflow-version` 和 plugin 版本，只更新標記為 `<!-- ss-workflow:managed -->` 的區段，區段以外你自己寫的內容不會被改動。

## 開發這個 plugin

```
.claude-plugin/
├─ plugin.json               plugin manifest；"version" 是唯一的版本來源
└─ marketplace.json          讓這個 repo 同時是自己的 marketplace
skills/
├─ ss-workflow-init/         SKILL.md、references/、templates/
├─ ss-workflow-new-req/      SKILL.md
├─ ss-workflow-check-req/    SKILL.md、references/
├─ ss-workflow-merge/        SKILL.md、references/
└─ ss-workflow-release/      SKILL.md、references/
ss-workflow-skill.md         設計規格
```

驗證 manifest，以及在單一 session 從工作目錄載入 plugin：

```bash
claude plugin validate .
```

```bash
claude --plugin-dir /path/to/ss-workflow
```

發佈變更時，要遞增 `.claude-plugin/plugin.json` 的 `version`。版本沒有變，已安裝的副本就不會更新。

各個 skill 背後的設計決定記錄在 [ss-workflow-skill.md](ss-workflow-skill.md)。

## 授權

MIT
