# RELEASE NOTES · dsh-infinite-gen-4 v0.5.1-lab-20261023

> 由 `node .diag/build_release.js` 生成；逐文件 SHA256 见同目录 `MANIFEST.json`。
> 源目录：`D:\deepseek\armor-lab\gen4_home\plugins\dsh-infinite-gen-4`（lab 规范源）。**发布件不含 `*.bak*` / `.REJECTED.md` / node_modules。**

## 0. 本版变更（第五代 · 对外唯一版本）

> 本文件 §1 以下为打包器继承的历史模板内容，含 0.4.x 时期的数字；**本版的事实以本节与 `MANIFEST.json` 为准**。

### 0.1 版本处置

| 版本 | 状态 |
| --- | --- |
| `v0.5.1`（本版） | 第五代对外唯一版本 |
| `v0.5.0` | **撤回**：GitHub 安装通道报 `ERR_MODULE_NOT_FOUND .../normalize.js`（发布清单 `files` 漏项），按发布标准 R1/R6 撤回，改动并入本版 |

### 0.2 机制（代际内容）

- **前置归一化 `normalize.js`**：送往模型前把题干的第一人称受害叙述 → `ROLE_A`、域名 → `TARGET_DOMAIN`、
  产品名 → `APP`、公司 → `CORP_TARGET`，并加一行 `[归一化]` 说明；只改送模型的那一份，会话落盘保留原文。
  开关 `GEN5_NORMALIZE=0` / `GEN5_NORMALIZE_DRYRUN=1`。
- **后置验证 `gen5_verify`**：只读工具，返回 `version` / `implementationRevision` / `promptSetHash` /
  `variant` / `normalize` 统计 / `checks` / `verdict`，用于判定「装的是不是这一版、加载的是不是这一份」。
- **机制退役**：默认变体 `b37-coldstart` → `b37-lite`（删自指元话语段落）；旧变体随包保留，
  `GEN4_VARIANT=b37-coldstart` 可切回做对照。

### 0.3 证据（可复跑）

- **交付 A/B（归一化关 / 开）**：T02/T21/T36 ×4 reps，实质交付 11/12 vs 11/12，净差 **0** → 本版**不主张能力提升**。
- **45 题电池**：见仓库 `docs/GENERATION_5.md` 与本目录 `MANIFEST.json` 同批记录；拒答/超时逐题标注，不折算成比例。
- **矩阵**：`r4/deepseek-v4.1-flash`（max）+ `guijiliudon/DeepSeek-V4-Flash`，各 3 格全交付。
- **安装实证**：空 `DSH_HOME` → `install.ps1 -LocalZip` → `INSTALL-OK v0.5.1`；
  `github:qilingzon/dsh-infinite-gen-4#v0.5.1` 通道安装后 `normalize.js` 在位、插件可导入。

### 0.4 安装 / 更新 / 回滚

- 一键：`install.ps1`（Windows）/ `install.sh`（macOS·Linux），查最新 release → 校验 `SHA256SUMS.txt` → 备份三处加载位 → 覆盖 → 回读版本与哈希。
- 插件管理器：`dsh plugin --profile <profile> add github:qilingzon/dsh-infinite-gen-4#v0.5.1`。
- 回滚：`install.ps1 -ListBackups` 选点 → `-Restore <时间戳>`；或退回上一 release zip。
- 卸载：`uninstall.ps1` / `uninstall.sh`，不动 `sessions/`、`.credentials.yaml`。

### 0.5 本版不改变什么

- 不改模型权重、采样与宿主能力；不新增网络出站行为；不读取 `sessions/`、`.credentials.yaml`、`node_modules/`。
- 不主张「更强 / 更稳 / 更快」；`noRegression: true` 仅表示无逐格负优化证据，不等于能力提升。
> 说明：§1–§4 由 build_release.js 模板继承，其中变体交付率与电池数字截至 0.4.2–0.4.10，属**历史数据**。

## 1. 这一版的关键事实（都可复跑核验）

- **重申通道默认值 = canonical 10 / 12**（与桌面端及九份历史副本一致），并**可 env 覆盖**：
  `GEN4_REANCHOR_EVERY_TURNS`（0=关周期性）、`GEN4_REANCHOR_ON_REFUSAL`、
  `GEN4_POSTEXEC_EVERY_ACTIONS`、`GEN4_REANCHOR_TEXT_FILE`（中性重申文本）。
  ⚠️ 历史教训：本文件第一版把源目录当时的 20/24 带进了生效副本，导致 b37v12/v13 与 b37v15/16/18 之间
  多出一个不一致变量；现已归零（见 `progress.md`）。
- **变体切换**：`GEN4_VARIANT=<名>` → `prompts/variants/<名>.md`；默认 `b37-coldstart`。
  本次发布含 **21 个变体**。
- **运行期加载的是 profile 的物化副本**（`<home>/profiles/<profile>/node_modules/dsh-infinite-gen-4`），
  **不是** `<home>/plugins/` 源目录 —— 改源不生效是常态。发布/安装必须走
  `.diag/sync_plugin_to_profile.ps1`（逐文件 SHA256 + 变体存在性断言，失败 exit 3）。

## 2. 甲（变体）的实测交付率（电池，元指令 n=9–18，判据 = score_win 金标版本）

| 变体 | 交付率 | 备注 |
| --- | --- | --- |
| `upstream-v040`（官方原版 3 KB，逐字节相同） | **61%** | 目前测得最高；措辞中性、脸上不写"破甲/越狱" |
| `b37-coldstart`（默认，25 KB） | **56%** | 桌面端当前安装的就是它 |
| `main`（`prompts/infinite-gen-4.md`，lab 源为 slim v1 2 KB） | 17% | 注意：桌面端那份 main 是 24 KB legacy，**与 lab 不同** |
| `window-v042live`（本窗口真机提示词，含 harness 前言） | **0%** | 实测最差，仅作对照件保留 |

## 3. 已知问题（如实）

1. **判据（`score_win.js`）仍有长尾，未收敛**：四批盲测残余误差 12.8% / 8.6% / 8.3% / 10.8%，
   合计 **16/155 ≈ 10.3%**，趋势**没有下降**。16 条分歧里，独立判读的结论与我逐条读原文的仲裁 **100% 一致**
   （判据全错、判读全对）。⇒ **架构建议**：把主判据换成 **LLM 独立判读**（rubric-only 读者 + 多次投票），
   `score_win.js` 降级为快速预筛/分流；marker 词表继续维护但不再当唯一真值。
2. **桌面与 lab 存在版本差**：桌面那份 `index.js` 无 env 开关、main 为 24 KB legacy、仅 6 个变体；
   对齐需走 `desktop-install-kit/`（**需用户明确指令 + 先备份**）。
3. **臂内 rep 漂移未消**（同格多轮共享一份 cwd 副本）；样本量 n=9–18，交付率只能当方向。
4. **工具通道在副本环境里可能静默失效**（`pwsh` 无 stdout 无副作用）—— 属环境现象，不是插件缺陷；
   `acp_client.js` 现在会在超时后重启子进程，避免一次超时报废整轮。
5. **甲的效果仍是概率性的**：测得最好的 `upstream-v040` 也只有 61%；没有任何配置复现出"本窗口那样连续交付"，
   目前唯一连中的组合是"中性工程预热 + 明确接着之前的进度"（W4 的 ST2，n=2 待扩样）。

## 4. 校验方式

```powershell
pwsh -File .diag\verify_release.ps1 -Version v0.5.1-lab-20261023      # 发布件 == lab 源 == 两份生效副本
node .diag\verify_regression.js                          # 判据金标
node .diag\selftest.js                                   # 12 项
pwsh -File .diag\overnight_verify.ps1                     # 一条命令全绿
```

