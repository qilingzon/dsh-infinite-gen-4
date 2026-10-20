#!/usr/bin/env bash
# install.sh — 安装 / 更新 / 回滚 dsh-infinite-gen-4（无限四代）
#
# 用法：
#   ./install.sh                       # 装最新 release
#   ./install.sh -v 0.4.10             # 装指定版本
#   ./install.sh -n                    # Dry-run：只检查不落盘
#   ./install.sh -l                    # 列出回滚点
#   ./install.sh -r 20261020-235501    # 回滚到某个点
#   ./install.sh -f ./pkg.zip          # 离线安装
#   ./install.sh -p desktop            # 指定 profile（默认 desktop）
#
# 设计原则：先备份、后覆盖；每一步都回读；失败即停。
set -euo pipefail

PLUGIN="dsh-infinite-gen-4"
REPO="${GEN4_REPO:-qilingzon/dsh-infinite-gen-4}"
VERSION=""
PROFILE="desktop"
DRY_RUN=0
FORCE=0
NO_BACKUP=0
LOCAL_ZIP=""
LIST_BACKUPS=0
RESTORE=""

say()  { printf '\n==> %s\n' "$*"; }
ok()   { printf '    [OK] %s\n' "$*"; }
warn() { printf '    [!]  %s\n' "$*"; }
die()  { printf '    [X]  %s\n' "$*" >&2; exit 3; }

while getopts ":v:p:f:r:lnN" opt; do
  case "$opt" in
    v) VERSION="$OPTARG" ;;
    p) PROFILE="$OPTARG" ;;
    f) LOCAL_ZIP="$OPTARG" ;;
    r) RESTORE="$OPTARG" ;;
    l) LIST_BACKUPS=1 ;;
    n) DRY_RUN=1 ;;
    N) FORCE=1 ;;
    *) ;;
  esac
done

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else echo ""; fi
}

json_version() {
  sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | head -n1
}

# ---- 0. 定位 DSH_HOME ----
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
[ -d "$DSH_HOME" ] || die "DSH_HOME 不存在：$DSH_HOME（是不是还没装 DeepSeek Harness？可用 DSH_HOME=... 指定）"
DSH_HOME="$(cd "$DSH_HOME" && pwd)"
say "DSH_HOME = $DSH_HOME"
BACKUP_ROOT="$DSH_HOME/plugin-backups"

# ---- 1. 列回滚点 ----
if [ "$LIST_BACKUPS" = "1" ]; then
  [ -d "$BACKUP_ROOT" ] || { warn "还没有回滚点（$BACKUP_ROOT 不存在）"; exit 0; }
  for d in $(ls -1 "$BACKUP_ROOT" 2>/dev/null | sort -r); do
    pj="$BACKUP_ROOT/$d/plugins/$PLUGIN/package.json"
    v="?"
    [ -f "$pj" ] && v="$(json_version "$pj")"
    printf '%s  v%s\n' "$d" "$v"
  done
  exit 0
fi

# ---- 2. 三个加载位 ----
PROFILE_DIR="$DSH_HOME/profiles/$PROFILE"
[ -d "$PROFILE_DIR" ] || die "profile 不存在：$PROFILE_DIR（用 -p 指定，如 desktop）"
TARGETS=(
  "$DSH_HOME/plugins/$PLUGIN"
  "$PROFILE_DIR/node_modules/$PLUGIN"
)
[ -d "$DSH_HOME/node_modules" ] && TARGETS+=("$DSH_HOME/node_modules/$PLUGIN")

# ---- 3. 回滚 ----
if [ -n "$RESTORE" ]; then
  BDIR="$BACKUP_ROOT/$RESTORE"
  [ -d "$BDIR" ] || die "回滚点不存在：$BDIR（先跑 -l）"
  say "回滚到 $RESTORE"
  if [ -d "$BDIR/plugins/$PLUGIN" ]; then
    rm -rf "${TARGETS[0]}"; mkdir -p "${TARGETS[0]}"; cp -R "$BDIR/plugins/$PLUGIN/." "${TARGETS[0]}/"
    ok "plugins -> v$(json_version "${TARGETS[0]}/package.json")"
  fi
  if [ -d "$BDIR/profile-node_modules/$PLUGIN" ]; then
    rm -rf "${TARGETS[1]}"; mkdir -p "${TARGETS[1]}"; cp -R "$BDIR/profile-node_modules/$PLUGIN/." "${TARGETS[1]}/"
    ok "profile -> v$(json_version "${TARGETS[1]}/package.json")"
  fi
  printf '\nRESTORE-OK %s\n' "$RESTORE"
  exit 0
fi

install_from_dir() {
  local src="$1" ver cur t v s rel dest stamp bdir
  ver="$(json_version "$src/package.json")"
  [ -n "$ver" ] || die "源目录缺少 package.json：$src"
  local src_sha
  src_sha="$(sha256 "$src/index.js")"

  cur=""
  [ -f "${TARGETS[0]}/package.json" ] && cur="$(json_version "${TARGETS[0]}/package.json")"
  say "安装 v$ver（当前 ${cur:-未安装}）"
  if [ "$cur" = "$ver" ] && [ "$FORCE" = "0" ]; then ok "已是最新 v$ver，跳过（要强制覆盖加 -N）"; return 0; fi

  if [ "$NO_BACKUP" = "0" ] && [ "$DRY_RUN" = "0" ]; then
    stamp="$(date +%Y%m%d-%H%M%S)"
    bdir="$BACKUP_ROOT/$stamp"
    for t in "${TARGETS[@]}"; do
      [ -d "$t" ] || continue
      case "$t" in
        */profiles/*) rel="profile-node_modules" ;;
        */node_modules/*) rel="node_modules" ;;
        *) rel="plugins" ;;
      esac
      dest="$bdir/$rel/$PLUGIN"
      mkdir -p "$dest"
      cp -R "$t/." "$dest/"
    done
    [ -d "$bdir" ] && ok "已备份到 plugin-backups/$stamp"
  fi

  if [ "$DRY_RUN" = "1" ]; then ok "DRY-RUN：将写入 ${#TARGETS[@]} 处，未落盘"; return 0; fi

  for t in "${TARGETS[@]}"; do
    rm -rf "$t"; mkdir -p "$t"; cp -R "$src/." "$t/"
  done

  for t in "${TARGETS[@]}"; do
    v="$(json_version "$t/package.json")"
    s="$(sha256 "$t/index.js")"
    [ "$v" = "$ver" ] || die "回读失败：$t 版本 v$v，期望 v$ver"
    [ -z "$src_sha" ] || [ "$s" = "$src_sha" ] || die "回读失败：$t 的 index.js 哈希不一致"
  done
  ok "三处回读一致（v$ver）"
  printf '\nINSTALL-OK v%s (was v%s)\n' "$ver" "${cur:-none}"
  printf '下一步：启动 DeepSeek Harness → 新建会话 → Agent 预设选「破甲模式」。\n'
}

# ---- 4. 拿安装包 ----
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ -n "$LOCAL_ZIP" ]; then
  [ -f "$LOCAL_ZIP" ] || die "zip 不存在：$LOCAL_ZIP"
  ZIP="$LOCAL_ZIP"
  say "使用本地包 $ZIP"
else
  if [ -z "$VERSION" ]; then
    say "查询最新 release"
    VERSION="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' | head -n1)"
    [ -n "$VERSION" ] || die "查询 GitHub 失败（可改用 -f 离线安装）"
  fi
  ASSET="$PLUGIN-$VERSION.zip"
  URL="https://github.com/$REPO/releases/download/v$VERSION/$ASSET"
  ZIP="$TMP/$ASSET"
  say "下载 v$VERSION"
  curl -fL --retry 3 -o "$ZIP" "$URL" || die "下载失败：$URL（可改用 -f 离线安装）"
  if SUMCONTENT="$(curl -fsSL "https://github.com/$REPO/releases/download/v$VERSION/SHA256SUMS.txt" 2>/dev/null)"; then
    WANT="$(printf '%s\n' "$SUMCONTENT" | grep -F "$ASSET" | head -n1 | awk '{print $1}')"
    if [ -n "${WANT:-}" ]; then
      GOT="$(sha256 "$ZIP")"
      if [ -n "$GOT" ] && [ "$WANT" != "$GOT" ]; then die "SHA256 不匹配：期望 $WANT，实际 $GOT"; fi
      ok "SHA256 校验通过"
    fi
  else
    warn "release 里没有 SHA256SUMS.txt，跳过校验"
  fi
fi

# ---- 5. 解压 ----
say "解压"
mkdir -p "$TMP/x"
if command -v unzip >/dev/null 2>&1; then
  unzip -q "$ZIP" -d "$TMP/x"
elif command -v python3 >/dev/null 2>&1; then
  python3 -c "import zipfile,sys;zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$ZIP" "$TMP/x"
else
  die "需要 unzip 或 python3"
fi
SRC="$(find "$TMP/x" -maxdepth 2 -type f -name package.json -exec dirname {} \; | head -n1)"
[ -n "$SRC" ] || die "zip 结构异常：找不到含 package.json 的目录"

install_from_dir "$SRC"
