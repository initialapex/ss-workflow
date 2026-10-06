# ss-workflow

這個專案主要是建立軟體開發的工作流 SKILL (不只一個)，會包含不同階段所需要的 SKILL，其中包含 Project Init, New/Check Request, Merge, Release 等等的動作，後續章節會一一介紹

## 環境設定

- 討論使用繁體中文 (zh-TW)，專有名詞保持英文
- README.md 為英文，但同步產生 README-zh-TW.md
- AGENTS 相關給 AI 看的文件使用英文
- 以上為預設，在初始化問答時，讓 developer 選擇

## 發佈方式 (Claude Code plugin)

整套 skills 包成一個 Claude Code plugin，本 repo 同時是 plugin 本體與 marketplace:

```
ss-workflow/
├─ .claude-plugin/
│   ├── marketplace.json
│   └── plugin.json          (version 為唯一版本來源)
└─ skills/
    ├── ss-workflow-init/
    │   ├── SKILL.md
    │   ├── templates/       (AGENTS.md, CLAUDE.md, README.md, .gitignore ... 範本)
    │   └── references/      (gitflow 規則, commit 格式, request 格式)
    ├── ss-workflow-new-req/SKILL.md
    ├── ss-workflow-check-req/SKILL.md
    ├── ss-workflow-merge/SKILL.md
    └── ss-workflow-release/SKILL.md
```

- 安裝: developer 執行 `/plugin marketplace add <ss-workflow repo>` 後安裝 plugin
- 更新比對來源: marketplace repo 上 `plugin.json` 的 `version`
  - 每次發佈新版都必須遞增 `version`，否則 Claude Code 不會視為更新
  - developer 執行 `/plugin marketplace update` 或開啟 auto-update 取得新版
- 團隊自動帶入: init 時在目標專案的 `.claude/settings.json` 寫入 `extraKnownMarketplaces` 與 `enabledPlugins`，其他成員 clone 並 trust 專案後會被提示安裝
- 專案文件版本: plugin 會自動更新，但專案內由範本產生的文件 (CLAUDE.md, AGENTS.md ...) 不會
  - init 時在 root `AGENTS.md` 記錄 `ss-workflow-version`
  - 重跑 `/ss-workflow-init` 時比對此值與 plugin 版本，較舊則 migrate 範本產生的檔案

## skill: `/ss-workflow-init`

這個 skill 會將目前的目錄初始化，其中包含:
    - 建立工作流所需的檔案結構；若是已有專案的目錄，一樣轉換成工作流的檔案結構
    - 建立 Git Repo；若是目錄已經為 git repo，則往後遵循此 skill 規則
      - 新建 repo 時建立 `master` (或 `main`，問答決定) 與 `develop` 兩個 branch，並完成第一個 commit
    - 若此目錄已經為本工作流目錄，比對 `ss-workflow-version` 與 plugin 版本 (見「發佈方式」)，較舊則一併更新 agent 檔案 (e.g. CLAUDE.md, AGENTS.md)
    - 建立 agent 所需要的檔案 `CLAUDE.md`, `AGENTS.md` 與 Project Spec, `README.md` 等工作流所需文件
    - CLAUDE.md / AGENTS.md 分工:
      - `AGENTS.md` 為內容本體 (AGENTS.md 開放格式，其他 agent 也可讀)
      - `CLAUDE.md` 只放 `@AGENTS.md` import，以及 Claude Code 專屬的設定
      - 撰寫方式依照 Claude Code 的 memory 規範 (簡潔、可執行的規則，子目錄的檔案在讀取該目錄時才載入)
    - README.md Template 可以參考:
      - https://github.com/MaterialDesignInXAML/MaterialDesignInXamlToolkit

### 初始化問答

以問答的方式 step-by-step 讓 developer 決定，至少包含:

- 語言設定 (見「環境設定」)，包含 reqs / docs 使用的語言
- 主分支名稱: `master` 或 `main`
- remote 平台: GitHub (`gh`) / GitLab (`glab`) / 無
- 專案類型 (目前以 Visual Studio 為例)；非 VS 專案時，`tests/`, `samples/` 是否保留
- 現有專案: 說明轉換的方法，由 developer 確認或答覆需調整的部分

### 檔案結構

整理檔案結構如下:

```
repo/
├─ CLAUDE.md
├─ AGENTS.md
├─ README.md
├─ README-zh-TW.md
├─ .gitignore
├─ .claude/
│   └── settings.json        (extraKnownMarketplaces, enabledPlugins)
├─ Directory.Build.props     (集中管理版本號)
├─ VisualStudioSolution.sln
├─ src/ (Source Code 目錄)
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   ├── project1-folder/
│   │   ├── README.md
│   │   └── project1.csproj
│   ...
│   └── projectX-folder/
│       ├── README.md
│       └── projectX.csproj
├─ reqs/ (需求檔)
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   ├── REQ-0014-20261007-export-csv.md
│   ├── REQ-0015-20261008-login-fix.md
│   └── done/
│       └── REQ-0012-20260907-gui-button.md
├─ docs/ (軟體規格、外部參考文件、知識庫)
│   ├── <xxxx>-spec.md
│   ...
├─ external/ (放置 submodule)
├─ tests/ (Test Project 目錄)
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   └── <test-project>-folder/
├─ samples/ (Sample/Demo Project 目錄)
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   └── <demo-project>-folder/
```

#### 根目錄

根目錄 `CLAUDE.md` / `AGENTS.md` 去限制整個 repo 內的工作流運作，並註記每個資料夾內運作的規則 (含 gitflow、commit 規範、`ss-workflow-version`)；在 repo 初始化的時候，會以問答的方式 step-by-step，讓 developer 完成檔案內所需的資訊。若是現有的專案，了解現有專案的架構後，與 developer 問答轉換的方法是否可接受，若需要調整的部分，developer 需要自行答覆

- `bin/` 資料夾也會放在此
- `.gitignore` 使用 Visual Studio 範本 (`bin/`, `obj/`, `.vs/` ...)，並確認包含根目錄的 `bin/`
- 版本號集中在 `Directory.Build.props` 管理，release 時只需修改一處

#### src

放置專案檔案，目前是以 `Visual Studio` 為例，底下會有自己的 `CLAUDE.md` / `AGENTS.md`
每個專案都要有描述自己專案的 `README.md`

#### reqs

整個工作流最主要的核心資料夾。每個 request 只有一個 `.md` 檔，不另外建立資料夾，也沒有 `STATUS.md`。

- 檔名: `REQ-<4 位流水號>-<yyyyMMdd>-<slug>.md`，e.g. `REQ-0012-20260907-gui-button.md`
  - 流水號由 skill 掃描 `reqs/` 與 `reqs/done/`，取最大號 + 1
- 未完成的 request 放在 `reqs/`；完成 (`done`) 後由 `/ss-workflow-merge` 以 `git mv` 移到 `reqs/done/`
- YAML frontmatter 為狀態的唯一來源:

```markdown
---
id: REQ-0012
status: in-progress        # draft | ready | in-progress | review | done
type: feat                 # feat | fix | docs | refactor | hotfix ...
branch: feat/REQ-0012-gui-button
priority: normal           # high | normal | low
created: 2026-09-07
---
# GUI buttonX 修改

## Spec
(與 developer 討論後確認的規格)

## Original
(developer 原始提供的需求內容，原文保留不修改)
```

- 狀態流程:

| status        | 意義                               | 在哪裡改變 / 誰改變                         |
|---------------|------------------------------------|---------------------------------------------|
| `draft`       | 新需求，規格討論中                 | develop，`/ss-workflow-new-req`             |
| `ready`       | developer 確認規格，等待認領       | develop，`/ss-workflow-new-req` (commit)    |
| `in-progress` | 已認領，在 worktree 實作中         | develop，`/ss-workflow-check-req` (commit + push) |
| `review`      | 實作完成，等待 developer review    | request branch (worktree)                   |
| `done`        | 已 merge 回 develop                | `/ss-workflow-merge`，移到 `reqs/done/`     |

- 認領 (lock):
  - 在 develop 上將 status 改為 `in-progress` 並寫入 `branch`，commit 後 push
  - push 被拒 (remote 已有其他 session 的認領) 時，pull 後重新選擇 request
  - 無 remote 時，以 local develop 的 commit 為準
- 同步到 remote:
  - worktree 只是某個 branch 的 checkout，push branch 即同步
  - 建立 worktree + branch 後立即 `git push -u`，實作過程中每次 commit 都 push
- 找回 request (session 遺漏時): 依 frontmatter 的 `branch`，搭配 `git worktree list` 或 remote branch 找回

- Note:
    - 若 developer 使用 `.md` 的方式加入新需求，原始需求的內容必須保留在 `## Original` 區段

#### docs

- 最主要是放置此專案規格
- 放置所有 developer 可閱讀的文件
- 過程中有建立相對應的知識庫，也放置在這邊

#### external

- 放置 submodule
- 放置外部參考的 module，可能為 binary files

#### tests

- 測試 src 的測試專案放置於此
- 目前是以 Visual Studio 為例，若其他類型的專案不需要用到此資料夾，可刪除 (在初始化問答的時候可提問)

#### samples

- 若是專案為 library，會建立 sample / demo 專案，展示如何使用 library，也是一種 GUI 測試

## skill: `/ss-workflow-new-req`

建立新需求使用，使用者可利用此 skill + .md file 建立新需求，也可單獨輸入此 skill，skill 會引導建立 new request

- 在 develop 上建立 `status: draft` 的 request 檔 (若提供 .md，原文放入 `## Original`)
- 與 developer 討論細部的需求規格，寫入 `## Spec`
- developer 確認規格沒有問題後，將 status 改為 `ready` 並 commit (有 remote 時一併 push develop)
  - 討論中斷時可選擇「保留 draft」先 commit，避免遺失；之後用 `/ss-workflow-new-req REQ-xxxx` 接續
  - commit 前再 fetch 一次，若流水號被其他 session 用掉則重新編號
- 輸入包含多個可獨立實作的需求時，提議拆成多個 request；與既有 request 重複時先提醒
- 此 skill 只寫 request，不實作
- 支援 `type: hotfix` 作為 hotfix 的入口 (hotfix branch 規則見 `/ss-workflow-merge`)，request 檔一樣建立在 develop

## skill: `/ss-workflow-check-req`

- 在 develop branch 上執行: 認領 request
  - 先檢查所有未完成 request 的狀態；若發現異常 (e.g. `in-progress` 但 branch 不存在、`review` 但 worktree 遺失)，先排除異常再認領
  - 若有多個 `ready` 的 request，依 `priority` 排序後讓 developer 選擇
  - 認領流程見 reqs 章節 (lock + 建立 worktree + `git push -u`)，之後在 worktree 上實作 (為了多 session 平行實作多個 request)
- 在 request worktree 上執行: 表示要再啟動實作
  - 若檢查這個需求已經完成 (`review`)，提示 developer 是否完成 review？後續要做什麼？(e.g. 執行 `/ss-workflow-merge`)

## skill: `/ss-workflow-merge`

本工作流 git 遵循 gitflow 流程，有不同形態的 branch (worktree)
若發現有 remote 端: e.g. github, gitlab，讓使用者選擇是否要發 merge-request 到 remote，由 remote 端 merge；對應到此，在 merge 之前都要先去 fetch remote，並用 `gh pr view` / `glab mr view` 檢查，因為有可能是已經發過 merge-request，也合併完了
合併完成後，刪除 local / remote branch 與 worktree

- request
  - 所有 reqs 都在 develop 開分支出去，完成後 merge 回 develop
  - request branch(worktree)種類可能會有: feat, fix, docs ... 等類型
  - branch(worktree) name 範例: `feat/REQ-0012-gui-button`
  - request 實作都開在 worktree 實作
  - merge 後將 request status 改為 `done`，並 `git mv` 到 `reqs/done/`

- release
  - 會從 develop 開分支出去，完成後 merge 回 master 與 develop
  - branch name 範例: release/v1.0.0-beta1
  - 不開 worktree
  - 合併回 master 後，依照 branch name 建立 tag: e.g. v1.0.0-beta1
  - release 流程使用 `/ss-workflow-release`

- hotfix
  - 會從 master 開分支出去，完成後 merge 回 master 與 develop
  - branch name 範例: hotfix/v1.0.1
  - 合併回 master 後，依照 branch name 建立 tag: e.g. v1.0.1

- master (持續存在)
  - 主要是在有新版要釋出時，才會有新的 commit
  - 例外: v1.0.0 釋出之前為快速疊代期，允許 develop 直接 merge 到 master，並建立 `v0.x.y` tag

- develop (持續存在)
  - 主要是開發 branch，所有變動大部分都會在這邊

## skill: `/ss-workflow-release`

- 若 developer 在 develop branch 使用此 skill，則表示想釋出新版本
  - 檢查適合的版本號推薦給使用者 (依上一個 tag 與 develop 上的 commit type)，使用者同意後，從 develop 建立 release branch
  - release branch 建立後，檢查是否有未完成需求 (`reqs/` 下非 `done` 的 request)、未完成 worktree；若有未完成，讓 developer 決定是否 release?
    - 若不同意，先處理完需求， developer 要在 release branch 再下一次此 skill
  - 若同意 release ，則去檢查 `Directory.Build.props` (以及 `src/` `samples/` 內未繼承的專案) 的版本號是否與 release branch 相符
    - 若不相符作相對應的修改並 commit
  - 若相符則直接啟用 release merge 規則 (見 `/ss-workflow-merge`)

## Git commit

此章節的規範會寫入專案 root `AGENTS.md`，所有 commit 都需遵守，不只在執行 skill 時

### commit 原則

- 在實作的過程中，可以一直 commit，讓每一次變動可以看得出為什麼而變動，而不是一大堆的檔案一起包在同一個 commit 上
- request branch 上的 commit 每次都 push 到 remote (見 reqs 章節)

### git commit format

- 範例是中文的，但是我要全英文 commit

範例: 
```
- Header: <type>(<scope>): <subject>
 - type: 代表 commit 的類別：feat, fix, docs, style, refactor, perf, test, build, ci, chore，必要欄位。
 - scope 代表 commit 影響的範圍，例如資料庫、控制層、模板層等等，視專案不同而不同，為可選欄位。
 - subject 代表此 commit 的簡短描述，不要超過 50 個字元，結尾不要加句號，為必要欄位。

Body: 72-character wrapped. This should answer:
 * Body 部份是對本次 Commit 的詳細描述，可以分成多行，每一行不要超過 72 個字元。
 * 說明程式碼變動的項目與原因，還有與先前行為的對比。

Footer: 
 - 填寫 request 編號（如果有的話），e.g. Refs: REQ-0012
 - BREAKING CHANGE（可忽略），記錄不兼容的變動，
   以 BREAKING CHANGE: 開頭，後面是對變動的描述、以及變動原因和遷移方法。
```
 
- Reference: 
  - https://wadehuanglearning.blogspot.com/2019/05/commit-commit-commit-why-what-commit.html
  - https://ithelp.ithome.com.tw/articles/10228738
