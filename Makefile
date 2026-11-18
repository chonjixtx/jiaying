# =============================================================================
# JiayingGameTweak — iOS 外设映射核心 (theOS tweak)
# 支持 rootful (MobileSubstrate) 与 rootless (elleKit) 双 scheme
#
# 编译（在 macOS + theOS 环境）:
#   make                                    # 默认 rootful
#   THEOS_PACKAGE_SCHEME=rootless make      # rootless (Dopamine 等)
#   make package                            # 打包 deb
# 也可直接用 ./build.sh 选择 scheme 打包。
# =============================================================================

export TARGET := JiayingGameTweak

# --- 让 theOS  recognize 这是一个 tweak ---
TWEAK_NAME = JiayingGameTweak

# --- 源文件（Tweak.x + 各 Objective-C 模块） ---
JiayingGameTweak_FILES = \
	Tweak.x \
	Sources/JGHCommon.m \
	Sources/JGHTweakManager.m \
	Sources/JGHEventInjector.m \
	Sources/JGHDeviceMonitor.m \
	Sources/JGHFloatingControl.m \
	Sources/JGHKeyMapManager.m

# --- 公开框架 ---
JiayingGameTweak_FRAMEWORKS = Foundation UIKit CoreGraphics QuartzCore

# --- 私有框架（IOHIDEvent / 触摸注入依赖） ---
JiayingGameTweak_PRIVATE_FRAMEWORKS = IOKit

# --- 头文件搜索路径 ---
JiayingGameTweak_CFLAGS = -fobjc-arc -I$(CURDIR)/Sources

# --- ARC + Logos 需要 C++17 (Logos 生成 .mm) ---
JiayingGameTweak_CXXFLAGS = -std=c++17

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

# 安装后重启 SpringBoard 让 tweak 生效
after-install::
	install.exec "killall -9 SpringBoard" || true
