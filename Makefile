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

# --- 让 theOS recognize 这是一个 tweak ---
# 注意：TARGET 是 theOS 保留变量（表示编译目标平台），不能设为工程名。
# 不设置它，让 theOS 根据 THEOS_PACKAGE_SCHEME 自动选择 iphoneos 目标。
TWEAK_NAME = JiayingGameTweak

# --- 架构：只编译 64 位 ---
# 现代 Xcode SDK 已移除 32 位 armv7 系统库，theOS 默认仍带 armv7 时
# 链接会报 "symbol(s) not found for architecture armv7"。
# 越狱设备均为 64 位（arm64 / arm64e），显式限定即可彻底避开。
ARCHS = arm64 arm64e

# --- 宽松编译：忽略 SDK 版本差异带来的无害警告 ---
GO_EASY_ON_ME = 1

# --- 源文件（Tweak.x + 各 Objective-C 模块） ---
JiayingGameTweak_FILES = \
	Tweak.x \
	Sources/JGHCommon.m \
	Sources/JGHTweakManager.m \
	Sources/JGHEventInjector.m \
	Sources/JGHDeviceMonitor.m \
	Sources/JGHFloatingControl.m \
	Sources/JGHKeyMapManager.m \
	Sources/JGHSettings.m

# --- 公开框架 ---
JiayingGameTweak_FRAMEWORKS = Foundation UIKit CoreGraphics QuartzCore

# --- 私有框架（IOHIDEvent / 触摸注入依赖） ---
JiayingGameTweak_PRIVATE_FRAMEWORKS = IOKit

# --- 头文件搜索路径 ---
# -Wno-error：theOS 默认把 warning 当 error（日志里可见 [-Werror]），
# 关闭后可避免 SDK 版本差异带来的无害警告导致编译失败。
JiayingGameTweak_CFLAGS = -fobjc-arc -Wno-error -I$(CURDIR)/Sources

# --- ARC + Logos 需要 C++17 (Logos 生成 .mm) ---
JiayingGameTweak_CXXFLAGS = -std=c++17 -Wno-error

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

# 安装后重启 SpringBoard 让 tweak 生效
after-install::
	install.exec "killall -9 SpringBoard" || true
