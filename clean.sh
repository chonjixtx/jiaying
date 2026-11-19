#!/bin/sh
# balls 一键清理：直接编辑 dpkg 账本，删除坏包记录，不调用 dpkg、不杀进程
D=$(command -v dpkg 2>/dev/null)
[ -x "$D" ] || D=/var/jb/usr/bin/dpkg
[ -x "$D" ] || D=/usr/bin/dpkg
J=$(dirname "$(dirname "$D")")
R="$J/var/lib/dpkg"
echo "jbroot=$J"

if [ ! -f "$R/status" ]; then
  echo "ERROR: status not found at $R/status"
  exit 1
fi

# 备份
cp "$R/status" "$R/status.ballsbak" 2>/dev/null

# 逐行状态机删除坏包段落
awk '
/^Package:[ \t]*/ {
    name=$2; sub(/\r$/,"",name)
    skip = (name=="com.jiaying.gamehall" || name ~ /^com\.balls\./) ? 1 : 0
}
skip==0 { print }
/^[ \t]*$/ { skip=0 }
' "$R/status" > "$R/status.ballsnew"

# 安全校验：新账本非空且至少还有1个包才覆盖
if [ -s "$R/status.ballsnew" ] && [ "$(grep -c '^Package:' "$R/status.ballsnew")" -ge 1 ]; then
  cat "$R/status.ballsnew" > "$R/status"
  echo "status cleaned"
else
  echo "SAFETY: new status invalid, keep original"
fi

# 清理 info 脚本和 updates 中断标记
rm -f "$R"/info/com.jiaying.gamehall.* 2>/dev/null
rm -f "$R"/info/com.balls.* 2>/dev/null
rm -f "$R"/updates/* 2>/dev/null

# 清理残留文件
rm -rf "$J/Applications/JiayingGameHall.app" 2>/dev/null
rm -f "$J/Library/MobileSubstrate/DynamicLibraries/JiayingGameTweak."* 2>/dev/null
rm -f "$J/usr/lib/TweakInject/JiayingGameTweak."* 2>/dev/null

if command -v uicache >/dev/null 2>&1; then uicache -r >/dev/null 2>&1; fi
echo "BALLS_CLEAN_OK"
