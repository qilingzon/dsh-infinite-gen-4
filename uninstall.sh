#!/usr/bin/env bash
# uninstall.sh — 卸载 dsh-infinite-gen-4（无限四代）
#
# 做三件事：删三处插件目录 → 摘掉 profile 依赖条目 → 提示重启。
# 不碰：sessions/、credentials、plugin-backups/、其他插件。
#
# 用法：
#   ./uninstall.sh
#   ./uninstall.sh -p desktop -n      # dry-run
#   ./uninstall.sh -P                 # 连 plugin-backups 一起清掉（不可恢复）
set -euo pipefail

PLUGIN="dsh-infinite-gen-4"
PROFILE="desktop"
DRY_RUN=0
PURGE_BACKUPS=0

say()  { printf '\n==> %s\n' "$*"; }
ok()   { printf '    [OK] %s\n' "$*"; }
warn() { printf '    [!]  %s\n' "$*"; }

while getopts ":p:nP" opt; do
  case "$opt" in
    p) PROFILE="$OPTARG" ;;
    n) DRY_RUN=1 ;;
    P) PURGE_BACKUPS=1 ;;
    *) ;;
  esac
done

DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
[ -d "$DSH_HOME" ] || { printf '[X] DSH_HOME 不存在：%s\n' "$DSH_HOME" >&2; exit 3; }
DSH_HOME="$(cd "$DSH_HOME" && pwd)"
say "DSH_HOME = $DSH_HOME"

TARGETS=(
  "$DSH_HOME/plugins/$PLUGIN"
  "$DSH_HOME/node_modules/$PLUGIN"
  "$DSH_HOME/profiles/$PROFILE/node_modules/$PLUGIN"
)

say "删除安装目录"
for t in "${TARGETS[@]}"; do
  if [ -e "$t" ]; then
    if [ "$DRY_RUN" = "1" ]; then ok "DRY-RUN 将删除 $t"
    else rm -rf "$t"; ok "已删除 $t"; fi
  else
    ok "不存在，跳过 $t"
  fi
done

say "清理 profile 依赖"
PJ="$DSH_HOME/profiles/$PROFILE/package.json"
if [ -f "$PJ" ]; then
  if grep -q "\"$PLUGIN\"" "$PJ"; then
    if [ "$DRY_RUN" = "1" ]; then
      ok "DRY-RUN 将从 package.json 移除 $PLUGIN"
    else
      cp "$PJ" "$PJ.bak-$(date +%Y%m%d-%H%M%S)"
      # 删掉包含插件名的那一行（依赖条目为单行 key: value 形式）
      grep -v "\"$PLUGIN\"" "$PJ" > "$PJ.tmp" && mv "$PJ.tmp" "$PJ"
      ok "已从 package.json 摘掉 $PLUGIN（已留 .bak）"
    fi
  else
    ok "依赖里没有 $PLUGIN，无需改动"
  fi
else
  warn "profile package.json 不存在：$PJ"
fi

if [ "$PURGE_BACKUPS" = "1" ] && [ -d "$DSH_HOME/plugin-backups" ]; then
  if [ "$DRY_RUN" = "1" ]; then ok "DRY-RUN 将删除 plugin-backups"
  else rm -rf "$DSH_HOME/plugin-backups"; ok "已删除 plugin-backups"; fi
fi

printf '\n'
if [ "$DRY_RUN" = "1" ]; then
  printf 'DRY-RUN 完成，未改动任何文件。\n'
else
  printf 'UNINSTALL-OK：已卸载 %s（重启 DeepSeek Harness 后生效）\n' "$PLUGIN"
fi
