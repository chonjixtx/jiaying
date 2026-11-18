# =============================================================================
# JiayingGameHall — 独立 App（theOS application）
# 与外层 tweak 分别编译；app deb 依赖 tweak deb，安装 app 会自动带上 tweak。
# =============================================================================

APP_NAME = JiayingGameHall
BUNDLE_ID = com.jiaying.gamehall.app

ARCHS = arm64
GO_EASY_ON_ME = 1

JiayingGameHall_FILES = \
	Sources/main.m \
	Sources/JGHAppDelegate.m \
	Sources/JGHGameListViewController.m \
	Sources/JGHGamePickerViewController.m \
	Sources/JGHSettingsViewController.m \
	Sources/JGHAppConfig.m

JiayingGameHall_FRAMEWORKS = Foundation UIKit
JiayingGameHall_RESOURCES = Resources/Icon.png

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/application.mk

# 安装后刷新图标缓存（失败也不影响安装）
after-install::
	install.exec "uicache -r || uicache || true" || true
