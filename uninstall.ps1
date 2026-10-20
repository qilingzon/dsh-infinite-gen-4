# uninstall.ps1 — 卸载 dsh-infinite-gen-4（无限四代）
#
# 做三件事：删三处插件目录 → 摘掉 profile 依赖条目 → 提示重启。
# 不碰：sessions/、credentials、plugin-backups/、其他插件。
#
# 用法：
#   .\uninstall.ps1
#   .\uninstall.ps1 -Profile desktop -DryRun
#   .\uninstall.ps1 -PurgeBackups      # 连 plugin-backups 一起清掉（不可恢复）
param(
  [string]$Profile = "desktop",
  [string]$DshHome = "",
  [switch]$DryRun,
  [switch]$PurgeBackups
)

$ErrorActionPreference = "Stop"
$Plugin = "dsh-infinite-gen-4"

function Step($m) { Write-Host ""; Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    [OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "    [!]  $m" -ForegroundColor Yellow }

if (-not $DshHome) {
  if ($env:DSH_HOME) { $DshHome = $env:DSH_HOME }
  elseif ($env:USERPROFILE) { $DshHome = Join-Path $env:USERPROFILE ".dsh" }
  else { throw "无法定位 DSH_HOME，请用 -DshHome 指定" }
}
if (-not (Test-Path $DshHome)) { throw "DSH_HOME 不存在：$DshHome" }
$resolved = (Resolve-Path -LiteralPath $DshHome)
$DshHome = $resolved.ProviderPath
Step "DSH_HOME = $DshHome"

$running = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match "DeepSeek Harness" }
if ($running) { Warn "检测到 DeepSeek Harness 正在运行；卸载后请重启一次应用（文件可能被占用）" }

$targets = @(
  (Join-Path $DshHome "plugins\$Plugin"),
  (Join-Path $DshHome "node_modules\$Plugin"),
  (Join-Path $DshHome "profiles\$Profile\node_modules\$Plugin")
)

Step "删除安装目录"
foreach ($t in $targets) {
  if (Test-Path $t) {
    if ($DryRun) { Ok "DRY-RUN 将删除 $t" }
    else {
      try { Remove-Item -Recurse -Force $t; Ok "已删除 $t" }
      catch { Warn "删除失败（可能被占用）：$t — 退出应用后重试" }
    }
  } else {
    Ok "不存在，跳过 $t"
  }
}

Step "清理 profile 依赖"
$pj = Join-Path $DshHome "profiles\$Profile\package.json"
if (Test-Path $pj) {
  try {
    $json = Get-Content $pj -Raw | ConvertFrom-Json
    $changed = $false
    foreach ($sec in @("dependencies", "devDependencies", "peerDependencies")) {
      if ($json.PSObject.Properties.Name -contains $sec -and $json.$sec.PSObject.Properties.Name -contains $Plugin) {
        if ($DryRun) { Ok "DRY-RUN 将从 $sec 移除 $Plugin" }
        else { $json.$sec.PSObject.Properties.Remove($Plugin); $changed = $true }
      }
    }
    if ($changed) {
      ($json | ConvertTo-Json -Depth 20) | Set-Content -Path $pj -Encoding UTF8
      Ok "已从 package.json 摘掉 $Plugin（pnpm install 后锁文件才会更新）"
    } elseif (-not $DryRun) { Ok "依赖里没有 $Plugin，无需改动" }
  } catch { Warn "读取 $pj 失败：$($_.Exception.Message)" }
} else { Warn "profile package.json 不存在：$pj" }

if ($PurgeBackups) {
  $bk = Join-Path $DshHome "plugin-backups"
  if (Test-Path $bk) {
    if ($DryRun) { Ok "DRY-RUN 将删除 $bk" } else { Remove-Item -Recurse -Force $bk; Ok "已删除 plugin-backups" }
  }
}

Write-Host ""
if ($DryRun) { Write-Host "DRY-RUN 完成，未改动任何文件。" -ForegroundColor Yellow }
else { Write-Host "UNINSTALL-OK：已卸载 $Plugin（重启 DeepSeek Harness 后生效）" -ForegroundColor Green }
