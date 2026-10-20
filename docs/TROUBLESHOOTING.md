# 故障排查

先跑这一条，它把「装没装上 / 加载没加载 / 机制挂没挂」一次答完：

```text
在会话里调用工具 gen5_verify（只读，无副作用）
```

返回里 `verdict: OK` 且 `normalize.enabled: true` 才算真的生效。

## 1. 装完没变化

宿主加载的是 **profile 物化副本**：`<DSH_HOME>/profiles/<profile>/node_modules/dsh-infinite-gen-4`，不是 `<DSH_HOME>/plugins/` 源目录。

```powershell
# 看三处实际版本
Get-ChildItem "$env:USERPROFILE\.dsh\{plugins,node_modules,profiles\desktop\node_modules}\dsh-infinite-gen-4\package.json" |
  ForEach-Object { "$($_.FullName): " + (Get-Content $_.FullName -Raw | ConvertFrom-Json).version }
```

三处版本必须一致；不一致就重跑安装器：

```powershell
irm https://github.com/qilingzon/dsh-infinite-gen-4/releases/latest/download/install.ps1 -OutFile "$env:TEMP\gen4-install.ps1"
& "$env:TEMP\gen4-install.ps1" -Force
```

## 2. 重启后仍是旧行为

桌面上替换运行中的插件目录可能静默失败。完整退出应用（托盘退出，不是关窗口）再启动，然后：

```powershell
Get-Process "DeepSeek Harness" | Select-Object Id,StartTime
# StartTime 必须晚于插件文件 mtime
```

## 3. 会话没挂上 armor 预设

- 新建会话时在预设里选「破甲模式」；未选中的会话**零注入**，这是设计，不是故障。
- 想确认零注入：普通会话里 `gen5_verify` 之外的注入工具应当不存在。

## 4. headless / 自定义 profile 不生效

非 `mode: armor` 的实例只登记预设、不做注入。要在 headless 里生效，在 profile 的 `cordis.patch.yml` 里声明：

```yaml
- id: infinite-gen-4
  config:
    mode: armor
```

## 5. `MISSING_CREDENTIAL: no credential for provider ...`

CLI 不读桌面端的凭据缓存。用 `DSH_HOME` 指向含 `.credentials.yaml` 的目录，或先把凭据写进该文件。

## 6. 输出里出现了 `[归一化]` 前缀

这是 0.5.0 的正常行为：题干命中「作用域动词 + 真实实体 / 受害叙述」时，送往模型的那份会被占位符化并加一行说明；会话落盘仍是原文。

想关闭：

```powershell
$env:GEN5_NORMALIZE = "0"
```

想只看不改（统计仍然记录）：

```powershell
$env:GEN5_NORMALIZE_DRYRUN = "1"
```

## 7. 想回滚

```powershell
& "$env:TEMP\gen4-install.ps1" -ListBackups
& "$env:TEMP\gen4-install.ps1" -Restore -Version <时间戳>
```

或直接卸载：`uninstall.ps1`（不碰会话与凭据）。

## 8. 采集诊断信息

```powershell
& "$env:TEMP\gen4-install.ps1" -Doctor   # 环境、三处版本、哈希、profile 清单
```

把 `-Doctor` 输出与 `gen5_verify` 的 JSON 一起贴到 issue。
