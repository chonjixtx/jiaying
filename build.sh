#!/bin/bash
# =============================================================================
# JiayingGameHall 打包脚本
#   ./build.sh rootless        # tweak + app（rootless）
#   ./build.sh both            # 兼容旧参数：同样只打 rootless
#   ./build.sh rootful         # rootful（仅 tweak，app 仅支持 rootless）
# =============================================================================
set -euo pipefail

SCHEME="${1:-rootless}"
ACTION="${2:-package}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ -z "${THEOS:-}" ]]; then
  echo "[ERROR] 请先设置 THEOS 环境变量" >&2
  exit 1
fi

mkdir -p artifacts

build_tweak() {
  local scheme="$1"
  echo "============================================================"
  echo " 构建 tweak: $scheme"
  echo "============================================================"
  if [[ "$scheme" == "rootless" ]]; then
    cp -f control.rootless control
    export THEOS_PACKAGE_SCHEME=rootless
  else
    cp -f control.rootful control
    unset THEOS_PACKAGE_SCHEME || true
  fi
  make clean >/dev/null 2>&1 || true
  if ! make package 2>&1 | tee /tmp/tweak_build.log; then
    echo "::group::Tweak build error tail"
    tail -60 /tmp/tweak_build.log
    echo "::endgroup::"
    grep -iE "error:|fatal|undeclared|no visible|only available|duplicate|redefinition|cannot find" /tmp/tweak_build.log | head -20 | while IFS= read -r line; do echo "::error::$line"; done
    return 1
  fi
  local deb
  deb="$(ls -t packages/*.deb 2>/dev/null | head -n1 || true)"
  if [[ -n "$deb" ]]; then
    cp -f "$deb" "artifacts/JiayingGameTweak-${scheme}.deb"
    echo "[OK] tweak 产物: artifacts/JiayingGameTweak-${scheme}.deb"
  else
    echo "[ERROR] 未找到 tweak deb" >&2
    exit 1
  fi
}

build_app() {
  echo "============================================================"
  echo " 构建 App: JiayingGameHall"
  echo "============================================================"
  export THEOS_PACKAGE_SCHEME=rootless
  make -C App clean >/dev/null 2>&1 || true
  if ! make -C App package 2>&1 | tee /tmp/app_build.log; then
    echo "::group::App build error tail"
    tail -60 /tmp/app_build.log
    echo "::endgroup::"
    grep -iE "error:|fatal|undeclared|no visible|only available|duplicate|redefinition|cannot find" /tmp/app_build.log | head -20 | while IFS= read -r line; do echo "::error::$line"; done
    return 1
  fi
  local deb
  deb="$(ls -t App/packages/*.deb 2>/dev/null | head -n1 || true)"
  if [[ -n "$deb" ]]; then
    cp -f "$deb" "artifacts/JiayingGameHall-app.deb"
    echo "[OK] App 产物: artifacts/JiayingGameHall-app.deb"
  else
    echo "[ERROR] 未找到 App deb" >&2
    exit 1
  fi
}

case "$SCHEME" in
  rootless|both)
    build_tweak rootless
    build_app
    ;;
  rootful)
    build_tweak rootful
    ;;
  *)
    echo "[ERROR] 未知 scheme: $SCHEME" >&2
    exit 1
    ;;
esac

if [[ "$ACTION" == "install" ]]; then
  echo "[INFO] 安装到设备 ${THEOS_DEVICE_IP:-未设置} ..."
  make install
fi

echo "[DONE] 全部完成。"
