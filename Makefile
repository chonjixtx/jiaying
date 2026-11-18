# =============================================================================
# JiayingGameTweak — iOS 外设映射核心 (theOS tweak)
# =============================================================================

TWEAK_NAME = JiayingGameTweak

# 只编译 64 位：避免 theOS 默认带 armv7 导致
# "symbol(s) not found for architecture armv7" 链接失败
ARCHS = arm64 arm64e

# 宽松编译：忽略 SDK 版本差异带来的无害警告
GO_EASY_ON_ME = 1

JiayingGameTweak_FILES = \
	Tweak.x \
	Sources/JGHCommon.m \
	Sources/JGHTweakManager.m \
	Sources/JGHEventInjector.m \
	Sources/JGHDeviceMonitor.m \
	Sources/JGHFloatingControl.m \
	Sources/JGHKeyMapManager.m

JiayingGameTweak_FRAMEWORKS = Foundation UIKit CoreGraphics QuartzCore
JiayingGameTweak_PRIVATE_FRAMEWORKS = IOKit

JiayingGameTweak_CFLAGS = -fobjc-arc -Wno-error -I$(CURDIR)/Sources
JiayingGameTweak_CXXFLAGS = -std=c++17 -Wno-error

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard" || true
