# ss-workflow

這個專案主要是建立軟體開發的工作流 SKILL (不只一個)，會包含不同階段所需要的 SKILL，其中包含 Project Init, New/Check Request, Merge, Release 等等的動作，後續章節會一一介紹

## 環境設定

- 討論使用繁體中文 (zh-TW)，專有名詞保持英文
- README.md 為英文，但同步產生 README-zh-TW.md
- AGENTS 相關給 AI 看的文件使用英文
- 以上為預設，在初始化問答時，讓 developer 選擇

## Workspace 架構

工作流不改變原本專案的檔案架構，而是在外面再包一層 (0.6.0 起，唯一支援的架構):

- **Workspace repo** (e.g. `SSDisp-workspace`): 放 `reqs/`、`docs/`、agent 檔與 Workflow settings；需求討論、request 狀態、review 結果的 commit 都在這裡
- **Source repo** (e.g. `SSDisp`): 原本的專案，以 git submodule 加入 workspace 的 `projects/<專案名稱>`；檔案架構依它自己的 toolchain (Visual Studio / Keil / 自訂)，history 只有實作的 commit
- 一個 workspace 可以有多個專案 (e.g. `projects/SSLib`、`projects/SSDisp`)，各自有版本號與 tag，沒有修改的專案不需要進版

```
SSDisp-workspace/
├─ CLAUDE.md / AGENTS.md / README.md / README-zh-TW.md / .gitignore / .gitmodules
├─ .claude/settings.json      (extraKnownMarketplaces, enabledPlugins)
├─ reqs/                      (需求檔，見 reqs 章節)
├─ docs/                      (overview.md 與各專案的 <專案名稱>/spec.md，見 docs 章節)
└─ projects/
    ├── CLAUDE.md / AGENTS.md (各專案的 Toolchain 與 Project rules)
    ├── SSLib/                (submodule → SSLib repo)
    └── SSDisp/               (submodule → SSDisp repo，內容依它自己的結構)
        ├── SSDisp.sln
        ├── SSDisp/
        ├── SSDisp.Test/
        └── SSDisp.Sample/
```

- 沒有 `tests/`、`samples/`、`external/`: test / sample 專案與第三方檔案都依各專案原本的結構放在 source repo 內
- init 不寫入 source repo 任何檔案；各專案的規則記錄在 workspace 的 `projects/AGENTS.md`，每個專案一個 `## Project: <name>` 章節 (Toolchain + Project rules，由 developer 維護)
- source repo 原本就有的 `AGENTS.md` / `CLAUDE.md` / `.gitignore` 保持不動；`.gitignore` 缺少 build output 的項目時只回報，建議另開 request 在 source repo 修正 (否則 workspace 會看到 submodule 有 untracked 內容)

### 兩層的 branch

兩層都走 gitflow，名稱可依專案設定 (既有專案可能用 `main`)；source repo 缺 develop 時，init 詢問後建立

| 項目 | Workspace | Source repo |
|------|-----------|-------------|
| 長期 branch | `master` (= 各專案最新 release 的組合)、`develop` (gitlink 跟著各 source repo 的 develop) | `main-branch`、`develop-branch` |
| request | `feat/REQ-0012-<slug>`，從 develop 開；**建立 draft 時就建立，一路用到 merge** | `feat/<slug>` (以變更內容命名，不含 request 編號，記錄在 request 的 `project-branch`)，從 source 的 `<develop-ref>` (最新的 develop，不是 gitlink) 開 |
| hotfix | `hotfix/<P>-v1.0.1`，從 workspace master 開 | `hotfix/v1.0.1`，從 source main 開 |
| release | 沒有 branch；develop merge 到 master，打 `<P>/v1.2.0` tag | `release/v1.2.0`，merge 到 main 與 develop，打 `v1.2.0` tag |

- 一個 request 可以同時修改多個專案 (`projects: [SSLib, SSDisp]`)，每個專案建立同一個 project branch；hotfix request 只能有一個專案 (版本號屬於一個專案)
- source repo 的歷史不出現任何 workspace 的資訊: branch 名稱、commit、merge commit、tag、merge request、changelog 都不帶 request 編號、workspace 名稱或指向 workspace 的 `Refs:`，以描述需求/修改內容為主，跟一般專案的 branch 與 commit 一樣
  - 原因: 多人開發時，每個人都在本機建立自己的 workspace，REQ 編號只在一個 workspace 內有意義
  - 關聯只由 workspace 單向記錄: request 檔的 `project-branch`，以及 workspace 的 gitlink
- project branch 的名稱 `<type>/<slug>` 在 request 的每個專案 (local 與 remote) 都必須是新的；已被使用 (可能是別人從自己的 workspace 建立的) 時，提出另一個簡短、描述性的名稱 (e.g. `feat/gui-button-color`) 由 developer 確認
- skill 只透過 request 的 `project-branch` 找 project branch，不以名稱規則比對；專案內其他 branch 可能是別人的工作，不回報、不修改、不刪除
- 0.8.0 以前開始的 request 沒有 `project-branch`，其 project branch 與 workspace branch 同名
- 開始實作時才建立各專案的 branch；draft 與 `ready` 的 request 在 source repo 沒有任何 branch

### gitlink

- workspace request branch 上記錄結果的 commit (交付 review、review 結果、close) 一併 stage 該 request 各專案的 gitlink；workspace 因此記錄「review 的是哪個 source commit」
- workspace develop 的 gitlink 指向各 source repo 的 develop；master 的 gitlink 指向各 source repo 的 main (= 最新 release)
- source repo 的 develop 被 workspace 以外的人更新 (別的團隊直接 commit) 時，gitlink 會落後: check-req 總覽與 merge 時以 `git -C projects/<P> rev-list --count <gitlink>..<source develop-ref>` 偵測，提議一個 `chore(workspace): update <P> to <sha>` 的 commit，由 developer 決定

### worktree 的結構

`git worktree remove` 拒絕移除含 submodule 的 worktree；worktree 自己 clone 的 submodule 在移除時會遺失未 push 的 commit。所以實作用的 worktree 是兩層:

- workspace worktree: `.claude/worktrees/<branch>` (request 檔與 gitlink)
- 每個 request 的專案: `git -C <root>/src/<P> worktree add --no-track -b <branch> <wt>/src/<P> <source develop-ref>`，commit 存在 root checkout 共用的 `.git/modules/src/<P>`，worktree 移除後仍在
- request 以外的專案: `--detach` 在 gitlink 的 commit (build 可能參照相鄰的專案)；專案內的巢狀 submodule 用 `submodule update --init --recursive`
- 移除: 先移除內層的各專案 worktree，`git -C <wt> restore projects/<P>` 補回空資料夾 (否則 workspace 視為刪除了 gitlink)，最後移除 workspace worktree；不使用 `--force`

### 乾淨的判定

`git status --porcelain` (v1) 對 submodule 不論是新 commit、修改或 untracked 都只顯示 ` M projects/<P>`；「乾淨」= workspace 的 `git status --porcelain` 為空，細節用 `git -C projects/<P> status --porcelain` 判斷

## 專案形式

工作流本身不相依任何一種專案形式，Visual Studio / Keil / ESP32 或其他類型都適用。

- 專案類型由 developer 在初始化時說明 (自由描述，e.g.「Visual Studio solution，old-style C# 專案，用 MSBuild 建置」、「Keil MDK-ARM」、「ESP-IDF」)；每個專案各自說明
- 所有跟專案形式有關的內容，都是初始化問答的答案，記錄在 workspace，plugin 不內建任何 toolchain 的範本或指令
  - root `AGENTS.md` 的 Workflow settings: workspace 層的設定，加上 `projects:` 清單，每個專案一筆:
    - `name`、`path` (`projects/<name>`)、`main-branch`、`develop-branch`、`project-type`、`project-kind`
    - `project-file`、`version-source` (路徑以專案資料夾為基準，`version-source` 可為 `none`)
    - `setup-command`、`build-command`、`test-command`、`verify-command` (在專案資料夾內執行)
    - 選填的 `remote-platform`、`merge-method`、`push-policy`: 覆寫 workspace 的預設值 (e.g. source repo 在 GitHub 要求發 PR，workspace 只在本機)
  - `projects/AGENTS.md` 的 `## Project: <name>` 章節: 需要安裝的工具、不在 `PATH` 上的工具如何找到、已知限制、新檔案 / 專案如何加入 build、哪些是產生的檔案不可手改、build 輸出位置、命名慣例
- AI 依偵測到的內容與對該 toolchain 的了解提出建議值，由 developer 確認或修正；不確定時直接詢問，不猜指令
- 指令可以留空 (e.g. 只能在 IDE 內 build 的專案): 該步驟會被略過並回報「未設定」，skill 不會自行編造指令
- init 不建立專案檔、build 檔或版本檔，這些由 developer 或第一個 request 產生

## 發佈方式 (Claude Code plugin)

整套 skills 包成一個 Claude Code plugin，本 repo 同時是 plugin 本體與 marketplace:

```
ss-workflow/
├─ .claude-plugin/
│   ├── marketplace.json
│   └── plugin.json          (version 為唯一版本來源)
└─ skills/
    ├── init/
    │   ├── SKILL.md
    │   ├── templates/       (AGENTS.md, CLAUDE.md, README.md, .gitignore ... 範本)
    │   ├── references/      (問答、layout、加入專案、轉換舊版、升級)
    │   └── migrations/      (<version>.md，逐版的升級步驟)
    ├── new-req/SKILL.md
    ├── check-req/SKILL.md
    ├── review/SKILL.md
    ├── merge/SKILL.md
    └── release/SKILL.md
```

- 安裝: developer 執行 `/plugin marketplace add <ss-workflow repo>` 後安裝 plugin
- 更新比對來源: marketplace repo 上 `plugin.json` 的 `version`
  - 每次發佈新版都必須遞增 `version`，否則 Claude Code 不會視為更新
  - developer 執行 `/plugin marketplace update` 或開啟 auto-update 取得新版
- 團隊自動帶入: init 時在 workspace 的 `.claude/settings.json` 寫入 `extraKnownMarketplaces` 與 `enabledPlugins`，其他成員 clone 並 trust 專案後會被提示安裝
- 專案文件版本: plugin 會自動更新，但專案內由範本產生的文件 (CLAUDE.md, AGENTS.md ...) 不會
  - init 時在 root `AGENTS.md` 記錄 `ss-workflow-version`
  - 重跑 `/ss-workflow:init` 時比對此值與 plugin 版本，較舊則 migrate 範本產生的檔案
- Migrations: 重新 render managed 區段只能帶入新的規則文字，帶不動的變更由 `skills/init/migrations/<version>.md` 處理
  - 需要 migration 檔的版本: 新增 / 改名 / 移除 Workflow settings 的欄位或可用的值、改變 request 檔格式、新增 / 搬動 / 移除產生的檔案或需要修改 managed 區段以外的文字、skill 改名、工作流行為有 developer 必須事先知道的改變
  - 只改 managed 區段內規則文字的版本不需要
  - 檔案內容: 「What changes」(行為差異，改之前 / 改之後，升級時先講給 developer 聽)、「Steps」(改哪個檔、改什麼、維持舊行為的值、是否需要 developer 回答、如何判斷已經做過)、「Check」
  - 升級順序: 從 repo 記錄的版本到 plugin 版本，依版本由低到高逐一套用 migration → 重新 render managed 區段 → 寫入新的 `ss-workflow-version` → 給 developer 看 diff 後才 commit
  - 預設值一律選「維持舊版行為」的那個；行為要不要改由 developer 決定
  - 不改寫 `## Original`，不改已回答的 `## Q&A`；request 檔在各自的 branch 上，migration 不 checkout request branch，格式變更由下一次寫入該檔的 skill 補上
  - 例外: 0.6.0 的 migration 是架構轉換 (見「轉換 0.5.0 以下的 repo」)，舊架構無法「維持舊版行為」，developer 拒絕時升級停止
  - `tests/migrations.sh`: 範本自上一個 release tag 後有變更，卻沒有更新版本的 migration 檔時失敗

## skill: `/ss-workflow:init`

參數: `[--upgrade] [--add <url|path>]... [<url|path> ...]`

| 模式 | 條件 | 做什麼 |
|------|------|--------|
| New workspace | 空目錄 (或只有暫存檔) | 建立 workspace repo；帶入的 URL / 路徑加入為專案；沒有帶入時 workspace 先是空的 |
| Add project | 已是 workspace，帶 `--add` | 加入一個或多個專案 (第二、第三個專案也一樣) |
| 在既有專案內執行 | 目錄是有程式碼、但不是 workspace 的 git repo | 提議在旁邊建立 `../<Name>-workspace`，把這個 repo 加入為專案；原 repo 不動 |
| Upgrade | root `AGENTS.md` 有 `ss-workflow-version:` | 依「發佈方式」升級；版本低於 0.6.0 時為「轉換 0.5.0 以下的 repo」 |

- 建立 workspace repo 時建立 `master` (或 `main`，問答決定) 與 `develop`，並完成第一個 commit
- 全新的專案 (還沒有任何 source code): developer 先建好一個空的 repo (remote 或 local)，再用 URL 或路徑加入
- 建立 agent 所需要的檔案 `CLAUDE.md`, `AGENTS.md`、`docs/overview.md` 與各專案的 `docs/<name>/spec.md`、`README.md` 等工作流所需文件
- CLAUDE.md / AGENTS.md 分工:
  - `AGENTS.md` 為內容本體 (AGENTS.md 開放格式，其他 agent 也可讀)
  - `CLAUDE.md` 只放 `@AGENTS.md` import，以及 Claude Code 專屬的設定
  - 撰寫方式依照 Claude Code 的 memory 規範 (簡潔、可執行的規則，子目錄的檔案在讀取該目錄時才載入)
- README.md Template 可以參考:
  - https://github.com/MaterialDesignInXAML/MaterialDesignInXamlToolkit
  - 版面: 置中的標題、描述與 badge → 語言連結 → 功能清單 → 可收合的目錄 → 各章節
  - workspace 的 README 列出各專案 (名稱、路徑、repo、spec 連結、說明)；版本屬於各專案，所以 workspace README 不放版本 badge
  - 程式碼區塊都標上語言 (指令依執行的 shell 選 `bash` / `powershell` / `bat`)；補充說明用 GitHub alert (`> [!NOTE]` 等)
  - 目錄要和章節一致，移除或新增章節時一併調整

### 加入專案

- remote URL: `git submodule add <url> projects/<name>`
- local 路徑:
  - local repo 有 origin: 從 local clone (省時間)，`.gitmodules` 記錄 origin URL (隊友 clone 得到)；原本的 local working copy 不動
  - 沒有 origin: 先說明這個路徑無法分享，再記錄 local 路徑；git 預設拒絕 local 路徑的 submodule，需要 `-c protocol.file.allow=always`。submodule 的 origin 會是 developer 的 working copy (non-bare)，push 到它 checkout 中的 branch 會被拒絕，所以該專案的 `push-policy` 預設為 `never`；建議改用 bare repo 作為共用的 remote，之後以 `git submodule set-url` 更新
- 新加入專案的 gitlink: workspace master 指向 source main，develop 指向 source develop
- source repo 缺 develop (或 main 的名稱不同) 時詢問: 建立 develop / 指定既有的 branch 名稱
- 每個專案各自走一次 toolchain 問答 (見下方)，結果寫入 `projects:` 與 `projects/AGENTS.md` 的 `## Project: <name>`
- 建立該專案的 `docs/<name>/spec.md` (workspace 已有該專案的 spec 時保留，不另外建立)，並在 `docs/overview.md` 的 Projects 加一行

### 初始化問答

以問答的方式 step-by-step 讓 developer 決定，至少包含:

- 語言設定 (見「環境設定」)，包含 reqs / docs 使用的語言
- workspace 的主分支名稱: `master` 或 `main`
- remote 平台: GitHub (`gh`) / GitLab (`glab`) / 無 (workspace 的預設值，各專案可覆寫)
- 每個專案: 專案類型與 toolchain (見「專案形式」)、main / develop branch 名稱、主要專案檔、setup / build / test 指令、版本號來源、工具注意事項、專案規則，以及需要時覆寫的 remote 設定
- merge 方式 (`merge-method`): 每次詢問 / local merge / 發 merge-request
- push 方式 (`push-policy`): `auto` (預設) / `ask` / `never`，見「Remote 與 push」

問答結果記錄在 root `AGENTS.md` 的 Workflow settings，另有選填的欄位，init 不詢問，由 developer 需要時自行填入:

- 各專案的 `verify-command`: `/ss-workflow:review` 在 build 與測試之後額外執行的驗證 script
- `agent-files`: 內建清單以外、會影響 agent 行為的檔案路徑 (glob，逗號分隔，可指向 `projects/<P>/...`)，e.g. 產品內附的 prompt 檔，見「如實回報與 agent 行為檔」
- `legacy-project`: 由「轉換 0.5.0 以下的 repo」寫入的專案名稱，沒有 `projects` 欄位的舊 request 屬於它；不是轉換來的 workspace 留空

### 轉換 0.5.0 以下的 repo

0.5.0 以下的架構是單一 repo (程式碼在 `src/`、`tests/`、`samples/`，request 在同一個 repo)。升級到 0.6.0 必須轉換，developer 拒絕時升級停止:

- 舊 repo 變成 source repo: 保留 remote、全部歷史與既有的版本 tag，不改寫歷史
- 前提 (不符合時停止並列出清單，請 developer 先完成或放棄): 沒有 `in-progress` / `review` / merge pending 的 request、沒有 `release/*` / `hotfix/*` branch、沒有 worktree；draft (`req/` branch) 與 `ready` 的 request 會帶到 workspace
- source repo 回到 toolchain 原本的結構 (e.g. Visual Studio 的 `SSDisp.sln`、`SSDisp/`、`SSDisp.Test/`、`SSDisp.Sample/` 在同一層)
  - AI 依 toolchain 提出搬移表，developer 確認後以 `git mv` 搬移，修正專案檔 / solution 內的相對路徑並確認 build
  - `tests/`、`samples/` 內的每個專案逐一詢問: 合併進 source (搬到 toolchain 的位置) 或刪除 (歷史中仍找得回)
  - `external/` 預設原地保留 (build 會參照它)，搬移表中可以改
- 從 source repo 移除工作流的檔案 (`reqs/`、ss-workflow 產生的 `AGENTS.md` / `CLAUDE.md`、plugin 註冊的 `.claude/settings.json`、`.gitignore` 的 ss-workflow 區段)；developer 寫在這些檔案 managed 區段以外的內容搬到 workspace
- 舊的 `docs/`: 逐一檔案詢問，預設搬到 workspace 的 `docs/<name>/` (舊的 `docs/<slug>-spec.md` 變成 `docs/<name>/spec.md`)；developer 可以指定哪些是產品文件 (e.g. 使用者手冊、API 文件)，留在 source repo
- README 是產品文件，留在 source repo (只修正指向已移除檔案的連結)；workspace 由範本產生新的 README
- 建立 workspace (預設 `../<Name>-workspace`，可帶 remote URL)，以舊 repo 的 URL 加入為專案
  - 匯入 request: `reqs/` 與 `reqs/done/` 的檔案原樣複製；`ready` 的 request 補上 `projects: [<name>]`，`reqs/done/` 的檔案不修改；Workflow settings 的 `legacy-project` 記錄該專案名稱，沒有 `projects` 欄位的 request 屬於它
  - draft: 在 workspace 重建為 `<type>/REQ-<id>-<slug>` branch；確認複製完成且 developer 同意後，才刪除舊 repo 的 `req/` branch
  - workspace master 的 gitlink 指向 source main，並在上面打 `<name>/v<最新版本>` tag，作為之後 release 比對的起點
- source repo 的 main 在下一次 release 前仍保有舊的檔案，這是預期的

## reqs (需求檔)

整個工作流最主要的核心資料夾，位於 workspace。每個 request 只有一個 `.md` 檔，不另外建立資料夾，也沒有 `STATUS.md`。

- 各階段在哪裡進行 (根目錄 = workspace 的主要 checkout，平常停在 develop):

| 階段 | 位置 | skill |
|------|------|-------|
| 規格討論 | 根目錄，workspace request branch | `/ss-workflow:new-req` |
| 實作 | worktree (workspace + 各專案)，request branch | `/ss-workflow:check-req` |
| Verify (跑 build / Test 專案 / script) 與 Review (人工驗證) | 根目錄，checkout 兩層的 request branch | `/ss-workflow:review` |
| 結案 (merge) | 根目錄 | `/ss-workflow:merge` |

  - 在 worktree 上跑 script 或執行檔的限制較多，所以 worktree 只寫程式並嘗試編譯，不跑測試、script、執行檔
  - AI 完成實作後直接刪除 worktree，但保留 branch；request 停在 `review` 狀態，由 developer 觸發 `/ss-workflow:review` 才開始 Verify 與 Review
  - developer 執行 `/ss-workflow:merge` 就算結案
  - 根目錄一次只能做一件事 (規格討論 / review / merge / release)；skill 切換根目錄的 branch 前，先確認它在 develop 且沒有未 commit 的變更 (含各專案)，完成後切回 develop 並 `git submodule update`

- 檔名: `REQ-<4 位流水號>-<yyyyMMdd>-<slug>.md`，e.g. `REQ-0012-20260907-gui-button.md`
  - 流水號取「使用中的最大號 + 1」；使用中 = workspace develop 上 `reqs/` 與 `reqs/done/` 的檔案，以及 workspace local / remote 上名稱含該編號的 branch (`feat/REQ-0012-…`，以及 0.8.0 以前的 `req/REQ-0012-…`)
- 未完成的 request 放在 `reqs/`；完成 (`done`) 後由 `/ss-workflow:merge` 以 `git mv` 移到 `reqs/done/`
- YAML frontmatter 為狀態的唯一來源:

```markdown
---
id: REQ-0012
title: GUI buttonX 修改
status: in-progress        # draft | ready | in-progress | review | done
type: feat                 # feat | fix | docs | refactor | hotfix ...
projects: [SSDisp]         # 修改的專案，對應 Workflow settings 的 projects
branch: feat/REQ-0012-gui-button
project-branch: feat/gui-button   # 各專案的 branch，不含 request 編號
priority: normal           # high | normal | low
created: 2026-09-07
---
# GUI buttonX 修改

## Spec
(與 developer 討論後確認的規格)

## Original
(developer 原始提供的需求內容，原文保留不修改)

## Q&A
(問過 developer 的問題與回答，依發問順序記錄，只增不改)

## Notes
(Assumption、implementation summary、行為變更、Verify / code review / Review 結果，都帶日期)
```

- `branch` 同時是 workspace 與各專案的 branch 名稱 (hotfix 例外: workspace 為 `hotfix/<P>-v<version>`，專案為 `hotfix/v<version>`)
- `projects: []`: 只修改 workspace 檔案的 request (見「request 修改 workspace 檔案」)；hotfix 一定剛好一個專案

- `## Q&A`: 對話即記錄，事後任何人都能回答「當時為什麼這樣決定」

```markdown
### Q3 (2026-09-08, spec)

Q: 按鈕也要出現在 toolbar 嗎？選項: toolbar 與選單 / 只有選單
A: 只有選單，toolbar 已經放滿了
Decision: Scope 只列選單項目，toolbar 移到 Out of scope
```

  - 要記錄的問題: 答案會改變 request 交付的內容，或改變結果如何判定 (範圍、行為、架構、acceptance criteria、失敗或沒跑的檢查是否接受)；流程性的問題 (選哪個 request、現在做還是之後做) 不記
  - 依發問順序編號；標題帶發問日期與階段 (`spec` / `implementation` / `review`)
  - `Q:` 是當時問的原話 (含提供的選項)，`A:` 是 developer 的原話，`Decision:` 是因此對 request 的決定
  - 未決的問題寫 `A: (pending)`，沒有 `Decision:`；有答案時補上
  - 只增不改: 已回答的紀錄不修改、不刪除；決定改變時新增一筆並註明取代哪一筆
  - AI 提出、developer 接受的預設值一樣記成一筆，另外在 `## Notes` 記為 Assumption，留待 Review 再確認
  - 沒有 pending 的紀錄，request 才能被核准 (取代 Spec 內的 Open questions)

- 狀態流程:

| status        | 意義                                         | 該狀態的檔案在哪個 branch            | 誰設定 |
|---------------|----------------------------------------------|--------------------------------------|--------|
| `draft`       | 規格討論中                                   | workspace request branch (根目錄)    | `/ss-workflow:new-req` |
| `ready`       | developer 確認規格，選擇之後再做             | workspace request branch             | `/ss-workflow:new-req` |
| `in-progress` | 已開始，在 worktree 實作中                   | workspace request branch             | `/ss-workflow:check-req` |
| `review`      | 實作完成、worktree 已刪除、branch 保留；等待或正在 Verify 與 Review | workspace request branch | `/ss-workflow:check-req` 設定，`/ss-workflow:review` 處理 |
| `done`        | 已關閉，檔案在 `reqs/done/`                  | workspace request branch 的最後一個 commit (merge 前) | `/ss-workflow:merge` |

- 一個 request 從 draft 到 merge 都在同一個 workspace branch `<type>/REQ-<id>-<slug>` 上 (從 develop 開)；develop 在 merge 時才拿到 request 檔 (已在 `reqs/done/`)；branch 上的檔案就是目前的狀態
- 討論過程只在建立 draft (占住流水號)、暫停 (Keep as draft) 與核准時 commit，每一輪討論只改工作目錄的檔案
- 核准時選擇「立即開始」(由 `/ss-workflow:check-req REQ-xxxx` 直接開始，不經過總覽與挑選) 或「之後再做」(`ready` 留在 branch 上)
- 討論中 type 改變時，核准前把 branch 改名 (`git branch -m`，push 新名稱並刪除 remote 的舊名稱)
- 開始實作 (不再需要搶 lock):
  - 多人開發時每個人都有自己的 workspace，不需要跨機器搶認領；branch 從 draft 就存在，開始實作只是一個把 status 改為 `in-progress` 並寫入 `branch` 與 `project-branch` 的 commit (`chore(reqs): start REQ-0012`)
  - 根目錄不能在該 branch 上 (git 不允許兩個 worktree 用同一個 branch)；new-req 交給 check-req 前會先把根目錄切回 develop
  - 共用同一個 workspace remote 時，push 出去的 `in-progress` 讓其他機器知道已經開始；push 被拒絕時不強推，交給 developer 決定
  - 開始前先確認 project branch 名稱在 request 的每個專案都還沒被使用
  - 之後在各專案建立 project branch 並 push；名稱在這之間被別人用掉時，改名並以 commit 更新 `project-branch`
- 0.8.0 以前的位置仍然支援: `req/REQ-…` branch 上的 draft (new-req 接續時改名為 `<type>/REQ-…`)，以及 develop 上 `reqs/` 內的 `ready` request (開始時從 develop 建立 branch)
- 同步到 remote (依「Remote 與 push」，允許 push 時才做，各專案依自己的設定):
  - 建立 branch 後立即 `git push -u`，實作過程中每次 commit 都 push
  - 刪除 worktree 前確認兩層都沒有未 commit 的變更；允許 push 時另外確認沒有未 push 的 commit，不 push 時確認 commit 都在本機 branch 上，並在回報中列出尚未 push 的 commit
- 找回 request (session 遺漏時): 依 branch 名稱中的 `REQ-<id>`，搭配 `git worktree list` (workspace 與各專案) 或 remote branch 找回
- Review 發現問題時:
  - 小修 (不影響設計與規格的局部修正): 直接在根目錄的 request branch 上修 (程式碼 commit 在 source repo，再更新 workspace 的 gitlink)，重跑 Verify
  - 大改: 狀態退回 `in-progress`，由實作 session 重新開 worktree 處理

- Note:
    - 若 developer 使用 `.md` 的方式加入新需求，原始需求的內容必須保留在 `## Original` 區段

### request 修改 workspace 檔案

程式碼只 commit 在各專案；但 request 也可能需要改 workspace 本身的檔案 (更新 spec、知識庫、專案規則)，否則「所有工作都從 request 開始」與「workspace branch 只有 request 檔與 gitlink」互相矛盾。

- workspace request branch 可以帶的內容: request 檔、gitlink，以及 workspace 檔案的修改: `docs/`、README、`.gitignore`、agent 檔中 managed 區段以外的文字 (e.g. Project notes、`## Project: <name>` 章節、Workflow settings 的值)
- 不在 request 範圍內: managed 區段與 `ss-workflow-version` (由 upgrade 改)、`.gitmodules` 與 `projects` 清單 (由 `/ss-workflow:init --add` 改)
- 在 workspace worktree commit，與 request 檔的 commit 分開，帶 `Refs: REQ-xxxx` (e.g. `docs(SSLib): describe the new frame API`)
- 不 build、不跑 code review；review 列出 workspace 的 diff 由 developer 逐項確認，動到 agent 行為檔時照「如實回報與 agent 行為檔」寫 Behavior changes
- `projects: []` 的 request: 只有 workspace branch，沒有專案 branch；Verify 沒有可跑的指令 (明講 Verify 沒有自動檢查任何東西)，全部由 Review 確認；merge 只做 workspace；不算進任何專案的 release
- workspace merge 會多出 docs 的文字衝突 (兩個 request 改同一份 spec)：和程式碼衝突一樣，顯示兩邊後詢問 developer

## docs

- `docs/overview.md`: workspace 整體 — 各專案的職責、彼此的相依與介面、跨專案的需求、共用詞彙
- `docs/<name>/`: 單一專案的文件，規格在 `docs/<name>/spec.md`；資料夾名稱就是專案的 `name` (與 `projects/<name>` 相同，不轉 kebab-case)
  - 該專案的設計筆記、參考文件、知識庫也放在這個資料夾
  - 加入專案時建立 `spec.md`；沒有專案的 workspace 只有 overview
- 跨專案或 workspace 整體的文件直接放在 `docs/`
- 讀取: new-req / check-req 只讀 overview 與 request 涉及的專案的 `docs/<name>/`，不讀全部專案的 spec
- 更新: request 改變專案的行為或對外介面時，在同一個 request 的 workspace branch 更新 `docs/<name>/spec.md`；專案之間的關係改變時更新 overview (見「request 修改 workspace 檔案」)
- 產品本身的文件 (e.g. 使用者手冊) 可以留在 source repo

## skill: `/ss-workflow:new-req`

建立新需求使用，使用者可利用此 skill + .md file 建立新需求，也可單獨輸入此 skill，skill 會引導建立 new request

- 在根目錄執行 (不在 worktree)；根目錄必須在 develop 且乾淨，或已在某個 draft 的 request branch 上 (接續該 draft)
- 從 develop 開 `<type>/REQ-<id>-<slug>` branch，在上面建立 `status: draft` 的 request 檔 (若提供 .md，原文放入 `## Original`)，commit 後立即 push (同時占住流水號)
- 讀程式碼前先 fetch 各專案，讀 source 的最新 develop (gitlink 可能落後)；docs 只讀 `docs/overview.md` 與相關專案的 `docs/<name>/`
- 與 developer 討論細部的需求規格，寫入 `## Spec`；每一輪討論不 commit，只在暫停與核准時 commit
  - Spec 內含 Goal / Scope / Architecture / Acceptance criteria / How to verify (每項標明由 Verify 自動檢查或 Review 人工檢查) / Out of scope
  - `projects` 在 Spec 討論時決定；修改多個專案時，Scope 與 Architecture 依專案分別寫，並寫明專案之間的相依 (e.g. SSDisp 需要 SSLib 的新 API)
  - workspace 檔案的修改 (含要跟著更新的 `docs/<name>/spec.md`) 在 Scope 的「Workspace」小節列出；只改 workspace 檔案時 `projects: []`，How to verify 全部標為 Review
  - 每一輪問過的問題與回答寫入 `## Q&A`；還沒有答案的寫 `A: (pending)`，不另外放 Open questions；有 pending 時不能 Approve
  - 開工前要講定的範圍: developer 或使用者看得到、用得到的東西 (UI、指令、檔案格式、對外 API，寫在 Scope)，以及軟體架構 (寫在 Architecture: 新增或修改的模組 / 元件、各自的責任、呼叫關係、資料流、重要的資料結構與狀態、新的相依)；更細的實作細節留給實作，除非 developer 想談
  - Architecture 不可省略: 不需要架構決定的變更也要用一句話寫明，並指出放在既有結構的哪裡；由 AI 依現有程式碼提出，有多種合理結構時列出取捨並推薦，由 developer 確認
  - `## Original` 只有需求或困擾、沒有做法時先探索: 先問問題本身 (誰需要、現在怎麼做、哪裡不好、有什麼限制)，再提出兩到三個做法 (對使用者如何運作、架構概要、影響範圍、代價與風險) 並推薦一個，developer 選定後才起草 Spec
  - developer 答不出來時: AI 提出預設值與理由，developer 接受後寫入 Spec、補完該筆 `## Q&A`，並在 `## Notes` 記為 Assumption，留待 Review 再確認；不自行默默決定
  - 只有別人能回答、或 developer 想晚點再答的問題，以 `A: (pending)` 留在 `## Q&A`，request 維持 draft
  - 接續舊版的 draft 時: 補上 `## Q&A` 區段，把 Spec 內的 Open questions 逐項轉成 pending 的紀錄；`## Notes` 內既有的決策不回頭改寫成 Q&A；沒有 `projects` 時補上
- 核准 (沒有 pending 的 Q&A 時才提供): 選項為「核准並立即開始」(推薦) / 「核准，之後再做」/ 「保留 draft」/ 「捨棄」；想繼續討論時以 Other 說明
  - 核准: type 改變時先把 branch 改名，再把 status 改為 `ready`，commit `docs(reqs): approve REQ-0012` 並 push，根目錄切回 develop；不 merge 回 develop
  - 立即開始: 呼叫 `/ss-workflow:check-req REQ-0012`，由它開始實作 (new-req 不自己建立 worktree)
  - 保留 draft: commit + push 後根目錄切回 develop，branch 留著；之後用 `/ss-workflow:new-req REQ-xxxx` 接續
  - 捨棄: 刪除 branch (local 與 remote)，develop 上不留任何痕跡
- 一個 request branch 只處理一個 request；輸入包含多個可獨立實作的需求時，提議拆開並依序處理；與既有 request 重複時先提醒
- 此 skill 只寫 request，不自己實作；source repo 不會有任何 commit
- 支援 `type: hotfix` 作為 hotfix 的入口 (hotfix branch 規則見 `/ss-workflow:merge`，只能有一個專案)，draft 放在從 develop 開的 `hotfix/REQ-<id>-<slug>`，開始實作時改到從 workspace master 開的 `hotfix/<P>-v<version>`

## skill: `/ss-workflow:check-req`

只負責總覽、開始與實作；Verify 與 Review 由 `/ss-workflow:review` 處理

- 在根目錄執行 (根目錄在哪個 branch 都可以，不需要切到 develop): 總覽 + 開始；帶 request 編號時 (例如由 new-req 交過來) 只檢查並開始該 request，不列總覽、不再確認
  - 不 checkout 任何東西，透過 `<develop-ref>` 與各 branch 讀取 request 檔
    - `<develop-ref>`: 無 remote 時為 `develop`；有 remote 且本機 develop 沒有自己的 commit 時為 `origin/develop`；本機 develop 領先時為 `develop` (並提醒其他機器還看不到)；兩邊各有對方沒有的 commit 時以 `develop` 為主、另外讀 `origin/develop` 才有的 request，提醒 developer 先同步，且不開始只有一邊有的 request
    - 各專案依同樣的規則決定自己的 `<develop-ref>` (以該專案的 `develop-branch` 為準)
  - 總覽包含: 各 request branch 上的 request (含 draft 與 `ready`)、0.8.0 以前的 `req/` branch 與 develop 上的 `ready` request、每個 request 的有效狀態 / 兩層的 branch / worktree，以及 gitlink 落後的專案
  - 若發現異常 (e.g. worktree 已建立但沒有 start commit、`review` 狀態卻還留著 worktree、有 commit 沒 push、只有一層有 branch (`projects: []` 只有 workspace branch 是正常的)、內層 worktree 殘留)，先排除異常再開始
  - 不帶編號時，候選為 `ready` (開始) 與 `in-progress` (回到 worktree 接續，或重建 worktree 後接續) 的 request；在別台機器開始的 `in-progress` 只列在總覽，不列為候選
  - 推薦順序 (依序比較): hotfix → 被其他候選依賴的 request → `priority` → 先完成 `in-progress` 再開始 `ready` → `in-progress` 中先處理 review 退回重做的、再來是 worktree 還在的 → 編號較小的
  - 以表格列出候選、排序理由與選擇後的動作，前三個以 AskUserQuestion 詢問 (推薦的放第一個)；選定即為同意，不再重複確認；worktree 有未 commit 變更的候選標示「可能有其他 session 在使用」
  - 開始: `git worktree add <path> <branch>` 用既有的 request branch 建立 worktree，做 start commit (見 reqs 章節) 並 push；再為每個 request 的專案建立 branch 與內層 worktree 並 push，其他專案 detached 在 gitlink；之後在 worktree 上實作 (為了多 session 平行實作多個 request)
  - worktree 路徑: `.claude/worktrees/<branch 名稱，"/" 換成 "-">`，e.g. `.claude/worktrees/feat-REQ-0012-gui-button`，各專案在其中的 `projects/<P>`
  - 不主動接手別的 `in-progress` request (可能有其他 session 正在實作)，需 developer 同意
  - `in-progress` 但沒有 worktree (被 review 退回，或 worktree 遺失): developer 同意後重建兩層的 worktree 繼續實作
  - 根目錄停在 `in-progress` / `ready` 的 request branch 上 (退回重做或開始被中斷後沒切回 develop，或手動 checkout): git 不允許為根目錄所在的 branch 建立 worktree (兩層都一樣)，所以先確認根目錄沒有未 commit 的變更，developer 同意後把根目錄切回 develop，再重建 worktree
- 在 request worktree 上執行: 表示要再啟動實作
  - `in-progress`: 找出上次停在哪裡 (含 `## Notes` 內的 review feedback)，繼續實作
  - `review` / `done`: 實作已完成，這個 worktree 不該存在；確認沒有遺漏後刪除，並提示下一步
- 實作原則
  - 只在 request 的 worktree 內修改，不改根目錄的檔案、不切換根目錄的 branch (唯一例外: 上述 developer 同意的修復，把根目錄切回 develop)
  - 程式碼只 commit 在各專案的 branch；workspace branch 有 request 檔、gitlink，以及 workspace 檔案的 commit (docs 等，見「request 修改 workspace 檔案」)
  - 對外介面或行為改變時，在 workspace worktree 更新該專案的 `docs/<name>/` 與需要時的 overview，並列在 implementation summary 的 What changed
  - worktree 內只嘗試 `setup-command` (需要時) 與 `build-command` (編譯，在專案資料夾內)，不跑測試 / script / 執行檔 / 燒錄；`build-command` 留空或環境限制導致無法 build 時不算失敗，記錄在 `## Notes` 留給 Verify
  - 動手前先讀 `projects/AGENTS.md` 中該專案的 `## Project: <P>` 章節，以及專案本身的 `AGENTS.md` / `CLAUDE.md` / README (若有)；新檔案要依 Project rules 加入 build
  - 依 Spec 的 Architecture 實作，不自行更改架構；Spec 沒有 Architecture 時先提出並由 developer 確認；implementation summary 註明架構是否照 Spec
  - 規格不清楚或有誤時停下來問，不自行猜測；問題與回答寫入 `## Q&A` (階段 `implementation`)，規格異動要更新 `## Spec`；session 結束前還沒有答案時留 `A: (pending)`
  - workspace 的 commit 帶 `Refs: REQ-xxxx`；source repo 的 commit 只描述變更內容，不提 request、編號或 workspace，沒有 `Refs:`；每個 commit 都 push；測試程式照寫但不執行；acceptance criteria 不在這裡打勾 (Verify / Review 實際檢查後才打勾)
  - 交付前: 把各專案 develop 的新 commit merge 進來 (不 rebase)、自己讀一次 diff、在 `## Notes` 寫 implementation summary
    - 固定欄位: What changed (依專案) / Architecture / Ran in the worktree (實際跑過的指令與結果) / Did not run (沒跑的與原因) / Not done (沒做完的 criteria 或規格) / Verify / Review by hand / Follow-ups
    - 每一行都依實際發生的事寫，不依預期寫；沒有的欄位寫 "none"，不省略
    - 動到 agent 行為檔時另外寫 `### Behavior changes` (見「如實回報與 agent 行為檔」)
  - 交付: status 改為 `review`，連同各專案的 gitlink 一起 commit 並 push → 確認兩層沒有未 commit / 未 push 的內容 → 依「worktree 的結構」的順序刪除 worktree、保留 branch → 提示 `/ss-workflow:review REQ-xxxx`
- hotfix request
  - workspace branch 為 `hotfix/<P>-v<version>`，從 workspace master 開；專案 branch 為 `hotfix/v<version>`，從 source main 開；其他專案 detached 在 workspace master 的 gitlink (= 已 release 的版本)，一樣在 worktree 實作
  - workspace master 上沒有尚未 release 的 request 檔，所以 start commit 會把 request 檔從 draft branch (`hotfix/REQ-…`) 複製到 hotfix branch 並刪除 draft branch，之後狀態都記在 hotfix branch 上

## skill: `/ss-workflow:review`

由 developer 觸發，在根目錄對一個 `review` 狀態的 request 做 Verify 與 Review；不會 merge

- Verify: AI 執行 build / Test 專案 / 驗證 script；Review: developer 人工驗證，AI 引導
- 在根目錄執行 (不在 worktree)；根目錄必須在 develop 且乾淨，或已在該 request branch 上 (接續 review)
- 根目錄在 request branch 上，但 request 檔的 status 不是 `review` (e.g. 退回重做或 merge 做到一半被中斷、手動 checkout): 屬於未定義的狀態，回報 branch、status、可能原因與未 commit 的變更，由 developer 選擇
  - 重新開始 review: status 改回 `review` (檔案在 `reqs/done/` 時先移回 `reqs/`)，Verify 與 Review 從頭執行
  - merge 回 develop (hotfix 為 master 與 develop): status 不是 `done` 時先改為 `review`，根目錄留在該 branch，交給 `/ss-workflow:merge`
  - 兩者都不選: 不做任何變更並停止
- 流程
  1. 選擇 request (可帶 `REQ-xxxx`；否則列出所有 `review` 的 request)
  2. 根目錄 checkout workspace request branch、`git submodule update`，各 request 專案 checkout 其 project branch，並把各專案 develop (hotfix 為 main) 的新 commit merge 進來
  3. Verify: 對每個 request 的專案依序執行 `setup-command` (需要時)、`build-command`、`test-command`、`verify-command`、request 內指定的 script (在專案資料夾內；留空的指令略過並記為「未設定」；build 與 test 都未設定時要明講 Verify 沒有自動檢查任何東西)；能由這些檢查證明的 acceptance criteria 打勾；結果依專案寫入 `## Notes`
  4. Code review (可選): Verify 通過後詢問 developer 是否執行；對每個專案以 `<base>...<project branch>` (有 remote 時 base 為該專案的 `origin/<develop-branch>`，hotfix 為 main) 為範圍、在專案資料夾內呼叫 Claude Code 的 `code-review` skill，只檢查這個 request 的變更；workspace 的檔案不跑 code review，改由 Review 讀 diff
     - 不帶範圍不可執行: `/code-review` 預設只看尚未 push 的 commit，而這個工作流每個 commit 都會 push
     - 發現的問題先對照程式碼確認: 小問題當場修 (修完重跑 Verify)、大問題提議退回、不屬於這個 request 的記為 follow-up、不確定的交給 developer 決定
     - 結果 (含 skipped / not available) 寫入 `## Notes`；不打勾 acceptance criteria；不帶 `--fix` / `--comment`
     - 無法呼叫時不以自行讀 diff 代替；雲端的 `ultra` 只能由 developer 自己輸入，skill 只列出指令
     - Review 期間 developer 也可以隨時要求執行
  5. Review: 列出需要人工確認的項目 (含 workspace 檔案的每一個 diff，以及行為改了但 `docs/<name>/` 沒跟著改的專案)，以及每一項怎麼檢查 (要啟動哪個 sample / 執行檔、操作步驟、預期結果)；developer 要求時可代為啟動程式
  6. 詢問結果
     - Review 通過: 其餘 criteria 打勾、記錄結果 (連同 gitlink)、根目錄切回 develop，提示 `/ss-workflow:merge REQ-xxxx` 結案
     - 小修: 直接在根目錄修正，程式碼 commit 在專案的 request branch，workspace 更新 gitlink，重跑 Verify
     - 需要大改: feedback 寫入 `## Notes`、status 退回 `in-progress`、根目錄切回 develop，提示 `/ss-workflow:check-req REQ-xxxx` 在 worktree 繼續
     - 還在 review: 保留根目錄在 request branch 上，之後再下一次 `/ss-workflow:review` 接續
- 原則
  - 失敗或跳過的檢查不會記成通過；Review 是否通過只由 developer 決定
  - 每一項檢查只記為 `passed` / `failed (原因)` / `did not run (原因)` / `not configured` 其中之一；這次 review 實際跑過並看到通過才算 `passed`，不沿用 implementation summary 或先前的結果
  - 環境造成的失敗一樣記為 `failed` 或 `did not run` 並註明原因；developer 決定接受時，問題與回答寫入 `## Q&A` (階段 `review`)
  - 開始前先看 implementation summary 的 Not done，有沒做完的部分先告知 developer
  - request 動到 agent 行為檔時，`### Behavior changes` 必須涵蓋每個檔；缺的由 review 依 diff 補寫，每一項都列入 Review 由 developer 確認
  - Review 的人工確認清單另外包含: `## Notes` 內的 Assumption、Verify 中 `failed` 或 `did not run` 的檢查
  - 回報時分三類: 有跑且通過 / 有跑但失敗 / 沒跑或未設定；只要後兩類有任何一項，就不能總結為「通過」
  - Verify 失敗時區分小問題 (當場修)、大問題 (退回) 與環境問題 (如實回報)；無法判斷時詢問 developer
  - 未 commit 的變更 (developer 手動修改、build / 測試 / 程式產生的檔案): 通過的內容必須等於 commit 的內容
    - 檢查時機 (workspace 的 `git status --porcelain` 與各專案的 `git -C projects/<P> status --porcelain`，含 untracked 檔案): 接續 review 時、每次 Verify 前、code review 前、處理結果前
    - 清單上每一項都要由 developer 決定，不留未決定的，也不 commit developer 沒看過的: 屬於 request (commit 成 `fix:` 等一般 commit，含新增的檔案，並在 `## Notes` 記「Changed by the developer」)、產生的或本機檔案 (加入該 repo 的 `.gitignore`，另一個 `chore:` commit；source repo 的 `.gitignore` 也算 request 的變更)、不要的 (developer 確認後捨棄)、先留著繼續試
    - 沒有「先留著」的項目時用 `git add -A`，否則依路徑 stage；記錄結果的 commit 只 stage request 檔與 gitlink
    - 先留著的期間: Verify 可以跑但不算數 (記錄註明含未 commit 的修改)、code review 不涵蓋、不能選「Review 通過」或「需要大改」
    - Verify 只有在乾淨的工作目錄上跑才算數；最後一次 Verify 之後有改到程式碼的 commit 時，要重跑 Verify 才能記 Review 通過
    - 切回 develop 前 workspace 與各專案的 `git status --porcelain` 必須是空的 (含 untracked)

## skill: `/ss-workflow:merge`

本工作流 git 遵循 gitflow 流程，有不同形態的 branch (worktree)，且分成 workspace 與各專案兩層
若發現有 remote 端: e.g. github, gitlab，讓使用者選擇是否要發 merge-request 到 remote，由 remote 端 merge；對應到此，在 merge 之前都要先去 fetch remote，先用 `git merge-base --is-ancestor` 檢查 (任何 remote 都適用)，有平台時再用 `gh pr view` / `glab mr view` 檢查，因為有可能是已經發過 merge-request，也合併完了
沒有 remote 時，local merge 就是完整的 merge，所有 pull / push 步驟略過；有 remote 但不是 GitHub / GitLab 時 (`remote-platform: none`)，一律 local merge 後 push
合併完成後，刪除兩層的 local / remote branch (worktree 在實作完成時就已刪除，若有殘留一併清除)
刪除前一定要先確認已合併 (`git merge-base --is-ancestor` 或 merge-request 狀態)；`git branch -d` 不能當安全檢查，已 push 但未 merge 的 branch 它只給 warning 就會刪除
對 request 而言，developer 執行此 skill 就代表驗收通過、結案

- 共通規則
  - 在根目錄執行 (不在 worktree)；會在 target branch / develop / master 之間切換，結束時停在 develop 並 `git submodule update`
  - request 的 `## Notes` 內沒有通過的 Review 或 Verify 結果時先提醒，由 developer 決定先跑 `/ss-workflow:review` 或直接 merge；最後一次 Verify 有 `failed` / `did not run`、有未確認的行為變更、`## Q&A` 有 pending 時也一樣提醒；developer 決定直接 merge 時，問題與回答寫入 `## Q&A`
  - 各專案依自己的 `remote-platform` / `merge-method` / `push-policy` (沒有覆寫時用 workspace 的)
  - 發 merge-request 需要 branch 已在 remote 上；不能 push 時做完 Prepare 就停止，告知 developer 要 push 哪個 branch
  - remote 拒絕 push 到受保護的 develop / master 時不繞過: 還原尚未發佈的 local merge commit，有平台改發 merge-request，沒有平台就停止並告知 developer 需要在 remote 上 merge 什麼 (request 為 merge pending)
  - 刪除 remote branch 只在允許 push 時進行，否則在回報中列出
  - draft 與 `ready` 的 request 不由此 skill 處理 (規格討論或實作尚未完成)
  - merge 方式由 Workflow settings 的 `merge-method` 決定: `local` (local merge 後 push) / `remote` (發 merge-request) / `ask` (每次詢問，預設)
  - 一律 `--no-ff`，不 squash、不 rebase 已 push 的 branch、不 force-push
  - merge commit message: `Merge <source> into <target>` (不套用 `<type>(<scope>)` 格式)，workspace 的 body 帶 request title 與 `Refs: REQ-xxxx`；source repo 的 body 為一行描述變更內容的英文，沒有 `Refs:`
  - source repo 的 merge request: 標題為 `<type>: <變更內容>`，內容不帶 request 編號、workspace 名稱或 workspace 檔案的連結
  - 根目錄有未 commit 的變更 (含各專案)，或正忙著別的事 (在 draft 的 request branch 或其他 request branch 上) 時停止
  - remote 上的 merge-request 狀態: 已合併 → 直接收尾；開啟中 → 詢問要等待或改用 local merge；已關閉 → 詢問
  - 選擇發 merge-request 時，skill 發完就把根目錄切回 develop 並停止；remote 合併後 developer 再下一次 `/ss-workflow:merge` 收尾 (刪除 branch)
  - 放棄 request: 透過一個短暫的 `drop/REQ-<id>` branch 把 request 標為 `done` 並註明原因，merge 回 workspace develop；各專案 branch 有未合併的 commit，需另外確認才刪除

- request
  - 所有 reqs 都在 develop 開分支出去，完成後 merge 回 develop (兩層都是)
  - request branch(worktree)種類可能會有: feat, fix, docs ... 等類型
  - branch(worktree) name 範例: workspace `feat/REQ-0012-gui-button`，專案 `feat/gui-button`
  - request 實作都開在 worktree 實作；merge 時 worktree 已刪除，全程在根目錄 checkout request branch 進行
  - 只 merge 有效狀態為 `review` 的 request
  - 順序: 先各專案，最後 workspace
    1. 每個專案: 把專案 develop 的新 commit merge 進專案 branch 並解衝突 (有新 commit 時重新跑 build + test + `verify-command`)，再 `--no-ff` merge 到專案 develop 並 push (或發 merge-request)
    2. workspace: 關閉 request (status 改為 `done`、`git mv` 到 `reqs/done/`，gitlink 設為各專案 develop 的 merge commit) 是 workspace request branch 上的最後一個 commit，隨著 merge 一起進 develop
    - `projects: []` 的 request 沒有專案 branch，只做第 2 步
  - 任何一步中斷 (merge-request 等待中、受保護的 branch)，下一次執行時以 `merge-base --is-ancestor` (專案 branch 是否已在專案 develop、workspace branch 是否已在 workspace develop) 判斷做到哪裡再接續
  - 發 merge-request 的情況下，專案已合併但 workspace 還沒 = 「merge pending」；remote review 要求修改時，下 `/ss-workflow:review REQ-xxxx` 重新開啟並繼續 review

- release (各專案自己的版本，見 `/ss-workflow:release`)
  - source repo: 從專案 develop 開 `release/v1.0.0-beta1`，完成後 merge 回專案 main 與 develop，在專案 main 的 merge commit 打 `v1.0.0-beta1`
  - workspace: 沒有 release branch；develop 的 gitlink 更新為專案 develop (release 沒有自己的 commit 時不需要)，再把 workspace develop `--no-ff` merge 到 workspace master，在同一個 merge commit 把**每個**專案的 gitlink 設為各自專案 main 的最新 commit (`git update-index --cacheinfo 160000,<sha>,projects/<P>`，這也解掉 gitlink 的衝突)，打 `<P>/v1.0.0-beta1`
  - 不開 worktree
  - merge 前檢查: 專案的 version-source 的版本與 branch 相符、兩層的 tag 都尚未存在、build + test 通過
  - push 專案 main、workspace master 與 tag 等於對外釋出，不論 `push-policy` 為何，push 前都再確認一次，並用 `git push --atomic` 一次推送 (每個 repo 各一次)；`push-policy: never` 時不 push，只列出指令由 developer 執行
  - 完成後可選擇是否在專案的平台上建立 release (`gh release create` / `glab release create`)

- hotfix (各專案)
  - 專案: `hotfix/v1.0.1` 從專案 main 開，完成後 merge 回專案 main 與 develop，打 `v1.0.1`
  - workspace: `hotfix/<P>-v1.0.1` 從 workspace master 開，完成後 merge 回 workspace master (gitlink = 專案 main 的 hotfix merge commit，打 `<P>/v1.0.1`) 與 workspace develop (gitlink = 專案 develop)
  - 開 worktree 實作 (由 `type: hotfix` 的 request 經 `/ss-workflow:check-req` 開始)，Verify / Review / merge 一樣在根目錄
  - merge 回專案 develop 時 version-source 衝突，保留較高的版本 (通常是 develop 的)
  - 若該專案有進行中的 release branch，詢問是否也 merge 進去
  - request 檔在 workspace hotfix branch 上關閉 (開始時已從 draft branch 複製過來)；merge 回 workspace develop 時用 `--no-commit`，在同一個 merge commit 內 (0.8.0 以前開始的 hotfix 才有) 刪除 develop 上仍為 `ready` 的舊副本，並把 gitlink 設為專案 develop

- master (兩層都持續存在)
  - 專案 main: 主要是在有新版要釋出時，才會有新的 commit
  - workspace master: 任一專案 release 或 hotfix 時更新，內容 = 各專案最新 release 的組合，加上當時的 request 紀錄
  - 例外: 專案 v1.0.0 釋出之前為快速疊代期，允許專案 develop 直接 merge 到專案 main，並建立 `v0.x.y` tag，workspace master 一併更新 (由 `/ss-workflow:merge` 的 pre-1.0 sync 處理，僅在 developer 要求時執行)

- develop (兩層都持續存在)
  - 主要是開發 branch，所有變動大部分都會在這邊

## skill: `/ss-workflow:release`

參數: `[<project>] [version]`；workspace 只有一個專案時可省略 `<project>`

- 在 workspace 根目錄的 develop 上使用此 skill，表示想釋出某個專案的新版本
  - 檢查適合的版本號推薦給使用者 (依該專案 source repo 的上一個 tag 與專案 develop 上的 commit type)，使用者同意後，從專案 develop 建立 release branch
  - release branch 建立後，檢查是否有未完成需求 (`projects` 含該專案、非 `done` 的 request)、未完成 worktree；若有未完成，讓 developer 決定是否 release?
    - 若不同意，先處理完需求， developer 要再下一次此 skill
  - 若同意 release ，則去檢查該專案 `version-source` (以及 `## Project: <P>` 章節列出的其他位置、專案內另外設定版本的地方) 的版本號是否與 release branch 相符
    - 若不相符作相對應的修改並 commit (在 source repo)
  - 若相符則直接啟用 release merge 規則 (見 `/ss-workflow:merge`)
- 若專案已有 release branch，表示接續先前的 release (根目錄停在 develop，專案停在該 release branch)
  - 專案 develop 有 release branch 沒有的 commit 時 (e.g. 剛完成的 request)，詢問是否納入這次 release
- 每個專案一次只進行一個 release；已有 release branch 時不再建立新的；不同專案可以先後 release
- 這次 release 包含的 request: 上一個 `<P>/v*` tag 之後 `reqs/done/` 新增、且 `projects` 含該專案的 request (沒有 `projects` 欄位的舊 request 屬於 `legacy-project`；`projects: []` 的 request 不屬於任何專案的 release)
- 版本號格式: `vX.Y.Z-{alpha/beta/rc}{R}`
  - X / Y / Z (MAJOR / MINOR / PATCH) 為 0 到 99 的整數，最多兩位數，不補零
  - 正式版本沒有後綴: `v1.0.0`；prerelease 使用後綴，階段只有 `alpha` / `beta` / `rc`，R 從 1 開始、直接接在階段後面: `v1.0.0-alpha1`、`v1.0.0-beta2`、`v1.0.0-rc1`
  - 同一個 X.Y.Z 的順序: `alpha` < `beta` < `rc` < 正式版；同階段依 R 的數值比較 (`alpha2` < `alpha10`)，不以文字比較
  - 階段不回頭: 出過 `rc1` 之後，同一個 X.Y.Z 不再有 `beta3`
  - tag: source repo 為 `v<version>`，workspace 為 `<P>/v<version>`
- 版本號推薦規則
  - 要遞增的位數已經是 99 時: 改推薦進位到上一位 (`1.4.99` → `1.5.0`) 並說明原因；MAJOR 已是 99 時沒有合法的下一版，交給 developer 決定
  - 尚無 tag (第一次 release): 使用 version-source 目前的版本
  - 1.0.0 以上: breaking → MAJOR、`feat` → MINOR、其他 → PATCH
  - 1.0.0 以下: breaking 與 `feat` → MINOR、其他 → PATCH；升到 1.0.0 由 developer 決定，不主動推薦
  - 上一個 tag 是 prerelease (e.g. `1.0.0-beta1`): 候選為同階段的下一個 (`beta2`) / 下一階段的第一個 (`rc1`) / 正式版
  - 上一個 tag 是正式版: 推薦正式版，另提供 prerelease 作為替代，階段由 developer 選擇 (`alpha1` / `beta1` / `rc1` 都可以)
  - 可直接帶版本號 `/ss-workflow:release SSDisp 1.0.0-beta1` 跳過推薦
- 未完成工作的判定 (只看該專案)
  - 未完成 (需 developer 決定): `in-progress`、`review`、merge pending 的 request，以及該專案未合併的 hotfix
  - 尚未開始 (draft、`ready`): 只列出，不阻擋 release
  - developer 的選項: 不含這些直接 release / 先完成 (專案切回 develop 處理，完成後再下一次) / 取消 release (刪除專案的 release branch)
- 版本號檢查範圍: 該專案的 version-source、`## Project: <P>` 章節列出的其他位置、專案內另外設定版本的地方、專案內 README / docs、既有的 `CHANGELOG.md` (沒有則不建立；條目以變更內容描述，不帶 request 編號)
  - workspace 以外的變更: request 不再以 `Refs:` 標示，改由已關閉 request 的 `Merged into develop` 紀錄找出它們的 merge commit；專案 develop 的 first-parent 歷史中其他的 commit 都來自 workspace 以外 (例如別人自己的 workspace)
  - workspace 的 `docs/<P>/` 與 `docs/overview.md` 內標示該專案目前版本的地方: workspace 沒有 release branch，由 release merge 在 workspace develop merge 到 master **之前**修改 (master 才會顯示新版本)；hotfix 在 workspace hotfix branch 上修改
  - 版本號的寫法依專案形式而定，沿用該欄位原本的格式 (e.g. 只能放四段數字的欄位寫成 `X.Y.Z.0`)
  - `version-source` 為 `none` 時不改檔案，版本只以 git tag 表示
- release branch 上只做 release 相關的變更 (版本號、release notes、阻擋 release 的修正)，新功能一律走 request

## Remote 與 push

此章節的規範會寫入 workspace root `AGENTS.md` (「Remote and pushing」)，各 skill 的「push」都依此判斷；workspace 與每個專案各自判斷

- 工作流不需要 remote。有沒有 remote 看該 repo 的 `git remote` 是否有 `origin`；`remote-platform` 只表示能不能發 merge-request (`github` / `gitlab`)，其他 remote 與沒有 remote 都是 `none`
- 沒有 remote: 所有 fetch / pull / push 步驟略過；本機 `develop` 代表 `origin/develop`、request 都在本機 branch 上、branch 一律 local merge
- 以沒有 origin 的 local 路徑加入的專案: submodule 的 origin 是 developer 的 working copy，視為不 push (`push-policy: never`)，fetch 照做
- 有 remote: 由 `push-policy` 決定 agent push 什麼 (專案沒有覆寫時用 workspace 的)

| `push-policy` | agent 的行為 |
|---------------|--------------|
| `auto` (預設) | 每次 commit 後 push topic branch (request、`hotfix/*`、`release/*`)；developer 要求 merge 之後 push develop |
| `ask` | 只在本機 commit；每次執行 skill 第一次要 push 前詢問，同意後該次執行都適用，拒絕則該次視同 `never` |
| `never` | 不 push、不刪除 remote branch；仍會 fetch 與 pull |

- 沒有 push 時 skill 繼續進行，並在回報中列出尚未在 remote 上的 branch 與 tag (依 repo)；在 developer push 之前，其他機器看不到這些 request 與狀態變更
- 不論 `push-policy` 為何都成立:
  - 不 force-push、不改寫已發佈的歷史
  - push master / main 或 tag 等於釋出，每次 push 前都要詢問 developer
  - 確認已 merge 之前不刪除 branch (local 與 remote)；有未合併 commit 的 branch 只有 developer 針對該 branch 明確同意才刪除
  - remote 拒絕 push 到受保護的 branch 時不繞過
- 取捨 (自動 push 與 never push 的比較):
  - 自動 push: 其他 session 即時看到 request 與狀態、每個 commit 都有備份、可直接發 merge-request；代價是誤 commit 的內容立刻外流且收不回、每次 push 都觸發 CI
  - never push: agent 無法對外發佈任何東西；代價是其他機器看到的狀態落後、merge-request 要先由人 push
  - 兩者沒有絕對的好壞，所以做成設定；預設 `auto` 是因為原本的設計就已經分層 (自動 push 的只有 topic branch，develop 在 developer 下指令後才 push，master 與 tag 一律再確認)
  - source repo 可能有 workspace 以外的人在用，所以可以針對專案設成 `ask` 或 `never`

## 如實回報與 agent 行為檔

此章節的規範會寫入 workspace root `AGENTS.md` (「Working agreement」) 與 `reqs/AGENTS.md` (「Results and behavior changes」)

- 如實回報: 每一份回報與寫入 request 的結果，都要講明什麼有跑且通過、什麼有跑但失敗、什麼沒跑以及原因；沒跑的檢查不能回報為通過，「應該會過」也不算
- Agent 行為檔: agent 當作指示來讀的檔案
  - 內建清單: `AGENTS.md`、`CLAUDE.md`、`.claude/` 底下的檔案 (不含 `.claude/worktrees/`)、`SKILL.md` 與同資料夾內的檔案 (workspace 與各專案內都算)
  - 專案自訂: Workflow settings 的 `agent-files`
- 改一行 agent 行為檔就是改變 agent 的行為，build 與測試都看不出來，所以動到這類檔案的 request 必須在 `## Notes` 附 `### Behavior changes`，每個檔一項:
  - Diff: 修改的原文 (太長時改附可重現的指令 `git diff <base>...<branch> -- <path>`)
  - Before / After: 用白話描述行為，不是描述修改本身 (e.g. 「Before: 每次 commit 後都 push。After: 第一次 push 前先詢問」)
  - 不影響行為的修改 (錯字、沒有人查找的標題) 也要列出並明講不影響行為
- 由實作 session 撰寫；Verify 無法證明，所以每一項都由 developer 在 Review 確認；缺漏時由 `/ss-workflow:review` 依 diff 補寫

## Git commit

此章節的規範會寫入 workspace root `AGENTS.md`，所有 commit 都需遵守，不只在執行 skill 時 (source repo 的 commit 也一樣)

### commit 原則

- 在實作的過程中，可以一直 commit，讓每一次變動可以看得出為什麼而變動，而不是一大堆的檔案一起包在同一個 commit 上
- request branch 上的 commit 每次都 push 到 remote (允許 push 時，見「Remote 與 push」)
- source repo 只有實作的 commit (程式碼、測試、版本號)；需求討論、request 狀態、review 結果的 commit 只在 workspace
- source repo 的 commit 就是一般專案的 commit: 以描述需求/修改內容為主，不出現 request 編號、workspace 名稱或 workspace 的檔案；專案有自己的 commit 規範時依其規範

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
 - 填寫 request 編號（如果有的話）
   - workspace 的 commit: Refs: REQ-0012
   - source repo 的 commit: 不寫 (REQ 編號只在一個 workspace 內有意義，每位開發者可能有自己的 workspace)
 - BREAKING CHANGE（可忽略），記錄不兼容的變動，
   以 BREAKING CHANGE: 開頭，後面是對變動的描述、以及變動原因和遷移方法。
```
 
- Reference: 
  - https://wadehuanglearning.blogspot.com/2019/05/commit-commit-commit-why-what-commit.html
  - https://ithelp.ithome.com.tw/articles/10228738
