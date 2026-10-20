# install.ps1 — 安装 / 更新 / 回滚 dsh-infinite-gen-4（无限四代）
#
# 用法：
#   .\install.ps1                        # 装最新 release
#   .\install.ps1 -Version 0.4.10        # 装指定版本
#   .\install.ps1 -DryRun                # 只检查，不落盘
#   .\install.ps1 -ListBackups           # 列出可回滚点
#   .\install.ps1 -Restore 20261020-235501
#   .\install.ps1 -LocalZip .\dsh-infinite-gen-4-0.4.10.zip   # 离线安装
#
# 设计原则：先备份、后覆盖；每一步都回读；失败即停，不留半装状态。
param(
  [string]$Version = "",
  [string]$Profile = "desktop",
  [string]$DshHome = "",
  [string]$LocalZip = "",
  [switch]$DryRun,
  [switch]$Force,
  [switch]$NoBackup,
  [switch]$ListBackups,
  [string]$Restore = "",
  [switch]$Doctor,
  [string]$Repo = "qilingzon/dsh-infinite-gen-4"
)

$ErrorActionPreference = "Stop"
$Plugin = "dsh-infinite-gen-4"

function Step($m) { Write-Host ""; Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    [OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "    [!]  $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "    [X]  $m" -ForegroundColor Red; exit 3 }

function Get-Sha256($path) {
  (Get-FileHash -Algorithm SHA256 -Path $path).Hash.ToLowerInvariant()
}

# ---- 0. 定位 DSH_HOME ----
if (-not $DshHome) {
  if ($env:DSH_HOME) { $DshHome = $env:DSH_HOME }
  elseif ($env:USERPROFILE) { $DshHome = Join-Path $env:USERPROFILE ".dsh" }
  else { Die "无法定位 DSH_HOME，请用 -DshHome 指定" }
}
$resolved = (Resolve-Path -LiteralPath $DshHome -ErrorAction SilentlyContinue)
if (-not $resolved) { Die "DSH_HOME 不存在：$DshHome（是不是还没装 DeepSeek Harness？）" }
$DshHome = $resolved.ProviderPath
Step "DSH_HOME = $DshHome"

$backupRoot = Join-Path $DshHome "plugin-backups"

# ---- 1. 只列回滚点 ----
if ($ListBackups) {
  if (-not (Test-Path $backupRoot)) { Warn "还没有回滚点（$backupRoot 不存在）"; exit 0 }
  Get-ChildItem $backupRoot -Directory | Sort-Object Name -Descending | ForEach-Object {
    $ver = ""
    $pj = Join-Path $_.FullName "plugins\$Plugin\package.json"
    if (Test-Path $pj) { try { $ver = (Get-Content $pj -Raw | ConvertFrom-Json).version } catch {} }
    "{0}  v{1}" -f $_.Name, $ver
  }
  exit 0
}

# ---- 2. 三个加载位 ----
$targets = @(Join-Path $DshHome "plugins\$Plugin")
$nodeDir = Join-Path $DshHome "node_modules"
if (Test-Path $nodeDir) { $targets += Join-Path $nodeDir $Plugin }
$profileDir = Join-Path $DshHome "profiles\$Profile"
if (-not (Test-Path $profileDir)) { Die "profile 不存在：$profileDir（可用 -Profile 指定，如 desktop）" }
$targets += Join-Path $profileDir "node_modules\$Plugin"

# ---- 2.5 只读诊断 ----
if ($Doctor) {
  Step "Doctor（只读诊断，不改任何文件）"
  $nodeExe = (Get-Command node -ErrorAction SilentlyContinue)
  "    Node           : " + $(if ($nodeExe) { (& node --version) } else { "未找到（插件要求 >= 20）" })
  "    DSH_HOME       : $DshHome"
  "    profile        : $Profile"
  $bad = 0
  foreach ($t in $targets) {
    $pj = Join-Path $t "package.json"
    if (-not (Test-Path $pj)) { "    [缺] $t"; $bad++; continue }
    $v = try { (Get-Content $pj -Raw | ConvertFrom-Json).version } catch { "?" }
    $sha = if (Test-Path (Join-Path $t "index.js")) { (Get-Sha256 (Join-Path $t "index.js")).Substring(0, 12) } else { "无 index.js" }
    $nz = if (Test-Path (Join-Path $t "normalize.js")) { "有" } else { "无" }
    "    [有] $t  v$v  index.js=$sha  normalize.js=$nz"
    if ($nz -ne "有") { $bad++ }
  }
  $vers = @($targets | ForEach-Object {
      $pj = Join-Path $_ "package.json"
      if (Test-Path $pj) { try { (Get-Content $pj -Raw | ConvertFrom-Json).version } catch { "?" } }
    })
  $uniq = @($vers | Sort-Object -Unique)
  if ($uniq.Count -gt 1) { "    [!] 三处版本不一致：" + ($uniq -join ", "); $bad++ }
  if (Test-Path $backupRoot) { "    回滚点         : " + (@(Get-ChildItem $backupRoot -Directory).Count) + " 个（$backupRoot）" } else { "    回滚点         : 无" }
  $varDir = Join-Path $targets[0] "prompts\variants"
  if (Test-Path $varDir) { "    提示词变体     : " + (@(Get-ChildItem $varDir -File).Count) + " 个" }
  if ($bad -eq 0) { Write-Host "DOCTOR-OK" -ForegroundColor Green; exit 0 }
  Write-Host "DOCTOR-FAIL（$bad 项异常）" -ForegroundColor Red
  exit 4
}

function Install-FromDir($srcDir) {
  $ver = (Get-Content (Join-Path $srcDir "package.json") -Raw | ConvertFrom-Json).version
  if (-not $ver) { Die "源目录缺少 package.json：$srcDir" }
  $srcSha = Get-Sha256 (Join-Path $srcDir "index.js")

  # 版本比对：force 关了就不重复覆盖
  $cur = ""
  $curPj = Join-Path $targets[0] "package.json"
  if (Test-Path $curPj) { try { $cur = (Get-Content $curPj -Raw | ConvertFrom-Json).version } catch {} }
  Step "安装 v$ver（当前 v$($cur -replace '^$','未安装')）"
  if ($cur -eq $ver -and -not $Force) { Ok "已是最新 v$ver，跳过（要强制覆盖加 -Force）"; return }

  # 备份
  if (-not $NoBackup -and -not $DryRun) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $bdir = Join-Path $backupRoot $stamp
    foreach ($t in $targets) {
      if (Test-Path $t) {
        $rel = if ($t -like "*\plugins\*") { "plugins" } elseif ($t -like "*\profiles\*") { "profile-node_modules" } else { "node_modules" }
        $dest = Join-Path $bdir (Join-Path $rel $Plugin)
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Copy-Item -Recurse -Force -Path (Join-Path $t "*") -Destination $dest
      }
    }
    if (Test-Path $bdir) { Ok "已备份到 plugin-backups\$stamp" }
  }

  if ($DryRun) { Ok "DRY-RUN：将写入 $($targets.Count) 处，未落盘"; return }

  # 覆盖
  foreach ($t in $targets) {
    if (Test-Path $t) { Remove-Item -Recurse -Force $t }
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    Copy-Item -Recurse -Force -Path (Join-Path $srcDir "*") -Destination $t
  }

  # 回读校验：三处 version 与 index.js 哈希必须一致
  foreach ($t in $targets) {
    $v = (Get-Content (Join-Path $t "package.json") -Raw | ConvertFrom-Json).version
    $s = Get-Sha256 (Join-Path $t "index.js")
    if ($v -ne $ver) { Die "回读失败：$t 的版本是 v$v，期望 v$ver" }
    if ($s -ne $srcSha) { Die "回读失败：$t 的 index.js 哈希不一致" }
  }
  Ok "三处回读一致（v$ver / index.js $($srcSha.Substring(0,12))…）"
  Write-Host ""
  Write-Host "INSTALL-OK v$ver (was v$($cur -replace '^$','none'))" -ForegroundColor Green
  Write-Host "下一步：启动 DeepSeek Harness → 新建会话 → Agent 预设选「破甲模式」。"
}

# ---- 3. 回滚 ----
if ($Restore) {
  $bdir = Join-Path $backupRoot $Restore
  if (-not (Test-Path $bdir)) { Die "回滚点不存在：$bdir（先跑 -ListBackups）" }
  Step "回滚到 $Restore"
  $map = @{
    "plugins"             = Join-Path $DshHome "plugins\$Plugin"
    "node_modules"        = Join-Path $DshHome "node_modules\$Plugin"
    "profile-node_modules" = Join-Path $profileDir "node_modules\$Plugin"
  }
  $restored = 0
  foreach ($k in $map.Keys) {
    $src = Join-Path $bdir (Join-Path $k $Plugin)
    if (-not (Test-Path $src)) { continue }
    $t = $map[$k]
    if (Test-Path $t) { Remove-Item -Recurse -Force $t }
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    Copy-Item -Recurse -Force -Path (Join-Path $src "*") -Destination $t
    $v = (Get-Content (Join-Path $t "package.json") -Raw | ConvertFrom-Json).version
    Ok "$k -> v$v"
    $restored++
  }
  if ($restored -eq 0) { Die "回滚点里没有本插件的内容：$bdir（结构不对，未做任何改动）" }
  Write-Host "RESTORE-OK $Restore" -ForegroundColor Green
  exit 0
}

# ---- 4. 拿安装包 ----
$tmp = Join-Path $env:TEMP ("gen4-install-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

if ($LocalZip) {
  if (-not (Test-Path $LocalZip)) { Die "zip 不存在：$LocalZip" }
  $zip = (Resolve-Path $LocalZip).Path
  Step "使用本地包 $zip"
} else {
  if (-not $Version) {
    Step "查询最新 release"
    try { $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ "User-Agent" = "gen4-install" } }
    catch { Die "查询 GitHub 失败：$($_.Exception.Message)（可改用 -LocalZip 离线安装）" }
    $Version = $rel.tag_name -replace "^v", ""
  }
  $asset = "$Plugin-$Version.zip"
  $url = "https://github.com/$Repo/releases/download/v$Version/$asset"
  $zip = Join-Path $tmp $asset
  Step "下载 v$Version"
  try {
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
  } catch {
    Die "下载失败：$url（版本号或网络问题；可用 -LocalZip 离线安装）"
  }
  # 校验和（release 里同时上传 SHA256SUMS.txt）
  # 注意：GitHub 对 .txt 资产常返回 application/octet-stream，Content 是 byte[]，必须先解码。
  try {
    $raw = (Invoke-WebRequest -Uri "https://github.com/$Repo/releases/download/v$Version/SHA256SUMS.txt" -UseBasicParsing).Content
    $sums = if ($raw -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($raw) } else { [string]$raw }
    $line = ($sums -split "\r?\n" | Where-Object { $_ -match [regex]::Escape($asset) } | Select-Object -First 1)
    if ($line) {
      $want = ($line -split "\s+")[0].ToLowerInvariant()
      $got = Get-Sha256 $zip
      if ($want -ne $got) { Die "SHA256 不匹配：期望 $want，实际 $got" }
      Ok "SHA256 校验通过（$($got.Substring(0,12))…）"
    } else { Warn "release 里没有该包的校验和，跳过" }
  } catch { Warn "取 SHA256SUMS.txt 失败，跳过校验（可用 -LocalZip 自行核验）" }
}

# ---- 5. 解压 ----
Step "解压"
Expand-Archive -Path $zip -DestinationPath $tmp -Force
$root = Get-ChildItem $tmp -Directory | Where-Object { Test-Path (Join-Path $_.FullName "package.json") } | Select-Object -First 1
if (-not $root) { Die "zip 结构异常：找不到含 package.json 的目录" }

Install-FromDir $root.FullName
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
