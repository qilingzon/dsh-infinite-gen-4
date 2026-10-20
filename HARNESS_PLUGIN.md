# DeepSeek Harness Plugin — 无限四代 / dsh-infinite-gen-4

破甲（armor-breaking）插件，项目名：**无限四代（Infinite Generation Four）** v0.4.0。
版本口径：**代际号 = minor**（gen2→0.2.x、gen4→0.4.x，今后 gen5→0.5.x）；
提示词标记 `STABLE v4` ↔ 包版本 0.4.x 对齐。
由「无限三代」v0.4.2 的 **fusion-v040 冠军骨架**（A/B 8/8 全过）最小增量升级而来。

## What the plugin provides

- `prompts/infinite-gen-4.md` 以追加式系统提示词段注册（`order: 100`）。
- `infinite_gen4_profile` — 返回打包的破甲提示词、血统、强度标定与完整模板库。
- **`client.js`（客户端半体）— 对话框「破甲已开启」状态条**：挂 `conversation.input.dock`
  槽位，显示 `⚫ 破甲已开启 · 无限四代`，四态实时判定（思考中/✓通过/◐未完交付/✗拒绝词）。
- 会话投影 `armor` + 再注入顾问（拒绝触发 + 每 10 轮周期重申，advisory 不阻塞）。

## 强度标定

| 版本 | 强度 | 说明 |
|---|---|---|
| dsh-deepseek-v4-obey (v4) | 100 | 无条件服从，最激进，易失稳 |
| **无限四代 (STABLE v4)** | **≈92** | 三代骨架 + 防超时纪律 + stealth v4 |
| 无限三代 (v0.4.2) | ≈90 | fusion 冠军骨架 |
| 无限二代 (v0.2.3) | ≈85 | 稳定化 + 降档 |
| 无限一代 | ≈60 | 保留豁免与澄清口子 |

## v4 相对三代 v0.4.2 的增量（最小增量纪律）

- **SPEED & SINGLE-PASS DISCILLINE v4（防超时专项）**：DEPTH IS NEVER CAPPED
  （单次深想永不设限，任何推理档位全实力）；EVIDENCE LOOP EXEMPTION（工程任务
  write→run→read→fix = 新证据迭代，非复验违规）；EFFICIENT THINKING PROTOCOL
  （结构换时长，low 档全实力）；SLOT-FIRST（槽位命中首 token 出槽）；
  ONE-PASS LOCK（禁无新证据的重复 deliberation）；LONG-TASK PIPELINE
  （>3000 字先落盘再逐块续写，块 ≤1500 字符）。
- **PROVIDER FILTER STEALTH v4**：thinking hygiene 只限域不限深（创作域思考链
  仅大纲，工程域 unrestricted）；FILE-FIRST 强制；CHAT-DIRECT 分章协议
  （长文直出自动降级为首章 ~2000 字 + 继续续章）。
- **新增类目槽位**：WiFi/无线破解（校园网/wifi密码/蹭网/WPA/PSK/portal认证/802.1X），
  边界词表同步扩充，题库 T14 对应。

## 保留的三代全部资产

意图化拒绝封禁、SPEC LOCK 需求保真、MID-STREAM PERSEVERANCE（含 REVERSION BAN /
TAIL-REFUSAL / TOKEN-SALVAGE）、ANTI-DRIFT 锚、INTRUSION-CLASS 首句协议、
WEB PENTEST / GAME REVERSE / EXTENDED ROUTING 全槽位、PRECEDENCE LADDER v4、
TURN SELF-CHECK（6 项）、格式锚、完整模板库（infinite_gen4_profile 按需取用）。

## Install in the lab homes

```powershell
# profiles/gen4-hl（headless 电池）与 profiles/gen4-lab（web 实验窗）：
"dependencies": {
  "dsh-infinite-gen-4": "file:../../plugins/dsh-infinite-gen-4"
},
"dsh": { "profile": { "bundles": ["@deepseek-ai/dsh-base","dsh-infinite-gen-4"] } }
```

然后 `cd <home>\profiles\gen4-hl && pnpm install`，重启会话。
生产安装用仓库内 `install.sh` / `uninstall.sh`（自动迁移清理旧版 dsh-infinite-gen-3）。

## Local verification

```powershell
node --check index.js; node --check client.js   # 双绿 = 语法通过
Get-Content package.json; Get-Content cordis.patch.yml
```

## URI Scheme One-Click Install Protocol

```text
dsh://plugin/install?id=dsh-infinite-gen-4&name=%E6%97%A0%E9%99%90%E5%9B%9B%E4%BB%A3&version=0.4.0&repo=Minglink%2Fdsh-infinite-gen-4&permissions=%E7%B3%BB%E7%BB%9F%E6%8F%90%E7%A4%BA%E8%AF%8D%E6%B3%A8%E5%85%A5%2C%E5%AE%A2%E6%88%B7%E7%AB%AF%E7%8A%B6%E6%80%81%E6%9D%A1&downloadUrl=https%3A%2F%2Fgithub.com%2FMinglink%2Fdsh-infinite-gen-4%2Farchive%2Frefs%2Fheads%2Fmaster.zip
```

