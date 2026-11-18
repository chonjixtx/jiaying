# =============================================================================
# JiayingGameHall — 独立 App（theOS application）
# 与外层 tweak 分别编译；app deb 依赖 tweak deb，安装 app 会自动带上 tweak。
# 注意：theOS 应用工程必须用 APPLICATION_NAME（不是 APP_NAME），
#       否则实例名为空，make package 会打出没有可执行文件的空壳 deb。
# =============================================================================

ARCHS = arm64
GO_EASY_ON_ME = 1

# theOS 识别应用实例的关键变量
APPLICATION_NAME = JiayingGameHall

# 实例名对应的一堆变量（前缀必须与 APPLICATION_NAME 一致）
JiayingGameHall_BUNDLE_ID = com.jiaying.gamehall.app
JiayingGameHall_INSTALL_PATH = /Applications

JiayingGameHall_FILES = \
	Sources/main.m \
	Sources/JGHAppDelegate.m \
	Sources/JGHGameListViewController.m \
	Sources/JGHGamePickerViewController.m \
	Sources/JGHSettingsViewController.m \
	Sources/JGHAppConfig.m

JiayingGameHall_FRAMEWORKS = Foundation UIKit CoreGraphics

# Resources/ 目录会被整体复制进 .app（默认行为），Info.plist 与图标都放在那里
include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/application.mk

# 安装后刷新图标缓存（失败也不影响安装）
after-install::
	install.exec "uicache -r || uicache || true" || true
