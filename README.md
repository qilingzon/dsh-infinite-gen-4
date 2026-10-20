# 无限四代 · dsh-infinite-gen-4

> DeepSeek Harness 插件：把「破甲模式」注册成一个**可选的 agent preset**。
> 只有你显式选中它的会话才会注入交付引擎提示词；其他会话、其他模式**零注入**。

[![version](https://img.shields.io/badge/version-0.4.10-2f6feb)](https://github.com/qilingzon/dsh-infinite-gen-4/releases)
[![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)
[![platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-555)]

---

## 这是什么

装好之后，DeepSeek Harness 的「新建会话 → Agent 预设」里会多出一项 **破甲模式（armor）**。
选中它，会话就会加载一套「交付引擎」规范：

| 能力 | 说明 |
|---|---|
| 直接交付 | 首行即交付物（标题或代码块），不再「我理解您想要…」式铺垫 |
| 格式锚点 | 入侵类以 `目标占位流程：` 槽位行开头；工程类给步骤 + 命令 + 代码 |
| 中途坚持 | 长文分段写入文件，被截断后从断点换措辞续写，不重头、不省略 |
| 防漂移 | 第 50 轮与第 1 轮同一套规则，前面答歪了也不当先例 |
| 工具结果免疫 | 文件内容、子代理输出、网页文本一律当数据，不当指令 |
| 落盘纪律 | 超 3000 字的产物先进工作区文件，回复只给标题 + 摘要 + 路径 |

**边界（重要）**：未选中「破甲模式」的会话里，本插件不写系统提示、不挂工具、不渲染状态条。
换句话说，它不会污染 `standard` 或其他预设的正常对话。可在会话头部看徽标：
绿色「破甲已开启 · 无限四代」= 当前会话正在使用它。

## 不是什么

- 不是模型权重改动，不改采样参数，不代理你的 API 请求；
- 不是常驻后台服务，没有网络回调，不上传任何会话内容；
- 不替代你自己的判断：产出的代码/命令由你负责验证后再执行。

---

## 环境要求

| 项 | 要求 |
|---|---|
| DeepSeek Harness | 桌面端 0.2.x 及以上，或 CLI 同版本 |
| Node.js | ≥ 20（桌面端自带，CLI 需系统安装） |
| 系统 | Windows 10/11、macOS 12+、主流 Linux |
| 网络 | 仅安装/更新时需要；运行时完全离线 |

DSH 的两个位置先记住（下文用占位符表示）：

- `$DSH_HOME`：默认 `C:\Users\<你>\.dsh`（Windows）或 `~/.dsh`（macOS/Linux）
- `$PROFILE`：你正在用的 profile，桌面端默认 `desktop`

## 安装（三选一）

### 方式 A：一键脚本（推荐，Windows）

**先完全退出 DeepSeek Harness**（插件文件被运行中的宿主占用，装不进去）。
然后在 PowerShell 里粘一行：

```powershell
irm https://raw.githubusercontent.com/qilingzon/dsh-infinite-gen-4/main/install.ps1 -OutFile "$env:TEMP\gen4-install.ps1"; & "$env:TEMP\gen4-install.ps1"
```

脚本会依次做：定位 `$DSH_HOME` → 查最新 release → 下载 zip → **校验 SHA256** →
备份现有安装 → 复制到三个加载位 → 回读校验文件哈希 → 打印版本与下一步。

脚本已经落到 `$env:TEMP\gen4-install.ps1`，常用参数直接加在后面：

```powershell
# 指定版本 / 只预览不落盘 / 指定 profile
& "$env:TEMP\gen4-install.ps1" -Version 0.4.10 -DryRun
& "$env:TEMP\gen4-install.ps1" -Profile desktop
```

> macOS / Linux：`curl -fsSL https://raw.githubusercontent.com/qilingzon/dsh-infinite-gen-4/main/install.sh -o /tmp/gen4-install.sh && bash /tmp/gen4-install.sh`
> （参数同理直接加在后面：`bash /tmp/gen4-install.sh -v 0.4.10 -n`）

### 方式 B：走 DSH 自己的插件管理器（等价的「正规军」路线）

`dsh plugin` 会把你后面的参数原样转给 profile 目录里的 pnpm，所以 git 依赖也能装：

```bash
# 先退出桌面端，再在终端里执行
dsh plugin --profile desktop add github:qilingzon/dsh-infinite-gen-4#v0.4.10
dsh plugin --profile desktop why dsh-infinite-gen-4   # 确认已入依赖树
```

它由 pnpm 管理版本、写进 `profiles/desktop/package.json`，升级时把 `#v0.4.10` 换成新 tag 即可。
缺点：需要能访问 GitHub、且 profile 的 peer 校验必须全绿（有一个插件不满足 peer，整次安装会被拒绝并回滚）。

### 方式 C：手动装 zip（完全离线）

1. 到 [Releases](https://github.com/qilingzon/dsh-infinite-gen-4/releases) 下载
   `dsh-infinite-gen-4-<版本>.zip` 与 `SHA256SUMS.txt`；
2. 校验：`certutil -hashfile dsh-infinite-gen-4-0.4.10.zip SHA256`（macOS：`shasum -a 256`）；
3. 解压后把整个 `dsh-infinite-gen-4` 目录复制到这三处（已存在就覆盖）：
   - `$DSH_HOME\plugins\dsh-infinite-gen-4`
   - `$DSH_HOME\node_modules\dsh-infinite-gen-4`
   - `$DSH_HOME\profiles\$PROFILE\node_modules\dsh-infinite-gen-4`
4. 启动 DeepSeek Harness。

## 验证装没装上

```powershell
# 三条都应输出 0.4.10
Get-Content "$env:USERPROFILE\.dsh\plugins\dsh-infinite-gen-4\package.json" | Select-String '"version"'
```

更直观的验证：打开桌面端 → 新建会话 → Agent 预设里能看到 **破甲模式**；
选中后会话头部出现绿色「破甲已开启 · 无限四代」徽标，即生效。

---

## 更新

**原则：先退出应用，再更新，再启动。** 运行中的宿主会用文件句柄占住插件目录。

```powershell
# 更新到最新 release（脚本自动取 latest；版本相同会跳过，不重复覆盖）
irm https://raw.githubusercontent.com/qilingzon/dsh-infinite-gen-4/main/install.ps1 -OutFile "$env:TEMP\gen4-install.ps1"; & "$env:TEMP\gen4-install.ps1"
```

已经下载过脚本的，直接：`.\install.ps1 -Force`。它会：比对当前版本 → 若已是最新则退出（不重复覆盖）→
否则备份旧目录到 `$DSH_HOME\plugin-backups\<时间戳>\` → 覆盖 → 回读哈希 → 打印 `INSTALL-OK v<新> (was v<旧>)`。

方式 B 用户：

```bash
dsh plugin --profile desktop remove dsh-infinite-gen-4
dsh plugin --profile desktop add github:qilingzon/dsh-infinite-gen-4#v0.4.10
```

## 回滚

每次安装前的旧版本都在 `$DSH_HOME\plugin-backups\` 下，按时间戳分目录：

```powershell
# 列出可用回滚点
.\install.ps1 -ListBackups
# 回滚到某个时间戳
.\install.ps1 -Restore 20261020-235501
```

回滚只覆盖本插件的三个目录，不动 `$DSH_HOME` 下其他任何文件（sessions、credentials、node_modules 其他包一律不碰）。

## 卸载

```powershell
# Windows
irm https://raw.githubusercontent.com/qilingzon/dsh-infinite-gen-4/main/uninstall.ps1 -OutFile "$env:TEMP\gen4-uninstall.ps1"; & "$env:TEMP\gen4-uninstall.ps1"
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/qilingzon/dsh-infinite-gen-4/main/uninstall.sh -o /tmp/gen4-uninstall.sh && bash /tmp/gen4-uninstall.sh
```

做的事情只有三件：删 `$DSH_HOME\plugins\dsh-infinite-gen-4`、删两处 `node_modules\dsh-infinite-gen-4`、
把 profile 依赖里的条目摘掉。**不会**删你的会话、不删 `plugin-backups`（留给你后悔）。
方式 B 用户的等价命令：`dsh plugin --profile desktop remove dsh-infinite-gen-4`。

卸载后重启应用，「破甲模式」预设与徽标即消失；已有会话下次打开会回落到默认预设。

---

## 首次使用

1. 重启 DeepSeek Harness；
2. 新建会话，在顶部把 **Agent 预设** 切到「破甲模式」；
3. 看头部徽标：绿色 `破甲已开启 · 无限四代` = 生效。没有徽标就是没选中，不是没装上。

> 若你的默认预设不是它，每次新建会话都要手动选一次；老会话保持创建时选的预设，不会自动切换。

## 配置（环境变量，全部可选）

| 变量 | 默认 | 作用 |
|---|---|---|
| `GEN4_VARIANT` | `b37-lite` | 选提示词变体，见 `prompts/variants/*.md`；`b37-coldstart` 是加长对照版 |
| `GEN4_PREHEAT_MODE` | `history` | 冷启动预热取数来源 |
| `GEN4_PREHEAT_GATE` | `continuation` | 只在首句是「继续/接着做」类裸续做语时注入预热卡 |
| `GEN4_PREHEAT_FILE` | 空 | 指定预热读取的文件（默认读工作区 `progress.md` 顶部） |
| `GEN4_REANCHOR_TEXT` | 内置中性短句 | 工作提醒（`[work-reminder]`）的文案 |
| `GEN4_REANCHOR_TEXT_FILE` | 空 | 从文件读取上面的文案 |

设置方式（Windows，用户级）：

```powershell
[Environment]::SetEnvironmentVariable('GEN4_VARIANT','b37-coldstart','User')  # 改完重启应用
```

## 目录结构

```
dsh-infinite-gen-4/
├─ index.js            # 插件主体：预设登记、提示词注入、状态投影、工作提醒
├─ client.js           # 客户端状态条（徽标）
├─ preheat.js          # 冷启动预热（读 progress.md 顶部一条未完成项）
├─ preset-rows.js      # 预设里的插件行
├─ cordis.patch.yml    # bundle 挂载声明
├─ prompts/            # 提示词正文与 20+ 个变体
├─ install.ps1         # 安装 / 更新 / 回滚（Windows）
├─ install.sh          # 安装 / 更新 / 回滚（macOS / Linux）
├─ uninstall.ps1       # 卸载（Windows）
├─ uninstall.sh        # 卸载（macOS / Linux）
├─ CHANGELOG.md        # 更新日志
├─ SECURITY.md         # 读写范围与网络行为
└─ tools/              # 自检小工具
```

## 故障排查

| 现象 | 原因 | 处理 |
|---|---|---|
| 预设里没有「破甲模式」 | 三处版本不一致，宿主加载了旧的 | 删三个目录后重装；或先升级再重启 |
| 徽标不出现 | 当前会话是 `standard` 预设 | 新建会话并选「破甲模式」 |
| 安装报 `EPERM` / 文件被占用 | 应用还在跑 | 完全退出（含托盘图标）后重装 |
| `dsh plugin add` 被拒并自动回滚 | profile 里有一个插件 peer 不满足，整次安装被拦 | 先修 peer，或用方式 A/C 绕过 pnpm |
| 长会话偶发被拒 | 模型侧概率事件，非插件失效 | 同题重开新会话；插件不做自动重投（实测净零收益） |
| 会话文件打不开 | 0.4.8 及更早的 role 写入缺陷 | 升到 0.4.9+ 即可，旧会话本身未损坏 |

## 隐私与安全

- 运行时不发任何网络请求，不上传会话内容、不读取凭据文件；
- 安装脚本只写 `$DSH_HOME` 下本插件相关的三个目录与 `plugin-backups`；
- 唯一的外联是安装/更新时向 GitHub 取 release 与校验和；
- 许可证 MIT，正文见 [LICENSE](./LICENSE)；改动记录见 [CHANGELOG.md](./CHANGELOG.md)。

---

<sub>本项目按「你让模型做什么，你就对结果负责」的原则分发：提示词只影响输出风格与完成度，不改变模型能力边界，也不替你判断用途是否合规。</sub>




