<h1 align="center">{{PROJECT_NAME}}</h1>

<p align="center">
  {{PROJECT_DESCRIPTION}}
</p>

<p align="center">
  <img alt="Version {{INITIAL_VERSION}}" src="https://img.shields.io/static/v1?label=version&message={{INITIAL_VERSION}}&color=blue">
  <!-- 其他徽章（建置狀態、授權等）確定後再加上，格式同 README.md -->
</p>

<!-- 語言連結：只保留 readme-languages 列出的語言 -->
<p align="center">
  <a href="README.md">English</a> | 繁體中文
</p>

<!-- 截圖或簡短的 demo GIF，例如：
<p align="center"><img alt="Screenshot" src="docs/images/screenshot.png" width="720"></p>
-->

<!-- 一段話：這個專案做什麼、給誰用。 -->

- <!-- 主要功能 1 -->
- <!-- 主要功能 2 -->

<details>
<summary>目錄</summary>

- [開始使用](#開始使用)
- [環境需求](#環境需求)
- [文件](#文件)
- [從原始碼建置](#從原始碼建置)
- [參與開發](#參與開發)
- [授權](#授權)

</details>

## 開始使用

<!-- Library：如何加入到專案，以及最簡單的使用範例。
     Application 或 firmware：執行所需的環境，以及下載、安裝或燒錄的方式。
     每個程式碼區塊都標上語言。 -->

## 環境需求

<!-- 建置專案所需的工具與版本，見 AGENTS.md 的「Toolchain」章節。 -->

## 文件

- 專案規格：[docs/{{PROJECT_SLUG}}-spec.md](docs/{{PROJECT_SLUG}}-spec.md)
- 範例：[samples/](samples/)

## 從原始碼建置

<!-- 語言標記依執行這些指令的 shell 而定：bash、powershell 或 bat。 -->

```bash
{{BUILD_COMMAND}}
{{TEST_COMMAND}}
```

## 參與開發

> [!NOTE]
> 本 repo 使用 ss-workflow 流程，所有變更都從 [`reqs/`](reqs/) 的 request 開始。開發在 `develop` 進行，版本釋出時 merge 到 `{{MAIN_BRANCH}}` 並建立 tag。branching model 與 commit 規範請見 [AGENTS.md](AGENTS.md)。

## 授權

<!-- 授權名稱與連結，e.g. MIT，見 [LICENSE](LICENSE)。 -->
