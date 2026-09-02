# MeoKDE

MeoKDE 是 MeoArch 的 KDE Plasma 6 原生集成仓库：Shell、Plasmoid、主题、默认配置、KDE/Qt 原生桥接和 Arch 打包定义都在这里。通用 MD3 QML 组件和 token 由相邻的 `meo-ui` 提供；MeoKDE 不复制它们。

## 目录 / Layout

- `qml/`、`plasmoids/`：MeoKDE QML 模块与 Plasma 原生界面。
- `widgets/`：受版本控制的上游 Widget 白名单、适配契约与验收测试；只包含可由 MeoUI 统一换皮的 Plasma Widget 集成入口。
- `third_party/`：固定版本的上游源码依赖；`kde-plasma6-widgets` 是保留 GPL-3.0 来源和历史的 Git submodule，不是打包输入的默认目录。
- `native/`：C++/Qt/KDE 平台桥接、独立 Layer Shell Dock 与原生样式。
- `themes/`、`defaults/`、`icons/`、`assets/`：主题、默认值和受版本控制的源资源。
- `setup/`、`scripts/`、`tools/`：受维护的安装、验证、同步与生成工具源码。
- `tests/`、`validation/`、`showcase/`：版本控制的测试、验证源码和展示输入，不是运行产物目录。
- `docs/`：与代码绑定的 Shell、主题、输入法和公开行为契约。
- `packaging/`：可发布的打包定义。
- `build/`、`out/`、`artifacts/`：既有构建/验证内容，不能作为新输出入口；已归档的迁移说明位于该项目的 Obsidian `99-archive/`。
- `.git/`、`.gitignore`：版本控制元数据和忽略规则。

根目录只新增入口文档、源码目录及必要的构建/发布配置。禁止新增零散计划、架构草稿、审计副本、Agent 日志、截图或输出日志。已有的 `build/`、`out/`、`artifacts/` 等历史内容在审阅迁移前保持不动；以后不再作为新输出的目的地。

## 文件与记录边界 / File policy

只有需要随已交付代码维护的公共契约可留在 `docs/`。计划、审计、决策记录、Agent 工作日志和历史报告放在：

`/home/shekong/Documents/Obsidian Vault/MeoArch/Projects/meo-kde/`

该记录目录必须有便于阅读的 `README.md` 索引；不要在仓库中保存同一份过程记录。

记录目录使用统一的编号结构：`00-inbox/`（临时收集）、`01-overview/`（范围与事实）、`02-decisions/`（已确认决定）、`03-work/`（计划和交接）、`04-validation/`（验证结论）和 `99-archive/`（已替代记录）。项目根 `README.md` 是人类入口；记录文件名使用 `YYYY-MM-DD--short-topic.md`，而不是含混的版本草稿名。

持久生成物统一放在：

`/home/shekong/Projects/outputs/meo-kde/{build,install,validation,packages,tmp}/`

`build/` 放配置和编译结果，`install/` 放暂存安装树，`packages/` 放待发布包及校验资料，`validation/` 放可复查验证证据，`tmp/` 仅作可丢弃工作区。每一次验证都使用 `validation/<UTC-run-id>/`，格式为 `YYYY-MM-DDTHHMMSSZ-short-label`，例如 `2026-08-26T104500Z-shell/`，并保存一个 `README.md`、日志、版本/环境信息及可复查的证据。`tmp/` 不可作为验收记录。

## Runtime boundary

Plasma、KWin 和 KDE 服务始终是窗口、任务、网络、音频、电源和会话状态的权威。MeoKDE 必须使用真实 KDE/DBus/系统 API 或明确的 KCM 交接，不能用装饰性的本地假开关。

构建、静态检查或离屏预览不能证明真实 Plasma/KWin 会话行为。涉及用户配置、显示、主题或会话的动作需要最小范围、可恢复的处理和相应运行证据；没有明确授权时不得重启/重载 Plasma 或 KWin、注销、重启，或改变用户的实时显示/主题状态。

## Read first

阅读 [AGENTS.md](AGENTS.md) 后，再根据改动阅读 `docs/` 中的相关契约。若改动需要通用 UI，先在 `meo-ui` 实现并遵守其 Showcase 交付门槛。
