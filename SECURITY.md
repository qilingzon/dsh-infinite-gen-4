# 安全与边界

## 插件会写什么、读什么

**写**（只有这些）：

| 路径 | 内容 | 何时 |
| --- | --- | --- |
| `$DSH_HOME/plugins/dsh-infinite-gen-4/` | 插件本体 | 安装时 |
| `$DSH_HOME/profiles/<profile>/node_modules/dsh-infinite-gen-4/` | 同上（宿主实际加载的一份） | 安装时 |
| `$DSH_HOME/plugin-backups/<时间戳>/` | 覆盖前的旧版本 | 安装 / 更新时，可用 `-Restore` 回滚 |

**读**：工作区里的进度文件（默认 `progress.md`，可配置）、`package.json`。

**不读**：`sessions/`、`.credentials.yaml`、任何环境变量里的密钥。模型凭据由宿主自己管理，
插件只通过宿主提供的接口发消息，从不接触 API key。

## 网络

插件自身**不发任何网络请求**，没有遥测、没有回连、没有自动更新检查。
所有模型流量都走你在宿主里配置的 provider。

安装脚本会访问：
- `api.github.com`（查最新版本，仅在未指定版本时）；
- `github.com/releases/...`（下载 zip 与 `SHA256SUMS.txt`）。

离线安装用 `-LocalZip` / `-f`，全程不联网。

## 权限模型

- 插件不提升宿主的任何权限，也不绕过宿主已有的确认弹窗；
- 未选中「破甲模式」预设的会话里，插件**零注入**：不写系统提示、不挂工具、不渲染徽标；
- 卸载走 `uninstall.ps1` / `uninstall.sh`，只删自己的三个目录与 profile 里的依赖条目。

## 完整性

- 每个 release 附 `SHA256SUMS.txt`，安装脚本下载后先校验再解压；
- 发布件逐文件哈希在仓库的 `RELEASE_NOTES.md` 里可查；
- 校验失败会直接中止，不会装一半。

## 报告问题

发现安全问题请开 issue（不要贴密钥或会话原文）：
<https://github.com/qilingzon/dsh-infinite-gen-4/issues>
