# ss-workflow

這個專案主要是建立軟體開發的工作流 SKILL (不只一個)，會包含不同階段所需要的 SKILL，其中包含 Project Init, New/Check Request, Merge, Release 等等的動作，後續章節會一一介紹

## 環境設定

- 討論使用繁體中文 (zh-TW)，專有名詞保持英文
- README.md 為英文，但同步產生 README-zh-TW.md
- AGENTS 相關給 AI 看的文件使用英文
- 以上為預設，在初始化問答時，讓 developer 選擇

## 專案形式

工作流本身不相依任何一種專案形式，Visual Studio / Keil / ESP32 或其他類型都適用。

- 專案類型由 developer 在初始化時說明 (自由描述，e.g.「Visual Studio solution，old-style C# 專案，用 MSBuild 建置」、「Keil MDK-ARM」、「ESP-IDF」)
- 所有跟專案形式有關的內容，都是初始化問答的答案，記錄在專案的 AGENTS.md，plugin 不內建任何 toolchain 的範本或指令
  - Workflow settings: `project-file` (主要的 solution / workspace / build 檔)、`version-source` (版本號所在的檔案與欄位，可為 `none`)、`setup-command`、`build-command`、`test-command`、`verify-command`
  - root `AGENTS.md` 的「Toolchain」章節: 需要安裝的工具、不在 `PATH` 上的工具如何找到、已知限制
  - source 資料夾 `AGENTS.md` 的「Project rules」章節: 新檔案 / 專案如何加入 build、哪些是產生的檔案不可手改、build 輸出位置、命名慣例
  - `.gitignore` 的 toolchain 相關項目
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
    │   ├── references/      (gitflow 規則, commit 格式, request 格式)
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
- 團隊自動帶入: init 時在目標專案的 `.claude/settings.json` 寫入 `extraKnownMarketplaces` 與 `enabledPlugins`，其他成員 clone 並 trust 專案後會被提示安裝
- 專案文件版本: plugin 會自動更新，但專案內由範本產生的文件 (CLAUDE.md, AGENTS.md ...) 不會
  - init 時在 root `AGENTS.md` 記錄 `ss-workflow-version`
  - 重跑 `/ss-workflow:init` 時比對此值與 plugin 版本，較舊則 migrate 範本產生的檔案
- Migrations: 重新 render managed 區段只能帶入新的規則文字，帶不動的變更由 `skills/init/migrations/<version>.md` 處理
  - 需要 migration 檔的版本: 新增 / 改名 / 移除 Workflow settings 的欄位或可用的值、改變 request 檔格式、新增 / 搬動 / 移除產生的檔案或需要修改 managed 區段以外的文字、skill 改名、工作流行為有 developer 必須事先知道的改變
  - 只改 managed 區段內規則文字的版本不需要
  - 檔案內容: 「What changes」(行為差異，改之前 / 改之後，升級時先講給 developer 聽)、「Steps」(改哪個檔、改什麼、維持舊行為的值、是否需要 developer 回答、如何判斷已經做過)、「Check」
  - 升級順序: 從 repo 記錄的版本到 plugin 版本，依版本由低到高逐一套用 migration → 重新 render managed 區段 → 寫入新的 `ss-workflow-version` → 給 developer 看 diff 後才 commit
  - 預設值一律選「維持舊版行為」的那個；行為要不要改由 developer 決定
  - 不改寫 `## Original`，不改已回答的 `## Q&A`；已認領的 request 檔在各自的 branch 上，migration 不 checkout request branch，格式變更由下一次寫入該檔的 skill 補上
  - `tests/migrations.sh`: 範本自上一個 release tag 後有變更，卻沒有更新版本的 migration 檔時失敗

## skill: `/ss-workflow:init`

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
      - 版面: 置中的標題、描述與 badge → 語言連結 → 功能清單 → 可收合的目錄 → 各章節
      - 版本 badge 使用初始版本 (release 時由版本號檢查一併更新)；授權等尚未確定的 badge 不產生，只留註解範例
      - 程式碼區塊都標上語言 (指令依執行的 shell 選 `bash` / `powershell` / `bat`)；補充說明用 GitHub alert (`> [!NOTE]` 等)
      - 目錄要和章節一致，移除或新增章節時一併調整

### 初始化問答

以問答的方式 step-by-step 讓 developer 決定，至少包含:

- 語言設定 (見「環境設定」)，包含 reqs / docs 使用的語言
- 主分支名稱: `master` 或 `main`
- remote 平台: GitHub (`gh`) / GitLab (`glab`) / 無
- 專案類型與 toolchain (見「專案形式」): 主要專案檔、setup / build / test 指令、版本號來源、工具注意事項、專案規則、ignore 項目
- 資料夾: source 資料夾 (預設 `src/`)、是否保留 `tests/` / `samples/` / `external/`、toolchain 需要的其他頂層資料夾
- merge 方式 (`merge-method`): 每次詢問 / local merge / 發 merge-request
- push 方式 (`push-policy`): `auto` (預設) / `ask` / `never`，見「Remote 與 push」
- 現有專案: 說明轉換的方法，由 developer 確認或答覆需調整的部分

問答結果記錄在 root `AGENTS.md` 的 Workflow settings，另有兩個選填的欄位，init 不詢問，由 developer 需要時自行填入:

- `verify-command`: `/ss-workflow:review` 在 build 與測試之後額外執行的驗證 script
- `agent-files`: 內建清單以外、會影響 agent 行為的檔案路徑 (glob，逗號分隔)，e.g. 產品內附的 prompt 檔，見「如實回報與 agent 行為檔」

轉換既有專案時，是否把程式碼搬進標準結構由 developer 決定；許多 toolchain 依賴檔案位置，這時可以選擇「維持現有結構」，只加入工作流需要的檔案

### 檔案結構

`reqs/`、`docs/` 與 agent 檔案是工作流必要的部分；程式碼相關的資料夾依初始化問答決定，以下為預設的標準結構:

```
repo/
├─ CLAUDE.md
├─ AGENTS.md
├─ README.md
├─ README-zh-TW.md
├─ .gitignore
├─ .claude/
│   └── settings.json        (extraKnownMarketplaces, enabledPlugins)
├─ src/ (Source Code 目錄，名稱可在初始化時調整)
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   ├── <主要專案檔>          (e.g. Visual Studio 的 .sln；依專案形式而定，可能沒有)
│   ├── project1-folder/
│   │   ├── README.md
│   │   └── <專案檔與原始碼>
│   ...
│   └── projectX-folder/
│       ├── README.md
│       └── <專案檔與原始碼>
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
├─ tests/ (自動化測試，可選)
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   └── <test-project>-folder/
├─ samples/ (Sample/Demo Project 目錄，可選)
│   ├── CLAUDE.md
│   ├── AGENTS.md
│   └── <demo-project>-folder/
```

#### 根目錄

根目錄 `CLAUDE.md` / `AGENTS.md` 去限制整個 repo 內的工作流運作，並註記每個資料夾內運作的規則 (含 gitflow、commit 規範、`ss-workflow-version`)；在 repo 初始化的時候，會以問答的方式 step-by-step，讓 developer 完成檔案內所需的資訊。若是現有的專案，了解現有專案的架構後，與 developer 問答轉換的方法是否可接受，若需要調整的部分，developer 需要自行答覆

- build 輸出資料夾 (e.g. `bin/`) 若放在此，要加入 `.gitignore`
- `.gitignore` 包含 ss-workflow 需要的項目 (`.claude/worktrees/` 等)，以及初始化問答決定的 toolchain 項目；已有 `.gitignore` 時保留並補上缺少的項目
- 版本號只放在 `version-source` 一處，release 時只需修改一處；toolchain 若強制要有第二個位置，記錄在「Toolchain」章節

#### src

放置專案檔案，底下會有自己的 `CLAUDE.md` / `AGENTS.md`
每個專案 (或模組) 都要有描述自己的 `README.md`

- 主要專案檔預設放在 source 資料夾內，與各專案資料夾同一層 (e.g. Visual Studio 的 `.sln` 放在 `src/`，符合它原本的階層設計)
- `AGENTS.md` 分成兩部分: 通用規則 (由工作流維護)，以及「Project rules」(初始化時依專案形式寫入，之後由 developer 維護)

#### reqs

整個工作流最主要的核心資料夾。每個 request 只有一個 `.md` 檔，不另外建立資料夾，也沒有 `STATUS.md`。

- 各階段在哪裡進行 (根目錄 = repo 的主要 checkout，平常停在 develop):

| 階段 | 位置 | skill |
|------|------|-------|
| 規格討論 | 根目錄，`req/REQ-xxxx-<slug>` branch | `/ss-workflow:new-req` |
| 實作 | worktree，request branch | `/ss-workflow:check-req` |
| Verify (跑 build / Test 專案 / script) 與 Review (人工驗證) | 根目錄，checkout request branch | `/ss-workflow:review` |
| 結案 (merge) | 根目錄 | `/ss-workflow:merge` |

  - 在 worktree 上跑 script 或執行檔的限制較多，所以 worktree 只寫程式並嘗試編譯，不跑測試、script、執行檔
  - AI 完成實作後直接刪除 worktree，但保留 branch；request 停在 `review` 狀態，由 developer 觸發 `/ss-workflow:review` 才開始 Verify 與 Review
  - developer 執行 `/ss-workflow:merge` 就算結案
  - 根目錄一次只能做一件事 (規格討論 / review / merge / release)；skill 切換根目錄的 branch 前，先確認它在 develop 且沒有未 commit 的變更，完成後切回 develop

- 檔名: `REQ-<4 位流水號>-<yyyyMMdd>-<slug>.md`，e.g. `REQ-0012-20260907-gui-button.md`
  - 流水號取「使用中的最大號 + 1」；使用中 = develop 上 `reqs/` 與 `reqs/done/` 的檔案，以及 local / remote 上名稱含該編號的 branch (`req/REQ-0012-…`、`feat/REQ-0012-…`)
- 未完成的 request 放在 `reqs/`；完成 (`done`) 後由 `/ss-workflow:merge` 以 `git mv` 移到 `reqs/done/`
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

## Q&A
(問過 developer 的問題與回答，依發問順序記錄，只增不改)

## Notes
(Assumption、implementation summary、行為變更、Verify / code review / Review 結果，都帶日期)
```

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
  - 沒有 pending 的紀錄，request 才能變成 `ready` (取代 Spec 內的 Open questions)

- 狀態流程:

| status        | 意義                                         | 該狀態的檔案在哪個 branch            | 誰設定 |
|---------------|----------------------------------------------|--------------------------------------|--------|
| `draft`       | 規格討論中                                   | `req/REQ-…` branch (根目錄)          | `/ss-workflow:new-req` |
| `ready`       | developer 確認規格，等待認領                 | develop (`req/` branch merge 之後)   | `/ss-workflow:new-req` |
| `in-progress` | 已認領，在 worktree 實作中                   | request branch                       | `/ss-workflow:check-req` |
| `review`      | 實作完成、worktree 已刪除、branch 保留；等待或正在 Verify 與 Review | request branch | `/ss-workflow:check-req` 設定，`/ss-workflow:review` 處理 |
| `done`        | 已關閉，檔案在 `reqs/done/`                  | request branch 的最後一個 commit (merge 前) | `/ss-workflow:merge` |

- draft 只存在 `req/` branch 上，develop 上只有 developer 確認過的 request
- 有效狀態: develop 上的檔案在 merge 前一直顯示 `ready`；request branch 上的檔案才是目前的狀態 (`in-progress` / `review` / `done`)
- 認領 (lock):
  - 「建立 request branch」就是認領: 從 develop 建立 `<type>/REQ-<id>-<slug>`
    - 同一個 repo 內，git 保證同名 branch 只能建立一次，兩個 local session 不會同時成功；這一層不需要 remote
    - 跨機器時，單純 push branch 還分不出先後 (兩邊 push 的是同一個起始 commit，remote 都會接受)；由認領 commit 的 push 決定，remote 只接受第一個，另一邊放棄自己的 branch
    - 沒有 push 時 (沒有 remote、`push-policy: never`、developer 拒絕)，認領只在這個 repo 內有效；之後 push 被拒絕表示別台機器已認領，不強推，由 developer 決定保留哪一邊
  - 該編號的 branch 已存在 (local 或 remote) = 已被認領
  - branch 上的第一個 commit 將 status 改為 `in-progress` 並寫入 `branch`
  - 認領不需要根目錄在 develop，所以根目錄正在討論規格或 review 時，其他 session 仍可認領
- 同步到 remote (依「Remote 與 push」，允許 push 時才做):
  - 建立 branch 後立即 `git push -u`，實作過程中每次 commit 都 push
  - 刪除 worktree 前確認沒有未 commit 的變更；允許 push 時另外確認沒有未 push 的 commit，不 push 時確認 commit 都在本機 branch 上，並在回報中列出尚未 push 的 commit
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
- 專案沒有可由指令執行的自動化測試時，不需要此資料夾 (在初始化問答的時候提問)

#### samples

- 若是專案為 library，會建立 sample / demo 專案，展示如何使用 library，也是一種 GUI 測試

## skill: `/ss-workflow:new-req`

建立新需求使用，使用者可利用此 skill + .md file 建立新需求，也可單獨輸入此 skill，skill 會引導建立 new request

- 在根目錄執行 (不在 worktree)；根目錄必須在 develop 且乾淨，或已在某個 `req/` branch 上 (接續該 draft)
- 從 develop 開 `req/REQ-<id>-<slug>` branch 並立即 push (同時占住流水號)，在上面建立 `status: draft` 的 request 檔 (若提供 .md，原文放入 `## Original`)
- 與 developer 討論細部的需求規格，寫入 `## Spec`；每一輪討論後 commit + push
  - Spec 內含 Goal / Scope / Architecture / Acceptance criteria / How to verify (每項標明由 Verify 自動檢查或 Review 人工檢查) / Out of scope
  - 每一輪問過的問題與回答寫入 `## Q&A`；還沒有答案的寫 `A: (pending)`，不另外放 Open questions；有 pending 時不能 Approve
  - 開工前要講定的範圍: developer 或使用者看得到、用得到的東西 (UI、指令、檔案格式、對外 API，寫在 Scope)，以及軟體架構 (寫在 Architecture: 新增或修改的模組 / 元件、各自的責任、呼叫關係、資料流、重要的資料結構與狀態、新的相依)；更細的實作細節留給實作，除非 developer 想談
  - Architecture 不可省略: 不需要架構決定的變更也要用一句話寫明，並指出放在既有結構的哪裡；由 AI 依現有程式碼提出，有多種合理結構時列出取捨並推薦，由 developer 確認
  - `## Original` 只有需求或困擾、沒有做法時先探索: 先問問題本身 (誰需要、現在怎麼做、哪裡不好、有什麼限制)，再提出兩到三個做法 (對使用者如何運作、架構概要、影響範圍、代價與風險) 並推薦一個，developer 選定後才起草 Spec
  - developer 答不出來時: AI 提出預設值與理由，developer 接受後寫入 Spec、補完該筆 `## Q&A`，並在 `## Notes` 記為 Assumption，留待 Review 再確認；不自行默默決定
  - 只有別人能回答、或 developer 想晚點再答的問題，以 `A: (pending)` 留在 `## Q&A`，request 維持 draft
  - 接續舊版的 draft 時: 補上 `## Q&A` 區段，把 Spec 內的 Open questions 逐項轉成 pending 的紀錄；`## Notes` 內既有的決策不回頭改寫成 Q&A
- developer 確認規格沒有問題後，將 status 改為 `ready`，把 `req/` branch `--no-ff` merge 回 develop 並刪除該 branch；之後由其他 session 認領
  - `merge-method` 為 `remote` 或 develop 不允許直接 push 時，改發 merge-request；remote 沒有可發 merge-request 的平台時，保留 `req/` branch 並停止，告知 developer 需要在 remote 上 merge
  - 保留 draft: commit + push 後根目錄切回 develop，`req/` branch 留著；之後用 `/ss-workflow:new-req REQ-xxxx` 接續
  - 捨棄: 刪除 `req/` branch，develop 上不留任何痕跡
- 一個 `req/` branch 只處理一個 request；輸入包含多個可獨立實作的需求時，提議拆開並依序處理；與既有 request 重複時先提醒
- 此 skill 只寫 request，不實作
- 支援 `type: hotfix` 作為 hotfix 的入口 (hotfix branch 規則見 `/ss-workflow:merge`)，規格討論一樣走 `req/` branch 並 merge 回 develop

## skill: `/ss-workflow:check-req`

只負責總覽、認領與實作；Verify 與 Review 由 `/ss-workflow:review` 處理

- 在根目錄執行 (根目錄在哪個 branch 都可以，不需要切到 develop): 總覽 + 認領
  - 不 checkout 任何東西，透過 `<develop-ref>` 與各 branch 讀取 request 檔
    - `<develop-ref>`: 無 remote 時為 `develop`；有 remote 且本機 develop 沒有自己的 commit 時為 `origin/develop`；本機 develop 領先時為 `develop` (並提醒其他機器還看不到)；兩邊各有對方沒有的 commit 時以 `develop` 為主、另外讀 `origin/develop` 才有的 request，提醒 developer 先同步，且不認領只有一邊有的 request
  - 總覽包含: `req/` branch 上的 draft、develop 上的 request、每個 request 的有效狀態 / branch / worktree
  - 若發現異常 (e.g. branch 已建立但沒有認領 commit、`review` 狀態卻還留著 worktree、有 commit 沒 push)，先排除異常再認領
  - 若有多個 `ready` 的 request，依 `priority` 排序後讓 developer 選擇
  - 認領: `git worktree add -b <branch> <path> <develop>` 一次建立 branch 與 worktree，push，再做認領 commit (見 reqs 章節)；之後在 worktree 上實作 (為了多 session 平行實作多個 request)
  - worktree 路徑: `.claude/worktrees/<branch 名稱，"/" 換成 "-">`，e.g. `.claude/worktrees/feat-REQ-0012-gui-button`
  - 不主動接手別的 `in-progress` request (可能有其他 session 正在實作)，需 developer 同意
  - `in-progress` 但沒有 worktree (被 review 退回，或 worktree 遺失): developer 同意後重建 worktree 繼續實作
  - 根目錄停在 `in-progress` / `ready` 的 request branch 上 (退回重做或認領被中斷後沒切回 develop，或手動 checkout): git 不允許為根目錄所在的 branch 建立 worktree，所以先確認根目錄沒有未 commit 的變更，developer 同意後把根目錄切回 develop，再重建 worktree
- 在 request worktree 上執行: 表示要再啟動實作
  - `in-progress`: 找出上次停在哪裡 (含 `## Notes` 內的 review feedback)，繼續實作
  - `review` / `done`: 實作已完成，這個 worktree 不該存在；確認沒有遺漏後刪除，並提示下一步
- 實作原則
  - 只在 request 的 worktree 內修改，不改根目錄的檔案、不切換根目錄的 branch (唯一例外: 上述 developer 同意的修復，把根目錄切回 develop)
  - worktree 內只嘗試 `setup-command` (需要時) 與 `build-command` (編譯)，不跑測試 / script / 執行檔 / 燒錄；`build-command` 留空或環境限制導致無法 build 時不算失敗，記錄在 `## Notes` 留給 Verify
  - 動手前先讀 root `AGENTS.md` 的「Toolchain」與 source 資料夾的「Project rules」；新檔案要依「Project rules」加入 build
  - 依 Spec 的 Architecture 實作，不自行更改架構；Spec 沒有 Architecture 時先提出並由 developer 確認；implementation summary 註明架構是否照 Spec
  - 規格不清楚或有誤時停下來問，不自行猜測；問題與回答寫入 `## Q&A` (階段 `implementation`)，規格異動要更新 `## Spec`；session 結束前還沒有答案時留 `A: (pending)`
  - 每個 commit 帶 `Refs: REQ-xxxx` 並 push；測試程式照寫但不執行；acceptance criteria 不在這裡打勾 (Verify / Review 實際檢查後才打勾)
  - 交付前: 把 develop 的新 commit merge 進來 (不 rebase)、自己讀一次 diff、在 `## Notes` 寫 implementation summary
    - 固定欄位: What changed / Architecture / Ran in the worktree (實際跑過的指令與結果) / Did not run (沒跑的與原因) / Not done (沒做完的 criteria 或規格) / Verify / Review by hand / Follow-ups
    - 每一行都依實際發生的事寫，不依預期寫；沒有的欄位寫 "none"，不省略
    - 動到 agent 行為檔時另外寫 `### Behavior changes` (見「如實回報與 agent 行為檔」)
  - 交付: status 改為 `review` 並 push → 確認沒有未 commit / 未 push 的內容 → 刪除 worktree、保留 branch → 提示 `/ss-workflow:review REQ-xxxx`
- hotfix request
  - branch 為 `hotfix/v<version>`，從 master 開，一樣在 worktree 實作
  - master 上沒有 request 檔，所以認領 commit 會把 request 檔從 develop 複製到 hotfix branch，之後狀態都記在 hotfix branch 上

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
  2. 根目錄 checkout request branch，並把 develop (hotfix 為 master) 的新 commit merge 進來
  3. Verify: 依序執行 `setup-command` (需要時)、`build-command`、`test-command`、`verify-command`、request 內指定的 script (留空的指令略過並記為「未設定」；build 與 test 都未設定時要明講 Verify 沒有自動檢查任何東西)；能由這些檢查證明的 acceptance criteria 打勾；結果寫入 `## Notes`
  4. Code review (可選): Verify 通過後詢問 developer 是否執行；以 `<base>...<branch>` (有 remote 時 base 為 `origin/develop`，hotfix 為 master) 為範圍呼叫 Claude Code 的 `code-review` skill，只檢查這個 request 的變更
     - 不帶範圍不可執行: `/code-review` 預設只看尚未 push 的 commit，而這個工作流每個 commit 都會 push
     - 發現的問題先對照程式碼確認: 小問題當場修 (修完重跑 Verify)、大問題提議退回、不屬於這個 request 的記為 follow-up、不確定的交給 developer 決定
     - 結果 (含 skipped / not available) 寫入 `## Notes`；不打勾 acceptance criteria；不帶 `--fix` / `--comment`
     - 無法呼叫時不以自行讀 diff 代替；雲端的 `ultra` 只能由 developer 自己輸入，skill 只列出指令
     - Review 期間 developer 也可以隨時要求執行
  5. Review: 列出需要人工確認的項目，以及每一項怎麼檢查 (要啟動哪個 sample / 執行檔、操作步驟、預期結果)；developer 要求時可代為啟動程式
  6. 詢問結果
     - Review 通過: 其餘 criteria 打勾、記錄結果、根目錄切回 develop，提示 `/ss-workflow:merge REQ-xxxx` 結案
     - 小修: 直接在根目錄的 request branch 上修正並 commit，重跑 Verify
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
    - 檢查時機 (`git status --porcelain`，含 untracked 檔案): 接續 review 時、每次 Verify 前、code review 前、處理結果前
    - 清單上每一項都要由 developer 決定，不留未決定的，也不 commit developer 沒看過的: 屬於 request (commit 成 `fix:` 等一般 commit，含新增的檔案，並在 `## Notes` 記「Changed by the developer」)、產生的或本機檔案 (加入 `.gitignore`，另一個 `chore:` commit)、不要的 (developer 確認後捨棄)、先留著繼續試
    - 沒有「先留著」的項目時用 `git add -A`，否則依路徑 stage；記錄結果的 commit 只 stage request 檔
    - 先留著的期間: Verify 可以跑但不算數 (記錄註明含未 commit 的修改)、code review 不涵蓋、不能選「Review 通過」或「需要大改」
    - Verify 只有在乾淨的工作目錄上跑才算數；最後一次 Verify 之後有改到 `reqs/` 以外檔案的 commit 時，要重跑 Verify 才能記 Review 通過
    - 切回 develop 前 `git status --porcelain` 必須是空的 (含 untracked)

## skill: `/ss-workflow:merge`

本工作流 git 遵循 gitflow 流程，有不同形態的 branch (worktree)
若發現有 remote 端: e.g. github, gitlab，讓使用者選擇是否要發 merge-request 到 remote，由 remote 端 merge；對應到此，在 merge 之前都要先去 fetch remote，先用 `git merge-base --is-ancestor` 檢查 (任何 remote 都適用)，有平台時再用 `gh pr view` / `glab mr view` 檢查，因為有可能是已經發過 merge-request，也合併完了
沒有 remote 時，local merge 就是完整的 merge，所有 pull / push 步驟略過；有 remote 但不是 GitHub / GitLab 時 (`remote-platform: none`)，一律 local merge 後 push
合併完成後，刪除 local / remote branch (worktree 在實作完成時就已刪除，若有殘留一併清除)
刪除前一定要先確認已合併 (`git merge-base --is-ancestor` 或 merge-request 狀態)；`git branch -d` 不能當安全檢查，已 push 但未 merge 的 branch 它只給 warning 就會刪除
對 request 而言，developer 執行此 skill 就代表驗收通過、結案

- 共通規則
  - 在根目錄執行 (不在 worktree)；會在 target branch / develop / master 之間切換，結束時停在 develop
  - request 的 `## Notes` 內沒有通過的 Review 或 Verify 結果時先提醒，由 developer 決定先跑 `/ss-workflow:review` 或直接 merge；最後一次 Verify 有 `failed` / `did not run`、有未確認的行為變更、`## Q&A` 有 pending 時也一樣提醒；developer 決定直接 merge 時，問題與回答寫入 `## Q&A`
  - 發 merge-request 需要 branch 已在 remote 上；不能 push 時做完 Prepare 就停止，告知 developer 要 push 哪個 branch
  - remote 拒絕 push 到受保護的 develop / master 時不繞過: 還原尚未發佈的 local merge commit，有平台改發 merge-request，沒有平台就停止並告知 developer 需要在 remote 上 merge 什麼 (request 為 merge pending)
  - 刪除 remote branch 只在允許 push 時進行，否則在回報中列出
  - `req/` branch 不由此 skill 處理 (由 `/ss-workflow:new-req` 在規格確認時 merge)
  - merge 方式由 Workflow settings 的 `merge-method` 決定: `local` (local merge 後 push) / `remote` (發 merge-request) / `ask` (每次詢問，預設)
  - 一律 `--no-ff`，不 squash、不 rebase 已 push 的 branch、不 force-push
  - merge commit message: `Merge <source> into <target>` (不套用 `<type>(<scope>)` 格式)，body 帶 request title 與 `Refs: REQ-xxxx`
  - 根目錄有未 commit 的變更，或正忙著別的事 (在 `req/` branch 或其他 request branch 上) 時停止
  - remote 上的 merge-request 狀態: 已合併 → 直接收尾；開啟中 → 詢問要等待或改用 local merge；已關閉 → 詢問
  - 選擇發 merge-request 時，skill 發完就把根目錄切回 develop 並停止；remote 合併後 developer 再下一次 `/ss-workflow:merge` 收尾 (刪除 branch)
  - 放棄 request: 透過一個短暫的 `req/REQ-<id>-drop` branch 把 request 標為 `done` 並註明原因，merge 回 develop；request branch 有未合併的 commit，需另外確認才刪除

- request
  - 所有 reqs 都在 develop 開分支出去，完成後 merge 回 develop
  - request branch(worktree)種類可能會有: feat, fix, docs ... 等類型
  - branch(worktree) name 範例: `feat/REQ-0012-gui-button`
  - request 實作都開在 worktree 實作；merge 時 worktree 已刪除，全程在根目錄 checkout request branch 進行
  - 只 merge 有效狀態為 `review` 的 request
  - merge 前先把 develop 的新 commit merge 進 request branch，在 branch 上解衝突；有 merge 進新 commit 時重新跑 build + test (+ `verify-command`)
  - 關閉 request (status 改為 `done`、`git mv` 到 `reqs/done/`) 是 request branch 上的最後一個 commit，隨著 merge 一起進 develop
    - 發 merge-request 的情況下，branch 上為 `done` 但尚未合併 = 「merge pending」；remote review 要求修改時，下 `/ss-workflow:review REQ-xxxx` 重新開啟並繼續 review

- release
  - 會從 develop 開分支出去，完成後 merge 回 master 與 develop
  - branch name 範例: release/v1.0.0-beta1
  - 不開 worktree
  - 合併回 master 後，依照 branch name 建立 tag: e.g. v1.0.0-beta1
  - merge 前檢查: version-source 的版本與 branch 相符、tag 尚未存在、build + test 通過
  - push master 與 tag 等於對外釋出，不論 `push-policy` 為何，push 前都再確認一次，並用 `git push --atomic` 一次推送 master / develop / tag；`push-policy: never` 時不 push，只列出指令由 developer 執行
  - 完成後可選擇是否在平台上建立 release (`gh release create` / `glab release create`)
  - release 流程使用 `/ss-workflow:release`

- hotfix
  - 會從 master 開分支出去，完成後 merge 回 master 與 develop
  - branch name 範例: hotfix/v1.0.1
  - 開 worktree 實作 (由 `type: hotfix` 的 request 經 `/ss-workflow:check-req` 認領)，Verify / Review / merge 一樣在根目錄
  - 合併回 master 後，依照 branch name 建立 tag: e.g. v1.0.1
  - merge 回 develop 時 version-source 衝突，保留較高的版本 (通常是 develop 的)
  - 若有進行中的 release branch，詢問是否也 merge 進去
  - request 檔在 hotfix branch 上關閉 (認領時已從 develop 複製過來)；merge 回 develop 時用 `--no-commit`，在同一個 merge commit 內刪除 develop 上仍為 `ready` 的舊副本

- master (持續存在)
  - 主要是在有新版要釋出時，才會有新的 commit
  - 例外: v1.0.0 釋出之前為快速疊代期，允許 develop 直接 merge 到 master，並建立 `v0.x.y` tag (由 `/ss-workflow:merge` 的 pre-1.0 sync 處理，僅在 developer 要求時執行)

- develop (持續存在)
  - 主要是開發 branch，所有變動大部分都會在這邊

## skill: `/ss-workflow:release`

- 若 developer 在 develop branch 使用此 skill，則表示想釋出新版本
  - 檢查適合的版本號推薦給使用者 (依上一個 tag 與 develop 上的 commit type)，使用者同意後，從 develop 建立 release branch
  - release branch 建立後，檢查是否有未完成需求 (`reqs/` 下非 `done` 的 request)、未完成 worktree；若有未完成，讓 developer 決定是否 release?
    - 若不同意，先處理完需求， developer 要在 release branch 再下一次此 skill
  - 若同意 release ，則去檢查 `version-source` (以及「Toolchain」章節列出的其他位置、source / samples / tests 內另外設定版本的地方) 的版本號是否與 release branch 相符
    - 若不相符作相對應的修改並 commit
  - 若相符則直接啟用 release merge 規則 (見 `/ss-workflow:merge`)
- 若在 release branch 上使用此 skill，表示接續先前的 release
  - develop 有 release branch 沒有的 commit 時 (e.g. 剛完成的 request)，詢問是否納入這次 release
- 一次只進行一個 release；已有 release branch 時不再建立新的
- 版本號格式: `vX.Y.Z-{alpha/beta/rc}{R}`
  - X / Y / Z (MAJOR / MINOR / PATCH) 為 0 到 99 的整數，最多兩位數，不補零
  - 正式版本沒有後綴: `v1.0.0`；prerelease 使用後綴，階段只有 `alpha` / `beta` / `rc`，R 從 1 開始、直接接在階段後面: `v1.0.0-alpha1`、`v1.0.0-beta2`、`v1.0.0-rc1`
  - 同一個 X.Y.Z 的順序: `alpha` < `beta` < `rc` < 正式版；同階段依 R 的數值比較 (`alpha2` < `alpha10`)，不以文字比較
  - 階段不回頭: 出過 `rc1` 之後，同一個 X.Y.Z 不再有 `beta3`
- 版本號推薦規則
  - 要遞增的位數已經是 99 時: 改推薦進位到上一位 (`1.4.99` → `1.5.0`) 並說明原因；MAJOR 已是 99 時沒有合法的下一版，交給 developer 決定
  - 尚無 tag (第一次 release): 使用 version-source 目前的版本
  - 1.0.0 以上: breaking → MAJOR、`feat` → MINOR、其他 → PATCH
  - 1.0.0 以下: breaking 與 `feat` → MINOR、其他 → PATCH；升到 1.0.0 由 developer 決定，不主動推薦
  - 上一個 tag 是 prerelease (e.g. `1.0.0-beta1`): 候選為同階段的下一個 (`beta2`) / 下一階段的第一個 (`rc1`) / 正式版
  - 上一個 tag 是正式版: 推薦正式版，另提供 prerelease 作為替代，階段由 developer 選擇 (`alpha1` / `beta1` / `rc1` 都可以)
  - 可直接帶版本號 `/ss-workflow:release 1.0.0-beta1` 跳過推薦
- 未完成工作的判定
  - 未完成 (需 developer 決定): `in-progress`、`review`、merge pending 的 request，以及未合併的 hotfix
  - 尚未開始 (`req/` branch 上的 draft、`ready`): 只列出，不阻擋 release
  - developer 的選項: 不含這些直接 release / 先完成 (根目錄切回 develop 處理，完成後回 release branch 再下一次) / 取消 release (刪除 release branch)
- 版本號檢查範圍: version-source、「Toolchain」章節列出的其他位置、source / samples / tests 內另外設定版本的地方、README / docs 內標示目前版本的地方、既有的 `CHANGELOG.md` (沒有則不建立)
  - 版本號的寫法依專案形式而定，沿用該欄位原本的格式 (e.g. 只能放四段數字的欄位寫成 `X.Y.Z.0`)
  - `version-source` 為 `none` 時不改檔案，版本只以 git tag 表示
- release branch 上只做 release 相關的變更 (版本號、release notes、阻擋 release 的修正)，新功能一律走 request

## Remote 與 push

此章節的規範會寫入專案 root `AGENTS.md` (「Remote and pushing」)，各 skill 的「push」都依此判斷

- 工作流不需要 remote。有沒有 remote 看 `git remote` 是否有 `origin`；`remote-platform` 只表示能不能發 merge-request (`github` / `gitlab`)，其他 remote 與沒有 remote 都是 `none`
- 沒有 remote: 所有 fetch / pull / push 步驟略過；本機 `develop` 代表 `origin/develop`、建立本機 branch 就是認領、branch 一律 local merge
- 有 remote: 由 `push-policy` 決定 agent push 什麼

| `push-policy` | agent 的行為 |
|---------------|--------------|
| `auto` (預設) | 每次 commit 後 push topic branch (`req/*`、request、`hotfix/*`、`release/*`)；developer 要求 merge 之後 push develop |
| `ask` | 只在本機 commit；每次執行 skill 第一次要 push 前詢問，同意後該次執行都適用，拒絕則該次視同 `never` |
| `never` | 不 push、不刪除 remote branch；仍會 fetch 與 pull |

- 沒有 push 時 skill 繼續進行，並在回報中列出尚未在 remote 上的 branch 與 tag；在 developer push 之前，其他機器看不到這些 request、認領與狀態變更
- 不論 `push-policy` 為何都成立:
  - 不 force-push、不改寫已發佈的歷史
  - push master 或 tag 等於釋出，每次 push 前都要詢問 developer
  - 確認已 merge 之前不刪除 branch (local 與 remote)；有未合併 commit 的 branch 只有 developer 針對該 branch 明確同意才刪除
  - remote 拒絕 push 到受保護的 branch 時不繞過
- 取捨 (自動 push 與 never push 的比較):
  - 自動 push: 跨機器認領可靠、其他 session 即時看到狀態、每個 commit 都有備份、可直接發 merge-request；代價是誤 commit 的內容立刻外流且收不回、每次 push 都觸發 CI
  - never push: agent 無法對外發佈任何東西；代價是認領只剩本機鎖、其他機器看到的狀態落後、merge-request 要先由人 push
  - 兩者沒有絕對的好壞，所以做成設定；預設 `auto` 是因為原本的設計就已經分層 (自動 push 的只有 topic branch，develop 在 developer 下指令後才 push，master 與 tag 一律再確認)

## 如實回報與 agent 行為檔

此章節的規範會寫入專案 root `AGENTS.md` (「Working agreement」) 與 `reqs/AGENTS.md` (「Results and behavior changes」)

- 如實回報: 每一份回報與寫入 request 的結果，都要講明什麼有跑且通過、什麼有跑但失敗、什麼沒跑以及原因；沒跑的檢查不能回報為通過，「應該會過」也不算
- Agent 行為檔: agent 當作指示來讀的檔案
  - 內建清單: `AGENTS.md`、`CLAUDE.md`、`.claude/` 底下的檔案 (不含 `.claude/worktrees/`)、`SKILL.md` 與同資料夾內的檔案
  - 專案自訂: Workflow settings 的 `agent-files`
- 改一行 agent 行為檔就是改變 agent 的行為，build 與測試都看不出來，所以動到這類檔案的 request 必須在 `## Notes` 附 `### Behavior changes`，每個檔一項:
  - Diff: 修改的原文 (太長時改附可重現的指令 `git diff <base>...<branch> -- <path>`)
  - Before / After: 用白話描述行為，不是描述修改本身 (e.g. 「Before: 每次 commit 後都 push。After: 第一次 push 前先詢問」)
  - 不影響行為的修改 (錯字、沒有人查找的標題) 也要列出並明講不影響行為
- 由實作 session 撰寫；Verify 無法證明，所以每一項都由 developer 在 Review 確認；缺漏時由 `/ss-workflow:review` 依 diff 補寫

## Git commit

此章節的規範會寫入專案 root `AGENTS.md`，所有 commit 都需遵守，不只在執行 skill 時

### commit 原則

- 在實作的過程中，可以一直 commit，讓每一次變動可以看得出為什麼而變動，而不是一大堆的檔案一起包在同一個 commit 上
- request branch 上的 commit 每次都 push 到 remote (允許 push 時，見「Remote 與 push」)

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
