# Changelog

## v0.1.0 — 2026-11-09

首个版本：`@dsh-external/dsh-ae-plugin`

- 随包注册 `ae-video-automation` 技能，让 AI 直接驱动 After Effects
- `run_ae_script.ps1`：自动定位 AE、注入 wrapper、以 UTF-8 BOM 执行 jsx、回读 JSON 日志
- 自动修正 `Pref_SCRIPTING_FILE_NETWORK_SECURITY`，兼容无原生 `JSON` 的 ExtendScript 引擎
- 内置 ExtendScript API 速查与常用配方（合成 / 关键帧 / 特效 / 渲染导出）

安装：在 DSH 插件面板安装 `@dsh-external/dsh-ae-plugin`，或在 profile 里 link 本地目录后重启 DSH。
