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
    ├── ss-workflow-review/SKILL.md
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
- merge 方式 (`merge-method`): 每次詢問 / local merge / 發 merge-request
- 現有專案: 說明轉換的方法，由 developer 確認或答覆需調整的部分

問答結果記錄在 root `AGENTS.md` 的 Workflow settings，另有選填的 `verify-command` (`/ss-workflow-review` 在 build 與測試之後額外執行的驗證 script)，init 不詢問，由 developer 需要時自行填入

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
├─ Directory.Build.props     (集中管理版本號，src / tests / samples 的專案都會繼承)
├─ src/ (Source Code 目錄)
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   ├── VisualStudioSolution.sln
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

- Solution file (`.sln`) 放在 `src/` 內，與各專案資料夾同一層 (符合 Visual Studio 原本的階層設計)
  - `tests/` 與 `samples/` 的專案也加入這個 solution，以相對路徑參考 (e.g. `..\tests\MyLib.Tests\MyLib.Tests.csproj`)
  - build / test 指令: `dotnet build src/<Solution>.sln`、`dotnet test src/<Solution>.sln`
- `Directory.Build.props` 留在 repo 根目錄，這樣 `src/`、`tests/`、`samples/` 的專案都會繼承同一個版本號

#### reqs

整個工作流最主要的核心資料夾。每個 request 只有一個 `.md` 檔，不另外建立資料夾，也沒有 `STATUS.md`。

- 各階段在哪裡進行 (根目錄 = repo 的主要 checkout，平常停在 develop):

| 階段 | 位置 | skill |
|------|------|-------|
| 規格討論 | 根目錄，`req/REQ-xxxx-<slug>` branch | `/ss-workflow-new-req` |
| 實作 | worktree，request branch | `/ss-workflow-check-req` |
| Verify (跑 build / Test 專案 / script) 與 Review (人工驗證) | 根目錄，checkout request branch | `/ss-workflow-review` |
| 結案 (merge) | 根目錄 | `/ss-workflow-merge` |

  - 在 worktree 上跑 script 或執行檔的限制較多，所以 worktree 只寫程式並嘗試編譯，不跑測試、script、執行檔
  - AI 完成實作後直接刪除 worktree，但保留 branch；request 停在 `review` 狀態，由 developer 觸發 `/ss-workflow-review` 才開始 Verify 與 Review
  - developer 執行 `/ss-workflow-merge` 就算結案
  - 根目錄一次只能做一件事 (規格討論 / review / merge / release)；skill 切換根目錄的 branch 前，先確認它在 develop 且沒有未 commit 的變更，完成後切回 develop

- 檔名: `REQ-<4 位流水號>-<yyyyMMdd>-<slug>.md`，e.g. `REQ-0012-20260907-gui-button.md`
  - 流水號取「使用中的最大號 + 1」；使用中 = develop 上 `reqs/` 與 `reqs/done/` 的檔案，以及 local / remote 上名稱含該編號的 branch (`req/REQ-0012-…`、`feat/REQ-0012-…`)
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

| status        | 意義                                         | 該狀態的檔案在哪個 branch            | 誰設定 |
|---------------|----------------------------------------------|--------------------------------------|--------|
| `draft`       | 規格討論中                                   | `req/REQ-…` branch (根目錄)          | `/ss-workflow-new-req` |
| `ready`       | developer 確認規格，等待認領                 | develop (`req/` branch merge 之後)   | `/ss-workflow-new-req` |
| `in-progress` | 已認領，在 worktree 實作中                   | request branch                       | `/ss-workflow-check-req` |
| `review`      | 實作完成、worktree 已刪除、branch 保留；等待或正在 Verify 與 Review | request branch | `/ss-workflow-check-req` 設定，`/ss-workflow-review` 處理 |
| `done`        | 已關閉，檔案在 `reqs/done/`                  | request branch 的最後一個 commit (merge 前) | `/ss-workflow-merge` |

- draft 只存在 `req/` branch 上，develop 上只有 developer 確認過的 request
- 有效狀態: develop 上的檔案在 merge 前一直顯示 `ready`；request branch 上的檔案才是目前的狀態 (`in-progress` / `review` / `done`)
- 認領 (lock):
  - 「建立 request branch」就是認領: 從 develop 建立 `<type>/REQ-<id>-<slug>` 並 push；git 保證同名 branch 只能建立一次
  - 該編號的 branch 已存在 (local 或 remote) = 已被認領
  - branch 上的第一個 commit 將 status 改為 `in-progress` 並寫入 `branch`
  - 認領不需要根目錄在 develop，所以根目錄正在討論規格或 review 時，其他 session 仍可認領
- 同步到 remote:
  - 建立 branch 後立即 `git push -u`，實作過程中每次 commit 都 push
  - 刪除 worktree 前確認沒有未 commit 的變更、沒有未 push 的 commit
- 找回 request (session 遺漏時): 依 branch 名稱中的 `REQ-<id>`，搭配 `git worktree list` 或 remote branch 找回
- Review 發現問題時:
  - 小修 (不影響設計與規格的局部修正): 直接在根目錄的 request branch 上修，重跑 Verify
  - 大改: 狀態退回 `in-progress`，由實作 session 重新開 worktree 處理

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

- 在根目錄執行 (不在 worktree)；根目錄必須在 develop 且乾淨，或已在某個 `req/` branch 上 (接續該 draft)
- 從 develop 開 `req/REQ-<id>-<slug>` branch 並立即 push (同時占住流水號)，在上面建立 `status: draft` 的 request 檔 (若提供 .md，原文放入 `## Original`)
- 與 developer 討論細部的需求規格，寫入 `## Spec`；每一輪討論後 commit + push
  - Spec 內含 Goal / Scope / Acceptance criteria / How to verify (每項標明由 Verify 自動檢查或 Review 人工檢查) / Out of scope / Open questions
- developer 確認規格沒有問題後，將 status 改為 `ready`，把 `req/` branch `--no-ff` merge 回 develop 並刪除該 branch；之後由其他 session 認領
  - `merge-method` 為 `remote` 或 develop 不允許直接 push 時，改發 merge-request
  - 保留 draft: commit + push 後根目錄切回 develop，`req/` branch 留著；之後用 `/ss-workflow-new-req REQ-xxxx` 接續
  - 捨棄: 刪除 `req/` branch，develop 上不留任何痕跡
- 一個 `req/` branch 只處理一個 request；輸入包含多個可獨立實作的需求時，提議拆開並依序處理；與既有 request 重複時先提醒
- 此 skill 只寫 request，不實作
- 支援 `type: hotfix` 作為 hotfix 的入口 (hotfix branch 規則見 `/ss-workflow-merge`)，規格討論一樣走 `req/` branch 並 merge 回 develop

## skill: `/ss-workflow-check-req`

只負責總覽、認領與實作；Verify 與 Review 由 `/ss-workflow-review` 處理

- 在根目錄執行 (根目錄在哪個 branch 都可以，不需要切到 develop): 總覽 + 認領
  - 不 checkout 任何東西，透過 `origin/develop` (無 remote 時為 `develop`) 與各 branch 讀取 request 檔
  - 總覽包含: `req/` branch 上的 draft、develop 上的 request、每個 request 的有效狀態 / branch / worktree
  - 若發現異常 (e.g. branch 已建立但沒有認領 commit、`review` 狀態卻還留著 worktree、有 commit 沒 push)，先排除異常再認領
  - 若有多個 `ready` 的 request，依 `priority` 排序後讓 developer 選擇
  - 認領: `git worktree add -b <branch> <path> <develop>` 一次建立 branch 與 worktree，push，再做認領 commit (見 reqs 章節)；之後在 worktree 上實作 (為了多 session 平行實作多個 request)
  - worktree 路徑: `.claude/worktrees/<branch 名稱，"/" 換成 "-">`，e.g. `.claude/worktrees/feat-REQ-0012-gui-button`
  - 不主動接手別的 `in-progress` request (可能有其他 session 正在實作)，需 developer 同意
  - `in-progress` 但沒有 worktree (被 review 退回，或 worktree 遺失): developer 同意後重建 worktree 繼續實作
- 在 request worktree 上執行: 表示要再啟動實作
  - `in-progress`: 找出上次停在哪裡 (含 `## Notes` 內的 review feedback)，繼續實作
  - `review` / `done`: 實作已完成，這個 worktree 不該存在；確認沒有遺漏後刪除，並提示下一步
- 實作原則
  - 只在 request 的 worktree 內修改，不改根目錄的檔案、不切換根目錄的 branch
  - worktree 內只嘗試 `build-command` (編譯)，不跑測試 / script / 執行檔；環境限制導致無法 build 時不算失敗，記錄在 `## Notes` 留給 Verify
  - 規格不清楚或有誤時停下來問，不自行猜測；規格異動要更新 `## Spec` 並在 `## Notes` 記錄原因
  - 每個 commit 帶 `Refs: REQ-xxxx` 並 push；測試程式照寫但不執行；acceptance criteria 不在這裡打勾 (Verify / Review 實際檢查後才打勾)
  - 交付前: 把 develop 的新 commit merge 進來 (不 rebase)、自己讀一次 diff、在 `## Notes` 寫 implementation summary (改了什麼、worktree 內 build 結果、Verify 要跑什麼、Review 要人工看什麼)
  - 交付: status 改為 `review` 並 push → 確認沒有未 commit / 未 push 的內容 → 刪除 worktree、保留 branch → 提示 `/ss-workflow-review REQ-xxxx`
- hotfix request
  - branch 為 `hotfix/v<version>`，從 master 開，一樣在 worktree 實作
  - master 上沒有 request 檔，所以認領 commit 會把 request 檔從 develop 複製到 hotfix branch，之後狀態都記在 hotfix branch 上

## skill: `/ss-workflow-review`

由 developer 觸發，在根目錄對一個 `review` 狀態的 request 做 Verify 與 Review；不會 merge

- Verify: AI 執行 build / Test 專案 / 驗證 script；Review: developer 人工驗證，AI 引導
- 在根目錄執行 (不在 worktree)；根目錄必須在 develop 且乾淨，或已在該 request branch 上 (接續 review)
- 流程
  1. 選擇 request (可帶 `REQ-xxxx`；否則列出所有 `review` 的 request)
  2. 根目錄 checkout request branch，並把 develop (hotfix 為 master) 的新 commit merge 進來
  3. Verify: 依序執行 `build-command`、`test-command`、Workflow settings 的 `verify-command` (選填)、request 內指定的 script；能由這些檢查證明的 acceptance criteria 打勾；結果寫入 `## Notes`
  4. Review: 列出需要人工確認的項目，以及每一項怎麼檢查 (要啟動哪個 sample / 執行檔、操作步驟、預期結果)；developer 要求時可代為啟動程式
  5. 詢問結果
     - Review 通過: 其餘 criteria 打勾、記錄結果、根目錄切回 develop，提示 `/ss-workflow-merge REQ-xxxx` 結案
     - 小修: 直接在根目錄的 request branch 上修正並 commit，重跑 Verify
     - 需要大改: feedback 寫入 `## Notes`、status 退回 `in-progress`、根目錄切回 develop，提示 `/ss-workflow-check-req REQ-xxxx` 在 worktree 繼續
     - 還在 review: 保留根目錄在 request branch 上，之後再下一次 `/ss-workflow-review` 接續
- 原則
  - 失敗或跳過的檢查不會記成通過；Review 是否通過只由 developer 決定
  - Verify 失敗時區分小問題 (當場修)、大問題 (退回) 與環境問題 (如實回報)；無法判斷時詢問 developer
  - 切回 develop 前，若 Verify 或執行程式改動了被追蹤的檔案，先讓 developer 決定 commit 或捨棄

## skill: `/ss-workflow-merge`

本工作流 git 遵循 gitflow 流程，有不同形態的 branch (worktree)
若發現有 remote 端: e.g. github, gitlab，讓使用者選擇是否要發 merge-request 到 remote，由 remote 端 merge；對應到此，在 merge 之前都要先去 fetch remote，並用 `gh pr view` / `glab mr view` 檢查，因為有可能是已經發過 merge-request，也合併完了
合併完成後，刪除 local / remote branch (worktree 在實作完成時就已刪除，若有殘留一併清除)
對 request 而言，developer 執行此 skill 就代表驗收通過、結案

- 共通規則
  - 在根目錄執行 (不在 worktree)；會在 target branch / develop / master 之間切換，結束時停在 develop
  - request 的 `## Notes` 內沒有通過的 Review 或 Verify 結果時先提醒，由 developer 決定先跑 `/ss-workflow-review` 或直接 merge
  - `req/` branch 不由此 skill 處理 (由 `/ss-workflow-new-req` 在規格確認時 merge)
  - merge 方式由 Workflow settings 的 `merge-method` 決定: `local` (local merge 後 push) / `remote` (發 merge-request) / `ask` (每次詢問，預設)
  - 一律 `--no-ff`，不 squash、不 rebase 已 push 的 branch、不 force-push
  - merge commit message: `Merge <source> into <target>` (不套用 `<type>(<scope>)` 格式)，body 帶 request title 與 `Refs: REQ-xxxx`
  - 根目錄有未 commit 的變更，或正忙著別的事 (在 `req/` branch 或其他 request branch 上) 時停止
  - remote 上的 merge-request 狀態: 已合併 → 直接收尾；開啟中 → 詢問要等待或改用 local merge；已關閉 → 詢問
  - 選擇發 merge-request 時，skill 發完就把根目錄切回 develop 並停止；remote 合併後 developer 再下一次 `/ss-workflow-merge` 收尾 (刪除 branch)
  - 放棄 request: 透過一個短暫的 `req/REQ-<id>-drop` branch 把 request 標為 `done` 並註明原因，merge 回 develop；request branch 有未合併的 commit，需另外確認才刪除

- request
  - 所有 reqs 都在 develop 開分支出去，完成後 merge 回 develop
  - request branch(worktree)種類可能會有: feat, fix, docs ... 等類型
  - branch(worktree) name 範例: `feat/REQ-0012-gui-button`
  - request 實作都開在 worktree 實作；merge 時 worktree 已刪除，全程在根目錄 checkout request branch 進行
  - 只 merge 有效狀態為 `review` 的 request
  - merge 前先把 develop 的新 commit merge 進 request branch，在 branch 上解衝突；有 merge 進新 commit 時重新跑 build + test (+ `verify-command`)
  - 關閉 request (status 改為 `done`、`git mv` 到 `reqs/done/`) 是 request branch 上的最後一個 commit，隨著 merge 一起進 develop
    - 發 merge-request 的情況下，branch 上為 `done` 但尚未合併 = 「merge pending」；remote review 要求修改時，下 `/ss-workflow-review REQ-xxxx` 重新開啟並繼續 review

- release
  - 會從 develop 開分支出去，完成後 merge 回 master 與 develop
  - branch name 範例: release/v1.0.0-beta1
  - 不開 worktree
  - 合併回 master 後，依照 branch name 建立 tag: e.g. v1.0.0-beta1
  - merge 前檢查: version-source 的版本與 branch 相符、tag 尚未存在、build + test 通過
  - push master 與 tag 等於對外釋出，push 前再確認一次，並用 `git push --atomic` 一次推送 master / develop / tag
  - 完成後可選擇是否在平台上建立 release (`gh release create` / `glab release create`)
  - release 流程使用 `/ss-workflow-release`

- hotfix
  - 會從 master 開分支出去，完成後 merge 回 master 與 develop
  - branch name 範例: hotfix/v1.0.1
  - 開 worktree 實作 (由 `type: hotfix` 的 request 經 `/ss-workflow-check-req` 認領)，Verify / Review / merge 一樣在根目錄
  - 合併回 master 後，依照 branch name 建立 tag: e.g. v1.0.1
  - merge 回 develop 時 version-source 衝突，保留較高的版本 (通常是 develop 的)
  - 若有進行中的 release branch，詢問是否也 merge 進去
  - request 檔在 hotfix branch 上關閉 (認領時已從 develop 複製過來)；merge 回 develop 時用 `--no-commit`，在同一個 merge commit 內刪除 develop 上仍為 `ready` 的舊副本

- master (持續存在)
  - 主要是在有新版要釋出時，才會有新的 commit
  - 例外: v1.0.0 釋出之前為快速疊代期，允許 develop 直接 merge 到 master，並建立 `v0.x.y` tag (由 `/ss-workflow-merge` 的 pre-1.0 sync 處理，僅在 developer 要求時執行)

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
- 若在 release branch 上使用此 skill，表示接續先前的 release
  - develop 有 release branch 沒有的 commit 時 (e.g. 剛完成的 request)，詢問是否納入這次 release
- 一次只進行一個 release；已有 release branch 時不再建立新的
- 版本號推薦規則
  - 尚無 tag (第一次 release): 使用 version-source 目前的版本
  - 1.0.0 以上: breaking → MAJOR、`feat` → MINOR、其他 → PATCH
  - 1.0.0 以下: breaking 與 `feat` → MINOR、其他 → PATCH；升到 1.0.0 由 developer 決定，不主動推薦
  - 上一個 tag 是 prerelease (e.g. `1.0.0-beta1`): 候選為 `beta2` / `rc1` / 正式版
  - 可直接帶版本號 `/ss-workflow-release 1.0.0-beta1` 跳過推薦
- 未完成工作的判定
  - 未完成 (需 developer 決定): `in-progress`、`review`、merge pending 的 request，以及未合併的 hotfix
  - 尚未開始 (`req/` branch 上的 draft、`ready`): 只列出，不阻擋 release
  - developer 的選項: 不含這些直接 release / 先完成 (根目錄切回 develop 處理，完成後回 release branch 再下一次) / 取消 release (刪除 release branch)
- 版本號檢查範圍: version-source、`src/` `samples/` `tests/` 內另外設定版本的地方 (`<AssemblyVersion>` 等用 `X.Y.Z.0`)、README / docs 內標示目前版本的地方、既有的 `CHANGELOG.md` (沒有則不建立)
- release branch 上只做 release 相關的變更 (版本號、release notes、阻擋 release 的修正)，新功能一律走 request

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
