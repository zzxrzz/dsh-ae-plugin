# @dsh-external/dsh-ae-plugin

DSH × After Effects 自动化插件。随包注册 `ae-video-automation` 技能，让 AI 通过 ExtendScript 驱动 AE：建合成、做关键帧动画、加特效、渲染导出。

插件本身不提供工具（tool）面——AE 没有远程 API，可靠的自动化通道是 `ExtendScript(.jsx) + PowerShell`，由随包技能文档描述。

## 能力

- **自动定位 AE**：扫描 `Program Files\Adobe` 与注册表，找到最新的 `AfterFX.exe` 及配套 `aerender.exe`。
- **脚本执行与回读**：`run_ae_script.ps1` 负责注入 wrapper（`aeLog()` + 顶层 try/catch）、以 UTF-8 BOM 写临时 jsx、用 `AfterFX.exe -s "$.evalFile(...)"` 启动，并等待 JSON 日志回传结构化结果（`status` / `error` / `line` / `log`）。
- **规避常见坑**：自动修正 `Pref_SCRIPTING_FILE_NETWORK_SECURITY = "0"`（AE 关闭时才改）、处理部分 AE 构建 `-r` 静默退出、兼容无原生 `JSON` 对象的 ExtendScript 引擎。
- **随包知识**：`references/extendscript-api.md`（API 速查）与 `references/recipes.md`（常用配方：合成、关键帧、特效、渲染、AME 队列）。

## 环境要求

- Windows
- Adobe After Effects CC 2018+（建议较新版本）
- Node.js >= 20（DSH 宿主）
- PowerShell 5.1+

## 安装

### 方式一：DSH 插件管理器

在 DSH Desktop 的插件面板安装 `@dsh-external/dsh-ae-plugin`，安装后重启 DSH。

### 方式二：本地源码挂载（开发用）

在 DSH 的 profile（`%APPDATA%\dsh-desktop\harness\profiles\web\package.json`）里：

```json
{
  "dependencies": {
    "@dsh-external/dsh-ae-plugin": "link:C:/Users/<you>/dsh-ae-plugin"
  },
  "dsh": {
    "profile": {
      "bundles": [
        "@dsh-external/dsh-ae-plugin"
      ]
    }
  }
}
```

`cordis.patch.yml` 会在装配时插入插件行，`apply()` 时把随包技能注册进 skills 注册表（rank 600，用户自装在 `~/.dsh/skills` 的同名技能 rank 400，优先级更高）。

## 使用

安装并重启后，直接对 AI 说“用 AE 做一个 XXX 动画”即可触发 `ae-video-automation` 技能。

手动调用 helper：

```powershell
# 探测 AE 安装位置
powershell -NoProfile -File "<plugin-dir>\skills\ae-video-automation\scripts\run_ae_script.ps1" -FindAE

# 执行任务脚本
powershell -NoProfile -File "<plugin-dir>\skills\ae-video-automation\scripts\run_ae_script.ps1" -ScriptPath "D:\work\task.jsx"
```

参数：`-LogPath`（默认 `<script>.result.json`）、`-AePath`、`-KeepOpen`（渲染后保留 AE 窗口）、`-NoUI`、`-TimeoutMinutes`（默认 30）。
退出码：`0` 成功 / `1` 脚本报错 / `2` 未找到 AE 或参数错误 / `3` 超时。

## 目录结构

```
dsh-ae-plugin/
├── lib/index.js                 # 插件入口：注册随包技能
├── cordis.patch.yml             # bundle 层补丁
├── skills/ae-video-automation/
│   ├── SKILL.md                 # 技能说明（frontmatter: name/description）
│   ├── references/
│   │   ├── extendscript-api.md  # ExtendScript API 速查
│   │   └── recipes.md           # 常用任务配方
│   └── scripts/run_ae_script.ps1# AE 定位 + 执行 + 日志回读
└── package.json
```

## 打包

```bash
npm pack   # 产出 dsh-external-dsh-ae-plugin-<version>.tgz
```

## 许可

MIT，见 [LICENSE](LICENSE)。
