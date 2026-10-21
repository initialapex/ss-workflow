<h1 align="center">ss-workflow</h1>

<p align="center">
  建立在 gitflow 之上、以 request 為核心的開發流程，以 Claude Code plugin 的形式提供。
</p>

<p align="center">
  <img alt="Version 0.7.0" src="https://img.shields.io/badge/version-0.7.0-blue">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-green"></a>
  <a href="https://code.claude.com/docs"><img alt="Claude Code plugin" src="https://img.shields.io/badge/Claude%20Code-plugin-d97757"></a>
  <img alt="Project type: any" src="https://img.shields.io/badge/project%20type-any-lightgrey">
</p>

<p align="center">
  <a href="README.md">English</a> | 繁體中文
</p>

一個 Claude Code plugin，在 gitflow 之上為你的專案建立以 request 為核心的開發流程，而且不改變專案 repo 原本的檔案架構。外面包一層 workspace repo：它放 request 與工作流的檔案，每個專案以 git submodule 加入。每個變更都從一個 request 檔開始，規格由你確認；agent 在獨立的 git worktree 裡實作，你在根目錄驗證和 review，再由 skill 依照固定的規則 merge 和 release。

- 專案維持自己的檔案架構，以 submodule 加入 workspace (remote URL 或 local 路徑都可以)；一個 workspace 可以有多個專案。
- 專案的歷史只有實作的 commit。規格討論、request 狀態與 review 結果都 commit 在 workspace。
- 每個專案有自己的版本號：沒有修改的專案不需要進版。
- 每個變更都是一個 request 檔，規格（包含軟體架構）經你確認之前不會開始實作。
- Agent 在各自的 git worktree 裡實作，所以多個 session 可以平行處理多個 request。
- Verify、可選的 code review 和你的人工 review 都在根目錄的 request branch 上進行。
- Merge 和 release 依照固定的 gitflow 規則：`--no-ff` merge、tag 和推薦的版本號。
- 不相依任何一種專案形式：Visual Studio solution、Keil 專案、ESP32 firmware 或其他類型，用法都一樣。
- 沒有 remote 也能用，可以搭配任何 git remote，也可以搭配 GitHub 或 GitLab 的 merge request。由設定決定 agent 是自動 push、先詢問，還是完全不 push。
- 每個 request 都保留問過的問題和你的回答；每一份結果都會寫明什麼有跑、什麼失敗、什麼沒跑。

> [!WARNING]
> **狀態：0.7.0，早期版本。** 六個 skill 都已寫完，plugin manifest 也通過驗證，但整套流程還沒有在實際專案上完整跑過一次。

<details>
<summary>目錄</summary>

- [開始使用](#開始使用)
  - [需求](#需求)
  - [安裝](#安裝)
  - [快速開始](#快速開始)
- [Skills](#skills)
- [Request 的流程](#request-的流程)
- [Branching model](#branching-model)
- [Remote 與 push](#remote-與-push)
- [Workspace 的檔案結構](#workspace-的檔案結構)
- [專案形式](#專案形式)
- [更新](#更新)
- [開發這個 plugin](#開發這個-plugin)
- [授權](#授權)

</details>

## 開始使用

### 需求

- [Claude Code](https://code.claude.com/docs)
- git
- 選用：`gh` 或 `glab` CLI，用來在 GitHub 或 GitLab 發 merge request
- 你的專案自己的 toolchain 所需的工具。Plugin 本身不需要其中任何一項。

### 安裝

把這個 repo 加為 plugin marketplace，再安裝 plugin。在 Claude Code session 裡執行：

```text
/plugin marketplace add <owner>/ss-workflow
/plugin install ss-workflow@ss-workflow
```

把 `<owner>/ss-workflow` 換成 GitHub repo；其他平台請用完整的 git URL。

> [!TIP]
> 想讓 workspace 的所有成員都取得這個 plugin，可以讓 `/ss-workflow:init` 把 marketplace 註冊到 workspace 的 `.claude/settings.json`。

### 快速開始

在一個新的空資料夾裡，例如 `SSDisp-workspace`：

```text
/ss-workflow:init https://github.com/me/SSDisp.git   建立 workspace 並加入專案 (URL 或 local 路徑)
/ss-workflow:init --add ../SSLib                      之後再加入其他專案
/ss-workflow:new-req 加入深色主題                     建立 request 並確認規格
/ss-workflow:check-req                                認領並在 worktree 實作
/ss-workflow:review                                   在根目錄驗證和 review
/ss-workflow:merge                                    驗收：先 merge 各專案，再關閉 request
/ss-workflow:release SSDisp                           釋出某個專案的新版本
```

## Skills

| Skill | 使用時機 | 在哪裡執行 | 做什麼 |
|-------|----------|------------|--------|
| `/ss-workflow:init` | 每個 workspace 一次、加入專案時，以及 plugin 更新後 | 根目錄 | 建立 workspace：git branch、`AGENTS.md` / `CLAUDE.md` 和 README，並以 URL 或 local 路徑把專案加入為 submodule。也能轉換 0.5.0 以下的 repo，或升級由舊版建立的 workspace。 |
| `/ss-workflow:new-req` | 有新功能、修正或其他變更 | 根目錄，`req/` branch | 撰寫 request 檔，決定它修改哪些專案，跟你討論規格，你確認後以 `ready` 狀態 merge 進 `develop`。 |
| `/ss-workflow:check-req` | 想看有哪些待辦，或要開始、繼續實作 | 總覽和認領在根目錄；實作在 worktree | 列出所有 request、修復異常狀態，在 workspace 與各專案建立 branch 和 worktree 來認領一個 `ready` 的 request 並實作。完成後標為待 review 並刪除 worktree。 |
| `/ss-workflow:review` | 有實作完成的 request 在等你 | 根目錄，request branch | Verify：執行各專案的 build、測試和驗證 script。Code review（可選）：檢查這個 request 的變更有沒有 bug。Review：引導你人工驗證。小問題當場修正，需要大改則退回重做。 |
| `/ss-workflow:merge` | 你驗收了一個 request，或 release / hotfix 準備好了 | 根目錄 | 先 merge 各專案的 branch，再關閉 request 並 merge workspace 的 branch；為 release 和 hotfix 建立 tag，並刪除 branch。 |
| `/ss-workflow:release` | 要釋出某個專案的新版本 | 根目錄 | 推薦該專案的版本號、建立它的 release branch、檢查它未完成的工作、設定版本號，然後交給 release merge。 |

> [!NOTE]
> 根目錄指的是 workspace 的主要 checkout。測試、script 和執行檔只在根目錄執行。在 worktree 裡執行程式的限制比較多，所以 agent 在 worktree 裡只寫程式並嘗試編譯。

每個 skill 都屬於 `ss-workflow` plugin，所以名稱以 `/ss-workflow:` 開頭。請一律輸入這個前綴：後面的名稱很短也很常見，其中像 `/init` 本身就是 Claude Code 的內建指令。

## Request 的流程

```mermaid
flowchart LR
    draft -->|你確認規格| ready
    ready -->|某個 session 建立 request branch| in-progress
    in-progress -->|實作完成，刪除 worktree| review
    review -->|需要大改| in-progress
    review -->|你執行 merge skill| done
```

| Status | 意義 | 在哪裡進行 | 由誰設定 |
|--------|------|------------|----------|
| `draft` | 規格討論中 | 根目錄，`req/REQ-…` branch | `/ss-workflow:new-req` |
| `ready` | 你已確認規格，request 在 `develop` 上等待認領 | （無） | `/ss-workflow:new-req` |
| `in-progress` | 已認領，實作中 | workspace 的 worktree，裡面有各專案的 worktree | `/ss-workflow:check-req` |
| `review` | 實作完成，worktree 已刪除、branch 保留；等待或正在 Verify 和 Review | 根目錄，request branch | `/ss-workflow:check-req`，接著 `/ss-workflow:review` |
| `done` | 已關閉，檔案在 `reqs/done/` | 根目錄 | `/ss-workflow:merge` |

一個 request 就是 workspace 裡的一個 Markdown 檔，例如 `reqs/REQ-0012-20260907-gui-button.md`。狀態只記錄在它的 YAML frontmatter 裡，也記錄它修改哪些專案 (`projects: [SSLib, SSDisp]`)；你原始提供的內容會原封不動保留在 `## Original` 區段。

| 區段 | 內容 |
|------|------|
| `## Spec` | 確認過的規格：目標、範圍、架構、acceptance criteria、如何驗證、不包含的範圍 |
| `## Original` | 你原始提供的需求，不會被修改 |
| `## Q&A` | 每一個影響 request 的問題、你的原話回答和因此做出的決定，依發問順序記錄。還沒回答的問題寫 `A: (pending)`。 |
| `## Notes` | Assumption、implementation summary、行為變更，以及 Verify、code review、Review 的結果，都帶日期 |

- Draft 只存在它的 `req/` branch 上，`develop` 上只有你確認過的 request。
- `## Q&A` 裡沒有 pending 的問題，request 才能變成 `ready`。已回答的紀錄不會被改寫：決定改變時是新增一筆。
- 在 workspace 建立 request branch 就是認領：git 保證同名的 branch 只能建立一次，所以兩個 session 不會認領到同一個 request。認領之後，request 的每個專案都會建立同名的 branch。
- request 也可以修改 workspace 自己的檔案：`docs/<專案>/` 的規格、知識庫、`src/AGENTS.md` 的專案規則，這些修改在 Review 由你確認；只改這些檔案的 request 為 `projects: []`。
- 程式碼 commit 在各專案，footer 為 `Refs: <workspace>#REQ-0012`；workspace 以 gitlink 記錄 request 產生了哪些專案 commit。
- Verify 或 Review 發現的小問題，直接在根目錄修正。需要大改的 request 會退回 `in-progress`，回到 worktree 實作。
- Review 期間你可以手動修改程式碼。`/ss-workflow:review` 會列出所有未 commit 的變更（包含新增的檔案），問你每一項是什麼：屬於這個 request（commit）、產生的檔案（加入 `.gitignore`）或不要的（捨棄）。Verify 只有在乾淨的工作目錄上跑才算數。
- Code review 是可選的。`/ss-workflow:review` 在 Verify 通過後會問你要不要跑，並在每個專案用 Claude Code 的 `/code-review` 只檢查這個 request 的變更 (`origin/develop...<request branch>`)。同一次 review 期間之後也可以再要求。結果記錄在 request 的 `## Notes`。
- 結果如實回報。每一項檢查都記為 `passed`、`failed`、`did not run` 或 `not configured`，implementation summary 會列出沒做完的部分。沒跑的檢查不會記成通過。
- 改到會影響 agent 行為的檔案（`AGENTS.md`、`CLAUDE.md`、`.claude/`、skill，或 `agent-files` 設定列出的路徑）時，會當成行為變更來 review：request 會記錄 agent 之前怎麼做、現在怎麼做，由你在 Review 逐項確認。這類變更 build 和測試都看不出來。

## Branching model

workspace 與每個專案都走 gitflow，各自有自己的 `master`（或 `main`）與 `develop`。

| Branch | Workspace | 專案 | 範例 |
|--------|-----------|------|------|
| 規格討論 | 從 `develop` 開、merge 回 `develop` | （無） | `req/REQ-0012-gui-button` |
| Request | 從 `develop` 開、merge 回 `develop` | 同名，從它的 `develop` 開、merge 回去 | `feat/REQ-0012-gui-button` |
| Release | 沒有 branch：`develop` merge 到 `master`，tag 為 `SSDisp/v1.0.0-beta1` | 從 `develop` 開，merge 到 `master` 與 `develop`，tag 為 `v1.0.0-beta1` | `release/v1.0.0-beta1` |
| Hotfix | 從 `master` 開，merge 回 `master` 與 `develop`，tag 為 `SSDisp/v1.0.1` | 從 `master` 開，merge 回 `master` 與 `develop`，tag 為 `v1.0.1` | `hotfix/SSDisp-v1.0.1`、`hotfix/v1.0.1` |

- 專案的 `master` 只接收它自己的 release 和 hotfix。它的 v1.0.0 之前，也允許把 `develop` 直接 merge 進來。
- workspace 的 `master` 是各專案最新 release 的組合：每次 release 都把 `develop` merge 進來，並把每個專案指向它自己的 `master`。
- Request 先逐一 merge 各專案，最後才是 workspace。
- Request 和 hotfix branch 都在 `.claude/worktrees/` 底下的 git worktree 實作，裡面有各專案的 worktree，所以多個 session 可以平行實作多個 request。worktree 只在實作期間存在。
- 規格討論、review、merge 和 release 共用根目錄，所以同一時間只能進行其中一項。
- 所有 merge 都用 `--no-ff`。可以在 local merge，也可以透過 GitHub 或 GitLab 的 merge request。

## Remote 與 push

這個工作流不需要 remote。沒有 remote 時，本機的 `develop` 就是已確認 request 的所在，建立本機 branch 就是認領，所有 branch 都在本機 merge；所有 fetch、pull、push 的步驟都會略過。

workspace 與每個專案各自判斷：專案可以覆寫 workspace 的設定，例如專案的 repo 要求發 merge request，而 workspace 只在你的機器上。有 remote 時，由 root `AGENTS.md` 的 `push-policy` 設定決定 agent 會 push 什麼：

| `push-policy` | Agent 的行為 | 適合 |
|---------------|--------------|------|
| `auto`（預設） | 每次 commit 後 push 自己的 topic branch；你要求 merge 之後 push `develop` | 多台機器或多個 session 共用 remote：認領和狀態變更立刻看得到 |
| `ask` | 只在本機 commit，每次執行 skill 第一次要 push 前先問你 | 想先看過要送出去的內容 |
| `never` | 不 push，也不刪除 remote branch。每個 skill 結束時列出你需要 push 的項目。 | 對「誰可以發佈」有嚴格規定的環境 |

- 不論設定為何，agent 在 push `master` 或 tag 之前一定會再問一次，不會 force-push，也不會在確認已 merge 之前刪除 branch。
- 以沒有 remote 的 local 路徑加入的專案不會 push：它的 remote 會是你自己的 working copy。
- 還沒 push 之前，認領只在這台機器上有效。
- `remote-platform` 是另一個設定，只表示能不能發 merge request（`github`、`gitlab`）。其他 remote 一律是 `none`，branch 在本機 merge 後再 push。
- Remote 拒絕 push 到受保護的 branch 時，skill 不會繞過：改發 merge request，或停下來告訴你需要在 remote 上 merge 什麼。

## Workspace 的檔案結構

```text
SSDisp-workspace/
├─ AGENTS.md, CLAUDE.md      給 agent 看的流程規則與設定（CLAUDE.md 只 import AGENTS.md）
├─ README.md, README-zh-TW.md
├─ reqs/                     未完成的 request；完成的在 reqs/done/
├─ docs/
│  ├─ overview.md            各專案如何一起運作
│  ├─ SSLib/spec.md          各專案的規格，以及它的其他文件
│  └─ SSDisp/spec.md
└─ src/
   ├─ AGENTS.md              各專案的 toolchain 與規則
   ├─ SSLib/                 submodule：SSLib repo，維持它自己的結構
   └─ SSDisp/                submodule：SSDisp repo，維持它自己的結構
      ├─ SSDisp.sln
      ├─ SSDisp/
      └─ SSDisp.Test/
```

init 不會寫入專案的任何檔案。專案的測試、sample 與第三方檔案，都依它的 toolchain 放在原本的位置。

> [!IMPORTANT]
> ss-workflow 0.5.0 以下建立的 repo 把程式碼與 request 放在同一個 repo。在那裡執行 `/ss-workflow:init` 會進行轉換：舊 repo 變成專案的 repo，保留 remote、歷史與 tag，並回到它 toolchain 原本的結構；旁邊建立新的 workspace，接收 request、draft 與文件。轉換時不能有進行中的 request、release 或 hotfix。

## 專案形式

Plugin 不內建任何 toolchain 的範本或指令。init 時你用自己的話描述每個專案的類型，agent 提出下表各項的建議值讓你確認。這些內容存在 workspace 裡，所有 skill 都從那裡讀取。

| 內容 | 存放位置 |
|------|----------|
| 每個專案的 branch、主要專案檔、版本號來源，以及 setup、build、test、verify 指令 | root `AGENTS.md`「Workflow settings」的 `projects` 中該專案的項目 |
| 其他會影響 agent 行為的檔案，例如產品內附的 prompt 檔（`agent-files`） | root `AGENTS.md` 的「Workflow settings」 |
| 需要的工具、不在 `PATH` 上的工具怎麼找、已知限制 | `src/AGENTS.md` 該專案章節的「Toolchain」 |
| 新檔案和專案如何加入 build、哪些是產生的檔案、命名慣例 | `src/AGENTS.md` 該專案章節的「Project rules」 |
| 要忽略的 build 輸出和本機檔案 | 專案自己的 `.gitignore` |

> [!NOTE]
> 指令可以留空，例如只能在 IDE 裡 build 的專案。這時 skill 會略過該步驟並回報「未設定」，不會自行編造指令。

## 更新

Marketplace 會拿 `.claude-plugin/plugin.json` 的 `version` 跟已安裝的版本比對。

```text
/plugin marketplace update ss-workflow
```

> [!IMPORTANT]
> Plugin 更新不會改動 init 在你 workspace 裡產生的檔案。更新之後，請在 workspace 裡再執行一次 `/ss-workflow:init`。它會比對 root `AGENTS.md` 記錄的 `ss-workflow-version` 和 plugin 版本，只更新標記為 `<!-- ss-workflow:managed -->` 的區段，區段以外你自己寫的內容不會被改動。

有些版本需要的不只是新的規則文字，例如新增設定或改變 request 檔的格式。這類版本都會附一份 migration 檔 `skills/init/migrations/<version>.md`。升級時會從你 repo 記錄的版本開始，依版本順序逐一套用到已安裝的版本。每一份都會先告訴你工作流的行為有什麼不同，再提出 managed 區段以外需要的修改；沒有你的回答，不會動那些內容。

## 開發這個 plugin

```text
.claude-plugin/
├─ plugin.json               plugin manifest；"version" 是唯一的版本來源
└─ marketplace.json          讓這個 repo 同時是自己的 marketplace
skills/
├─ init/                     SKILL.md、references/、templates/、migrations/
├─ new-req/                  SKILL.md
├─ check-req/                SKILL.md、references/
├─ review/                   SKILL.md
├─ merge/                    SKILL.md、references/
└─ release/                  SKILL.md、references/
tests/git-sequences.sh       檢查各 skill 規定的 git 步驟
tests/migrations.sh          檢查範本有變更時是否附了 migration 檔
ss-workflow-skill.md         設計規格
```

驗證 manifest，以及在單一 session 從工作目錄載入 plugin：

```bash
claude plugin validate .
```

```bash
claude --plugin-dir /path/to/ss-workflow
```

這些 skill 依賴 git 的特定行為：branch 如何認領 request、專案的 worktree 如何放在 workspace 的 worktree 裡並移除、關閉的 request 與它的 gitlink 如何進到 `develop`、release 如何設定 workspace `master` 的 gitlink、hotfix 如何 merge，以及舊 repo 如何轉換。這支 script 會在暫存的沙盒裡跑這些指令並檢查結果。它測的是 git，不是 agent。修改 skill 的 git 步驟後請重跑一次：

```bash
bash tests/git-sequences.sh
```

`skills/init/templates/` 底下的檔案最後會出現在別的 repo 裡，plugin 更新碰不到它們。新增設定、改變 request 檔格式、搬動產生的檔案、改 skill 名稱，或改變工作流行為的版本，都需要附 migration 檔。什麼情況需要、格式怎麼寫，見 [skills/init/migrations/README.md](skills/init/migrations/README.md)。範本自上一個 release tag 之後有變更，卻沒有更新版本的 migration 檔時，這支 script 會失敗：

```bash
bash tests/migrations.sh
```

> [!IMPORTANT]
> 發佈變更時，要遞增 `.claude-plugin/plugin.json` 的 `version`，並同步更新兩份 README 開頭的版本 badge 和狀態說明。版本沒有變，已安裝的副本就不會更新。Migration 檔以該版本命名。

各個 skill 背後的設計決定記錄在 [ss-workflow-skill.md](ss-workflow-skill.md)。

## 授權

MIT，詳見 [LICENSE](LICENSE)。
