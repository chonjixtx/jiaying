# JiayingGameTweak

iOS 外设映射核心（类「佳影游戏厅」的 root 版实现）。把蓝牙/有线键鼠、手柄的 HID 输入映射为屏幕触摸，供手游使用。

> ⚠️ **合规与风险**：本项目仅用于学习 HID 事件与越狱 tweak 开发。用于竞技类网游可能违反游戏服务条款并导致封号；越狱会破坏设备安全模型。请自行评估风险，勿用于任何违法用途。

## 功能

- **外设监听**：IOHIDManager 监听键盘 / 鼠标 / 手柄，支持热插拔
- **触摸注入**：IOHIDEvent digitizer 事件注入，支持 点按 / 长按 / 滑动 / 虚拟摇杆 / 多点触控
- **键位配置**：JSON 配置，按 App bundleID 自动切换，可持久化
- **悬浮面板**：可拖动、启用/停用、重载配置、触摸穿透不挡游戏
- **双环境兼容**：rootful (MobileSubstrate) 与 rootless (elleKit) 一键打包

## 目录结构

```
JiayingGameTweak/
├── Makefile                # theOS 构建配置（双 scheme）
├── control{,.rootful,.rootless}  # deb 元数据
├── Tweak.x                 # Logos 入口
├── Sources/
│   ├── IOHIDPrivate.h      # 私有 API 前向声明
│   ├── JGHCommon.{h,m}     # 日志 / rootless 路径适配
│   ├── JGHEventInjector.{h,m}   # 触摸注入（dlsym 私有符号）
│   ├── JGHDeviceMonitor.{h,m}   # HID 外设监听
│   ├── JGHKeyMapManager.{h,m}   # 键位配置管理
│   ├── JGHFloatingControl.{h,m} # 悬浮面板
│   └── JGHTweakManager.{h,m}    # 核心协调器
├── build.sh                # 打包脚本
├── layout/                 # 随 deb 安装的资源（theOS 自动纳入）
│   └── Library/PreferenceLoader/Preferences/JiayingGameTweak.plist
└── repo/
    ├── build_repo.sh       # 生成 APT repo 元数据
    └── example-profile.json
```

## 编译（无需自己有 Mac）

本机为 Windows，**无法本地编译 iOS tweak**。推荐用 GitHub Actions 的免费云端 Mac 编译（已配置好 `.github/workflows/build.yml`）：

1. 注册/登录 GitHub，新建一个仓库（可设为私有，私有仓库每月也有 2000 分钟免费额度，编译一次仅需几分钟）
2. 把整个 `JiayingGameTweak` 文件夹上传到仓库（网页拖拽上传，或用 `git`）
3. 进入仓库的 **Actions** 标签页 → 点 **I understand, enable the workflow**（首次需启用）
4. 等待自动构建完成（通常 3~6 分钟）。若未自动触发，点右侧 **Run workflow** 手动运行
5. 构建成功后，点击该次运行 → 页面底部 **Artifacts** → 下载 `JiayingGameTweak-rootless`（rootless 环境）或 `JiayingGameTweak-rootful`
6. 解压得到 `.deb`，传到越狱设备安装（见下方「安装」）

> 云端编译会自动装 theOS + dpkg，无需你配置任何环境。若编译失败，点开该次运行的日志，把红色报错贴出来即可定位。

### 如果你自己有 Mac（可选）

本地编译方式：

```bash
# 1. 安装 theOS
bash <(curl -sL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)

# 2. 配置
export THEOS=~/theos

# 3. 打包（二选一或都打）
cd JiayingGameTweak
chmod +x build.sh
./build.sh rootful      # -> artifacts/JiayingGameTweak-rootful.deb
./build.sh rootless     # -> artifacts/JiayingGameTweak-rootless.deb
./build.sh both
```

- **rootless** 适用 iOS 15.0+（Dopamine / Odyssey 等），依赖 `mobilesubstrate`（ElleKit 提供该虚拟包）
- **rootful** 适用 iOS 14 及以下传统越狱，依赖 `mobilesubstrate`

> 编译期若报 IOHID 私有符号未定义，确认 `JiayingGameTweak_PRIVATE_FRAMEWORKS = IOKit` 已生效，且所用 SDK 含 IOKit 私有头。

## 安装

方式 A — 直接安装 deb：
```bash
# 传到越狱设备后
dpkg -i JiayingGameTweak-rootless.deb
killall -9 SpringBoard
```

方式 B — Sileo 添加自建源：
```bash
# 1. 把 deb 放进 repo/ 目录
cp artifacts/*.deb repo/

# 2. 生成元数据
cd repo && chmod +x build_repo.sh && ./build_repo.sh

# 3. 用 HTTP 托管 repo/（需 HTTPS 或 Sileo 允许 HTTP）
python3 -m http.server 8080 --directory repo

# 4. Sileo -> 源 -> 添加 -> 填 http://<你的地址>:8080
```
公司/内网部署建议用 Nginx + HTTPS，避免明文源被拦截。

## 键位配置格式

配置存放路径（自动适配环境）：
- rootless: `/var/jb/var/mobile/Library/JiayingGameHall/Profiles/`
- rootful: `/var/mobile/Library/JiayingGameHall/Profiles/`

格式见 `repo/example-profile.json`：
- `bundleID`：目标 App；`*` 表示通用配置
- 映射 key 为 `usagePage:usage`（如 `7:4` = 键盘 A，`9:1` = 鼠标左键）
- `type`：`tap` / `hold` / `swipe` / `joystick`
- `x`,`y`：屏幕归一化坐标（0~1）；`dx`,`dy`：方向/位移；`finger`：手指编号（多点）

用 HID 调试工具确认具体按键的 usage 值后填入即可。

## 已知限制 / 待真机调试项

1. **未在本机编译验证**：本工程在 Windows 生成，Objective-C/Logos 代码需在 Mac + theOS 下编译。已做符号与头文件的静态核对，但 iOS 私有 API 的行为需真机确认。
2. **IOHIDEvent 字段常量**：不同 iOS 版本 `kIOHIDEventField*` 取值可能不同，注入器只用 `IOHIDEventCreateDigitizerEvent` 的参数传坐标。若真机出现坐标偏移，需按目标 SDK 调整 `JGHEventInjector.m`。
3. **反作弊**：带「映射/连点/自瞄」特征的代码可能被游戏检测，本项目不含此类逻辑，但注入本身即可能被识别。
4. **App 沙盒**：tweak 注入到目标 App 进程，配置读写路径在 App 容器外，需确保文件权限（代码已设 `NSFileProtectionNone`）。
5. **arm64e**：真机若需 arm64e，注意 ptrauth 对函数指针(dlsym)的影响，必要时在 Makefile `ARCHS` 中去掉 arm64e。

## 路线图

- [ ] PreferenceLoader 图形化配置面板（替代手写 JSON）
- [ ] 按键录制 / 学习模式
- [ ] 陀螺仪 / 触摸宏
- [ ] 设备级白名单（仅对指定 App 注入）
