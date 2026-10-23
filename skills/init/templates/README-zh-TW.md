<h1 align="center">{{WORKSPACE_NAME}}</h1>

<p align="center">
  {{WORKSPACE_DESCRIPTION}}
</p>

<!-- 徽章：workspace 本身沒有版本號，各專案的版本與徽章在各自的 repo。workspace 的徽章
     (例如授權) 確定後再加上，格式同 README.md -->

<!-- 語言連結：只保留 readme-languages 列出的語言 -->
<p align="center">
  <a href="README.md">English</a> | 繁體中文
</p>

<!-- 一段話：這個 workspace 的各專案一起做什麼、給誰用。 -->

- <!-- 重點 1 -->
- <!-- 重點 2 -->

<details>
<summary>目錄</summary>

- [專案](#專案)
- [開始使用](#開始使用)
- [文件](#文件)
- [參與開發](#參與開發)
- [授權](#授權)

</details>

## 專案

每個專案都是 `projects/` 底下的 git submodule，有自己的 repo、版本與 README。

| 專案 | 路徑 | Repo | 規格 | 說明 |
|------|------|------|------|------|
{{PROJECT_ROWS}}

## 開始使用

連同各專案一起 clone workspace：

```bash
git clone --recurse-submodules <workspace URL>
```

> [!NOTE]
> 如果 clone 時沒有帶入專案，執行 `git submodule update --init --recursive`。各專案的建置方式請見它自己的 README。

## 文件

- Workspace 總覽：[docs/overview.md](docs/overview.md)
- 各專案的規格：`docs/<專案>/spec.md`，連結在[專案](#專案)
- Request：[reqs/](reqs/)

## 參與開發

> [!NOTE]
> 本 workspace 使用 ss-workflow 流程，所有變更都從 [`reqs/`](reqs/) 的 request 開始。程式碼 commit 在各專案的 repo，workspace 記錄 request 以及它們產生了哪些專案 commit。開發在 `develop` 進行，各專案各自釋出版本。branching model 與 commit 規範請見 [AGENTS.md](AGENTS.md)。

## 授權

<!-- 授權名稱與連結，e.g. MIT，見 [LICENSE](LICENSE)。 -->
