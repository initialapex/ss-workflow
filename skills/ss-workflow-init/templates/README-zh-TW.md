[English](README.md) | 繁體中文

# {{PROJECT_NAME}}

<!-- 徽章：建置狀態、版本、授權等，確定後再加上，格式同 README.md -->

{{PROJECT_DESCRIPTION}}

<!-- 截圖或簡短的 demo GIF -->

## 功能特色

- <!-- 主要功能 1 -->
- <!-- 主要功能 2 -->

## 開始使用

<!-- Library：如何加入到專案，以及最簡單的使用範例。
     Application 或 firmware：執行所需的環境，以及下載、安裝或燒錄的方式。 -->

## 環境需求

<!-- 建置專案所需的工具與版本，見 AGENTS.md 的「Toolchain」章節。 -->

## 文件

- 專案規格：[docs/{{PROJECT_SLUG}}-spec.md](docs/{{PROJECT_SLUG}}-spec.md)
- 範例：[samples/](samples/)

## 從原始碼建置

```
{{BUILD_COMMAND}}
{{TEST_COMMAND}}
```

## 參與開發

本 repo 使用 ss-workflow 流程，所有變更都從 [`reqs/`](reqs/) 的 request 開始。開發在 `develop` 進行，版本釋出時 merge 到 `{{MAIN_BRANCH}}` 並建立 tag。branching model 與 commit 規範請見 [AGENTS.md](AGENTS.md)。

## 授權

<!-- 授權名稱與連結，e.g. MIT，見 [LICENSE](LICENSE)。 -->
