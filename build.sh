#!/bin/bash
# =============================================================================
# JiayingGameTweak 打包脚本
# 用法:
#   ./build.sh rootful           # 打包 rootful deb
#   ./build.sh rootless          # 打包 rootless deb
#   ./build.sh both              # 同时打包两个
#   ./build.sh rootless install  # 打包并通过 SSH 安装到设备
#
# 前置条件:
#   1. macOS + theOS (https://github.com/theos/theos)
#   2. export THEOS=/path/to/theos
#   3. rootless 需 Xcode 13+ SDK；rootful 需 iOS 11~14 SDK
# =============================================================================
set -euo pipefail

SCHEME="${1:-rootful}"
ACTION="${2:-package}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ -z "${THEOS:-}" ]]; then
  echo "[ERROR] 请先设置 THEOS 环境变量，例如: export THEOS=~/theos" >&2
  exit 1
fi

build_one() {
  local scheme="$1"
  echo "============================================================"
  echo " 构建 scheme: $scheme"
  echo "============================================================"

  if [[ "$scheme" == "rootless" ]]; then
    cp -f control.rootless control
    export THEOS_PACKAGE_SCHEME=rootless
  else
    cp -f control.rootful control
    unset THEOS_PACKAGE_SCHEME || true
  fi

  make clean >/dev/null 2>&1 || true
  make package

  # theOS 产物在 packages/ 目录，按 scheme 重命名归档
  mkdir -p artifacts
  local deb
  deb="$(ls -t packages/*.deb 2>/dev/null | head -n1 || true)"
  if [[ -n "$deb" ]]; then
    cp -f "$deb" "artifacts/JiayingGameTweak-${scheme}.deb"
    echo "[OK] 产物: artifacts/JiayingGameTweak-${scheme}.deb"
  else
    echo "[ERROR] 未找到 deb 产物" >&2
    exit 1
  fi

  if [[ "$ACTION" == "install" ]]; then
    echo "[INFO] 安装到设备 ${THEOS_DEVICE_IP:-未设置} ..."
    make install
  fi
}

case "$SCHEME" in
  rootful)  build_one rootful ;;
  rootless) build_one rootless ;;
  both)     build_one rootful; build_one rootless ;;
  *) echo "[ERROR] 未知 scheme: $SCHEME (可选 rootful/rootless/both)" >&2; exit 1 ;;
esac

echo "[DONE] 全部完成。"
