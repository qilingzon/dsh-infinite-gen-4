# 无限四代 · 启用范围设置（命令行等价物）
#
# 徽标点击 = 本脚本的图形版：范围写在 <DSH_HOME>\.dsh-infinite-gen-4.json，
# 插件两个实例都轮询该文件，改完热生效（无需重启宿主）。
#
#   local  —— 只有「破甲模式」预设的会话注入框架（默认，不污染其他模式）
#   global —— 本 profile 的所有预设都注入，徽标在所有模式显示
#
# 用法：
#   pwsh -File tools\scope.ps1            # 看当前范围
#   pwsh -File tools\scope.ps1 global     # 设为全部模式
#   pwsh -File tools\scope.ps1 local      # 设为仅破甲模式
#   pwsh -File tools\scope.ps1 global -DshHome D:\some\home
#
# 注意：环境变量 GEN4_SCOPE 优先级最高；若已设置，本脚本只提示、不写入。

[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('show', 'local', 'global')]
  [string]$Scope = 'show',

  [string]$DshHome = $env:DSH_HOME
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($DshHome)) {
  $DshHome = Join-Path $env:USERPROFILE '.dsh'
}
$file = Join-Path $DshHome '.dsh-infinite-gen-4.json'

function Show-State {
  $fromEnv = $env:GEN4_SCOPE
  $fromFile = $null
  if (Test-Path $file) {
    try { $fromFile = (Get-Content $file -Raw | ConvertFrom-Json).scope } catch { $fromFile = '<解析失败>' }
  }
  "DSH_HOME   : $DshHome"
  "设置文件   : $file"
  "文件里的值 : $(if ($fromFile) { $fromFile } else { '<未设置>' })"
  "环境变量   : $(if ($fromEnv) { $fromEnv } else { '<未设置>' })"
  $effective = if ($fromEnv) { $fromEnv } elseif ($fromFile) { $fromFile } else { 'local' }
  "生效范围   : $effective$(if ($fromEnv) { '  (环境变量优先，界面无法切换)' } else { '' })"
}

if ($Scope -eq 'show') {
  Show-State
  exit 0
}

if ($env:GEN4_SCOPE) {
  "环境变量 GEN4_SCOPE=$($env:GEN4_SCOPE) 优先级最高，本脚本不改写设置文件。"
  Show-State
  exit 2
}

if (-not (Test-Path $DshHome)) { throw "DSH_HOME 不存在：$DshHome" }
$payload = [ordered]@{
  scope     = $Scope
  updatedAt = (Get-Date).ToString('o')
  by        = 'scope.ps1'
} | ConvertTo-Json
Set-Content -Path $file -Value ($payload + "`n") -Encoding utf8
"SCOPE-SET $Scope"
Show-State
