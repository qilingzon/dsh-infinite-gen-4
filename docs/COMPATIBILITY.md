# 兼容性

## 宿主

| 项 | 要求 |
|---|---|
| DeepSeek Harness | 桌面端 0.2.1-rc 及以上；CLI runtime 需支持 `agentPresets` 服务与 `ctx.effect` |
| Node.js | ≥ 20（插件用 ESM、`node:crypto`、`Array.prototype.at`） |
| 操作系统 | Windows 10/11（`.ps1` 安装器）；Linux / macOS / Git Bash（`.sh` 安装器） |

插件只依赖宿主暴露的插件 API，不打包第三方运行时依赖；`package.json` 里没有 `dependencies`。

## 版本线

| 版本 | 状态 | 说明 |
|---|---|---|
| 0.5.x | 当前代际 | 新增执行前归一化 + `gen5_verify` 后置验证 |
| 0.4.x | 维护 | b37-lite 默认变体、work-reminder 中性化 |
| ≤ 0.4.9 | 历史 | 见 `CHANGELOG.md` |

向后兼容承诺：0.5.0 的 `cordis.patch.yml` 与 0.4.x 相同（66 B），不新增宿主侧自动挂载项；`armor` 预设 id 不变，老会话继续可用。

## 已验证组合

| 宿主 | 安装方式 | 结果 |
|---|---|---|
| Windows 11 · 桌面端 0.2.1-rc.2 | `install.ps1` 三处刷入 | 三处 `version` 一致、`gen5_verify` OK |
| Windows 11 · CLI（`dsh --profile gen4-hl`） | `dsh plugin add` / 源同步 | headless 会话可交付 |
| Git Bash · Windows | `install.sh` | `-f` / `-l` / `-r` 全通 |

## 未验证 / 已知限制

- **profile 物化副本**：宿主加载的是 `profiles/<p>/node_modules/` 下的副本，不是 `plugins/` 源目录；改源不生效属正常现象，须走安装器或 `dsh plugin add`。
- **运行期替换目录**：宿主运行中替换已加载的插件目录可能报 `EPERM`，需要完整退出应用后升级。
- 多模型矩阵只覆盖 OpenAI 兼容端点，本地推理端点未做矩阵测评。
